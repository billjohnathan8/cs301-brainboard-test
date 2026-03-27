#!/usr/bin/env python3
"""
Delete everything in the repository root except selected directories.

Default keep list:
- brainboard-import/
- tools/
- build-logs/
- .gitignore
- README.md

Safety:
- Always keeps .git/ to avoid corrupting repository metadata.
"""

from __future__ import annotations

import shutil
import stat
from pathlib import Path


KEEP_NAMES = {
    "brainboard-import",
    "tools",
    "build-logs",
    ".git",
    ".gitignore",
    "README.md",
}


def _handle_remove_readonly(func, path, exc_info):
    # Make read-only files writable, then retry the failed delete operation.
    Path(path).chmod(stat.S_IWRITE)
    func(path)


def _delete_path(path: Path) -> None:
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path, onerror=_handle_remove_readonly)
    else:
        path.unlink(missing_ok=True)


def main() -> None:
    repo_root = Path(__file__).resolve().parent.parent
    removed = []
    kept = []

    for entry in repo_root.iterdir():
        if entry.name in KEEP_NAMES:
            kept.append(entry.name)
            continue

        _delete_path(entry)
        removed.append(entry.name)

    print(f"Repository root: {repo_root}")
    print("Kept:")
    for name in sorted(kept):
        print(f"  - {name}")
    print("Removed:")
    for name in sorted(removed):
        print(f"  - {name}")


if __name__ == "__main__":
    main()
