# GroundControl2 & Our Deviations

GroundControl2 (often "GC2") is the Astros' production analytics
system. It computes the metrics displayed in the official GC2
leaderboards, player profiles, and dashboards that coaches and the
front office reference daily. Our codebase implements **most** GC2
metrics with byte-identical results --- and **deliberately differs** in
a small number of well-documented places.

This chapter explains what GC2 is, what its proprietary metrics
(gcERA, gcOBA, gcPerf, pBarrel) actually compute, and where we
intentionally diverge.

::: tip
**What you'll learn:** what GC2 is and isn't, the four big GC2
metrics with their formulas + run values, the seven places we diverge
from GC2, and how to tell when a divergence is intentional vs a bug.
:::

## What GC2 is

GC2 is an internal R&D system that produces:

1. **Leaderboards** --- per-level, per-domain, per-stat ranked
   tables.
2. **Player profile pages** --- a player's full career across
   levels with all metrics.
3. **Daily dashboards** --- coach-facing one-pagers for in-game and
   postgame use.
4. **A SQL query layer** --- the canonical queries against
   `GroundControl2` for every metric. When we add a new metric, the
   first move is finding the GC2 production SQL and porting it.

GC2 is owned by R&D (Adam Brodie wrote much of it). Our four apps
exist alongside it --- they don't replace GC2, they extend it for
specific Player Development workflows that GC2 doesn't ship as a
default product.

::: note
GC2 is also where the five proprietary metrics (gcERA, gcPerf, gcOBA,
pBarrel, gcPerformanceGrade) are defined. When we say "gcOBA matches
GC2 exactly" we mean: pull the canonical GC2 SQL, port it, and verify
the numbers match for a known player.
:::

## Why our codebase exists alongside GC2

Three reasons:

1. **GC2 doesn't ship per-player PDFs.** Coaches want their daily
   postgame as a Slack message with a PDF attachment. GC2 has
   leaderboards and dashboards; we have the report-generation
   pipeline.
2. **GC2 doesn't ship custom Player Development workflows.**
   Transition reports, PD goals, drift alerts, advance scouting in
   our specific format --- these are PD-specific products.
3. **GC2 doesn't ship the cross-app patterns.** Three-surface parity
   (tracker / KPI weekly / org KPI all matching) is a discipline
   we've built up over a year of bug-hunting. GC2 reports each
   surface separately.

## The four big GC2 metrics

### gcERA --- GroundControl ERA

**Definition:** R&D's best predictive estimate of a pitcher's runs
allowed using only in-season measurable components --- pBarrels,
strikeouts, walks, HBPs, and the league HR-per-fly-ball rate.

**Run values (per outcome):**

| Outcome | Run value |
|---|---|
| Strikeout | -3.3 |
| Walk + HBP | +9.9 |
| non-pBarrel BBE | +3.5 |
| pBarrel BBE | +7.6 (slightly varies by year) |

**Formula:**

```
gcERA = ((3.9 + 31.1*hr_rate) * bip * pbarrel_rate
       + 3.5 * bip * (1 - pbarrel_rate)
       - 3.3 * SO
       + 9.9 * (BB + HBP))
       / TBF
```

`hr_rate` is the global MLB HR-per-fly-ball rate, with a before-May
fallback to the prior year. NEVER level-specific.

**Reference SQL:** `sql-queries/gc2_gcera_query.sql`. The R&D paper
explaining the derivation: `astros-docs/AR-gcERA-260923-213026.pdf` (in
the handbook assets folder for offline reading).

**Our implementation:** PA-weighted everywhere (matches GC2). The
canonical impl is `bullpen-report/src/tracker_data.py::_get_league_hr_rate_gc2()`.

### gcPerf --- GroundControl Performance Grade

**Definition:** A pitch-level, context-neutral performance score using
6 primary pitch results. More predictive of future RVGainHS than
RVGainHS itself. Scaled 20-80 (50 = average, higher = better pitcher
performance).

**Run values (per 1000 pitches):**

