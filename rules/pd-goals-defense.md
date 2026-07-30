---
paths:
  - "pd-goals/**"
---
# PD Goals — Defense Stats Architecture

> **Extracted from `pd-goals.md` 2026-05-19** to keep the parent rule under
> the article-recommended discoverability threshold. See parent for
> `## Defense Stats — Tier Architecture` pointer. Auto-loaded with the parent on any
> Python edit in `pd-goals/`.

---

## Defense Stats — Tier Architecture (matches intangibles)

### Tier 1 — KPI Gate (6-term OR, Apr 16 2026)
`DCBP.out_made + DCBP.competitive_play + DCBP.competitive_throw + TDM.competitive_play + TDM.competitive_throw + (arm >= floor) > 0`

Same 6-term gate as `rules/fielding.md`. `stats.py::_filter_tier1_plays()` applies
this in Python over the DataFrame returned by the base query.

All tracking metrics aggregate from Tier 1 rows:
- **React, UseReact, ReactRad, ReactAccRad:** P25 (lower = faster = better)
- **TopSpd:** P95, capped at 34
- **AccelCU, AccelCD:** P75
- **Arm:** P99, filtered to arm >= floor AND <= 108 (IF floor=70, OF floor=75)
- **Exchange:** P10, filtered to >= 0.4

### Tier 3 — Difficulty Attribution
`first_defender_id == fielder_id AND out_prob IS NOT NULL`
Used for routine play conversion (out_prob > 0.90).

### No Gate — Value Metrics
PAA/EO uses ALL DCBP rows, no filtering. Matches GC2.

## Defense Base Query — FROM Tracking Tables, Not Events_View (Apr 20 2026)

**BLOCKING: `get_defense_stats()` base query in `pd-goals/src/stats.py` starts FROM a CTE that UNIONs DCBP + TDM keys for the player. Events_View is LEFT JOINed for context only.**

### Two-part bug history (Forrester / gc_id 1302809 — SS @ A Fayetteville)

Forrester had a goal `"Increase Arm to 85mph in IF"`. He had 3 TDM arm throws >= 70
mph in-window (pos 6 @ 83.49, pos 4 @ 73.46, pos 4 @ 71.54). The bar kept coming
back blank. Two independent structural bugs in the defense query had to be fixed
in sequence:

**Bug 1 — `pg.pos_id = tdm.pos_id` in the JOIN chain (commit `5454970`).** The
original query JOINed `Players_Games pg` for per-game position, then required
`pg.pos_id = tdm.pos_id`. When pg listed him at SS but he made a throw from 2B
that day, the TDM row for 2B was dropped because there was no pg row with
`pos_id = 4` to match it.

**Bug 2 — FROM Events_View dropped non-PA tracking events (commit `0e0e44d`).**
The first fix switched to `INNER JOIN (DISTINCT pg.sched_id)` for game-scope and
`COALESCE(dcbp.pos_id, tdm.pos_id)` for position filtering. But `FROM Events_View`
still dropped any DCBP/TDM event whose `event_id` didn't match a PA
(pickoffs, non-PA tracking events). Forrester's throws were still zeroed out.

### Final architecture (current)

