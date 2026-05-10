#!/usr/bin/env python3
"""Sync 3d_gedruckt column in kontakte.csv from Finder green tags on export/*.3mf.

Finder tag "Grün" on export/{Vorname}_{Nachname}.3mf  =>  3d_gedruckt=true
(Filename sanitization mirrors export_badges.sh: non-[A-Za-z0-9_-] -> _)

Reads tags via the com.apple.metadata:_kMDItemUserTags xattr (bplist) directly,
so it works even when Spotlight is not indexing the volume.
"""
import csv
import plistlib
import re
import subprocess
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CSV_FILE = ROOT / "kontakte.csv"
EXPORT_DIR = ROOT / "export"
COL = "3d_gedruckt"
TAG_XATTR = "com.apple.metadata:_kMDItemUserTags"


def safe_name(vorname: str, nachname: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]", "_", f"{vorname}_{nachname}")


def is_green(path: Path) -> bool:
    if not path.exists():
        return False
    try:
        hex_data = subprocess.run(
            ["xattr", "-px", TAG_XATTR, str(path)],
            capture_output=True, text=True, check=True,
        ).stdout
    except subprocess.CalledProcessError:
        return False
    try:
        raw = bytes.fromhex(hex_data.replace(" ", "").replace("\n", ""))
        tags = plistlib.loads(raw)
    except Exception:
        return False
    # Each tag entry is "Name\nColorCode" (color 2 = green); name is NFD on macOS.
    for entry in tags or []:
        name = unicodedata.normalize("NFC", entry.split("\n", 1)[0])
        if name == "Grün":
            return True
    return False


def main() -> None:
    with CSV_FILE.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        rows = list(reader)

    if COL not in fieldnames:
        fieldnames.append(COL)

    changed = 0
    for row in rows:
        badge = EXPORT_DIR / f"{safe_name(row['Vorname'], row['Nachname'])}.3mf"
        new_val = "true" if is_green(badge) else "false"
        if row.get(COL) != new_val:
            row[COL] = new_val
            changed += 1

    with CSV_FILE.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Synced {COL}: {changed} row(s) changed, {sum(1 for r in rows if r.get(COL) == 'true')}/{len(rows)} printed.")


if __name__ == "__main__":
    main()
