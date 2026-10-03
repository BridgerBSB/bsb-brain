# BSB Resources - Archived References

Verbose detail sections moved from `CLAUDE.md` to keep the main file concise.
These sections are stable/complete and rarely need editing during active development.

---

## PD Goals — Detailed Current State (Feb 8, 2026)

- **DB CONNECTION WORKING ON POSIT CONNECT** (FreeTDS + domain auth, credit Ryan Ferguson)
- **Dashboard + PDF reports WORKING on work laptop with LIVE DB data**
- Report delivery pipeline TESTED & WORKING (OneDrive -> Power Automate -> Slack)
- Goal parser, stats module, metrics module all functional
- stats.py audited against GC production SQL -- all discrepancies fixed (foul tip=swinging strike, bit column casts, ignore_flag/pitch_id filters, negative LA filter)
- Percentile engine (`src/percentiles.py`) live with league-wide data -- **8 groups, fully migrated to Astros tables (Feb 4):**
  - **Group 1 SplitsBat:** K%, BB%, wOBA, SLG (MLBAM.SplitsBat -- pre-computed, kept on MLBAM)
  - **Group 2 Pitches_View:** Chase%, Oswing, Zswing, Zcon, Whiff%, SwDec, Stuff Grade, FF metrics (Astros.Pitches_View)
  - **Group 3 Hits:** Damage, Barrel%, Avg EV, Top50th EV, Hard Hit% (Astros.Hits)
  - **Group 4-8:** OF Fielding, Bat Speed, Zswing 0-0, Catcher, Count Swings (all Astros tables)
  - Contact detection: `pitch_result_id NOT IN (10,16,21,22,23)` for Astros, `event_type` for MLBAM
  - Damage computed in Python via `calculate_damage_vectorized` (matches GC2 tool formula)
