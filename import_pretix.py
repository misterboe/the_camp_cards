#!/usr/bin/env python3
"""
Importiert Teilnehmerdaten aus Pretix-Export in kontakte.csv.

Quellen (erste passende wird verwendet):
1. Neuester CSV-Export _inbox/attendees_*.csv (semicolon, UTF-8 BOM)
2. JSON-Dump _inbox/THECAEMP26_pretixdata.json (Legacy)

- Keine doppelten Imports (Vorname+Nachname)
- Einträge mit 3d_erstellt=true werden übersprungen
- Neue Einträge bekommen 3d_erstellt=false
- Manuelle Einträge (manual=true) werden NIE angefasst (siehe .claude/rules/manual-contacts.md)
- Zusätzliche Spalten (3d_gedruckt etc.) bleiben beim Schreiben erhalten
"""

import csv
import glob
import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CSV_FILE = os.path.join(BASE_DIR, "kontakte.csv")
INBOX_DIR = os.path.join(BASE_DIR, "_inbox")
JSON_FILE = os.path.join(INBOX_DIR, "THECAEMP26_pretixdata.json")
CSV_PATTERN = os.path.join(INBOX_DIR, "attendees_*.csv")

# Minimal-Schema — die echte Spaltenliste wird aus der CSV gelesen, damit
# manuell/durch andere Scripts hinzugefügte Spalten nicht zerstört werden.
REQUIRED_FIELDS = ["Vorname", "Nachname", "Firma", "3d_erstellt", "3d_gedruckt", "manual"]


def load_csv():
    if not os.path.exists(CSV_FILE):
        return [], list(REQUIRED_FIELDS)
    with open(CSV_FILE, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or REQUIRED_FIELDS)
        for req in REQUIRED_FIELDS:
            if req not in fieldnames:
                fieldnames.append(req)
        rows = []
        for row in reader:
            if "3d_erstellt" not in row or row["3d_erstellt"] is None:
                row["3d_erstellt"] = "false"
            rows.append(row)
        return rows, fieldnames


def split_name(full_name):
    parts = full_name.strip().split()
    if len(parts) == 0:
        return "", ""
    if len(parts) == 1:
        return parts[0], ""
    return " ".join(parts[:-1]), parts[-1]


def make_key(vorname, nachname):
    return (vorname.strip().lower(), nachname.strip().lower())


def newest_inbox_csv():
    files = glob.glob(CSV_PATTERN)
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def load_pretix_attendees_csv(path):
    attendees = []
    seen = set()
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f, delimiter=";"):
            vorname = (row.get("Vorname") or "").strip()
            nachname = (row.get("Nachname") or "").strip()
            if not vorname and not nachname:
                continue
            firma = (row.get("Firma") or "").strip()
            key = make_key(vorname, nachname)
            if key in seen:
                continue
            seen.add(key)
            attendees.append({"Vorname": vorname, "Nachname": nachname, "Firma": firma})
    return attendees


def load_pretix_attendees_json(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    attendees = []
    seen = set()

    for order in data["event"]["orders"]:
        if order.get("status") not in ("p", "n"):
            continue
        for pos in order.get("positions", []):
            name = pos.get("attendee_name")
            if not name:
                continue
            vorname, nachname = split_name(name)
            firma = pos.get("company") or ""
            if firma == "None":
                firma = ""
            key = make_key(vorname, nachname)
            if key in seen:
                continue
            seen.add(key)
            attendees.append({"Vorname": vorname, "Nachname": nachname, "Firma": firma})

    return attendees


def load_pretix_attendees():
    """Prefer newest CSV export, fall back to legacy JSON."""
    csv_path = newest_inbox_csv()
    if csv_path:
        print(f"Quelle: {os.path.relpath(csv_path, BASE_DIR)}")
        return load_pretix_attendees_csv(csv_path)
    if os.path.exists(JSON_FILE):
        print(f"Quelle: {os.path.relpath(JSON_FILE, BASE_DIR)}")
        return load_pretix_attendees_json(JSON_FILE)
    raise FileNotFoundError(
        f"Keine Pretix-Quelle gefunden. Erwartet: {CSV_PATTERN} oder {JSON_FILE}"
    )


def main():
    existing, fieldnames = load_csv()

    # Bestehende Einträge indexieren
    existing_keys = {}
    for row in existing:
        key = make_key(row["Vorname"], row["Nachname"])
        existing_keys[key] = row

    pretix = load_pretix_attendees()

    added = 0
    skipped_3d = 0
    skipped_duplicate = 0
    skipped_manual = 0

    for att in pretix:
        key = make_key(att["Vorname"], att["Nachname"])

        if key in existing_keys:
            row = existing_keys[key]
            if row.get("manual", "").strip().lower() == "true":
                skipped_manual += 1
            elif row.get("3d_erstellt", "").strip().lower() == "true":
                skipped_3d += 1
            else:
                skipped_duplicate += 1
            continue

        new_row = {fn: "" for fn in fieldnames}
        new_row.update({
            "Vorname": att["Vorname"],
            "Nachname": att["Nachname"],
            "Firma": att["Firma"],
            "3d_erstellt": "false",
        })
        if "3d_gedruckt" in fieldnames:
            new_row["3d_gedruckt"] = "false"
        if "manual" in fieldnames:
            new_row["manual"] = "false"
        existing.append(new_row)
        existing_keys[key] = existing[-1]
        added += 1

    # CSV schreiben (dynamische Spaltenliste - schützt 3d_gedruckt, manual etc.)
    with open(CSV_FILE, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in existing:
            writer.writerow({fn: row.get(fn, "") for fn in fieldnames})

    print(f"Import abgeschlossen:")
    print(f"  {added} neue Einträge hinzugefügt")
    print(f"  {skipped_duplicate} Duplikate übersprungen")
    print(f"  {skipped_3d} übersprungen (3D bereits erstellt)")
    print(f"  {skipped_manual} manuelle Einträge nicht angefasst")
    print(f"  {len(existing)} Einträge gesamt")


if __name__ == "__main__":
    main()
