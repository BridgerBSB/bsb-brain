# Fielding Affiliate Trackers — Complete Specification

> **Purpose:** Architecture spec for revamping IF, OF, and Catching affiliate trackers to exactly mirror the Arm Farm pitcher tracker pattern.
> **Source:** GC2 production SQL (Feb 28, 2026), Arm Farm `tracker_data.py` + `3_Affiliate_Tracker.py`, PD Goals OF metrics.
> **Generated:** 2026-02-28

---

## 1. Architecture Requirements (Arm Farm Carbon Copy)

### What MUST match the Arm Farm pitcher tracker exactly:

| Feature | Arm Farm Pattern | Notes |
|---------|-----------------|-------|
| **Metric config** | `LEADERBOARD_COLS: List[Tuple[str, str, str, Optional[bool]]]` | `(key, label, format, higher_is_better)`. Already matches. |
| **Tab structure** | 3 tabs: Leaderboard (HOU + vs Level), Org Rankings, Trends (MoM + YoY) | Already matches via `render_tracker_tab()`. |
| **Caching** | `@st.cache_data(ttl=21600)` per-year per-sched_types_tuple | Currently using session_state. **CHANGE to `@st.cache_data`** for Arm Farm parity. |
| **Background warmup** | ThreadPoolExecutor fires org/monthly/yearly loads after leaderboard | Add this. |
| **Loading animation** | Pixel character CSS + progress bar (40s leaderboard, 30s org/trends) | Already in `tracker_page.py`. |
| **Qualified mask (HOU)** | `n_volume >= threshold AND pos != "-"` (pos check = on PP_MASTER roster) | Implement for C/OF/IF. |
| **Qualified mask (vs Level)** | `n_volume >= threshold` (no pos check) | |
| **HOU percentiles** | `pd.rank(pct=True)` within HOU qualified pool | Already matches. |
| **vs Level percentiles** | `bisect` against all-orgs qualified pool | Already in `tracker_page.py`. |
| **Multi-level combine** | Volume-weighted rates, sum for volumes, highest level assigned | Already matches. |
| **Org rankings** | Separate SQL queries GROUP BY org, then `aggregate_org_across_levels()` | Implement per domain. |
| **Trend charts** | Level-split MoM traces, combined YoY, Player + Org sub-tabs | Already in `tracker_page.py`. |
| **NaN gap fix** | `dropna(subset=[metric])` before each `go.Scatter` trace | Already applied. |
| **Display modes** | Stat / Percentile / Rank radio | Already in `tracker_page.py`. |
| **Season default** | `get_latest_season_with_games()` — current year if month >= April, else prior | Already matches. |
| **Sched filter** | `_build_sched_filter()` with pseudo types `_WIN`/`_BBC` | Already matches. |
| **MIN_QUERY_PITCHES** | `1` (get ALL players, filter in Python) | Verify each module uses this. |
| **PCTILE_THRESHOLD** | Module-specific (see §2) | |
| **Sidebar controls** | Seasons, Game Type, Levels, Info Columns, Metric Columns, Display Mode, Highlight HOU | In `render_tracker_tab()`. |
| **IP display** | N/A for fielding | |

### What the current code does WRONG (must fix):

| Bug | Module | Fix |
|-----|--------|-----|
| References `outs_above_average` column | OF | Column doesn't exist. Compute: `SUM(out_made - out_prob)` from `Defense_Combined_By_Pos` |
| `reaction_radius` direction wrong | OF | Should be `higher_is_better=False` (lower radius = better reaction). Currently `True`. |
| Uses `exchange` instead of `exchange_dp` | IF | GC2 IF uses `exchange_dp` (double-play exchange). Both columns exist in `Tracking_Defensive_Metrics`. |
| Arm strength range | IF, OF | Our code uses 60-108 for IF/OF, 60-94 for Catcher. |
| Missing PAA/EO calibration | OF, IF | GC2 computes calibrated PAA via `PAA_EO_Position_Calibration` table. |
| Missing `reaction_accuracy_radius` | OF, IF | GC2 includes this metric for both IF and OF. **FIXED.** |
| Uses AVG(arm_strength) for catching | C | GC2 uses PERCENTILE_CONT(0.99) for arm strength. |
| Catching percentile threshold too low | C | Change to 1750 (season) / 500 (month). |
| No `@st.cache_data` | All | Session_state caching doesn't match Arm Farm. Switch to `@st.cache_data(ttl=21600)`. |

