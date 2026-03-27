import argparse
from datetime import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODULES_DIR = ROOT / "modules"
OUT_DIR = ROOT / "brainboard-import"
OUT_FILE = OUT_DIR / "brainboard.tf"
ENV_DIR = ROOT / "env"
PROD_TFVARS = ENV_DIR / "prod.tfvars"

BLOCK_START_RE = re.compile(
    r'(?m)^\s*(resource|data|locals)\b(?:\s+"([^"]+)")?(?:\s+"([^"]+)")?\s*{'
)
VAR_REF_RE = re.compile(r"\bvar\.([A-Za-z_][A-Za-z0-9_]*)\b")
VAR_DECL_RE = re.compile(r'(?m)^variable\s+"([^"]+)"\s*{')
RANDOM_PASSWORD_REF_RE = re.compile(r"\brandom_password\.[A-Za-z_][A-Za-z0-9_]*\.result\b")

# Brainboard does not currently provide identity cards for these resource types.
# We omit them from visualization-only output to avoid import warning noise.
UNSUPPORTED_BRAINBOARD_RESOURCE_TYPES = {
    "random_password",
    "aws_wafv2_web_acl",
}


class BuildLogger:
    def __init__(self, path: Path):
        self.path = path
        self._fh = path.open("a", encoding="utf-8")

    def log(self, message: str):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        line = f"[{timestamp}] {message}"
        print(line)
        self._fh.write(line + "\n")
        self._fh.flush()

    def close(self):
        self._fh.close()


LOGGER = None


def _log(message: str):
    if LOGGER is None:
        print(message)
    else:
        LOGGER.log(message)


def _extract_block(text: str, start_idx: int):
    brace_idx = text.find("{", start_idx)
    if brace_idx == -1:
        return None, start_idx

    depth = 0
    i = brace_idx
    in_str = False
    str_char = ""
    in_heredoc = False
    heredoc_end = None

    while i < len(text):
        ch = text[i]

        if in_heredoc:
            line_end = text.find("\n", i)
            if line_end == -1:
                line_end = len(text)
            line = text[i:line_end]
            if line.strip() == heredoc_end:
                in_heredoc = False
                heredoc_end = None
            i = line_end + 1
            continue

        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == str_char:
                in_str = False
            i += 1
            continue

        # HCL strings are double-quoted; single quotes often appear in comments.
        if ch == '"':
            in_str = True
            str_char = ch
            i += 1
            continue

        # Skip comments so braces/apostrophes inside comments do not affect parsing.
        if ch == "#":
            line_end = text.find("\n", i)
            if line_end == -1:
                return None, len(text)
            i = line_end + 1
            continue
        if ch == "/" and text[i : i + 2] == "//":
            line_end = text.find("\n", i)
            if line_end == -1:
                return None, len(text)
            i = line_end + 1
            continue
        if ch == "/" and text[i : i + 2] == "/*":
            block_end = text.find("*/", i + 2)
            if block_end == -1:
                return None, len(text)
            i = block_end + 2
            continue

        if ch == "<" and text[i : i + 2] == "<<":
            m = re.match(r"<<-?\s*([A-Za-z0-9_]+)", text[i:])
            if m:
                heredoc_end = m.group(1)
                in_heredoc = True
                i += m.end()
                continue

        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start_idx : i + 1], i + 1
        i += 1

    return None, len(text)


def _collect_blocks(text: str):
    blocks = []
    pos = 0
    while True:
        m = BLOCK_START_RE.search(text, pos)
        if not m:
            break

        kind = m.group(1)
        label_1 = m.group(2)
        label_2 = m.group(3)
        block_text, end = _extract_block(text, m.start())
        if block_text:
            blocks.append((kind, label_1, label_2, block_text))
            pos = end
        else:
            pos = m.end()
    return blocks


def _rename_header(block_text: str, kind: str, label_1: str, old_name: str, new_name: str):
    pattern = (
        rf'(^\s*{re.escape(kind)}\s+"{re.escape(label_1)}"\s+")'
        rf'{re.escape(old_name)}(")'
    )
    return re.sub(pattern, rf"\1{new_name}\2", block_text, count=1, flags=re.M)


def _replace_refs(block_text: str, res_map, data_map, var_map):
    for (dtype, name), new_name in data_map.items():
        block_text = re.sub(
            rf"\bdata\.{re.escape(dtype)}\.{re.escape(name)}\b",
            f"data.{dtype}.{new_name}",
            block_text,
        )
    for (rtype, name), new_name in res_map.items():
        block_text = re.sub(
            rf"\b{re.escape(rtype)}\.{re.escape(name)}\b",
            f"{rtype}.{new_name}",
            block_text,
        )
    for old_name, new_name in var_map.items():
        block_text = re.sub(
            rf"\bvar\.{re.escape(old_name)}\b",
            f"var.{new_name}",
            block_text,
        )
    # Keep module-relative template paths valid after flattening into brainboard-import/.
    block_text = block_text.replace(
        "${path.module}/../../template/ecs_json.tpl",
        "${path.module}/../template/ecs_json.tpl",
    )
    return block_text


