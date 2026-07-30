---
paths:
  - "intangibles/**/*"
---

# Intangibles — BR & Fielding Analytics

## Purpose
Multi-page Streamlit app for baserunning, outfield, infield, and catcher analytics. Same multi-page pattern as Arm Farm.

**Streamlit page convention (BLOCKING):** PDF-generation block goes LAST in any page script. See `.claude/rules/pdf-last-in-script.md`. Reference impl in this app: `pages/4_Catching.py:1655` (PDF below all main content, only glossary expander after).

**Deployed on Posit Connect.** App GUID: `295a5205-5568-4fb6-a759-26dc63bc9439`

## Key Files
- `intangibles/Intangibles.py` — Landing page (retro arcade)
- `intangibles/pages/1_Baserunning.py` — BR Postgame dashboard [LIVE]
- `intangibles/pages/2_Outfield.py` — OF Postgame dashboard [LIVE]
- `intangibles/pages/3_Infield.py` — IF Postgame dashboard [LIVE]
- `intangibles/pages/4_Catching.py` — Catcher report dashboard [CODE COMPLETE]
- `intangibles/src/br_data.py` — Statline + PBP queries
- `intangibles/src/br_report.py` — PDF generation (plottable tables, percentile coloring)
- `intangibles/src/br_percentiles.py` — Lead length percentile engine (1B + 2B distributions)
- `intangibles/src/of_postgame_data.py` — OF event-level play queries, error detection
- `intangibles/src/of_postgame_report.py` — OF daily PDF (landscape, plottable tables)
- `intangibles/src/of_postgame_percentiles.py` — OF season distributions (9 tracking KPIs + PAA)
- `intangibles/src/if_postgame_data.py` — IF event-level play queries, OPG infield
- `intangibles/src/if_postgame_report.py` — IF daily PDF (per-level, affiliate logos, KPI header)
- `intangibles/src/if_postgame_percentiles.py` — IF season distributions (8 tracking KPIs + OPG)
- `intangibles/src/catcher_data.py` — Catcher queries (864 lines)
- `intangibles/src/catcher_report.py` — Catcher PDF (1110 lines)
- `intangibles/src/catcher_percentiles.py` — Catcher percentile distributions
- `intangibles/src/of_individual_page.py` — OF Individual player page (app, called via render())
- `intangibles/src/if_individual_page.py` — IF Individual player page (app, called via render())
- `intangibles/src/of_individual_app_data.py` — OF Individual sidebar data (roster, sessions)
- `intangibles/src/if_individual_app_data.py` — IF Individual sidebar data
- `intangibles/src/of_weekly_data.py` — OF weekly/individual data (tracking, value, plays)
- `intangibles/src/if_weekly_data.py` — IF weekly/individual data
- `intangibles/src/of_weekly_report.py` — OF weekly/individual PDF
- `intangibles/src/if_weekly_report.py` — IF weekly/individual PDF
- `intangibles/src/hitter_advance_data.py` — Opposing hitter roster + BIP query + series detection
- `intangibles/src/hitter_advance_report.py` — Hitter advance PDF (2 KDE density heatmaps)
- `intangibles/src/fielding_base.py` — **SHARED MODULE** — Events_View architecture, position configs, filter functions
- `intangibles/src/database.py` — DB connection (dual-mode)
- `intangibles/scripts/generate_of_report.py` — OF daily CLI (single PDF, single channel)
- `intangibles/scripts/generate_if_report.py` — IF daily CLI (per-level PDFs, per-affiliate channels)

## Affiliate Tracker — Live vs Dead File Map (BLOCKING)

**BEFORE editing ANY file with "tracker" in the name, verify which one is live.** A prior refactor consolidated OF + IF trackers into a shared module but left the per-domain files on disk. They look live (same function names, same SQL shape) but nothing imports them.

| File | Status | Used by |
|------|--------|---------|
| `src/fielding_tracker_page.py` | **LIVE** | `pages/2_Outfield.py` and `pages/3_Infield.py` via `fielding_tracker_page.render("OF")` / `render("IF")` |
| `src/fielding_tracker_data.py` | **LIVE** | Imported only by `fielding_tracker_page.py` — single source for both OF + IF tracker SQL |
| `src/br_tracker_page.py` | **LIVE** | `pages/1_Baserunning.py` |
| `src/br_tracker_data.py` | **LIVE** | Imported only by `br_tracker_page.py` |
| `src/catching_tracker_page.py` | **LIVE** | `pages/4_Catching.py` |
| `src/catching_tracker_data.py` | **LIVE** | Imported only by `catching_tracker_page.py` |
| `src/of_tracker_page.py` | **DEAD** | Nothing. Marked for deletion in `intangibles/FIELDING_TRACKER_SPEC.md` |
| `src/of_tracker_data.py` | **DEAD** | Only imported by `of_tracker_page.py` (also dead) |
| `src/if_tracker_page.py` | **DEAD** | Nothing. Marked for deletion in `intangibles/FIELDING_TRACKER_SPEC.md` |
| `src/if_tracker_data.py` | **DEAD** | Only imported by `if_tracker_page.py` (also dead) |

**Verification command (run before every tracker edit):**
```bash
grep -rn "from.*<module_name>\|import <module_name>" intangibles/pages/ intangibles/scripts/
```
Zero hits → dead code. Do NOT edit.

**Why this matters:** Editing dead files produces zero runtime change. User redeploys, sees no difference, loses trust. Multiple sessions have wasted 4+ commits on these four files. Never again.

## IF Daily Report — Per-Level Slack Delivery

