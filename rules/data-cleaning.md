---
paths:
  - "**/*.py"
  - "**/*.sql"
---

# Data Cleaning Standards (BLOCKING)

Two cleaning rules, applied across every surface that aggregates the
affected metric. Both target Hawkeye tracker errors that distort
averages.

---

## 1. Arm Angle — two-step pitcher-level cleanup

### The bugs we're killing

- **Hawkeye glitches** that produce arm angles > 90° (physically
  impossible for normal pitching — the elbow can't get above the
  shoulder by that much).
- **Less-extreme outliers** within a pitcher's own distribution that
  represent tracker noise around his actual release slot.

### The two steps

**Step 1 — pool-wide hard cap (every pitcher, every input):**

Drop (NaN out) any pitch where `arm_angle > 90`.

**ABSOLUTELY NO LOWER BOUND.** Sidearm AND submarine pitchers legitimately
throw with low or even **negative** arm angles. Real submariners like
**Tyler Rogers, Josh Hejka, Adam Cimber** routinely produce arm-angle
values at or below 0°. Lefties' values can also be negative regardless
of slot.

**Never** add a `>= 0` or any other lower-bound assumption. The only
safe pool-wide cap is the physical upper limit at 90° (elbow-above-
shoulder is impossible for normal pitching). Anything below that is
a legit release slot for SOMEONE. Per-pitcher cleanup (step 2) handles
within-pitcher noise without needing a global lower bound.

**Step 2 — per-pitcher 2.5σ trim (eligible pitchers only):**

For pitchers with **≥ 20 arm-angle pitches in the input dataframe**:

1. Compute that pitcher's mean and σ on the post-step-1 arm angles.
2. NaN out any pitch where `|arm_angle − pitcher_mean| > 2.5 × pitcher_σ`.

For pitchers with < 20 pitches in the input, skip step 2 entirely (just
the >90° cap applies). Their σ estimate is too unstable to trust.

### NaN the value, not the row

Both steps operate on the `arm_angle` column only. The pitch row
remains in the DataFrame. Pitch counts, BF, IP, and every other metric
on that pitch are unaffected.

`AVG()` / `np.mean()` / `pandas.mean()` automatically skip NaN, so
downstream aggregates Just Work.

### Canonical helper

`bullpen-report/src/database.py::clean_arm_angle()` — Python pandas
helper. Apply right after every pitch fetch, BEFORE aggregation /
display.

```python
from src.database import clean_arm_angle

pitch_df = _query_pitch_data(pitcher_id, season, levels, sched_types)
pitch_df = clean_arm_angle(pitch_df)
# All downstream aggregations now skip the bad arm-angle reads.
```

### SQL-side equivalent (for queries that aggregate inside SQL)

For places that compute `AVG(arm_angle)` directly in SQL without
returning per-pitch rows to Python, embed step 1 inline. Step 2
requires window functions — left as a future addition if needed.

```sql
-- Step 1 only, inline
AVG(CASE WHEN pv.arm_angle <= 90 THEN pv.arm_angle END) AS avg_arm_angle
```

If you need step 2 in pure SQL, use the per-pitcher window pattern:

```sql
-- Step 1 + 2 via window functions
WITH cleaned AS (
    SELECT pv.*,
           AVG(CASE WHEN pv.arm_angle <= 90 THEN pv.arm_angle END)
               OVER (PARTITION BY pv.pitcher_id) AS aa_mean,
           STDEV(CASE WHEN pv.arm_angle <= 90 THEN pv.arm_angle END)
               OVER (PARTITION BY pv.pitcher_id) AS aa_std,
           COUNT(CASE WHEN pv.arm_angle <= 90 THEN 1 END)
               OVER (PARTITION BY pv.pitcher_id) AS aa_n
    FROM Astros.Pitches_View pv
    WHERE ...
)
SELECT
    AVG(CASE
        WHEN arm_angle > 90 THEN NULL
        WHEN aa_n < 20 THEN arm_angle  -- skip step 2 below threshold
        WHEN ABS(arm_angle - aa_mean) > 2.5 * aa_std THEN NULL
        ELSE arm_angle
    END) AS clean_avg_arm_angle
FROM cleaned;
```

