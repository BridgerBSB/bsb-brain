# Cross-App Patterns

The single biggest reason this codebase doesn't drift is the
discipline around five cross-cutting patterns:

1. **Three-surface parity** --- the same metric computed in 3 places must agree
2. **Multi-level rollup** --- weighted-avg patterns that don't silently bias org values
3. **Dual query path** --- CLI vs app data functions that must stay in sync
4. **KPI weekly chart math** --- pool-then-aggregate vs aggregate-then-roll
5. **In-app submission pattern** --- form → pin → PDF → Slack inside Streamlit

Plus two more situational patterns:

6. **Video angle three-tier fallback** --- the V-column standard
7. **PA gate vs wOBA denom** --- two PA conventions that must not be confused

This chapter is the discipline that keeps the codebase honest.

::: tip
**What you'll learn:** the three-surface parity invariant, the
weight column rule that catches multi-level bugs, the dual-query-path
sync rule, the difference between cumulative / rate / per-player
percentile chart metrics, the in-app submission pattern, the
V-column fallback, and the PA gate trap.
:::

## 1. Three-surface parity (BLOCKING)

For each domain (Hitting, Pitching, Catcher, OF, IF, BR), **the same
metric is computed in three places.** Any change to ONE of these
surfaces MUST be propagated to the other TWO before the commit ships.

### The three surfaces

| Domain | Tracker (live app) | KPI Weekly (PDF + chart) | PD-Goals Org KPI Report |
|---|---|---|---|
| Hitting | `barrelsville/src/tracker_data.py` | `barrelsville/src/hitter_kpi_data.py` + report | `pd-goals/src/org_kpi_data.py` (hitting section) |
| Pitching | `bullpen-report/src/tracker_data.py` | `bullpen-report/src/pitcher_kpi_data.py` + report | `pd-goals/src/org_kpi_data.py` (pitching section) |
| Catcher | `intangibles/src/catching_tracker_data.py` + page | `intangibles/src/c_kpi_data.py` + report | `pd-goals/src/org_kpi_data.py` (catcher section) |
| OF | `intangibles/src/fielding_tracker_data.py` + page (`render("OF")`) | `intangibles/src/of_kpi_data.py` (uses shared `fielding_tracker_data.py`) | `pd-goals/src/org_kpi_data.py` (OF section) |
| IF | `intangibles/src/fielding_tracker_data.py` + page (`render("IF")`) | `intangibles/src/if_kpi_data.py` (shared) | `pd-goals/src/org_kpi_data.py` (IF section) |
| BR | `intangibles/src/br_tracker_data.py` + page | `intangibles/src/br_kpi_data.py` | `pd-goals/src/org_kpi_data.py` (BR section) |

### What counts as a change requiring propagation

ANY of these on a metric query/aggregation:

- WHERE filter (date range, sched_type, level, `c_id IS NOT NULL`,
  `pitch_id > 0`, etc.)
- JOIN keys / extra JOINs
- Range filter (e.g. `arm BETWEEN 60 AND 94`, `pop_time BETWEEN 1.70 AND 2.35`)
- Percentile target (P99, P10, P01, etc.)
- Aggregation column (which `n_X` count is the weight at each tier)
- Sign convention (e.g. `br_rv` negation for BlockRAA)
- Bucket boundaries (CSC framing buckets, pop_time 2B vs 3B ranges)
- Pool gating (Tier 1 6-term gate on fielding, `c_id NOT NULL` gates on catching)

### The propagation workflow before every commit

```
1. Identify the metric + the surface you changed.
2. grep the OTHER two surface files for the same metric:
   grep -n "metric_name\|column_name\|table_name" <other_surface>.py
3. Confirm the same filter/aggregation logic exists in the other two.
4. If divergent: apply the same fix to the other two.
5. Test all three views show the same value for HOU.
```

### Common per-surface differences (NOT bugs)

| Aspect | Tracker | KPI Weekly | PD-Goals |
|---|---|---|---|
| Date filter | No `end_date` cutoff (live data) | Per chart date range | `<= :end_date` (report-as-of) |
| Multi-level | Aggregates per-level → all-level via Python | Per-level only (one PDF per level) | Single SQL pass across all levels |
| Caching | Streamlit `@st.cache_data` + parquet pins | Generated on-demand | Generated on-demand |

### Bug history --- recent parity fixes

The discipline came from a year of bug-hunting. A short tour of what's
been fixed:

