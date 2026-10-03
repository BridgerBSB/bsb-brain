---
paths:
  - "**/*.sql"
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Compute-Once Precompute for Scope-Independent Heavy CTEs (BLOCKING for big pins)

When the SAME expensive sub-CTE / window aggregation is embedded in MANY query
strings and re-run per query, compute it **once** and inline the result as a
constant `VALUES` lookup. This is **output-neutral by construction** and is the
canonical fix for the daily-pin DB-strain class. **Proven, shipped pattern** —
do it exactly this way; the harness is non-negotiable.

Created 2026-06-24 after R&D/Navisite flagged 5 parallel `cxconsumer` sessions
from the affiliate-tracker pins. Shipped on the Barrelsville hitting tracker
(Phase 1) and the Arm Farm pitcher tracker (Phase 3) the same day.

---

## Problem

An affiliate tracker pin runs ~a dozen query strings, fanned 5-wide
(`ThreadPoolExecutor`). Each query embedded the **same** `batter_ev_p95` CTE:

```sql
batter_ev_p95 AS (
    SELECT DISTINCT pv2.batter_id,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY h2.hit_exit_speed)
            OVER (PARTITION BY pv2.batter_id) AS p95_ev, ...
    -- full-season, all-7-levels scan of Pitches_View ⋈ Schedule_View ⋈ Hits
)
```

A `PERCENTILE_CONT` is a **sort**. SQL Server parallelizes it across cores
(`cxconsumer` wait). Re-running that full-season sort a dozen+ times per refresh,
5 concurrent, **saturates the box** — the exact query Navisite tagged.

The percentile is **identical** in every query (it ignores the calling query's
level/hand/H-A/date filters), so recomputing it per query is pure waste.

---

## The SAFETY CRITERION (the one rule that matters)

A heavy CTE is a compute-once candidate **ONLY IF its result depends solely on
`season` (or on nothing) — NOT on the calling query's level / hand / H-A / date /
position / org scope.**

- `batter_ev_p95` qualifies: its WHERE is hardcoded (`pitch_result_id IN
  (12,13,14)`, EV 0..125, `sched_type R/S/E`, fixed level list, `n_bip>=20`,
  `YEAR=:season`). Every query that joins it gets the same numbers today.
- **Fielding / catcher percentiles do NOT qualify.** Their `PERCENTILE_CONT`
  pools are filtered by the calling query's level/hand/position **inside the base
  CTE**, so the obs pool changes per query. Precomputing once there would
  **CHANGE outputs** = data-altering. **Do not apply this pattern to them.**
  (See `fielding.md`, `pooled-percentile-pattern.md`.)

If you cannot prove the CTE is scope-independent, STOP — it is not a candidate.

---

## The Pattern (3 pieces, all in `src/database.py`)

### 1. A brace-free sentinel + a toggle
```python
EV_CTE_SENTINEL = "__EV_CTE__"      # brace-free: survives .format() + token-replace passes
USE_EV_VALUES_CTE = True            # production default; harness flips False for baseline
_EV_VALUES_CHUNK = 1000             # SQL Server VALUES constructor cap
_EV_P95_LOCK = threading.Lock()     # single-flight the cold compute under the 5-wide fan-out
```

### 2. `build_ev_values_cte(season)` — render the precompute as inlined VALUES
```python
def build_ev_values_cte(season: int) -> str:
    with _EV_P95_LOCK:
        p95_map = _get_batter_ev_p95(season)          # existing lru-cached helper
    pairs = [(int(b), float(v)) for b, v in p95_map.items()
             if v is not None and float(v) == float(v)]   # float(v)==float(v) drops NaN
    # chunk ≤1000 rows per VALUES block, UNION ALL the chunks
    # CAST(p95_ev AS float) + repr(v) float literal so the > comparison matches the 8-byte double
    # empty map -> a single non-matching row (CAST(-1 AS int)) so every batter falls to ISNULL(...,105)
```

