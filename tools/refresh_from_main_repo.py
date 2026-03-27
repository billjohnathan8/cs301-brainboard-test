#!/usr/bin/env python3
"""
Run the local refresh pipeline:
1) prune
2) copy terraform from main repo
3) brainboard flatten
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TOOLS_DIR = ROOT / "tools"
PRUNE_SCRIPT = TOOLS_DIR / "prune_repo.py"
COPY_SCRIPT = TOOLS_DIR / "copy_main_repo_terraform.py"
FLATTEN_SCRIPT = TOOLS_DIR / "brainboard_flatten.py"
DEFAULT_SOURCE = Path(
    r"C:\code\work\smu-cs301-project\project-2025-26-t2-project-2025-26t2-g2-t3\platform\terraform"
)


def _run(cmd: list[str]) -> None:
    print(f"[run] {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prune this repo, copy terraform from main repo, and generate Brainboard import."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Source terraform directory (default: {DEFAULT_SOURCE})",
    )
    parser.add_argument(
        "--skip-static-analysis",
        action="store_true",
        help="Pass through to brainboard_flatten.py",
    )
    parser.add_argument(
        "--skip-checkov",
        action="store_true",
        help="Pass through to brainboard_flatten.py",
    )
    parser.add_argument(
        "--profile",
        choices=["prod", "generic"],
        default="prod",
        help="Pass through to brainboard_flatten.py",
    )
    args = parser.parse_args()

    python_exe = sys.executable

    _run([python_exe, str(PRUNE_SCRIPT)])
    _run([python_exe, str(COPY_SCRIPT), "--source", str(args.source)])

    flatten_cmd = [python_exe, str(FLATTEN_SCRIPT), "--profile", args.profile]
    if args.skip_static_analysis:
        flatten_cmd.append("--skip-static-analysis")
    if args.skip_checkov:
        flatten_cmd.append("--skip-checkov")
    _run(flatten_cmd)

    print("Pipeline complete.")


if __name__ == "__main__":
    main()