| When | Bug | Fix |
|---|---|---|
| Apr 2026 (catcher) | `_get_baserunner_advance_rv` returned positive (batting-team) instead of negated (pitching-team); BlockRAA rank inverted | Negated everywhere |
| Apr 2026 (catcher) | Tracker Pop2B base filtered to SBA events only; PD-Goals + KPI weekly use all TDM throws | Aligned to all-TDM pool |
| Apr 2026 (catcher) | `pv.pitch_id > 0` filter missing on PD-Goals + KPI weekly per-catcher blocking | Added everywhere |
| Apr 2026 (catcher) | Multi-level org Arm/Exch weighted by `comp_throws` instead of `n_arm`/`n_exch` | Switched to per-metric weight (see Pattern 2) |
| Apr 2026 (OF/IF) | Multi-level percentile pooling failed for cross-level fielders --- weighted avg of per-level P99s ≠ pooled P99 | Single SQL with `IN (levels)` filter |
| Apr 2026 (hitting) | wOBA denom inflated by SH count (used PA count instead of `AB+BB-IBB+HBP+SF`) | Fixed everywhere |
| Apr 2026 (hitting) | PD-Goals xwOBA exponents fell back to prior year; tracker queried `:season` directly --- ~0.003 xwoba gap year-round | Dropped fallback in PD-Goals |
| Apr 2026 (hitting) | PD-Goals weight JOIN used `wl.year = sv.year` --- NULL'd 2026 weights early-season | Added `:lookup_year` param |
| May 2026 (hitting) | gcOBA swing-distribution Python groupby used `ab_event_id` alone (not globally unique) --- distribution SUM 0.72 instead of 1.0 | Use `(sched_id, ab_event_id)` composite |
| May 2026 (hitting) | Bat speed `cur_event_id` INNER JOIN dropped mid-AB foul balls + whiffs (silently); double-filter postgame trimmed mean down ~0.5 mph | Canonical helper, JOIN on `ab_event_id` |

::: blocking
**Never patch display rounding to hide drift.** Fix the underlying
SQL/aggregation. Drift is the codebase telling you a real bug
exists.
:::

## 2. Multi-level rollup --- the weight column rule (BLOCKING)

When aggregating a metric from per-level → multi-level (or any
tier-to-tier weighted average), **the weight column at the OUTER tier
MUST equal the count column used at the INNER tier.**

If you weight by a different proxy (e.g. `comp_throws` instead of
`n_arm`), the multi-level result silently drifts off the all-pool
answer. Math doesn't recover.

### The bug pattern (made concrete)

```
Per-level Arm = SUM(catcher_p99 × n_arm) / SUM(n_arm)   ← weighted by n_arm

Multi-level (WRONG):
   = SUM(per_level_Arm × comp_throws) / SUM(comp_throws)   ← weighted by DIFFERENT count

Multi-level (RIGHT):
   = SUM(per_level_Arm × per_level_Σ(n_arm)) / SUM(per_level_Σ(n_arm))
   = SUM(catcher_p99 × n_arm) over ALL levels / SUM(n_arm) over ALL levels
   = ALL-POOL WEIGHTED AVG  [correct]
```

The right multi-level expression algebraically reduces to the all-pool
answer. The wrong one doesn't, because `comp_throws ≠ n_arm` per level
(different filters: `competitive_throw=1` vs `arm BETWEEN 60-94`).

### Per-metric weight reference (catcher example)

| Metric | Per-level weight (inside SQL) | Multi-level weight (outer tier) | Notes |
|---|---|---|---|
| Arm (P99) | `n_arm` = COUNT(arm 60-94) per catcher | `arm_n` = SUM of `n_arm` per org | NOT `comp_throws` |
| Exch (P10) | `n_exch` = COUNT(exch≥0.4 AND arm≥60) per catcher | `exch_n` = SUM per org | NOT `comp_throws` |
| Pop2B (P01) | `n_obs_2b` = COUNT(pop 1.70-2.35) | `n_throws_2b` per org | Same value (no extra filter) → OK |
| AugPop (P01) | `n_aug_pop` per catcher | `n_sba_events` per org | Same value → OK |
| NetK (SUM) | --- (cumulative) | `n_pitches` | Cumulative SUMs add cleanly |
| FramRAA (SUM) | --- | `n_pitches` | Same |
| Framing buckets (rate) | --- (rate from CASE/SUM) | `n_pitches` | Pitch-weighted across levels |