### Surfaces that must apply this

Arm angle exists ONLY in Arm Farm pitcher data — no other app touches it.

| File | Where to apply |
|---|---|
| `bullpen-report/src/postgame_data.py` | After per-pitcher pitch queries |
| `bullpen-report/src/tracker_data.py` | Org P99 / per-pitcher tracker queries |
| `bullpen-report/src/pitcher_kpi_data.py` | KPI weekly per-pitcher computation |
| `bullpen-report/scripts/pitcher_analysis.py` | After `_query_pitch_data` calls |
| `bullpen-report/scripts/pitcher_kpi_snapshot.py` | After KPI fetch |
| `bullpen-report/src/postgame_report.py` | The per-pitch arm-angle box (Apr 17 feature) |

PD Goals does not currently surface pitcher arm angle. If/when it does,
apply the same helper.

### Pin re-runs required

After landing this, the Arm Farm tracker pins encode the pre-clean
numbers. Re-run the tracker pin CLI for the pitcher tracker on the work
laptop after the cleaning ships and the deploy is live. See
`tracker-parquet-pins.md` for the re-pin procedure.

### Audit findings (2026-04-26 — `sql-queries/arm-angle-2.5sigma-audit.sql`)

Validated against HOU MiLB pitchers, 2025+2026 R-season:

**Distribution of σ across pitchers:**
| Year | p25 | p50 | p75 | p90 | range |
|---|---|---|---|---|---|
| 2025 | 3.69° | **4.49°** | 5.23° | 6.36° | 1.73 – 11.66 |
| 2026 | 3.30° | **4.33°** | 5.32° | 6.82° | 1.53 – 14.85 |

**Per-pitcher trim rates:**
- Median ~1% trimmed (matches gaussian theoretical 1.24% at 2.5σ)
- 80% of pitchers below 2% trim
- 5 pitchers > 5% trim — these have heavy-tailed data (high σ from bad reads inflating the σ estimate). σ-based cleaning is partially-effective for them; the underlying tracker noise is the real problem.

**Verdict:** 2.5σ is appropriate for the bulk of the population. Loosening to 3σ would barely affect the median pitcher (drops trim from 1% → 0.3%) but does not meaningfully fix the heavy-tailed cases either.

### Caveat — slot switchers and submariners

For pitchers who **deliberately change slots** (e.g. Charlie Weber 2026,
σ=8.13° at mean 19.88°), the 2.5σ trim WILL remove some legitimate
variance. The helper has no way to tell "real slot drop" from
"tracker glitch" — both look like outliers from the personal mean.
Acceptable trade-off because the alternative (no cleaning) keeps
genuine glitches in.

For submariners (Tyler Rogers / Josh Hejka archetype), step 2 handles
them correctly because the trim is **relative to each pitcher's own
mean**. A submariner's true arm angles cluster tightly around their
low/negative mean, so their 2.5σ window naturally contains those
values — no special-casing needed.

Murrieta example (sidearm, mean 45.61°): his -6.54° read IS a glitch
because it's 52° below his typical slot. Tyler Rogers (mean ~0°)
having a -3° read is NOT a glitch — it's inside his window. The
helper distinguishes these correctly without any global rule.

---

## 2. Primary Lead Length — 1B floor (5.0) + 1B ceiling (20.0) + 2B ceiling (25.0)

### The bugs we're killing

**Floor (1B PL ≤ 5.0):** Hawkeye occasionally latches onto the **first
baseman** instead of the runner during pre-pitch tracking, producing
tiny "lead" readings of 1-3 feet when the runner is actually taking a
normal lead off the bag. Real example (2026-04-22): Xavier Nay shown
with a 2-ft lead on a pitch where he was off the bag taking a normal
big lead.

