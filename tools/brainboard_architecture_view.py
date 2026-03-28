import argparse
import json
import re
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "brainboard-import" / "brainboard.tf"
DEFAULT_OUT_DIR = ROOT / "brainboard-architecture-import"
DEFAULT_OUT_FILE = "brainboard.tf"

# Core services for an architecture-level Brainboard view.
CORE_RESOURCE_TYPES = {
    "aws_apigatewayv2_api",
    "aws_backup_plan",
    "aws_backup_vault",
    "aws_cloudfront_distribution",
    "aws_cloudfront_origin_access_control",
    "aws_cloudtrail",
    "aws_cognito_user_pool",
    "aws_cognito_user_pool_client",
    "aws_db_instance",
    "aws_db_subnet_group",
    "aws_dynamodb_table",
    "aws_ecr_repository",
    "aws_ecs_cluster",
    "aws_ecs_service",
    "aws_internet_gateway",
    "aws_lambda_function",
    "aws_lb",
    "aws_nat_gateway",
    "aws_route53_record",
    "aws_route53_zone",
    "aws_s3_bucket",
    "aws_service_discovery_private_dns_namespace",
    "aws_service_discovery_service",
    "aws_ses_email_identity",
    "aws_sns_topic",
    "aws_sqs_queue",
    "aws_subnet",
    "aws_vpc",
}

# Flow-focused resources that preserve traffic and security relationships.
FLOW_RESOURCE_TYPES = {
    "aws_apigatewayv2_integration",
    "aws_apigatewayv2_route",
    "aws_apigatewayv2_stage",
    "aws_lambda_permission",
    "aws_lb_listener",
    "aws_lb_listener_rule",
    "aws_lb_target_group",
    "aws_route_table",
    "aws_route_table_association",
    "aws_security_group",
}

# Optional data blocks to keep in architecture view when requested.
OPTIONAL_CORE_DATA_TYPES = {
    "aws_availability_zones",
    "aws_caller_identity",
}

BLOCK_START_RE = re.compile(r'(?m)^\s*(resource|data)\s+"([^"]+)"\s+"([^"]+)"\s*{')
RESOURCE_REF_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b")
DATA_REF_RE = re.compile(r"\bdata\.([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b")


@dataclass(frozen=True)
class Block:
    kind: str
    type_name: str
    name: str
    start: int
    end: int
    text: str


def _extract_block(text: str, start_idx: int):
    brace_idx = text.find("{", start_idx)
    if brace_idx == -1:
        return None, start_idx

    depth = 0
    i = brace_idx
    in_str = False
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
            if ch == '"':
                in_str = False
            i += 1
            continue

        if ch == '"':
            in_str = True
            i += 1
            continue

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

        block_text, end = _extract_block(text, m.start())
        if not block_text:
            pos = m.end()
            continue

        blocks.append(
            Block(
                kind=m.group(1),
                type_name=m.group(2),
                name=m.group(3),
                start=m.start(),
                end=end,
                text=block_text,
            )
        )
        pos = end

    return blocks


def _build_maps(blocks):
    resource_blocks = {}
    data_blocks = {}
    for block in blocks:
        key = (block.type_name, block.name)
        if block.kind == "resource":
            resource_blocks[key] = block
        else:
            data_blocks[key] = block
    return resource_blocks, data_blocks


def _build_keep_sets(resource_blocks, data_blocks, mode: str, include_core_data: bool):
    seed_resource_types = set(CORE_RESOURCE_TYPES)
    if mode == "flow":
        seed_resource_types.update(FLOW_RESOURCE_TYPES)

    keep_resources = {
        key for key in resource_blocks.keys() if key[0] in seed_resource_types
    }
    keep_data = (
        {key for key in data_blocks.keys() if key[0] in OPTIONAL_CORE_DATA_TYPES}
        if include_core_data
        else set()
    )

    if mode in {"compatible", "flow"}:
        # Keep small foundational data sources for safer dependency closure.
        keep_data.update(
            key for key in data_blocks.keys() if key[0] in OPTIONAL_CORE_DATA_TYPES
        )

    if mode not in {"compatible", "flow"}:
        return keep_resources, keep_data

    changed = True
    while changed:
        changed = False

        for key in list(keep_resources):
            block = resource_blocks[key]
            for ref_type, ref_name in RESOURCE_REF_RE.findall(block.text):
                ref_key = (ref_type, ref_name)
                if ref_key in resource_blocks and ref_key not in keep_resources:
                    keep_resources.add(ref_key)
                    changed = True
            for ref_type, ref_name in DATA_REF_RE.findall(block.text):
                ref_key = (ref_type, ref_name)
                if ref_key in data_blocks and ref_key not in keep_data:
                    keep_data.add(ref_key)
                    changed = True

        for key in list(keep_data):
            block = data_blocks[key]
            for ref_type, ref_name in DATA_REF_RE.findall(block.text):
                ref_key = (ref_type, ref_name)
                if ref_key in data_blocks and ref_key not in keep_data:
                    keep_data.add(ref_key)
                    changed = True
            for ref_type, ref_name in RESOURCE_REF_RE.findall(block.text):
                ref_key = (ref_type, ref_name)
                if ref_key in resource_blocks and ref_key not in keep_resources:
                    keep_resources.add(ref_key)
                    changed = True

    return keep_resources, keep_data