def _normalize_dynamodb_gsi_key_schema(block_text: str) -> str:
    """Normalize DynamoDB GSIs to hash_key/range_key for Brainboard compatibility."""
    lines = block_text.splitlines()
    out = []
    stack = []

    block_open_re = re.compile(r"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*{\s*$")
    hash_re = re.compile(r'^\s*hash_key\s*=\s*(.+?)\s*$')
    range_re = re.compile(r'^\s*range_key\s*=\s*(.+?)\s*$')
    attr_re = re.compile(r'^\s*attribute_name\s*=\s*(.+?)\s*$')
    key_type_re = re.compile(r'^\s*key_type\s*=\s*"([^"]+)"\s*$')

    for line in lines:
        stripped = line.strip()
        m_open = block_open_re.match(line)

        if m_open:
            frame = {
                "name": m_open.group(2),
                "indent": m_open.group(1),
                "hash_expr": None,
                "range_expr": None,
                "hash_seen": False,
                "range_seen": False,
                "attr_expr": None,
                "key_type": None,
            }
            stack.append(frame)
            if frame["name"] == "key_schema" and len(stack) >= 2 and stack[-2]["name"] == "global_secondary_index":
                continue
            out.append(line)
            continue

        if stripped == "}" and stack:
            current = stack[-1]

            if current["name"] == "key_schema" and len(stack) >= 2 and stack[-2]["name"] == "global_secondary_index":
                parent = stack[-2]
                if current["key_type"] == "HASH" and current["attr_expr"] is not None:
                    parent["hash_expr"] = current["attr_expr"]
                if current["key_type"] == "RANGE" and current["attr_expr"] is not None:
                    parent["range_expr"] = current["attr_expr"]
                stack.pop()
                continue

            if current["name"] == "global_secondary_index":
                key_indent = current["indent"] + "  "
                if current["hash_expr"] is not None and not current["hash_seen"]:
                    out.append(f"{key_indent}hash_key        = {current['hash_expr']}")
                if current["range_expr"] is not None and not current["range_seen"]:
                    out.append(f"{key_indent}range_key       = {current['range_expr']}")
            out.append(line)
            stack.pop()
            continue

        if stack and stack[-1]["name"] == "global_secondary_index":
            m_hash = hash_re.match(line)
            if m_hash:
                stack[-1]["hash_expr"] = m_hash.group(1)
                stack[-1]["hash_seen"] = True
                out.append(line)
                continue
            m_range = range_re.match(line)
            if m_range:
                stack[-1]["range_expr"] = m_range.group(1)
                stack[-1]["range_seen"] = True
                out.append(line)
                continue

        if stack and stack[-1]["name"] == "key_schema" and len(stack) >= 2 and stack[-2]["name"] == "global_secondary_index":
            m_attr = attr_re.match(line)
            if m_attr:
                stack[-1]["attr_expr"] = m_attr.group(1)
                continue
            m_key_type = key_type_re.match(line)
            if m_key_type:
                stack[-1]["key_type"] = m_key_type.group(1).upper()
                continue
            continue

        out.append(line)

    return "\n".join(out)


def _strip_dynamic_block_instances(block_text: str, block_name: str) -> str:
    pattern = re.compile(rf'(?m)^\s*dynamic\s+"{re.escape(block_name)}"\s*{{')
    out = []
    pos = 0

    while True:
        m = pattern.search(block_text, pos)
        if not m:
            out.append(block_text[pos:])
            break
        out.append(block_text[pos : m.start()])
        dynamic_block, end = _extract_block(block_text, m.start())
        if not dynamic_block:
            out.append(block_text[m.start() :])
            break
        pos = end
        if pos < len(block_text) and block_text[pos] == "\n":
            pos += 1

    normalized = "".join(out)
    return re.sub(r"\n{3,}", "\n\n", normalized)


