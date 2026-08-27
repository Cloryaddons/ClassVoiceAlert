#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
ADDONS = ROOT / "addons"
DIST = ROOT / "dist"
FIXED_ZIP_TIME = (2026, 1, 1, 0, 0, 0)


def add_file(zf: zipfile.ZipFile, source: Path, arcname: PurePosixPath) -> None:
    data = source.read_bytes()
    info = zipfile.ZipInfo(str(arcname), FIXED_ZIP_TIME)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    zf.writestr(info, data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the installable ClassVoiceAlert suite ZIP.")
    parser.add_argument("--version", help="Expected version; defaults to VERSION")
    args = parser.parse_args()

    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if args.version and args.version != version:
        raise SystemExit(f"Requested version {args.version} does not match VERSION {version}")

    subprocess.run([sys.executable, str(ROOT / "scripts/validate.py")], check=True)

    DIST.mkdir(exist_ok=True)
    out = DIST / f"ClassVoiceAlertSuite-{version}.zip"
    if out.exists():
        out.unlink()

    with zipfile.ZipFile(out, "w") as zf:
        for addon_dir in sorted(p for p in ADDONS.iterdir() if p.is_dir()):
            for source in sorted(p for p in addon_dir.rglob("*") if p.is_file()):
                rel = source.relative_to(ADDONS)
                add_file(zf, source, PurePosixPath(*rel.parts))

    print(out)


if __name__ == "__main__":
    main()