def _strip_blocks(text: str, blocks_to_remove):
    spans = sorted((block.start, block.end) for block in blocks_to_remove)
    output_parts = []
    pos = 0

    for start, end in spans:
        output_parts.append(text[pos:start])
        pos = end
        if pos < len(text) and text[pos] == "\n":
            pos += 1
    output_parts.append(text[pos:])

    # Keep file readable after large block removal.
    return re.sub(r"\n{3,}", "\n\n", "".join(output_parts)).rstrip() + "\n"


def _find_unresolved_references(text: str, removed_resources, removed_data):
    unresolved = []

    for type_name, name in sorted(removed_resources):
        pattern = re.compile(rf"\b{re.escape(type_name)}\.{re.escape(name)}\b")
        count = len(pattern.findall(text))
        if count:
            unresolved.append((count, f"{type_name}.{name}"))

    for type_name, name in sorted(removed_data):
        pattern = re.compile(
            rf"\bdata\.{re.escape(type_name)}\.{re.escape(name)}\b"
        )
        count = len(pattern.findall(text))
        if count:
            unresolved.append((count, f"data.{type_name}.{name}"))

    unresolved.sort(reverse=True)
    return unresolved


def _ensure_variable_block(text: str, variable_name: str, block_text: str):
    if re.search(rf'(?m)^\s*variable\s+"{re.escape(variable_name)}"\s*{{', text):
        return text
    return text.rstrip() + "\n\n" + block_text.strip() + "\n"


def _strip_route53_multivalue_flags_for_architecture_import(text: str):
    routing_policy_re = re.compile(
        r"(?m)^\s*(cidr_routing_policy|failover_routing_policy|geolocation_routing_policy|geoproximity_routing_policy|latency_routing_policy|weighted_routing_policy)\b"
    )
    blocks = _collect_blocks(text)
    for block in reversed(blocks):
        if block.kind != "resource" or block.type_name != "aws_route53_record":
            continue

        has_routing_policy = routing_policy_re.search(block.text) is not None
        has_set_identifier = (
            re.search(r"(?m)^\s*set_identifier\s*=", block.text) is not None
        )
        has_multivalue = (
            re.search(r"(?m)^\s*multivalue_answer_routing_policy\s*=", block.text)
            is not None
        )

        new_block_text = block.text

        # Brainboard often treats multivalue flags inconsistently for architecture
        # imports, so strip it from generated architecture files.
        if has_multivalue:
            new_block_text = re.sub(
                r"(?m)^\s*multivalue_answer_routing_policy\s*=.*\n",
                "",
                new_block_text,
            )

        # If any routing policy exists, guarantee set_identifier to satisfy
        # provider validation even when Brainboard injects latency policy.
        if has_routing_policy and not has_set_identifier:
            indent_match = re.search(
                r'(?m)^(\s*)resource\s+"aws_route53_record"\s+"[^"]+"\s*{',
                new_block_text,
            )
            if not indent_match:
                continue

            indent = indent_match.group(1) + "  "
            if re.search(r"(?m)^\s*for_each\s*=", new_block_text):
                set_identifier_expr = f'try(tostring(each.key), "{block.name}")'
            elif re.search(r"(?m)^\s*count\s*=", new_block_text):
                set_identifier_expr = f'"{block.name}-${{count.index}}"'
            else:
                set_identifier_expr = f'"{block.name}"'

            lines = new_block_text.rstrip().splitlines()
            insert_idx = len(lines) - 1
            for idx, line in enumerate(lines):
                if re.match(r"^\s*type\s*=", line):
                    insert_idx = idx + 1
                    break
            lines.insert(insert_idx, f"{indent}set_identifier = {set_identifier_expr}")
            new_block_text = "\n".join(lines)

        # Brainboard may drop dynamic expressions like `${count.index}` during
        # architecture import. Keep a static identifier so downstream validate
        # still has set_identifier when latency policy appears.
        new_block_text = re.sub(
            r"(?m)^(\s*)set_identifier\s*=.*$",
            rf'\1set_identifier = "{block.name}"',
            new_block_text,
        )

        if new_block_text == block.text:
            continue

        text = text[: block.start] + new_block_text + text[block.end :]
    return text


