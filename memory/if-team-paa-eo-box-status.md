---
name: if-team-paa-eo-box-status
description: "Team PAA/EO box on daily IF reports + DSL-as-Rookie mazzo fix — SHIPPED + VERIFIED LIVE on feature/astros-intangibles"
metadata: 
  node_type: memory
  type: project
  originSessionId: fdf54534-2d78-43e2-8d9a-b5484023c7fd
---

**Team PAA/EO box on the daily IF reports** — Nic O (IF coordinator) ask.
SHIPPED + **VERIFIED LIVE on the work laptop** — box renders correctly AND
DSL no longer shows as "Rookie". `feature/astros-intangibles`.

**Two SEPARATE DSL→"Rookie" fixes (different reports — easy to conflate):**
- **IF daily report** (`if_postgame_report.py`, `07592196`) — combined report
  grouped by raw level_code → fixed to `route_key`. Plus the box zorder.
- **Mazzo Special = OF all-plays report** (`of_postgame_report.py`, `f588f93e`)
  — THIS is where the user actually saw DSL="Rookie". Mazzo =
  `scripts/mazzo_special.py` (named after **Dylan Mazzo**, OF, ungated, per-row
  Level column), NOT the IF combined report. Fixed the per-row Level column AND
  section grouping to gc2_level_code (was raw level_code). Run:
  `python scripts/mazzo_special.py --date <date>` → `reports/Mazzo_Special_OF_<date>.pdf`.

----- ORIGINAL (now historical) -----
SHIPPED on `feature/astros-intangibles` (commits `bb030e7a` feature →
`07592196` two fixes). ~~UNVERIFIED on live DB after the fixes~~ — needs a
work-laptop re-run; the **mazzo special (combined all-levels / DSL) is
untested**.

## What it is
A compact box right of the percentile key on each **per-level** IF daily
report (per-level PDFs only — the combined report passes `team_paa_eo=None`,
no box). Two lines for that level's HOU IF:
- **Today**  — R-game IF plays on the report date only (noisy on small n).
- **Season** — season-to-date through the report date.
Both are the rate-form **PAA/EO** at f3 (e.g. `+0.041`), NOT cumulative PAA.

## Files (all on intangibles worktree)
- `intangibles/src/if_postgame_data.py` — `_TEAM_PAA_EO_QUERY` + `get_team_paa_eo(level_code, game_date)` → `{"today": float|None, "season": float|None}`.
- `intangibles/src/if_postgame_report.py` — `_draw_team_paa_eo_box(fig, paa_eo)`; `generate_if_daily_report` gained `team_paa_eo` param; page-0 draws box + drops `y_cursor` 0.875→0.845 + `MAX_ROWS_PAGE1`−3.
- `intangibles/scripts/generate_if_report.py` — computes `get_team_paa_eo(route_key, date)` per level, passes to per-level report, prints `Team PAA/EO <LVL>: today=…, season=…`.

## The math (mirrors `fielding_tracker_data._DCBP_QUERY`, verified vs GC2)
Per (fielder, pos_id): `expected_outs = SUM(out_prob)*AVG(eo_scalar)`;
`paa_cal = (SUM(paa)/SUM(out_prob) − AVG(paaeo_offset)) * SUM(out_prob) * AVG(eo_scalar)`.
Calibration JOIN `guts.PAA_EO_Position_Calibration` on `(pos_id, positional, season)`.
Team identity via `fielding_team_id → mlbam.teams`, `UPPER(org_abbrev)='HOU'`.
Team rollup = `SUM(paa_cal)/SUM(expected_outs)` over the level's HOU IF
(pos 3,4,5,6). paa_cal + expected_outs additive → matches affiliate tracker
+ org KPI (three-surface parity). Level scope via `_build_level_filter`
(dsl/rok via gc2_level_code). Window only differs by the date filter
(`= :game_date` today vs `<= :game_date` season).

## Two fixes (`07592196`)
1. **Empty box** — `FancyBboxPatch` had `zorder=6`; `fig.text` defaults ~3 →
   fill painted over the text. Dropped patch zorder, set text `zorder=10`.
2. **DSL → "Rookie"** in combined report — `generate_if_daily_report` grouped
   sections by raw `sv.level_code` (DSL games carry `level_code='rok'`). Now
   groups by `route_key` (gc2-based: dsl='dsl', rok='rok'); also fixed the
   per-section percentile-pool lookup for DSL. (Instance of level-codes.md
   blocking rule #6, not a new pattern.)

## Open / decide after a real run
- **Rate vs cumulative**: shipped PAA/EO rate (what Nic said). One-line swap to
  cumulative PAA (`team_paa_cal` instead of `/expected_outs`) if he'd rather see
  the tangible "+3 plays" count — query already computes both.
- **Combined report box**: v1 has none (per-level only). Could add per-level
  boxes to each level page of the mazzo special if wanted.
- **Doc**: optional one-line note in `three-surface-parity.md` registering the
  daily IF report as a PAA/EO consumer (reuse, not a new definition) — not done.

## Verify (work laptop)
`cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles\intangibles; git pull;`
`python scripts/generate_if_report.py --date <date>` — box should show
Today/Season; combined PDF should show a real **DSL** section separate from
Rookie/FCL. Sanity-check the Season line vs the tracker's HOU IF PAA/EO.

## Same session — catcher NetK (Jase Mitchell exploration, gc_id 1293257)
Side thread, not blocking. Jase Mitchell catcher NetK in FCL 2026.
- **By-game NetK SQL** (`bsb-resources/sql-queries/jase-mitchell-fcl-netk-by-game-2026.sql`,
  committed) — game-by-game `SUM(net_k)` on edge-zone called pitches (canonical
  gate: raw `called_strike_chance` 0.05–0.95, `pitch_result_id IN (4,5,6)`,
  `ignore_flag=0`, `pitch_id>0`) + running `netk_before`/`netk_after` window +
  `pitches_caught`/`edge_pitches` coverage cols. Reconciles to his displayed
  per-catcher NetK. Bottom has a Players_Games (pos_id=2) completeness cross-check.
- **Catcher framing hexbin gained single-player single-game mode** (commit
  `ed911ecb`, `feature/astros-intangibles`) — `generate_catcher_framing_hexbin.py`
  + `catcher_framing_hexbin_data.get_called_pitches(game_date=…)`. New flags
  `--catcher <gc_id>` + `--date YYYY-MM-DD` (scopes pitch pull to one game, season
  to that year, skips org title page; colors still calibrated to the season level
  pool). Batch path unchanged. **UNTESTED on live DB** (just built). Jase -22 day:
  `python scripts/generate_catcher_framing_hexbin.py --catcher 1293257 --date 2026-05-30`
  → `output/Catcher_Framing_Hexbin_1293257_2026-05-30.pdf`.
- FCL HawkEye sparsity caveat: non-tracked venues → thin hexes / 0 net_k even on
  games he caught (NetK needs `called_strike_chance`).
