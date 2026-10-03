# Reference

This is the index. Use it as a lookup table when you know the topic
but don't remember which file holds the canonical answer.

## `.claude/rules/` index

The rules directory is the authoritative knowledge base for the
codebase. Every rule has YAML frontmatter declaring which file paths
it auto-applies to when Claude is editing.

### Universal rules (apply to any `.py` or `.sql`)

| File | Topic |
|---|---|
| `db-columns.md` | Column names, Astros vs MLBAM, ID mapping, arm angle formula |
| `db-joins.md` | Pitches_View join keys, `cur_event_id` vs `ab_event_id` dual-join |
| `db-connection.md` | FreeTDS (Posit Connect), ODBC 17 (work laptop), dual-mode |
| `pitch-codes.md` | `Astros.LK_Pitch_Results` full table, code group constants |
| `level-codes.md` | SPORT codes, DSL/FCL split, junk levels (BBC = College, corrected Apr 2026) |
| `draft-tables.md` | `R4_Draft_Query` + `PP_MASTER` UDFA query patterns, org-tenure-gating |
| `draft-projects.md` | BLOCKING for any draft / amateur / UDFA project. Pool definition, R4-to-MLBAM mapping (chi/la/ny + Athletics rebrand) |
| `advance-levels.md` | Advance reports allow `bbc/ind/int/sum/win/min` --- recency wins over level purity |
| `advance-non-ebiz-pitchers.md` | Procedure for opposing pitchers without a clean PP_MASTER row (multi-gc-id stitching) |
| `pitfalls.md` | BIT columns, NaN in IN clauses, session_state, cache bugs |
| `query-performance.md` | 5-step diagnostic for slow queries (multi-column-OR, scan count, date pushdown) |
| `tracking-schema.md` | `groundcontroltracking.tracking.*` schema (64 tables) + HawkEye coverage |
| `event-vs-pitch-anchored.md` | Event-anchored vs pitch-anchored aggregation |
| `sched-types.md` | `R/S/E/V/I` meanings, BBC/WIN pseudo types |
| `sz-planning-prompts.md` | Strike zone framework planning prompts |

### Domain rules (apply to `src/` and `scripts/`)

| File | Topic |
|---|---|
| `gc2-metrics.md` | gcOBA, pBarrel, Whiff%, gcPerf, R2K%, Loc Grade |
| `woba-rules.md` | wOBA weights, xwOBA formula, wRC+, zxwOBA |
| `coordinates.md` | `plate_x` conventions per project, matplotlib figure coords |
| `fielding.md` | 3-tier standard, arm floors, OAA, PERCENTILE_CONT |
| `multi-level-rollup.md` | Per-metric `n_obs` weighting iron rule |
| `three-surface-parity.md` | BLOCKING --- catcher/OF/IF/BR metrics live in 3 surfaces, ALL must match |
| `kpi-weekly-charts.md` | BLOCKING --- pool-then-aggregate pattern across all 6 KPI weekly reports |
| `kpi-roster-filter.md` | BLOCKING --- KPI weekly Season table active-roster filter |
| `kpi-parallelization.md` | P2/P3/P4 query parallelization for KPI fetches |
| `combined-kpi-stapler.md` | BLOCKING --- KPI stapler architecture |
| `bat-speed-canonical.md` | BLOCKING --- canonical bat speed cleaning helper |
| `data-cleaning.md` | Codebase-wide cleaning patterns |
| `damage-pct-cross-app-divergences.md` | Damage% post-percentage rounding pattern |
| `never-round-until-display.md` | BLOCKING --- never round until display layer |
| `visual-standards.md` | Strike zones, spray charts, HP orientation, pitch colors |
| `pdf-patterns.md` | Plottable null fix, percentile coloring, video links, images |
| `delivery.md` | Logic App pipeline, channel routing |
| `dual-query-path.md` | Sync rule for app vs CLI queries |
| `slack-channels-sync.md` | 5-copy CSV sync rule |
| `in-app-submission.md` | Streamlit form → pin → reportlab PDF → Logic App pattern |
| `tracker-parquet-pins.md` | Pin pattern + Connect-scheduled refresh playbook (~1100 lines) |
| `streamlit-tracker-column-pinning.md` | Streamlit tracker column pinning |
| `ip-calculation.md` | Pitching IP from `Gamelog_Pitching` (gold standard) |
| `reference-impl-index.md` | Per-metric file-pointer index |

