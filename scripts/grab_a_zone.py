#!/usr/bin/env python3
"""Download saved WowWiki zone pages used by the data build."""

from __future__ import annotations

import argparse
import csv
import json
import time
from pathlib import Path

import requests


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CSV = ROOT / "data" / "generated" / "fishing_locations_wowwiki.csv"
DEFAULT_OUT_DIR = ROOT / "data" / "manual" / "zones"
API_URL = "https://wowwiki-archive.fandom.com/api.php"


def grab_zones(args: argparse.Namespace) -> None:
    args.out_dir.mkdir(parents=True, exist_ok=True)
    names = sorted(read_zone_names(args.csv))

    for name in names:
        out_path = args.out_dir / f"{file_name(name)}.out"
        if out_path.exists() and not is_redirect_file(out_path):
            continue

        print(f"Downloading zone page: {name}")
        download_page(name, out_path)
        time.sleep(args.sleep)


def read_zone_names(path: Path) -> set[str]:
    with path.open(encoding="utf-8", newline="") as csv_file:
        return {
            row["zone_name"].strip()
            for row in csv.DictReader(csv_file)
            if row.get("zone_name", "").strip()
        }


def is_redirect_file(path: Path) -> bool:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False

    wikitext = payload.get("parse", {}).get("wikitext", {}).get("*", "")
    return wikitext.lower().startswith("#redirect")


def download_page(page_name: str, out_path: Path) -> None:
    params = {
        "action": "parse",
        "page": page_name,
        "prop": "wikitext",
        "redirects": "1",
        "format": "json",
    }
    print(f"  {API_URL}")

    response = requests.get(API_URL, params=params, timeout=30)
    if response.status_code in (429, 503):
        raise SystemExit("WowWiki asked us to back off; try again later.")
    response.raise_for_status()

    payload = response.json()
    if "error" in payload:
        out_path = out_path.with_name(f"error_{out_path.name}")
        out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        return

    out_path.write_bytes(response.content)


def file_name(value: str) -> str:
    return value.replace(" ", "_")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--sleep", type=float, default=5.0)
    parser.set_defaults(func=grab_zones)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        args.func(args)
    except KeyboardInterrupt:
        return 130
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