| Route Key | Channel Name | Channel ID |
|-----------|-------------|------------|
| mlb | pd-automation-test | `C0ABHSF6SCA` |
| aaa | sugarland_intangibles | `C0AKNKW1UKU` |
| aax | corpus_intangibles | `C0AL1HM1CDP` |
| afa | asheville_intangibles | `C0AK76YS1NK` |
| afx | fayetteville_intangibles | `C0AKNL9BGN6` |
| rok | fcl_intangibles | `C0AKG8WA267` |
| dsl | dsl_intangibles | `C0AK777QM47` |

**DSL/FCL Split:** Both use `level_code='rok'` in DB. Split by `sv.gc2_level_code`: `'dsl'` → route key `dsl`, `'rok'` → route key `rok`.

## Scripts — Daily Report Generators
- `scripts/generate_br_report.py` — BR postgame (per runner). Args: `--date`, `--level`, `--runner`, `--deliver`
- `scripts/generate_br_daily_report.py` — BR daily team report (all runners per level). Args: `--date`, `--level`, `--deliver`
- `scripts/generate_of_report.py` — OF daily postgame (single PDF, single channel). Args: `--date`, `--level`, `--deliver`
- `scripts/generate_if_report.py` — IF daily postgame (per-level PDFs, per-affiliate channels). Args: `--date`, `--level`, `--deliver`
- `scripts/generate_catcher_report.py` — Catcher postgame. Args: `--date`, `--level`, `--deliver`

## Scripts — Weekly KPI Reports
- `scripts/generate_br_kpi_report.py` — Weekly BR KPI (per-level). Args: `--end`, `--weeks`, `--level`, `--deliver`
- `scripts/generate_of_kpi_report.py` — Weekly OF KPI (per-level). Args: `--end`, `--weeks`, `--level`, `--deliver`
- `scripts/generate_if_kpi_report.py` — Weekly IF KPI (per-level). Args: `--end`, `--weeks`, `--level`, `--deliver`
- `scripts/generate_c_kpi_report.py` — Weekly Catcher KPI (per-level). Args: `--end`, `--weeks`, `--level`, `--deliver`

## Scripts — Weekly Player Reports
- `scripts/generate_of_weekly_report.py` — Single OF player weekly report. Args: `--player-id`, `--start-date`, `--end-date`
- `scripts/generate_of_weekly_batch.py` — Batch all OF players. Args: `--start-date`, `--end-date`, `--level`, `--deliver`
- `scripts/generate_if_weekly_report.py` — Single IF player weekly report
- `scripts/generate_if_weekly_batch.py` — Batch all IF players

## Scripts — Advance Scouting
- `scripts/generate_hitter_advance.py` — Opposing hitter defensive positioning. Args: `--level`, `--series`, `--deliver`, `--logic-app-url`, `--diagnostic`
- Data: `src/hitter_advance_data.py` — roster, BIP query, series detection (same flow as Barrelsville pitching advance)
- Report: `src/hitter_advance_report.py` — PDF: navy header + 2 KDE density heatmaps (IF LA<15 & dist<150ft, OF LA>=15 & dist>=150ft)

## Fielding Tier System (fielding_base.py) — SHARED ACROSS PD GOALS

### Three Tiers
| Tier | Purpose | Filter | Used For |
|------|---------|--------|----------|
| **Tier 1** (KPI) | Physical tool metrics | 6-term: `OM + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= floor) > 0` | React, TopSpd, AccelCD, AccelCU, Arm, Exchange, UseReact, ReactRad |
| **Tier 2** (Plays) | Display-worthy plays | 6-condition OR filter (1stD, CP+out_prob, bearing fallback, wall_ball) | Play tables in weekly reports |
| **Tier 3** (Difficulty) | Routine play conversion | `first_defender_id = fielder_id AND out_prob IS NOT NULL` | Difficulty buckets (Routine/Extended/Good/Great/Elite) |

### Position Configs
| Position | pos_ids | Arm Floor | Arm Ceiling | UseReact? | Exchange Col |
|----------|---------|-----------|-------------|-----------|--------------|
| OF | (7,8,9) | 75 | 108 | Yes | `exchange` |
| IF | (3,4,5,6) | 70 | 108 | No | `exchange_dp` |

### Metric Aggregation (all Tier 1 rows, no additional CP gate)
| Metric | Percentile | Extra Filter | Higher=Better |
|--------|-----------|--------------|---------------|
| TopSpd | 95th | `top_speed <= 34` | Yes |
| AccelCU | 75th | — | Yes |
| AccelCD | 75th | — | Yes |
| React | 25th | — | No (lower=faster) |
| UseReact | 25th | OF only | No (lower=faster) |
| ReactRad | 25th | — | No (lower=tighter) |
| ReactAccRad | 25th | — | No |
| Arm | 99th | `arm >= floor AND <= 108` | Yes |
| Exchange | 10th | `exchange >= 0.4` | No (lower=faster) |

### Difficulty Buckets (Tier 3)
| Label | out_prob Range |
|-------|---------------|
| Routine | 0.90 - 1.00 |
| Extended | 0.75 - 0.90 |
| Good | 0.50 - 0.75 |
| Great | 0.25 - 0.50 |
| Elite | 0.00 - 0.25 |

Routine play conversion = `AVG(out_made) * 100` on plays where `out_prob >= 0.90`.

### Data Sources
- `Astros.Tracking_Defensive_Metrics` — per-play tracking (BIT: competitive_play, competitive_throw)
- `Astros.Defense_Combined_By_Pos` — defensive value (BIT: out_made, competitive_play, competitive_throw)
- BIT columns: ALWAYS `CAST(col AS int)` or `CAST(col AS float)` before SUM/aggregation

