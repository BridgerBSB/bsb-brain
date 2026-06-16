# PD Goals — Rolling Value Chart — 6 Week Per-Goal Time Series

> **Extracted from `pd-goals.md` 2026-05-19** to keep the parent rule under
> the article-recommended discoverability threshold. See parent for
> `## Rolling Value Chart` pointer. Auto-loaded with the parent on any
> Python edit in `pd-goals/`.

---

## Rolling Value Chart — 6 Week Per-Goal Time Series (Apr 25 2026, IN PROGRESS)

Per-goal cumulative-expanding chart added to PD Goals. Three columns
matching the bar chart / percentile rows, between percentile rankings
and the 3-bullet glossary on both surfaces.

### Files
| File | Role |
|---|---|
| `pd-goals/src/rolling_chart.py` | Plotly + matplotlib renderers; `compute_cumulative_at_ticks`; `weekly_tick_anchors`; `daily_dates`; metric-key normalizer |
| `pd-goals/src/rolling_stats.py` | Per-game SQL queries (`_hitter_per_game`, `_pitcher_per_game`, `_catcher_per_game`, `_fielding_per_game`, `_fielding_per_play`, `_hitter_sb_per_game`); `_translate` dispatcher |
| `pd-goals/src/report.py` | PDF wire-in (3-col row above glossary) |
| `pd-goals/pages/1_PD_Goals.py` | App wire-in (3 `st.columns` row, parallel fetch via ThreadPoolExecutor) |

### Three modes (dispatched by metric key)
| Mode | Detection | Computation at each tick | Examples |
|---|---|---|---|
| **CUMULATIVE_SUM** | `_normalize_metric_key(metric_key) in CUMULATIVE_METRICS` | `SUM(daily_value)` for game_date ≤ tick | NetK, OAA, PAA, FramRAA, BlockRAA, SurPP, SB count, IP |
| **RATE** | default if neither cumulative nor percentile | `SUM(numer) / SUM(denom)` for game_date ≤ tick | K%, BB%, Damage, zCon, FF Velo, FPinZ%, R2K%, EW%, all per-PT shape, all usage, Routine Conv, **PAA/EO** |
| **PERCENTILE** | `_normalize_metric_key(metric_key) in PERCENTILE_METRICS` | `np.percentile(play_value WHERE game_date ≤ tick, P_target)` | React P25, **UseReact P25**, ReactRad P25, ReactAccRad P25, TopSpd P95, Arm P99, Exch P10 |

### X-axis spec
- LINE plotted at DAILY granularity (every day from goal_start to `min(goal_end, today)`)
- TICK MARKS only at weekly anchors (start, +1wk, +2wk, ... end)
- Labels only on first + last anchors
- Final tick value = bar chart's "Goal Period" value EXACTLY (any divergence = bug)

### BLOCKING — single source of truth on metric-key normalization

**Both `rolling_stats._normalize` AND `rolling_chart._normalize_metric_key`
must produce the same canonical key for any user-facing metric string.**
Mismatched normalize logic between dispatcher and chart compute caused
multiple silent bugs this session. Required substitutions in both:
- lowercase + strip
- `%` → `_pct`
- ` ` (space) → `_`
- `-` → `_`
- `/` → `_`  *(critical for PAA/EO)*

Plus user-facing aliases in `rolling_chart._normalize_metric_key.aliases`:
`usereact` → `use_react`, `reactrad` → `react_rad`, `topspd`/`topspeed`
→ `top_speed`, `arm` → `arm_strength`, `exch` → `exchange`, `netk` →
`net_strikes`, `framraa` → `fram_raa`, `blockraa` → `block_raa`, `ip` →
`innings_pitched`, `stolenbases`/`steal` → `stolen_bases`, `reactaccrad`
→ `react_acc_rad`.

### Audit-driven parity fixes (commit `1a2415a`)
After diffing against canonical formulas in `stats.py`:
1. Stolen Bases — switched to runner_Nb match (was batter-row event_result_id)
2. EV misread filter — added to all BIP-tracked CASE WHEN blocks
3. FPS% — explicit whitelist (was NOT-IN ball codes)
4. CSW% — dropped redundant did_swing gate on whiff codes
5. SL HorzBrk — exposed raw catcher's-view column (was negated as sl_hb only)
6. Fielding default position — was "INF", switched to "ALL" matching stats.py:2666
7. INF Exchange — added exchange_dp branch (was always exchange)
8. PAA/EO offset — JOIN PAA_EO_Position_Calibration, expose adj_paa_delta = SUM(paa - offset*out_prob). Single-position: exact canonical match. Multi-position: small drift (eo-weighted vs simple mean).

