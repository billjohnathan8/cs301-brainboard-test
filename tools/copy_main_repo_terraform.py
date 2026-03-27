#!/usr/bin/env python3
"""
Copy all contents from a source Terraform directory into this repository root.

This script only reads from the source directory and writes into the current
repository. It never writes to the source repository.
"""

from __future__ import annotations

import argparse
import os
import shutil
import stat
from pathlib import Path


DEFAULT_SOURCE = Path(
    r"C:\code\work\smu-cs301-project\project-2025-26-t2-project-2025-26t2-g2-t3\platform\terraform"
)
REPO_ROOT = Path(__file__).resolve().parent.parent


def _make_writable(path: Path) -> None:
    if path.exists():
        path.chmod(stat.S_IWRITE | stat.S_IREAD)


def _remove_path(path: Path) -> None:
    if not path.exists():
        return
    if path.is_dir() and not path.is_symlink():
        def onerror(func, target, _exc_info):
            target_path = Path(target)
            _make_writable(target_path)
            func(target)

        shutil.rmtree(path, onerror=onerror)
        return
    _make_writable(path)
    path.unlink(missing_ok=True)


def _assert_paths(source: Path, destination: Path) -> None:
    source_resolved = source.resolve()
    destination_resolved = destination.resolve()
    if not source_resolved.exists() or not source_resolved.is_dir():
        raise SystemExit(f"Source directory does not exist: {source_resolved}")
    if source_resolved == destination_resolved:
        raise SystemExit("Source and destination cannot be the same directory.")


def copy_tree(source: Path, destination: Path) -> tuple[int, int]:
    copied_files = 0
    created_dirs = 0

    for root, dirs, files in os.walk(source):
        root_path = Path(root)
        rel_root = root_path.relative_to(source)

        dirs[:] = [d for d in dirs if d != ".git"]

        target_root = destination / rel_root
        if not target_root.exists():
            target_root.mkdir(parents=True, exist_ok=True)
            created_dirs += 1
        elif target_root.is_file():
            _remove_path(target_root)
            target_root.mkdir(parents=True, exist_ok=True)
            created_dirs += 1

        for filename in files:
            source_file = root_path / filename
            rel_file = source_file.relative_to(source)
            if ".git" in rel_file.parts:
                continue

            target_file = destination / rel_file
            if target_file.exists() and target_file.is_dir():
                _remove_path(target_file)
            target_file.parent.mkdir(parents=True, exist_ok=True)
            if target_file.exists():
                _make_writable(target_file)
            shutil.copy2(source_file, target_file)
            copied_files += 1

    return copied_files, created_dirs


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Copy platform/terraform contents from a source repository into this repository."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Source terraform directory (default: {DEFAULT_SOURCE})",
    )
    args = parser.parse_args()

    source_dir = args.source
    destination_dir = REPO_ROOT

    _assert_paths(source_dir, destination_dir)
    files, dirs = copy_tree(source_dir, destination_dir)

    print(f"Source      : {source_dir.resolve()}")
    print(f"Destination : {destination_dir.resolve()}")
    print(f"Copied files: {files}")
    print(f"Created dirs: {dirs}")


if __name__ == "__main__":
    main()
