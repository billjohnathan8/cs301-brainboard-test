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
    keep_resources = {
        key for key in resource_blocks.keys() if key[0] in CORE_RESOURCE_TYPES
    }
    keep_data = (
        {key for key in data_blocks.keys() if key[0] in OPTIONAL_CORE_DATA_TYPES}
        if include_core_data
        else set()
    )

    if mode == "compatible":
        # Keep small foundational data sources for safer dependency closure.
        keep_data.update(
            key for key in data_blocks.keys() if key[0] in OPTIONAL_CORE_DATA_TYPES
        )

    if mode != "compatible":
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
        choices=["core", "compatible"],
        default="core",
        help=(
            "core: keep only architecture-level types (closest to ~43-node view). "
            "compatible: also keep transitive dependencies for fewer unresolved refs."
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

    blocks_to_remove = []
    for block in blocks:
        key = (block.type_name, block.name)
        if block.kind == "resource" and key not in keep_resources:
            blocks_to_remove.append(block)
        if block.kind == "data" and key not in keep_data:
            blocks_to_remove.append(block)

    output_text = _strip_blocks(source_text, blocks_to_remove)
    out_tf.write_text(output_text, encoding="utf-8")

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

    summary = {
        "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "mode": args.mode,
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
