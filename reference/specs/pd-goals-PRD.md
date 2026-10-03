# PD Goals App - Product Requirements Document

> **Version:** 2.2
> **Created:** January 26, 2026
> **Updated:** February 8, 2026
> **Author:** Z. Bridger + Claude
> **Status:** MVP Complete — Live on Posit Connect with DB Connection + Expanded Percentiles

---

## 📋 Table of Contents
1. [Overview](#overview)
2. [Components](#components)
3. [Data Sources](#data-sources)
4. [User Interface](#user-interface)
5. [Goal Management](#goal-management)
6. [Metrics Reference](#metrics-reference)
7. [Technical Implementation](#technical-implementation)
8. [CSV Template](#csv-template)
9. [Open Questions](#open-questions)
10. [Implementation Phases](#implementation-phases)

---

## 🎯 Overview

### Purpose
Track and visualize player development goals for Houston Astros minor league players. Each player has 1-3 goals measured over 6-week periods, with both a dashboard view and automated reporting capability.

### Two Components
1. **Dashboard (Streamlit App)** - Interactive player goal tracking
2. **Automated Reports** - Scheduled 6-week goal summaries (terminal-based)

### Target Users
- Player Development staff
- Coaches
- Front office

---

## 🧩 Components

### Component 1: Interactive Dashboard (BUILT — Updated Feb 4)
- Player selection by Level + Name
- Date range filtering with quick buttons (Last 6 Weeks, All Season)
- Goal progress visualization with trend arrows (↑↓) and color-coded status
- **Period Toggle**: 4 sidebar toggles (2026 Season, Goal Period, Selected Dates, Recent Week) — controls goal squares, bar charts, AND percentile bars
- **Save Report**: PDF download reflecting only toggled periods (all 4 supported)
- **Upload Goals**: Append-and-save CSV upload (new periods append, same periods update)
- Goal period buttons for quick-switching between 6-week windows
- Platoon + count filtering support
- **Goal compliance emojis**: ✅/❌ on every metric value across all active period columns
- **Inches suffix**: Movement metrics (Hop, IVB, HB, Extension) display `"` suffix
- **Percentile Rankings section**: Battery bar indicators below each goal's bar chart, red→gray→green gradient, ordinal labels (1st, 2nd, 3rd)

### Component 2: PDF Reports (BUILT — Updated Feb 4)
- Bar charts colored by goal status (green=met, yellow=within 5%, red=off target)
- Dynamic periods: shows only toggled periods (was hardcoded 3, now supports all 4)
- Dashed target line, actual value above bars
- Colored ✓/✗ compliance markers on goal rows (matplotlib-safe unicode)
- Inches suffix on movement metrics
- **Percentile battery bars**: Separate indicators below each goal's bar chart, red→gray→green gradient, ordinal labels
- 2-column key with Spanish translations
- Astros branding (navy header, cap logo)
- Delivery: OneDrive → Power Automate → Email → Slack channel

### Component 3: Report Delivery Pipeline (TESTED & WORKING)
- Python generates PDFs → saves to OneDrive local folder
- OneDrive syncs to cloud automatically
- Power Automate flow picks up files → sends email with PDF to Slack channel email
- PDF appears in coach-facing `zzz_` Slack channels

---

## 🗄️ Data Sources

### Primary Roster Query
See: [sql-queries/live_rosters_cristian.sql](../sql-queries/live_rosters_cristian.sql)

```sql
-- Include all statuses EXCEPT Released (REL) and Free Agent (FA)
WHERE 
    pm.levelofplay_lk IN ('ml', '3a', '2a', '1a', '1f', 'r', 'ds')
    AND pm.mnrosterstatus_lk NOT IN ('rel', 'fa')
    AND pm.org_lk = 'hou'
```

### Key Tables (Confirmed Jan 31, 2026 via DB Discovery)
| Source | Table | Purpose | Join Notes |
|--------|-------|---------|------------|
| `Astros.Players` | Player master | `groundcontrol_id`, names, bats/throws | Direct lookup |
| `MLB_eBis.PP_MASTER` | Current roster | `levelofplay_lk`, `mnrosterstatus_lk`, `position_lk` | JOIN on `groundcontrol_id` |
| `Astros.Pitches_View` | Pitch-level data (107 cols) | Most metrics, player IDs, stuff grades | Central table — `batter_id`, `pitcher_id` live here |
| `Astros.Schedule_View` | Game schedule | Date filtering (`sched_date`), level info | JOIN on `sched_id` |
| `Astros.Hits` | Batted balls | EV (`hit_exit_speed`), LA (`hit_vertical_angle`) | JOIN via Pitches_View (`sched_id + pitch_id`) — no `batter_id` |
| `Astros.Events_View` | PA outcomes (68 cols) | K%, BB% (bit flags: `so`, `bb`, `pa`) | JOIN via Pitches_View (`sched_id + event_id = cur_event_id`) — no `batter_id` |
| `Astros.Hits_Probabilities` | Hit outcome probs | xwOBA derivation | JOIN via Pitches_View (`sched_id + pitch_id`) |
| `Astros.Bat_Tracking_Metrics` | Bat tracking | `v_true_peak` bat speed (data may be sparse) | Has `groundcontrol_id` directly |
| `Astros.Pitches_Grades` | Pitch grades | Stuff/command 20-80 grades (also in Pitches_View) | JOIN via Pitches_View (`sched_id + pitch_id`) |
| `Astros.LK_Pitch_Results` | Lookup table | 31 pitch result codes for CSW%, Whiff% | Reference only |
| `Guts.woba_lwts` | wOBA coefficients | xwOBA calculation weights by year | Reference by year |
| `Astros.CatcherDefense_Framing` | Catcher framing | `raa650` (Frame650), `net_strikes`, `adj_net_strikes_per_pitch` | By `groundcontrol_id + year` |
| `Astros.CatcherDefense_Throwing` | Catcher arm | `pop_time`, `exch_time`, throw metrics | By `groundcontrol_id + year` |
| `Astros.CatcherDefense_Blocking` | Catcher blocking | `surpluss_pppp` (Block Value), `gross_pppp` | By `groundcontrol_id + year` |
| `Astros.Bat_Tracking_Metrics` | Bat speed | `v_true_peak` (FPS) * 0.682 = MPH, competitive swings | By `groundcontrol_id + pitch_id` |

### Game Type Filtering (Schedule_View.sched_type)
| Code | Type | Include? |
|------|------|----------|
| `R` | Regular Season | Yes |
| `S` | Spring Training (GF/CL) | Yes |
| `U` | Other Spring | Yes |
| `F` | Wild Card | Yes |
| `D` | Division Series | Yes |
| `L` | League Championship | Yes |
| `W` | World Series | Yes |
| `C` | Other Playoff | Yes |
| `P` | Preseason | No (unofficial) |
| `E` | Exhibition | No (unofficial) |
| `I` | Intrasquad | No (unofficial) |
| `B` | B-Game | No (unofficial) |
| `V` | Various | No (unofficial) |

**Current:** No filter applied (include all). **Future:** Add `WHERE sv.sched_type NOT IN ('P','E','I','B','V')`.

### MLBAM vs Astros Tables
- **Astros.\*** tables = ALL teams, ALL levels (MLB, MiLB, college, international, etc.) — "Astros" means "processed into Astros DB format with our models", NOT Astros-only data. Confirmed by Adam Brodie (RnD) and Nick Arrivo (Feb 3, 2026).
- **MLBAM.\*** tables = All 30 MLB teams (league-wide Statcast data, different schema/columns)
- **Join pattern:** `Astros.Players.mlbam_id → MLBAM.*.player_id`, `Schedule_View.mlbam_game_pk → MLBAM.*.game_pk`
- **Percentiles** can come from EITHER schema. Astros.Pitches_View is preferred (has proprietary columns like stuff grades, swing decision). MLBAM currently used for some metrics, migration to Astros planned.
- See `sql-queries/mlbam-exploration-queries.md` for discovery queries

### Critical Column Name Corrections
| Wrong Name | Correct Name | Table |
|------------|-------------|-------|
| `balls` | `balls_before` | Pitches_View |
| `strikes` | `strikes_before` | Pitches_View |
| `batter_side` | `bat_side` | Pitches_View |
| `pitch_number` | `ab_pitch_number` | Pitches_View |
| `game_date` | `sched_date` | Schedule_View |

### Roster Status Codes (from MLB_eBis.PP_MASTER)
| Code | Description | Count | Include? |
|------|-------------|-------|----------|
| `ACT` | Active | 230 | ✅ Yes |
| `VOL` | Voluntary (retired?) | 129 | ❌ No |
| `RES` | Restricted (?) | 41 | ❓ TBD |
| `DIS` | Disabled/Released? | 6 | ❓ TBD |
| `PAC` | ? | 4 | ❓ TBD |
| `FA` | Free Agent | 3 | ❌ No |
| `REL` | Released | 3 | ❌ No |
| `NULL` | No status | 46 | ❓ TBD |

**Question:** Which status codes include injured players? Need to confirm with assistant director.

### Position Codes (from MLB_eBis.PP_MASTER.POSITION_LK)
| Code | Description | Count |
|------|-------------|-------|
| `RHS` | Right-Handed Starter (Pitcher) | 119 |
| `OF` | Outfield | 30 |
| `SS` | Shortstop | 29 |
| `C` | Catcher | 22 |
| `IF` | Infield | 8 |
| `RHR` | Right-Handed Reliever | RHP |
| `LHS` | Left-Handed Starter | LHP |
| `LHR` | Left-Handed Reliever | LHP |
| `C` | Catcher | C |
| `1B` | First Base | INF |
| `2B` | Second Base | INF |
| `3B` | Third Base | INF |
| `SS` | Shortstop | INF |
| `IF` | Infield (utility) | INF |
| `LF` | Left Field | OF |
| `CF` | Center Field | OF |
| `RF` | Right Field | OF |
| `OF` | Outfield (utility) | OF |

**Position Categories for Reports:**
- **Pitchers:** Normalize to RHP or LHP for goal norming
- **Catchers:** Unique defensive metrics (framing, blocking, pop times)
- **Infielders:** 1B, 2B, 3B, SS, IF → React, ReactRad, ArmINF, ExchINF
- **Outfielders:** LF, CF, RF, OF → UseReact, ArmOF, ExchOF

### Level Codes Mapping
| `levelofplay_lk` | Affiliate |
|------------------|-----------|
| `ml` | HOU (MLB) |
| `3a` | AAA Sugar Land |
| `2a` | AA Corpus Christi |
| `1a` | A+ Asheville |
| `1f` | A Fayetteville |
| `r` | FCL |
| `ds` | DSL |

---

## 🖥️ User Interface

### Sidebar (Built — Updated Feb 4)
1. **Save Report Button** — generates PDF reflecting toggled periods
2. **Period Toggle** — 4 toggles (2026 Season, Goal Period, Selected Dates, Recent Week). Default: Season + Goal Period on. Controls goal squares, bar charts, AND percentile bars.
3. **Date Range** — Start/End date pickers + quick buttons (Last 6 Weeks, All Season)
4. **Level Dropdown** — All Levels or specific affiliate, filters player list
5. **Player Dropdown** — filtered by level, format: "Last, First (Position)"
6. **Goal Period Buttons** — horizontal buttons for each period from CSV (● Active, ✓ Past, ○ Future)
7. **Connection Status** — shows "Connected to GC2" or "Demo Mode (no DB)"

### Main Content (Built — Updated Feb 4)
1. **Player Header** — Name, Level, Position, B/T, headshot, Astros logo
2. **Upload Goals Tab** — CSV upload with append-and-save, countdown to period end, preview table
3. **Goals Tab** — Dynamic columns from active toggles showing:
   - Compliance emoji (✅/❌) + metric value (color-coded: green=met, yellow=within 5%, red=off)
   - Inches suffix on movement metrics (Hop, IVB, HB, Extension)
   - Trend arrow with % from target
   - Sample size (PA or pitches)
4. **Performance Charts** — Bar charts per goal colored by goal status (green/yellow/red), dashed target line
5. **Percentile Rankings** — Battery bar indicators below each goal's bar chart, red→gray→green gradient, ordinal labels (1st, 2nd, 3rd)

---

## 📊 Goal Management

### Goal Structure
Each goal has:
- **Metric** - What we're measuring (e.g., "FF iVB", "Damage%", "K%")
- **Direction** - Increase (↑) or Decrease (↓)
- **Target Value** - The number we're aiming for
- **Timeframe** - 6-week periods

### Goal Input Method: CSV Upload (BUILT)
- Assistant director creates CSV with goals for new 6-week period
- Uploads via dashboard Upload Goals tab
- **New period**: rows APPENDED to existing data (historical periods preserved)
- **Same period re-upload**: rows REPLACED for that period only
- Saves to `pd-goals/data/goals.csv` on disk automatically
- Analyst commits to GitHub for version control

### Goal Convention: Percentages
- Write percentage goals as actual percentages: `K% > 28%` (not `0.28`)
- Code handles both formats (auto-converts decimals < 1) but percentages are standard
- Non-percentage metrics use raw values: `Damage > 0.034`, `SwDec > 50`

### Goal Limits
- Minimum: 1 goal per player
- Maximum: 3 goals per player
- Players with no goals: omit from CSV (system skips them)

---

## 📈 Metrics Reference

### Priority Metrics for MVP

#### Hitter Metrics
| Metric | Column/Formula | Table |
|--------|----------------|-------|
| **Damage%** | Complex formula (see DATABASE_REFERENCE.md) | Astros.Hits |
| **Barrel%** | EV/LA formula | Astros.Hits |
| **K%** | SO / PA | Astros.Events_View |
| **BB%** | BB / PA | Astros.Events_View |
| **Chase%** | Swing on pitches < 0.01 csc_mlb | Astros.Pitches_View |
| **xwOBA** | Expected wOBA | Astros.Hits_Probabilities |
| **Bat Speed** | `v_true_peak * 0.682` (competitive = top 90%) | Astros.Bat_Tracking_Metrics |
| **Top 50th EV** | Top half EV average | Astros.Hits |
| **Zswing 0-0** | Zone swing% on first pitch, CSC-weighted | Astros.Pitches_View |
| **Oswing 0-0** | Out-of-zone swing% on first pitch | Astros.Pitches_View |
| **Oswing 2K** | Out-of-zone swing% with 2 strikes | Astros.Pitches_View |

#### Pitcher Metrics
| Metric | Column/Formula | Table |
|--------|----------------|-------|
| **FF iVB (Hop)** | `inducedvertbreak` WHERE pitch_type='FF' | Astros.Pitches_View |
| **SL HB** | `horzbreak` WHERE pitch_type='SL' | Astros.Pitches_View |
| **CH Shape** | TBD | Astros.Pitches_View |
| **K%** | SO / BF | Astros.Events_View |
| **BB%** | BB / BF | Astros.Events_View |
| **Stuff Grade** | `stuffrelvel_grade_2080` | Astros.Pitches_View (directly) |
| **Whiff%** | Swinging strikes / Swings | Astros.Pitches_View |
| **pBarrel** | `ev >= 0.011*la² - 0.91*la + 95.0` | Astros.Hits |

#### Catcher Metrics
| Metric | Column/Formula | Table |
|--------|----------------|-------|
| **Frame650** | `raa650` (runs above avg per 650 pitches) | Astros.CatcherDefense_Framing |
| **Pop Time** | `pop_time` (seconds to 2B) | Astros.CatcherDefense_Throwing |
| **Exchange Time** | `exch_time` (catch-to-release) | Astros.CatcherDefense_Throwing |
| **Block Value** | `surpluss_pppp` (surplus value) | Astros.CatcherDefense_Blocking |

### Level-Based Percentile Tables
For table displays, show percentiles **by level**:
- Bat Speed percentile at AA
- xwOBACON percentile at AAA
- etc.

---

## 🔧 Technical Implementation

### Tech Stack
- **Frontend:** Streamlit
- **Backend:** Python + SQLAlchemy
- **Database:** SQL Server (GCSQL02.ASTROS.COM → GroundControl2)
- **Auth (Posit Connect):** FreeTDS driver + domain auth (BASEBALL\zbridger), no password needed
- **Auth (Local dev):** Windows Authentication (ODBC Driver 17)
- **Hosting:** Posit Connect (`connect2.astros.com`), App GUID: `79f52369-8244-46da-a4d6-95df956bacad`

### File Structure
```
pd-goals/
├── app.py                 # Streamlit dashboard
├── PRD.md                 # This document
├── README.md              # Setup guide, CSV docs, delivery pipeline
├── requirements.txt       # Dependencies
├── data/
│   ├── goals.csv          # Production goals (created by upload, persists)
│   ├── mock_goals.csv     # Fallback mock data for testing
│   └── slack_channels.csv # Slack channel email routing
├── src/
│   ├── __init__.py
│   ├── database.py        # DB connection (FreeTDS on Posit, Windows Auth local)
│   ├── goal_parser.py     # Parse goal text like "Damage% > 0.034"
│   ├── metrics.py         # Metric definitions and calculations
│   ├── percentiles.py     # MLBAM league-wide percentile engine
│   ├── report.py          # PDF report generation (matplotlib)
│   ├── roster.py          # Roster queries
│   └── stats.py           # Stat calculations (live DB queries)
├── reports/               # Generated PDF reports
└── test_email.py          # Email delivery test script
```

### Character Encoding
- Use UTF-8 throughout
- Handle Spanish accents: é, ñ, ú, etc.
- Ensure name matching works with/without accents

### Name Matching Strategy
```python
import unicodedata

def normalize_name(name):
    """Normalize name for matching (handle accents)."""
    # NFD decomposition then remove combining characters
    normalized = unicodedata.normalize('NFD', name)
    ascii_name = ''.join(c for c in normalized if not unicodedata.combining(c))
    return ascii_name.lower().strip()
```

---

## 📄 CSV Template

### Generated Template Columns
| Column | Description | Source |
|--------|-------------|--------|
| `groundcontrol_id` | Primary player ID | Astros.Players |
| `ebis_id` | eBis system ID | MLB_eBis.PP_MASTER |
| `player_name` | "First Last" | Astros.Players |
| `position` | Primary position | MLB_eBis.PP_MASTER |
| `level` | Current affiliate | MLB_eBis.PP_MASTER |
| `bats` | L/R/S | Astros.Players |
| `throws` | L/R | Astros.Players |
| `start_date` | Goal period start | Generated (6-week periods) |
| `end_date` | Goal period end | Generated (6-week periods) |
| `goal_1` | First goal | **User enters** |
| `goal_2` | Second goal | **User enters** |
| `goal_3` | Third goal | **User enters** |

### Goal Format in CSV
```
goal_1: "Damage% > 0.034"
goal_2: "K% < 25%"
goal_3: "Chase% < 28%"
```
Percentage metrics use `%` symbol. Non-percentage metrics use raw values.

### Sample Template Output
```csv
groundcontrol_id,ebis_id,player_name,position,level,bats,throws,start_date,end_date,goal_1,goal_2,goal_3
769558,78084,Freuddy Batista,C,AAA Sugar Land,R,R,2026-02-09,2026-03-22,,,
799349,81631,Jax Biggers,SS,AAA Sugar Land,L,R,2026-02-09,2026-03-22,,,
773093,77028,Cody Bolton,P,AAA Sugar Land,R,R,2026-02-09,2026-03-22,,,
```

---

## ❓ Open Questions

### Roster/Player Questions
1. **What `mnrosterstatus_lk` values should be INCLUDED?**
   - ACT = Active ✅
   - Need to include injured (IL, DTD)?
   - What are all possible values?

2. **Position handling for two-way players?**
   - Player has both P and position duties
   - Show both reports?

3. **How to handle players who change levels mid-season?**
   - Show all data regardless of level?
   - Split by level in tables?

### Goal Questions
4. **Who enters goals?**
   - One person uploads CSV?
   - Multiple coaches enter for their players?

5. **What happens when goal period ends?**
   - Archive and start new period?
   - Goals roll over?

6. **How are goals structured in the goal column?**
   - Format: `"MetricName > value"` or `"MetricName < value"`?
   - Or: `"MetricName|increase|0.034"` (pipe-separated)?

### Metric Questions
7. **Which metrics need level-based percentiles in tables?**
   - Bat Speed ✓
   - xwOBACON ✓
   - Others?

8. **What defines "on track" vs "off track"?**
   - Current value vs target?
   - Trending in right direction?
   - Both?

---

## � Metrics Status (Validated vs TODO)

### ✅ VALIDATED (Ready for MVP)

| Metric | Type | Formula/Source | Directionality |
|--------|------|----------------|----------------|
| **Damage** | Hitting | Logistic formula (EV, LA) | ⬆️ H, ⬇️ P |
| **Barrel%** | Hitting | MLB & pBarrel formulas | ⬆️ H, ⬇️ P |
| **Whiff%** | Both | `whiffs / swings` (codes 10,21,22,23) | ⬆️ P, ⬇️ H |
| **ZWhiff%** | Both | Weighted by CSC | ⬆️ P, ⬇️ H |
| **Strike%** | Pitching | Strikes / Total Pitches | ⬆️ P |
| **FPS% (0-1%)** | Pitching | Strikes on first pitch | ⬆️ P |
| **ZSw%** | Both | Weighted `SUM(swing × csc) / SUM(csc)` | ⬆️ H, ⚠️ P* |
| **OSw%** | Both | Weighted `SUM(swing × (1-csc)) / SUM(1-csc)` | ⬇️ H, ⬆️ P |
| **Chase%** | Both | Binary (csc < 0.01) | ⬇️ H, ⬆️ P |
| **ZContact%** | Both | Weighted by CSC | ⬆️ H, ⬇️ P |
| **OContact%** | Both | Weighted by (1-CSC) | ⬆️ H |
| **SwDec** | Both | 3 variants (Grade, Component, ABS) | ⬆️ H, ⬇️ P |
| **iVB (Hop)** | Pitching | `inducedvertbreak` (FF) | ⬆️ P |
| **HB** | Pitching | `horzbreak` by pitch type | Varies |
| **RVGain** | Both | `rv_gain`, `rv_gain_given_hit_specs` | ⬆️ H, ⬇️ P |
| **Pitch Grades** | Pitching | StuffVel→StuffRelVel→All→Component→Grade | ⬆️ P |
| **gcPerformanceGrade** | Pitching | Custom 20-80 formula | ⬆️ P, ⬇️ H |

### 🔄 CONFIRMED — Ready to Wire Up (from DB Discovery Jan 31)

| Metric | Type | Formula | Status |
|--------|------|---------|--------|
| **K%** | Both | `SUM(ev.so) / SUM(ev.pa)` via Events_View + Pitches_View join | READY |
| **BB%** | Both | `SUM(ev.bb) / SUM(ev.pa)` | READY |
| **CSW%** | Pitching | `pitch_result_id IN (6,3,24,30,31,10,16,21,22,23) / total` | READY |
| **FPS%** | Pitching | Strikes where `ab_pitch_number = 1` / total first pitches | READY |
| **Velo (Avg/Max)** | Pitching | `AVG(release_speed) WHERE pitch_type = 'FF'` | READY |
| **Extension** | Pitching | `AVG(extension)` by pitch type | READY |
| **Spin Rate** | Pitching | `AVG(spin_rate)` by pitch type | READY |
| **Stuff Grade** | Pitching | `AVG(stuffrelvel_grade_2080)` — directly in Pitches_View | READY |
| **SwDec** | Both | `AVG(swing_decision_grade_2080)` — in Pitches_View | READY |
| **xwOBA** | Hitting | Derive from Hits_Probabilities probs + Guts.woba_lwts coefficients | READY (complex) |
| **Catcher Pop Time** | Catching | `CatcherDefense_Arm.pop_time_2b` | READY |
| **Framing** | Catching | `CatcherDefense_Framing.adj_net_strikes_per_pitch` | READY |

### ✅ NEWLY IMPLEMENTED (Feb 7, 2026)

| Metric | Type | Formula/Source | Status |
|--------|------|----------------|--------|
| **Bat Speed** | Hitting | `v_true_peak * 0.682` (competitive swings = top 90%) | WORKING |
| **pBarrel** | Pitching | `ev >= 0.011*la² - 0.91*la + 95.0` (parabolic formula) | WORKING |
| **Zswing 0-0** | Both | `balls_before=0 AND strikes_before=0`, zone weighted | WORKING |
| **Oswing 2K** | Both | `strikes_before=2`, out-of-zone weighted | WORKING |
| **Oswing 0-0** | Both | `balls_before=0 AND strikes_before=0`, out-of-zone weighted | WORKING |
| **Frame650** | Catching | `CatcherDefense_Framing.raa650` | WORKING |
| **Pop Time** | Catching | `CatcherDefense_Throwing.pop_time` | WORKING |
| **Exchange Time** | Catching | `CatcherDefense_Throwing.exch_time` | WORKING |
| **Block Value** | Catching | `CatcherDefense_Blocking.surpluss_pppp` | WORKING |

### 🔄 TODO (Need Follow-Up Queries)

| Metric | Type | Notes |
|--------|------|-------|
| **xwOBACON** | Hitting | xwOBA on contact only — same formula, filter to BIP |
| **Spray/Pull%** | Hitting | `hit_bearing` analysis |
| **Tilt/Clock** | Pitching | Break vector → clock face |

### ⚠️ PARTIAL SUPPORT (Have Data, Need Integration)

| Metric | Type | Notes |
|--------|------|-------|
| Fielding (INF) | Defense | Tables: `INF_Ability_Metrics` — React, ReactRad, ArmINF, ExchINF |
| Fielding (OF) | Defense | Tables: `OF_Ability_Metrics` — UseReact, ArmOF, ExchOF (percentiles in percentiles.py) |

### ❌ NOT PLANNED FOR MVP

| Metric | Type | Notes |
|--------|------|-------|
| Baserunning | Hitting | Tables found in GroundControlTracking (`Baserun_Tracking_*`) |
| Force Plate | SportsMed | `Sportsmed.ForceDeck_Metrics` — available but not planned |

---

## 🚀 Implementation Phases

### Phase 1: Foundation ✅ COMPLETE
- [x] Database connection module (database.py)
- [x] Explore tables and columns
- [x] Document metric formulas (DATABASE_REFERENCE.md)
- [x] Roster query implementation (roster.py + live_rosters_cristian.sql)
- [x] Validate core metrics (Damage, SwDec, RV, Pitch Grades, weighted rates)

### Phase 2: Dashboard ✅ COMPLETE (live data on Posit Connect)
- [x] Streamlit app with full sidebar (level, player, date range, chart toggle, goal periods)
- [x] Goal parser (goal_parser.py)
- [x] CSV upload with append-and-save logic
- [x] Goal display with color-coded status, trend arrows, percentage formatting
- [x] Bar charts filtered by toggled periods, colored by goal status (green/yellow/red)
- [x] Save Report button (PDF download reflecting toggled periods)
- [x] Real roster query wired up (live on Posit Connect)

### Phase 3: PDF Reports ✅ COMPLETE (live data)
- [x] Percentile-colored rounded bar charts (blue=low→gray→red=high, Savant convention)
- [x] Astros branding (navy header, cap logo)
- [x] Dynamic period support (automated = 3 bars, dashboard = toggled bars)
- [x] Real league-wide percentile calculations (8 groups, mostly Astros tables after Feb 4 migration)
- [x] stats.py audited against GC production SQL (foul tip codes, bit casts, filters)

### Phase 4: Report Delivery ✅ TESTED & WORKING
- [x] PDF generation to OneDrive local folder
- [x] OneDrive cloud sync
- [x] Power Automate flow (OneDrive → email → Slack)
- [x] Slack channel email routing via CSV
- [ ] **Schedule Power Automate trigger (daily 6 AM)** ← manual for now
- [ ] **Collect all zzz_ channel emails** ← manual one-time task

### Phase 5: Live Data Integration ✅ COMPLETE (Feb 2, 2026)
- [x] DB Discovery — confirmed table structures, column names, join patterns (Jan 31)
- [x] goals_template.csv with real 275-player roster and IDs
- [x] Run 9 follow-up queries on work laptop — ALL CONFIRMED
- [x] Wire stats.py to real metric queries using corrected column names
- [x] Audit stats.py against GC production SQL — fixed foul tip codes, bit casts, filters
- [x] Wire goal_parser.py with all new metric aliases
- [x] MLBAM exploration queries run — confirmed Pitch_fx, Schedule, Hits, SplitsBat join paths
- [x] Percentile engine built (`src/percentiles.py`) — SplitsBat (K%, BB%, wOBA, SLG), Pitch_fx (Chase%, Oswing, Zswing, Zcon, Zcon vs OS/BB/FB, Whiff%, usage counts, FF/SL/CH movement), Hits (Damage, Barrel%, EV, Top50th EV, Hard%)
- [x] Wire roster.py to real player dropdowns
- [ ] Add game type filtering (sched_type) to production queries

### Phase 6: Production Deployment ✅ LIVE (Feb 3, 2026)
- [x] Deploy dashboard to Posit Connect (FreeTDS + domain auth)
- [x] DB connection working (credit: Ryan Ferguson / gcpy)
- [ ] Windows Task Scheduler for daily report generation
- [ ] Power Automate scheduled trigger
- [ ] Postgame reports (same pipeline, different trigger)

### Phase 7: Visual Overhaul (Sam's Feedback) ✅ COMPLETE (Feb 4, 2026)
- [x] **Period Toggle controls everything** — renamed Chart Toggle → Period Toggle, moved above Date Range, swapped Selected Dates before Recent Week. Goal squares, bar charts, and percentile bars all respond to toggles. Selected Dates added as 4th period in dashboard + PDF.
- [x] **Goal compliance emojis** — ✅/❌ (dashboard) and colored ✓/✗ (PDF) on every metric value across all active period columns. Inches suffix (`"`) on movement metrics (Hop, IVB, HB, Extension, Rel Height, Rel Side).
- [x] **Percentile bar separation** — bar charts now use goal-status colors (green/yellow/red) instead of percentile gradient. Percentile info moved to battery bar indicators below each goal's bar chart. Gradient changed to red→gray→green. Proper ordinal suffixes (1st, 2nd, 3rd).
- [x] **PDF layout polish** — columnized battery bars, 2-column key with Spanish translations, tighter spacing between goal rows and bar charts, proper pitch count for pitchers (was showing PA count).
- [x] **Dashboard layout polish** — columnized battery bars in Percentile Rankings section, key updated with percentile bar explanation.

### Phase 8: Percentile Expansion (Feb 7, 2026) ✅ COMPLETE
- [x] **Smart sample size display** — reports show metric-specific counts (e.g., "330 FF" for FF Hop, "45 BIP" for Damage, "892 SW" for Whiff%)
- [x] **Bat Speed percentiles** — Astros.Bat_Tracking_Metrics, competitive swings filter (top 90%), converted to MPH
- [x] **pBarrel for pitchers** — parabolic barrel formula (`ev >= 0.011*la² - 0.91*la + 95.0`)
- [x] **Zswing 0-0 percentiles** — first-pitch zone swing rate, weighted by CSC
- [x] **Count-specific Oswing** — Oswing on 2K counts and 0-0 counts
- [x] **Catcher defense percentiles** — Frame650, Pop Time, Exchange Time, Block Value
- [x] **percentiles.py now has 8 metric groups** — SplitsBat, Pitch_fx, Hits, OF_Fielding, Bat_Speed, Zswing_0_0, Catcher, Count_Swing

### Phase 9: Sample Size Polish (Feb 8, 2026) ✅ COMPLETE
- [x] **EVEN → P:** Even count usage metrics now show "P" unit instead of "EVEN"
- [x] **Zcon vs. metrics:** Zcon vs. OS/BB/FB95+ now show zone swings on pitch type (e.g., "14/22 ZSW OS")

### Phase 10: Next Steps
- [ ] **Metric audit** — verify all metric and percentile calculations match GC production formulas
- [ ] **Collect all zzz_ Slack channel emails** — manual one-time task in Slack for delivery routing
- [ ] Add game type filtering (sched_type) to production queries
- [ ] Verify headshot loads on Posit Connect (requires Astros.Players mlbam_id lookup + MiLB CDN)
- [ ] Windows Task Scheduler for daily report generation
- [ ] Power Automate scheduled trigger (daily 6 AM)
- [ ] Add FPS%, CSW%, Zone% percentiles (easy — already have queries)

---

## ❓ Open Questions

### Answered
- **Who enters goals?** → Assistant director creates CSV, uploads via dashboard
- **Goal format?** → `"MetricName > value"` or `"MetricName < value"` (human-readable)
- **Percentage convention?** → Write as percentages (`K% > 28%`), code auto-converts decimals < 1
- **What happens when goal period ends?** → New CSV uploaded for new period, old data preserved
- **How are reports delivered?** → OneDrive → Power Automate → Email → Slack channel
- **DB connection on Posit Connect?** → FreeTDS driver + domain auth (BASEBALL\zbridger), no password needed. Credit: Ryan Ferguson.

### Still Open
1. **Which `mnrosterstatus_lk` values include injured players?** → Confirm with assistant director
2. **Position handling for two-way players?** → Show both hitting and pitching reports?
3. **Players who change levels mid-period?** → Show all data or split by level?
4. **Which metrics need level-based percentiles?** → Bat Speed, xwOBACON confirmed; others TBD
5. **"On track" definition** → Current value vs target? Trending direction? Both?

---

*Document updated: February 8, 2026*
