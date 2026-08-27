#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION_FILE = ROOT / "VERSION"
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def replace_one(path: Path, pattern: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    new, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Could not update expected version field in {path}")
    path.write_text(new, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Synchronize the ClassVoiceAlert suite version.")
    parser.add_argument("version", help="Semantic version without v prefix, e.g. 0.1.1")
    args = parser.parse_args()

    version = args.version.strip()
    if not SEMVER.fullmatch(version):
        raise SystemExit("Version must match X.Y.Z, e.g. 0.1.1")

    VERSION_FILE.write_text(version + "\n", encoding="utf-8")

    for toc in sorted((ROOT / "addons").glob("*/*.toc")):
        replace_one(toc, r"^## Version: .+$", f"## Version: {version}")

    replace_one(
        ROOT / "addons/ClassVoiceAlertToolbox/Root.lua",
        r'^local ROOT_VERSION = "[^"]+"$',
        f'local ROOT_VERSION = "{version}"',
    )
    replace_one(
        ROOT / "addons/ClassVoiceAlertToolbox_Core/Init.lua",
        r'^CVA\.VERSION = "[^"]+"$',
        f'CVA.VERSION = "{version}"',
    )

    print(f"Synchronized ClassVoiceAlert version to {version}")


if __name__ == "__main__":
    main()