### RESOLVED Apr 25 2026 — UseReact + PAA/EO root cause

**Bug was hypothesis #1 from the prior handoff: silent SQL error
swallowed by the dispatcher's try/except.**

`_fielding_per_play` line 864 selected `tdm.reaction_time AS react`
and `_fielding_per_game` line 981 selected `AVG(tdm.reaction_time)`.
**`reaction_time` is NOT a column on `Astros.Tracking_Defensive_Metrics`.**
The actual column is `reaction_4mph`. Stats.py + every working fielding
query in this repo SELECT `tdm.reaction_4mph AS reaction_time` (the
inverse direction — alias the real column). Rolling_stats had it
backwards.

SQL Server returned `Invalid column name 'reaction_time'`, the
dispatcher's `except Exception` caught it via `logger.warning()` —
which is hidden by default in Connect logs (per
`tracker-parquet-pins.md` rule 5.3) — and returned an empty DataFrame.

**Same bug killed React, ReactRad, TopSpd, Arm, Exch, Routine
Conversion in the rolling chart too.** The user only happened to
notice UseReact and PAA/EO because those were the active goals in
their test player's CSV — every fielding metric was equally broken.

**Fix:** commit `aad1e6e` — two SELECT lines patched + `logger.warning`
converted to `print` so the next class of swallowed-SQL-error surfaces
in Connect logs. Total diff: 5 deletions / 15 insertions.

**Lesson encoded in the fix's commit message:** five prior fix attempts
thrashed on dispatch / normalize / mode detection without ever
checking whether the SQL actually executed. Always verify the SQL
runs before chasing Python-layer bugs. The dispatcher's silent
`except` is a documented anti-pattern that just got bitten.

### Outstanding (none related to this bug class)

Code traces verified:
- `_translate("UseReact")` → `"use_react"` (`_PARSER_TO_INTERNAL["usereact"]`) ✓
- `_translate("PAA/EO")` → `"paa_eo"` (after `/` → `_` fix in `ed9e383`) ✓
- Dispatcher routes `use_react` → `_PCT_COL` → `_fielding_per_play` ✓
- Dispatcher routes `paa_eo` → `_FIELDING_RATE` → `_fielding_per_game` ✓
- `_normalize_metric_key("UseReact")` → `"use_react"` via aliases (commit `511f718`) ✓
- `is_pct = True` → percentile branch, np.percentile cumulative ✓
- For Frey (gc_id 174203, OF, A Fayetteville): bar chart populates UseReact value, so canonical Tier 1 + dropna chain returns non-empty data ⇒ data was NOT the issue. (Confirmed retroactively after the `reaction_time` fix.)

### Commits in chronological order
| Commit | What |
|---|---|
| `82f80a9` | Initial rolling chart + stats module |
| `f1ed1cb` | Layout fix (was being silently skipped in PDF) |
| `68906fc` | Dispatch fix — user-facing strings (was matching internal keys) |
| `ab74729` | Refactor to 7 weekly cumulative-expanding ticks |
| `d475f84` | Adaptive tick count (was always 7 even if period not elapsed) |
| `1aa04b5` | Daily line + weekly x-axis labels (was per-week-only line) |
| `b9cab36` | Dots only on weekly anchors (line stays daily) |
| `2c22240` | Glossary refactor (3-column, smaller text, more breathing room) |
| `f1a... ` | Y-axis domain formatting (`format_value` for ticks) |
| `fe7e978` | Damage canonical logistic formula (was binary EV/LA threshold) |
| `1a2415a` | 8 audit-driven parity fixes (SB, EV misread, FPS%, CSW%, SL HorzBrk, fielding default, INF exch, PAA/EO offset) + compound shape goals (two-line) |
| `8530b6e` | UseReact `is_inf` gate fix (legacy ALL/OUTFIELD position labels) |
| `511f718` | Mode-detection normalize bug — `compute_cumulative_at_ticks` was using raw lower() not aliases |
| `ed9e383` | PAA/EO slash bug — `_normalize` now replaces `/` with `_` |
| `ad951f0` | Docs handoff — KNOWN ISSUES section listing 5 next-agent hypotheses |
| `aad1e6e` | **ROOT CAUSE FIX** — `tdm.reaction_time` (alias-not-column) → `tdm.reaction_4mph` in both `_fielding_per_play` + `_fielding_per_game`; converted swallowing `logger.warning` → `print` |
| `66d1d1b` | PAA/EO denom — removed wrong `ev.first_defender_id = :fid` filter (canonical is "NO GATE" per stats.py:2868) |
| `b3bbecb` | Perf — `@st.cache_data(ttl=60)` wrapper for rolling-chart fetches |
| `ec54a60` | **REFACTOR** — PAA/EO + Routine Conv use per-play data + canonical aggregation (matches stats.py byte-for-byte regardless of position mix) |
| `5a85752` | **BLOCKING** — position scope fallback `'ALL'` (NOT roster pos_cat). See "Position Override" section above |
| `6c0f135` | Damage% BIP filter parity — `BIP_FILTER` now requires `hit_vertical_angle IS NOT NULL` matching bar chart |
| `c5eaa1b` | Damage% rounding aligned with Barrelsville (`round(x*100, 1) / 100`). See `damage-pct-cross-app-divergences.md` |
| `2cef0ac` | Audit batch — Wohlgemuth K%, AccelCD/CU/ReactAccRad wired, RoutineConversion alias, Top50EV per-tick path, Heart Swing %, position_override flows through chart_data, compound shape secondary metric in chart_data |
| `70ed28c` | Percentile color flip uses goal direction (NOT just `is_higher_better` default) — fixes SL IVB et al |
| `14271e8` | Reverted `f3ce81c` (no-percentile-for-shape/usage) per user request |
| `fdbb10d` | Compound shape crash fix — `bool()` wrap on `has_secondary` (Python `and` chain returned string) |
| `3ea3cdc` | Top50EV — removed `player_type='H'` gate + diagnostic print |
| `db5d77f` | SB perf via UNION ALL + Top50EV alias `top50thavgev → top_50th_avg_ev` |
| `8aac519` | Hitter SwDec wired (ppg.swing_decision LEFT JOIN + dispatcher) |
| `2abfb3a` | zCon vs BB & OS combined metric (was silently dropping OS) |

