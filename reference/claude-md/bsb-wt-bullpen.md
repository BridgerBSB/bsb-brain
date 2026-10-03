# BSB Resources

Houston Astros Player Development analytics codebase.

## Projects

| Project | Branch | Status | Directory | App GUID |
|---------|--------|--------|-----------|----------|
| **PD Engine (Goals)** | `feature/pd-goals` | LIVE | `pd-goals/` | `79f52369-...` |
| **Arm Farm** | `feature/bullpen-reports` | LIVE | `bullpen-report/` | `13482bcb-...` |
| **Intangibles** | `feature/astros-intangibles` | IN PROGRESS | `intangibles/` | `295a5205-...` |
| **Barrelsville** | `feature/barrelsville` | DEPLOYED | `barrelsville/` | `bbb53548-...` |

> Each app has a detailed rules file in `.claude/rules/<app-name>.md` with key files, architecture, and features.

## Core Rules — READ FIRST

1. **Always read existing sibling/reference implementations before writing new code.** Never guess column names, SQL syntax, or function signatures — grep the codebase first. If a pattern exists in postgame, hitter_analysis, or OF reports, match it exactly.
2. **When working across worktrees**, always confirm WHICH worktree the user wants before making changes. Never assume. Each worktree has its own patterns — check that worktree's existing code, not another's.
3. **Never speculate about data or root causes.** If unsure, run the query or read the file. Do not claim work is complete without verifying the output. If you don't know a column name, grep for it — do not guess.

## SQL & Database

This project uses **SQL Server (T-SQL) syntax, NOT PostgreSQL**. Key differences:
- `ISNULL()` not `COALESCE()` (for 2-arg null replacement)
- `TOP N` not `LIMIT`
- No `FILTER` clause — use `CASE WHEN` inside aggregates
- `CAST(bit_col AS int)` before `SUM()` — BIT columns cannot be SUM'd directly
- Always verify column names against the actual schema or by grepping existing queries before writing new ones

## Metric Standards

- **Filtering architecture:** Tier 1 gates (observation minimums), display-tier filters, and arm strength floors must be applied consistently. When adding new reports, audit existing gate logic in the reference implementation before coding.
- **Lead averages/percentiles:** PL (primary) includes all leads — no `runner_going` filter. SL (secondary) and TL (total) filter `runner_going = 0` (steal inflates secondary). 1B leads gate on `closest_fielder_distance <= 10` (fielder holding). All leads exclude next-base-occupied pitches (LEFT JOIN IS NULL in aggregates). Daily per-game pitch rows show all values unfiltered but skip SL/TL percentile coloring on steal pitches. See `db-columns.md` for full filter table.
- **SB/CS counts:** Use `Events_View.event_result_id` (official scoring), NEVER `Events_StolenBases` for totals. ESB is for play-by-play detail/video only. See `db-columns.md` SB/SBA Count Rule.
- **Percentile pools:** Volume gates control who enters the distribution, not who displays. Players always show; gate only controls coloring.

## PDF Reports

- **Always generate individual per-player PDFs** (not bulk). Match header layout, table rendering style, and glossary formatting from the closest existing report (e.g., postgame report style).
- **Never use `fontdict` and `fontsize` together** in matplotlib — pick one.
- **Plottable tables:** Always call `_fix_null_bbox()` after creating a table with percentile coloring.

## Branch Strategy & Workflow

One branch per project. Only touch your project's subfolder. Shared files (CLAUDE.md, sql-queries/) OK on any branch. Merge to main ONLY at milestones.