### 3. `_resolve_ev_cte` + a hook at the TOP of `run_query`
```python
def _resolve_ev_cte(query, params):
    season = (params or {}).get("season")
    if season is None: raise ValueError(...)            # fail loud, never silent
    cte = (build_ev_values_cte(int(season)) if USE_EV_VALUES_CTE
           else EV_MISREAD_CTE.replace("{{season}}", ":season").strip())  # heavy = exact prod baseline
    return query.replace(EV_CTE_SENTINEL, cte)

# in run_query, BEFORE the retry loop (so retries reuse it):
if EV_CTE_SENTINEL in query:
    query = _resolve_ev_cte(query, params)
```

Then the tracker query layer injects the **sentinel** instead of the heavy CTE.
`run_query` resolving the sentinel centrally means you cannot miss a call site,
and Phase-2/3 ports are nearly free.

---

## Why it is output-neutral (the proof you state, then verify)

The downstream `LEFT JOIN batter_ev_p95 bp95 ... ISNULL(bp95.p95_ev, 105)` and the
`NOT(...)` filter are unchanged. The values list carries the **same**
`(batter_id, p95_ev)` pairs the heavy CTE produces (≥20-BIP batters present;
<20-BIP absent → NULL → 105). So every row is cleaned identically. Float literals
use `repr()` (round-trips float64) + `CAST(... AS float)` so the `>` comparison
matches the original 8-byte double.

---

## The DIFF HARNESS is the gate (BLOCKING — never ship without it)

`scripts/diff_ev_precompute.py` (copy it between apps). Run on the **work laptop**
(DB-bound). It flips `database.USE_EV_VALUES_CTE` to compare:

- **`--check-p95`** (run FIRST, ~3s): diff the `batter_ev_p95` table itself,
  heavy vs values, in SQL. **Byte-identical (max_abs_diff = 0.000) is the
  correctness anchor** — proves the precompute reproduces every P95 exactly.
- **default / `--levels <one>`**: run the pin's public functions both ways and
  compare every frame, reporting per-column `n_diff / max_abs / max_rel`.
- **`--baseline-twice`**: control — run the heavy path twice; any diff = inherent
  parallel-plan FP nondeterminism.

### CLOSE is a PASS, not a FAIL (the lesson that cost two rounds)
Float `SUM`/`AVG` in SQL Server is **not** bit-reproducible across plans (parallel
reorders the addends). A plan change therefore produces last-bit drift
(`max_rel ≈ 1e-15`, float64 epsilon) in aggregated columns — often on columns
that have **nothing to do with the precompute** (e.g. `fb_spin`, `zctct_pct`,
`useful_ev_sum`). That is **display-identical FP aggregation noise, not a bug.**
- The gate is **display-exact, NOT bit-exact.** Classify `PASS` (identical) /
  `CLOSE` (within `atol=1e-6` / `rtol=1e-9`) / `FAIL` (beyond tol → real, do not
  ship). `check_exact=True` alone is the WRONG gate.
- Align rows by **identity columns only** before comparing (a real value diff
  must not reorder rows and corrupt the per-column magnitude).
- If `--check-p95` is byte-identical AND frames are all `PASS`/`CLOSE` → ship.

---

## App-Specific Differences

| App | Heavy CTE source | Injection chokepoint | Sentinel swap |
|---|---|---|---|
| **Barrelsville** (hitting) | `tracker_data._EV_CTE` (built at import from `EV_MISREAD_CTE`) | each query const `WITH """ + _EV_CTE` | `_EV_CTE = EV_CTE_SENTINEL` (one line; survives both `.format()` passes + `_monthly_to_weekly_sql`) |
| **Arm Farm** (pitching) | `tracker_data._EV_P95_CTE` | one fn `_inject_ev_misread_cleaning()` injects into all 7 | swap `_EV_P95_CTE.strip()` → `EV_CTE_SENTINEL` at the 2 inject lines |
| **PD Engine** `org_kpi_data.py` + `gcoba_canonical.py` | own `batter_ev_p95` copy | per-query | needs the resolver ported into PD Engine `database.py` first (Phase 2) |