def _normalize_route_table_association_for_each(text: str):
    blocks = _collect_blocks(text)
    for block in reversed(blocks):
        if block.kind != "resource" or block.type_name != "aws_route_table_association":
            continue

        match = re.search(
            r"(?m)^(\s*)for_each\s*=\s*(aws_subnet\.[A-Za-z0-9_]+)\s*$", block.text
        )
        if not match:
            continue

        indent = match.group(1)
        subnet_ref = match.group(2)
        replacement = (
            f"{indent}for_each = {{ for k, subnet in {subnet_ref} : k => subnet.id }}"
        )
        new_block_text = (
            block.text[: match.start()] + replacement + block.text[match.end() :]
        )
        new_block_text = re.sub(
            r"(?m)^(\s*subnet_id\s*=\s*)each\.value\.id\s*$",
            r"\1each.value",
            new_block_text,
        )

        if new_block_text == block.text:
            continue

        text = text[: block.start] + new_block_text + text[block.end :]
    return text


def _drop_route53_records_for_architecture_import(text: str):
    # Brainboard architecture import currently mutates Route53 record routing
    # fields (notably latency policy/set_identifier), causing validate failures.
    # Keep DNS records in full import, but drop them from architecture view.
    blocks = _collect_blocks(text)
    for block in reversed(blocks):
        if block.kind == "resource" and block.type_name == "aws_route53_record":
            text = text[: block.start] + text[block.end :]
    return re.sub(r"\n{3,}", "\n\n", text).rstrip() + "\n"