**Personal laptop** (`C:\Users\Owner\`): Windows, Claude Code, no DB access, GitHub SSH key
**Work laptop** (`C:\Users\zbridger\`): Windows, DB access (ODBC Driver 17), Python 3.13

```
1. Claude Code on personal laptop (only machine where it's installed)
2. Code → commit → push to feature branch
3. Work laptop: git pull → test with live DB → verify
4. Fix on personal → push → pull on work
```

### Worktrees

| Path | Branch | Project |
|------|--------|---------|
| `C:\Users\Owner\bsb-resources` | `feature/pd-goals` | PD Engine (main repo) |
| `C:\Users\Owner\bsb-wt-bullpen` | `feature/bullpen-reports` | Arm Farm |
| `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles` | `feature/astros-intangibles` | Intangibles |
| `C:\Users\Owner\bsb-wt-hitting` | `feature/barrelsville` | Barrelsville |

## IT Constraints — Do Not Suggest Workarounds
- Claude Code BLOCKED on work laptop
- SMTP AUTH disabled, Slack Incoming Webhooks denied, Slack Bot/App install denied

## Blocking Rules — ALWAYS APPLY

The 15 non-negotiable rules live in **`.claude/rules/blocking-rules.md`**
— it auto-loads universally alongside this file. Highlights: don't guess
DB columns, BIT casting before SUM, gc2_level_code for DSL/FCL, dual
query path sync, App↔Report parity, Tier 1 fielding gate, org-code
canon, and PDF-last in Streamlit pages. Open that file for the full
list + linked deep-dives.

## Reference Guide — `.claude/rules/`

Rules auto-load by file path. When editing Python in `barrelsville/`, you get `rules/barrelsville.md` + `rules/db-columns.md` + `rules/gc2-metrics.md` automatically.

### Universal (load for any .py/.sql)
- `rules/db-columns.md` — Column names, Astros vs MLBAM, ID mapping, arm angle formula. **Includes xwoba denom = AB+BB+HBP+SF — IBB IS counted (different from wOBA), May 19 2026.**
- `rules/db-joins.md` — Pitches_View join keys, cur_event_id vs ab_event_id
- `rules/db-connection.md` — FreeTDS (Posit Connect), ODBC 17 (work laptop), dual-mode pattern
- `rules/event-vs-pitch-anchored.md` — Decision guide: drive FROM Events_View vs Pitches_View. Prevents the PA-inflation trap on per-batter aggregation.
- `rules/org-codes.md` — **BLOCKING.** Cross-source MLB-org code canonicalization (PP_MASTER / GBL_CLUB_LKUP / MLBAM.Teams / R4_Draft_Query). 4 known mismatches: CHI↔CHC (Cubs), LA↔LAD (Dodgers), NY↔NYM (Mets), OAK↔ATH (Athletics). MUST apply CASE remap on every cross-source JOIN or those orgs silently drop.
- `rules/pitch-codes.md` — LK_Pitch_Results full table, code group constants
- `rules/level-codes.md` — SPORT codes, DSL/FCL split, junk levels. **BBC = College (4-yr amateur), corrected Apr 28 2026 — NOT Big League Camp.**
- `rules/sched-types.md` — R/S/E/V/I meanings, BBC/WIN pseudo types
- `rules/draft-tables.md` — R4_Draft_Query + PP_MASTER UDFA query patterns, org-tenure-gating mechanic, hitter/pitcher position lists, lowercase-vs-uppercase org abbreviation gotchas. Reference for any draft/amateur/UDFA analysis.
- `rules/draft-projects.md` — **BLOCKING for any draft/amateur project.** Project catalog, pool definition (drafted + UDFA, no international filter by default), amateur level code conventions, org-tenure mechanics, R4-to-MLBAM mapping (chi/la/ny + Athletics rebrand), aggregation patterns (BLOCKING: always ask user per-player vs pool before building org rollups), display conventions, future-skill candidacy.
- `rules/advance-levels.md` — ADVANCE REPORT EXCEPTION: advance reports (hitter/pitcher/fielder) allow bbc/ind/int/sum/win/min — they window on recency, not level purity. Overrides global "always exclude" for those modules only.
- `rules/advance-non-ebiz-pitchers.md` — Procedure for opposing pitchers without a clean PP_MASTER row (indy callups, multi-GC-id players). Diagnostic SQL + `generate_advance_oneoff.py` companion for one-off reports.
- `rules/pitfalls.md` — BIT columns, NaN in IN clauses, session_state, cache bugs
- `rules/query-performance.md` — 5-step diagnostic for slow queries: scan-count → multi-column-OR → UNION ALL collapse → CTE inline → date pushdown. Apply BEFORE caching/pinning. Reference for SB / lead / runner-attribution queries (the slowest pattern in this codebase).
- `rules/tracking-schema.md` — `groundcontroltracking.Tracking.*` schema (64 tables). Per-fielder catch position, full team trajectory, INF/OF tracking metrics, event-type lookup. Apr 30 2026 IF catch-position discovery. **HawkEye coverage caveat**: ~50% sparsity at non-HawkEye MiLB venues — plan for it.
- `rules/never-round-until-display.md` — **BLOCKING.** Never round, truncate, or quantize mid-pipeline. Round ONCE at display layer in display units. Damage% / SB% drift bug class.
- `rules/slack-channels-sync.md` — **BLOCKING.** `slack_channels.csv` lives in 5 places across 4 worktrees — sync ALL when editing. zzz_ ≠ z_ (coach vs athlete), channel-name suffix ≠ gc_id (frozen Slack label).
- `rules/reference-impl-index.md` — Canonical impl map per metric (wOBA / xwOBA / gcOBA / fielding tier1 / catcher Arm P99 / BR leads / etc.) → file:line in `barrelsville/`/`bullpen-report/`/`intangibles/`/`pd-goals/`. Read BEFORE drafting SQL for any metric.
- `rules/data-cleaning.md` — **BLOCKING.** Arm angle 2-step pitcher cleanup (90° cap + per-pitcher 2.5σ); 1B PL 5.0ft floor + 20.0ft ceiling, 2B PL 25.0ft ceiling; bat speed 3-step.

### Domain — Hitting Metric Canonicals (load for src/ and scripts/)
- `rules/gc2-metrics.md` — gcOBA, pBarrel, Whiff%, gcPerf, R2K%, Loc Grade. **gcOBA BLOCKING rules updated May 19 2026 for xwoba IBB-as-walk.**
- `rules/woba-rules.md` — wOBA weights (Guts.woba_lwts) + JOIN keys + per-level resolution + fallback year. **xwoba denom = AB+BB+HBP+SF per GC2 (May 19 2026 fix). See `xwoba-canonical.md` for canonical helper.**
- `rules/xwoba-canonical.md` — **BLOCKING NEW (May 19 2026).** xwOBA IBB-as-walk (opposite of wOBA), `WOBA_WEIGHTS_JOIN` constant, f-string vs .format() per-file gotcha (the painful lesson). Every xwOBA value MUST match GC2. Sacco AA .330→.335 verification case.
- `rules/bat-speed-canonical.md` — **BLOCKING.** Bat speed at contact: SCV-sourced (`scv.batvx/y/z_con`), 3-step per-player cleaning (top-90% / 57mph floor / 2.5σ), `clean_bat_speed_per_player` helper. 8 surfaces enumerated.
- `rules/damage-pct-cross-app-divergences.md` — Damage% post-percentage-round canonical (matches Barrelsville everywhere). Known LA-not-null-filter divergences in postgame_data.py + 4 Arm Farm tracker queries — deferred, not fixed.
- `rules/coordinates.md` — plate_x conventions per project (catcher's view vs pitcher's view), matplotlib figure coords. Negate `plate_x`/`horzbreak`/`release_x` to flip.

### Domain — Multi-Level / Pool Architecture
- `rules/multi-level-rollup.md` — **BLOCKING.** Two-tier architecture for percentile metrics (May 16 2026): Individual tier ALWAYS pools raw obs; Org tier ALWAYS weighted-mean of individuals by per-metric n_obs. Plus Iron Rule (weight column = inner-tier count). Fielding canonical = `_ORG_POOLED_TRACKING_AGG_QUERY`. Catcher fix DEFERRED.
- `rules/three-surface-parity.md` — **BLOCKING.** Catcher/OF/IF/BR metrics live in 3 surfaces (tracker, KPI weekly, PD-Goals org). Any change to one MUST propagate to the other two before commit ships.
- `rules/merge-union-not-primary.md` — **BLOCKING.** When merging multi-source DataFrames into one display, build row universe from UNION of every non-empty source; never `df = primary.copy()` + left-join. Prevents silent row-drop on sparse primary sources.
- `rules/fielding.md` — 3-tier standard, arm floors, OAA, PERCENTILE_CONT
- `rules/ip-calculation.md` — IP via `MLBAM.Gamelog_Pitching.outs` (gold) or `Events_View.outs_after - outs_before` (good); never `AB - H + SF`. Baseball notation `4.1`/`4.2`. H/A proportional split. AOL = appearance length sibling metric.

### Domain — KPI Weekly + Cross-Worktree
- `rules/kpi-weekly-charts.md` — BLOCKING: chart-line implementation across all 6 KPI weekly reports. Three metric types (cumulative SUM / rate / per-player percentile), three correct treatments. Pool-then-aggregate, NEVER aggregate-then-roll for percentiles (Apr 27 OF/IF Arm IF bias incident). T-SQL CTE alias-in-WHERE gotcha. Chart line vs rank box vs card intentionally differ. Reference impls for all 6 surfaces.
- `rules/kpi-roster-filter.md` — BLOCKING: KPI weekly Season table displays only currently-rostered HOU players per PP_MASTER (Apr 27 2026 boss request). Stats / pool / chart line / rank box / cards stay UNFILTERED. `get_active_roster_ids(level_code, season)` helper in each app's `database.py`.
- `rules/combined-kpi-stapler.md` — BLOCKING: cross-worktree PDF stapler delivers ONE combined KPI PDF per level to affiliate channels (Apr 28 2026 boss request). The 6 individual KPI scripts only deliver to per-domain channels; affiliate-channel delivery is owned exclusively by `pd-goals/scripts/generate_combined_kpi.py`. NEVER re-add `AFFILIATE_CHANNEL_IDS` to any of the 6 scripts.
- `rules/kpi-parallelization.md` — P2/P3/P4 query parallelization tiers in KPI reports (`ThreadPoolExecutor` patterns, season+span concurrent, sub-query fanout).

### Domain — Visualization + PDFs
- `rules/visual-standards.md` — Strike zones (Two Frameworks — ABS 17" display + Tango Heart/Shadow/Chase classification), spray charts, HP orientation, pitch colors, axis ranges, diverging colormap white-midpoint rule, click-to-video patterns (Scatter3d is dead in Streamlit — workarounds documented).
- `rules/sz-planning-prompts.md` — Strike zone planning prompts. 5 questions to confirm BEFORE building/modifying any SZ visual or classification path.
- `rules/pdf-patterns.md` — Plottable null fix, percentile coloring with bbox, video links via `set_url()` on Text artists (NOT scatter/Line2D — silently dropped), multi-page PDF patterns, section pagination, cumulative single-PDF over multi-select.
- `rules/pdf-last-in-script.md` — **BLOCKING.** Streamlit PDF gen block MUST sit below all main-flow `st.plotly_chart`/`st.dataframe` calls. Reference impl: `barrelsville/pages/5_KPI_Report.py:437` ("charts first, PDF last").
- `rules/video-angles.md` — Two video tables (Astros.Video sporty-clips + Astros.Video_Network internal). 3-tier V-column fallback chain (`Astros.Video.angle_id=1` → `Video_Network 'v'` → `Video_Network 'a'`).

### Domain — Infrastructure + Tracker Pins
- `rules/tracker-parquet-pins.md` — **LARGE BLOCKING reference.** Affiliate tracker pin pattern (joblib bundle per app per year), 5 trackers LIVE, Connect-scheduled daily refresh (Apr 29 §12). Sparse-pin recovery via `repair_tracker_pin.py`. Spring / handedness / date-range future expansions §12.9 + §12.12.
- `rules/tracker-new-metric-checklist.md` — **BLOCKING 5-place checklist** when adding a new metric to any affiliate tracker. Skip any one and the metric goes NULL silently in specific views.
- `rules/database-tcp-retry.md` — **BLOCKING.** `run_query` auto-retries TCP drops (SQLSTATE 08S01/08001) + `pool_pre_ping=True` on `create_engine`. Mitigates VPN flakiness on multi-hour pin jobs.
- `rules/streamlit-tracker-column-pinning.md` — **BLOCKING.** Pixel-int widths on pinned info columns (Streamlit ≥1.49.0). 60% pinned-width threshold or pinning silently disables.

### Domain — Delivery + Submissions
- `rules/delivery.md` — Logic App pipeline, channel routing (CLI + in-app). BLOCKING payload field names: `channel`, `filename`, `pdf`. Per-affiliate channel map. `--no-heatmaps` + `--split` for analysis PDFs.
- `rules/dual-query-path.md` — Sync rule for app vs CLI queries
- `rules/in-app-submission.md` — Streamlit form → parquet pin → reportlab PDF → Logic App → Slack, all in-process on Posit. Reusable blueprint for any internal form app. Transition Report is the reference impl.

### App-Specific (load only in that app's directory)
- `rules/barrelsville.md` — Hitting: zones, video, advance scouting, 6 KPI categories
- `rules/arm-farm.md` — Pitching: LVA markers, enrich_pitches, click-to-video
- `rules/intangibles.md` — BR/OF/IF/Catcher: fielding_base.py, channel routing
- `rules/pd-goals.md` — Goal tracking: percentile engine, goal parser. PD Engine landing + 4 cards (PD Goals / Transition / WPA Plays / Defense Matrix).
- `rules/pd-goals-unmeasurable.md` — Subjective/unmeasurable goal categorization. Force plate, twitch, eccentric, etc. → `direction=DESCRIPTIVE`, no progress bar.
- `rules/org-board.md` — **BLOCKING** for PD Engine Card "Org Board". HOU-org kanban + Team View. EBIS/PP_MASTER canonical, TR_HISTORY decorates. IL dedupe invariant, drawer dual-lookup, CommonMark `_compact_html` trap, GBL_CLUB_LKUP global fallback for cross-org levels.

## DB Quick Reference

- **Server:** GCSQL02.ASTROS.COM → GroundControl2
- **Full schema docs:** `sql-queries/DATABASE_REFERENCE.md`
- **Player IDs:** `pd-goals/data/slack_channels.csv`
- **Posit Connect:** FreeTDS driver, domain auth (BASEBALL\zbridger)

## Tech Stack
- Python 3.11+, Streamlit, matplotlib, reportlab, pandas, Plotly
- Database: SQL Server via pyodbc
- Hosting: Posit Connect (connect2.astros.com)

## Colors
- Astros Navy: `#002D62`
- Astros Orange: `#EB6E1F`

## IT Contact
- **Chris Josefy** — Supervisor of Data (cjosefy@astros.com)