## App ↔ Report Parity Rule — BLOCKING
When changing ANY filter, tier gate, or rendering logic on a report OR app page, **ALWAYS update BOTH**. Even if the user only mentions one, the other must match. This applies to:
- Display tier filters (spray chart, play table)
- Direction rose (Tier 1 + HawkEye gate)
- Difficulty chart (Tier 3: first_defender + out_prob)
- KPI bar aggregation and percentile logic
- Any new visual section added to either side

The app's PDF download button calls the report generator with the same data — so filters applied inside the report function and inside the app rendering must produce identical results.

**Files that must stay in sync (OF example):**
| Section | Report (`of_weekly_report.py`) | App (`of_individual_page.py`) |
|---------|-------------------------------|-------------------------------|
| Spray | `_display_tier_filter()` before render | `_display_tier_filter()` before render |
| Direction rose | Tier 1 + `fielder_direction_txt` not null | Tier 1 + `fielder_direction_txt` not null |
| Difficulty | `first_defender == "Y"` + `out_prob` not null | `first_defender == "Y"` before `bucket_plays_by_difficulty()` |
| Play table | `_display_tier_filter()` | `_display_tier_filter()` |
| KPI bars | Same DB query | Same DB query |

Same pattern applies to IF (`if_weekly_report.py` ↔ `if_individual_page.py`).

## Personal Records — Tier 1 Gated (Updated Apr 16, 2026)
`get_player_all_time_bests()` in `of_postgame_data.py` / `if_postgame_data.py` queries a player's career-best tracking values (MAX TopSpd, MIN React, etc.) for PR detection on daily postgame reports.

**Uses the full 6-term Tier 1 gate** (DCBP join + OM+DCBP.CP+DCBP.CT+TDM.CP+TDM.CT+arm>=floor). PRs only come from Tier 1 plays — not random non-competitive tracking noise. The inner `cp_ok` flag for PR detection includes CT: `TDM.CP == 1 OR DCBP.CP == 1 OR TDM.CT == 1`. Previously had no gate at all (any TDM play counted), then briefly used CP=1 (same bug as everywhere else).

## Daily Postgame Play Table — Display Tier Filtered
OF daily uses 6-condition `_display_tier_filter()`, IF daily uses 4-condition version. Same filters as weekly individual reports. Defined in `of_postgame_report.py` and `if_postgame_report.py`.

### IF daily — non-fielding outs excluded (DSL only, Jun 2026)
`get_daily_if_plays` row-inclusion gate:
`DCBP NOT NULL OR TDM NOT NULL OR (first_defender = player AND (pv.pitch_id IS NOT NULL OR gc2_level_code <> 'dsl'))`.
**DSL only**: the first-defender branch requires a batted ball (`pv.pitch_id IS
NOT NULL` = a BIP-ending pitch, `pitch_result_id IN (12,13,14)`), which drops
**strikeouts** where the 1B is tagged `first_defender` but no ball was put in
play — they carried no tracking, no PAA, no video and just produced blank rows.
Routine + near-impossible plays still qualify (they have a BIP pitch);
dropped-third-strike putouts that GC2 records in DCBP still qualify via DCBP.
**All other levels keep the original open gate** (the `<> 'dsl'` clause preserves
it) — zero change outside DSL. Single data path, so the CLI and the Infield app
page both get the filtered rows.

**OF daily got the SAME DSL-only gate (Jun 2026).** `get_daily_of_plays`
first-defender branch is now
`(ev.first_defender_id = pg.groundcontrol_id AND (pv.pitch_id IS NOT NULL OR
gc2_level_code <> 'dsl'))`. OF's bearing-zone fallback branch already requires
`ev.fo = 1` (a batted fly ball) so it needs no DSL change. The DCBP/TDM branches
are unchanged. Other levels unchanged.

## Batch CLI Rule — BLOCKING
When writing ANY batch CLI script (`scripts/generate_*.py`), MUST verify:
1. Every import name exists in the target module
2. Every function call uses the exact parameter names from the function signature
3. Diagnostic functions exist before importing them
4. Data collected as dicts must be unpacked to match report function params
Read the target function signature before writing the call.

## Scripts — KPI Snapshot & Analysis
- `scripts/generate_kpi_snapshot.py` — Position player **KPI snapshot** PDF (OF/IF/BR/C). Args: `--position`, `--season`, `--level`, `--spring`
  - **TBD (Apr 25, 2026):** needs `--deliver` + `--logic-app-url` CLI flags wired to route to **weekly-player-updates** (`C0AVBKPEG8H`, Zac + Sam) — same pattern shipped on Barrelsville `kpi_snapshot_3.py` (commit `cac02cb`) and Arm Farm `pitcher_kpi_snapshot.py` (commit `329d229`). Run a metric-audit pass first (diff vs `c_kpi_data.py` / `of_kpi_data.py` / `if_kpi_data.py` / `br_kpi_data.py` and the canonical `pitch-codes.md`) before shipping. See `delivery.md` "Analysis + Snapshot Delivery" section for the pattern.
- `scripts/generate_pickoff_report.py` — Pickoff outs report (video analysis)
- `scripts/tagup_2to3_analysis.py` — Tag-up 2nd-to-3rd multi-page analysis
- `scripts/build_guide_pdf.py` — OF/IF fielding report technical guide