```sql
WITH tracking_events AS (
    -- UNION of DCBP + TDM keys for THIS player, no position filter yet
    SELECT sched_id, event_id, pos_id
    FROM Astros.Defense_Combined_By_Pos
    WHERE groundcontrol_id = :gc_id
    UNION
    SELECT sched_id, event_id, pos_id
    FROM Astros.Tracking_Defensive_Metrics
    WHERE groundcontrol_id = :gc_id
),
filtered_events AS (
    SELECT sched_id, event_id, pos_id
    FROM tracking_events
    WHERE pos_id IN (:pos_ids)           -- position override applied here
)
SELECT te.sched_id, te.event_id, te.pos_id,
       ev.first_defender_id,
       :gc_id AS fielder_id,
       dcbp.out_prob, dcbp.out_made, dcbp.paa, dcbp.competitive_play, ...,
       tdm.top_speed, tdm.reaction_time, tdm.arm_strength, tdm.exchange, ...,
       paaeo.paaeo_offset, paaeo.eo_scalar
FROM filtered_events te
JOIN Astros.Schedule_View sv ON te.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View ev
    ON te.sched_id = ev.sched_id AND te.event_id = ev.event_id
LEFT JOIN Astros.Defense_Combined_By_Pos dcbp
    ON te.sched_id = dcbp.sched_id AND te.event_id = dcbp.event_id
    AND te.pos_id = dcbp.pos_id AND dcbp.groundcontrol_id = :gc_id
LEFT JOIN Astros.Tracking_Defensive_Metrics tdm
    ON te.sched_id = tdm.sched_id AND te.event_id = tdm.event_id
    AND te.pos_id = tdm.pos_id AND tdm.groundcontrol_id = :gc_id
LEFT JOIN Guts.PAA_EO_Position_Calibration paaeo
    ON paaeo.pos_id = dcbp.pos_id AND paaeo.positional = dcbp.positional
    AND paaeo.season = sv.year
WHERE sv.sched_type = 'R' AND sv.level_code NOT IN (junk)
  AND sched_date BETWEEN :start AND :end
```

### BLOCKING RULES for future edits

1. **Never go back to `FROM Astros.Events_View`** as the defense base. Pickoffs,
   timeout events, and other TDM/DCBP rows without matching PA event_ids silently
   drop. Always start from the `tracking_events` CTE.
2. **Never re-introduce `pg.pos_id = {dcbp,tdm}.pos_id` in the JOIN chain.** Position
   filtering happens INSIDE `filtered_events` via `pos_id IN (:pos_ids)`. Position
   mobility mid-game is real (utility IF / OF corners rotating).
3. **`Players_Games` is gone from this query.** If you re-add it for anything,
   only use it in a game-scope subquery (`SELECT DISTINCT sched_id`), never as a
   row-level JOIN that filters tracking data.
4. **Apply the 6-term Tier 1 gate in Python** (`_filter_tier1_plays`) over the
   returned DataFrame. Never pre-filter in SQL — Tier 1 needs all columns present
   to evaluate the OR.
5. **Intangibles `fielding_base.py` has the same class of bug potential.** If a
   user reports an affiliate tracker missing a play that clearly exists in TDM,
   suspect the same `pg.pos_id` coupling.

## Position Override — Goal Text Drives Defense Routing — BLOCKING

When goal text references a specific position (e.g. "at 1B", "in IF"), that
position overrides the default for defense stats. **When no position keyword
is in the goal text, defense MUST scope to `'ALL'` — NEVER fall back to the
player's roster `position_category`.**

### The canonical formula (single source of truth)

```python
# fetch_player_stats (1_PD_Goals.py:578) — the bar-chart fetch:
def_cat = defense_pos_override or 'ALL'
```

That's it. **EVERY defense data fetch in this app MUST use this rule.**
- Goal-text position keyword → specific position (`'INF'`, `'OF'`, `'1B'`, etc.)
- No keyword → `'ALL'` (every position 3-9, captures every play the player has logged)

**NEVER** write `defense_pos_override or roster_pos_cat`. Roster is stale
(players get promoted, demoted, switched). The 'ALL' fallback is intentional
— it lets us capture every play regardless of where the player has been
logged on the roster.

### Parser

`_extract_position_override()` detects:
- "at 1B/2B/3B/SS", "in IF", "infield spots" → `'INF'`
- "at CF/LF/RF", "in OF", "in outfield" → `'OF'`
- "at 1B", "at 2B", "at 3B", "at SS", "at CF", "at LF", "at RF" → that specific position
- Returns `None` if no position in text → caller MUST default to `'ALL'`

### Why (Brutcher bug, Apr 2026)

Brutcher is `OF` roster but goal is "defender at 1B (PAA/EO above 0)". With
the override (`'INF'`), defense stats query INF pos_ids and get his 1B PAA/EO.

### Why (Powell bug, Apr 25 2026 — the rolling chart regression)

