---
{type: concept, domain: hitting, source: personal-bsbres/notebooks, created: '2026-06-15'}
---
# Gainers Analysis

**Core idea:** Rank athletes by **how much they improved**, not by where they
currently stand. A "gainer" is whoever moved the most between tests. The whole
method is **compute a per-athlete delta on each metric, two ways, then rank the
deltas** — current snapshots are noise; the *trajectory* is the signal. Built for
youth HP program ops (force-plate strength + velo), but the pattern is general.

## The two deltas (always compute both)

For each athlete, for each metric:

| Delta | Formula | Answers |
|---|---|---|
| **diff-from-previous** | `current_test − immediately_prior_test` | Recent momentum — are they trending up *right now*? |
| **diff-from-baseline** | `current_test − first_recorded_test` | Total program gain — how far have they come overall? |

Both matter: a kid can be way up from baseline but flat/declining recently
(plateau), or down from baseline but spiking lately (turning a corner).

## The canonical implementation — a 3-CTE self-join

The clean way to get both deltas in one pass (see `gainers_query_OG.sql` /
[[youth-hp-analytics]]):

```sql
WITH latest_tests AS (   -- curr: each athlete's MAX(test_date)
  SELECT * FROM hp_tests t
  WHERE t.test_date = (SELECT MAX(test_date) FROM hp_tests x WHERE x.athlete_name = t.athlete_name)
),
previous_tests AS (      -- prev: each athlete's 2nd-most-recent test
  SELECT * FROM hp_tests t
  WHERE t.test_date = (SELECT MAX(test_date) FROM hp_tests x
                       WHERE x.athlete_name = t.athlete_name
                       AND x.test_date < (SELECT MAX(test_date) FROM hp_tests WHERE athlete_name = t.athlete_name))
),
first_tests AS (         -- first: each athlete's MIN(test_date) = baseline
  SELECT * FROM hp_tests t
  WHERE t.test_date = (SELECT MIN(test_date) FROM hp_tests x WHERE x.athlete_name = t.athlete_name)
)
SELECT curr.athlete_name,
       curr.metric - prev.metric  AS metric_diff_from_previous,
       curr.metric - first.metric AS metric_diff_from_baseline
FROM latest_tests curr
LEFT JOIN previous_tests  prev  ON curr.athlete_name = prev.athlete_name
LEFT JOIN first_tests     first ON curr.athlete_name = first.athlete_name;
```

Repeat the two subtractions for **every metric** (here: CMJ power, SJ power, IMTP
force, pitch speed, bat speed, bodyweight). `LEFT JOIN` so an athlete with only
one test still appears (NULL deltas → treated as 0 downstream).

## The alternate alignment trick — rolling join

When the improvement metric lives in a **different database** than the test you're
anchoring on (e.g. force-plate `hp_tests` vs swing-lab POI data, no shared session
key), align by **athlete + nearest date** instead of an exact join:

```r
data.table::setkeyv(swing_db, c("name","date"))
data.table::setkeyv(hp_tests,  c("name","date"))
combined <- swing_db[hp_tests, roll = "nearest"]   # attach nearest-date swing row
```

**Caveat:** with sparse data this can pair a test to a swing weeks away. Add a
max-gap guard if precision matters.

## Ranking — keep it dumb

Once you have the delta table, ranking is deliberately lightweight. In the youth
work it's **outsourced to an LLM prompt** (paste the dataset, ask for "top 3 per
age group, missing → 0, rank by highest positive improvement, handle ties"). The
data pipeline earns its keep; the ranking is just sort-desc with rules. Contrast
[[lightgbm-baseball-modeling]] — that's when the *ranking itself* needs a model;
gainers don't.

## Gotchas

- **Missing values → 0**, not dropped — a kid with no IMTP test shouldn't vanish,
  he just scores 0 improvement on that metric.
- **Cohort-specific metric availability** — younger age groups only have a subset
  (11U/12U = CMJ only; 13U–15U lack IMTP; 16U/18U = all). Rank within what each
  group actually has.
- **Exclusions** — outliers / known-bad athletes get hardcoded out of rankings
  (e.g. "Exclude Kaito Garrett").
- **Tie handling** — define it up front (tie for 3rd → list 4, etc.).

## Where this shows up on the Astros side

This is the same engine as the **PD Flag / drift tracker**
(`rules/pd-goals-flag-tracker`): flag who moved the most between a baseline and a
current window, good direction or bad. Also the **amateur→pro development deltas**
in the draft work (`rules/draft-projects`) — same "current minus baseline, ranked"
shape, different population.

## Links
- [[MOC-baseball-analytics]]
- [[youth-hp-analytics]] · [[hp-trios]]
- [[swing-path-bat-tracking]] · [[big-3-hitting]] · [[hitting-biomechanics]]
- [[biomech-scores]] · [[statcast-pipeline]] · [[lightgbm-baseball-modeling]]
- Astros tie-ins: `rules/pd-goals-flag-tracker` (drift), `rules/draft-projects`

## From sources
- [[2026-08-15-why-1-mph-is-worth-millions-to-mlb-players]] - Why 1 MPH Is Worth Millions to MLB Players