::: blocking
**Per-fielder per-org P-metrics use per-metric `n_X_total` weighting,
not `comp_plays` / `comp_throws` / `n_pitches`.** This is the most
common multi-level bug class. See `.claude/rules/multi-level-rollup.md`
for the full per-metric weight reference and the per-fielder pattern
that catches catcher / OF / IF / BR P-metrics.
:::

### Pooled percentile bug --- weighted avg of per-level percentiles ≠ single-pool percentile

Even with correct per-metric weighting, percentile metrics have a
deeper trap: a fielder who appears in TWO levels gets two per-level
percentiles, and `weighted_avg(p1, p2)` is **NOT** the same as
`percentile(union(p1_pool, p2_pool))`.

A fielder with 30 TopSpd readings at AAA and 20 at AA:

- Per-level percentile approach (old tracker): P95 over 30 AAA = 28.5,
  P95 over 20 AA = 29.2, weighted avg = 28.78
- Pooled percentile approach (PD-Goals): P95 over all 50 = 28.9 (or
  any value between 28.5 and 29.2)

The two are only equal when the player appears in one level. OF has
more cross-level movement than IF (CF prospects get promoted more than
2B/SS), so OF drifted visibly while IF looked OK --- same code,
different player-mobility patterns.

### The fix --- single SQL with `IN (levels)` filter

When the user selects 2+ levels, run ONE SQL that scopes the
per-player percentile CTE to ALL selected levels:

```sql
per_fielder AS (
    SELECT DISTINCT org, fielder_id,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY
            CASE WHEN top_speed <= 34 THEN top_speed END)
            OVER (PARTITION BY fielder_id) AS top_speed,
        ...
    FROM base
)
-- base:
WHERE ({level_filter})           -- was: sv.level_code = 'aaa'
                                 -- now: sv.level_code IN ('mlb','aaa','aax',...)
```

`PERCENTILE_CONT OVER (PARTITION BY fielder_id)` partitions across
pooled observations naturally. Reference impl:
`intangibles/src/fielding_tracker_data.py::_build_levels_filter` +
`_get_pooled_org_stats` + `get_org_rankings_pooled` (commit `1dd24bb`).

## 3. Dual query path (BLOCKING)

When modifying ANY pitch query, check if a parallel app/CLI query
exists and update both.

### The pattern

| App | CLI path | Streamlit path |
|---|---|---|
| Barrelsville postgame | `get_game_pitches()` | `get_game_pitches_for_app()` |
| Arm Farm postgame | `get_game_pitches()` | `get_game_pitches_for_app()` |
| Intangibles BR postgame | `br_data.py` queries | `br_postgame_app.py` |

### Why two

The CLI path is optimized for batch generation (one query per player
per day). The app path is optimized for interactive use (cached,
filtered by user-selected sched_types). They have slightly different
parameter shapes but produce **identical metric values** when given
the same inputs.

### When to update which

| Change type | Update both? |
|---|---|
| WHERE filter | YES |
| Metric formula in SELECT | YES |
| New JOIN | YES |
| Param name change | YES |
| Performance tuning (index hint, query rewrite) | Usually one is enough |

When in doubt, update both.

## 4. KPI weekly chart math --- the pool-then-aggregate rule (BLOCKING)

The chart-line implementation for every KPI weekly report follows one
of three patterns depending on the metric type. **Picking the wrong
one silently breaks chart values.**

### The shape

Every KPI weekly chart consumes data shaped like this:

```
DataFrame: one row per (org, year, iso_week)
Columns:   org, year, week, game_date, game_month, <metric_cols>
```

The chart consumer plots the line; rank boxes pin to the most recent
weekly row in each month.

### Three metric types, three correct treatments

| Type | Examples | Correct treatment |
|---|---|---|
| **Cumulative SUM** | OAA, NetK, FramRAA, BlockRAA, SB, CS, 1→3, 2→H | `groupby("org")[col].cumsum()` across weekly rows. Line ramps; end-of-season = season tracker total exactly |
| **Rate** (numer/denom) | R2K%, FPinZ%, EW%, K-BB%, xwOBA, SurPP, 1B PL, 1B SL, PAA/EO | 4-week rolling SUM on numer + denom separately, divide AFTER rolling. NEVER rolling-avg the pre-computed rate |
| **Percentile** (per-fielder/player) | TopSpd P95, React P25, UseReact P25, Arm P99, AugPop2B P01 | Pool 4 weeks of RAW observations per fielder, compute `np.percentile` ON the pool, weighted-avg to org by per-fielder n_obs. NEVER rolling-avg per-week percentiles |