| Result | Run value |
|---|---|
| In-Heart whiff | -10 |
| Out-of-Heart whiff | -8 |
| Called Strike | -2 |
| Ball + HBP | +2 |
| pBarrel BBE | +9 |
| non-pBarrel BBE | -2 |

**SQL:**

```sql
gcPerformanceGrade = 50.0 - 1500.0 * AVG(
    CASE
        WHEN pitch_result_id IN (10, 22, 23) THEN
            CASE WHEN swing_zone IN ('heart', 'meatball')
                 THEN -0.10 ELSE -0.08 END
        WHEN pitch_result_id IN (6) THEN -0.02
        WHEN pitch_result_id IN (4, 5, 11) THEN +0.02
        WHEN pitch_result_id IN (12, 13, 14) THEN
            CASE WHEN <pBarrel formula> THEN +0.09 ELSE -0.02 END
        ELSE 0.0
    END
)
```

**Reference paper:** `astros-docs/AR-gcPerf-100923-184838.pdf`.

::: note
"Heart" zone in gcPerf includes the "Meatball" zone --- it functions
similarly to the in-zone/out-of-zone distinction.
:::

### gcOBA --- GroundControl OBA

**Definition:** A composite per-batter expected OBP that combines
swing distribution, contact quality, and the league's MLB OBP base.

**Formula** (verified Apr 16 2026 against GC2 production):

```
gcOBA = MLB_OBP * (
    0.50 * K_rate
    + 1.49 * BB_HBP_rate
    + 0.11 * zero_whiff_pct
    + 0.08 * one_whiff_pct
    + (-0.10) * two_whiff_pct
    + (-0.10) * three_plus_whiff_pct
    + BIP_rate * (1.70 * barrel_rate + 1.09 * avg_useful_ev / 100)
)
```

**Where the 0/1/2/3+ whiff distribution comes from:** GC2 counts S+W+T
characters in the `Events_View.pitches` string. We count whiffs per
PA --- `pitch_result_id IN (10, 22, 23)` --- which produces identical
results.

::: blocking
**Six BLOCKING rules to keep gcOBA matching GC2:**