### App-specific rules (auto-load only in that app's directory)

| File | App |
|---|---|
| `barrelsville.md` | Barrelsville (hitting) |
| `arm-farm.md` | Arm Farm (pitching) |
| `intangibles.md` | Intangibles (BR/OF/IF/Catcher) |
| `pd-goals.md` | PD Engine (Goals + Org Board + Transition) |
| `pd-goals-unmeasurable.md` | PD Goals --- subjective + unmeasurable goals reference |
| `org-board.md` | Org Board page architecture |

### Operational

| File | Topic |
|---|---|
| `.graduation-log.md` | Append-only audit trail for `memory-cleanup` skill runs |

## Glossary of acronyms

| Acronym | Meaning |
|---|---|
| **ABS** | Automated Ball-Strike (the strike zone definition introduced for the robot ump system) |
| **AAA / AAX / AFA / AFX** | Triple-A / Double-A / High-A / Single-A (MLBAM SPORT codes) |
| **AB** | At-Bat |
| **AccelCD / AccelCU** | Acceleration (Chest Down / Chest Up) |
| **AS** | Astros (HOU MLB team) |
| **BB** | Walk (Base on Balls) |
| **BBE** | Batted-Ball Event |
| **BIP** | Ball in Play |
| **BR** | Baserunning |
| **CF** | Center Field (also Center-Field camera angle) |
| **CP** | Competitive Play (`competitive_play` BIT column) |
| **CS** | Caught Stealing |
| **CSC** | Called Strike Chance |
| **CSW** | Called Strike + Whiff |
| **CT** | Competitive Throw (`competitive_throw` BIT column) |
| **DCBP** | Defense_Combined_By_Pos table |
| **DSL** | Dominican Summer League |
| **EBIS** | The roster master system; data lives in `MLB_eBis.PP_MASTER` |
| **EO** | Expected Outs |
| **ESB** | Events_StolenBases table |
| **EV** | Exit Velocity |
| **EW%** | Early Win % (pitcher metric) |
| **FCL** | Florida Complex League (Rookie ball, Astros affiliate) |
| **FIP** | Fielding Independent Pitching |
| **FPS%** | First-Pitch Strike % |
| **GC2** | GroundControl2 (the database AND the production analytics system) |
| **GC ID** | `groundcontrol_id` --- the canonical Astros player ID |
| **HiB** | Higher is Better |
| **IL** | Injured List (also `IL-60` for 60-day) |
| **IP** | Innings Pitched |
| **IR** | Internal Rotation (S&C metric) |
| **K%** | Strikeout rate |
| **KPI** | Key Performance Indicator (the weekly metric reports) |
| **L2W** | Last 2 Weeks (the rolling window in KPI weekly reports) |
| **LA** | Launch Angle |
| **LCS** | League Championship Series (sched_type `'L'`) |
| **LHH / RHH** | Left-Handed Hitter / Right-Handed Hitter |
| **LHP / RHP** | Left-Handed Pitcher / Right-Handed Pitcher |
| **LiB** | Lower is Better |
| **LVA** | Live Velocity Analysis (Arm Farm postgame chart) |
| **MiLB** | Minor League Baseball (everything below MLB) |
| **MLBAM** | MLB Advanced Media (their data system; Statcast layer) |
| **OAA** | Outs Above Average (Statcast definition; was DRS) |
| **OBP** | On-Base Percentage |
| **OF** | Outfield |
| **PA** | Plate Appearance |
| **PAA** | Plays Above Average |
| **PBL** | Pitches_Baserunner_Leads table |
| **PD** | Player Development |
| **PR** | Personal Record |
| **R2K%** | Race to 2K (pitcher metric --- on pitch 3, did the pitcher have 2+ strikes?) |
| **RAA** | Runs Above Average |
| **RAR** | Runs Above Replacement |
| **RV** | Run Value |
| **SB** | Stolen Base |
| **SBA** | Stolen Base Attempt |
| **SCV** | swing_contact_values (tracking table) |
| **SF** | Sacrifice Fly |
| **SH** | Sacrifice Hit (bunt) |
| **SO** | Strikeout |
| **SS** | Shortstop (also SQL Server) |
| **SZ** | Strike Zone |
| **TBF** | Total Batters Faced |
| **TDM** | Tracking_Defensive_Metrics table |
| **WPA** | Win Probability Added |
| **wOBA** | Weighted On-Base Average |
| **wRC+** | Weighted Runs Created Plus |
| **xBA / xSLG / xwOBA** | Expected Batting Average / Slugging / wOBA from hit specs |
| **xPP** | Expected Passed Pitches |
| **YTD** | Year to Date |
| **zxwOBA** | Per-pitch expected wOBA delta (in wOBA-scale units) |

