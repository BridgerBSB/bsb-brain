---
name: analysis-scripts-session-2026-06-10
description: "Jun 10 2026 hitter_analysis.py overhaul (acquisition mode, DSL fix, zone-page redesign, GC2 heatmaps, Age/Ht/Wt header) + pitcher header parity. SHIPPED, untested on live DB."
metadata: 
  node_type: memory
  type: project
  originSessionId: 18c11562-d60f-4dd0-9937-9de68c051183
---

# Hitter/Pitcher Analysis batch-PDF session — Jun 10 2026

All on `feature/barrelsville` (hitter) + `feature/bullpen-reports` (pitcher).
`hitter_analysis.py` = `bsb-wt-hitting/barrelsville/scripts/`; `pitcher_analysis.py`
= `bsb-wt-bullpen/bullpen-report/scripts/`. **All SHIPPED + pushed + compile-clean,
but UNTESTED against live DB** (personal laptop has no DB) — user verifies on work
laptop. Verified the two new visuals via synthetic smoke tests only.

## What shipped (commits, hitter unless noted)

| Commit | What |
|---|---|
| `33f0a3b6` | hitter `--batter-ids` ACQUISITION MODE — mirror of pitcher `--pitcher-ids`. Bypasses `ORG_LK='hou'` roster gate to scout non-HOU bats by gc_id. Local-only (`reports/..._ACQ.pdf`), `--deliver` ignored. |
| `5208ac3c` | Removed a FALSE "vs-HOU games only" caveat I'd wrongly carried over from the pitcher acq note. `Pitches_View` has the FULL league — all requested players returned data. (User corrected me; don't speculate about data.) |
| `f2c602ef` | **DSL PA-inflation fix** + un-split zone pages (see below) |
| `6ffcbc62` | Transpose zone pages: metric across top (columns), season down side (rows) |
| `bf004f68` | Header shows Age/Height/Weight instead of `GC <id>` + xwOBAcon chart numbers 0.5pt smaller |
| `28d31772` | (pitcher) header Age/Height/Weight parity |
| `1f58d122` | GC2/Statcast turbo-rainbow Swing/Contact heatmaps |
| `003c79d9` | Density color key (Low→High "Pitch Density") right of title on Swing/Contact pages |

## DSL PA-inflation fix (the original bug)
`_query_timeframe` aliases `gc2_level_code AS level_code`, so per-level Results tables
filter `level_code=='dsl'` and correctly EXCLUDE the INT Live AB intrasquads. But the
Total/RHP/LHP KPI split tables + zone heatmaps ran on the FULL season frame (which still
carries the DSL player's `level_code=='int'` Live AB rows) → inflated PA. **Fix:** in
`collect_player_data`, scope `pitch_df`/`pa_df` to `levels` (cur + prev season) right
after `clean_ev_misreads`, before splits/zones. Drops INT/BBC/SUM junk generally.
**pitcher_analysis is NOT affected** — it filters levels in SQL at fetch
(`_query_pitch_data`/`_query_pa_data` use `AND ({level_filter})`; `_build_level_filter('dsl')`
= `gc2_level_code='dsl'`).

## Page structure now (hitter)
Dual-season = 6 pages, single-season = 5:
- Pg1: Results + KPI(vs RHP/LHP) + **xwOBAcon** hand-split zones (relabeled from "xwOBA"; metric was already contact-xwOBA on BIP).
- Pg2: Attack Angle + Launch Angle + xwOBAcon zones — ALL pitches (no FB/OS/BRK split), metric=columns / season=rows.
- Pg3: Avg EV + Whiff% zones — same transposed all-pitches layout.
- Pg4/5: Swing Location / Contact Location (KDE, STILL split FB/OS/BRK).
- Pg6: Contact-point page.
Single-season collapses Swing+Contact to one page.
Helpers added: `_draw_metric_zone_page` (R×C zone grid), `_zone_cell` closure (kinds aa/la/ev/whiff/xwc), `_filter_pitch_group("ALL")`, `_compute_zone_xwoba(hand=None)`.

## GC2 Swing/Contact heatmaps (`_draw_kde_contour`)
Replaced single-hue contourf bands with smooth turbo-rainbow density:
`_HEAT_CMAP` (blue→cyan→green→yellow→red), 200×200 KDE grid → imshow RGBA with
density-driven alpha fade (`alpha=clip(norm,0,1)**0.65`, zero below norm<0.03, cap 0.92).
Zone box + home plate on top. NO batter silhouette (user opted out; no asset exists —
only logos/badges/running_man.png). `_draw_density_legend` = Low→High gradient bar +
"Pitch Density" caption, right of title (passed via `legend_cmap=_HEAT_CMAP` on the
swing/contact `_draw_metric_rows` calls only).

## Header Age/Ht/Wt (both scripts)
`_compute_age(birthdate)` (1-decimal, truncated, never rounds up) + `_lookup_height_weight(mlbam_id)`
(`SELECT * FROM mlbam.players` + candidate-column scan for weight: `weight`/`weight_lbs`/
`playerweight`/`body_weight`/`weight_pounds`). Height cols verified = `height_feet`/`height_inches`;
weight col NOT in DB docs → scanned not guessed. Bio computed ONCE per player in
`collect_player_data`, stashed as `_bio_age`/`_bio_height`/`_bio_weight` on the player Series;
`_draw_header` renders `Name | Pos | B/T | Level | Age X.X | H'I" | W lb`.

## Run commands (work laptop)
```
# Acquisition (non-HOU scouting targets) — hitter
python scripts\hitter_analysis.py --season 2026 --batter-ids 110466 93490 162667 176436 139152 94392 94535 66559 155852 197816 218594
# (also --season 2025; players w/ no 2026 data DROP, no auto-fallback — prior season is a side-by-side column only)
# DSL by level (full HOU DSL roster) — hitter + pitcher
python scripts\hitter_analysis.py --season 2026 --levels dsl
python scripts\pitcher_analysis.py --season 2026 --levels dsl
```
Acquisition gc_ids = Hendrie 110466, Cartaya 93490, Thompson 162667, Figueroa 176436,
Lege 139152, Vargas 94392, Lugo 94535, G.Collins 66559, Munoz 155852, Rushford 197816,
Redfield 218594. NO gc_id yet: Michael Soper (Pioneer Lg link), Paul DeJong (no link).

## Open follow-ups
1. **Verify weight populates** on work laptop. If header shows `— lb`, the real mlbam.players
   weight column isn't in my candidate list — run `SELECT TOP 1 * FROM mlbam.players` and pin it.
2. **Pitcher-analysis location heatmaps** could get the same turbo restyle — user-optional, not done.
3. Add Soper + DeJong to acquisition runs once their `gctwo-spa-prd.../players/<id>` ids are provided.
4. All visuals/logic UNTESTED on live DB — eyeball first DSL PDF (split-table PA should match
   Results "Total" row; pages 2/3 combined-pitch grids + xwOBAcon; Swing/Contact turbo + legend).
