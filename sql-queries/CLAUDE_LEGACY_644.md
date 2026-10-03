# BSB Resources - Project Memory

## Repository Overview
Houston Astros Baseball Operations analytics codebase. Multiple sub-projects for player development tools.

## Projects Summary

| Project | Branch | Status | Key Directory |
|---------|--------|--------|---------------|
| **PD Goals** | `feature/pd-goals` | LIVE on Posit Connect | `pd-goals/` |
| **Astros Arm Farm** | `feature/bullpen-reports` | LIVE (Feb 16, 2026) | `bullpen-report/` |
| **Postgame Pitcher** | `feature/bullpen-reports` | DEPLOYED | `bullpen-report/pages/2_Postgame.py` |
| **Bullpen Reports** | `feature/bullpen-reports` | LIVE on Posit Connect | `bullpen-report/pages/1_Side_Reports.py` |
| **Astros Intangibles** | `feature/astros-intangibles` | IN PROGRESS | `intangibles/` |
| **Affiliate Tracker** | `feature/bullpen-reports` | ALPHA V1 | `bullpen-report/pages/3_Affiliate_Tracker.py` |
| **Astros Barrelsville** | `feature/barrelsville` | DEPLOYED on Posit Connect | `barrelsville/` |

### Astros Intangibles (Active — Mar 13, 2026)
- **BR Postgame:** LIVE on Posit Connect. PDF + app working.
- **Catcher Report:** CODE COMPLETE — `catcher_data.py`, `catcher_report.py`, `catcher_percentiles.py`, `catcher_app_data.py`, `pages/4_Catching.py`. Awaiting work laptop testing.
- **OF Daily Postgame:** TESTED & POLISHED (Mar 7). Single PDF all levels → single channel delivery.
- **IF Daily Postgame:** CODE COMPLETE (Mar 13). Per-level PDFs → per-affiliate Slack delivery (7 channels). KPI-style header with affiliate logos.
- **IF/OF Postgame App Pages:** LIVE — `pages/2_Outfield.py`, `pages/3_Infield.py`
- Worktree: `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles/` on `feature/astros-intangibles`
- **Next:** Test IF delivery on work laptop, Catcher fixes, Weekly OF/IF player reports

### Astros Barrelsville (Active — Mar 22, 2026)
- **Postgame Hitting:** DEPLOYED on Posit Connect. App GUID: `bbb53548-a7c5-4a03-9146-44647e7c88c0`
- Visual overhaul complete: navy header, KPI cards, statline cards, glossary (EN+ES)
- 2×3 zone grid with heatmaps DONE: Pre-2K / 2K × Takes / Swings / BIPs, per-batter zones, zone metric selector (RV Gain / xwOBA / gcOBA)
- Video pipeline working: CF (M/a/v) + Side by batter hand (RHH→F/7, LHH→H/6), fallback_bat_side from roster
- 6-category Customize Table Columns: Statline, Damage, Contact, Approach, Ball Flight, Proj Outcome — controls both app AND PDF
- Supplementary metrics: Hard% (Damage), Ch% (Contact) — toggle-able, default OFF
- PDF null fix: transparent bbox for null values (clean dashes everywhere)
- Daily Tracker: "Download Report" button generates + downloads PDF directly
- Sidebar doubleheader dedup fix applied (all 5 pages across 3 projects — see commit c6d1605)
- **MiLB Advance Scouting:** LIVE. Batch + single-pitcher CLI, ZIP delivery
- **Box Score:** SOLID — delivery method TBD
- **Heart Zone Report:** COMPLETED
- **Blast Motion:** FULLY COMPLETED — app page + CLI + DB-powered
- **Weekly Hitter KPI Report:** CODE COMPLETE — active next step for iteration
- Worktree: `C:/Users/Owner/bsb-wt-hitting/` on `feature/barrelsville`
- **Next:** Weekly Hitter KPI iteration + delivery, RISP runner indicator, opposing team logos, spray chart

---

## PD Goals (`pd-goals/` on branch `feature/pd-goals`)

Tracks player development goals for MiLB players. Each player gets 1-3 goals measured over 6-week periods. Two components: Streamlit dashboard (`app.py`) + automated PDF reports (`src/report.py`).

**Status:** LIVE on Posit Connect. Percentile engine live (8 groups, Astros tables). Stats audited against GC production SQL.
> See `docs/ARCHIVED_REFERENCES.md` for detailed current state, metric gaps, dashboard features, upload flow, and metric formulas.

### Key Files
- `pd-goals/app.py` - Streamlit dashboard
- `pd-goals/src/report.py` - PDF report generation
- `pd-goals/src/goal_parser.py` - Parses goal text like "K% > 28%"
- `pd-goals/src/stats.py` - Stat calculations (audited against GC production SQL)
- `pd-goals/src/metrics.py` - Metric definitions (Damage, pBarrel formulas)
- `pd-goals/src/percentiles.py` - League-wide percentile engine (8 groups)
- `pd-goals/src/database.py` - DB connection + `SCHED_TYPES` config
- `pd-goals/src/roster.py` - Roster queries
- `pd-goals/data/goals.csv` - PRODUCTION goals (persists to disk)
- `pd-goals/data/slack_channels.csv` - Channel mapping for Slack delivery
- `pd-goals/PRD.md` - Full product requirements document

### Tech Stack
- Python 3.11+, Streamlit, matplotlib, reportlab, pandas
- Database: SQL Server (GCSQL02.ASTROS.COM -> GroundControl2)
- Hosting: Posit Connect (`connect2.astros.com`)
- PD Goals App GUID: `79f52369-8244-46da-a4d6-95df956bacad`

---

## Postgame Reports (`bullpen-report/` on branch `feature/bullpen-reports`)

Multi-page landscape PDF postgame pitcher reports. Deployed as part of Astros Arm Farm multi-page Streamlit app.
> See `docs/ARCHIVED_REFERENCES.md` for detailed metrics reference, percentile architecture, and plottable patterns.

### Key Files
- `bullpen-report/Arm_Farm.py` -- Landing page (retro arcade)
- `bullpen-report/pages/2_Postgame.py` -- Postgame dashboard (~1770 lines)
- `bullpen-report/src/postgame_report.py` -- PDF drawing (plottable tables, custom column params)
- `bullpen-report/src/postgame_data.py` -- Game pitch/PA queries, stat computation, gcERA
- `bullpen-report/src/postgame_percentiles.py` -- League distributions + color mapping (6 queries)
- `bullpen-report/src/bullpen_data.py` -- Shared constants (PITCH_TYPE_COLORS, enrich_pitches)
- `bullpen-report/src/plots.py` -- Plotly charts (rolling velo, movement scatter, pie charts)
- `bullpen-report/src/reclassify.py` -- Pitch reclassification (CSV-based)
- `bullpen-report/src/video.py` -- Video URL lookup (Synergy)
- `bullpen-report/scripts/generate_postgame.py` -- CLI entry point

### Arm Farm Structure
```
bullpen-report/
├── Arm_Farm.py                  # Landing page
├── pages/
│   ├── 1_Side_Reports.py       # Bullpen session analysis [LIVE]
│   ├── 2_Postgame.py           # Postgame pitcher reports [LIVE]
│   └── 3_Affiliate_Tracker.py  # Affiliate leaderboard [ALPHA V1]
├── src/
│   ├── tracker_data.py          # Affiliate Tracker data + SQL queries
│   └── ...                      # Shared modules
└── manifest.json                # Posit Connect deployment manifest
```
- Arm Farm App GUID: `13482bcb-8ff2-4f20-92c9-5465f49e5846`
- Pages use `sys.path.insert(0, str(Path(__file__).parent.parent))` for src/ imports

