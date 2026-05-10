---
description: Before changing kontakte.csv or the 3D-print workflow, sync the 3d_gedruckt column from Finder green tags on export/*.3mf files.
paths:
  - kontakte.csv
  - export/**
  - export_badges.sh
  - import_pretix.py
  - sync_3d_gedruckt.py
---

# Finder-Tag "Grün" = 3D gedruckt

Der User markiert fertig gedruckte Badges im macOS Finder mit dem **grünen Tag**.
Diese Information wird in `kontakte.csv` in der Spalte `3d_gedruckt` gespiegelt.

## CSV-Schema (kontakte.csv)

```
Vorname,Nachname,Firma,3d_erstellt,3d_gedruckt
```

- `3d_erstellt` — 3MF-Datei wurde via `export_badges.sh` generiert (automatisch gesetzt)
- `3d_gedruckt` — Badge wurde tatsächlich gedruckt (aus Finder-Grün-Tag gesynct)

## Regel

**Vor jeder Änderung an `kontakte.csv` oder am Druck-/Export-Workflow** das Sync-Script laufen lassen:

```bash
python3 sync_3d_gedruckt.py
```

Das Script liest die Finder-Tags (`kMDItemUserTags`) aller `export/*.3mf`, mappt sie per Dateiname auf die CSV-Zeilen und aktualisiert `3d_gedruckt` (`true` = grüner Tag vorhanden, sonst `false`).

## Warum

Die Finder-Tags sind die **Ground Truth** für den Druckstatus — der User pflegt sie manuell beim Einsortieren der fertig gedruckten Badges. Git trackt extended attributes **nicht**, also muss der Druckstatus in die CSV übertragen werden, damit er versioniert und für Reports/Queries nutzbar ist.

## Wann syncen

- Bevor neue Einträge in `kontakte.csv` importiert werden
- Bevor `export_badges.sh` läuft (stellt sicher, dass der aktuelle Druckstatus committed wird)
- Vor jedem Commit, der `kontakte.csv` berührt
- Wenn der User fragt „was ist schon gedruckt?" oder ähnliches

## Technisch

- Filename-Mapping spiegelt `export_badges.sh`: `{Vorname}_{Nachname}` mit allen non-`[A-Za-z0-9_-]` → `_`
- Tag-Check via `mdls -raw -name kMDItemUserTags <datei>`; „Grün" kommt als NFD („Gr" + U+0308 + „n") zurück
- Script ist idempotent — mehrfaches Ausführen ist sicher