## Catcher KPI Metric Standardization (Updated Apr 16, 2026)
- **NetK:** Cumulative `SUM(pv.net_k)` everywhere (postgame, KPI, snapshot, org reports, H2H, percentile pool). Display f1-f2. NetK/P (per-pitch rate) ONLY in affiliate tracker as second column alongside NetK. See `gc2-metrics.md` for full reference. Gate: `called_strike_chance` (not `_mlb`), strict `> 0.05 AND < 0.95`, result_id `(4,5,6)`, `pv.net_k` column, `ignore_flag=0`.
- **SurPP, FramRAA, BlockRAA:** Cumulative in KPI chart. Match tracker formula (PP-xPP, edge-zone RV, surpp×br_rv).
- **R2K%:** GC2 formula — ab_pitch_number=3, strikes_after>=2, gated by (pa=0 OR so=1). Switched Apr 13 2026.
- **AugPop2B:** Match tracker formula exactly.
- **Framing buckets (E Stl, Stl, Mid, Loss, B Loss):** `compute_framing_buckets()` empty fallback includes `_frac` keys (fixed Apr 6).
- **Pre2K IZ%:** `AVG(csc) * 100` on pre-2-strike pitches (fixed Apr 10 — was binary `csc > 0.5` count, now matches Arm Farm continuous AVG standard).
- **Strike zone width:** ±0.708 ft ABS standard (fixed Apr 10 — was ±0.939, now matches all apps).
- **Setup click-to-video:** Added Apr 11 — catcher setup charts (pitcher-by-pitcher faceted grid) now have click-to-video. Query adds `pv.sched_id`, `pv.pitch_id`, `vid.video_url` via `Astros.Video` (angle_id=1). App uses `@st.fragment` + `on_select` + `_handle_chart_click(video_url_index=2)` — same pattern as SZ/throws/blocks panels.

## OF/IF Weekly Report — Year to Date Boxes (Apr 11, 2026; rendering gate fix Apr 27, 2026)

Bottom of KPI page (page 2), left 60% (x=0.03–0.68). 8 percentile-colored boxes showing season-long values.

**⚠️ DESIGN IS SUBJECT TO CHANGE.** The structure documented here (which fields are cross-level, how ranks are scoped, the 10-event gate, the hide-vs-show-NA behavior) reflects current intent as of Apr 27, 2026. Box layout, scoping, and the specific design-quirk choices below may all evolve. When making future changes, update THIS section in lockstep — three-surface parity does not apply (YTD is PDF-only) but cross-worktree rule sync does.

### Data Functions
- `get_player_season_tracking(gcid, level=None, season)` — wraps `get_player_weekly_tracking` with Jan 1–Dec 31. ALL levels, R games only.
- `get_season_ranks(gcid, level, season, position)` — queries all players at level with 10+ Tier 1 events, aggregates per-player, ranks target player.

### Each Box Shows
1. **Metric label** with percentile aggregate: e.g., `TopSpd (P95)`
2. **Large season value** (same P95/P75/P25/P99/P10 as battery bars above)
3. **Percentile ordinal** (e.g., "62nd") — colored by season distribution
4. **Lvl Rank:** `#3/45` — rank among ALL players at level (all orgs), 10+ Tier 1 gate
5. **Org Rank:** `#1/8` — rank among HOU org players at level only

### Key Rules
- **Player season values:** `level=None` (all levels, all games). Same rule as weekly tracking — no level filter on the player's own data.
- **Rank pool:** Scoped to `primary_level`. 10+ Tier 1 events gate. R games only.
- **Org determined by:** `PP_MASTER.ORG_LK` for each player in the pool.
- **If date range = full season:** YTD box values would match the battery bars exactly (same function, same gate, same aggregates).

### Cross-level vs level-scoped — exactly what each field does

| Box element | Pool | Player value used |
|---|---|---|
| YTD value (e.g. `28.4 mph`) | n/a | **Cross-level** — full season, all levels combined |
| Percentile ordinal + bg color | Current level's season distribution | Cross-level value ranked against current-level pool |
| Lvl Rank `#3/45` | Current level only, 10+ Tier 1 events to enter pool | Player's **current-level-only** aggregate |
| Org Rank `#1/8` | Current level × HOU only, 10+ Tier 1 events | Same as Lvl Rank |

A just-promoted player with <10 Tier 1 events at the new level will see the YTD value, percentile, and color populate, but the Lvl/Org rank lines hide until they accumulate.

There's a known apples-to-oranges quirk on the box itself: the displayed YTD value is cross-level, but the rank uses the level-only aggregate. The two numbers can disagree for cross-level fielders. Design intent is preserved: "rank is where you sit at the level you're at; value is your true year-to-date skill."

### Rendering gate — BLOCKING (Apr 27, 2026 — commit `9583f8a`)

Both `of_weekly_report._draw_ytd_boxes()` AND `if_weekly_report._draw_ytd_boxes()` MUST gate on `season_tracking` only:

```python
# WRONG — entire YTD section disappears for just-promoted players
if season_tracking and season_ranks:
    _draw_ytd_boxes(fig, season_tracking, season_ranks, ...)

# RIGHT — value+percentile+color show; per-metric rank lines hide gracefully
if season_tracking:
    _draw_ytd_boxes(fig, season_tracking, season_ranks or {}, ...)
```

**Why this matters:** `get_season_ranks()` returns `{}` when the player has fewer than 10 Tier 1 events at the current level (rank-pool gate). Empty dict is falsy. Naive `season_tracking and season_ranks` check fails, the entire YTD section is suppressed, and a just-promoted player who has 4 months of cross-level data gets a blank YTD page even though `season_tracking` is fully populated.

The renderer's per-metric guards at `_draw_ytd_boxes` (`if rank is not None` for both `lvl_str` and `org_str`) already handle missing rank data gracefully — they just hide the Lvl/Org lines on a per-metric basis. Gating only on `season_tracking` lets those guards do their job.