The `_get_batter_ev_p95(season)` lru-cached helper already exists in both
trackers' `database.py` (reuse it; do NOT re-query). Verify the helper's WHERE is
**byte-identical** to the heavy CTE's WHERE before trusting it (Arm Farm: it is).

### Where it applies vs NOT
- **APPLIES (daily pins, high value):** Barrelsville hitting tracker ✅ done,
  Arm Farm pitcher tracker ✅ done.
- **Same swap, lower traffic (Phase 2, weekly/on-demand):** Barrelsville
  `hitter_kpi_data` / `weekly_hitter_data` / `postgame_percentiles` /
  `poc_research_data` / `sugar_land_la_ev_data`; PD Engine `org_kpi_data` +
  `gcoba_canonical`.
- **DOES NOT APPLY (scope-dependent pools — would alter data):** Intangibles
  fielding / catcher / BR trackers. Leave them alone.

---

## What NOT to do

- **Don't** apply this to a CTE whose result depends on the query's
  level/hand/position/date scope. That changes outputs. The safety criterion is
  the whole ballgame.
- **Don't** ship without the diff harness. "Output-neutral by construction" is a
  claim; `--check-p95` byte-identical is the proof.
- **Don't** gate on bit-exactness. `CLOSE` at `~1e-15` is FP aggregation noise
  (inherent to SQL float SUM under parallel plans), display-identical → ship.
  Use `atol/rtol`, not `check_exact=True` alone.
- **Don't** use a `#temp`/session table — `run_query` opens a fresh pooled
  connection per call (5-wide), so a temp table won't survive across queries.
  Inline `VALUES` is the transport.
- **Don't** forget the 1000-row `VALUES` cap — chunk + `UNION ALL` (the league
  pool is thousands of batters).
- **Don't** drop `repr()` + `CAST(... AS float)` on the inlined floats — a
  rounded threshold flips borderline rows between cleaned/kept.
- **Don't** re-query the percentile in `build_ev_values_cte` — reuse the
  lru-cached `_get_batter_ev_p95`, single-flighted under a lock so the 5-wide
  fan-out triggers exactly one sort.
- **Don't** mutate the raw DB value. The EV "nulling" is an in-query filter; raw
  `Astros.Hits.hit_exit_speed` is never written. A later pitch-by-pitch tool
  chooses whether to apply `clean_ev_misreads(df, season)` (Python helper) — it
  is NOT cleaned everywhere by default and is NOT gcOBA-specific.

---

## Reference impls

| Piece | File |
|---|---|
| Machinery (canonical) | `barrelsville/src/database.py` (`build_ev_values_cte`, `_resolve_ev_cte`, run_query hook) + `bullpen-report/src/database.py` |
| Sentinel swap | `barrelsville/src/tracker_data.py` `_EV_CTE` ; `bullpen-report/src/tracker_data.py` `_inject_ev_misread_cleaning` |
| Diff harness | `barrelsville/scripts/diff_ev_precompute.py` + `bullpen-report/scripts/diff_ev_precompute.py` |
| Scope / phasing plan | `pd-goals/docs/plans/2026-06-24-ev-p95-precompute-phase1.md` |

## Cross-references
- `query-performance.md` — run its SQL diagnostic BEFORE reaching for precompute;
  this pattern is the "step 6" when the heavy thing is genuinely scope-independent
  and reused across queries.
- `pooled-percentile-pattern.md` / `fielding.md` — the scope-DEPENDENT percentile
  pools this pattern must NOT touch.
- `never-round-until-display.md` — the FP-noise verdict here is consistent: the
  drift is below display precision; round once at display.
- `tracker-parquet-pins.md` — the daily pin jobs this optimizes.