def _apply_brainboard_compatibility_patches(text: str, removed_resources):
    # Brainboard architecture preflight may not model these dependency resources
    # as architecture nodes. Route those links via explicit variables so import
    # does not fail even when helper resources are omitted in the visual graph.
    replacement_specs = [
        {
            "remove_if_missing": ("aws_ecs_task_definition", "ecs__service"),
            "old": "task_definition                    = aws_ecs_task_definition.ecs__service[each.key].arn",
            "new": 'task_definition                    = lookup(var.ecs__task_definition_arns, each.key, "arn:aws:ecs:${var.ecs__aws_region}:000000000000:task-definition/${var.ecs__name_prefix}-${each.key}:1")',
            "fallback_var": (
                "ecs__task_definition_arns",
                """
variable "ecs__task_definition_arns" {
  type    = any
  default = {}
}
                """,
            ),
        },
        {
            "remove_if_missing": ("aws_eip", "network__nat"),
            "old": "allocation_id = aws_eip.network__nat[count.index].id",
            "new": 'allocation_id = element(concat(var.network__nat_eip_allocation_ids, ["eipalloc-00000000000000000"]), count.index)',
            "fallback_var": (
                "network__nat_eip_allocation_ids",
                """
variable "network__nat_eip_allocation_ids" {
  type    = any
  default = []
}
                """,
            ),
        },
        {
            "remove_if_missing": ("aws_kms_key", "rds__rds"),
            "old": "kms_key_id                 = aws_kms_key.rds__rds.arn",
            "new": "kms_key_id                 = var.rds__kms_key_arn",
            "fallback_var": (
                "rds__kms_key_arn",
                """
variable "rds__kms_key_arn" {
  type    = any
  default = "arn:aws:kms:ap-southeast-1:000000000000:key/00000000-0000-0000-0000-000000000000"
}
                """,
            ),
        },
        {
            "remove_if_missing": ("aws_db_parameter_group", "rds__postgres"),
            "old": "parameter_group_name       = aws_db_parameter_group.rds__postgres.name",
            "new": "parameter_group_name       = var.rds__db_parameter_group_name",
            "fallback_var": (
                "rds__db_parameter_group_name",
                """
variable "rds__db_parameter_group_name" {
  type    = any
  default = "default.postgres14"
}
                """,
            ),
        },
        {
            "remove_if_missing": ("aws_kms_key", "rds__rds"),
            "old": "performance_insights_kms_key_id       = var.rds__performance_insights_enabled ? aws_kms_key.rds__rds.arn : null",
            "new": "performance_insights_kms_key_id       = var.rds__performance_insights_enabled ? var.rds__kms_key_arn : null",
            "fallback_var": (
                "rds__kms_key_arn",
                """
variable "rds__kms_key_arn" {
  type    = any
  default = "arn:aws:kms:ap-southeast-1:000000000000:key/00000000-0000-0000-0000-000000000000"
}
                """,
            ),
        },
        {
            "remove_if_missing": ("aws_secretsmanager_secret", "security__root_admin_password"),
            "old": "valueFrom = ((aws_secretsmanager_secret.security__root_admin_password.arn))",
            "new": "valueFrom = var.ecs__root_admin_password_secret_arn",
        },
    ]
    fallback_vars_to_add = {}

    for spec in replacement_specs:
        if spec["remove_if_missing"] not in removed_resources:
            continue
        if spec["old"] not in text:
            continue
        text = text.replace(spec["old"], spec["new"])
        fallback_var = spec.get("fallback_var")
        if fallback_var:
            fallback_var_name, fallback_block = fallback_var
            fallback_vars_to_add[fallback_var_name] = fallback_block

    # For architecture import, keep simple alias Route53 records free of
    # multivalue/set_identifier flags while preserving explicit routing-policy
    # records (latency/weighted/etc.) that require set_identifier.
    text = _strip_route53_multivalue_flags_for_architecture_import(text)

    # Brainboard architecture validate is currently unstable for Route53 records.
    # Use a DNS-node-free architecture artifact to keep import/validate reliable.
    text = _drop_route53_records_for_architecture_import(text)

    # Brainboard may flag for_each references that point at whole subnet objects.
    # Rewrite to an id-map expression without changing association behavior.
    text = _normalize_route_table_association_for_each(text)

    for variable_name in sorted(fallback_vars_to_add):
        text = _ensure_variable_block(text, variable_name, fallback_vars_to_add[variable_name])
    return text


def _copy_if_exists(src: Path, dest: Path):
    if src.exists():
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
        return True
    return False


def _copy_dir_if_exists(src: Path, dest: Path):
    if src.exists() and src.is_dir():
        shutil.copytree(src, dest, dirs_exist_ok=True)
        return True
    return False