Caden Powell (gc_id 283965) is rostered SS at A Fayetteville but has been
playing mostly OF. His goal "Have a positive PAA/EO (Goal: above 0)" has NO
position keyword. The bar chart correctly used `'ALL'` fallback and showed
PAA/EO = 0.004 (capturing his OF + IF plays). The rolling chart had been
written with `position_override or pos_cat` (roster fallback), which scoped
to INF only and dropped every OF play — chart came back blank.

Fixed in commit `5a85752` across both surfaces (app page + PDF report).

### BLOCKING checklist for every defense fetch

ANY function that calls `get_defense_stats(...)` or `_fielding_per_play(...)`
or `get_per_game_data(...)` for a fielding metric MUST resolve position as:

```python
_eff_pos = goal.get('position_override') or 'ALL'   # ← 'ALL', NEVER pos_cat
get_defense_stats(player_id, _eff_pos, ...)
```

Three live surfaces that follow the rule:
| Surface | File | Line | Status |
|---|---|---|---|
| Bar chart fetch | `1_PD_Goals.py::fetch_player_stats` | 578 | canonical (always correct) |
| Rolling chart fetch (app) | `1_PD_Goals.py::_fetch_one` | ~1410 | fixed `5a85752` |
| Rolling chart fetch (PDF) | `src/report.py` | ~1144 | fixed `5a85752` |

When you add a new surface that fetches defense data, mirror this rule.
Test: pull a player rostered at one position (e.g. SS) who has been playing
elsewhere (e.g. OF), and confirm the new surface returns the same value as
the bar chart. If it returns less or empty, the position scope is too narrow.

## Goal-Text Position Keyword Routing in Parser (Apr 20 2026)

`detect_goal_type()` in `goal_parser.py` MUST call `_extract_position_override()`
FIRST, before the pitching/hitting/catching/fielding indicator keyword checks.