---

## 2. Per-Domain Metric Specifications

### 2A. OUTFIELD — LEADERBOARD_COLS

**8 Main Metrics** (from pd-goals, confirmed against GC2):

| # | key | Label | Format | higher_is_better | GC2 Agg | GC2 Filter | GC2 Cap/Range |
|---|-----|-------|--------|-----------------|---------|------------|---------------|
| 1 | `top_speed` | TopSpd | f1 | True | PERCENTILE_CONT(0.95) | `competitive_play=1` | `<= 34` |
| 2 | `accel_up` | AccelCU | f1 | True | PERCENTILE_CONT(0.75) | `competitive_play=1` | — |
| 3 | `accel_down` | AccelCD | f1 | True | PERCENTILE_CONT(0.75) | `competitive_play=1` | — |
| 4 | `reaction_time` | React | f3 | False | PERCENTILE_CONT(0.25) | `competitive_play=1` | — |
| 5 | `useful_reaction` | UseReact | f3 | False | PERCENTILE_CONT(0.25) | `competitive_play=1` | — |
| 6 | `reaction_radius` | ReactRad | f1 | **False** | PERCENTILE_CONT(0.25) | `competitive_play=1` | — |
| 7 | `arm_strength` | Arm | f1 | True | PERCENTILE_CONT(0.99) | `competitive_throw=1` | 60–100 |
| 8 | `exchange` | Exch | f2 | False | PERCENTILE_CONT(0.10) | `competitive_throw=1` | `>= 0.4, arm >= 60` |

**Supplementary Metrics** (from GC2):

| # | key | Label | Format | higher_is_better | GC2 Agg | Notes |
|---|-----|-------|--------|-----------------|---------|-------|
| 9 | `reaction_accuracy_radius` | ReactAccRad | f1 | False | PERCENTILE_CONT(0.25) | `competitive_play=1` |
| 10 | `oaa` | OAA | f1 | True | `SUM(out_made - out_prob)` | From Defense_Combined_By_Pos |
| 11 | `comp_plays` | Comp Plays | int | None | COUNT | Volume column |
| 12 | `comp_throws` | Comp Throws | int | None | `SUM(competitive_throw)` | Volume column |
| 13 | `paa_cal` | PAA Cal | f2 | True | Calibrated formula | See §3 |
| 14 | `raa` | RAA | f1 | True | `paa_cal * AVG(drv)` | Run value |
| 15 | `games` | G | int | None | `COUNT(DISTINCT sched_id)` | From Players_Games |

**Volume/Info columns:** player_name, org, level, age, pos, games, comp_plays

### 2B. INFIELD — LEADERBOARD_COLS

Same as OF except these 3 differences:

| Difference | OF | IF |
|-----------|-----|-----|
| `pos_id` filter | `(7, 8, 9)` | `(3, 4, 5, 6)` |
| `exchange` column | `exchange` | `exchange_dp` |
| Arm strength range | 60–100 | 60–108 |

IF also includes `reaction_accuracy_radius` (same as OF — confirmed in GC2 production SQL).
Everything else identical — same tracking metrics, same percentile levels, same filters.

### 2C. CATCHING — LEADERBOARD_COLS

Catching is a completely different domain. Organized by skill area:

**Throwing Metrics (#NTILE — percentile-aggregated):**

| # | key | Label | Format | higher_is_better | GC2 Agg | GC2 Filter | GC2 Range |
|---|-----|-------|--------|-----------------|---------|------------|-----------|
| 1 | `arm_strength` | Arm | f1 | True | PERCENTILE_CONT(0.99) | `competitive_throw=1, pos_id=2` | 60–108 |
| 2 | `exchange` | Exch | f2 | False | PERCENTILE_CONT(0.10) | `competitive_throw=1, pos_id=2` | `>= 0.4` |
| 3 | `pop_time_2b` | Pop 2B | f2 | False | PERCENTILE_CONT(0.01) | SBA event to 2B | 1.70–2.35 |
| 4 | `pop_time_3b` | Pop 3B | f2 | False | PERCENTILE_CONT(0.01) | SBA event to 3B | 1.40–1.85 |
| 5 | `aug_pop_time` | AugPop | f2 | False | PERCENTILE_CONT(0.01) | From SBAMetrics | — |

**Throwing Metrics (#AGG — sum/avg aggregated):**

| # | key | Label | Format | higher_is_better | GC2 Formula | Notes |
|---|-----|-------|--------|-----------------|-------------|-------|
| 6 | `comp_throws` | Comp Throws | int | None | `SUM(competitive_throw)` | Volume |
| 7 | `aug_pop_accuracy_penalty` | AugPop Pen | f2 | False | `AVG(accuracy_penalty)` | From SBAMetrics |
| 8 | `aug_pop_bounce_rate` | Bounce% | pct1 | False | `AVG(bounce_flag)` | From SBAMetrics |
| 9 | `aug_pop_horz_miss` | Horz Miss | f2 | False | Rate: `SUM(CASE throw_x > 1.5)/COUNT` | From ball_trajectories |
| 10 | `aug_pop_vert_miss` | Vert Miss | f2 | False | Complex polynomial | From ball_trajectories |

**Framing Metrics (YTD — from CatcherDefense_Framing):**

| # | key | Label | Format | higher_is_better | Source | Notes |
|---|-----|-------|--------|-----------------|--------|-------|
| 11 | `adj_net_strikes` | AdjNSP | f3 | True | `adj_net_strikes_per_pitch` | From CatcherDefense_Framing |
| 12 | `framing_raa` | FramRAA | f1 | True | `raa` | From CatcherDefense_Framing |
| 13 | `framing_raa_650` | FramRAA650 | f1 | True | `raa650` | From CatcherDefense_Framing |
| 14 | `netk_per_pitch` | NetK/P | f3 | True | `SUM(csc) / COUNT` | CSC 0.05–0.95, called strike only |
| 15 | `generic_pitch_count` | Pitches | int | None | From CatcherDefense_Framing | `qualifying_pitches` |

**Blocking Metrics (from CatcherDefense_Blocking):**

| # | key | Label | Format | higher_is_better | Source | Notes |
|---|-----|-------|--------|-----------------|--------|-------|
| 16 | `blocking_raa` | BlockRAA | f1 | True | `SUM(r)` | From CatcherDefense_Blocking |
| 17 | `blocking_raa_650` | BlockRAA650 | f1 | True | `7560 * SUM(r) / SUM(np)` | Prorated to 7560 pitches |
| 18 | `passed_pitches` | PP | int | False | `SUM(passed_pitches)` | Lower = better |
| 19 | `x_passed_pitches` | xPP | f1 | False | `SUM(x_passed_pitches)` | Lower = better |

**SBA Metrics:**

| # | key | Label | Format | higher_is_better | GC2 Formula | Notes |
|---|-----|-------|--------|-----------------|-------------|-------|
| 20 | `sb` | SB | int | None | `SUM(ev.sb)` | Info column |
| 21 | `cs` | CS | int | None | `SUM(ev.cs)` | Info column |
| 22 | `cs_pct` | CS% | pct1 | True | `cs / (sb + cs)` | Derived |

**Volume/Info columns:** player_name, org, level, age, games, comp_throws, generic_pitch_count

**Thresholds:**
- Season qualified: 1750 pitches
- Monthly qualified: 500 pitches

---

## 3. GC2 SQL Formulas — Critical Reference

### PAA/EO Calibration (IF + OF)

```sql
-- Source table: Astros.PAA_EO_Position_Calibration
-- Columns: pos_id, paaeo_offset, eo_scalar

-- Calibrated PAA:
(SUM(dcbp.paa) / NULLIF(SUM(dcbp.out_prob), 0) - AVG(paaeo.paaeo_offset))
  * SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar)  AS paa_calibrated

-- RAA (run-adjusted):
((SUM(dcbp.paa) / NULLIF(SUM(dcbp.out_prob), 0) - AVG(paaeo.paaeo_offset))
  * SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar)) * AVG(dcbp.drv)  AS raa

-- JOIN pattern:
LEFT JOIN Astros.PAA_EO_Position_Calibration paaeo
  ON dcbp.pos_id = paaeo.pos_id
```

### OAA (IF + OF) — NOT a DB column

```sql
-- Computed, NOT stored:
SUM(dcbp.out_made - dcbp.out_prob) AS oaa

-- Defense_Combined_By_Pos columns used:
-- sched_id, event_id, pos_id, groundcontrol_id, out_prob, out_made, paa,
-- positional, competitive_play, competitive_throw, drv, pitch_id
```

### Pop Time (Catching)

```sql
-- Pop Time to 2B:
-- event_result_id IN (4, 42, 46, 47) = SB/CS events to 2B
-- play_code LIKE '%CS2%' OR '%SB2%'
PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY pop_time ASC)
  OVER (PARTITION BY groundcontrol_id)
WHERE pop_time BETWEEN 1.70 AND 2.35

-- Pop Time to 3B:
-- event_result_id IN (5, 43, 46, 47) = SB/CS events to 3B
-- play_code LIKE '%CS3%' OR '%SB3%'
PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY pop_time ASC)
  OVER (PARTITION BY groundcontrol_id)
WHERE pop_time BETWEEN 1.40 AND 1.85
```

### AugPop Vertical Miss (Catching — complex polynomial)

```sql
-- From groundcontroltracking.tracking.ball_trajectories
-- Uses polynomial coefficients to compute throw height at 2B bag
CASE WHEN (bt.poly_coeff_a * POWER(127.28, 2) + bt.poly_coeff_b * 127.28 + bt.poly_coeff_c) > 5 THEN 1 ELSE 0 END
-- 127.28 = distance to 2B in feet
-- > 5 feet = vertical miss
-- Aggregated as rate: SUM(vert_miss) / COUNT
```

### AugPop Horizontal Miss (Catching)

```sql
-- From groundcontroltracking.tracking.ball_trajectories
-- throw_x displacement at bag
CASE WHEN ABS(bt.throw_x) > 1.5 THEN 1 ELSE 0 END
-- > 1.5 feet from center = horizontal miss
-- Aggregated as rate: SUM(horz_miss) / COUNT
```

### NetK Per Pitch (Catching — Framing)

```sql
-- From Pitches_View, catcher's perspective
SUM(CASE WHEN pv.pitch_result_id IN (6, 3, 24, 30, 31) THEN pv.csc ELSE 0 END)
  / NULLIF(COUNT(*), 0)
WHERE pv.csc BETWEEN 0.05 AND 0.95  -- edge zone only
  AND pv.did_swing = 0               -- takes only
```

### Blocking RAA 650 (Catching)

```sql
-- From CatcherDefense_Blocking (year-level aggregated table)
7560.0 * SUM(r) / NULLIF(SUM(np), 0) AS blocking_raa_650
-- 7560 = standard full-season pitch count denominator
```

### Org Mapping (all defensive trackers)

```sql
-- Fielding team = team in the field (defensive side)
JOIN Astros.Events_View ev ON tdm.sched_id = ev.sched_id AND tdm.event_id = ev.event_id
JOIN mlbam.teams mt
  ON mt.team_id = ev.fielding_team_id
  AND mt.season = sv.year
SELECT UPPER(mt.org_abbrev) AS org
```

### Events_View as Hub (GC2 IF/OF pattern)

```sql
FROM Astros.Events_View ev
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
LEFT JOIN Astros.Players_Games pg
  ON ev.sched_id = pg.sched_id AND ev.fielder_{N}_id = pg.groundcontrol_id
LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
  ON ev.sched_id = dcbp.sched_id AND ev.event_id = dcbp.event_id
  AND dcbp.pos_id IN ({pos_ids})
LEFT JOIN Astros.PAA_EO_Position_Calibration paaeo
  ON dcbp.pos_id = paaeo.pos_id
LEFT JOIN groundcontroltracking.tracking.Tracking_Defensive_Metrics tdm
  ON dcbp.sched_id = tdm.sched_id AND dcbp.event_id = tdm.event_id
  AND dcbp.groundcontrol_id = tdm.groundcontrol_id
WHERE sv.level_code = :level AND YEAR(sv.sched_date) = :season
  AND sv.sched_type IN (:sched_types)
```

---

## 4. Key Tables — Column Reference

### Astros.Defense_Combined_By_Pos
```
sched_id, event_id, pos_id, groundcontrol_id,
out_prob, out_made, paa, positional,
competitive_play, competitive_throw, drv, pitch_id
```
**NO `outs_above_average` column.** OAA = `SUM(out_made - out_prob)`.

### groundcontroltracking.tracking.Tracking_Defensive_Metrics
```
sched_id, event_id, groundcontrol_id, pos_id,
top_speed, acceleration_chest_up, acceleration_chest_down,
reaction_4mph, useful_reaction_4mph, reaction_radius, reaction_accuracy_radius,
arm_strength, exchange, exchange_dp,
competitive_play, competitive_throw
```
21 columns total. Both `exchange` AND `exchange_dp` exist. OF uses `exchange`, IF uses `exchange_dp`.

### Astros.PAA_EO_Position_Calibration
```
pos_id, paaeo_offset, eo_scalar
```
Small lookup table. One row per position.

### Astros.CatcherDefense_Framing
```
year, groundcontrol_id, pos, qualifying_pitches,
adj_net_strikes_per_pitch, raa, raa650
```

### Astros.CatcherDefense_Blocking
```
year, groundcontrol_id, pos, r, np
```

### groundcontroltracking.tracking.ball_trajectories
```
sched_id, event_id, groundcontrol_id,
poly_coeff_a, poly_coeff_b, poly_coeff_c,
throw_x, ...
```

### SBAMetrics (via Events_View or Tracking)
```
aug_pop, accuracy_penalty, bounce_flag
```

---

## 5. Architecture: Shared IF/OF Data Module

Since IF and OF are 95% identical, use ONE parameterized data module:

```python
# fielding_tracker_data.py

_DOMAIN_CONFIGS = {
    "OF": {
        "pos_ids": (7, 8, 9),
        "pos_map": {7: "LF", 8: "CF", 9: "RF"},
        "arm_range": (60, 100),
        "exchange_col": "exchange",
        "has_reaction_accuracy_radius": True,
    },
    "IF": {
        "pos_ids": (3, 4, 5, 6),
        "pos_map": {3: "1B", 4: "2B", 5: "3B", 6: "SS"},
        "arm_range": (60, 108),
        "exchange_col": "exchange_dp",
        "has_reaction_accuracy_radius": False,
    },
}

def get_fielder_leaderboard(domain: str, level_codes, season, ...):
    cfg = _DOMAIN_CONFIGS[domain]
    # Same queries with cfg["pos_ids"], cfg["exchange_col"], etc.
```

Catching stays its own module — completely different metrics and tables.

---

## 6. Percentile Aggregation Rules (GC2 Source of Truth)

| Metric | Percentile | Direction | Filter | Cap/Range |
|--------|-----------|-----------|--------|-----------|
| **OF/IF Shared** | | | | |
| TopSpd | p95 | Higher=better | `competitive_play=1` | `<= 34` |
| AccelCU | p75 | Higher=better | `competitive_play=1` | — |
| AccelCD | p75 | Higher=better | `competitive_play=1` | — |
| React | p25 | Lower=better | `competitive_play=1` | — |
| UseReact | p25 | Lower=better | `competitive_play=1` | — |
| ReactRad | p25 | Lower=better | `competitive_play=1` | — |
| Arm | p99 | Higher=better | `competitive_throw=1` | 60-108 (IF/OF), 60-94 (Catcher) |
| Exchange | p10 | Lower=better | `competitive_throw=1, >= 0.4` | OF: `exchange`, IF: `exchange_dp` |
| **OF Only** | | | | |
| ReactAccRad | p25 | Lower=better | `competitive_play=1` | — |
| **Catching** | | | | |
| ArmC | p99 | Higher=better | `competitive_throw=1, pos_id=2` | 60-94 |
| ExchC | p10 | Lower=better | `competitive_throw=1, pos_id=2, >= 0.4` | — |
| Pop2B | p01 | Lower=better | SBA to 2B events | 1.70-2.35 |
| Pop3B | p01 | Lower=better | SBA to 3B events | 1.40-1.85 |
| AugPop | p01 | Lower=better | SBAMetrics | — |

**CRITICAL:** These are PERCENTILE_CONT aggregations computed PER PLAYER from their raw play-level data. This is what the IF module does correctly (raw data → Python percentile agg). The OF module currently does AVG/MAX in SQL — **must be changed to match**.

### Implementation Pattern (from IF — the gold standard approach)

```python
def _aggregate_tracking_metrics(raw_df: pd.DataFrame, config: dict) -> pd.DataFrame:
    """Per-player percentile aggregation from raw play-level data."""
    result = []
    for fid, group in raw_df.groupby("fielder_id"):
        comp = group[group["competitive_play"] == 1]
        throws = group[group["competitive_throw"] == 1]

        row = {"fielder_id": fid, "comp_plays": len(comp)}
        if len(comp) > 0:
            row["top_speed"] = np.percentile(comp["top_speed"].dropna().clip(upper=34), 95)
            row["accel_up"] = np.percentile(comp["acceleration_chest_up"].dropna(), 75)
            row["accel_down"] = np.percentile(comp["acceleration_chest_down"].dropna(), 75)
            row["reaction_time"] = np.percentile(comp["reaction_4mph"].dropna(), 25)
            row["useful_reaction"] = np.percentile(comp["useful_reaction_4mph"].dropna(), 25)
            row["reaction_radius"] = np.percentile(comp["reaction_radius"].dropna(), 25)

        if len(throws) > 0:
            arm_data = throws["arm_strength"].dropna()
            arm_data = arm_data[(arm_data >= config["arm_range"][0]) & (arm_data <= config["arm_range"][1])]
            row["arm_strength"] = np.percentile(arm_data, 99) if len(arm_data) > 0 else np.nan

            exch_col = config["exchange_col"]
            exch_data = throws[exch_col].dropna()
            exch_data = exch_data[exch_data >= 0.4]
            row["exchange"] = np.percentile(exch_data, 10) if len(exch_data) > 0 else np.nan

        result.append(row)
    return pd.DataFrame(result)
```

---

## 7. Multi-Level Combine — Weighted Keys

### OF/IF weighted_keys:
```python
_COMP_PLAY_WEIGHTED_KEYS = {
    "top_speed", "accel_up", "accel_down",
    "reaction_time", "useful_reaction", "reaction_radius",
    "reaction_accuracy_radius",  # OF only
}
_THROW_WEIGHTED_KEYS = {"arm_strength", "exchange"}
# OAA, comp_plays, comp_throws, games = SUM
# paa_cal, raa = SUM
```

For `_combine_multi_level`: comp_play-weighted for tracking metrics, throw-count-weighted for arm/exchange, SUM for volumes.

### Catching weighted_keys:
```python
# Pitch-weighted: netk_per_pitch, adj_net_strikes, blocking metrics
# Throw-weighted: arm_strength, exchange, pop times
# SUM: sb, cs, comp_throws, passed_pitches, x_passed_pitches
# DERIVE: cs_pct (from summed sb + cs)
# RAA650 = re-derive from summed r, np
```

---

## 8. PAA_EO_Position_Calibration — Test Query

Run this on the work laptop to verify access:

```sql
-- Test 1: Does the table exist and what's in it?
SELECT * FROM Astros.PAA_EO_Position_Calibration ORDER BY pos_id;

-- Test 2: Compute calibrated PAA for a sample player at AA
SELECT TOP 5
    dcbp.groundcontrol_id,
    p.first_name + ' ' + p.last_name AS player_name,
    COUNT(*) AS events,
    SUM(dcbp.out_prob) AS total_out_prob,
    SUM(dcbp.out_made) AS total_outs_made,
    SUM(dcbp.out_made - dcbp.out_prob) AS oaa,
    SUM(dcbp.paa) AS raw_paa,
    AVG(paaeo.paaeo_offset) AS paaeo_offset,
    AVG(paaeo.eo_scalar) AS eo_scalar,
    (SUM(dcbp.paa) / NULLIF(SUM(dcbp.out_prob), 0) - AVG(paaeo.paaeo_offset))
        * SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar) AS paa_calibrated,
    ((SUM(dcbp.paa) / NULLIF(SUM(dcbp.out_prob), 0) - AVG(paaeo.paaeo_offset))
        * SUM(dcbp.out_prob) * AVG(paaeo.eo_scalar)) * AVG(dcbp.drv) AS raa
FROM Astros.Defense_Combined_By_Pos dcbp
JOIN Astros.Schedule_View sv ON dcbp.sched_id = sv.sched_id
LEFT JOIN Astros.PAA_EO_Position_Calibration paaeo ON dcbp.pos_id = paaeo.pos_id
LEFT JOIN Astros.Players p ON dcbp.groundcontrol_id = p.groundcontrol_id
WHERE sv.level_code = 'aax'
  AND YEAR(sv.sched_date) = 2025
  AND sv.sched_type = 'R'
  AND dcbp.pos_id IN (7, 8, 9)  -- OF positions
GROUP BY dcbp.groundcontrol_id, p.first_name, p.last_name
HAVING COUNT(*) >= 50
ORDER BY paa_calibrated DESC;
```

---

## 9. New DB Tables to Verify Access

Run these on work laptop to confirm access:

```sql
-- CatcherDefense_Framing
SELECT TOP 5 * FROM Astros.CatcherDefense_Framing WHERE year = 2025;

-- CatcherDefense_Blocking
SELECT TOP 5 * FROM Astros.CatcherDefense_Blocking WHERE year = 2025;

-- ball_trajectories
SELECT TOP 5 * FROM groundcontroltracking.tracking.ball_trajectories;

-- SBAMetrics (verify table name and schema)
SELECT TOP 1 * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE '%SBA%';

-- Tracking_Defensive_Metrics (confirm all columns)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'tracking' AND TABLE_NAME = 'Tracking_Defensive_Metrics'
ORDER BY ORDINAL_POSITION;
```

---

## 10. File Plan for Implementation

### Files to CREATE:
- `src/fielding_tracker_data.py` — Shared IF/OF data module (replaces both `of_tracker_data.py` and `if_tracker_data.py`)

### Files to REWRITE:
- `src/catching_tracker_data.py` — Add framing (CatcherDefense_Framing), blocking (CatcherDefense_Blocking), fix arm percentile, add pop time, add AugPop metrics, update thresholds

### Files to DELETE:
- `src/of_tracker_data.py` — Replaced by `fielding_tracker_data.py`
- `src/if_tracker_data.py` — Replaced by `fielding_tracker_data.py`
- `src/of_tracker_page.py` — Replaced by direct `render_tracker_tab()` call
- `src/if_tracker_page.py` — Replaced by direct `render_tracker_tab()` call
- `src/catching_tracker_page.py` — Replaced by direct `render_tracker_tab()` call

### Files to UPDATE:
- `pages/2_Outfield.py` — Import from `fielding_tracker_data` with domain="OF"
- `pages/3_Infield.py` — Import from `fielding_tracker_data` with domain="IF"
- `pages/4_Catching.py` — Import from updated `catching_tracker_data`
- `src/tracker_page.py` — Switch from session_state to `@st.cache_data(ttl=21600)`, add background warmup

### Files to NOT TOUCH:
- `src/br_tracker_data.py` — Working, different domain
- `src/br_tracker_page.py` — Working
- `pages/1_Baserunning.py` — Working
- `src/br_data.py`, `src/br_report.py`, `src/br_percentiles.py` — Postgame BR (working)
- `Intangibles.py` — Landing page (working)