### LVA Pitch Result Marker Shapes (Feb 20, 2026)
Page 2 LVA grid + Streamlit app show 5 marker shapes by pitch outcome (all keep pitch-type color):
| Result | matplotlib | Plotly | Definition |
|--------|-----------|--------|------------|
| Whiff | `'o'` filled | `circle` | pitch_result_id IN (10,16,21,22,23) — 10=Foul Tip, 16=Missed Bunt |
| Foul | `'s'` square | `square` | pitch_result_id IN (7,8,9) — 7=Foul, 8=Foul Bunt, 9=Foul on Pitchout |
| Hard Hit | `'X'` cross | `x` | BIP (12,13,14) with EV >= 89 |
| Weak | `'^'` triangle | `triangle-up` | BIP with EV < 89 or NULL |
| Take | `'o'` hollow | `circle-open` | Everything else (did_swing=0) |

---

## Astros Intangibles (`intangibles/` on branch `feature/astros-intangibles`)

Multi-page Streamlit app for BR & fielding analytics (same multi-page pattern as Arm Farm).

### Key Files
- `intangibles/Intangibles.py` -- Landing page (retro arcade)
- `intangibles/pages/1_Baserunning.py` -- BR Postgame dashboard [LIVE]
- `intangibles/pages/2_Outfield.py` -- OF Postgame dashboard [LIVE]
- `intangibles/pages/3_Infield.py` -- IF Postgame dashboard [LIVE]
- `intangibles/pages/4_Catching.py` -- Catcher report dashboard [CODE COMPLETE]
- `intangibles/src/br_data.py` -- Statline + PBP queries
- `intangibles/src/br_report.py` -- PDF generation (plottable tables, percentile coloring)
- `intangibles/src/br_percentiles.py` -- Lead length percentile engine (1B + 2B distributions)
- `intangibles/src/of_postgame_data.py` -- OF event-level play queries, error detection, desc abbreviation
- `intangibles/src/of_postgame_report.py` -- OF daily PDF (landscape, plottable tables, percentile coloring)
- `intangibles/src/of_postgame_percentiles.py` -- OF season distributions (9 tracking KPIs + PAA)
- `intangibles/src/of_postgame_page.py` -- OF Streamlit app page
- `intangibles/src/if_postgame_data.py` -- IF event-level play queries, OPG infield, error detection
- `intangibles/src/if_postgame_report.py` -- IF daily PDF (per-level, affiliate logos, KPI-style header)
- `intangibles/src/if_postgame_percentiles.py` -- IF season distributions (8 tracking KPIs + OPG)
- `intangibles/src/if_postgame_page.py` -- IF Streamlit app page
- `intangibles/src/catcher_data.py` -- Catcher queries (864 lines)
- `intangibles/src/catcher_report.py` -- Catcher PDF (1110 lines)
- `intangibles/src/catcher_percentiles.py` -- Catcher percentile distributions
- `intangibles/src/database.py` -- DB connection (dual-mode)
- `intangibles/scripts/generate_of_report.py` -- OF daily CLI (single PDF, single channel)
- `intangibles/scripts/generate_if_report.py` -- IF daily CLI (per-level PDFs, per-affiliate channels)
- `intangibles/BR_DATA_REFERENCE.md` -- Full table schemas and metric calculations
- Intangibles App GUID: `295a5205-5568-4fb6-a759-26dc63bc9439`

### IF Daily Report — Per-Level Slack Delivery (Mar 13, 2026)
One PDF per affiliate level, each delivered to its own Slack channel:

| Route Key | Channel Name | Channel ID | Notes |
|-----------|-------------|------------|-------|
| mlb | pd-automation-test | `C0ABHSF6SCA` | Placeholder |
| aaa | sugarland_intangibles | `C0AKNKW1UKU` | |
| aax | corpus_intangibles | `C0AL1HM1CDP` | |
| afa | asheville_intangibles | `C0AK76YS1NK` | |
| afx | fayetteville_intangibles | `C0AKNL9BGN6` | |
| rok | fcl_intangibles | `C0AKG8WA267` | FCL/ACL games |
| dsl | dsl_intangibles | `C0AK777QM47` | DSL games (split from rok via sv.league) |

**DSL/FCL Split:** Both use `level_code='rok'` in DB. Split by `sv.league` column: `'DSL'` → route key `dsl`, everything else → `rok`. `sv.league` is now in BOTH games and plays queries (no merge dependency).

---

## Astros Barrelsville (`barrelsville/` on branch `feature/barrelsville`)

Multi-page Streamlit app for hitting analytics (same multi-page pattern as Arm Farm).

### Key Files
- `barrelsville/Barrelsville.py` -- Landing page (retro arcade, 3 active cards)
- `barrelsville/pages/1_Postgame.py` -- Postgame hitting dashboard (~1300 lines, full visual overhaul)
- `barrelsville/pages/3_Advance.py` -- MiLB advance scouting dashboard (Level→Org→Pitcher flow)
- `barrelsville/src/postgame_data.py` -- Batter queries, game stats, timeframe stats, bat tracking
- `barrelsville/src/postgame_report.py` -- PDF: header, configurable tables (17 metrics), 6 zone plots, RV heatmap
- `barrelsville/src/postgame_percentiles.py` -- Batter percentile distributions
- `barrelsville/src/postgame_app_data.py` -- Game sessions, BBC/WIN sched filter, batters
- `barrelsville/src/advance_data.py` -- Opposing roster query (parameterized ORG_LK), scouting pitches (5 GS/30 IP), count-state usage, pitch summary
- `barrelsville/src/advance_report.py` -- Advance PDF: summary page (break chart, velo/IZ table, count-state usage, physical metrics) + per-pitch-type density pages
- `barrelsville/src/advance_percentiles.py` -- Pitcher percentile distributions at level (IZ%, velo, movement, release)
- `barrelsville/src/video.py` -- Video URL query + merge (batter hand-aware, fallback_bat_side)
- `barrelsville/src/roster.py` -- Roster queries, player lookup, dropdown data (includes bats)
- `barrelsville/scripts/generate_postgame.py` -- CLI with --date, --batter, --deliver, --exclude
- `barrelsville/scripts/generate_advance.py` -- Single-pitcher CLI with --level, --org, --pitcher, --bat-side, --deliver
- `barrelsville/scripts/generate_advance_batch.py` -- Batch CLI: auto-detect upcoming series, all levels, all pitchers
- `barrelsville/src/deliver.py` -- Logic App delivery (send_reports_via_logic_app + send_to_channel)
- `barrelsville/docs/ADVANCE_BATCH_DESIGN.md` -- Batch advance system design doc
- `barrelsville/ARM_FARM_APP_ARCHITECTURE.md` -- Comprehensive architecture reference
- Barrelsville App GUID: `bbb53548-a7c5-4a03-9146-44647e7c88c0`