### Architecture notes
- Per-play fielding data: `_fielding_per_play` returns one row per
  qualifying play with raw tracking values. Used ONLY for percentile
  metrics (compute uses `np.percentile` cumulatively).
- Per-game fielding aggregates: `_fielding_per_game` returns one row
  per game with daily aggregates. Used for rate metrics (Routine Conv,
  PAA/EO) and cumulative metrics (OAA, PAA SUM).
- 6-term Tier 1 gate applied client-side after SQL fetch (matches
  `stats.py::_filter_tier1_plays`).
- Caching: `@st.cache_data(ttl=...)` not yet wrapped on the per-game
  helpers — relies on Streamlit's intrinsic widget rerun caching for
  app, runs sequentially on report-side.

### What NOT to do
- Don't add a third source of normalize logic. Both modules must call
  through the same alias table, OR refactor to a single shared module.
- Don't reinvent SQL formulas. When adding a new metric, diff against
  `stats.py` line-by-line. Damage taught us: the rolling and bar chart
  must match character-for-character on the formula.
- Don't fall through to the rate branch silently when mode detection
  fails. The `compute_cumulative_at_ticks` function should explicitly
  warn if `metric_key` doesn't match any of the three modes — currently
  it returns all-Nones which renders as a blank chart and looks like a
  data issue.
- **Don't use `logger.warning` in dispatcher try/except blocks.** Use
  `print()`. Connect's default log level hides warnings (per
  `tracker-parquet-pins.md` rule 5.3). The Apr 25 `reaction_time` bug
  burned 5 fix attempts because the swallowed SQL error was invisible.
- **Don't reference column ALIASES as if they're column names.**
  Stats.py + intangibles do `tdm.reaction_4mph AS reaction_time` —
  the *alias* is `reaction_time`, the *column* is `reaction_4mph`.
  Rolling_stats had the inverse. When porting SQL between modules,
  always SELECT the real column name (`reaction_4mph`,
  `useful_reaction_4mph`, `acceleration_chest_up`,
  `acceleration_chest_down`) — never the alias the destination module
  happens to use downstream. Authoritative TDM column list:
  `sql-queries/pd-goals-discovery-queries.md` Q7 (verified via
  INFORMATION_SCHEMA).
- **Don't fall back to roster `pos_cat` when no goal-text position
  keyword is present.** ALWAYS fall back to `'ALL'`. The bar chart
  uses `defense_pos_override or 'ALL'` (1_PD_Goals.py:578) — every
  other defense fetch in the rolling chart (app + PDF) MUST mirror
  that rule exactly. Roster pos_cat is stale (mid-season position
  swaps); 'ALL' captures every play regardless of where the player
  is rostered. Apr 25 2026 Powell incident: rostered SS, playing OF,
  rolling chart silently dropped every OF play under roster fallback.
  See "Position Override — Goal Text Drives Defense Routing" section
  above for the full rule + checklist.
