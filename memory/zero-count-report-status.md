---
name: zero-count-report-status
description: "0-0 / 0-1(0/1) usage-vs-command Arm Farm batch report — shipped v1, phase-2 postgame port pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: cff9e98b-0097-487e-9230-459778fb101d
---

## Weekly report — FULL STATE as of Jun 16 2026 (SHIPPED `feature/bullpen-reports`, user iterated live; "alright right now")

Weekly week-vs-YTD mode (`--weekly`). User signed off on the design this
session ("alright right now" — may adjust later, NOT now). All on
`feature/bullpen-reports`. Last commit chain ended ~`07145730`.

### Layout (in-place on the reverted layout — NEVER full-rearrange; user
reverted `7f34af3b` a big rearrange and was furious. Edit IN PLACE.)
- Cover page 1 (`build_cover_figure`): Astros logo (square via `_place_logo`
  aspect-correction), title "0-0 & 0/1 Usage & iZ% Report", date range
  (weekly) or season-only (batch), + color KEY (green/yellow/red/neutral) +
  italic footnote on the two-lens behavior. Prepended to weekly + batch +
  hand-split PDFs (NOT `--individual`).
- Header: orange top-right chip = `vs RHH/vs LHH/Overall · YTD InZ · Wk InZ`
  (hand label MOVED here from subline). Subline = `87 / 657 (this week / season)`.
- Mini-zones left (gold last-7-day dots over faded 0.45 season cloud,
  `_GOLD=#FFC20E`; `_draw_mini_zone(week_df=)`). Zones+table ordered by
  **season iZ% desc** (best-commanded first).
- Right side table: per pitch **Season/Week/Δ for BOTH Usage + In-Zone** (7-col).
- Order lines: Ideal (cmd) / Season / Week. Summary sentence below.

### Eligibility = PER-BUCKET gate (`BUCKET_MIN_PITCHES={"00":15,"01":30}`)
A pitch shows in a bucket if thrown >= that bucket's gate IN THAT BUCKET this
season. 0-0=15, 0/1=30. `min_pitches` arg=None → per-bucket; an int overrides
both. Empty bucket text = "Has not met N-pitch threshold".

### Coloring logic (`_week_assessment` + `_line_color`) — top-2, order-sensitive
Refs: ideal_order=season iZ desc; week_iz_order=this week's iZ desc;
usage orders=most-thrown. **RED requires 3+ pitches; 2 caps at yellow; <2 neutral.**
- Season line: green if season usage matches ideal; red if not (yellow at 2).
- Week line: green=matches ideal; yellow=matches what he located best THIS WEEK
  (not ideal); red=neither.
- Summary text: green if week usage matches week-iZ OR ideal; red if neither
  (amber at 2, neutral at <2). ⚠+red pitch name only on a real red.
- **Two-lens by design (user "this is beautiful"):** Week LINE grades vs season
  command (yellow when off ideal); SENTENCE also credits what he located best
  this week → a yellow Week line CAN pair with a green sentence. Documented in
  the cover footnote. Option to unify (sentence follows line) declined for now.

### Roster scope (batch `_BATCH_GATE`, Jun 2026 user direction)
NO POSITION_LK restriction — ANY current HOU-org MiLB player who clears the
per-bucket gate shows (position players who pitch enough included). `ORG_LK='hou'`
+ inactive-status exclusion drop released/non-HOU (e.g. Eurys Martich falls off
when PP_MASTER flips status). MiLB scope kept (`LEVELOFPLAY_LK <> 'ml'`).

### CLI flags
`--weekly --last-week` (only pitchers who pitched in the trailing-7d window;
`--week-only` = back-compat alias) `--week-ending YYYY-MM-DD` `--deliver`
`--channel` `--logic-app-url URL` (overrides LOGIC_APP_URL env). Delivers to
BOTH `#weekly-iz-vs-usg` (C0BABH1PU3Z) + `weekly-player-updates` (C0AVBKPEG8H).
`--last-week` org-wide ≈ 185 pages (~60 pitchers × Overall/RHH/LHH) — expected.

### Monday cascade
`run_monday.ps1` line 314: `generate_zero_count.py --season $SEASON --weekly
--last-week --week-ending $Date $d` (`$d`=--deliver live). Registered in
PhaseOrder (lines 85,120). Delivers via LOGIC_APP_URL env (no flag needed).

### Phase 2 app Visuals tab (Arm Farm postgame tab2) — season 0-0/0-1 only,
`min_pitches=None` (per-bucket). UNTESTED on live DB still.

### OPEN (not blocking; "may adjust in future"): right-strip 7-col fit on real
data; drop mini-zone Use%/InZ% titles (doubled w/ table)?; unify sentence↔line
color?; org-wide 185pp maybe split by level.

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

