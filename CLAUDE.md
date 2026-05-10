# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Badge generation pipeline for **THE CÄMP 2026** (TYPO3 community event). Generates personalized 3D-printable badges (100x60mm, 3MF format) from attendee CSV data using OpenSCAD.

## Pipeline

1. **Import**: `python3 import_pretix.py` — imports the newest `_inbox/attendees_*.csv` (semicolon-delimited Pretix export) into `kontakte.csv`; falls back to the legacy `_inbox/THECAEMP26_pretixdata.json` if no CSV is present. Dedups by (Vorname, Nachname); `manual=true` rows are never touched.
2. **Export**: `sh export_badges.sh` — batch-renders badges for all entries with `3d_erstellt=false`, runs max 2 parallel OpenSCAD processes, marks entries `true` on success
3. **Print status sync**: `python3 sync_3d_gedruckt.py` — reads Finder green tags on `export/*.3mf` and writes them to the `3d_gedruckt` column. Run before any change to `kontakte.csv` or the print workflow. See `.claude/rules/finder-tags-3d-printed.md`.

## Key Files

- `openscad/the_camp_card.scad` — parametric OpenSCAD badge template (receives `vorname`, `nachname`, `firma` via `-D` flags)
- `openscad/the_camp_card_blank.scad` — blank badge variant (no name/company)
- `kontakte.csv` — master data (`Vorname,Nachname,Firma,3d_erstellt,3d_gedruckt,manual`), the single source of truth. `manual=true` rows are last-minute additions not in Pretix and must never be deleted — see `.claude/rules/manual-contacts.md`.
- `export_badges.sh` — batch export orchestrator, uses `SCRIPT_DIR` for portable paths
- `import_pretix.py` — Pretix data importer with deduplication
- `sync_3d_gedruckt.py` — syncs `3d_gedruckt` column from Finder green tags (ground truth for print status)
- `openscad/typo3_logo.svg` — logo embedded in badges (relative-imported by the .scad files)

## OpenSCAD Template Architecture

The badge has embossed text (0.4mm) on a yellow base plate with rounded corners and a lanyard hole.

**Firma text wrapping** (the most complex part):
- `|` (pipe) in company names acts as a **forced line break** and is not rendered
- Text auto-wraps at word boundaries after `firma_max_chars` (default 20)
- Processing chain: `split_pipe()` → `wrap_lines()` per segment → `wrap_all()` combines results
- String helper functions (`substr`, `_join`, `last_space`) are needed because OpenSCAD has no built-in string manipulation

**Font**: Google Font "Onest" must be installed on the system (SemiBold for names, ExtraBold for headers).

## CSV Format

Semicolon-delimited input from Pretix, comma-delimited in `kontakte.csv`. Company field is optional (can be empty). Supports Unicode (German umlauts, special chars).

## Output

3MF files in `export/`, named `{Vorname}_{Nachname}.3mf` with special characters replaced by underscores.