1. Swing distribution = WHIFF count per PA, not all swings.
2. PA gate uses `(pa=1 OR ibb=1)` --- IBBs have `pa=0`.
3. Python-side groupby uses `(sched_id, ab_event_id)` --- never
   `ab_event_id` alone (it's not globally unique).
4. IBB included in BB+HBP rate (different from wOBA which excludes IBB).
5. Barrel formula uses integer truncation --- `int(ev) * 1.5 - int(la) >= 117`.
6. MLB OBP always (no level-specific OBP for gcOBA).
:::

**Reference impl:** `barrelsville/src/postgame_data.py::_compute_gcoba()` and
`barrelsville/src/tracker_data.py::_SWING_DIST_QUERY`.

**Diagnostic:** `python scripts/gcoba_diagnostic.py --batter <gc_id> --start <date> --end <date>`

### pBarrel --- Astros Custom (Parabolic Barrel)

**Definition:** A barrel definition derived from a parabolic threshold
between exit velocity and launch angle. Replaces the linear MLB Barrel
definition for pitcher-side metrics (gcERA, gcPerf).

**Formula:**

```sql
pBarrel = CASE WHEN
    hit_exit_speed >= 0.011 * POWER(hit_vertical_angle, 2)
                    - 0.91 * hit_vertical_angle
                    + 95.0
THEN 1 ELSE 0 END
```

**Versus the MLB Barrel (linear):**

```sql
Barrel = CASE WHEN
    hit_exit_speed * 1.5 - hit_vertical_angle >= 117
    AND (hit_exit_speed + hit_vertical_angle) >= 124
    AND hit_exit_speed >= 98
    AND hit_vertical_angle > 4
    AND hit_vertical_angle < 50
THEN 1 ELSE 0 END
```

**Both filters share:** bunt exclusion (`hit_trajectory_id NOT IN (2,3,4)`)
and EV cap (`hit_exit_speed < 125`). Always apply these before
computing either.

## The seven deliberate divergences from GC2

We've found and documented seven places where our codebase intentionally
differs from GC2. Each has a reason --- usually because GC2's choice
introduces a known bug or doesn't fit our use case.

### 1. Max EV --- we use MAX(), GC2 uses P99

**GC2:** `PERCENTILE_CONT(0.99)` over a player's BIPs.
**Us:** True `MAX()` after EV misread cleaning.

**Why we differ:** We have a separate EV misread filter (`hit_exit_speed >= 100
AND hit_vertical_angle < -35 AND hit_exit_speed > batter_p95`). After
that filter, the highest EV in the cleaned distribution is the real
max. P99 on top of that double-discounts and discards the player's
actual best swing.

**Caveat:** if we ever drop the misread filter, P99 should come back as
a fallback safety net. Tracked in `gc2-metrics.md`.

### 2. NetK denom --- strict inequality, called_strike_chance (level-adjusted)

**GC2:** `BETWEEN 0.05 AND 0.95` on `called_strike_chance_mlb`.
**Us:** `> 0.05 AND < 0.95` (strict) on `called_strike_chance` (level-adjusted).

**Why we differ:** Brodie clarified Apr 2026 that the level-adjusted
column (`called_strike_chance`) describes actual called-strike behavior at
the level, while `called_strike_chance_mlb` applies MLB zone standards
to all levels. The level-adjusted version is the right denom for NetK.
Strict inequality matches GC2's actual exclusion of boundary values.

::: blocking
**FramRAA (different metric) uses `called_strike_chance_mlb` with
inclusive `BETWEEN`.** Don't conflate. They're intentionally different
columns and different ranges:

- NetK: `called_strike_chance` (level-adjusted), strict `> 0.05 AND < 0.95`
- FramRAA: `called_strike_chance_mlb` (MLB model), inclusive `BETWEEN 0.05 AND 0.95`
:::

### 3. Bat speed at contact --- we include fouls, GC2 BIP-only

**GC2 leaderboard `BatSpeedAtContactAvg`:** `pitch_result_id IN (12,13,14,18,19,20)` (BIP only).
**Us:** include BIP + fouls + foul tips. Whiffs are auto-excluded
(no contact-frame value).

**Why we differ:** ~2x sample size. Per-player numbers can differ up
to 0.5 mph, but aggregate MLB pool tracks ~71.5 mph either way (matches
public Savant figure). The wider sample stabilizes per-player values
faster.

**Reference:** `.claude/rules/bat-speed-canonical.md`. The cleaning
helper (`clean_bat_speed_per_player`) lives in two byte-identical
copies: `barrelsville/src/bat_speed_clean.py` and
`pd-goals/src/bat_speed_clean.py`. Eight surfaces route through it.

### 4. Tier 1 fielding gate --- 6-term, not GC2's CP=1

**GC2:** uses `Defense_Combined_By_Pos.competitive_play = 1` as the
gate for tracking metric aggregation.

**Us:** 6-term OR gate:

```
DCBP.out_made + DCBP.CP + DCBP.CT + TDM.CP + TDM.CT + (arm >= floor) > 0
```

**Why we differ:** DCBP and TDM independently flag the same play and
**can disagree**. Example: Trammell 04/01 --- TDM.CP=1 with TopSpd=27.2,
but DCBP.CP=0. GC2 drops the play and all its tracking data. Our gate
catches everything GC2 catches PLUS plays GC2 misses.

**Critical caveat:** CP count is **display-only**. `SUM(competitive_play)`
is fine for showing a volume column, but never use it as a metric gate.

### 5. R2K% --- GC2 formula, not Zach's original

**GC2 (active since Apr 13 2026):** `ab_pitch_number = 3 AND strikes_after >= 2`,
gated by `(pa=0 OR so=1)`. Excludes 3-pitch PAs ending in non-K
contact.

**Zach's R2K% (retired):** No `(pa=0 OR so=1)` filter --- counted ALL
PAs with 3+ pitches. If a batter was 0-2 and homered on pitch 3, it
counted as the pitcher winning the race.

**Why we ship GC2's:** Coaches prefer GC2 alignment. Zach's version
better captured the intent of "race to 2 strikes" but the production
reports compare directly to GC2 leaderboards, so we matched.

### 6. Bunt + EV cap on barrel --- always applied, GC2 sometimes

We always apply `hit_trajectory_id NOT IN (2,3,4)` (bunt exclusion)
and `hit_exit_speed < 125` (EV cap) on every Barrel/pBarrel/Dmg%
calculation. GC2's gcOBA uses BIP codes (12,13,14) but doesn't
universally apply the bunt filter on every barrel calc. We do.

### 7. Whiff codes --- we include 16 (missed bunt), GC2 excludes

**GC2 Ctct%:** WHIFF_CODES = `(10, 21, 22, 23)`.
**Us:** WHIFF_CODES = `(10, 16, 21, 22, 23, 25)`.

**16 = "Strike - Missed Bunt"** (NOT foul tip --- foul tip is 10).
**25 = "bunt_foul_tip".** Our decision: all swinging strikes belong in
WHIFF_CODES. Deliberate, documented, intentional.

## How to spot a real divergence vs a bug

If you compare a number in our app to GC2 and they differ, the
diagnostic order:

1. **Is it one of the seven deliberate divergences above?**
   If yes, the difference is expected. Confirm the magnitude is in
   the documented range.
2. **Is it a known three-surface parity issue?** Check `.claude/rules/three-surface-parity.md`
   for the bug history. Most common silent drifts:
   - wOBA denom uses PA count instead of `AB+BB-IBB+HBP+SF`
   - Multi-level rollup weights by `n_pitches` instead of per-metric `n_obs`
   - Damage% rounded in decimal space instead of percentage space
   - Multi-level percentile pooling fails for cross-level players (CF
     prospects more than 2B/SS)
3. **Is the GC2 reference SQL up-to-date?** R&D occasionally tweaks
   formulas. Ask Brodie or check `sql-queries/gc-hitter-production-queries.sql`
   for the latest snapshot.
4. **Run the diagnostic SQL.** Most metrics have a parity-diagnostic
   in `sql-queries/`. xwOBA has `xwoba-parity-diag.sql`. gcOBA has
   `gcoba_diagnostic.py`. Bat speed has `bat-speed-canonical.md`'s
   verification recipe.

## The gcOBA diagnostic --- worked example

A coach reports "Sullivan AAA gcOBA on the postgame is 0.402 but the
GC2 profile says 0.395." That's a 0.007 spread --- big enough to be a
bug, small enough to be a sampling-window artifact.

Diagnostic order:

```bash
# 1. Run the existing diagnostic
python scripts/gcoba_diagnostic.py \
    --batter 244959 --start 2026-04-03 --end 2026-04-14
```

What it prints:

- The 6-component breakdown: K, BB+HBP, swing dist (4 buckets), BIP rate, barrel rate, useful EV
- The MLB OBP base used
- The final gcOBA value
- A side-by-side with what GC2 would produce on the same window

If the components match GC2 but the final differs, it's a coefficient
or rounding mismatch (rare --- the formula is locked).

If a component differs, the bug is in the SQL or Python that produced
it. Most common:

- Swing distribution counts ALL swings instead of WHIFFs only (BLOCKING rule #1)
- IBBs not included in PA gate (`pa=0` on IBBs --- need explicit `OR ibb=1`)
- Barrel formula uses float instead of integer truncation

## Where to look next

- **Chapter 5** (Metric Catalog) for every metric, formula, and source-code pointer.
- **Chapter 6** (Data Cleaning Canon) for BIP filters, EV misread, bat speed cleaning, BIT casting.
- **Chapter 11** (Cross-App Patterns) for three-surface parity.
- `astros-docs/AR-gcERA-260923-213026.pdf` and `AR-gcPerf-100923-184838.pdf` --- the R&D papers.
- `.claude/rules/gc2-metrics.md` --- the canonical rule file underlying this chapter.
- `sql-queries/gc2_gcera_query.sql` and `gc-hitter-production-queries.sql` --- GC2 reference SQL we port from.
