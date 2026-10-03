# Data Cleaning Canon

The DB has noise. HawkEye misreads exit velocity occasionally,
sensors flag check swings as bunts, BIT columns refuse to SUM in SQL
Server, NaN propagates silently, and float-quantization at the
display layer creates 0.1% drifts between surfaces.

This chapter is the definitive reference for every cleaning rule the
codebase enforces. Memorize the BIP filter chain and the BIT casting
rule on day 1; the rest gets internalized as you encounter each bug
class.

::: tip
**What you'll learn:** the BIP filter chain (4 filters every BIP
metric uses), the EV misread CTE, the bat speed canonical helper,
the 6-term Tier 1 fielding gate, BIT casting for SQL Server, the
ignore_flag swing-recovery pattern, the never-round-until-display
rule, and ~10 silent-failure traps.
:::

## The BIP filter chain (BLOCKING)

Every batted-ball metric (Avg EV, Max EV, Hard%, Barrel%, pBarrel%,
PullAir%, Dmg%, xwOBA-on-BIPs) applies all four of these filters. Skip
one and the metric drifts.

### 1. Tracked BIP

```sql
WHERE pv.pitch_result_id IN (12, 13, 14)
  AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
```

`pitch_result_id IN (12,13,14)` = ball-in-play codes. `EV > 0`
excludes sensor zeros; `EV < 125` caps physically impossible reads.

::: note
Some queries (gcERA / gcPerf BIP rate) include pitchout BIPs
`pitch_result_id IN (12,13,14,18,19,20)`. Pitchout BIPs are extremely
rare --- the difference is negligible. Standardize when convenient.
:::

### 2. Bunt exclusion

```sql
AND (h.hit_trajectory_id NOT IN (2, 3, 4)
     OR h.hit_trajectory_id IS NULL)
```

The `hit_trajectory_id` column lives in **`Events_View`**, NOT in
`Hits`. So you'll typically join Events_View on `ab_event_id` to get
this column for every pitch.

`(2, 3, 4)` = bunt popup, bunt groundout, bunt foul. Always exclude.

### 3. EV misread filter (per-batter P95 floor)

```sql
WITH batter_ev_p95 AS (
    SELECT pv.batter_id,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY h.hit_exit_speed)
            OVER (PARTITION BY pv.batter_id) AS ev_p95
    FROM Astros.Pitches_View pv
    JOIN Astros.Hits h ON pv.sched_id = h.sched_id AND pv.pitch_id = h.pitch_id
    JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
    WHERE pv.pitch_result_id IN (12, 13, 14)
      AND h.hit_exit_speed > 0 AND h.hit_exit_speed < 125
      AND sv.year = :season
      AND sv.level_code IN ('mlb','aaa','aax','afa','afx','rok','dsl')
      AND pv.pitch_id > 0
)
-- ... later in main query:
AND NOT (h.hit_exit_speed >= 100 AND h.hit_vertical_angle < -35
         AND h.hit_exit_speed > b95.ev_p95)
```

Three conditions must ALL be true to flag a misread:

