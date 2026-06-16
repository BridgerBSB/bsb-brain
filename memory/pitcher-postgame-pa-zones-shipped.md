---
name: pitcher-postgame-pa-zones-shipped
description: Per-PA strike-zone cards SHIPPED in Arm Farm pitcher postgame report + app (Jun 7 2026); work-laptop visual test pending
metadata: 
  node_type: memory
  type: project
  originSessionId: 25d66815-30b4-46b0-828e-687ad05912b5
---

# Pitcher Postgame — Per-PA Strike Zone Cards (SHIPPED Jun 7 2026)

Coordinator ask: in the pitch-log section, couple each PA's pitches
together with a strike zone showing the pitch sequence. Built on
`feature/bullpen-reports` (worktree `C:\Users\Owner\bsb-wt-bullpen`).
Knowledge graduated to `.claude/rules/arm-farm.md` ("Per-PA Strike Zone
Cards" section, synced byte-identical to all 4 worktrees, md5 `c2a9a47…`).

## What shipped (report + app, REPLACES the flat pitch-log table)
Per outing → per PA card = header `PA n — F. Last → Result` + that PA's
full pitch rows + a plain-white strike zone below, each pitch plotted at
its location with the existing result-shaped/pitch-type-colored marker
and a **small sequence number offset just above** each marker. No heatmap.

- **Data:** `postgame_data.py::_PITCH_LOG_QUERY` added `-pv.plate_x AS
  plate_x` (pitcher's-view flip), `plate_z`, `batter_id`,
  `batter_first/last` (+ `Players bp` JOIN), `ev.event_result AS
  pa_result`. Flows through `get_postgame_pitch_log` to BOTH report + app.
- **Report:** `postgame_report.py` — extracted `_render_pitch_log_table`
  (single source of truth), new `_draw_pa_zone` / `_draw_pa_card` /
  `_draw_pa_card_page` (PA_PER_PAGE=3), wired into the per-outing loop;
  removed the flat-log chunk loop. `_draw_pitch_log_page` kept but
  UNUSED (revert toggle).
- **App:** `pages/2_Postgame.py` — "Individual Pitches" → "Plate
  Appearances"; per-PA styled `st.dataframe` (`_render_pa_pitch_table`,
  ▶ V/Side links preserved) + `_draw_pa_zone` via `st.pyplot` in a narrow
  left column (`figsize=(2.6,3.0)`). Static zone; video stays on table ▶.

## Locked design decisions (brainstorming)
PA-card stack · full rows in cards · plain-white zone · number offset
ABOVE marker · cards REPLACE flat table (not additive). Design doc:
`bullpen-report/docs/plans/2026-06-07-pitcher-postgame-pa-strike-zones-design.md`.

## Commits (all pushed)
- `78b9aaea` report cards → `b1defa7a` cards replace flat table →
  `607b40ad` app mirror + arm-farm.md (feature/bullpen-reports)
- rule sync: `354292f3` (barrelsville), `5de0efd5` (intangibles),
  `91014379` (pd-goals)

## PENDING — work laptop (no DB/visual on personal laptop)
1. `cd C:\Users\zbridger\bsb-wt-bullpen && git pull`
2. Test report: `python bullpen-report/scripts/generate_postgame.py
   --date <date> --pitcher <gc_id>` (no `--deliver`) → open PDF, check
   the PA-card pages.
3. Test app: run/redeploy Arm Farm → Postgame → Plate Appearances.
4. **Visual tuning likely** (I couldn't render): card/zone figure coords
   in `_draw_pa_card` (report) + in-app zone `figsize` (2.6×3.0).
   Also: PA_PER_PAGE=3 (drop to 2 if zones cramped). All one-liners.

## Notes
- Each pitch's row appears once now (flat table removed) — user
  explicitly wanted REPLACE, not add-on.
- App is interactive per-PA (chosen over static-image mirror).
- Related session also added Bryce Collins zzz_ Slack channel
  (`zzz_collins_bryce_80773`/`C0B8DE24124`) across all 5 CSVs — see
  `slack-channels-sync.md`.