### Why pool-then-aggregate (and not aggregate-then-roll)

#### For rates: trivially correct, also commutative

`SUM(numer over 4 weeks) / SUM(denom over 4 weeks)` =
`weighted_avg(weekly_rates, weights=weekly_denom)`. So either
implementation works arithmetically. The "rolling SUM on raw
components" form is preferred because it composes cleanly with
multi-level rollup and matches the reference impls.

#### For percentiles: the math is fundamentally different

P99 is **non-linear and non-additive**. You CANNOT recover the
4-week-window P99 by averaging the four 1-week P99s. They aren't equal.

**Per-week-then-roll bias (the trap):** P99 over a fielder's 5-15
throws in one week is biased LOW versus P99 over their 50+ season
throws --- small samples rarely include the fielder's max-effort
throws. Rolling-avg of those biased weekly percentiles inherits the
bias and the chart line sits 3-5 mph below the season tracker value
indefinitely.

**Pool-then-percentile (the fix):** for each week-ending date, gather
all observations from the trailing 4 weeks per fielder, compute
`np.percentile(pool, 99)` on the combined ~50-80 throws. Big enough
sample for P99 to mean something. Each week the pool slides forward
by 1 week --- chart still bumps weekly with real signal but absolute
values stay close to season-tracker (typically <1 mph drift by
mid-season).

This was the core of the Apr 27 2026 OF/IF Arm IF fix. Symptoms: PD
Goals tracker showed AAX HOU Arm IF = 92.6 mph; weekly KPI chart line
showed ~89 mph. Three commits to find it; the working fix is
`8a8f378`.

### Reference implementations (canonical, keep in sync)

| Surface | Module | Pattern type |
|---|---|---|
| Barrelsville hitter weekly | `barrelsville/src/hitter_kpi_data.py::get_kpi_chart_data` | Rate (4-week rolling SUM on numer/denom) |
| Arm Farm pitcher weekly | `bullpen-report/src/pitcher_kpi_data.py::get_kpi_chart_data` | Rate (same pattern) |
| Intangibles OF | `intangibles/src/of_kpi_data.py` | Percentile + cumsum + rate |
| Intangibles IF | `intangibles/src/if_kpi_data.py` | Same as OF |
| Intangibles BR | `intangibles/src/br_kpi_data.py` | Cumsum + rate |
| Intangibles Catcher | `intangibles/src/c_kpi_data.py` | Rate + cumsum |

### Chart line vs rank box vs card --- they intentionally differ

| View | What it shows |
|---|---|
| **Chart line at week N** | 4-week rolling rate or pool-percentile **as of week N** |
| **Rank box at month-end** | HOU's standing vs other 29 orgs |
| **Card / season-to-date** | Season tracker / season aggregate |

Last week's chart value ≠ card value, by design. The chart shows
"recent form"; the card shows "season standing." Both useful, both
correct.

## 5. The in-app submission pattern

For any user-triggered Streamlit form that needs to:

- Persist user-submitted data
- Render a branded PDF
- Deliver to Slack channels

…all from inside a running Streamlit app, with no CLI and no external
infrastructure.

### Five required modules per app

```
src/<app>_pins.py          # Pin RW (submissions + drafts)
src/<app>_channels.py      # Channel resolution
src/<app>_pdf.py           # reportlab PDF generator
src/<app>_slack.py         # Logic App POST wrapper
pages/<submit>.py          # Form page calling the above
```

Each under 200 lines. No new infrastructure beyond what the app already
has (Posit pins board, Logic App URL).

### Two parquet pins per submission flow

- `zbridger/<app>_reports` --- final submissions
- `zbridger/<app>_drafts` --- works in progress

Both as joblib bundles with `allow_pickle_read=True` on the board.
Conform DataFrame to canonical column list on read AND write.

### Cleanup CLI ships from day one

`scripts/clean_<app>_submissions.py` with `--list`, `--delete <uuid>`,
`--clear-all --confirm`. Without it, debugging a corrupt pin is
manual and risky.

### Reference impl: Transition Reports

The Transition Report on PD Engine is the canonical reusable
architecture. When building any future internal form (incident
reports, weekly coach notes, scout reports), copy this module family
and change only what's app-specific (column list, PDF layout, channel
routing rule, form labels).