1. `hit_exit_speed >= 100` (high EV)
2. `hit_vertical_angle < -35` (severe downward LA)
3. `hit_exit_speed > batter_p95` (exceeds the batter's own 95th percentile)

If a batter has fewer than 20 BIPs, the per-batter P95 isn't
trustworthy --- the fallback is 105 mph (`hit_exit_speed > 105` as
condition 3).

**Where this lives:**

- SQL: `EV_MISREAD_CTE` in `barrelsville/src/postgame_data.py`,
  `tracker_data.py`, `postgame_percentiles.py` (most files have a
  copy --- they're byte-identical).
- Python: `clean_ev_misreads()` in each app's `database.py`. NULLs
  the misread EV in the DataFrame once; downstream code just uses
  the cleaned column.

::: blocking
**Misread cleaning is a SINGLE PASS.** Don't apply the filter twice.
The Apr 2026 Schiavone Dmg% bug was caused by `_enrich_pitches`
applying Pass 1 of an old 2-step filter and `_compute_summary_stats`
applying Pass 2 on already-cleaned data --- mean drifted DOWN ~0.5
mph.
:::

### 4. Junk-level scope

```sql
WHERE NOT (h.hit_vertical_angle < -25 AND sv.level_code IN ('hsb', 'sum', 'bbc'))
```

Amateur level data has more sensor noise. We don't drop these levels
entirely (they're needed for amateur-vs-pro analyses), but we drop
the most extreme misreads inside them.

## The bat speed canonical helper (BLOCKING)

There's ONE helper. Every surface that aggregates per-batter bat speed
routes through it. If you write a new computation that doesn't call
`clean_bat_speed_per_player`, you're reintroducing the May 2026 bug
class.

### The canonical rule (memorize this)

```
Pool = every event with a swing_contact_values row
       (BIP + fouls + foul tips + WHIFFS — bat speed at contact is
       tracked even on whiffs, because HawkEye measures bat velocity
       at the contact-zone frame regardless of strike outcome)

Per batter:
    Always: drop anything below 57 mph
            (catches bunts, check swings, tracking glitches —
             bunts physically can't exceed 57 mph in a competitive swing)
    Conditional: if the batter has >= 20 swings in the pool,
                 also drop the bottom 10% (per-batter p10).
                 p10 is computed on RAW (pre-floor) speeds.
    No upper cap. At-contact distribution self-bounds.
    No ±2.5σ trim. Trims legitimate elite swings on small samples.
    No post-clean minimum count. Even one surviving swing publishes.
```

### The helper

```python
from .bat_speed_clean import clean_bat_speed_per_player

cleaned = clean_bat_speed_per_player(raw_df,
                                     batter_id_col="batter_id",
                                     bs_col="bat_speed_mph")
```

**Lives in TWO byte-identical copies:**

- `barrelsville/src/bat_speed_clean.py`
- `pd-goals/src/bat_speed_clean.py`

If you change one, change the other in the same commit.

### Pulling raw bat speed --- the canonical SQL

```sql
SELECT pv.batter_id,
       SQRT(POWER(scv.batvx_con, 2) + POWER(scv.batvy_con, 2)
          + POWER(scv.batvz_con, 2)) * 0.681818 AS bat_speed_mph
FROM Astros.Pitches_View pv
JOIN groundcontroltracking.tracking.plays tp
    ON tp.sched_id = pv.sched_id AND tp.astros_pitch_id = pv.pitch_id
JOIN groundcontroltracking.tracking.swing_contact_values scv
    ON scv.sched_id = tp.sched_id AND scv.tracking_play_id = tp.tracking_play_id
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
WHERE scv.batvx_con IS NOT NULL
  AND pv.pitch_id > 0
  -- + level / season / sched_type / batter_id / date scope per use case
```

If you need an H/A filter (`top_of_inning`), JOIN `Events_View` on
`ab_event_id` (NOT `cur_event_id` --- that drops mid-AB foul balls and
mid-AB whiffs, which was the May 2026 Tracker bug).

### What the helper does NOT do

- **Does not exclude bunts via `hit_trajectory_id`.** The 57 mph floor
  catches every bunt because bunts physically can't exceed 57 in a
  competitive swing.
- **Does not exclude whiffs.** Whiffs DO have bat-speed-at-contact
  readings.
- **Does not enforce a min-swings hard cutoff for publishing.** Pool
  inclusion gates (e.g. min 50 for percentile distributions) belong
  at the OUTER layer, not in the helper.
- **Does not apply ±2.5σ trim.** Removed because it trims legitimate
  elite swings on small samples and σ is unstable on small samples.
- **Does not round.** Returns full-precision floats. Display layers
  round at presentation.

### The 8 surfaces that route through it

| App | File | Function |
|---|---|---|
| Barrelsville | `tracker_data.py` | `_compute_batter_bat_speeds`, `_compute_bat_speed_per_org` |
| Barrelsville | `hitter_kpi_data.py` | `_compute_bat_speed_per_batter` |
| Barrelsville | `weekly_hitter_data.py` | `_filter_bat_speed` |
| Barrelsville | `postgame_data.py` | `_enrich_pitches` (per-pitch column) + summary |
| Barrelsville | `postgame_percentiles.py` | `_compute_bs_distribution` |
| PD Goals | `stats.py` | bar chart `bat_speed_query` |
| PD Goals | `org_kpi_data.py` | `_compute_bat_speed_per_org` |
| PD Goals | `percentiles.py` | `_get_bat_speed_distribution` |
| PD Goals | `drift_hitting.py` | `_clean_bat_speed_avg` |

If you're adding a 9th surface, follow the implementation playbook in
`.claude/rules/bat-speed-canonical.md`.

## The 6-term Tier 1 fielding gate (BLOCKING)

For OF + IF tracking metrics. Replaces GC2's `competitive_play = 1`
gate with a 6-term OR that catches plays GC2 misses.

```sql
WHERE (
    CAST(ISNULL(dcbp.out_made, 0) AS int)
  + CAST(ISNULL(dcbp.competitive_play, 0) AS int)
  + CAST(ISNULL(dcbp.competitive_throw, 0) AS int)
  + CAST(ISNULL(tdm.competitive_play, 0) AS int)
  + CAST(ISNULL(tdm.competitive_throw, 0) AS int)
  + CASE WHEN tdm.arm >= :arm_floor THEN 1 ELSE 0 END
) > 0
```

Arm floor: OF = 75, IF = 70.

**Why both DCBP and TDM?** They independently flag the same play and
**can disagree**. Example: Trammell 04/01 --- TDM.CP=1 with TopSpd=27.2,
but DCBP.CP=0. GC2 (which only checks DCBP) drops the play and all
its tracking data. Our gate catches it.

**Three BLOCKING rules for Tier 1:**

1. Tier 1 is the ONLY gate for ALL tracking metrics. NEVER add
   `competitive_play = 1` as an extra filter on top of Tier 1.
2. NEVER use `CP=1` alone as a tracking metric gate. A play with
   `out_made=1, arm=78, CP=0` passes Tier 1 and its tracking data
   MUST be included.
3. CP count is **display-only**. `SUM(competitive_play)` is fine for
   showing a volume column; never as a metric filter.

**Tier 2 vs Tier 3:**

- **Tier 2** = play-visibility filter (whether to display a play in a
  table). 5-condition OR: `out_prob BETWEEN 0.02 AND 0.98 OR
  competitive_throw=1 AND first_defender OR |PAA| >= 0.05 ...`
- **Tier 3** = difficulty attribution. `first_defender = this fielder
  AND out_prob IS NOT NULL`. Used for the Routine/Extended/Good/Great/Elite buckets.

### Cumulative value metrics --- NO gate (BLOCKING)

**OAA, PAA, PAA/EO, RAA are computed across ALL
`Defense_Combined_By_Pos` rows for the fielder. No Tier 1 / 2 / 3
gate.** Matches GC2 exactly (verified Apr 16 2026 in
`.claude/rules/fielding.md`).

The actual computation in `pd-goals/src/stats.py::get_defense_stats`:

```python
# All DCBP rows for this fielder, in scope (level + sched_type + date)
has_dcbp = df[df["out_prob"].notna()].copy()
total_paa = has_dcbp["paa"].sum()           # sum of pre-computed dcbp.paa column
total_out_prob = has_dcbp["out_prob"].sum() # sum of out_prob across all rows
avg_offset = has_dcbp["paaeo_offset"].mean()
paa_eo = total_paa / total_out_prob - avg_offset
```

::: note
**What `paaeo_offset` actually corrects for (verified May 2026 vs GC2
source SQL).** The calibration table is keyed on `(pos_id, positional,
season)`, where `positional` is a **tracking-completeness flag**
(1 = fully HawkEye-tracked, 0 = `out_prob`-only). The offset zeroes
out systematic bias in raw `dcbp.paa` per (position × tracking-state)
combo, refit yearly. It is NOT just a "position rescaler" — it's also
the correction that lets you sum across tracked + untracked plays
cleanly. GC2 publishes both a default (all plays) and `_Tracked`
(positional = 1) variant of every PAA-family metric; we currently
expose only the default. Full breakdown in
`.claude/rules/pd-goals-defense.md` "Calibration mechanics" section.
:::

**Notice:** no `first_defender_id` filter, no Tier 1 6-term gate, no
Tier 2 / 3 conditions. Just every DCBP row for the fielder.

**What this means in practice:** if `Defense_Combined_By_Pos` gave a
fielder a row with non-zero `out_prob` on a play, that row counts in
their PAA --- whether or not they were the first defender, whether or
not the play was tracked, whether or not it was "competitive" by Tier
1 standards. The credit / blame baked into `dcbp.paa` per row is
GC2's responsibility; our code just sums it.

That's the difference from the difficulty buckets. Difficulty
buckets (Tier 3) explicitly gate on
`first_defender_id = dcbp.groundcontrol_id` (see `stats.py:2107`)
--- a fielder who wasn't the first defender doesn't show up in any
of his own buckets. But the same play CAN still affect his PAA if
DCBP gave him a row with non-zero `out_prob`.

The Tier 1 / 2 / 3 gates are for **tracking** metrics (TopSpd, React,
Arm, Exchange, etc.) and the **display** layer. **Value metrics**
ignore those gates entirely --- by design, matching GC2.

| Metric class | Gate | Why |
|---|---|---|
| Tracking (P95 TopSpd, P25 React, P99 Arm, P10 Exchange, etc.) | **Tier 1** (6-term) | Restricts pool to plays where the fielder actually had a chance to run / make a tracked move |
| Play table display | **Tier 2** (5-condition OR) | Cosmetic --- which plays show up in PDFs/tables |
| Difficulty buckets (Routine/Extended/Good/Great/Elite) | **Tier 3** (first_defender + out_prob) | Attribution --- only the first defender owns the play for difficulty conversion |
| **OAA, PAA, PAA/EO, RAA** | **NO gate** | Value metric --- summed across every DCBP row in scope for the fielder |

**Open question worth verifying when it comes up:** how often does
DCBP give a non-first-defender fielder a row with `out_prob > 0` on
the same play? Our queries always filter DCBP to one fielder, so that
isn't visible from the source. If a coach asks "is my SS getting
penalized on plays the LF actually fielded?", run a diagnostic query
against DCBP without the player filter to count multi-fielder events
per `(sched_id, event_id)`. We haven't done this audit yet.

## BIT casting (BLOCKING)

SQL Server throws `"Operand data type bit is invalid for sum
operator"` if you `SUM` a BIT column. Cast first.

**Known BIT columns (the ones that have bitten people):**

- `Events_View`: `pa`, `ab`, `bb`, `ibb`, `hbp`, `sf`, `sh`, `so`,
  `[1b]`, `[2b]`, `[3b]`, `hr`
- `Defense_Combined_By_Pos`: `out_made`, `competitive_play`,
  `competitive_throw`
- `Tracking_Defensive_Metrics`: `competitive_play`, `competitive_throw`
- `Pitches_Baserunner_Leads`: `runner_going`, `next_base_open`,
  `ignore_flag`
- `Events_StolenBases`: `success`

**The fix:**

```sql
SUM(CAST(ev.so AS int))           -- correct
SUM(CAST(ev.pa AS int))            -- correct
SUM(ev.so)                         -- ERROR

-- Comparison against BIT works fine:
WHERE pbl.runner_going = 1         -- correct
WHERE pbl.runner_going = 0         -- correct
```

## ignore_flag --- swing recovery (BLOCKING)

Don't filter `ignore_flag = 0` on Pitches_View. Some legitimate game
pitches have `ignore_flag = 1` (e.g. ABs vs position players
pitching). The only standard pitch filter is `pv.pitch_id > 0`.

When `ignore_flag = 1`, only TWO fields are NULL: `did_swing` and
`pitch_type`. Everything else (`plate_x`, `plate_z`, `release_speed`,
`pitch_result_id`, `hit_exit_speed`) is populated. We recover swings
from `pitch_result_id`:

```python
SWING_CODES = (7, 8, 9, 10, 12, 13, 14, 16, 18, 19, 20, 21, 22, 23, 25)
# = BIP + WHIFF + FOUL codes

# Python pattern in enrich_pitches():
_ignore_recovery = (
    (df.get("ignore_flag", pd.Series(0, index=df.index)) == 1)
    & df["did_swing"].isna()
    & df["pitch_result_id"].isin(SWING_CODES)
)
df["is_swing"] = (df["did_swing"] == 1) | _ignore_recovery
```

**SQL pattern --- everywhere you'd write `pv.did_swing = 1`:**

```sql
(pv.did_swing = 1
 OR (pv.ignore_flag = 1
     AND pv.did_swing IS NULL
     AND pv.pitch_result_id IN (7,8,9,10,12,13,14,16,18,19,20,21,22,23,25)))
```

### Two exceptions where filtering on ignore_flag IS required

1. **NetK queries.** GC2's NetK formula requires `ignore_flag = 0`.
   Apply in WHERE for standalone NetK queries, or inside CASE WHEN
   for combined queries that also compute Steal%/Loss%/FramRAA.
2. **`Pitches_Baserunner_Leads`** (PBL). PBL's `ignore_flag` is a
   DIFFERENT column with a different meaning --- it flags bad
   tracking data for lead-distance measurements. Always filter
   `bl.ignore_flag = 0` on PBL queries.

### The 5-layer fix checklist when porting to a new app

1. SQL WHERE: remove `ignore_flag = 0`, keep `pitch_id > 0`
2. SQL SELECT: add `pv.ignore_flag` as a column
3. SQL CASE WHEN: add the swing-recovery OR clause to every `did_swing = 1`
4. Python data: `enrich_pitches()` recovery, pitch_name/pitch_color
   None handling, DataFrame `did_swing == 1` filters
5. App rendering: sidebar pitch_type filter includes NULL, zone plot
   pitch_type loops include NULL, plottable None handling, pitch
   arsenal legend includes "Unknown"

## Never round until display (BLOCKING)

Carry full float precision through every aggregation, weighting,
merge, and intermediate computation. Round ONCE, at the display
layer, in the same units as the displayed value.

User direction May 5 2026: "DO NOT ROUND UNTIL THE END!!!!! THIS
SHOULD BE A RUKE!!!!!" --- five exclamation points worth of
non-negotiable.

### Why

Repeated rounding compounds error. Pre-rounding in decimal space and
then formatting in percentage space creates float-quantization
mismatches that drift values across surfaces. Documented at length in
`.claude/rules/damage-pct-cross-app-divergences.md` and
`.claude/rules/never-round-until-display.md`.

### How to apply

| Layer | Rule |
|---|---|
| **SQL** | Don't wrap aggregates in `ROUND()` in CTEs or subqueries. Return raw integer counts (`SUM(sb)`, `SUM(cs)`) or full-precision floats. `CAST(... AS DECIMAL(N, K))` mid-pipeline counts as rounding --- don't. |
| **Python aggregation** | `value = numerator / denominator` --- full float, no `round(...)`. When merging dataframes, keep both sides at full precision. Never `.round(2)` "to clean up floats." |
| **Display layer ONLY** | `f"{val * 100:.1f}%"` --- the `:.1f` does the rounding implicitly at format time. This is the canonical single-rounding point. |

### Damage% --- the canonical post-percentage round

If you MUST store a rounded display form, round in PERCENTAGE space:

```python
# Canonical (matches Barrelsville everywhere):
dmg_pct_decimal = round(damage_value_decimal * 100, 1) / 100

# WRONG — diverges by 0.1% at boundary values due to float repr:
dmg_pct_decimal = round(damage_value_decimal, 4)
```

The two diverge because `0.045500001` rounds to `0.0455` in decimal
space (formats to "4.5%") but to `0.046` in percentage space (formats
to "4.6%"). Pick one and use it everywhere; we use the post-percentage
round.

## Common pitfalls (the silent-failure traps)

### `int(x or 0)` does NOT catch NaN

`NaN` is **truthy** in Python. `int(val or 0)` passes NaN through and
`int(NaN)` raises `ValueError`. Never write `int(x or 0)`.

```python
# WRONG
val = int(row.get("pa") or 0)

# RIGHT
val = int(0 if pd.isna(row.get("pa")) else row.get("pa"))
# or
def _safe_int(x):
    return int(0 if pd.isna(x) else x)
```

### NaN in SQL IN clauses

```python
# WRONG — produces literal "nan" in the SQL
ids = ','.join(str(x) for x in df['batter_id'])

# RIGHT — filter and cast
ids = [int(x) for x in df['batter_id'].dropna()]
```

### `groupby` silently drops NaN groups

```python
# WRONG — pitches with pitch_type = NULL are silently excluded
for pt, group in df.groupby("pitch_type"):
    ...

# RIGHT — handle NULL explicitly
for pt in list(df['pitch_type'].dropna().unique()) + (
        [None] if df['pitch_type'].isna().any() else []):
    sub = df[df['pitch_type'] == pt] if pt is not None else df[df['pitch_type'].isna()]
```

### CTE alias mismatch

When a CTE JOINs Schedule_View with a different alias (`sv2`) than
the main query (`sv`), the `{level_filter}` and `{sched_filter}`
template substitutions reference `sv` --- WRONG inside the CTE.
Always build CTE-aliased versions:

```python
cte_lf = _build_level_filter(level_code, sv_alias="sv2")
cte_sf = sched_filter.replace("sv.", "sv2.")
_fmt = dict(..., cte_level_filter=cte_lf, cte_sched_filter=cte_sf)
```

### Outer/inner SELECT parity

When a query wraps a subquery, every column in the outer SELECT must
be defined in the inner SELECT. SQL Server throws `"Invalid column
name 'X'"` if it isn't. Especially dangerous in multi-query files
(e.g. `org_kpi_data.py` has parallel pitching + hitting subqueries
--- new column must go in BOTH inner subqueries).

### `pitcher_throws` vs `throws`

- `Astros.Pitches_View.pitcher_throws` --- on Pitches_View
- `Astros.Players.throws` --- on Players

NEVER `p.pitcher_throws` when joining Players. NEVER `pv.throws` on
Pitches_View. Symptom: `Invalid column name 'pitcher_throws'`.

### `did_swing` data type

- `Astros.Pitches_View.did_swing` is INT (0/1)
- `MLBAM.Pitch_fx.did_swing` is VARCHAR ('Y'/'N')

If you copy-paste a query from one schema to the other, fix the
comparison.

### Streamlit `session_state`

Once a widget key exists in session state, the `value=` / `default=`
parameters on later renders are IGNORED. To programmatically set a
widget value, you must set `st.session_state[key]` BEFORE the widget
renders.

The deferred-load pattern in `pages/2_Transition.py::_apply_pending_load`
is the canonical fix: one button click stores the desired values in a
sentinel session state key, calls `st.rerun()`, and the next run
hydrates widget keys before any widget renders.

### `@st.cache_data` underscore bug

Parameters with names starting with `_` are EXCLUDED from the cache
hash. Never use `_` prefix for params on cached functions:

```python
@st.cache_data
def get_data(_engine, season):  # _engine excluded from cache key — typically what you want
    ...

@st.cache_data
def get_data(engine, _season):  # _season excluded — DEFINITELY NOT what you want
    ...
```

### Lazy queries

Never write `WHERE first_name LIKE '%John%' AND last_name LIKE '%Smith%'`
to look up a player. Always look up the `groundcontrol_id` from
`pd-goals/data/slack_channels.csv` (which has every player we report
on) and use the concrete ID.

### Schema prefixes

Always full-qualify cross-schema tables: `MLB_eBis.PP_MASTER`,
`Guts.woba_lwts`, `Guts.hit_specs_ratios`. Default schema is `dbo`
--- anything outside the default needs the prefix.

## Where to look next

- **Chapter 11** for the cross-app patterns that catch silent drift
  (three-surface parity, multi-level rollup, etc.).
- **Chapter 14** for the fix recipes (add a metric, debug a divergence).
- `.claude/rules/pitfalls.md` --- the canonical pitfalls reference.
- `.claude/rules/bat-speed-canonical.md` --- the full bat-speed playbook.
- `.claude/rules/never-round-until-display.md` --- the rounding rule.
- `.claude/rules/damage-pct-cross-app-divergences.md` --- the rounding
  bug class.
- `.claude/rules/fielding.md` --- the 6-term Tier 1 gate.