### Key Hitting Features
- Per-batter personalized strike zones (heart/shadow/SZ z-bounds from `swing_zone`)
- gcOBA, xwOBA, video URLs, bat tracking (EV, LA, Hard%, PullAir%)
- 5 KPI tables (Damage, Contact, Approach, Ball Flight, Proj Outcome) with percentile coloring
- 2×3 zone grid (Pre-2K / 2K × Takes / Swings / BIPs) with RV Gain heatmap backgrounds
- Zone metric selector: RV Gain (default), xwOBA, zxwOBA
- **zxwOBA:** Per-pitch wOBA-scale delta metric (every pitch valued via Count_RE + BIP expected RV). Own normalization range (`_ZXWOBA_NORM_RANGE = 0.015`)
- 6-category Customize Table Columns expander — controls both app tables AND PDF output
- Supplementary metrics: Hard% (Damage), Ch% (Contact) — toggle-able, default OFF
- Daily Tracker: "Download Report" generates + downloads PDF directly (no tab navigation)
- PDF null fix: transparent bbox for null values (clean dashes, no visible boxes)
- BBC/WIN pseudo sched types (same pattern as Intangibles `_build_sched_filter()`)
- Video: CF (M→a→v), Side by batter hand (RHH→F/7, LHH→H/6), `fallback_bat_side` from roster
- Glossary (English + Spanish) at bottom of app + final PDF page

### Key Advance Scouting Features
- Opposing pitcher roster via PP_MASTER with parameterized `ORG_LK` (flipped from `'hou'` to any org)
- PP_MASTER eBis level codes → MLBAM SPORT codes mapping: `ml→mlb, 3a→aaa, 2a→aax, 1a→afa, 1f→afx, r/ds→rok`
- Data scope: pitcher's last 30 IP at selected level. Walks backwards from most recent outing, no year filter — crosses season boundaries for early-season coverage. Includes R+S schedule types by default
- Count-state buckets: First Pitch (0,0), 0/1K (1-0/0-1/2-1/1-1), Plus2 (3-0/3-1/2-0), Full (3-2), 2K (0-2/1-2/2-2)
- Usage% color thresholds (FIXED, not percentile): <45%=white, 45-55=light green, 56-65=green, 66-75=dark green, 76+=blue
- IZ% bars: width=value, color=percentile at level (red-white-green). No number displayed.
- Break chart mirrored: LHH PDF = chart LEFT, RHH PDF = chart RIGHT
- Per-pitch-type pages: 5 count-state × 2 density plots (LOC + DMG KDE) + spray chart + IZ% badges
- **Single-pitcher CLI:** Two separate PDFs: `Last_First_vsLHH_Level_Date.pdf` / `Last_First_vsRHH_Level_Date.pdf`
- **Batch CLI:** One combined PDF per pitcher: `{level}_{org}_{Last}_{First}_{series_start}.pdf` (RHH + LHH in one file)
- **Batch flow:** Auto-detect upcoming series via `MLBAM.Schedule` + `MLBAM.Teams` + `mlb_ebis.gbl_club_lkup` → iterate all opposing pitchers → generate combined PDFs
- **New tables (batch):** `MLBAM.Schedule` (game schedule), `mlb_ebis.gbl_club_lkup` (eBis club→ORG_LK, org quirks: la→lad, chi→chc, ny→nym)
- **Batch delivery:** `send_to_channel()` in deliver.py — explicit Slack channel routing (no GC ID parsing)
- **`--diagnostic` mode:** Dumps INFORMATION_SCHEMA + org mappings for work laptop verification
- **Open items:** RISP runner indicator, opposing team logos, Slack advance channels (5-6, one per level)

### xwOBA / wOBA Data Sources — CRITICAL
- **wOBA weights** (`Guts.woba_lwts`): We HAVE DB access. Query by `level_code` + `year`. One blanket set per level per year — NO sched_type filtering
- **xwOBA exponents** (`Guts.hit_specs_ratios`): DB ACCESS GRANTED (Feb 23). `lru_cached` query by season. Exponents are global (no level dimension).
- **xwOBA formula:** `POWER(prob, exp) * woba_weight` for each outcome (1b, 2b, 3b, hr, fo), summed per BIP
- **Inputs:** `Astros.Hits_Probabilities` (per-BIP probs) + exponents (from DB) + wOBA weights (from DB)
- **wRC+ league context:** `_get_league_woba_env()` uses league-specific row when `mlbam_league` available (Astros=AL). Falls back to level_code AVG.
- **xwOBA excludes IBB** from denominator (diverges from GC2 for internal consistency with wOBA).
- **Barrel bunt filter:** All barrel/pBarrel calcs exclude bunts (`hit_trajectory_id NOT IN (2,3,4)`). Audited Mar 12.

---

## Report Delivery Pipeline

### Azure Logic App Direct Upload (WORKING — Feb 18, 2026)
**Architecture:** Python -> base64 PDF -> POST to Logic App HTTP trigger -> Slack file upload
```
Python generates PDF
  -> parses groundcontrol_id from filename
  -> looks up channel_id in slack_channels.csv
  -> requests.post(LOGIC_APP_URL, json={"channel": "C...", "filename": "...", "pdf": "<base64>"})
  -> pd-report-delivery -> astros-file-uploader -> Slack channel
```

**Key Files:**
- `bullpen-report/src/deliver.py` -- `send_reports_via_logic_app()` handles routing + POST
- `pd-goals/data/slack_channels.csv` -- `channel_id` column maps groundcontrol_id -> Slack channel
- Logic App URL: from `--logic-app-url` CLI arg or `LOGIC_APP_URL` env var

**CLI:** `python scripts/generate_postgame.py --date 2026-02-17 --deliver --logic-app-url "https://..."`

**Routing:** Python handles ALL routing — Azure is a dumb pipe. Filename -> groundcontrol_id -> CSV lookup -> channel_id -> POST.

**Setup per channel:** Each `zzz_` channel needs (1) channel_id in CSV and (2) "Astros File Uploader" app added via Integrations.

> See `docs/ARCHIVED_REFERENCES.md` for Azure resource details, permissions, legacy OneDrive pipeline, and Power Automate flow specs.

---

## DB Essentials

