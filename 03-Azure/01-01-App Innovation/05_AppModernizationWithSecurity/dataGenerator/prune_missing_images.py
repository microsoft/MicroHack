"""Utility script to detect catalog entries whose image files are missing.

Usage (from dataGenerator directory):
  uv run python prune_missing_images.py --check
  uv run python prune_missing_images.py --prune

It reads ../data/catalog.json and ../data/images/*.png
If --prune is specified, it writes a backup catalog.json.bak then rewrites catalog.json without missing-image entries.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from typing import List, Tuple

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
CATALOG_PATH = DATA_DIR / "catalog.json"
IMAGES_DIR = DATA_DIR / "images"


def load_catalog() -> List[dict]:
    with CATALOG_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def find_missing(catalog: List[dict]) -> Tuple[List[dict], List[dict]]:
    existing_files = {p.name for p in IMAGES_DIR.glob("*.png")}
    present = []
    missing = []
    for item in catalog:
        if item.get("filename") in existing_files:
            present.append(item)
        else:
            missing.append(item)
    return present, missing


def prune_catalog(present: List[dict], missing: List[dict]) -> None:
    if not missing:
        print("No missing images. Nothing to prune.")
        return
    backup = CATALOG_PATH.with_suffix(".json.bak")
    if not backup.exists():
        backup.write_text(CATALOG_PATH.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup written: {backup}")
    CATALOG_PATH.write_text(json.dumps(present, indent=2), encoding="utf-8")
    print(f"Pruned catalog written. Removed {len(missing)} entries. New total: {len(present)}")


def main():
    parser = argparse.ArgumentParser(description="Detect and optionally prune catalog entries with missing images.")
    parser.add_argument("--prune", action="store_true", help="Remove entries with missing images from catalog.json (creates backup once).")
    parser.add_argument("--check", action="store_true", help="Only check and list missing (default if neither flag provided).")
    args = parser.parse_args()

    catalog = load_catalog()
    present, missing = find_missing(catalog)
    print(f"Catalog entries: {len(catalog)} | Images present: {len(present)} | Missing images: {len(missing)}")
    if missing:
        print("Missing filenames:")
        for m in missing:
            print(f"  {m['filename']}  (productId={m['productId']})")
    else:
        print("All catalog entries have images.")

    if args.prune:
        prune_catalog(present, missing)
    # If neither --check nor --prune specified, default is just check (already printed)

if __name__ == "__main__":
    main()