def _normalize_lb_listener_default_action(block_text: str) -> str:
    if 'dynamic "default_action"' not in block_text:
        return block_text

    normalized = _strip_dynamic_block_instances(block_text, "default_action")
    if re.search(r"(?m)^\s*default_action\s*{", normalized):
        return normalized

    lines = normalized.rstrip().splitlines()
    if not lines:
        return normalized

    close_idx = len(lines) - 1
    while close_idx >= 0 and lines[close_idx].strip() == "":
        close_idx -= 1
    if close_idx < 0 or lines[close_idx].strip() != "}":
        return normalized

    resource_indent = re.match(r"^(\s*)", lines[0]).group(1)
    indent = resource_indent + "  "
    default_action_block = [
        f"{indent}default_action {{",
        f'{indent}  type = "fixed-response"',
        f"{indent}  fixed_response {{",
        f'{indent}    content_type = "application/json"',
        f'{indent}    message_body = "{{\\"message\\":\\"Not Found\\"}}"',
        f'{indent}    status_code  = "404"',
        f"{indent}  }}",
        f"{indent}}}",
    ]

    new_lines = lines[:close_idx] + [""] + default_action_block + lines[close_idx:]
    return "\n".join(new_lines)


def _normalize_cloudfront_origin_access_identity(block_text: str) -> str:
    return re.sub(
        r'(?m)^(\s*origin_access_identity\s*=\s*)""\s*$',
        r'\1"origin-access-identity/cloudfront/brainboard-placeholder"',
        block_text,
    )


def _normalize_kms_rotation_period(block_text: str) -> str:
    if not re.search(r"(?m)^\s*enable_key_rotation\s*=\s*true\s*$", block_text):
        return block_text
    if re.search(r"(?m)^\s*rotation_period_in_days\s*=", block_text):
        return block_text

    m = re.search(r"(?m)^(\s*)enable_key_rotation\s*=\s*true\s*$", block_text)
    if not m:
        return block_text
    insert_at = m.end()
    indent = m.group(1)
    return block_text[:insert_at] + f"\n{indent}rotation_period_in_days = 365" + block_text[insert_at:]


def _rewrite_unsupported_refs_for_visualization(block_text: str) -> str:
    # Keep generated Terraform self-consistent after omitting random_password resources.
    return RANDOM_PASSWORD_REF_RE.sub('"brainboard-placeholder"', block_text)


FALLBACK_VAR_DEFAULTS = {
    "use_custom_domain": False,
    "enable_cloudfront_oac": True,
    "enable_log_api_origin": False,
    "enable_audit_table": False,
    "enable_aml_table": False,
    "enable_point_in_time_recovery": True,
    "enable_ttl": False,
    "billing_mode": "PAY_PER_REQUEST",
    "manage_route53_record": False,
}


def _run_brainboard_compatibility_checks(tf_file: Path):
    text = tf_file.read_text(encoding="utf-8")
    issues = []

    if 'dynamic "default_action"' in text:
        issues.append('Found `dynamic "default_action"`; Brainboard preflight may miss required listener action fields.')
    if "key_schema {" in text:
        issues.append("Found DynamoDB `key_schema` blocks; Brainboard expects GSI `hash_key`/`range_key`.")
    if re.search(r'(?m)^\s*origin_access_identity\s*=\s*""\s*$', text):
        issues.append("Found empty CloudFront `origin_access_identity`; Brainboard treats it as missing.")
    if re.search(r'(?ms)resource\s+"aws_kms_key"\s+"[^"]+"\s*{.*?enable_key_rotation\s*=\s*true', text) and "rotation_period_in_days" not in text:
        issues.append("Found `aws_kms_key.enable_key_rotation = true` without `rotation_period_in_days`.")
    if 'provider "aws"' in text and 'region = "ap-southeast-1"' not in text:
        issues.append("No explicit `ap-southeast-1` provider region found in generated file.")

    if issues:
        formatted = "\n".join(f"- {issue}" for issue in issues)
        raise RuntimeError(f"Brainboard compatibility check failed:\n{formatted}")


def _append_module_var_stubs(out_lines, module_name: str, var_map: dict):
    if not var_map:
        return

    out_lines.append(f"# Variables for module {module_name}")
    for var_name in sorted(var_map):
        default_value = _resolve_module_var_default(var_name)
        out_lines.append(f'variable "{var_map[var_name]}" {{')
        out_lines.append("  type    = any")
        out_lines.append(f"  default = {_hcl_literal(default_value)}")
        out_lines.append("}")
        out_lines.append("")


PROFILE_VAR_VALUES = {}


def _resolve_module_var_default(var_name: str):
    if var_name in FALLBACK_VAR_DEFAULTS:
        return FALLBACK_VAR_DEFAULTS[var_name]
    if var_name in PROFILE_VAR_VALUES:
        return PROFILE_VAR_VALUES[var_name]
    if var_name == "name_prefix":
        return PROFILE_VAR_VALUES.get("name_prefix", "brainboard-prod")
    if var_name == "project_name":
        return PROFILE_VAR_VALUES.get("project_name", "scroogebank-crm")
    if var_name == "environment":
        return PROFILE_VAR_VALUES.get("environment", "prod")
    if var_name == "aws_region":
        return PROFILE_VAR_VALUES.get("aws_region", "ap-southeast-1")
    if var_name in {"lab_role_arn", "lab_role_name"}:
        return ""
    return None


