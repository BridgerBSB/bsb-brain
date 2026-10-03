# Pitcher Postgame — Per-PA Strike Zone Section (design)

**Date:** 2026-06-07
**Branch:** `feature/bullpen-reports`
**Requested by:** coordinator (via Zac)
**Scope:** Arm Farm pitcher postgame **report** only. (App page is a
separate follow-up — "we'll add it to the app too" — not in this change.)

## What the coordinator asked for

In the Individual / pitch-log section at the bottom of the pitcher
postgame report: for every plate appearance, couple that PA's pitches
together and draw a strike zone below them — like the existing LVA
"plain white" zones — with each pitch plotted at its location and a
small sequence number (1, 2, 3, …) rendered just **above** each pitch's
result marker.

## Locked design decisions (from brainstorming)

1. **Layout:** PA-card stack. New section, added AFTER the existing flat
   pitch-log pages (per outing). Existing flat pitch-log table is
   unchanged.
2. **Card contents:** minimal header (`PA n — F. Last → Result`) +
   the PA's **full** pitch rows (same columns as the flat log) + a
   plain-white strike zone below. Single column, ~2–3 PAs per page.
3. **Markers:** keep the existing result-shaped, pitch-type-colored
   markers (whiff ●, foul ■, hard ✕, weak ▲, take ○) and render a
   **small sequence number just above** each marker (offset, not
   centered — does not cover the marker).
4. **Zone background:** plain white (SZ rectangle + home plate only,
   NO projection heatmap).

Known accepted trade-off: each pitch's row appears twice (flat table +
PA card). Easy to drop the flat table later if it's too much.

## Page order (per outing)

Stuff page → LVA zone pages → **flat pitch-log pages (unchanged)** →
**PA-card pages (NEW)**.

## Implementation

### Data layer — `bullpen-report/src/postgame_data.py`

Extend `_PITCH_LOG_QUERY` (consumed by `get_postgame_pitch_log`) with:
- `-pv.plate_x AS plate_x` — flipped to **pitcher's view** to match the
  LVA zones (per `coordinates.md`; the flat log query is otherwise raw).
- `pv.plate_z`
- `pv.batter_id`
- `bp.first_name AS batter_first`, `bp.last_name AS batter_last`
  (new `LEFT JOIN Astros.Players bp ON bp.groundcontrol_id = pv.batter_id`)
- `ev.event_result AS pa_result` (`ev` already joined on `ab_event_id`,
  which is the PA-terminal event, so this is the PA outcome).

`get_postgame_pitch_log` already returns all query columns + `count` +
`pbrl`, so these flow through with no other change. `ab_pitch_number`
(sequence within PA) and `ab_event_id` (PA grouping) are already
selected.

### Report layer — `bullpen-report/src/postgame_report.py`

1. **Refactor (no behavior change):** extract the table-building body of
   `_draw_pitch_log_page` into `_render_pitch_log_table(ax_table,
   pitch_df, active_cols, percentiles)`. `_draw_pitch_log_page` keeps its
   header strip and calls the helper. Single source of truth for the
   table so the PA card can reuse it with the full column set.

2. **New `_draw_pa_zone(ax, pa_df)`:** plain-white strike zone. Reuses
   `_SZ_*` bounds, `_HP_VERTS`, `_classify_pitch_result`,
   `_RESULT_MARKERS`, `PITCH_TYPE_COLORS`. Per pitch: result-shaped
   marker filled/colored by pitch type; small bold sequence number
   (`ab_pitch_number`) at `plate_z + ~0.18 ft` above the marker;
   `_attach_clickable(... v_url ...)` for click-to-video (the pitch-log
   URL column is `v_url`, not `cf_angle_url`).

3. **New `_draw_pa_card_page(fig, pa_dfs, outing_header, percentiles,
   player_view)`:** lays up to `PA_PER_PAGE` (3) PA cards down the page.
   Each card band: header text (`PA n — F. Last → Result`), full pitch
   table (upper portion), strike zone (lower portion). Coordinates are
   figure-relative and **tunable** (visual tuning to happen on the work
   laptop — no DB/visual on personal laptop).

4. **Wire-in:** in `generate_postgame_report`, after the per-outing
   flat pitch-log chunk loop, group `_outing_pitches` by `ab_event_id`
   (chronological), chunk into groups of 3, and render PA-card pages.

## Verification

Personal laptop has no DB — cannot render. Plan: `py_compile` both
modules, push, user runs the report on the work laptop and visually
tunes card/zone coordinates. Then port to the app page (separate task).

## What NOT to do

- Don't touch the existing flat pitch-log table output (stays identical).
- Don't add a heatmap behind the PA zones (plain white only).
- Don't center the sequence number on the marker — offset it above.
- Don't forget the `-pv.plate_x` flip (pitcher's view parity with LVA).