**Ceiling (1B PL > 20.0, 2B PL > 25.0):** Hawkeye occasionally latches
onto the **wrong object** (a passing fielder, the runner from a
different base, debris) producing absurdly large lead readings — 25+
feet at 1B, 30+ feet at 2B. Real example flagged 2026-05-12: PL values
in the 30-50 ft range at 1B where the runner physically couldn't have
been that far off the bag.

### The rule

**1B PL:** drop / NULL any row where
`primary_distance_from_occupied_base <= 5.0 OR primary_distance_from_occupied_base > 20.0`

**2B PL:** drop / NULL any row where
`primary_distance_from_occupied_base > 25.0`

**3B PL:** unchanged — no floor, no ceiling (different physical norms,
separate evidence needed).

Strict bounds. Apply at the SQL level so both the PL value AND the TL
(total lead) value for that same row are excluded together. The TL is
built off PL — if PL is bad, TL has no reliable foundation either.

### Apply only to 1B (floor) / 1B+2B (ceiling)

The 5-ft floor specifically targets first-baseman confusion (1B only —
2B/3B don't have a holder to confuse with).

The ceilings target generic Hawkeye object-latch errors which can fire
at any base, but 3B leads are physically more constrained (held by 3B,
shorter physical range) so a ceiling there is deferred until evidence
shows the bug fires.

### SQL pattern

```sql
-- 1B PL: floor + ceiling. Same gate is reused on the 1B TL aggregate
-- because TL is meaningless when PL is bad.
AVG(CASE
    WHEN pbl.occupied_base = 1
     AND pbl.closest_fielder_distance_to_occupied_base <= 10
     AND pbl.primary_distance_from_occupied_base > 5.0
     AND pbl.primary_distance_from_occupied_base <= 20.0     -- NEW CEILING
     AND pv.runner_going IS NULL
    THEN pbl.primary_distance_from_occupied_base
END) AS avg_ll_1b

-- 2B PL: ceiling only (no holder → no floor needed).
AVG(CASE
    WHEN pbl.occupied_base = 2
     AND pbl.primary_distance_from_occupied_base <= 25.0     -- NEW CEILING
     AND pv.runner_going IS NULL
    THEN pbl.primary_distance_from_occupied_base
END) AS avg_ll_2b
```

When using the same `pbl` row for both PL and TL aggregates in the same
query, the same gate goes inside the CASE WHEN for TL too. n_leads
counts are unaffected (gate only NULLs the metric, doesn't drop the row).

### Surfaces that must apply this

| File | Notes |
|---|---|
| `intangibles/src/br_tracker_data.py` | All 1B + 2B PL agg queries (12 + 17 sites) |
| `intangibles/src/br_data.py` | Daily / postgame BR query (5 + 5 sites) |
| `intangibles/src/br_weekly_data.py` | Weekly BR report data |
| `intangibles/src/br_kpi_data.py` | KPI report 1B + 2B PL (6 + 2 sites) |
| `intangibles/src/br_percentiles.py` | Percentile pools (3 + 3 sites) |
| `intangibles/src/snapshot_data.py` | Snapshot 1B + 2B PL |
| `intangibles/src/baserunning_base.py` | If 1B PL is aggregated here, gate |
| `pd-goals/src/org_kpi_data.py` | BR section's 1B + 2B PL agg |
| `pd-goals/src/drift_br.py` | PD Flag Tracker BR drift queries |

### Pin re-runs required

BR tracker pins (Intangibles) encode pre-clean numbers. Re-run BR
tracker pin CLI after deploy is live. See `tracker-parquet-pins.md`.

### Bug history

- **Apr 22 2026:** 5.0 ft floor added (1B only) — Xavier Nay 2-ft lead caught.
- **May 12 2026:** 20.0 ft ceiling on 1B + 25.0 ft ceiling on 2B added — observed PL values > 30 ft at 1B and 35+ ft at 2B that were physically impossible. Same Hawkeye object-latch bug class as the floor but at the other extreme.

---

## 3. Bat Speed at Contact — three-step per-player cleanup

### The bugs we're killing
- Hawkeye glitches that produce zero or negative contact speeds (sensor noise during the bat-ball event).
- Defensive / check swings that drag the season average below the player's true competitive bat speed.
- Per-player heavy-tail outliers from misreads.

### The three steps (in order, per player)
1. **Top-90% per player** — drop the bottom 10th percentile of each player's contact speeds (Savant "competitive swings" method).
2. **Hard floor 57 mph** — drop tracker glitches. NO UPPER CAP (peak's old 87 cap doesn't apply; at-contact self-bounds).
3. **Per-player 2.5σ trim** — drop values > 2.5σ from the post-step-2 mean.

Plus: **>= 20 raw rows** to attempt cleaning at all; **>= 5 rows after steps 1+2** to compute final value.

### Why
- Same Savant top-90% pattern used for "Avg Bat Speed" leaderboards.
- 57 mph floor catches Hawkeye sensor failures that produce ~0 readings without affecting any real swing.
- 2.5σ is conservative enough to keep elite tail values (Stanton 79.7) while catching tracker-glitch outliers.
- No upper cap because at-contact distribution self-bounds (peak's 87 cap was anti-glitch for peak's higher tail; doesn't apply here).

### Canonical helper

`_clean_bat_speed_avg(values: np.ndarray, min_swings: int = 20)` — present in:
- `pd-goals/src/drift_hitting.py:531` (canonical reference)
- `pd-goals/src/percentiles.py` (inline within `_get_bat_speed_distribution`)
- `pd-goals/src/org_kpi_data.py:855` (inline within org cleaning)
- `barrelsville/src/tracker_data.py::_compute_batter_bat_speeds` (line 830)
- `barrelsville/src/tracker_data.py::_compute_bat_speed_per_org` (line 1897)
- `barrelsville/src/hitter_kpi_data.py::_compute_bat_speed_per_batter` (line 1066)
- `barrelsville/src/postgame_percentiles.py` (inline)
- `barrelsville/src/weekly_hitter_data.py` (inline)
- `barrelsville/src/postgame_data.py:1416-1428` (inline + bunt filter prefix)

All sites must drop the upper-87 cap when this rule lands. Grep `<= 87` after the refactor — should return zero matches.

### What NOT to do
- Don't add an upper cap. At-contact has no plausible upper outlier in real data.
- Don't lower the 57 floor without a tracker-glitch case study.
- Don't skip the min-20-rows gate — small samples produce unstable means even after cleaning.

---

## What NOT to do

- **Don't** add a `>= 0` lower bound on `arm_angle`. Sidearm/submarine
  pitchers legitimately throw at low and negative angles.
- **Don't** drop the entire pitch row in either cleanup. We NaN/exclude
  only the affected metric column. Pitch counts and other metrics on
  the same row stay valid.
- **Don't** apply the 5-ft lead floor to 2B or 3B — the floor bug is
  specific to first-baseman confusion at 1B. Ceilings ARE applied at 2B
  per May 12 2026 rule update; 3B leads remain unbounded.
- **Don't** apply the 2.5σ arm-angle trim to pitchers with < 20 pitches
  in the input — the σ estimate is too unstable.
- **Don't** skip the re-pin step after deploying. Pinned numbers will
  be off until the CLI is re-run.

---

## Cross-reference

- `db-columns.md` — column meanings, existing lead filter table
- `arm-farm.md` — Arm Farm pitcher-side architecture
- `intangibles.md` — BR architecture
- `tracker-parquet-pins.md` — re-pin procedure after data changes
- `pitfalls.md` — Hawkeye / SQL Server pitfalls