## People to ping

| Person | Role | When to ping |
|---|---|---|
| **Zac Bridger** | PD analyst | Anything code, anything pattern --- he wrote most of the canon |
| **Chris Josefy** (`cjosefy@astros.com`) | Supervisor of Data | DB access, IT issues, VPN |
| **Adam Brodie** | R&D | DB schema, metric formulas (he wrote much of GC2) |
| **Sam Niedorf** | Farm Director | Org-level rollup requests, age-vs-league questions |
| **Cristian** | Pitching directional input on goals | FPinZ%, FB velo targets, IF arm goals --- ask Zac for current title |
| **Perez** | Pitching directional input (FF usage vs RHH in pre-2K) | May or may not be the same person as Cristian --- ask Zac |
| **Kyle Brennan** | Set advance scouting page-1 layout (May 2026) | Advance report layout questions --- ask Zac for current title |
| **Mazzo** | Drove OF positioning project requirements (May 2026) | OF positioning + spray chart questions --- ask Zac for current title |
| **Nick Arrivo** | Wrote UDFA detection pattern for PP_MASTER queries | UDFA roster patterns --- ask Zac for current title |

## Key URLs

| What | URL |
|---|---|
| Posit Connect | `https://connect2.astros.com` |
| Logic App webhook | (in `LOGIC_APP_URL` env var; see Ch 13) |
| GitHub repo (private) | `git@github.com:<org>/bsb-resources.git` |

## Hardware paths

### Personal laptop (Windows)

| Path | Purpose |
|---|---|
| `C:\Users\<user>\bsb-resources` | PD Engine main worktree (`feature/pd-goals`) |
| `C:\Users\<user>\bsb-wt-hitting` | Barrelsville (`feature/barrelsville`) |
| `C:\Users\<user>\bsb-wt-bullpen` | Arm Farm (`feature/bullpen-reports`) |
| `C:\Users\<user>\bsb-wt-intangibles\astros-intangibles` | Intangibles (`feature/astros-intangibles`) |
| `C:\Users\<user>\AppData\Local\Pandoc\pandoc.exe` | Pandoc (handbook build) |
| `C:\Users\<user>\AppData\Roaming\TinyTeX\bin\windows\xelatex.exe` | xelatex (handbook build) |

### Work laptop (Windows)

| Path | Purpose |
|---|---|
| `C:\Users\zbridger\bsb-resources` | (and the three sibling worktrees, same structure as personal) |
| `C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe` | rsconnect for Connect deploys |

## Building this handbook

```bash
cd docs/handbook
make pdf
```

Outputs `pd-apprentice-handbook.pdf`. See `docs/handbook/README.md`
for the full build instructions, including the LaTeX template and
the chapter conventions.

## Reading order recap (from Chapter 1)

1. Chapter 1 (Orientation) --- 30 min
2. Chapter 2 (Stack & Workflow) --- 1 hr
3. Chapter 3 (Database Tour) --- 2 hr
4. Chapter 4 (GC2 & Deviations) --- 1 hr
5. Skim Chapter 5 (Metrics) --- 30 min
6. Chapter 6 (Data Cleaning) --- 1 hr
7. Pick ONE app chapter (7-10) --- 1 hr
8. Skim Chapters 11-15 --- 30 min

About 7 hours of focused reading. The rest of the handbook is
reference.

---

**Welcome to the team. Build something great.**