def _write_summary(path: Path, payload: dict):
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Generate a decluttered Brainboard Terraform import directory from "
            "brainboard-import/brainboard.tf."
        )
    )
    parser.add_argument(
        "--source",
        default=str(DEFAULT_SOURCE),
        help="Source flattened Terraform file (default: brainboard-import/brainboard.tf).",
    )
    parser.add_argument(
        "--out-dir",
        default=str(DEFAULT_OUT_DIR),
        help="Output directory for architecture view import files.",
    )
    parser.add_argument(
        "--out-file",
        default=DEFAULT_OUT_FILE,
        help="Output Terraform filename under --out-dir.",
    )
    parser.add_argument(
        "--mode",
        choices=["core", "compatible", "flow"],
        default="flow",
        help=(
            "flow: include additional traffic-path and security relationship resources "
            "(recommended default). "
            "compatible: keep transitive dependencies with a smaller node set. "
            "core: keep only architecture-level types (closest to ~43-node view)."
        ),
    )
    parser.add_argument(
        "--include-core-data",
        action="store_true",
        help=(
            "In core mode, keep aws_caller_identity/aws_availability_zones data blocks. "
            "Default is off to target the 43-resource view."
        ),
    )
    parser.add_argument(
        "--allow-unresolved",
        action="store_true",
        help=(
            "Keep unresolved references in output (legacy core-mode behavior). "
            "By default, core mode auto-falls back to dependency-compatible output "
            "when unresolved references are detected."
        ),
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Delete --out-dir before writing fresh outputs.",
    )
    parser.add_argument(
        "--skip-copy-artifacts",
        action="store_true",
        help="Do not copy .terraform.lock.hcl or .generated-lambda-artifacts.",
    )
    args = parser.parse_args()

    source = Path(args.source).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_tf = out_dir / args.out_file

    if not source.exists():
        raise SystemExit(
            f"Source Terraform file not found: {source}\n"
            "Run the master flatten pipeline first."
        )

    if args.clean and out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    source_text = source.read_text(encoding="utf-8")
    blocks = _collect_blocks(source_text)
    resource_blocks, data_blocks = _build_maps(blocks)
    keep_resources, keep_data = _build_keep_sets(
        resource_blocks,
        data_blocks,
        mode=args.mode,
        include_core_data=args.include_core_data,
    )
    effective_mode = args.mode

    def build_output_text(selected_resources, selected_data):
        blocks_to_remove = []
        for block in blocks:
            key = (block.type_name, block.name)
            if block.kind == "resource" and key not in selected_resources:
                blocks_to_remove.append(block)
            if block.kind == "data" and key not in selected_data:
                blocks_to_remove.append(block)
        removed_resources = set(resource_blocks.keys()) - selected_resources
        return _apply_brainboard_compatibility_patches(
            _strip_blocks(source_text, blocks_to_remove),
            removed_resources=removed_resources,
        )

    output_text = build_output_text(keep_resources, keep_data)

    copied_files = []
    if not args.skip_copy_artifacts:
        src_dir = source.parent
        lock_src = src_dir / ".terraform.lock.hcl"
        lock_dest = out_dir / ".terraform.lock.hcl"
        if _copy_if_exists(lock_src, lock_dest):
            copied_files.append(lock_dest.name)

        artifacts_src = src_dir / ".generated-lambda-artifacts"
        artifacts_dest = out_dir / ".generated-lambda-artifacts"
        if _copy_dir_if_exists(artifacts_src, artifacts_dest):
            copied_files.append(artifacts_dest.name + "/")

    removed_resources = set(resource_blocks.keys()) - keep_resources
    removed_data = set(data_blocks.keys()) - keep_data
    unresolved = _find_unresolved_references(output_text, removed_resources, removed_data)
    compatibility_fallback_applied = False

    if unresolved and args.mode == "core" and not args.allow_unresolved:
        keep_resources, keep_data = _build_keep_sets(
            resource_blocks,
            data_blocks,
            mode="compatible",
            include_core_data=args.include_core_data,
        )
        output_text = build_output_text(keep_resources, keep_data)
        removed_resources = set(resource_blocks.keys()) - keep_resources
        removed_data = set(data_blocks.keys()) - keep_data
        unresolved = _find_unresolved_references(output_text, removed_resources, removed_data)
        effective_mode = "compatible"
        compatibility_fallback_applied = True

    out_tf.write_text(output_text, encoding="utf-8")

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": effective_mode,
        "requested_mode": args.mode,
        "compatibility_fallback_applied": compatibility_fallback_applied,
        "source": str(source),
        "output_file": str(out_tf),
        "resource_count_in_source": len(resource_blocks),
        "data_count_in_source": len(data_blocks),
        "resource_count_kept": len(keep_resources),
        "data_count_kept": len(keep_data),
        "estimated_brainboard_nodes": len(keep_resources) + len(keep_data),
        "resource_count_removed": len(removed_resources),
        "data_count_removed": len(removed_data),
        "copied_artifacts": copied_files,
        "unresolved_reference_count": sum(count for count, _ in unresolved),
        "unresolved_reference_entries": [
            {"count": count, "address": address} for count, address in unresolved
        ],
    }
    summary_path = out_dir / "view-summary.json"
    _write_summary(summary_path, summary)

    print(f"Generated architecture view Terraform: {out_tf}")
    print(
        f"Kept resources={summary['resource_count_kept']} "
        f"data={summary['data_count_kept']} "
        f"estimated_nodes={summary['estimated_brainboard_nodes']}"
    )
    if compatibility_fallback_applied:
        print(
            "Core mode produced unresolved references; "
            "auto-switched to dependency-compatible output."
        )
    if unresolved:
        print(
            f"Warning: unresolved references remain in {args.mode} view."
        )
        for count, address in unresolved[:12]:
            print(f"  {count:>3}  {address}")
    else:
        print("No unresolved references detected.")
    print(f"Summary report: {summary_path}")


if __name__ == "__main__":
    main()
