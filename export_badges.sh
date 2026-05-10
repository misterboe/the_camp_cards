#!/bin/bash
# Batch-Export für THE CÄMP Badges
# - Exportiert nur Einträge mit 3d_erstellt != true
# - Setzt 3d_erstellt=true sofort nach jedem erfolgreichen Export
# - Max 2 parallele OpenSCAD-Prozesse

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCAD_FILE="$SCRIPT_DIR/openscad/the_camp_card.scad"
OUTPUT_DIR="$SCRIPT_DIR/export"
CSV_FILE="$SCRIPT_DIR/kontakte.csv"
MAX_JOBS=2

mkdir -p "$OUTPUT_DIR"

# CSV mit Python lesen (sicher bei Sonderzeichen/Kommas)
# Nur Einträge mit 3d_erstellt != true
ENTRIES=$(python3 -c "
import csv
with open('$CSV_FILE', 'r', encoding='utf-8') as f:
    for row in csv.DictReader(f):
        if row.get('3d_erstellt', '').strip().lower() == 'true':
            continue
        print(row['Vorname'] + '\t' + row['Nachname'] + '\t' + row.get('Firma', ''))
")

if [ -z "$ENTRIES" ]; then
    echo "Keine neuen Badges zu exportieren."
    exit 0
fi

# Lock für parallele CSV-Zugriffe
LOCK_DIR="/tmp/export_badges_csv_lock"
rmdir "$LOCK_DIR" 2>/dev/null

# Hilfsfunktion: 3d_erstellt=true für einen Eintrag setzen (mit Lock)
mark_done() {
    local vn="$1"
    local nn="$2"
    # Lock holen
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        sleep 0.1
    done
    python3 -c "
import csv
rows = []
with open('$CSV_FILE', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    fn = reader.fieldnames
    for row in reader:
        if row['Vorname'] == '''$vn''' and row['Nachname'] == '''$nn''':
            row['3d_erstellt'] = 'true'
        rows.append(row)
with open('$CSV_FILE', 'w', encoding='utf-8', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fn)
    writer.writeheader()
    writer.writerows(rows)
"
    # Lock freigeben
    rmdir "$LOCK_DIR"
}

# Wrapper: OpenSCAD exportieren, bei Erfolg CSV aktualisieren
export_badge() {
    local vorname="$1"
    local nachname="$2"
    local firma="$3"
    local output_file="$4"

    /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD \
        -o "$output_file" \
        -D "vorname=\"$vorname\"" \
        -D "nachname=\"$nachname\"" \
        -D "firma=\"$firma\"" \
        "$SCAD_FILE" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "$output_file" ]; then
        mark_done "$vorname" "$nachname"
        echo "Fertig: $vorname $nachname -> $output_file"
    else
        echo "FEHLER: $vorname $nachname"
    fi
}

started=0

while IFS=$'\t' read -r vorname nachname firma; do
    safe_name=$(echo "${vorname}_${nachname}" | sed 's/[^a-zA-Z0-9_-]/_/g')
    output_file="$OUTPUT_DIR/${safe_name}.3mf"

    # Warten bis weniger als MAX_JOBS laufen
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do
        sleep 1
    done

    echo "Starte: $vorname $nachname ($firma)"
    started=$((started + 1))

    export_badge "$vorname" "$nachname" "$firma" "$output_file" &

done <<< "$ENTRIES"

# Auf restliche Hintergrundprozesse warten
if [ $started -gt 0 ]; then
    echo "Warte auf letzte Export(s)..."
    wait
fi

echo "Fertig! $started Badge(s) verarbeitet."
