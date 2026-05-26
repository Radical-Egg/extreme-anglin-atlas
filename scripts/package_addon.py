#!/usr/bin/env python3
"""Create a distributable Tackle Box addon zip."""

from __future__ import annotations

import argparse
import re
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ADDON_DIR = ROOT / "addon"
DEFAULT_OUT_DIR = ROOT / "dist"
PACKAGE_NAME = "TackleBox"
EXCLUDED_SUFFIXES = {".json"}
EXCLUDED_NAMES = {".gitkeep"}


def package_addon(args: argparse.Namespace) -> None:
    toc_path = args.addon_dir / f"{PACKAGE_NAME}.toc"
    if not toc_path.exists():
        raise SystemExit(f"Missing required TOC file: {toc_path}")

    version = read_toc_field(toc_path, "Version") or "0.0.0"
    archive_path = args.out_dir / f"{PACKAGE_NAME}-{version}.zip"
    args.out_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(args.addon_dir.rglob("*")):
            if not path.is_file() or should_exclude(path):
                continue

            relative_path = path.relative_to(args.addon_dir)
            archive.write(path, Path(PACKAGE_NAME) / relative_path)

    print(f"Packaged {archive_path}")


def read_toc_field(path: Path, field_name: str) -> str | None:
    pattern = re.compile(rf"^##\s*{re.escape(field_name)}\s*:\s*(.*?)\s*$", re.IGNORECASE)
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.match(line)
        if match:
            return match.group(1).strip()

    return None


def should_exclude(path: Path) -> bool:
    return path.name in EXCLUDED_NAMES or path.suffix.lower() in EXCLUDED_SUFFIXES


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addon-dir", type=Path, default=DEFAULT_ADDON_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.set_defaults(func=package_addon)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
