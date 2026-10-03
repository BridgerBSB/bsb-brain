---
type: project
status: untested-on-db
created: 2026-06-29
tags: [barrelsville, hitter-analysis, pdf-report, untested]
---

# Hitter Analysis report — table + swing-viz tweaks (Jun 2026)

**File:** `barrelsville/scripts/hitter_analysis.py` (+ `src/postgame_percentiles.py`) on
`feature/barrelsville`. All committed + pushed; **UNTESTED on the work-laptop DB** — `git pull`
+ run `hitter_analysis.py` on the work laptop to verify, then eyeball the items below.

## What changed (Results tables = the per-level `RESULTS_COLS` table, current + prior season)
- **Removed `wLuck`** (redundant given wOBA + xwOBA both shown).
- **Added `90% EV`** (90th-pctile EV) right after `Avg EV` — in BOTH the results tables AND the
  KPI **Damage** card (Total / vs RHP / vs LHP). It IS percentiled (colored): new league pool via
  a SEPARATE `_BATTER_EV90_QUERY` in `postgame_percentiles.py` (kept separate from the canonical
  GROUP BY `_BATTER_BIP_QUERY` since `PERCENTILE_CONT` is a window fn; same cleaned BIP pool +
  misread filter as Avg EV; ≥20-BIP gate; runs as a 7th parallel pool query → `distributions["ev_p90"]`).
  Display value pooled raw-obs via `_ev_p90_from_pitch_dfs` helper. `_PCTILE_MAP["ev_p90"]=("ev_p90",True)`.
- **Removed `Hrt Tk%`** from the KPI **Approach** card (redundant — take-complement of Hrt Sw%).
- **Results-table text 8 → 7** (column headers + cell values). Other tables untouched.

## Swing Path page (3D arc)
- **LHH camera mirrored** to view from the other side of the plate: `azim -6 → 186`. Side read from
  the data's `bat_side` (mode), so switch hitters get the right view per panel (bat L vs RHP / R vs LHP).
  RHH unchanged. `_draw_swing_path_panel` line ~3166.

## Verify on work laptop (the eyeball list)
1. **90% EV coloring** renders (green→red) in both tables + Damage card.
2. **KPI Damage card** now has 6 rows (was 5) — check it doesn't crowd the card below; tighten spacing if so.
3. **LHH swing angle** = `186` is the geometric mirror of `-6`; if it reads backwards, one-number flip.
4. **Header font** shrinks to 7 via table-level textprops (plottable usually honors it); if headers look
   unchanged, set header size explicitly post-render.

## Notes
- `postgame_percentiles.py` is SHARED with the postgame report, but the EV90 add is additive (postgame
  doesn't read `ev_p90`) — just one extra parallel query per `get_level_percentiles` call.
- Standing direction: **most metrics added to these tables must be percentiled** (color-coded).

Related: [[prp-player-review-process]] (same multi-stop session). Arm Farm FIP-always-red fix is logged in
that note's "different worktree" section.