def _strip_inline_comment(value: str) -> str:
    in_str = False
    escaped = False
    for idx, ch in enumerate(value):
        if in_str:
            if escaped:
                escaped = False
                continue
            if ch == "\\":
                escaped = True
                continue
            if ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
            continue
        if ch == "#":
            return value[:idx].rstrip()
    return value.strip()


def _parse_tfvars_scalar(raw: str):
    text = raw.strip()
    if text == "":
        return ""
    if text.startswith('"') and text.endswith('"'):
        try:
            return json.loads(text)
        except Exception:
            return text.strip('"')
    low = text.lower()
    if low == "true":
        return True
    if low == "false":
        return False
    if re.match(r"^-?\d+$", text):
        return int(text)
    if re.match(r"^-?\d+\.\d+$", text):
        return float(text)
    return text


def _load_simple_tfvars(tfvars_path: Path) -> dict:
    values = {}
    if not tfvars_path.exists():
        return values

    for raw_line in tfvars_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        key = key.strip()
        if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
            continue
        raw_value = _strip_inline_comment(raw_value)
        values[key] = _parse_tfvars_scalar(raw_value)
    return values


def _build_prod_profile_values() -> dict:
    values = _load_simple_tfvars(PROD_TFVARS)

    project_name = str(values.get("project_name", "scroogebank-crm")).strip() or "scroogebank-crm"
    environment = str(values.get("environment", "prod")).strip() or "prod"
    aws_region = str(values.get("aws_region", "ap-southeast-1")).strip() or "ap-southeast-1"
    name_prefix = f"{project_name}-{environment}".replace("_", "-").lower()

    values["project_name"] = project_name
    values["environment"] = environment
    values["aws_region"] = aws_region
    values["name_prefix"] = name_prefix
    values.setdefault("lab_role_arn", "")
    values.setdefault("lab_role_name", "")
    return values


def _profile_bool(name: str, default: bool = False) -> bool:
    value = PROFILE_VAR_VALUES.get(name, default)
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() == "true"
    return bool(value)


def _profile_non_empty(name: str) -> bool:
    value = PROFILE_VAR_VALUES.get(name, "")
    if value is None:
        return False
    return str(value).strip() != ""


def _is_module_enabled(module_name: str) -> bool:
    if not PROFILE_VAR_VALUES:
        return True

    if module_name == "acm":
        # Root module gate: module.acm count depends on both app_domain_name and create_acm_certificates.
        return _profile_non_empty("app_domain_name") and _profile_bool("create_acm_certificates")
    if module_name == "apigateway":
        return _profile_bool("enable_log_lambda")
    if module_name == "cloudfront":
        return _profile_bool("enable_cloudfront", default=True)
    if module_name == "cognito":
        return _profile_bool("enable_cognito", default=True)

    return True


def _append_aws_provider(out_lines, region: str, alias: str | None = None):
    out_lines.append('provider "aws" {')
    if alias:
        out_lines.append(f'  alias  = "{alias}"')
    out_lines.append(f'  region = "{region}"')
    out_lines.append("  skip_credentials_validation = true")
    out_lines.append("  skip_requesting_account_id  = true")
    out_lines.append("  skip_region_validation      = true")
    out_lines.append("  skip_metadata_api_check     = true")
    out_lines.append("}")
    out_lines.append("")