| Piece | File |
|---|---|
| Pins module | `pd-goals/src/transition_pins.py` |
| Channels | `pd-goals/src/transition_channels.py` |
| PDF generator | `pd-goals/src/transition_pdf.py` |
| Slack wrapper | `pd-goals/src/transition_slack.py` |
| Submit page | `pd-goals/pages/2_Transition.py` |
| View page (3-tab browse) | `pd-goals/pages/3_Transitions_View.py` |
| Cleanup CLI | `pd-goals/scripts/clean_transition_submissions.py` |

### Streamlit gotcha: deferred-load pattern (BLOCKING)

Streamlit forbids mutating `st.session_state[KEY]` AFTER the widget
with `key=KEY` has instantiated in the current script run. Naive
load-button handlers throw `StreamlitAPIException` on every click.

The canonical fix --- two-pass state hydration:

```python
# Load button anywhere below the widgets:
if st.button("Load draft", key=f"load_{draft_id}"):
    st.session_state.t_pending_draft_load = draft_row.to_dict()
    st.rerun()

# _apply_pending_load() — called ONCE at the top of the script,
# BEFORE any widget instantiates:
def _apply_pending_load():
    row = st.session_state.pop("t_pending_draft_load", None)
    if row is None:
        return
    # Now safe to set every widget-key state, since widgets haven't rendered yet
    st.session_state.t_submitter_name = row["submitter_name"]
    ...

_apply_pending_load()  # ← call HERE, before any st.text_input() etc.
```

## 6. The V-column three-tier video fallback

Every "V" column that ships to players (Arm Farm pitcher postgame,
Barrelsville hitter postgame, Intangibles BR/OF/IF weekly + individual,
Arm Farm Daily Tracker click-to-video) uses this fallback chain:

```sql
ISNULL(av.video_url,                       -- 1. Astros.Video angle_id=1  (PRIMARY)
  ISNULL(vn_v.video_url, vn_a.video_url))  -- 2. VN 'v' → 3. VN 'a'       (FALLBACK)
```

Required JOINs:

```sql
LEFT JOIN Astros.Video av
    ON av.sched_id = pv.sched_id AND av.pitch_id = pv.pitch_id AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id AND vn_v.pitch_id = pv.pitch_id AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id AND vn_a.pitch_id = pv.pitch_id AND vn_a.angle = 'a'
```

### Why this order

1. **`Astros.Video` first** --- sporty-clips is the only source that
   reliably plays on player phones regardless of IT policy. Catcher
   reports have always used this and they've been the one surface that
   never breaks for home games.
2. **`Video_Network 'v'` second** --- personal-device-safe when RND
   ingests it, but they routinely miss it. Covers Astros-AWAY MiLB
   games where sporty-clips is empty.
3. **`Video_Network 'a'` third** --- CF broadcast feed, often available
   when V isn't, still plays on phones. Last-resort safety net.

Side / Main / CF Edge columns use a different chain --- this rule
applies ONLY to the V column. Side angles serve team-device viewing
where all angles are available.

## 7. PA gate vs wOBA denom (BLOCKING)

Two PA conventions coexist; using the wrong one silently inflates
denominators.

| Use case | Formula | Why |
|---|---|---|
| K%, BB%, IP-ish PA counts | `SUM(pa) + SUM(ibb)` (total PA inc. IBB and SH) | What every app's K%/BB% denom uses |
| wOBA / xwOBA denom | `AB + BB - IBB + HBP + SF` (FanGraphs std, EXCLUDES SH) | Matches FanGraphs / GC2 production |
| xwOBA denom (alternative) | non-IBB PA count `SUM(CASE WHEN pa=1 AND ibb=0 THEN 1 ELSE 0 END)` | Includes SH but SHs contribute 0 to xwOBA numer; this form works for xwOBA specifically |

::: blocking
**Most apps' K%/BB% use `SUM(pa) + SUM(ibb)` as denom --- "total PA."**
Developers reach for the same pattern for wOBA denom and it silently
drifts by the SH count. Always use the explicit `AB + BB - IBB + HBP + SF`
formula for wOBA. This is the most common silent-drift bug in the
codebase.
:::

## Where to look next

- **Chapter 14** for the recipes (add a metric, debug a parity issue,
  propagate a fix).
- `.claude/rules/three-surface-parity.md` --- the canonical parity rule.
- `.claude/rules/multi-level-rollup.md` --- the weight column rule.
- `.claude/rules/dual-query-path.md` --- dual query path.
- `.claude/rules/kpi-weekly-charts.md` --- KPI chart math.
- `.claude/rules/in-app-submission.md` --- form pattern.
- `.claude/rules/video-angles.md` --- V-column fallback.
