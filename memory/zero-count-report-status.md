---
name: zero-count-report-status
description: "0-0 / 0-1(0/1) usage-vs-command Arm Farm batch report — shipped v1, phase-2 postgame port pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: cff9e98b-0097-487e-9230-459778fb101d
---

**Jun 8-9 2026 — SHIPPED v1 on `feature/bullpen-reports` (Arm Farm).** DJ Engle ask:
per HOU MiLB pitcher, are we throwing the pitch we command best in the zone on
0-0 / early counts? Batch per-pitcher PDF, postgame `_draw_pa_zone` style.

**Files (bullpen-report/):** `src/zero_count_data.py`, `src/zero_count_report.py`,
`scripts/generate_zero_count.py`, `docs/plans/2026-06-08-zero-count-usage-vs-command-design.md`.
Commits: `07d18002` (v1) → `c0c424f0` (MLB+header InZ+order) → `9f96b6ba`
(roster fix) → `45b2db05` (hand-split) → `fd9480b5` (interleaved batch) →
`4e577725` (both InZ on hand pages).

**Locked semantics:**
- Pool = `count_usage_data._COUNT_USAGE_QUERY` scope, **roster FCL→AAA only**
  (`LEVELOFPLAY_LK<>'ml'`) BUT **MLB-level pitches counted** (`'mlb'` in game-level
  whitelist) — a AAA guy's callup pitches count, MLB-rostered guys get no page.
- InZ% = `avg(called_strike_chance_mlb)`. **0-0** = balls=0 & strikes=0.
  **0/1** = `strikes_before IN (0,1)` (zero-or-one STRIKE, NOT the 0-1 count).
- Pitch type shown only at **≥30 pitches** (per-hand when `--hand-split`).
- Batch ordered **lowest overall InZ first**. Header orange chip shows Overall InZ;
  hand-split pages show BOTH "Overall InZ X% · RHH/LHH InZ Y%".
- `--hand-split` batch = ONE interleaved PDF (Pitcher RHH, Pitcher LHH, next…).
- v1 markers = simple pitch-color dots (NOT postgame result shapes — easy to swap if asked).
- CLI: `python scripts\generate_zero_count.py --season 2026 [--hand-split] [--individual] [--pitcher <id>] [--min-pitches N]`. No Slack delivery. Out: `output/zero_count/`.

**PENDING work-laptop (DB):** real-data run + tune zone/table coords.

**PHASE 2 (not built — Camden may take it):** port into **Arm Farm postgame Tab 2**
(currently "Daily Tracker") → rebuild as **"Displays"** like Barrelsville postgame
Tab 2 Visuals. Same `zero_count_data` layer (app-ready pandas), Plotly instead of
matplotlib, **season-scoped for selected pitcher** (needs the 30 sample — NOT
single-game). Gotchas: 2D click-to-video OK via canonical helper (3D dead),
pdf-last-in-script, reuse PITCH_TYPE_COLORS. Open Qs for Camden: Tab2 fully
replaces daily tracker? hand toggle on page? "Displays" = just this or grows?

Also this session: DSL WPA Plays routing fixed (`pd-goals/scripts/generate_wpa_plays.py`
`dsl` → `CFZLA3W2K` z8_dominican_academy, was overflow placeholder; commit `2e0487c5`).