**PHASE 2 (app Visuals tab) — SHIPPED Jun 15 2026 (`feature/bullpen-reports`), UNTESTED on live DB.**
Arm Farm postgame **tab2 "Daily" → "Visuals"** (full replace; old Daily Tracker
body kept behind `if False:` guard). **Season-level** 0-0 & 0/1 view for the
**sidebar-selected pitcher**, stacked **full-width Overall / vs RHH / vs LHH**
(user changed from side-by-side to stacked). **matplotlib st.pyplot reuse, NOT
Plotly** (lowest compute + App↔Report parity via shared
`zero_count_report.build_zero_count_figure`). Commits: `22928f0c` (initial) →
`c69d7999` (manifest fix — added `src/zero_count_data.py` + `zero_count_report.py`
to manifest.json; rsconnect allow-list, app crashed ModuleNotFoundError) →
`5b0ece88` (per-pitcher fetch + season-from-sidebar) → `9699c586` (stack full-width).
- **No season selectbox, no min slider** (user rejected both): season = year of
  the **sidebar-selected outings** (`pitch_df.sched_date`), min hardcoded **30**.
- **Roster-gate fix (key):** `fetch_zero_count_rows(season, pitcher_id=None)` — when
  `pitcher_id` given (app), DROPS the batch gate (`POSITION_LK`, `LEVELOFPLAY_LK<>'ml'`,
  inactive) so ANY selected pitcher resolves (MLB-rostered / inactive included).
  `_BATCH_GATE` applies only to the whole-pool batch report path.
- **VERIFY on work laptop:** pull bullpen → redeploy → Postgame → Visuals → pick
  pitcher → confirm Overall/RHH/LHH render; tune fig size if needed.

**WEEKLY REPORT (week-vs-YTD) — BUILT Jun 15 2026 (`feature/bullpen-reports` `6dc80e44`
+ run_monday phase `9282abaa` on `feature/pd-goals`), UNTESTED on live DB.**
DJ Engle: each Monday, how did THIS WEEK's 0-0/0-1 Usage% + InZ% move off the season
rate. New `--weekly` mode (NOT a separate script). Verified end-to-end on synthetic
data (agg + 3-page figure). Locked + built decisions:
- **Window = trailing 7 days** ending `--week-ending` (default today).
- **Eligibility YTD ≥30; NO week min-gate** (eligible type not thrown this week → wk
  usage 0%, InZ "—").
- **Scope = all roster pitchers**; `--week-only` restricts to who threw this week.
- **Overall + RHH + LHH per pitcher** (one PDF, interleaved), ordered lowest-YTD-InZ first.
- **REVERTED Jun 16 2026 (`7f34af3b`) — the redesign below was REJECTED.** Zac wanted
  surgical in-place edits to the prior side-table layout, NOT a rearrange. Back to:
  header subline carries the "X wk / Y season pitches" count; per bucket = mini-zones
  on LEFT (titles `Use X% (Δ)` / `InZ Y% (Δ)`) + "This Week vs Season" side table on
  RIGHT + ⚠ line. Make future changes IN PLACE on this layout; do not move blocks.
  (Rejected redesign for reference only — DO NOT re-ship without explicit ask:)
- **Layout (REDESIGNED Jun 15 2026, commit `e908af88` — REVERTED):** header + auto **"Weekly
  read"** block (1 sentence per bucket: leaned-on-vs-best-commanded + order-shifted
  flag + week-InZ-vs-season). Per bucket: big **"wk / season pitches"** count top-right;
  **zones = picture + pitch name ONLY** (no stats — killed the double-drawn numbers
  Zac flagged); ONE table with **Season / Week / Δ for BOTH Usage and In-Zone**;
  **3 order lines** (Ideal command / Season usage / This-week usage, "← shifted").
  ⚠ = most-thrown-this-week pitch ≠ best-commanded. `aggregate_pitcher_weekly` bucket
  dict gained `wk_n`/`ytd_n`/`wk_inz_overall`/`ytd_inz_overall`. Render fns:
  `_draw_summary_weekly` + `_summary_for_bucket` + rewritten `_draw_section_weekly`
  (`_WK_BANDS` geometry). Matplotlib coords likely need a visual tune on real data.
- **Files:** `zero_count_data.py` (SELECT now has `sv.sched_date`;
  `aggregate_pitcher_weekly` + `_weekly_bucket_table`), `zero_count_report.py`
  (`build_weekly_figure` + `_draw_*_weekly`), `generate_zero_count.py`
  (`_run_weekly`, args `--weekly --week-ending --week-only --deliver --channel`,
  delivers to BOTH `C0BABH1PU3Z` #weekly-iz-vs-usg AND `C0AVBKPEG8H`
  weekly-player-updates — same channel pitcher_analysis/hitter_analysis use;
  commit `56713bd5`).
- **run_monday.ps1:** new `zero-count` phase (Stage 1) →
  `generate_zero_count.py --weekly --week-ending $Date $d`. In PhaseOrder + Resume set.
- **CLI:** `python scripts\generate_zero_count.py --season 2026 --weekly [--week-ending YYYY-MM-DD] [--week-only] [--deliver]`. Out: `output/zero_count/ZeroCount_Weekly_HOU_Org_<season>_<YYYYMMDD>.pdf`.
- **VERIFY work laptop:** real `--weekly` run; eyeball the 3-line zone titles + side
  table fit (coord tune likely); then `--deliver` dry-check before live Monday.
- **STILL OPEN (ask DJ):** trailing-7d vs L2W window (built 7d); whether mini-zone
  dots should be week vs YTD locations (built YTD).

Also this session: DSL WPA Plays routing fixed (`pd-goals/scripts/generate_wpa_plays.py`
`dsl` → `CFZLA3W2K` z8_dominican_academy, was overflow placeholder; commit `2e0487c5`).