- **Dynamic level detection:** `get_primary_level()` queries where player had most PAs during goal period, not current roster level
- Damage values display 3 decimal places (0.072 not 0.0719)
- Percentage convention: write goals as `K% > 28%` not `0.28` (code handles both but % is standard)
- Goals tab shows first (Upload Goals tab second)
- **Feb 4 major update -- 3-phase visual overhaul (Sam's feedback):**
  - **Period Toggle controls everything:** Renamed Chart Toggle -> Period Toggle, moved above Date Range. All 4 periods (Season, Goal Period, Selected Dates, Recent Week) now control goal squares, bar charts, AND percentile bars simultaneously. Selected Dates added as 4th period throughout dashboard + PDF.
  - **Goal compliance emojis:** checkmark/X (dashboard) and colored check/X (PDF) prepended to every metric value on every active period column. Inches suffix (`"`) on movement metrics (Hop, IVB, HB, Extension, Rel Height, Rel Side).
  - **Percentile bar separation:** Bar charts now colored by goal status (green=met, yellow=within 5%, red=off target) instead of percentile gradient. Percentile info moved to separate battery bar indicators below each goal's bar chart. Gradient changed from blue->gray->red to red->gray->green (red=bad, green=good). Proper ordinal suffixes (1st, 2nd, 3rd, not 1th/2th/3th).
  - **PDF layout:** Columnized battery bars under each goal's chart, 2-column key with Spanish translations, tighter gap between goal rows and bar charts.
  - **Dashboard layout:** Columnized battery bars in "Percentile Rankings" section, key updated with percentile bar explanation.
- **Feb 7 update -- Smart sample sizes + massive percentile expansion:**
  - **Smart sample size display:** Report now shows metric-specific sample sizes instead of generic PA/P counts. E.g., "330 FF" for FF Hop goals, "85 BIP" for Damage goals, "45 2K" for 2-strike usage goals, "210 swings" for Bat Speed.
  - **pBarrel for pitchers:** Now computed via parabolic formula `ev >= 0.011*la^2 - 0.91*la + 95.0` (matches GC2). Uses Hits data joined via Pitches_View.
  - **Bat Speed PERCENTILE:** Now has league-wide percentile! Uses `Astros.Bat_Tracking_Metrics` (all 30 teams). Filters to "competitive swings" (top 90% per player, Baseball Savant method), then AVERAGE (not 95th). v_true_peak * 0.682 = MPH.
  - **Zswing 0-0 PERCENTILE:** Now has league-wide percentile! Queries zone swings where `balls_before=0 AND strikes_before=0 AND csc>=0.5`.
  - **Catcher Defense PERCENTILES:** Now implemented via `CatcherDefense_*` tables:
    - `Frame650` = `raa650` from CatcherDefense_Framing (runs above avg scaled to 650 pitches)
    - `Pop Time` = `pop_time` from CatcherDefense_Throwing
    - `Exchange` = `exch_time` from CatcherDefense_Throwing
    - `Block Value` = `surpluss_pppp` from CatcherDefense_Blocking
  - **Count-Specific Swing PERCENTILES:** Oswing 2K (2-strike chase rate), Oswing 0-0 (first pitch chase rate)
  - **CSV upload hardening:** Date normalization (Excel->ISO), auto-backup before save, template sorting by level+last name, goal text validation with warnings.
- **Feb 8 update -- Sample size unit fixes:**
  - **EVEN -> P:** Even count usage metrics (e.g., "CH Usage in Even") now show "P" unit instead of confusing "EVEN"
  - **Zcon vs. metrics:** Zcon vs. OS, Zcon vs. BB, Zcon vs. FB 95+ now show zone swings on that pitch type (e.g., "14/22 ZSW OS") instead of generic "PA". These are rate metrics (contacts / zone swings on pitch type).

### PD Goals Metric Gaps
- **Stat + percentile WORKING (8 groups in percentiles.py):**
  - Group 1 SplitsBat: K%, BB%, SLG
  - Group 2 Pitches_View: Chase%, Oswing%, Zswing%, Zcon%, OCtct%, ZWhiff%, Whiff%, SwDec, Stuff Grade, FPS%, CSW%, Zone%, FF Hop/Velo/Ext/Spin, SL Velo/Spin, CH Velo, SL/CH Usage 2K/Even, Zcon vs BB/OS/FB95+
  - Group 3 Hits: Damage, Barrel%, Avg EV, Hard%, Top50th EV, pBarrel (pitchers)
  - Group 4 OF Fielding: TopSpd, AccelCU, AccelCD, React, UseReact, ReactRad, ArmOF, ExchOF
  - Group 5 Bat Speed: Avg bat speed (competitive swings, top 90%)
  - Group 6 Zswing 0-0: First pitch zone swing rate
  - Group 7 Catcher: Frame650, Pop Time, Exchange, Block Value
  - Group 8 Count Swings: Oswing 2K, Oswing 0-0
- **COMPUTED (splitter_analysis.py, Feb 9):** wOBA (via Guts.woba_lwts linear weights + Events_View PA outcomes), xwOBACON (via Hits_Probabilities + wOBA weights), SLG (total bases / AB from Events_View)
- **NOT computed yet:** xwOBA full PA-level (needs non-contact events weighted in), HB/Horizontal Break (easy -- same pattern as FF Hop), Spray/Pull% (needs hit_bearing formula), Tilt/Clock (break vector -> clock face), RV Gain (rv_gain column exists), gcPerformanceGrade (need formula from GC)
- **Not planned for MVP:** Baserunning (Baserun_Tracking_*), Force Plate (Sportsmed.ForceDeck_Metrics), INF Fielding (could add using INF_Ability_Metrics)

---

## PD Goals — Dashboard Features (Updated Feb 4, 2026)

- **Period Toggle**: 4 sidebar toggles (2026 Season, Goal Period, Selected Dates, Recent Week) -- controls goal squares, bar charts, AND percentile bars
  - Default: Season + Goal Period on
  - Moved ABOVE Date Range in sidebar; Selected Dates before Recent Week
- **Save Report**: PDF reflects only toggled periods (all 4 supported)
- **Upload Goals**: Appends new periods or updates existing ones, saves to `data/goals.csv`
- **Tab**: Just "Goals" (not "Hitting Goals" / "Pitching Goals")
- **Goal Squares**: Dynamic columns from active toggles, compliance emojis + inches suffix on movement metrics
- **Bar Charts**: Colored by goal status (green=met, yellow=close, red=off), dashed target line, value labels with inches suffix
- **Percentile Rankings**: Battery bar indicators below each goal's bar chart, columnized per goal, red->gray->green gradient, ordinal labels (1st, 2nd, 3rd)
- **Key**: 4 bullets including percentile bar explanation with Spanish translations
- **Automated PDF**: Shows only toggled periods (was hardcoded 3, now dynamic)

---

## PD Goals — Goals CSV Upload Flow & Known Flaws

### Upload Flow (Detailed)
1. Assistant director downloads blank template from dashboard (pre-filled roster with IDs)
2. Fills in `goal_1`, `goal_2`, `goal_3` columns + sets `start_date`/`end_date` for 6-week period
3. Uploads CSV via dashboard Upload Goals tab
4. App compares uploaded `(start_date, end_date)` pairs against existing `data/goals.csv`:
   - **New period dates** -> APPEND those rows (old periods preserved intact)
   - **Same period dates** -> REPLACE only those period's rows (keeps all other periods)
   - **No date columns** -> Full overwrite (replaces everything)
5. Combined DataFrame saved to `pd-goals/data/goals.csv` on disk immediately
6. **Manual git step:** `git add pd-goals/data/goals.csv && git commit && git push`
7. Report pipeline reads from `goals.csv` automatically
8. Next `rsconnect deploy` includes the committed `goals.csv` in the bundle

### Known Flaws (status updated Feb 7)
- **Posit Connect redeploy wipes uploads:** If someone uploads goals via the Posit Connect dashboard (not work laptop), the file lives on the server. Next `rsconnect deploy` overwrites with whatever's in git. Must commit goals.csv before every deploy.
- ~~**No automatic backup:**~~ **FIXED Feb 7** -- Auto-backup now creates `goals_backup_{timestamp}.csv` before every overwrite.
- ~~**No goal text validation:**~~ **FIXED Feb 7** -- Upload now validates with `parse_goal()` and warns about unparseable entries or unrecognized metrics. Data still saved, but user sees warnings.
- ~~**Date format sensitivity:**~~ **FIXED Feb 7** -- Dates normalized to YYYY-MM-DD on upload using `pd.to_datetime().dt.strftime()`. Handles Excel date mangling (2/5/2026 -> 2026-02-05).
- **No concurrency protection:** Two simultaneous uploads = last write wins. Unlikely with small team but possible.
- **Manual git workflow:** Data persistence relies on someone remembering to commit after upload. No automatic reminder.
- **Future fix:** Move goals to a DB table (GroundControl2 or standalone SQLite) -- eliminates all of the above

---

## PD Goals — Metric Formulas Reference

| Metric | Formula | Source |
|--------|---------|--------|
| **Damage** | Complex EV/LA curve -- see `metrics.py:calculate_damage_vectorized()` | GC2 tool |
| **Barrel (hitters)** | `EV >= 98 AND 4 < LA < 50` | Statcast |
| **pBarrel (pitchers)** | `EV >= 0.011*LA^2 - 0.91*LA + 95.0` | GC2 parabolic |
| **Bat Speed (MPH)** | `v_true_peak * 0.682` -> filter to top 90% per player -> AVERAGE | Adam Brodie + Baseball Savant |
| **Zswing 0-0** | Zone swing% on first pitch (`balls_before=0, strikes_before=0, csc>=0.5`) | Internal |
| **Oswing 2K** | Chase% in 2-strike counts (`strikes_before=2, csc<0.01`) | Internal |
| **Oswing 0-0** | Chase% on first pitch (`balls_before=0, strikes_before=0, csc<0.01`) | Internal |
| **Even Count FB%** | FB usage when `balls_before = strikes_before` (pitch types: FF, FT, SI, FC) | Internal |
| **Chase%** | Swing% on pitches with `called_strike_chance_mlb < 0.01` | GC2 |
| **Whiff%** | Swinging strikes / swings (codes 10,16,21,22,23 -- 16=foul tip) | Statcast |
| **Frame650** | `raa650` from CatcherDefense_Framing (runs above avg scaled to 650 pitches) | Astros proprietary |
| **Pop Time** | `pop_time` from CatcherDefense_Throwing (seconds) | Astros proprietary |
| **Block Value** | `surpluss_pppp` from CatcherDefense_Blocking | Astros proprietary |
| **wOBA** | `(w_BB*(BB-IBB) + w_HB*HBP + w_1B*1B + w_2B*2B + w_3B*3B + w_HR*HR) / (AB+BB-IBB+SF+HBP)` | Guts.woba_lwts |
| **xwOBACON** | `AVG((prob_inf_1b+prob_of_1b)*w_1B + prob_2b*w_2B + prob_3b*w_3B + prob_hr*w_HR)` | Hits_Probabilities |
| **SLG** | `(1B + 2*2B + 3*3B + 4*HR) / AB` from Events_View `[1b],[2b],[3b],hr,ab` | Standard |
| **SWM%** | Swinging strikes / swings (same whiff codes as Whiff%) | Internal |
| **OSw%** | `SUM(did_swing*(1-CSC)) / SUM(1-CSC)` (CSC-weighted out-zone swing rate) | GC2 |
| **ZCtct%** | `SUM(CSC for contacts) / SUM(CSC for swings)` (zone contact rate) | GC2 |
| **OCtct%** | `SUM((1-CSC) for contacts) / SUM((1-CSC) for swings)` (out-zone contact rate) | GC2 |

---

## PD Goals — New DB Tables Confirmed (Feb 9, 2026)

- **Events_View full PA columns:** `[1b]`, `[2b]`, `[3b]`, `hr`, `ab`, `bb`, `hbp`, `sf`, `ibb`, `so`, `pa` -- all bit/int, MUST CAST. Join: `pv.cur_event_id = ce.event_id`
- **Guts.woba_lwts:** 30 columns -- `year`, `level_code`, `league`, `wOBA_BB`, `wOBA_HB`, `wOBA_1B`, `wOBA_2B`, `wOBA_3B`, `wOBA_HR`, `wOBA_scale`, `runs_per_pa`, `FIPconstant`, etc. Join via `year + league` (through MLBAM.Schedule for league)
- **Astros.Hits_Probabilities:** `prob_inf_1b`, `prob_of_1b`, `prob_2b`, `prob_3b`, `prob_hr`, `prob_inf_out`, `prob_of_out`. Join: `pv.sched_id = hp.sched_id AND pv.pitch_id = hp.pitch_id`
- **Guts.hit_specs_ratios:** PERMISSION DENIED -- not accessible via zbridger

---

## Percentile Migration Reference (Feb 4, 2026)

**What moved:** All Group 2 (pitch-level) metrics from `MLBAM.Pitch_fx` -> `Astros.Pitches_View`
**What stayed on MLBAM:** Group 1 SplitsBat (K%, BB%, SLG) -- pre-computed table, no benefit to switching
**What was already Astros:** Group 3 Hits (Damage, Barrel, EV, Hard Hit%) -- unchanged

| MLBAM.Pitch_fx Column | Astros.Pitches_View Column | Notes |
|------------------------|---------------------------|-------|
| `did_swing = 'Y'` | `did_swing = 1` | varchar -> int |
| `event_type IN ('swinging_strike',...)` | `pitch_result_id IN (10,16,21,22,23)` | String -> code (16=foul tip) |
| `event_type NOT IN (...)` for contact | `pitch_result_id NOT IN (10,16,21,22,23)` | Same logic, code-based |
| `initial_speed` | `release_speed` | Different column name |
| `InducedVertBreak` | `inducedvertbreak` | Case difference |
| `swing_decision_score` | `swing_decision_grade_2080` | Different column name, may differ in scale |
| `stuffrelvel_grade_2080` | `stuffrelvel_grade_2080` | Same |
| `called_strike_chance_mlb` | `called_strike_chance_mlb` | Same |
| `pitcher_throws` / `bat_side` | `pitcher_throws` / `bat_side` | Same |
| `pitch_type` | `pitch_type` | Same |
| `balls_before` / `strikes_before` | `balls_before` / `strikes_before` | Same |
| N/A | `ignore_flag = 0 AND pitch_id > 0` | Quality filters added |

**Join pattern (new):**
```sql
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE sv.level_code = '{level}'  -- MLBAM SPORT codes (aax, afa, etc.)
  AND YEAR(sv.sched_date) = {season}
  AND pv.ignore_flag = 0 AND pv.pitch_id > 0
```

---

## Report Delivery Pipeline (TESTED & WORKING as of Jan 29, 2026)

### Architecture
```
Python script (generates PDFs)
    -> saves to local repo: pd-goals/reports/
    -> saves to OneDrive: C:\Users\Owner\OneDrive - Houston Astros, LLC\pd-goals-reports\
        -> OneDrive syncs to cloud automatically
            -> Power Automate scheduled flow picks up files
                -> sends email with PDF attachment to Slack channel email
                    -> PDF appears in Slack channel
```

### What Was Tested & Confirmed Working
1. Python generates PDF (Freuddy_Batista_769558.pdf) - WORKS
2. PDF copied to OneDrive local folder - WORKS
3. OneDrive syncs to cloud (astros-my.sharepoint.com) - WORKS
4. Power Automate flow reads files from OneDrive folder - WORKS
5. Power Automate sends email with PDF to Slack channel email - WORKS
6. PDF appears in Slack channel (pd-automation-test) - WORKS

### What Was Tried & BLOCKED
- Slack Incoming Webhooks: DENIED by IT
- Slack Bot Token / App Install: DENIED by IT
- Power Automate Slack Connector: Can't access private channels
- SMTP AUTH (smtplib from Python): DISABLED on zbridger@astros.com account
- Power Automate HTTP Request Trigger: Premium connector, not available as trigger
- SharePoint document creation: No write permissions

### Power Automate Flow: "pd-goals" (WORKING)
- **Trigger**: Manual trigger (for now; switch to Scheduled daily at 6 AM for production)
- **Step 1**: OneDrive for Business - List files in folder (`/pd-goals-reports/`)
- **Step 2**: Apply to each (loops through all files)
- **Step 3** (inside loop): Get file content (OneDrive for Business)
- **Step 4** (inside loop): Send an email (V2) with file as attachment to Slack channel email
- Connected as: zbridger@astros.com

### PDF Naming Convention (PRODUCTION)
```
{FirstName}_{LastName}_{GroundControlID}_{EndDate}.pdf
Example: Freuddy_Batista_769558_2026-02-12.pdf
```
- End date included so we know which goal period the report covers
- GroundControlID used to look up the destination Slack channel email from slack_channels.csv

### Slack Channel Email Routing
- Mapping stored in: `pd-goals/data/slack_channels.csv`
- Columns: `groundcontrol_id, player_name, channel_name, channel_email, channel_type`
- `channel_type` values: `coach` (normal) or `overflow` (catchall)
- **Overflow channel**: `pd-automation-test`
  - Email: `pd-automation-test-aaaas44nozinf2mpp4jtly3nuu@astros.org.slack.com`
  - Players WITHOUT a paired zzz_ channel get reports sent here
  - Also used for testing
- To collect channel emails: Slack > channel header > Integrations > "Send emails to this channel"
- **Manual process**: update CSV when players sign (add row) or get cut (no action needed - script just won't generate report if no active goals)

### OneDrive Paths
- **Local (personal PC)**: `C:\Users\Owner\OneDrive - Houston Astros, LLC\pd-goals-reports\`
- **Cloud**: `astros-my.sharepoint.com/personal/.../pd-goals-reports/`
- **Work laptop** (when set up): same OneDrive path, will sync to same cloud folder

### Making It Production-Ready (TODO)
1. **Update report.py**: Add end_date to PDF filename, copy to OneDrive, look up channel email from slack_channels.csv, route overflow to catchall
2. **Update Power Automate flow**: Scheduled daily 6 AM, dynamic routing, delete/move after send
3. **Collect all zzz_ channel emails**: manual one-time task in Slack
4. **Windows Task Scheduler**: Python script at 5:30 AM before Power Automate flow
5. **Postgame reports**: same pipeline, different trigger time (4-6 AM)

---

## Postgame Reports -- Detailed Current State (Feb 16, 2026)

- **PDF generation TESTED & WORKING on work laptop with live DB**
- **Streamlit app v2 COMPLETE** -- multi-page app via `pages/2_Postgame.py`
- **Page 1 (Stuff):** plottable tables, rolling velo chart, movement scatter, 6 pie charts, Key KPIs box
- **Page 2+ (LVA):** Location vs Action heatmap grid (pitch type x count state x batter hand)
  - Diverging Red->White->Blue projection-grade heatmaps (fb_grade, 20-80 scale)
  - Numpy gaussian fallback when scipy unavailable (work laptop)
  - Per-cell cascading data fallback: curr-year R (100+) -> prev-year R (100+) -> all-years R (100+) -> all RSEVI
  - Normalization: raw grades -> gaussian smooth -> clip AFTER averaging (per Brodie SE guidance)
  - Overflow to page 3+ if >6 pitch types
  - Black vertical separator between LHH/RHH columns
- **ALL metrics have percentile coloring** -- gcERA was last one, now done (Feb 15)
- **Percentile keys:** 9-square gradient on both pages ("Poor"->"Great"), with contextual subtitles
- **Tables:** plottable library with native cmap coloring (rounded rectangle backgrounds)
- **Percentiles:** 6 SQL distribution queries per level+season (game-level + per-pitch-type + gcERA)
- **gcERA matches GC2 exactly:** pitch-weighted product-of-averages, not per-PA average
- **Charts:** Rolling velo (per-type line chart), pitch movement (scatter), 6 usage pie charts
- **Headshots:** MiLB CDN via mlbam_id lookup
- **Goals:** Reads from pd-goals/data/goals.csv by groundcontrol_id
- **Delivery:** CLI -> PDF -> OneDrive subfolders -> Power Automate -> Slack (or `--deliver` via Azure Logic App)
- **Level codes:** Supports both MLBAM (aax, afa) and PP_MASTER (2a, 1a) -> display as AA, A+, etc.
- **Multi-level percentiles:** When outings span levels, uses most-played level for percentile ranking
- **Click-to-video:** Plotly chart clicks open Synergy video (movement scatter, rolling velo)
- **App v2 layout:** Key KPIs + Pitch Arsenal + Color Key top row, Statline table, Customize Columns expander, Pitch Characteristics, Pitch Results, Rolling Velo (On Pitch / Avg toggle), 6 charts (3+3), Reclassification, Individual Pitches w/ video
- **Feb 16 updates (post-testing):**
  - **Renamed P2K Z% -> 0-1 IZ%** everywhere (app + PDF statline + pitch results)
  - **Removed InZ% percentile coloring** -- InZ% now displays value only, no colored background
  - **PDF reflects app custom columns** -- Customize Table Columns selections + rolling metric/mode carry to PDF via `generate_postgame_report()` params. CLI/automated reports use defaults; app can pass expanded set via `_ALL_*_DEFS`.
  - **Daily tab pitch reclassification** -- movement chart (lasso/box select) + pitch table with Spin + video, reclassify panel (Apply/Remove), same pattern as Bullpen Daily
  - **Player switch resets to most recent outing** -- date inputs + sched type multiselect session state keys reset on player change (Streamlit ignores `value=`/`default=` once key exists)
  - **2K Proj has dedicated percentile distribution** -- game-level `proj_2k` from advanced statline query, NOT reusing general `proj` pool. Per-pitch-type was already correct.

---

## Postgame Metrics Reference

| Metric | Formula | Percentile |
|--------|---------|------------|
| **Strk%** | Non-ball pitches / total | Game-level + per-pitch-type |
| **SWM%** | Swinging strikes / total pitches (codes 10,16,21,22,23) | Game-level + per-pitch-type |
| **InZ%** | CSC >= 0.5 / total pitches | **No percentile** (value only) |
| **0-1 IZ%** | Zone rate (CSC >= 0.5) where strikes_before < 2 | Game-level + per-pitch-type |
| **FPinZ%** | Zone rate on 0-0 count (balls=0, strikes=0) | Game-level (fps_pct dist) |
| **R2K%** | PAs reaching 2K before 2B / total PAs | Game-level (CTE query) |
| **EW%** | Early count BIP with EV<=89 and LA outside 10-35 / early BIP | Game-level |
| **2KProj** | AVG(fb_grade) on 2-strike pitches (excl 3-2) | **Game-level (dedicated proj_2k dist) + per-pitch-type** |
| **pBrl%** | EV >= 0.011*LA^2 - 0.91*LA + 95.0 / BIP | Game-level + per-pitch-type |
| **Proj** | AVG(fb_grade) from Projections_Pitches_Grades | Game-level |
| **gcPerf** | 50 - 1500 * AVG(per-pitch run values) | Game-level |
| **gcERA** | GC2 pitch-weighted: (3.9+31.1*HR_rate)*bip_rate*pBrl_rate + 3.5*bip_rate*(1-pBrl_rate) + (-3.3)*so_rate + 9.9*bb_hbp_rate | Game-level |
| **StuffRelVelo** | AVG(stuffrelvel_grade_2080) 20-80 scale | Per-pitch-type |
| **SwDec** | AVG(swing_decision_grade_2080) 20-80 scale | Per-pitch-type |

---

## Postgame Percentile Architecture

- **6 SQL queries** per level+season, cached via `@lru_cache`
- **Per-pitch-type keys:** `"metric:PT"` format (e.g., `"whiff_pct:FF"`, `"swdec:SL"`)
- **Game-level keys:** plain metric name (e.g., `"strike_pct"`, `"r2k_pct"`)
- **Color gradient:** Red (#E53935) -> White (#FFFFFF) -> Green (#66BB6A)
- **`higher_is_better` flag:** True = high pctile -> green; False = high pctile -> red (pBrl%)
- **Minimum samples:** 20 pitches/game-appearance, 30 pitches/pitch-type, 5 PAs for R2K%
- **Fallback:** Current season -> prior year if insufficient Regular Season data

---

## plottable Library Patterns (CRITICAL for Postgame)

- **cmap ONLY works with NUMERIC cell values.** String values -> uniform default color.
- For string columns needing coloring (e.g., Pitch names): store numeric index in DataFrame, use `formatter` closure to display text, use `cmap` with `{float_idx: hex_color}` dict.
- For percentile coloring: use `cmap` + `formatter` + `textprops={"bbox": {"boxstyle": "round,pad=0.3", "edgecolor": "none"}}`.
- Pre-compute `{float_value: hex_color}` dicts per column before creating Table (cmap is per-column, no row context).
- Hidden index column: `ColumnDefinition(name="idx", width=0.001, textprops={"fontsize": 0.1, "color": "white"})`.

---

## Arm Farm -- Landing Page Design

- Retro arcade aesthetic: spinning Astros logo (CSS @keyframes rotateY coin-flip)
- Typography: Press Start 2P (headers) + VT323 (body) -- Google Fonts
- Colors: Astros Navy (#002D62) cards + Orange (#EB6E1F) accents
- Navigation: st.switch_page() buttons + HTML cards (dual nav for reliability)
- Rendered via `st.components.v1.html()` (~200 lines HTML/CSS/JS)
- Design system persisted: `design-system/astros-arm-farm/MASTER.md`

---

## Work Laptop Commands Reference

### Run Streamlit Apps
```powershell
# Arm Farm (from bullpen-report/)
cd C:\Users\zbridger\bsb-resources\bullpen-report
python -m streamlit run Arm_Farm.py

# Intangibles (from intangibles/)
cd C:\Users\zbridger\bsb-resources\intangibles
python -m streamlit run app.py
```

### Deploy to Posit Connect
```powershell
cd C:\Users\zbridger\bsb-resources\bullpen-report

# Arm Farm (Bullpen + Postgame)
C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe deploy manifest . --server https://connect2.astros.com --api-key lbMcrPhsgeyCZnIjcXjBoIQZRWZKWMzO --app-id 13482bcb-8ff2-4f20-92c9-5465f49e5846 --title "Arm Farm"

# PD Goals
C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe deploy manifest . --server https://connect2.astros.com --api-key lbMcrPhsgeyCZnIjcXjBoIQZRWZKWMzO --app-id 79f52369-8244-46da-a4d6-95df956bacad --title "PD Goals"
```

### Generate Automated Reports
```powershell
cd C:\Users\zbridger\bsb-resources\bullpen-report

# Postgame reports for a date
python scripts/generate_postgame.py --date 2026-02-15 --copy-onedrive

# Side (bullpen) reports
python scripts/generate_reports.py --date 2026-02-14 --copy-onedrive

# Single pitcher
python scripts/generate_reports.py --date 2026-02-13 --pitcher 69773 --copy-onedrive
```

---

## Astros vs MLBAM Tables -- Extended Details

- **Percentiles** can come from EITHER schema. Astros.Pitches_View is preferred because it has proprietary columns (stuffrelvel_grade_2080, swing_decision_grade_2080) and consistent data types (did_swing as int, not varchar).
- **Production_Percentile:** Pre-computed OVERALL production percentile by `groundcontrol_id + season + level` (1-100). NOT per-metric -- for K%, EV, etc. percentiles, compute from YTD tables via `PERCENT_RANK()`
- **Bat speed:** `Astros.Bat_Tracking_Metrics.v_true_peak` (FPS) * 0.682 = MPH. This is peak swing speed at interpolated peak (NOT Statcast's contact speed). Source: Adam Brodie (RnD).
- **Catcher Defense tables** (explored Feb 7, 2026):
  - `Astros.CatcherDefense_Framing`: `groundcontrol_id`, `pos`, `year`, `qualifying_pitches`, `net_strikes_per_pitch`, `adj_net_strikes_per_pitch`, `raa`, `raa650` (**Frame650**)
  - `Astros.CatcherDefense_Throwing`: `groundcontrol_id`, `year`, `pop_time` (**Pop Time**), `exch_time` (**Exchange**), `throw_time`, `t_rec_after_pitch_rel`, `r1_dist_from_2B_at_*`
  - `Astros.CatcherDefense_Blocking`: `groundcontrol_id`, `pos`, `year`, `surpluss_pppp` (**Block Value**), `np`, `ic`, `xpp`, `pp`, `pb`, `r`
  - `Astros.CatcherDefense_Arm`: arm strength metrics
  - `Astros.CatcherDefense_SBA_Metrics`: stolen base attempt metrics
- **MLBAM.Hits is NOT broken** -- `sv_pitch_id` IS populated in MLBAM.Hits. The broken join is `MLBAM.Pitch_fx.sv_pitch_id` (NULL) -- so you can't join Pitch_fx->Hits to get batter_id. Workaround: use Astros.Hits (has all teams). MLBAM.Hits columns: `hit_initial_speed` (EV), `hit_vertical_angle` (LA), `hit_horizontal_angle` (spray angle), `hit_initial_contact_point_x/y/z`, `hit_initial_velocity_x/y/z`, `hit_average_lop_error`, `hit_chopper`.
- **Percentile migration COMPLETE (Feb 4):** Pitch-level metrics migrated from MLBAM.Pitch_fx -> Astros.Pitches_View. SplitsBat stays on MLBAM. Damage/Barrel via Astros.Hits (unchanged).
- **did_swing type:** Astros = `did_swing = 1` (int). Old MLBAM = `did_swing = 'Y'` (varchar).
- **MLBAM.SplitsBat / SplitsPit** = Gold mine for platoon percentiles. Pre-computed splits by `sit_code` ('vl'=vs Left, 'vr'=vs Right, etc.), 82 split types.
- **Platoon percentiles:** Filter SplitsBat by `sit_code='vl'` (or 'vr') + `level` + `year`, then PERCENT_RANK().
- **GC production queries** saved in `sql-queries/gc-hitter-production-queries.sql`
- **MLBAM exploration queries** saved in `sql-queries/mlbam-exploration-queries.md`
- **Comprehensive DB reference:** `sql-queries/DATABASE_REFERENCE.md`
- **MLBAM YTD table columns:** `sql-queries/mlbam-ytd-columns.csv`
- **Pitch type classification:** FF/FT/SI=Fastball, SL/CU/FC=Breaking, CH/FS/SC/KN=Offspeed
- **Astros.LK_* tables:** Lookup tables with value definitions -- run `SELECT * FROM Astros.LK_<name>` for definitions
