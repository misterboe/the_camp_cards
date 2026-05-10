---
description: Never delete or overwrite rows with manual=true in kontakte.csv — they are last-minute additions that don't exist in the Pretix export.
paths:
  - kontakte.csv
  - import_pretix.py
---

# Manuelle Einträge schützen (manual=true)

Die Spalte `manual` in `kontakte.csv` markiert Einträge, die **nicht aus Pretix** stammen — typischerweise kurzfristige Ersatzteilnehmer, die der User von Hand einträgt.

## Regel

**Einträge mit `manual=true` NIE löschen, nicht durch Pretix-Daten überschreiben, nicht bei einem Re-Import verlieren.**

- `import_pretix.py` respektiert das bereits (siehe `skipped_manual` im Output)
- Andere Scripts/Cleanups, die CSV-Zeilen entfernen, müssen `manual=true` ausfiltern
- Beim Hinzufügen neuer Spalten / bei CSV-Migrationen: Spalte `manual` immer beibehalten

## Wann wird `manual=true` gesetzt

Der User sagt Dinge wie „bitte manuell ergänzen", „kommt kurzfristig dazu", „ersetzt XY" — dann:
1. Neue Zeile mit `manual=true`, `3d_erstellt=false`, `3d_gedruckt=false` anlegen
2. Den ersetzten Eintrag **nicht löschen** (Badge könnte schon gedruckt sein, Korrektur wäre teurer als ein überschüssiger Badge)

## Warum kein hardcoded FIELDNAMES mehr

`import_pretix.py` hatte früher eine hardcoded Spaltenliste — dadurch hätte ein Re-Import die Spalten `3d_gedruckt` und `manual` gelöscht. Fieldnames werden jetzt aus der CSV selbst gelesen, damit zusätzliche Spalten automatisch überleben.