**Why (Forrester Arm goal):** `"Increase Arm to 85mph in IF"` was falling through
detect_goal_type. None of the indicator keyword lists matched (`'arm'` alone
isn't an indicator — only `'arm strength'` is). So the goal defaulted to HITTING.
`extract_metric(text, HITTING)` couldn't find `"Arm"` in `HITTING_METRICS`, stripped
the direction keyword `"Increase"`, and returned the raw phrase `"Increase Arm"` as
the metric. That phrase isn't in `defense_metrics` → `get_defense_stats()` was
never called → arm_strength never computed → N/A displayed.

**Fix (commit `8a92d90`):** At the top of `detect_goal_type()`:
```python
position_override = _extract_position_override(text)
if position_override == 'INF':
    return GoalType.INFIELD
elif position_override == 'OF':
    return GoalType.OUTFIELD
```

### Regression — shared fielding metrics must exist in both dicts (commit `95829ae`)

Once the position-keyword routing worked, Brutcher's `"defender at 1B (PAA/EO above 0)"`
started failing. Reason: `"PAA/EO"` existed in `HITTING_METRICS` (for back-compat with
goals that don't use a position keyword) but was missing from `INFIELD_METRICS` /
`OUTFIELD_METRICS`. New routing sent the goal to INFIELD, then extract_metric fell
through again and returned a raw phrase.

**Rule:** `PAA/EO` and `RoutineConversion` aliases MUST exist in all three dicts —
HITTING, INFIELD, OUTFIELD. If you add a new shared fielding metric, add it to all
three. HITTING entries stay for goals like `"Have a positive PAA/EO (Goal: above 0)"`
with no position keyword — those hit the `'paa'` hitting indicator match and route
HITTING → still valid.

### PAA vs PAA/EO — distinct metrics (Apr 20 2026)

The Intangibles glossary defines two separate metrics:
- **PAA** (`paa_cal`) — Plays Above Average, cumulative **SUM**, displayed f2
- **PAA/EO** (`paa_eo`) — PAA ÷ Expected Outs, per-play **ratio**, displayed f3

**In PD-Goals today: only `PAA_EO` is wired through stats.py + percentiles.py.**
No `paa_raw` / `paa_cal` metric exists in the PD-Goals pipeline. All real 2026
goals in `goals.csv` use `"PAA/EO"` explicitly — there are zero plain `"PAA"`
goals. (The affiliate tracker DOES expose `paa_cal` for cross-level math —
see "Raw PAA vs PAA Cal" in the next section — but it's not surfaced in PD-Goals.)

**Parser state (Apr 20 2026):** `"PAA/EO"` aliases to `"PAA_EO"` in all three dicts.
`"PAA"` alone is intentionally **NOT** aliased — if it ever appears in a goal, it
should fail to parse and prompt a design conversation about wiring raw PAA as its
own metric (different format, different status logic: SUM can be target=0 or a
specific positive number; ratio is usually target=0 "above").

If you add raw PAA later:
1. New stat key (`paa_raw` or `paa_sum`) in `stats.py::get_defense_stats()` — `SUM(dcbp.paa)` over all DCBP rows (no Tier 1 gate, matches GC2 cumulative value pattern).
2. New percentile distribution in `percentiles.py`.
3. Add `"PAA": "paa_raw"` to INFIELD/OUTFIELD_METRICS.
4. Add f2 formatter in report + app (distinct from PAA/EO's f3).

### Calibration mechanics + what `positional` actually is (verified May 20 2026 vs GC2 source SQL)

Verified against GC2's own SQL — the query that powers the fielder card on
GC2 itself. Our PAA formula across `paa_eo_matrix_data.py`,
`fielding_tracker_data.py`, `org_kpi_data.py`, and `stats.py` is
**byte-identical to GC2's**:

```sql
PlaysAboveAverage = (SUM(paa)/SUM(out_prob) - AVG(paaeo_offset))
                    * SUM(out_prob) * AVG(eo_scalar)
PlaysAboveAveragePerExpectedOut = SUM(paa)/SUM(out_prob) - AVG(paaeo_offset)
RunsAboveAverage = PAA × SUM(drv × out_prob) / SUM(out_prob)
ExpectedOuts = SUM(out_prob) × AVG(eo_scalar)
```

#### What `positional` actually is

`Defense_Combined_By_Pos.positional` is a **tracking-completeness flag**,
NOT a "nominal position vs covering" indicator (an earlier extrapolation
that was wrong; GC2's SQL settles it). Per GC2's source SQL,
`positional = 1` rows are the **fully-tracked plays** — the ones HawkEye
captured with full positional detail. `positional = 0` rows have enough
data to give an `out_prob` but lack the full positional component.

GC2's player card publishes BOTH variants for every PAA-family metric:

| Default (all DCBP rows) | Tracked-only (positional = 1) |
|---|---|
| `PlaysAboveAverage` | `PlaysAboveAverage_Tracked` |
| `PlaysAboveAveragePerExpectedOut` | `PlaysAboveAveragePerExpectedOut_Tracked` |
| `RunsAboveAverage` | `RunsAboveAverage_Tracked` |
| `RunsAboveAveragePerExpectedOut` | `RunsAboveAveragePerExpectedOut_Tracked` |
| `ExpectedOuts` | `EOTracked` |
| `PlaysTracked` = `SUM(CAST(positional AS int))` | — |

Our apps compute only the **default (untracked + tracked combined)**
variant. The `_Tracked` cuts are not exposed anywhere. If a coach needs
HawkEye-only signal (e.g., at FCL / DSL where tracking is patchier), we
don't have it today — would be a reasonable feature add if it comes up.

#### What the calibration actually corrects for

`guts.PAA_EO_Position_Calibration` is keyed on `(pos_id, positional,
season)`. The offset varies by:

- **Position** — each fielding `pos_id` has its own offset
- **Tracking state** — within a position, tracked vs untracked plays
  get DIFFERENT offsets (separate calibration rows)
- **Season** — refit yearly

The calibration is a yearly per-(position × tracking-state) bias
correction R&D fits to make cumulative PAA come out unbiased. It's NOT
just a "position rescaler" — it also zeroes out the systematic
difference between tracked and untracked plays' PAA distributions.
Without it, blindly summing `dcbp.paa` across both `positional`
populations would carry whatever bias is baked into the raw model
output per (pos, tracking-state) combo.

#### Raw PAA vs PAA Cal — what we expose and why

| Name | Formula | Used for | Matches GC2? |
|---|---|---|---|
| `raw_paa` | `SUM(dcbp.paa)` (no calibration) | Internal plumbing only — exposed by fielding tracker queries to support cross-level math. NEVER displayed. | N/A — GC2 doesn't publish this anywhere |
| `paa_cal` (= GC2 `PlaysAboveAverage`) | `(SUM(paa)/SUM(out_prob) - AVG(offset)) * SUM(out_prob) * AVG(eo_scalar)` | Canonical displayed value. Matches GC2's player card "PAA" exactly. | ✅ Verified May 2026 |
| `paa_eo` (= GC2 `PlaysAboveAveragePerExpectedOut`) | `SUM(paa)/SUM(out_prob) - AVG(offset)` | The per-play rate. Position-comparable, additive across levels via `SUM(paa_cal)/SUM(expected_outs)`. | ✅ Verified May 2026 |

The `paa_cal` form is sum-able across levels (because the calibration
JOIN is keyed on `(pos_id, positional, season)` — no level join — so
`paa_cal` and `expected_outs` add cleanly across levels). The Mazzo
PAA/EO matrix (`pd-goals/src/paa_eo_matrix_data.py`) exposes both:
`paa_eo` is the displayed value, `paa_cal` is the additive math
intermediate.

#### Other GC2 patterns worth knowing (from the source SQL)

GC2's PAA query also applies these scope filters that we don't currently
mirror everywhere:

| GC2 filter | What it does | Where we use / don't |
|---|---|---|
| `Schedule.is_pro_level_and_winter = 1` | GC2's pro-roster gate | We use explicit level_code lists instead — worth a parity audit |
| `gc2_level_id NOT IN ('14','6','22','8','23')` | GC2's level blacklist (junk codes) | We use level_code blacklists — same effect, different keys |
| `FielderTeam.team_id <> 0` | Excludes plays with placeholder team_id | We don't currently gate on this; a small number of rows may differ |
| `PlayersGames.pos_id <> 0` | Excludes DH / non-fielder rows | We rely on `pos_id IN (2..9)` filters — equivalent |
| Inning calc: `SUM(outs)/3 + 0.1*(SUM(outs)%3)` | Baseball notation IP (4.1 = 4⅓ IP) | We use this same pattern per `ip-calculation.md` |

#### What NOT to do

- **Don't claim `positional` means "nominal position vs covering."**
  It's a tracking-completeness flag. GC2's source SQL settles it via
  the `_Tracked` suffix metrics that all filter on `positional = 1`.
- **Don't display `raw_paa` (`SUM(dcbp.paa)` direct).** It carries
  per-(pos × tracking-state) bias that the calibration zeros out. It's
  exposed in tracker queries only for cross-level math, never for
  display. The canonical display value is `paa_cal`.
- **Don't drop the `paaeo.positional = OutProbs.positional` JOIN
  predicate** when reading the calibration table. Without it, you'd
  apply an averaged offset across both populations and lose the
  per-tracking-state correction. Always JOIN on all three keys:
  `(pos_id, positional, season)`.
- **Don't add a competitive-play / Tier 1 / first_defender gate to
  PAA aggregation.** GC2 doesn't (verified in their SQL: the entire
  WHERE clause is `groundcontrol_id = @Param0 AND
  is_pro_level_and_winter = @Param1 AND team_id <> @Param2 AND
  gc2_level_id NOT IN (junk)`). Matches the existing "Cumulative
  value metrics — NO gate" rule in `fielding.md`.

## Defense Percentile Distributions — Schedule_View Required (Apr 20 2026)

`percentiles.py::_get_hits_distribution()` and any other defense pool query that
uses `sched_type_filter()` MUST join `Astros.Schedule_View` (not `Astros.Schedule`).

`sched_type_filter()` emits SQL referencing `s.sched_type` and `s.level_code` —
columns that exist only on **Schedule_View**, not on the raw `Schedule` table
(which has numeric `level_id`). Using the wrong table throws
`Invalid column name 'sched_type'` and the entire percentile pool comes back empty.

Commit `3ec47f5` fixed this.