### Column Name Reference (Critical Corrections)
- Events_View has NO `batter_id` -- JOIN via Pitches_View on `sched_id + event_id = cur_event_id`
- Hits has NO `batter_id` -- JOIN via Pitches_View on `sched_id + pitch_id`
- Pitches_View: `balls_before` (not `balls`), `strikes_before` (not `strikes`), `bat_side` (not `batter_side`), `ab_pitch_number` (not `pitch_number`)
- Schedule_View: `sched_date` (not `game_date`)
- Pitches_Grades: no `pitcher_id` -- join via Pitches_View on `sched_id + pitch_id`
- Stuff grades exist DIRECTLY in Pitches_View (`stuffrelvel_grade_2080`, etc.)
- Whiff codes: `pitch_result_id IN (10, 16, 21, 22, 23, 25)` — 10=Foul Tip, 16=Missed Bunt, 21=Swinging on Pitchout, 22=Swinging, 23=Swinging Blocked, 25=Bunt Foul Tip
- Called strike codes: `pitch_result_id IN (6, 3, 24, 30, 31)` — 6=Called, 3=Automatic, 24=Unknown, 30/31=Automatic (timer/batter violations)
- Foul codes: `pitch_result_id IN (7, 8, 9)` — 7=Foul, 8=Foul Bunt, 9=Foul on Pitchout. **NOT 16** (16=Missed Bunt). **25=Bunt Foul Tip is NOT in any code set (gap).**
- BIP codes: `pitch_result_id IN (12, 13, 14, 18, 19, 20)` — 12=Out(s), 13=No Out(s), 14=Run(s), 18/19/20=Pitchout BIPs (extremely rare).
- MLBAM.Pitch_fx: whiff filter uses `event_type IN ('swinging_strike',...)` -- pitch_result_id does NOT exist in MLBAM tables
- **Astros.Hits:** `hit_bearing` (NOT hit_spray_angle), `hit_exit_speed`, `hit_vertical_angle`. NO `hit_trajectory_id` (that's in Events_View/Events)
- **Astros.Events_View / Events:** HAS `hit_trajectory_id` (bunt filter: NOT IN 2,3,4)
- **MLBAM.Hits:** `hit_initial_speed` (NOT hit_exit_speed), `hit_horizontal_angle` (spray)
- **Astros.Pitches_View:** Zone confidence column is `called_strike_chance_mlb` (NOT `csc` — that's only a Python alias in postgame_data.py). Used for CSC-weighted zone metrics (ZSw%, OSw%, ZCtct%, etc.)
- **Astros.Video_Network:** Join on `sched_id` + `pitch_id`. Column is `angle` (NOT `camera_angle`). Values: `'M'`=Main CF, `'a'`=alt CF, `'v'`=alt2 CF, `'H'`=high home, `'F'`=1B high, `'7'`=3B high, `'5'`=side mid 1B, `'6'`=side mid 3B, `'s'`=RHH high speed, `'t'`=LHH high speed. URL column is `video_url`.
- **Astros.LK_Event_Results:** `event_result_id`, `event_result`. Error IDs: 11=`error`, 13=`field_error`, 32-34=`pickoff_error_1b/2b/3b`.
- **Error type detection:** `event_result_id IN (11, 13)` flags an error play, but BOTH IDs cover throwing AND fielding errors. Must parse `play_by_play` description: `"throwing error"` (~26%), `"fielding error"` (~71%), `"missed catch error"` (rare). Parse BEFORE description abbreviation (needs full text).
- **Astros.Players:** `birthdate` (NOT `birth_date`), `first_name`, `last_name`, `groundcontrol_id`, `ebis_id`, `mlbam_id`, `bats`, `throws`. NO `first_last` column — use PP_MASTER or roster query
- **MLB_eBis.PP_MASTER:** Must use full schema `MLB_eBis.PP_MASTER` (NOT bare `PP_MASTER`). Position column is `POSITION_LK` (NOT `POSITION`). Join key is `pm.player_id` = `r.ebis_id` (NOT groundcontrol_id). Other cols: `ORG_LK`, `LEVELOFPLAY_LK`, `MNROSTERSTATUS_LK`, `MJROSTERSTATUS_LK`, `EMPLOYEE_FLG`
- **Astros.LK_Pitch_Results:** Columns: `pitch_result_id`, `pitch_result`, `did_swing`, `gumbo_code`, `gumbo_description`. Use `gumbo_description` for human-readable labels (NOT `description` — that column does NOT exist). **NO `ab_swing` column.**
- **pitch_result_id 16** = "Strike - Missed Bunt" (NOT "Foul Tip" as previously assumed). CAN be a strikeout (strikes_before=2).
- **pitch_result_id 10** = "Strike - Foul Tip" (the ACTUAL foul tip). In WHIFF_CODES — displays as "Whiff" in swing-by-swing.
- **pitch_result_id 25** = "Strike - Bunt Foul Tip" (did_swing=1). Included in WHIFF_CODES (extremely rare).
- **pitch_result_ids 18/19/20** = Pitchout BIPs (out/no out/run). did_swing=1. Included in BIP_CODES (extremely rare).
- **Astros.Defense_Combined_By_Pos:** `out_made` and `competitive_play` are **BIT columns** — `SUM(bit)` is ILLEGAL in SQL Server. MUST use `SUM(CAST(out_made AS float))` and `SUM(CAST(competitive_play AS int))`. Same for `competitive_throw`. Failing to CAST crashes the entire query silently (returns 0 rows), leaving all downstream metrics (paa_cal, raa, oaa, expected_outs) as NaN.
- **Astros.Tracking_Defensive_Metrics:** `competitive_play` and `competitive_throw` are also **BIT columns**. Filter in Python (`== 1`) not SQL `SUM()`. Column names: `acceleration_chest_up`, `acceleration_chest_down` (NOT `accel_toward`/`accel_away`). Used for BOTH IF and OF (differentiated by `pos_id`).

### GC2 Defensive Metric Aggregation — PERCENTILE_CONT (Updated Mar 24, 2026)
GC2 production uses `PERCENTILE_CONT` window functions (NOT MAX/AVG) for per-player tracking metric aggregation.

**GC2 values (for reference only — our code intentionally differs on arm/exchange):**

| Metric | Percentile | GC2 Filter | IF | OF |
|--------|-----------|--------|-----|-----|
| TopSpeed | P95 | `competitive_play=1`, `top_speed<=34` | Same | Same |
| AccelChestUp | P75 | `competitive_play=1` | Same | Same |
| AccelChestDown | P75 | `competitive_play=1` | Same | Same |
| ReactionTime | P25 | `competitive_play=1` | Same | Same |
| UsefulReaction | P25 | `competitive_play=1` | NULL for IF | Same |
| ReactionRadius | P25 | `competitive_play=1` | Same | Same |
| ReactionAccuracyRadius | P25 | `competitive_play=1` | Same | Same |
| ArmStrength | P99 | GC2: `competitive_throw=1`, arm 60-100 (OF), 60-94 (IF), 60-94 (C) | 60-94 | 60-100 |
| Exchange | P10 | GC2: `competitive_throw=1`, `exchange>=0.4`, `arm>=60` | `exchange_dp` col | `exchange` col |

**OUR CODE (updated Mar 26 — gate + IF arm floor changes):**
- **Play gate (Tier 1):** `OM + CP + CT + (arm >= floor) > 0`. Superset of GC2 — keeps CT AND adds arm floor.
- **OF arm floor:** 75 mph (GC2: 60). OF exchange: arm >= 75, no CT req.
- **IF arm floor:** 70 mph (GC2: 60). IF throws are slower than OF. IF exchange: arm >= 70, no CT req.
- **Arm ceiling OF/IF:** 108 (GC2: 100 OF, 94 IF). More permissive, rare edge case.
- **Arm/Exchange do NOT require `competitive_throw=1`**. The arm floor IS the filter.
- **Catcher arm range unchanged:** 60-94 (matches GC2).
- **OAA:** `SUM(out_made - out_prob)` — renamed from DRS (Mar 25). Matches Statcast definition.
- **PAA/EO and OAA:** identical formulas to GC2 overall column. **NO gate on DCBP value queries** — all plays count.

**Query standard** (see `intangibles/docs/OF_FIELDING_QUERY_STANDARD.md`):
- Tier 1 (tracking KPIs + direction rose): `OM + CP + CT + (arm >= floor) > 0` — superset of GC2. OF floor=75, IF floor=70
- Tier 2 (play table + spray chart): 5-condition OR filter — per-play detail rows
- Tier 3 (difficulty chart): `first_defender + out_prob IS NOT NULL` — expected vs actual
- No gate (OAA, PAA/EO, RAA): ALL DCBP rows, no filtering — cumulative value metrics match GC2
- **OF KPI display:** TopSpd, AccelCU, AccelCD, React, **UsefulReact**, ReactRad + Arm + Exchange
- **IF KPI display:** TopSpd, AccelCU, AccelCD, React, ReactRad, **ReactAccRad** + Arm + Exchange

**Shared module:** `intangibles/src/fielding_base.py` — Events_View architecture, position configs, filter functions, Python-side aggregation. Weekly OF report wired to it. All 8 data files updated with new gate (Mar 26).

**Pattern:** `SELECT DISTINCT ... PERCENTILE_CONT(x) WITHIN GROUP (ORDER BY CASE WHEN filter THEN col END) OVER (PARTITION BY player_id)` — window functions compute same value per row in partition, SELECT DISTINCT collapses to 1 row per player.
**Source table:** `Astros.Tracking_Defensive_Metrics` for both IF and OF (pos_id differentiates).
**Value metrics** (OAA, PAA Cal, RAA): Separate query from `Defense_Combined_By_Pos` with GROUP BY.

### Pitches_View Join Keys -- CRITICAL
- **`cur_event_id`** = NULL for 75% of pitches -- only set on FINAL pitch of each PA
- **`ab_event_id`** = stays constant for ALL pitches in a plate appearance -- use THIS for Events_View joins
- When joining `Pitches_View -> Events_View`: always use `pv.ab_event_id = ev.event_id`, NOT `pv.cur_event_id`
- **`event_id` / `cur_event_id` are NOT globally unique** -- they repeat across games (e.g., event_id=1 exists in every game). NEVER use `COUNT(DISTINCT cur_event_id)` for PA counts across multiple games -- it will UNDERCOUNT. Use `COUNT(*)` when each row is already a unique PA (e.g., after `cur_event_id IS NOT NULL` filter + Events_View join). To uniquely identify a PA, always use `(sched_id, event_id)` pair.
- **When indexing HP/event data by event_id**, always include `sched_id` in the key: `(batter_id, season, sched_id, event_id)` -- never just `(batter_id, season, event_id)`

### MLBAM Schedule SPORT Codes
| Code | Level | Astros Affiliate |
|------|-------|-------------------|
| mlb | MLB | Houston Astros |
| aaa | AAA | Sugar Land Space Cowboys |
| aax | AA | Corpus Christi Hooks |
| afa | A+ (High-A) | Asheville Tourists |
| afx | A (Single-A) | Fayetteville Woodpeckers |
| rok | Rookie (FCL/DSL/ACL) | All rookie ball — use `sv.league` to distinguish DSL/FCL/ACL |
| int | Internal/Private | NOT real games — NULL teams, off-season dates (Feb/Nov/Dec). Exclude. |

**CRITICAL: `MLBAM.Schedule.SPORT` is always `'rok'` for ALL rookie ball — DSL has NO separate SPORT code.** When querying `MLBAM.Schedule` for DSL series, pass `sport_code='rok'` and isolate DSL via `mlb_ebis.gbl_club_lkup` with `LEVELOFPLAY_LK='ds'`. NEVER pass `sport_code='dsl'` — it returns 0 rows.

### DSL vs FCL Distinction — USE gc2_level_code (Refactored Mar 19, 2026)
**`sv.gc2_level_code`** is the definitive DSL/FCL distinguisher. NOT `sv.league`.
- **DSL:** `sv.gc2_level_code = 'dsl'` (gc2_level_id=24)
- **FCL/ACL:** `sv.gc2_level_code = 'rok'` (gc2_level_id=20)
- **All other levels:** `gc2_level_code` = `level_code` (identical values for aaa, aax, afa, afx, mlb)

**`_build_level_filter()` in all 3 database.py files now uses gc2_level_code for dsl/rok:**
```python
def _build_level_filter(level_code, sv_alias="sv"):
    if level_code in ("dsl", "rok"):
        return f"{sv_alias}.gc2_level_code = '{level_code}'"
    return f"{sv_alias}.level_code = '{level_code}'"
```

**DO NOT use sv.league for DSL detection.** The old `sv.league = 'DSL'` approach had NULL gaps. gc2_level_code is always populated.

- **For wOBA weights lookup:** DSL uses `level_code = 'rok'` in `Guts.woba_lwts` (not a separate code). Use `_woba_level_code()` helper in Barrelsville.
- **`int` level_code:** Internal/private tracking. `int`/V games = DSL bullpens (allow through for V sched type). `int`/R games = junk (exclude).

### DSL Percentile Pools — ALWAYS SEPARATE
- **All 7 percentile files** across all 3 projects (Barrelsville, Arm Farm, Intangibles) give DSL its own isolated percentile pool
- `_build_level_filter('dsl')` → `sv.gc2_level_code = 'dsl'`
- `_build_level_filter('rok')` → `sv.gc2_level_code = 'rok'`
- **NEVER combine DSL with FCL/ACL** for percentiles or level lists
- **ALWAYS include DSL** in level constants (`BATCH_LEVELS`, sidebar dropdowns, etc.) — it's a real level used everywhere

### Schedule Types
- **Postgame data queries:** R, S, E, V, I -- **Postgame percentile queries:** R only
- **PD Goals filter:** `sched_type IN ('E','R','S')` -- config in `pd-goals/src/database.py`
- **GC2 production uses ONLY 'R'**
> See `docs/ARCHIVED_REFERENCES.md` for full schedule type table.

### Astros vs MLBAM Tables
- **Astros.\*** = ALL teams, ALL levels -- "Astros" = processed into Astros DB format, NOT Astros-only
- **MLBAM.\*** = ALL 30 MLB teams (league-wide Statcast data, different schema/columns)
- **Schedule_View.level_code uses MLBAM SPORT codes** (`aax`, `afa`, etc.) -- NOT PP_MASTER codes
- **ID mapping:** `groundcontrol_id` = `batter_id`/`pitcher_id` in Astros.Pitches_View; `mlbam_id` in `Astros.Players` -> `player_id` in MLBAM tables; `ebis_id` = `PP_MASTER.PLAYER_ID`
- **Astros join pattern:**
```sql
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE sv.level_code = '{level}' AND YEAR(sv.sched_date) = {season}
  AND pv.ignore_flag = 0 AND pv.pitch_id > 0
```
> See `docs/ARCHIVED_REFERENCES.md` for extended Astros vs MLBAM details, catcher defense tables, percentile migration reference.

### xwOBA / wOBA Weights — CRITICAL RULES
- **wOBA weights** (`Guts.woba_lwts`): WE HAVE ACCESS. Query by `level_code` + `year`. One blanket set per level per year. NO sched_type filtering. Astros = AL.
- **Guts.woba_lwts columns:** `woba_bb`, `woba_hb` (NOT `woba_hbp`!), `woba_1b`, `woba_2b`, `woba_3b`, `woba_hr`. Python dict key is `"hbp"` but DB column is `woba_hb`. Audited Mar 12 — `woba_hbp` crashes, `woba_hb` is the real column.
- **xwOBA exponents** (`Guts.hit_specs_ratios`): DB ACCESS GRANTED (Feb 23). `lru_cached` query by season. Exponents are global (no level dimension).
- **For wRC+:** Use league-specific woba_lwts row (`_get_league_woba_env(year, level_code, league=)`). Astros = AL.
- **For outcome weights (bb,1b,2b,3b,hr):** level_code AVG is fine (AL/NL nearly identical).
- **xwOBA excludes IBB** from denominator (our decision — GC2 does NOT subtract IBB from xwOBA denom).
- Hardcoded fallback in code: `_DEFAULT_WOBA_WEIGHTS = {"bb": 0.69, "hbp": 0.72, "1b": 0.88, "2b": 1.24, "3b": 1.56, "hr": 2.01}`

### plate_x / HorzBreak / Release_x Coordinate Convention — CRITICAL
**Raw DB (HawkEye/Statcast) = catcher's perspective.** Positive plate_x = right from catcher's view. Same for horzbreak and release_x.

| Project | Convention | How | Why |
|---------|-----------|-----|-----|
| **Barrelsville** (hitting) | Catcher's view | Raw DB values (no flip) | Hitting plots are naturally catcher's perspective |
| **hitter_analysis.py** | Catcher's view | Raw DB values (no flip) | Same as Barrelsville |
| **Arm Farm postgame** | Pitcher's view | `enrich_pitches()` flips: `plate_x = -plate_x`, `horzbreak = -horzbreak`, `release_x = -release_x` | Pitching reports show pitcher's perspective |
| **pitcher_analysis.py** | Pitcher's view | Flips `plate_x = -plate_x` after query | Matches Arm Farm postgame convention |
| **Advance Scouting** | Catcher's view | Raw DB values | Hitter-facing scouting report |

**Rules:**
- **Pitching reports** (postgame, pitcher analysis, bullpen): Flip plate_x/horzbreak/release_x to **pitcher's view**
- **Hitting reports** (Barrelsville, hitter analysis, advance): Keep raw DB values = **catcher's view**
- `enrich_pitches()` in `bullpen_data.py` handles the flip for Arm Farm. Other scripts must flip manually.
- **NEVER assume plate_x orientation** — always check which convention the current script uses before plotting
- **Home plate pentagon orientation must match the view.** Pitcher's view = point faces UP (toward pitcher). Catcher's view = point faces DOWN (toward catcher). If you flip plate_x, flip home plate too.

### Schedule_View level_code — Competitive vs Non-Competitive (Audited Mar 18, 2026)
**ONLY these level_codes are competitive affiliated games:**
`mlb`, `aaa`, `aax`, `afa`, `afx`, `rok` (FCL/ACL/DSL via `sv.league`)

**ALL other level_codes are NON-COMPETITIVE and must be excluded:**
| Code | R Games | V Games | What It Is | Notes |
|------|---------|---------|-----------|-------|
| `bbc` | 43,748 | 0 | Big league camp / pseudo level | Always exclude |
| `sum` | 14,496 | 0 | Summer league | Always exclude |
| `int` | 8,145 | 1,267 | Internal / private tracking | **EXCEPTION: int/V = DSL bullpens — allow V through** |
| `hsb` | 8,176 | 0 | Showcase / high school | Always exclude |
| `ind` | 5,915 | 0 | Independent league | Always exclude |
| `win` | 5,232 | 0 | Winter league | Always exclude |
| `jcb` | 2,337 | 0 | Junior camp | Always exclude |
| `nae` | 2 | 0 | Unknown | Always exclude |
| `min` | 40 | E games | MiLB minor / Exhibition level | **NOT junk — removed from junk lists Mar 22, 2026. Has real E sched_type games.** |
| `NULL` | 234 | 0 | No level assigned | Always exclude |

**CRITICAL: Every junk code has `sched_type = 'R'` games.** `sched_type = 'R'` alone does NOT protect against contamination.

**`int` level exception:** `int` with `sched_type = 'V'` (1,267 games) = DSL bullpen sessions. These are REAL pitching data. Block `int` for R sched type, ALLOW for V/I. Arm Farm `postgame_app_data.py` uses split junk lists: `_JUNK_LEVELS_R` (includes int) vs `_JUNK_LEVELS_NON_R` (excludes int).

**Safe query patterns (use one of these):**
1. **Whitelist:** `sv.level_code IN ('mlb','aaa','aax','afa','afx','rok')` — scripts querying all data for a player
2. **`_build_level_filter()`** — tracker, KPI data, percentile queries
3. **`EXCLUDE_LEVELS_SQL`** — full 8-code list in postgame_data.py (for R-type queries)
4. **`sched_id` constraint** — postgame apps query by specific game
5. **Split junk lists** — `_JUNK_LEVELS_R` (with int) for R, `_JUNK_LEVELS_NON_R` (without int) for V/I/S/E

**UNSAFE pattern:** `WHERE pv.batter_id = :id AND sv.sched_type = 'R'` with NO level constraint. This lets all junk codes through.

**DSL/FCL Split (Refactored Mar 19, 2026):** Use `sv.gc2_level_code` — NOT `sv.level_code` — for DSL vs FCL:
- `sv.gc2_level_code = 'dsl'` → DSL games (7,238 games, no NULLs)
- `sv.gc2_level_code = 'rok'` → FCL/ACL games (16,198 games, includes NULL league rows)
- `_build_level_filter('dsl')` → `sv.gc2_level_code = 'dsl'` (all worktrees)
- `_build_level_filter('rok')` → `sv.gc2_level_code = 'rok'` (all worktrees)
- **No sv.league dependency. No PP_MASTER lookup needed. No int/R detection hacks.**
- For queries using `_query_timeframe`: `gc2_level_code` is SELECTed and remapped to `level_code` column after query
- `sv.level_code` still used for non-rookie levels (aaa, aax, afa, afx, mlb) — unchanged

### Common Pitfalls
- **NEVER write lazy queries.** When writing SQL for a specific player, ALWAYS look up their `groundcontrol_id` from `pd-goals/data/slack_channels.csv` first. Use the concrete ID — never use `LIKE '%Name%'` subqueries against PP_MASTER when we have the ID on disk. Same applies to any entity we have local data for: look it up, don't punt it to the user.
- Astros.* tables contain ALL 30 teams, not just Astros
- pitch_result_id=16 = "Strike - Missed Bunt" (GC2 gumbo_description). IS a swinging strike for Whiff% but NOT for gcPerf. Previously mislabeled as "foul tip" in our docs.
- Foul tip (pitch_result_id=10) IS a swinging strike — included in WHIFF_CODES, NOT in FOUL_CODES. Correct per MLB rules (foul tip with 2 strikes = strikeout).
- Bunt foul tip (pitch_result_id=25) = "Strike - Bunt Foul Tip" (did_swing=1). NOT in any code set — currently unclassified.
- `did_swing` is int (1) in Astros, varchar ('Y') in old MLBAM
- Chase% (CSC < 0.01) and Oswing% (CSC < 0.5) are DIFFERENT metrics
- **cur_event_id vs ab_event_id:** `cur_event_id` = only final pitch of PA (use for PA-level aggregation, matches GC2). `ab_event_id` = all pitches in PA (use for pitch-level Events joins)
- OSw%, ZSw%, ZCon%, OCtct%, ZWhiff% all use CSC-WEIGHTED formulas (not binary). Chase% is the ONLY binary metric
- Events_View PA columns (`[1b]`, `[2b]`, `[3b]`, etc.) are bit/int -- MUST CAST
- **SQL Server BIT columns CANNOT be SUM'd.** `SUM(bit_col)` throws `"Operand data type bit is invalid for sum operator"` and returns 0 rows. Known bit columns: `Defense_Combined_By_Pos.out_made`, `.competitive_play`, `.competitive_throw`; `Tracking_Defensive_Metrics.competitive_play`, `.competitive_throw`; Events_View PA columns. **ALWAYS CAST before aggregation:** `SUM(CAST(col AS int))` or `SUM(CAST(col AS float))`.
- **Pitch type classification:** FF/FT/SI=Fastball, SL/CU/FC=Breaking, CH/FS/SC/KN=Offspeed
- **NEVER guess DB column names — THIS IS A BLOCKING RULE.** Before writing ANY SQL query (even a "quick" one for the terminal), you MUST first either: (1) Read `sql-queries/DATABASE_REFERENCE.md` for the table's columns, or (2) Grep the codebase for existing queries that use that table, or (3) Check CLAUDE.md Column Name Reference above. If the table/column is not documented anywhere, tell the user you need to verify and provide an INFORMATION_SCHEMA query FIRST. **No exceptions. No "quick" queries. Verify then write.**
- **NEVER use Python variable names as SQL column names.** Example: `csc` is a Python alias — the real DB column is `called_strike_chance_mlb`. Always grep existing SQL queries in `src/` to find the actual column name.
- **ALWAYS use full schema prefixes for cross-schema tables.** `MLB_eBis.PP_MASTER` (not bare `PP_MASTER`), `MLB_eBis.R4_Draft_Query`, `Guts.woba_lwts`, `Guts.hit_specs_ratios`, etc. The default schema is `dbo` — anything outside it needs the prefix.
- **NEVER build SQL IN clauses from raw DataFrame columns without filtering NaN.** DataFrame `batter_id` / `pitcher_id` columns can contain NaN (float) values. Using `','.join(str(x) for x in df['batter_id'])` produces literal `nan` or `-791510.0` in the SQL, causing `Invalid column name 'nan'` errors. ALWAYS filter and cast: `ids = [int(x) for x in df['col'].dropna()]`. Use `_safe_id_list()` helper when available.
- **Streamlit session state gotcha:** Once a widget key exists, `value=`/`default=` params are IGNORED. Must set `st.session_state[key]` before widget renders.

### GC2 Standardization (Updated Mar 19, 2026)
Postgame + Affiliate Tracker metrics standardized to match GC2 production:
- **gcOBA (VERIFIED Mar 19):** `did_swing=1` (all swings), IBB subtracted from BB/HBP, `>=3` bin, MLB OBP always. **DO NOT CHANGE** — this formula matches GC2 production numbers. Trying WHIFF_CODES/no-IBB/=3 made it worse. In `postgame_data.py`, `tracker_data.py`, `postgame_percentiles.py`.
- **InZ%/FPinZ%/Pre2K InZ%:** `AVG(csc)` — skip NULLs (not ISNULL(csc,0))
- **FPinZ%:** `balls_before=0 AND strikes_before=0` (not ab_pitch_number=1)
- **FPS% (First Pitch Strike):** Binary outcome — `NOT IN BALL_CODES` = strike. Includes called strikes, whiffs, fouls, AND BIP. Different from FPinZ% (which is CSC-weighted probability). Used in boxscore report only.
- **gcPerf run values:** CS=-0.02, ball/HBP=+0.02, pBrl=+0.09, non-pBrl=-0.02
- **pBarrel:** EV < 125 cap applied. Bunt filter pending (needs Events_View JOIN)
- **Whiff%** (whiffs/swings) replaced SWM% (whiffs/pitches) as default column in both tables
- **Loc Grade:** `AVG(stuffrelvelloc - stuffrelvel)` from Pitches_Grades (new column)
- **SWM% missed bunt (16):** Intentionally KEPT in whiff count — GC2 excludes it from Ctct%, we include it. 16 = "Strike - Missed Bunt" (NOT foul tip — foul tip is 10).
- **PA aggregation:** Uses `cur_event_id` (matches GC2), not `ab_event_id`
- **R2K% (Race to 2K):** Pitch-level AVG, NOT CTE-based. GC2 formula: `100 * AVG(CASE WHEN (COALESCE(ev.pa,0)=0 OR ev.so=1) AND ab_pitch_number=3 THEN CASE WHEN strikes_after>=2 THEN 1.0 ELSE 0.0 END END)`. Denominator filter excludes PAs that ended on pitch 3 with a non-K outcome. Requires LEFT JOIN Events_View on `cur_event_id` for `ev.pa`/`ev.so`.
- **FB Velo:** `('FF','FT','SI')` — SI IS included. GC2 uses only `('FF','FT')` but we intentionally include SI.
- **WHIFF_CODES:** `(10, 16, 21, 22, 23, 25)` — we intentionally include 16 (missed bunt) and 25 (bunt foul tip). GC2 excludes 16. Our decision: all swinging strikes belong in WHIFF_CODES.
- **is_whiff MUST be gated by did_swing:** `is_whiff = (did_swing == 1) & pitch_result_id.isin(WHIFF_CODES)`. Without the `did_swing` gate, data anomalies cause Ctct% + Whf% > 100%. Fixed Mar 24, 2026 in Barrelsville. Arm Farm was already safe (pre-filters to swings). NEVER check `pitch_result_id.isin(WHIFF_CODES)` without also requiring `did_swing == 1` when computing rates.

### Dual Query Path Rule — BLOCKING (Added Mar 9, 2026)
**When ANY project has separate CLI/PDF and Streamlit app query paths, BOTH MUST stay in sync.**

Known dual-path files (app query ≠ CLI query):
| Project | CLI/PDF Query | App Query | Status |
|---------|--------------|-----------|--------|
| Arm Farm (pitcher) | `postgame_data.py::get_game_pitches()` | `postgame_app_data.py::get_game_pitches_for_app()` | SYNCED (Mar 9) |
| Barrelsville (hitting) | `postgame_data.py::get_game_pitches()` | `postgame_data.py::get_game_pitches_for_app()` | SYNCED (Mar 9) |

Single-path files (safe — no duplication risk):
| Project | Data Module | Notes |
|---------|------------|-------|
| Intangibles BR | `br_data.py` | `br_app_data.py` only has sidebar queries, not data queries |
| Intangibles Catcher | `catcher_data.py` | `catcher_app_data.py` only has sidebar queries |
| Intangibles OF | `of_data.py` | Single data path |

**RULES:**
1. **When adding a column, JOIN, or filter to ANY pitch query, ALWAYS check if a parallel query exists and update it too.** Grep for the function name pattern (e.g., `get_game_pitches`, `get_game_pitches_for_app`).
2. **When creating a new `*_app_data.py` file, NEVER copy-paste the SQL and diverge.** Either: (a) reuse the same data function from the main module (preferred — Intangibles pattern), or (b) if a separate query is needed, add a comment `# MUST STAY IN SYNC WITH get_game_pitches() in postgame_data.py` at the top of the function.
3. **Before any deploy, diff the SELECT columns of both queries.** Missing columns cause silent metric failures (return None/0% instead of crashing).
4. **Columns that have caused silent failures when missing:** `strikes_after` (R2K% = 0%), `stuffrelvelloc_grade_2080` (Loc Grade = NaN), `hit_exit_speed < 125` cap (pBarrel inflated), `sv.league` (DSL/FCL distinction broken), `mlbam_league` (wOBA weights fall to defaults).

### Key Reference Files — ALWAYS CHECK BEFORE WRITING SQL OR QUERIES
**MANDATORY:** Before writing ANY SQL query, lookup query, or referencing DB columns — READ the relevant reference files below. Do NOT guess column names, table schemas, or player IDs. These files exist specifically to prevent errors.

#### DB Schema & Query References (`sql-queries/`)
- `sql-queries/DATABASE_REFERENCE.md` -- full schema docs, join patterns, LK tables
- `sql-queries/gc-hitter-production-queries.sql` -- GC production SQL reference
- `sql-queries/gc2_gcera_query.sql` -- GC2 production gcERA reference
- `sql-queries/INTANGIBLES_TABLE_REFERENCE.md` -- groundcontroltracking tables
- `sql-queries/gc2_baserunning_query.sql` -- baserunning reference

#### Player & Entity Data Files (`pd-goals/data/`)
- `pd-goals/data/slack_channels.csv` -- `groundcontrol_id`, player name, Slack channel_id mappings for ALL players. **Use this to look up player IDs by name.**
- `pd-goals/data/goals.csv` -- PRODUCTION goals data (player goals, periods, metrics)

### LK_Pitch_Results — Complete Reference (Audited Feb 28, 2026)
| ID | gumbo_description | pitch_result | did_swing | gumbo_code | Code Group |
|----|-------------------|--------------|-----------|------------|------------|
| 1 | NULL | (empty) | 0 | NULL | BALL |
| 2 | Ball - Automatic | automatic_ball | 0 | V | BALL |
| 3 | Strike - Automatic | automatic_strike | 0 | A | CALLED_STRIKE |
| 4 | Ball - Called | ball | 0 | B | BALL |
| 5 | Ball - Ball In Dirt | blocked_ball | 0 | *B | BALL |
| 6 | Strike - Called | called_strike | 0 | C | CALLED_STRIKE |
| 7 | Strike - Foul | foul | 1 | F | FOUL |
| 8 | Strike - Foul Bunt | foul_bunt | 1 | L | FOUL |
| 9 | Strike - Foul on Pitchout | foul_pitchout | 1 | R | FOUL |
| 10 | Strike - Foul Tip | foul_tip | 1 | T | WHIFF |
| 11 | Ball - Hit by Pitch | hit_by_pitch | 0 | H | BALL |
| 12 | Hit Into Play - Out(s) | hit_into_play | 1 | X | BIP |
| 13 | Hit Into Play - No Out(s) | hit_into_play_no_out | 1 | D | BIP |
| 14 | Hit Into Play - Run(s) | hit_into_play_score | 1 | E | BIP |
| 15 | Ball - Intentional | intent_ball | 0 | I | BALL |
| 16 | Strike - Missed Bunt | missed_bunt | 1 | M | WHIFF |
| 17 | Ball - Pitchout | pitchout | 0 | P | BALL |
| 18 | Pitchout HIP - Out(s) | pitchout_hit_into_play | 1 | Y | BIP |
| 19 | Pitchout HIP - No Out(s) | pitchout_hit_into_play_no_out | 1 | J | BIP |
| 20 | Pitchout HIP - Run(s) | pitchout_hit_into_play_score | 1 | Z | BIP |
| 21 | Strike - Swinging on Pitchout | swinging_pitchout | 1 | Q | WHIFF |
| 22 | Strike - Swinging | swinging_strike | 1 | S | WHIFF |
| 23 | Strike - Swinging Blocked | swinging_strike_blocked | 1 | W | WHIFF |
| 24 | Strike - Unknown | unknown_strike | 0 | K | CALLED_STRIKE |
| 25 | Strike - Bunt Foul Tip | bunt_foul_tip | 1 | O | WHIFF |
| 26 | Ball - Automatic (IBB) | automatic_ball | 0 | VB | BALL |
| 27 | Ball - Auto (Timer - Catcher) | automatic_ball | 0 | VC | BALL |
| 28 | Ball - Auto (Timer - Pitcher) | automatic_ball | 0 | VP | BALL |
| 29 | Ball - Auto (Shift Violation) | automatic_ball | 0 | VS | BALL |
| 30 | Strike - Auto (Pitch Timer) | automatic_strike | 0 | AC | CALLED_STRIKE |
| 31 | Strike - Auto (Batter Timeout) | automatic_strike | 0 | AB | CALLED_STRIKE |

**Code group constants** (in Barrelsville `postgame_data.py`, Arm Farm `bullpen_data.py`):
- `BALL_CODES = (1, 2, 4, 5, 11, 15, 17, 26, 27, 28, 29)` — 11 codes
- `WHIFF_CODES = (10, 16, 21, 22, 23, 25)` — 10=Foul Tip, 16=Missed Bunt, 25=Bunt Foul Tip (all swinging strikes)
- `CALLED_STRIKE_CODES = (6, 3, 24, 30, 31)` — 5 codes
- `FOUL_CODES = (7, 8, 9)` — 3 codes (NOT 16, NOT 25)
- `BIP_CODES = (12, 13, 14, 18, 19, 20)` — 6 codes (includes pitchout BIPs)
- **All 31 pitch_result_ids are now classified.** 18/19/20 (pitchout BIPs) and 25 (bunt foul tip) are extremely rare but properly grouped.

---

## Posit Connect DB Connection (WORKING)
FreeTDS driver on Posit Connect Linux server. Golden ticket from Ryan Ferguson:
```python
DRIVER = '/usr/lib/x86_64-linux-gnu/odbc/libtdsodbc.so'
# Domain auth: UID=BASEBALL\zbridger, PWD="" (not needed), TDS_VERSION=7.4, Trusted_Connection=no
# Env vars DB_USER/DB_PASS set in Posit Connect Vars tab
```
> See `docs/ARCHIVED_REFERENCES.md` for full connection code block.

---

## IT Contact
- **Chris Josefy** - Supervisor of Data (cjosefy@astros.com)

## Colors
- Astros Navy: `#002D62`
- Astros Orange: `#EB6E1F`

---

## Environment & Development Workflow

### Machines
- **Personal laptop** (`C:\Users\Owner\`): Windows, Claude Code here, no DB access, GitHub SSH key
- **Work laptop** (`C:\Users\zbridger\`): Windows, DB access via Windows Auth (ODBC Driver 17), testing with live data

### IT Constraints (IMPORTANT -- Do Not Suggest Workarounds)
- **Claude Code BLOCKED on work laptop** -- IT will not allow installation
- **SMTP AUTH disabled**, Slack Incoming Webhooks denied, Slack Bot/App install denied
- **Power Automate Slack Connector** -- cannot access private `zzz_` channels

### Development Workflow (THE ONLY PATH)
```
1. Claude Code runs on PERSONAL laptop (only machine where it's installed)
2. Code written/edited here, committed, pushed to GitHub
3. On WORK laptop: git pull -> test with live DB -> verify
4. Fix issues on personal laptop -> push -> pull on work
```

### Branch Strategy
```
main (stable, production -- merged at milestones)
  ├── feature/pd-goals               <- PD Goals
  ├── feature/bullpen-reports        <- Arm Farm (Bullpen + Postgame)
  ├── feature/astros-intangibles     <- Intangibles
  └── feature/barrelsville           <- Barrelsville (hitting)
```
**Rules:** One branch per project. Only touch your project's subfolder. Shared files (CLAUDE.md, sql-queries/) OK on any branch. Merge to main at milestones.

### Work Laptop (`C:\Users\zbridger\bsb-resources`)
Single repo folder, `git checkout feature/X` to switch branches.
> See `docs/ARCHIVED_REFERENCES.md` for Streamlit run commands, deploy commands, and report generation commands.

### Personal Laptop Worktrees (`C:\Users\Owner\`)

| Path | Branch | Project |
|------|--------|---------|
| `C:\Users\Owner\bsb-resources` | `feature/pd-goals` | PD Goals (main repo, Claude Code here) |
| `C:\Users\Owner\bsb-wt-bullpen` | `feature/bullpen-reports` | Arm Farm + Postgame |
| `C:\Users\Owner\bsb-wt-intangibles` | `feature/astros-intangibles` | Intangibles |
| `C:\Users\Owner\bsb-wt-hitting` | `feature/barrelsville` | Barrelsville (hitting) |