### Design quirks — known, NOT bugs (do not "fix" without user direction)

These are conscious design choices documented for future agents:

| Quirk | Today | Alternatives if user ever asks |
|---|---|---|
| 10-event pool gate (`of_weekly_data.py:236`) excludes just-promoted players from rank entirely | Lvl/Org rank hidden until they cross 10 Tier 1 plays at the new level | Drop the gate (introduces noise from tiny samples) |
| Value-vs-rank apples-to-oranges (cross-level value displayed, level-only value used for rank) | Status quo — preserved by both fixes above | Use cross-level value for ranking too — unfair to non-cross-level peers ranked on their level-only number |
| Hide-vs-show-NA for missing per-metric rank | Currently HIDE (rank line just doesn't render) | Show `n/a (X plays)` to make the gate explicit to coaches |

If users complain, #3 is the most honest UX change. #1 introduces noise. #2 is the apples-to-oranges trap. None are wrong today.

### Files
| Component | OF | IF |
|-----------|----|----|
| Season tracking | `of_weekly_data.get_player_season_tracking()` | `if_weekly_data.get_player_season_tracking()` |
| Season ranks | `of_weekly_data.get_season_ranks()` | `if_weekly_data.get_season_ranks()` (delegates to OF) |
| YTD drawing | `of_weekly_report._draw_ytd_boxes()` | `if_weekly_report._draw_ytd_boxes()` (delegates to OF) |
| Single CLI | `generate_of_weekly_report.py` (steps 7-8) | `generate_if_weekly_report.py` (steps 7-8) |
| Batch CLI | `generate_of_weekly_batch.py` | `generate_if_weekly_batch.py` |

### App parity — N/A
YTD boxes are PDF-only. The Streamlit app pages (Outfield, Infield) do NOT render them — `pages/` directory has zero references to `season_tracking` / `season_ranks` / `ytd`. App↔Report parity rule does not apply for this feature.

## OF/IF KPI Metric Standardization (Audited Apr 6, 2026)
All fielding KPI metrics verified identical to weekly/postgame/tracker:
- Same Tier 1 gate, same percentiles (P95/P75/P25/P99/P10), same arm floors (OF=75, IF=70)
- PAA/EO and RAA/EO use same calibration offsets (`guts.PAA_EO_Position_Calibration`)
- KPI uses SQL PERCENTILE_CONT; weekly uses Python np.percentile — algebraically identical

## Percentile Standardization (Apr 7, 2026)
**All 6 KPI reports** — L2W span table uses season-wide percentile distribution for coloring.
Players always display regardless of volume. Pool gate controls who enters the distribution.
Span threshold controls who gets colored. Season threshold = pool gate threshold.

### KPI Percentile Pool Gates (Apr 7, 2026)
| Report | Volume Metric | Pool Gate | Span Display | Season Display |
|--------|--------------|-----------|-------------|----------------|
| OF KPI | Competitive Plays | 10+ Tier 1 events | 1+ CP | 10+ CP |
| IF KPI | Competitive Plays | 10+ Tier 1 events | 1+ CP | 10+ CP |
| BR KPI | Bases On | 50+ bases on | 5+ bases on | 50+ bases on |
| Catcher KPI | Pitches Received | 1500+ pitches | 500+ pitches | 1500+ pitches |
| Hitter KPI | PA | 50+ PA | 20+ PA | 50+ PA |
| Pitcher KPI | Pitches | 300+ pitches | 50+ pitches | 300+ pitches |

**Pool gate** = who enters the percentile distribution (prevents low-volume players from diluting ranks).
**Span display** = minimum to get colored in L2W table (value still shows, just no color below this).
**Season display** = minimum to get colored in season table (same as pool gate for BR/C/H/P).

**OF/IF Weekly Individual Reports:**
- `aggregate_tracking()` uses `min_obs=1` — any tracked value shows a bar (no n>=3 gate on player)
- Distribution pool: season-wide, 10+ Tier 1 events, per-metric n>=3 quality gate (pool only)
- Spray chart aligned to same display tier filter as play table (OF: 6 conditions, IF: 4 conditions)
- Daily postgame and weekly individual use identical `_display_tier_filter()` logic

**OF/IF Weekly Batch CLI** — simplified to `--end` (required), `--start-date` optional (default: end - 6 days).
Matches hitter weekly pattern. Delivery: `--deliver` (zzz) + `--deliver-z` (z athlete channels).
Hitter weekly also got `--deliver-z` flag added.

**OF/IF Weekly Glossary** — 3-column layout: Report Contents EN + Contenido ES (left), Methodology EN (mid), Metodología ES (right). Spanish in italics.

## OF/IF Individual App Architecture (Fixed Apr 7, 2026)

**Flow:** Level → Player → Sched Type → Period → Game(s) → render data + PDF download.

### Sidebar Pattern (matches Barrelsville/Arm Farm postgame)
1. **Level dropdown** → passes `level_code` to roster query
2. **Roster query** → `Players_Games` with 365-day lookback (`DATEADD(DAY, -365, GETDATE())`), filtered by `DATA_SCHED_TYPES` (`R/S/E/V/I`). No year filter — FCL/DSL always populate.
3. **Player dropdown** → selected `groundcontrol_id`
4. **Sched Type multiselect** → auto-detects most recent game's type on player change
5. **Period radio** → Selected Dates / Recent Outing / Last 2 Weeks / Last Month
6. **Game multiselect** → filtered by sched_type + date range

### SCHED_TYPE_OPTIONS (shared from `br_app_data.py`)
All 7 types: `R`, `S`, `E`, `V`, `I`, `_WIN`, `_BBC` — matches Barrelsville/Arm Farm postgame.

### Data Flow
- App passes single `sched_type` string (or None) to data functions
- CLI passes same single string via `--sched-type` arg
- Data functions use `_sched_type_filter()` which expands None → all DATA_SCHED_TYPES
- **Weekly reports only run on R games** — CLI default is R-only

### Key Files
| Component | OF | IF |
|-----------|----|----|
| App page | `of_individual_page.py` | `if_individual_page.py` |
| App data (roster, sessions) | `of_individual_app_data.py` | `if_individual_app_data.py` |
| Weekly data (tracking, value, plays) | `of_weekly_data.py` | `if_weekly_data.py` |
| Weekly report (PDF) | `of_weekly_report.py` | `if_weekly_report.py` |
| Batch CLI | `generate_of_weekly_batch.py` | `generate_if_weekly_batch.py` |
| Single CLI | `generate_of_weekly_report.py` | `generate_if_weekly_report.py` |

## Difficulty Buckets (Tier 3 — `out_prob`-based)

Tier 3 filter: `first_defender_id = fielder_id AND out_prob IS NOT NULL`.

| Bucket | out_prob Range | Boundary |
|--------|---------------|----------|
| Routine | > 0.90 | exclusive lower |
| Extended | (0.75, 0.90] | exclusive lower, inclusive upper |
| Good | (0.50, 0.75] | exclusive lower, inclusive upper |
| Great | (0.25, 0.50] | exclusive lower, inclusive upper |
| Elite | <= 0.25 | inclusive upper |

**Expected** = `AVG(out_prob)` — what the average fielder converts in that bucket.
**Actual** = `AVG(out_made)` — what this player converted (0 or 1 per play).
**Gap** = Actual - Expected — positive means beating expectation (same concept as OAA by difficulty tier).

Implementation: `bucket_plays_by_difficulty()` in `of_weekly_data.py` / `if_weekly_data.py`.

## KPI Report + App File Map (EVERY KPI has BOTH a PDF report AND a Streamlit app page)
| KPI | Data | Report (PDF) | App Page (Plotly) | Streamlit Entry |
|-----|------|-------------|-------------------|-----------------|
| OF | `of_kpi_data.py` | `of_kpi_report.py` | `of_kpi_page.py` | `pages/2_Outfield.py` → view=kpi |
| IF | `if_kpi_data.py` | `if_kpi_report.py` | `if_kpi_page.py` | `pages/3_Infield.py` → view=kpi |
| BR | `br_kpi_data.py` | `br_kpi_report.py` | `br_kpi_page.py` | `pages/1_Baserunning.py` → view=kpi |
| Catcher | `c_kpi_data.py` | `c_kpi_report.py` | `c_kpi_page.py` | `pages/4_Catching.py` → view=kpi |

| KPI | Data | Report (PDF) | App Page (Plotly) | Streamlit Entry |
|-----|------|-------------|-------------------|-----------------|
| Hitter | `hitter_kpi_data.py` | `hitter_kpi_report.py` | `pages/5_KPI_Report.py` (inline) | `pages/5_KPI_Report.py` |
| Pitcher | `pitcher_kpi_data.py` | `pitcher_kpi_report.py` | `pages/5_Pitcher_KPI.py` (inline) | `pages/5_Pitcher_KPI.py` |

**When changing ANY KPI chart/table logic, ALWAYS update BOTH the report AND app page.**

### KPI Table Sort Orders (Apr 7, 2026)
| Report | Primary Sort | Secondary Sort |
|--------|-------------|----------------|
| OF KPI | UseReact asc (fastest) | CP desc |
| IF KPI | React asc (fastest) | CP desc |
| BR KPI | SB desc | Bases On desc |
| Catcher KPI | NetK desc | Pitches desc |

### KPI Chart X-Axis (Apr 7, 2026)
All 12 chart renderers (6 reports + 6 apps): ticks at 1st of each month, x-limits = `min(first_tick, data_min) - 2 days` to `max(last_tick, data_max) + 2 days`. Rank boxes at last HOU data point per month (not calendar month-end).

## BR KPI Report Architecture (Apr 7, 2026)
**Charts (2 rows):**
- Top row (cumulative): SB, 1→3, 2→H — `_cum` suffix, 30 org lines + HOU navy
- Bottom row (rolling 4-month avg): 1B PL, 1B SL — raw column, not `_cum`
- Y-axis: decimals for small-range metrics (leads), ints for cumulative

**Table columns:** Player, Bases On, SB, CS, 1→3, 2→H, PL 1B, SL 1B, PL 2B, SL 2B
**Sort:** SB descending, then bases on descending
**Pool gate:** 50+ bases on enters distribution. Fraction pctiles (ft3/s2h) also gated.

**Files:** `br_kpi_data.py` (data + constants), `br_kpi_report.py` (PDF), `br_kpi_page.py` (app)

### BR KPI Fix (Apr 6, 2026)
- `_get_org_mapping()` was missing `ha_filter` parameter — broke BR KPI app after H/A split feature
- H/A split is tracker-only, KPI passes `ha_filter=""` (no filter) — fixed function signature + 2 call sites

## Catcher Report — 7-Bucket Framing System

| Bucket | CSC Range | Color | Meaning |
|--------|-----------|-------|---------|
| E Stl | 0-5% | #1B5E20 (dk green) | Extra steal |
| Stl | 5-25% | #66BB6A (green) | Steal |
| Mid+ | 25-50% | #42A5F5 (blue) | Mid gain |
| Exp | matched | #BBBBBB (grey) | Expected |
| Mid− | 50-75% | #FDD835 (yellow) | Mid loss |
| Loss | 75-95% | #FF9800 (orange) | Loss |
| B Loss | 95-100% | #F44336 (red) | Bad loss |

**Key format:** `E Stl (0-5%) · Stl (5-25%) · Mid+ (25-50%) · Exp · Mid− (50-75%) · Loss (75-95%) · B Loss (95-100%)`

### Catcher Report Details
- **NetK table columns:** Full Season (percentile colored) | Game (green/red vs opp) | Opp C name (inverse green/red) | H2H (W-L or W-L-T total season record vs ALL opponent catchers)
- **NetK H2H record (Apr 15, 2026):** `get_netk_vs_record()` in `catcher_data.py`. Two-step query: (1) resolve our_team_id, (2) ALL games this season where our catcher played — inline NetK per game per side, pivot in Python. No params — all values formatted directly to avoid SQL Server errors 144/8180. Record includes current game. Shows in PDF report (`catcher_report.py`) + Streamlit app (`4_Catching.py`).
- **NetK win/loss coloring:** Game column green if ours > opponent, red if <. Opp column inverse. Season = league-wide percentile. Uses `tab.cells[0, col]` (not text matching).
- **AugPop2B:** Between Pop and Exch in per-throw table.
- **2B throws visual:** Dark panes `#111` inside 3D cube, no gridlines, white 2B bag diamond. Pop time colorbar nudged up.
- **Depth distribution fallback:** `get_player_depth_distribution_by_side()` falls back to prior year if current season < 2 games. Per-level, per-bat-side.

### Cross-Module Pop Time Sources
| Module | Source Table | Status |
|--------|-------------|--------|
| R App (CatchMeIfYouCan) | `CatcherDefense_Throwing.pop_time` | PRODUCTION |
| Catcher Postgame | `CatcherDefense_Throwing.pop_time` + `SBA_Metrics.aug_pop` | LIVE |
| BR Postgame | `CatcherDefense_SBA_Metrics.pop` | LIVE |
| Catcher Tracker | `TDM.pop_time` (PERCENTILE_CONT P01) | LIVE |

## Hitter Advance — BIP Filters & Scope

### PA Scope Logic (same as pitching advance IP scope)
1. Count R-only PA in current season at level
2. If >= 100 PA → use ALL current season R sched_ids (uncapped)
3. If < 100 PA → wide net (R/S/E/I) + backfill from prior years until 100 PA
- `_get_batter_scope_sched_ids()` handles the two-pass logic

### BIP Filter Criteria
- **IF visuals:** LA < 15 AND distance < 150ft
- **OF visuals:** LA >= 15 AND distance >= 150ft
- BIPs outside both criteria: excluded from all visuals

### Wedge Chart Zones
- **IF (4 equal wedges):** bearing -45 to +45, 22.5° each, radius 0-150ft
- **OF (3 equal wedges):** bearing -45 to +45, 30° each, radius 150-330ft
- Green gradient: white (#FFFFFF) → dark green (#1B5E20), scaled to max %

### KDE Colormap
`['#FFFFFF', '#90CAF9', '#42A5F5', '#FF9800', '#F44336']` (matches Barrelsville)

## Home/Away Split — Direction Mapping

All 6 affiliate trackers have H/A filter. `_build_ha_filter(ha_split)` → `{ha_filter}` in SQL WHERE.

**toi (top_of_inning) direction mapping — NON-OBVIOUS:**
| Domain | Home | Away | Why |
|--------|------|------|-----|
| Batting / BR | toi=0 | toi=1 | Home bats bottom of inning (toi=0) |
| Pitching / Fielding / Catching | toi=1 | toi=0 | Home fields top of inning (toi=1) |

**Dead tracker files (superseded by shared `fielding_tracker_*`):**
`of_tracker_page.py`, `if_tracker_page.py`, `of_tracker_data.py`, `if_tracker_data.py` — NOT used at runtime.

## Video Fallback Order (OF/IF/BR)
- **OF/BR MLB Main:** M → V → B → X (V second in all OF main)
- **OF/BR MiLB Main:** M → V → A (V second)
- Side chains: position-specific (LF/CF/RF)
- **IF daily report (`if_postgame_data.py`) — DSL leads with angle `D`, not CF** (Jun 2026).
  The CF broadcast angle does not show the infielders. The DSL feed's
  overhead-infield camera is angle **`D`** (verified by eye across multiple DSL
  games — `'H'`/high-home and `'F'`/`'7'` corner-high were all wrong for DSL).
  **`D` is UNIVERSAL across the whole DSL league (verified Jun 2026):** a
  league-wide angle audit across every DSL field — every team's home park,
  i.e. what HOU plays at on the road — confirmed `D` is the overhead-infield
  angle at ALL of them, so it's correct for HOU **away** games too. The side
  `B`/`C` angles are also universal in meaning but PRESENT only at a few parks
  (HOU + Brewers + Cleveland in the audit) — elsewhere the side falls back to
  CF `A`. Audit query: `sql-queries/dsl-high-home-angle-audit.sql`.
  DSL also records neither `M` nor `V`, so the old `M → V → A` chain always
  resolved to the CF `A` angle — the wrong video that was showing. DSL now uses
  its own branch `_DSL_MAIN = D → M → V → A` (falls back to old behavior if `D`
  is missing). DSL detected via `sv.gc2_level_code = 'dsl'`. **All other levels
  (MLB + AAA/AA/A+/A/FCL) keep their ORIGINAL chains unchanged** — their correct
  infield angle is unverified, so do NOT touch them. To identify the right angle
  for another level, run `sql-queries/dsl-if-one-play-all-angles.sql` (per-play
  angle dump) at that level and confirm by clicking each URL.
  - **DSL SIDE video is position-dependent** (user request Jun 2026): left side
    3B (pos 5) / SS (pos 6) → angle `C`; right side 1B (pos 3) / 2B (pos 4) →
    angle `B`. Both fall back to CF `A` → `M`/`V` so a link is never lost. Keyed
    on `pg.pos_id` in the side `CASE`. Note `B`/`C` only exist in ~10 of 18 DSL
    games, so the side falls back to CF `A` on the rest.
  - **Dead-link handling** (Jun 2026): a row can exist in `Video_Network` with a
    `video_url` whose FILE is missing (HTTP 404). SQL's `ISNULL` picks that
    non-null url and shows a dead link — SQL can't detect a missing file. The
    CLI path (`get_daily_if_plays(..., validate_side_urls=True)`) HEAD-checks the
    angle the DSL side actually **resolved to** (B/C *or* the CF `A` fallback)
    via `_validate_dsl_side_urls`, and on a definitive 4xx **swaps to CF `A` if
    that's live, else BLANKS the link** (no link beats a 404). This covers the
    doubleheader case where game 1 ran a minimal 2-camera setup (D + A only) and
    fell to CF `A`, but the CF feed itself is dead → side blanks instead of
    404'ing. FAIL-OPEN: timeouts / connection errors / non-4xx leave the link
    unchanged, so a slow/down video host is never worse than today. DSL rows only
    (gated on `gc2_level_code`). The live app (`if_postgame_page`) skips
    validation to stay fast — minor app/PDF divergence on dead links only.
- **OF daily report (`of_postgame_data.py`) — SAME DSL fix as IF** (user
  direction Jun 2026). The OF main had the identical problem: the old
  `M → V → A` chain resolved to CF `A` on DSL, which doesn't show the play.
  DSL now leads with the high-home/overhead angle `D` (the SAME angle the IF
  DSL report uses): `_DSL_OF_MAIN = D → M → V → A`. MLB + other MiLB main
  chains unchanged.
  - **DSL OF SIDE is a SINGLE chain for all OF positions** (user direction —
    NOT position-split like IF): `_DSL_OF_SIDE = C → B → A → M → V` (corner
    cameras DSL records, then CF `A`, then `M`/`V` so a link is never lost).
    Keyed on `sv.gc2_level_code = 'dsl'` in the side `CASE`, ahead of the
    per-position MiLB branches.
  - **Dead-link handling — validates BOTH Main and Side** (`of_postgame_data.py`,
    `_validate_dsl_video_urls`). A dead 404 on the Main `D` link or the Side
    `B`/`C` link is swapped to its CF `A` fallback (`dsl_main_fallback_url` /
    `dsl_side_fallback_url`) when that's live, else BLANKED. Fixes the "Main
    only opens when a Side exists" symptom — a no-upload DSL game leaves both
    `D` (main) and `B`/`C` (side) files missing, so without main validation the
    Main rendered a clickable `▶` that 404'd while the side correctly blanked.
    CLI passes `get_daily_of_plays(..., validate_side_urls=True)`; live app
    (`of_postgame_page`) keeps the default `False`. Fail-open; DSL rows only.
    **OF validates the Main; IF's `_validate_dsl_side_urls` still validates
    the Side only** — port the Main check to IF if the same dead-Main symptom
    shows there.
  - **DSL EV/Dist/Hang left as-is** (user direction Jun 2026). Those come from
    `Astros.Hits` and are unreliable at non-HawkEye DSL venues (internally
    inconsistent hang-vs-distance, templated duplicate values) — a source-data
    limitation, NOT a code bug. Coaches read DSL EV with a grain of salt; no
    suppression applied.
  - Report structure unchanged — angle wiring only. `_ALL_ANGLES` gains `'D'`.

## Known Gaps — Weekly OF/IF Reports
1. No `_shorten_desc()` — play descriptions unabbreviated in table
2. No error detection (thr_e/fld_e) — can't flag throwing vs fielding errors
3. No junk I-game filter — intrasquad singles pass through
4. No PR detection — no personal record highlights in weekly (only in daily postgame)

## Fielder Direction (Direction Rose Data Source)
- `Astros.Fielder_Direction` — **ACTIVELY USED** in OF/IF weekly reports for the direction rose.
- Joined as `fd` in `of_weekly_data.py` / `if_weekly_data.py`. Columns: `fd.direction`, `fd.direction_bin`, `fd.direction_txt`.
- Direction rose uses `fielder_direction_txt` only (real tracked movement). Plays without it are excluded from the rose.
- 8 bins: Going Back, Back-Left, Moving Left, In-Left, Coming In, In-Right, Moving Right, Back-Right.
- Size = play count per bin, color = avg PAA (red=negative, green=positive).
- IF-only angle fields (`fielder_move_angle_at_field`, `player_move_dir_angle_at_throw`) are in `Out_Probs_Infield_Defense_Attributes` — separate table, not used.

## Discovered Tables (Not Yet Used)
- `Astros.Similar_Outfield_Plays` — Worth exploring for future features.

## Reference Docs
- `intangibles/BR_DATA_REFERENCE.md` — Full table schemas and metric calculations
- `intangibles/docs/OF_FIELDING_QUERY_STANDARD.md` — 3-tier query architecture
- `intangibles/VIDEO_ANGLE_REFERENCE.md` — Video angle tables
