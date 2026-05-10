# THE CÄMP Badge Pipeline

Generiert personalisierte 3D-druckbare Konferenz-Badges (100×60 mm, 3MF) aus Pretix-Teilnehmerdaten. Druck auf Bambulab P1S/X1 via Bambu Studio.

## Workflow für eine neue Druck-Charge

1. **Pretix-Export ablegen**
   Den frischen CSV-Export aus Pretix als `_inbox/attendees_*.csv` ablegen (Semikolon-getrennt, UTF-8 BOM — Pretix-Default).

2. **Claude Bescheid geben**
   Im Prompt sagen, dass eine neue CSV in der Inbox liegt. Claude führt dann `python3 import_pretix.py` aus und meldet, wie viele neue Einträge dazugekommen sind.

3. **Auf Aufforderung warten**
   Claude fordert dich auf, den Export selbst zu starten (siehe `.claude/`-Regel — Claude soll das Skript bewusst nicht selbst anwerfen).

4. **Badges rendern**
   ```bash
   sh export_badges.sh
   ```
   Erzeugt für jeden Eintrag mit `3d_erstellt=false` eine `export/{Vorname}_{Nachname}.3mf` (max. 2 parallele OpenSCAD-Prozesse) und setzt `3d_erstellt=true` in `kontakte.csv`.

5. **Bambu-Studio-Vorlage öffnen**
   `bambustudio/bambulab_template.3mf` in Bambu Studio öffnen. In der Vorlage sind bereits korrekt platzierte Karten **inklusive Filament-Change-Layer** konfiguriert.

6. **Neue Karten als Geometrie importieren**
   Bis zu **6 neue** `export/*.3mf` als „Objekt importieren" hinzufügen.

   **WICHTIG:** Vor dem Import muss **mindestens eine alte Karte aus der Vorlage erhalten bleiben**, sonst räumt Bambu Studio die Filament-Change-Einstellungen ab. Erst importieren, dann die zuletzt schon gedruckte Karte löschen.

7. **Mehr als 6 Karten gleichzeitig vermeiden**
   Bei mehr als 6 Karten auf dem Druckbett wird das Ergebnis am äußeren Rand unsauber — die geringe Druckhöhe sorgt dort für sichtbare Mängel. 6 Karten pro Druck ist das stabile Maximum.

8. **Drucken**
   Plate slicen, drucken.

9. **Fertige Badges markieren**
   Gedruckte Badges im Finder mit dem **grünen Tag** versehen. Beim nächsten Lauf spiegelt `python3 sync_3d_gedruckt.py` das in die Spalte `3d_gedruckt`.

## Technische Details

### Badge-Geometrie

- 100 × 60 mm, 1,4 mm dick, abgerundete Ecken (r=6 mm)
- Lanyard-Loch oben rechts (Ø 8 mm, 6 mm vom Rand)
- BaWü-Gelb (`#FFFC00`) als Basis, BaWü-Schwarz (`#2A2623`) für Text/Logo
- Text/Logo als 0,4 mm hohes Embossing → Filament-Change auf Schwarz beim Druck
- Font **Onest** (Google Fonts) muss systemweit installiert sein — sonst rendert OpenSCAD die Texte mit Fallback-Schrift

### CSV-Schema (`kontakte.csv`)

```
Vorname,Nachname,Firma,3d_erstellt,3d_gedruckt,manual
```

- `3d_erstellt` — 3MF wurde von `export_badges.sh` generiert (automatisch)
- `3d_gedruckt` — Badge wurde gedruckt (von `sync_3d_gedruckt.py` aus Finder-Tag „Grün" gesynct)
- `manual=true` — Eintrag wurde von Hand ergänzt (nicht aus Pretix); wird beim Re-Import nie überschrieben

Single source of truth. Wird beim ersten Import automatisch aus dem Pretix-Export angelegt.

### Firma-Umbruch im Badge

Mehrzeilige Firmen-Strings funktionieren:

- **Automatischer Wrap** bei Wortgrenzen, sobald die Zeile länger als `firma_max_chars` (Default 20) wird
- **Erzwungener Umbruch** mit `|` (Pipe) im Firma-Namen — das Pipe-Zeichen wird nicht gerendert, bricht aber die Zeile

Beispiel: `Demo|Studios AG` → zwei Zeilen, `Demo` / `Studios AG`.

### Pipeline-Skripte

| Skript | Zweck |
|---|---|
| `import_pretix.py` | Importiert die neueste `_inbox/attendees_*.csv` in `kontakte.csv`. Dedup über (Vorname, Nachname). Respektiert `manual=true`. |
| `export_badges.sh` | Batch-Render aller Einträge mit `3d_erstellt!=true`. Max. 2 parallele OpenSCAD-Prozesse. Setzt `3d_erstellt=true` nach erfolgreichem Render. |
| `sync_3d_gedruckt.py` | Liest macOS-Finder-Tags der `export/*.3mf` (xattr `_kMDItemUserTags`, bplist). Grüner Tag → `3d_gedruckt=true`. |

### Dateistruktur

```
.
├── _inbox/                          # Pretix-CSV-Exporte (Drop-Zone)
│   └── attendees_example.csv        # Beispiel-Inputformat
├── bambustudio/
│   ├── bambulab_template.3mf        # Vorbereitete Druckplatte mit Filament-Change
│   └── blank_badge.3mf              # Leerer Badge ohne Name/Firma (Ersatzteilnehmer)
├── openscad/
│   ├── the_camp_card.scad           # Parametrisches Badge-Template (vorname/nachname/firma via -D)
│   ├── the_camp_card_blank.scad     # Blanko-Variante ohne Texte
│   └── typo3_logo.svg               # Logo, relativ importiert
├── export/                          # Generierte {Vorname}_{Nachname}.3mf (gitignored)
├── kontakte.csv                     # Master-Daten (gitignored)
├── import_pretix.py
├── export_badges.sh
├── sync_3d_gedruckt.py
└── CLAUDE.md                        # Pipeline-Regeln für Claude Code
```

### Voraussetzungen

- macOS (wegen `sync_3d_gedruckt.py` — nutzt `xattr`/Finder-Tags)
- Python 3 (nur Stdlib, keine externen Deps, kein venv nötig)
- OpenSCAD unter `/Applications/OpenSCAD.app/`
- Google-Font **Onest** installiert (SemiBold + ExtraBold)
- Bambu Studio (für die Vorlage und den eigentlichen Druck)

### Dateiname-Sanitization

Sowohl `export_badges.sh` als auch `sync_3d_gedruckt.py` ersetzen in `{Vorname}_{Nachname}` alle Zeichen außerhalb von `[A-Za-z0-9_-]` durch `_`. Umlaute werden also zu Unterstrichen — wichtig, damit Tag-Sync und Render-Output denselben Dateinamen treffen.

### Manuelle Einträge

Kurzfristige Ersatzteilnehmer, die nicht in Pretix stehen, als neue Zeile mit `manual=true`, `3d_erstellt=false`, `3d_gedruckt=false` in `kontakte.csv` eintragen. Den ursprünglichen Eintrag **nicht** löschen — sein Badge ist eventuell schon gedruckt, und ein überschüssiger Badge ist günstiger als die Korrektur. Details siehe `.claude/rules/manual-contacts.md`.
