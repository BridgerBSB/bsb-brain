---
name: astros-training-network-deck-status
description: "Astros approved-training-facility network deck (US map + per-region directory) — built, iterated with Sam's notes, resume/iterate pointer"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4408103e-7483-4176-9c9a-d550245059db
---

One-off slide deck for Sam Niedorf's "Astros approved training facility network"
idea (support players during the dead period). NOT a reusable pattern → stays
out of `.claude/rules/`. Fully reproducible from the script (all data is inline).

## Files (on `feature/pd-goals`)
- Builder: `pd-goals/scripts/generate_facility_deck.py` — run: `python pd-goals/scripts/generate_facility_deck.py`
- Earlier standalone map (superseded by the deck): `pd-goals/scripts/generate_facility_network_map.py`
- Outputs: `pd-goals/output/astros_training_network_deck.{pptx,pdf}` + per-page PNGs in `pd-goals/output/_deck_pages/`
- Facility images: `pd-goals/assets/facilities/<slug>/{logo,photo1}.<ext>`
- US states geometry: `pd-goals/assets/us-states.geojson`; Astros logo: `pd-goals/assets/astros_logo.png`

## What the deck is (7 slides)
1. **Training Network map** (16:9): white bg, gold-filled facility states, each city = a
   leader-lined callout with the **facility logo on a tile** + 3 text rows (name / City, State /
   website). Multi-facility cities **stack like drawers** (Phoenix ×4, Seattle ×2). Force-declutter
   spreads callouts (NE fans into the Atlantic) — `MINSEP` + per-stack separation in `slide_map()`.
   **Remote/Online panel** bottom-left (Dungeon Rhats, Fowler Fitness, Jochum Strength). No legend.
2–7. **Per-region directory pages** (`slide_directory`): card grid, each card = photo + dark logo chip +
   name + city + contact (website + IG). Regions: West Coast, Arizona, Central, Southeast, Northeast, Remote.

## Key design decisions (Zac/Sam-driven)
- **Pin tiles are BLACK** (`#0D0D0D`) so white logos read — EXCEPT dark logos on a `WHITE_TILE` set:
  `knct`, `terrasports_az`, `coastal_sports`, `maven_baseball` (their logos are dark → white tile).
- Logos contained-to-fit (`_zoom_contain`); discipline chips REMOVED from directory cards.
- 29 facilities total (Sam's 28-row sheet + Maven). Driveline ×3 locations, Cressey ×2.
- Region = both map color + directory grouping; "Central" folds Mountain+Midwest+Texas.

## Logos fixed/sourced this build
- Re-downloaded correct: TerraSports, Chapman (was white→invisible, black tile fixed), X2, Praise
  (→ skool.com), Dungeon Rhats (trainheroic). Added: Florida Baseball Armory, **BRX Performance
  (Milwaukee — brxperformance.com, 414 area code confirms)**, **Maven Baseball (Atlanta — mavenbaseball.com,
  Hitting/Pitching)**.
- Label fixes: RPP→"North Jersey, NJ", Ascent→"Philadelphia, PA", Coastal→"Corpus Christi, TX".
- Name: it's **Dungeon Rhats** (`@dungeonrhats`), NOT "Dungeonraths" (Zac corrected).

## Open threads / options (not yet built)
- **East crowding** is the one imperfect thing: 13 of 29 facilities sit in SE+NE; a single national map
  can't fit them all cleanly. Cleanest fix = **regional zoom slides** (a Southeast + Northeast slide).
- **3D/video flythrough** ("crazier" deck Sam wants): BLOCKED — WebFetch hits X paywall (HTTP 402) and
  there's no X MCP, so I can't see Sam's 3 example tweets (ann_nnng / shloked / emollick). Need Zac to
  screenshot/describe. Build would be React Three Fiber / Three.js US flythrough → Remotion video export.
- **Native-editable PPTX** (real text boxes vs current image-per-slide) if Sam wants to edit copy in PPT.
- **Image gaps**: TerraSports photo still a placeholder on its directory card (logo is fine).
- Possible adds if Sam asks: phone numbers / emails on contacts.

## Status: delivered iteratively; Zac on standby for Sam's corrections (Jun 2026).