def _prepare_build_logger():
    logs_dir = ROOT / "build-logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    # Keep at most 2 existing logs before creating a new one, so retention stays at 3.
    existing_logs = sorted(
        logs_dir.glob("build-*.log"),
        key=lambda p: p.stat().st_mtime,
    )
    while len(existing_logs) > 2:
        oldest = existing_logs.pop(0)
        oldest.unlink(missing_ok=True)

    if os.name == "nt":
        subprocess.run(
            ["attrib", "+h", str(logs_dir)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    log_file = logs_dir / f"build-{datetime.now().strftime('%Y%m%d-%H%M%S-%f')}.log"
    return BuildLogger(log_file)


def generate_brainboard_tf() -> tuple[Path, bool]:
    if not MODULES_DIR.exists():
        raise SystemExit(f"Missing modules dir: {MODULES_DIR}")

    OUT_DIR.mkdir(exist_ok=True)

    out_lines = []
    out_lines.append("# Auto-generated Brainboard import file")
    out_lines.append("# Source: modules/*")
    out_lines.append("# Purpose: visualize resources (not intended for Terraform apply)")
    out_lines.append("# Note: known Brainboard-unsupported resources are omitted.")
    out_lines.append("")
    out_lines.append("terraform {")
    out_lines.append('  required_version = ">= 1.5.0"')
    out_lines.append("  required_providers {")
    out_lines.append('    aws = { source = "hashicorp/aws", version = "~> 6.0" }')
    out_lines.append('    random = { source = "hashicorp/random", version = "~> 3.0" }')
    out_lines.append("  }")
    out_lines.append("}")
    out_lines.append("")

    primary_region = str(PROFILE_VAR_VALUES.get("aws_region", "ap-southeast-1"))
    _append_aws_provider(out_lines, primary_region)
    _append_aws_provider(out_lines, "us-east-1", alias="us_east_1")
    _append_aws_provider(out_lines, "ap-southeast-1", alias="ap_southeast_1")

    for module_dir in sorted(MODULES_DIR.iterdir()):
        if not module_dir.is_dir():
            continue
        module_name = module_dir.name
        if not _is_module_enabled(module_name):
            _log(f"Skipping module '{module_name}' for prod profile.")
            continue

        res_map = {}
        data_map = {}
        module_blocks = []
        var_names = set()

        for tf_file in sorted(module_dir.rglob("*.tf")):
            text = tf_file.read_text(encoding="utf-8")
            var_names.update(VAR_REF_RE.findall(text))
            blocks = _collect_blocks(text)
            for kind, label_1, label_2, block_text in blocks:
                if kind == "resource":
                    res_map[(label_1, label_2)] = f"{module_name}__{label_2}"
                elif kind == "data":
                    data_map[(label_1, label_2)] = f"{module_name}__{label_2}"
                module_blocks.append((kind, label_1, label_2, block_text, tf_file))

        if not module_blocks:
            continue

        var_map = {name: f"{module_name}__{name}" for name in var_names}

        out_lines.append(f"# ---- Module: {module_name} ----")
        _append_module_var_stubs(out_lines, module_name, var_map)

        for kind, label_1, label_2, block_text, tf_file in module_blocks:
            if kind in {"resource", "data"}:
                new_name = (
                    res_map.get((label_1, label_2))
                    if kind == "resource"
                    else data_map.get((label_1, label_2))
                )
                block_text = _rename_header(block_text, kind, label_1, label_2, new_name)

            block_text = _replace_refs(block_text, res_map, data_map, var_map)
            block_text = _rewrite_unsupported_refs_for_visualization(block_text)
            if kind == "resource" and label_1 == "aws_dynamodb_table":
                block_text = _normalize_dynamodb_gsi_key_schema(block_text)
            if kind == "resource" and label_1 == "aws_lb_listener":
                block_text = _normalize_lb_listener_default_action(block_text)
            if kind == "resource" and label_1 == "aws_cloudfront_distribution":
                block_text = _normalize_cloudfront_origin_access_identity(block_text)
            if kind == "resource" and label_1 == "aws_kms_key":
                block_text = _normalize_kms_rotation_period(block_text)
            if kind == "resource" and label_1 in UNSUPPORTED_BRAINBOARD_RESOURCE_TYPES:
                continue

            out_lines.append(f"# Source: {tf_file.relative_to(ROOT).as_posix()}")
            out_lines.append(block_text.rstrip())
            out_lines.append("")

    new_text = "\n".join(out_lines).rstrip() + "\n"
    old_text = OUT_FILE.read_text(encoding="utf-8") if OUT_FILE.exists() else None

    if old_text != new_text:
        OUT_FILE.write_text(new_text, encoding="utf-8")
        return OUT_FILE, True
    return OUT_FILE, False


def _neutral_aws_env():
    env = os.environ.copy()
    env.update(
        {
            "AWS_ACCESS_KEY_ID": "static-analysis",
            "AWS_SECRET_ACCESS_KEY": "static-analysis",
            "AWS_SESSION_TOKEN": "static-analysis",
            "AWS_DEFAULT_REGION": "ap-southeast-1",
            "AWS_REGION": "ap-southeast-1",
            "AWS_EC2_METADATA_DISABLED": "true",
            "AWS_SDK_LOAD_CONFIG": "0",
            "TF_IN_AUTOMATION": "1",
        }
    )
    env.pop("AWS_PROFILE", None)
    env.pop("AWS_DEFAULT_PROFILE", None)
    return env


def _run_command(cmd: list[str], cwd: Path, env=None, allow_failure: bool = False):
    start = time.perf_counter()
    _log(f"[run] {' '.join(cmd)} (cwd={cwd})")
    result = subprocess.run(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        capture_output=True,
    )
    if result.stdout:
        for line in result.stdout.rstrip().splitlines():
            _log(f"[stdout] {line}")
    if result.stderr:
        for line in result.stderr.rstrip().splitlines():
            _log(f"[stderr] {line}")

    elapsed = time.perf_counter() - start
    _log(f"[done] exit={result.returncode} duration={elapsed:.2f}s")
    if result.returncode != 0 and not allow_failure:
        raise RuntimeError(f"Command failed with exit code {result.returncode}: {' '.join(cmd)}")
    return result


def _build_operable_lambda_artifacts(terraform_dir: Path):
    artifacts_dir = terraform_dir / ".generated-lambda-artifacts"
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    lambda_source = artifacts_dir / "lambda_function.py"
    lambda_source.write_text(
        "def lambda_handler(event, context):\n"
        "    return {\"statusCode\": 200, \"body\": \"ok\"}\n",
        encoding="utf-8",
    )

    variable_to_zip = {
        "lambda__log_lambda_zip_path": "log-lambda.zip",
        "lambda__aml_lambda_zip_path": "aml-lambda.zip",
        "lambda__sftp_transaction_collector_zip_path": "sftp-transaction-collector.zip",
        "lambda__audit_consumer_zip_path": "audit-consumer-lambda.zip",
        "lambda__aml_consumer_zip_path": "aml-consumer-lambda.zip",
        "lambda__verification_zip_path": "verification-lambda.zip",
    }

    out = {}
    for var_name, zip_name in variable_to_zip.items():
        zip_path = artifacts_dir / zip_name
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(lambda_source, arcname="lambda_function.py")
        out[var_name] = f"./.generated-lambda-artifacts/{zip_name}"
    return out


def _hcl_literal(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[{}]".format(", ".join(_hcl_literal(v) for v in value))
    if isinstance(value, dict):
        pairs = []
        for key in sorted(value):
            if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
                hcl_key = key
            else:
                hcl_key = json.dumps(key)
            pairs.append(f"{hcl_key} = {_hcl_literal(value[key])}")
        return "{{ {} }}".format(", ".join(pairs))
    return json.dumps(str(value))


def _write_tfvars(path: Path, values: dict):
    lines = []
    for key in sorted(values):
        lines.append(f"{key} = {_hcl_literal(values[key])}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _collect_declared_variables(tf_file: Path):
    text = tf_file.read_text(encoding="utf-8")
    return set(VAR_DECL_RE.findall(text))


def _feature_flag_values(declared_vars: set[str], artifact_paths: dict):
    values = {}

    def put(name, value):
        if name in declared_vars:
            values[name] = value

    for name in sorted(declared_vars):
        if name.endswith("__name_prefix"):
            put(name, "brainboard-test")
        if name.endswith("__project_name"):
            put(name, "brainboard")
        if name.endswith("__environment"):
            put(name, "dev")
        if name.endswith("__aws_region"):
            put(name, "ap-southeast-1")

    for name in [
        "lambda__enable_log_lambda",
        "lambda__enable_aml_lambda",
        "lambda__enable_sftp_transaction_collector",
        "lambda__enable_audit_consumer",
        "lambda__enable_aml_consumer",
        "lambda__enable_verification_lambda",
        "security__enable_audit_pipeline",
        "security__enable_aml_pipeline",
        "security__enable_verification_pipeline",
        "security__enable_sftp_transaction_collector",
        "sqs__enable_audit_pipeline",
        "sqs__enable_aml_pipeline",
        "sns__enable_verification_pipeline",
        "s3__enable_verification_bucket",
        "s3__enable_transaction_sftp_bucket",
        "dynamodb__enable_audit_table",
        "dynamodb__enable_aml_table",
        "ses__enable_ses",
    ]:
        put(name, True)

    for name in [
        "ses__sender_email",
        "lambda__ses_sender_email",
        "sns__notification_email",
        "sns__alarm_notification_email",
    ]:
        put(name, "no-reply@example.com")

    put("lambda__verification_frontend_base_url", "https://example.com")
    put("lambda__log_api_base_url", "https://api.example.com")

    for key, path in artifact_paths.items():
        put(key, path)

    for name, arn in {
        "lambda__log_lambda_role_arn": "arn:aws:iam::123456789012:role/log-lambda",
        "lambda__aml_lambda_role_arn": "arn:aws:iam::123456789012:role/aml-lambda",
        "lambda__sftp_transaction_collector_role_arn": "arn:aws:iam::123456789012:role/sftp-collector",
        "lambda__audit_consumer_role_arn": "arn:aws:iam::123456789012:role/audit-consumer",
        "lambda__aml_consumer_role_arn": "arn:aws:iam::123456789012:role/aml-consumer",
        "lambda__verification_role_arn": "arn:aws:iam::123456789012:role/verification-lambda",
        "lambda__db_username_secret_arn": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:db-user",
        "lambda__db_password_secret_arn": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:db-pass",
        "lambda__jwt_hmac_secret_arn": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:jwt",
        "lambda__verification_jwt_hmac_secret_arn": "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:jwt",
        "lambda__audit_sqs_arn": "arn:aws:sqs:ap-southeast-1:123456789012:audit",
        "lambda__aml_sqs_arn": "arn:aws:sqs:ap-southeast-1:123456789012:aml",
        "lambda__verification_sns_topic_arn": "arn:aws:sns:ap-southeast-1:123456789012:verification",
        "lambda__verification_bucket_arn": "arn:aws:s3:::verification-bucket",
    }.items():
        put(name, arn)

    put("lambda__private_subnet_ids", ["subnet-12345", "subnet-67890"])
    put("lambda__lambda_security_group_id", "sg-12345678")
    put("lambda__db_host", "db.example.internal")
    put("lambda__db_port", 5432)
    put("lambda__db_name", "app")
    put("lambda__audit_dynamodb_table_name", "audit_logs")
    put("lambda__aml_dynamodb_table_name", "aml_reports")
    put("lambda__verification_bucket_id", "verification-bucket")
    put("lambda__transaction_sftp_bucket_id", "transaction-bucket")
    put("lambda__transaction_import_api_url", "https://api.example.com/api/v1/transactions/import")
    put("lambda__aml_sftp_host", "sftp.example.com")
    put("lambda__aml_sftp_port", 22)
    put("lambda__aml_sftp_user", "user")
    put("lambda__aml_sftp_key_secret_arn", "arn:aws:secretsmanager:ap-southeast-1:123456789012:secret:sftp")
    put("lambda__aml_sftp_remote_path", "/drop/aml.csv")
    put("lambda__crm_api_base_url", "https://api.example.com")
    put("lambda__cloudwatch_log_retention_days", 7)

    put("security__vpc_id", "vpc-123456")
    put("security__db_port", 5432)
    put("security__db_username", "postgres")
    put("security__jwt_hmac_secret", "secret")
    put("security__root_admin_password", "ChangeMe123!")

    put("s3__frontend_bucket_name", "brainboard-test-frontend")
    put("s3__verification_bucket_name", "brainboard-test-verification")
    put("s3__transaction_sftp_bucket_name", "brainboard-test-sftp")

    return values


def _run_static_analysis(terraform_dir: Path, tf_file: Path, run_checkov: bool):
    no_aws_env = _neutral_aws_env()
    generated_tfvars = terraform_dir / ".generated-feature-flags.auto.tfvars"
    artifact_paths = {}

    def run_step(step_name: str, fn):
        _log(f"{step_name} started")
        start = time.perf_counter()
        try:
            fn()
            elapsed = time.perf_counter() - start
            _log(f"{step_name} PASS ({elapsed:.2f}s)")
        except Exception:
            elapsed = time.perf_counter() - start
            _log(f"{step_name} FAIL ({elapsed:.2f}s)")
            raise

    def step_0_brainboard_compatibility():
        _run_brainboard_compatibility_checks(tf_file)

    def step_1_fmt_check():
        fmt_result = _run_command(
            ["terraform", "fmt", "-check", "-recursive"],
            cwd=terraform_dir,
            env=no_aws_env,
            allow_failure=True,
        )
        if fmt_result.returncode != 0:
            _log("terraform fmt -check failed; auto-formatting generated files, then re-checking.")
            _run_command(["terraform", "fmt", "-recursive"], cwd=terraform_dir, env=no_aws_env)
            _run_command(["terraform", "fmt", "-check", "-recursive"], cwd=terraform_dir, env=no_aws_env)

    def step_2_clean_cache():
        terraform_cache_dir = terraform_dir / ".terraform"
        if terraform_cache_dir.exists():
            shutil.rmtree(terraform_cache_dir)
            _log(f"Deleted {terraform_cache_dir}")
        else:
            _log("No .terraform cache directory found; skipping delete.")

    def step_3_init():
        _run_command(["terraform", "init", "-backend=false"], cwd=terraform_dir, env=no_aws_env)

    def step_4_validate_baseline():
        if generated_tfvars.exists():
            generated_tfvars.unlink()
        _run_command(["terraform", "validate"], cwd=terraform_dir, env=no_aws_env)

    def step_5_build_artifacts():
        nonlocal artifact_paths
        artifact_paths = _build_operable_lambda_artifacts(terraform_dir)
        _log(f"Created Lambda artifacts in {terraform_dir / '.generated-lambda-artifacts'}")

    def step_6_validate_feature_flags():
        declared_vars = _collect_declared_variables(tf_file)
        feature_values = _feature_flag_values(declared_vars, artifact_paths)
        _write_tfvars(generated_tfvars, feature_values)
        _run_command(["terraform", "validate"], cwd=terraform_dir, env=no_aws_env)
        generated_tfvars.unlink(missing_ok=True)

    def step_7_tflint():
        tflint_exe = shutil.which("tflint")
        if tflint_exe:
            _run_command([tflint_exe, "--init"], cwd=terraform_dir, env=no_aws_env)
            _run_command([tflint_exe, "--format", "compact"], cwd=terraform_dir, env=no_aws_env)
        else:
            _log("tflint not installed; skipping.")

    def step_8_install_checkov():
        _run_command([sys.executable, "-m", "pip", "install", "checkov"], cwd=ROOT)

    def step_9_run_checkov():
        result = _run_command(
            [
                sys.executable,
                "-m",
                "checkov.main",
                "--directory",
                ".",
                "--framework",
                "terraform",
                "--output",
                "cli",
                "--compact",
                "--quiet",
                "--hard-fail-on",
                "CRITICAL,HIGH",
            ],
            cwd=terraform_dir,
            env=no_aws_env,
            allow_failure=True,
        )
        summary_match = re.search(
            r"Passed checks:\s*(\d+),\s*Failed checks:\s*(\d+),\s*Skipped checks:\s*(\d+)",
            result.stdout or "",
        )
        if summary_match:
            passed = int(summary_match.group(1))
            failed = int(summary_match.group(2))
            skipped = int(summary_match.group(3))
            if result.returncode == 0 and failed == 0:
                _log(f"Checkov summary: PASS (passed={passed}, failed={failed}, skipped={skipped})")
            elif result.returncode == 0:
                _log(
                    f"Checkov summary: WARN non-blocking findings (passed={passed}, failed={failed}, skipped={skipped})"
                )
            else:
                _log(
                    f"Checkov summary: FAIL blocking findings (passed={passed}, failed={failed}, skipped={skipped})"
                )
        else:
            if result.returncode == 0:
                _log("Checkov summary: PASS (no parsed summary line).")
            else:
                _log("Checkov summary: FAIL (no parsed summary line).")
        if result.returncode != 0:
            raise RuntimeError("Checkov reported blocking findings (CRITICAL/HIGH).")

    run_step("Step 0: Brainboard compatibility sanity check", step_0_brainboard_compatibility)
    run_step("Step 1: Terraform format check", step_1_fmt_check)
    run_step("Step 2: Clean local Terraform cache", step_2_clean_cache)
    run_step("Step 3: Terraform init (no backend)", step_3_init)
    run_step("Step 4: Terraform validate (baseline)", step_4_validate_baseline)
    run_step("Step 5: Build operable Lambda artifacts", step_5_build_artifacts)
    run_step("Step 6: Terraform validate (feature flags enabled)", step_6_validate_feature_flags)
    run_step("Step 7: TFLint init/run (if installed)", step_7_tflint)

    if run_checkov:
        run_step("Step 8: Install Checkov", step_8_install_checkov)
        run_step("Step 9: Checkov scan", step_9_run_checkov)
    else:
        _log("Step 8/9: Checkov disabled by flag; skipping.")


def main():
    global LOGGER
    parser = argparse.ArgumentParser(
        description="Flatten Terraform modules for Brainboard and run static analysis checks."
    )
    parser.add_argument(
        "--skip-static-analysis",
        action="store_true",
        help="Only generate brainboard-import/brainboard.tf.",
    )
    parser.add_argument(
        "--skip-checkov",
        action="store_true",
        help="Skip Checkov install + scan.",
    )
    parser.add_argument(
        "--profile",
        choices=["prod", "generic"],
        default="prod",
        help="Generation profile. 'prod' uses env/prod.tfvars defaults and root-style module gating.",
    )
    args = parser.parse_args()

    LOGGER = _prepare_build_logger()
    run_start = time.perf_counter()
    pipeline_success = False
    _log(f"Build log file: {LOGGER.path}")

    try:
        global PROFILE_VAR_VALUES
        PROFILE_VAR_VALUES = _build_prod_profile_values() if args.profile == "prod" else {}

        tf_file, changed = generate_brainboard_tf()
        if changed:
            _log(f"Generated {tf_file} [CHANGED]")
        else:
            _log(f"Generated {tf_file} [UNCHANGED]")

        if not args.skip_static_analysis:
            _run_static_analysis(OUT_DIR, tf_file, run_checkov=not args.skip_checkov)
        else:
            _log("Static analysis skipped by flag.")
        pipeline_success = True
    except Exception as exc:
        _log(f"PIPELINE FAILED: {exc}")
        raise
    finally:
        total = time.perf_counter() - run_start
        if pipeline_success:
            _log(f"PIPELINE SUCCESS: completed in {total:.2f}s")
        else:
            _log(f"PIPELINE FAILED: terminated after {total:.2f}s")
        LOGGER.close()


if __name__ == "__main__":
    main()
