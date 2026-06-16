# xwOBA Canonical — BLOCKING (READ THIS BEFORE TOUCHING ANY HITTING METRIC)

## The non-negotiable

**Every script. Every app. Every worktree. Every xwOBA value MUST match
GC2's per-PA xwoba within ±0.001 (rounding noise).** No exceptions.
Same rule applies to wOBA and gcOBA. We get fired if coordinators or
management catch us .003 off.

This rule is the **single source of truth** for the migration sweep.
If you change the rule, update every file in the surface map below.
If you add a new surface, register it here AND wire it through the
canonical helper. Inline xwoba formulas are forbidden.

---

## The math (memorize this)

```
xwoba = SUM(per_PA_contribution) / COUNT(per_PA_contribution)

per_PA_contribution:
    if BB or HBP:       w_bb  ← THIS PA's GAME'S LEAGUE w_bb
                        ← IBB falls here too (IBB rows have BB=1 in our schema).
                          GC2: `when bb=1 or hbp=1 then 1.0 * Woba.woba_bb`
                          NO IBB exclusion (May 18 2026 fix to match GC2).
    if AB or SF (BIP):  (1 - p_hr^e_hr) * Σ(p_X^e_X * w_X) / Σ(p_X^e_X) + p_hr^e_hr * w_hr
                        ← w_1b, w_2b, w_3b, w_hr from THIS PA's GAME'S LEAGUE
                        ← falls back to actual outcome if all probs zero
    if AB or SF (no HP): actual outcome × THIS PA's GAME'S LEAGUE weights
    if SH or other:     NULL (excluded)
```

### wOBA math (different from xwOBA on IBB)

```
wOBA = (w_bb*(BB-IBB) + w_hb*HBP + w_1b*1B + w_2b*2B + w_3b*3B + w_hr*HR)
       / (AB + BB - IBB + SF + HBP)
```

**Critical asymmetry**: xwOBA INCLUDES IBB as walk. wOBA SUBTRACTS IBB
from both numer (in the BB-IBB term) and denom. Documented divergence
in GC2 reference SQL — match it exactly. See `woba-rules.md` for full
wOBA reference.

**The key word is "THIS PA's GAME'S LEAGUE".** Every PA looks up its
own game's league for the weight set. NOT the batter's level. NOT
the batter's primary league. NOT the level's AVG across leagues.
THIS PA's GAME's LEAGUE.

That's what GC2 does:
```sql
LEFT JOIN guts.woba_lwts Woba
    ON Woba.year = MlbamSchedule.year
   AND Woba.league = MlbamSchedule.league
```

GC2 reads the league from `mlbam.Schedule` for that game and matches
the wOBA weights row exactly. We mirror this 1:1.

---

## The Hector Salas reference case (verified May 18 2026)

Single batter, three levels, three leagues, one season:

| Level | League | PA | xwOBA at level |
|---|---|---:|---|
| Low A | Carolina (CAR) | 37 | .385 |
| A+ | South Atlantic (SAL) | 3 | .095 |
| AA | Texas (TEX) | 12 | .370 |

**Correct combined xwoba (GC2):**
```
SUM(per_PA contribution) / COUNT(non-IBB PA)
  = (0.385 × 37 + 0.095 × 3 + 0.370 × 12) / (37 + 3 + 12)
  = (14.245 + 0.285 + 4.440) / 52
  = 18.970 / 52
  = .3648 → .364 / .365
```

PA-weighted average of per-level xwobas is mathematically identical
to pooling all PAs and dividing (so long as each per-level xwoba was
itself computed with that level's league weights).

**Salas is THE canonical multi-level test case.** Any surface that
shows .367 instead of .364 has the bug class below. Diagnostic:
`barrelsville/scripts/diagnose_xwoba_vs_gc2.py --batter-id <salas_gc_id> --season 2026`.

---

## The bug class

**ONE weights dict applied to all PAs across multiple levels →
wrong-league weights for the PAs at other levels → .003+ drift.**

Visible signature: a multi-level batter's combined xwoba differs from
GC2 by .002-.010. Single-level batter looks correct. Two-level batter
shows partial drift proportional to PA split. Three-level batter (Salas)
shows full drift.

Two failure modes:

1. **Python helper that takes ONE weights dict**: e.g.
   `compute_xwoba(pa_df, pitch_df, weights, exps)` where `weights` is
   a single dict applied to every PA in `pa_df`. This is the postgame
   pattern.

2. **SQL with `:w_*` params**: weights are passed as SQL bind
   parameters and applied to every PA in the query. This is the
   pre-fix pattern for tracker/KPI/org_kpi.

The fix for failure mode 2 (per-pitch JOIN) was shipped May 18 2026
across 4 surfaces. The fix for failure mode 1 (helper signature
upgrade + postgame migration) is **PENDING** — see §"Migration map"
below for status.

---

## The two canonical fix patterns

### Pattern A — SQL per-pitch JOIN (for SQL-aggregate surfaces)

Mirrors GC2's SQL exactly. Each PA gets its game's league weights.

```sql
LEFT JOIN mlbam.Schedule ms ON ms.game_pk = sv.mlbam_game_pk
LEFT JOIN Guts.woba_lwts woba
    ON woba.year = sv.year AND woba.league = ms.league
```

Then reference `woba.woba_bb`, `woba.woba_1b`, etc. inline in the
xwoba CASE expression. **Drop all `:w_*` SQL params.**

When the caller needs an early-season prior-year fallback for weights,
pin `woba.year = :lookup_year` instead of `woba.year = sv.year` —
all PAs in current season look up either current-year or prior-year
weights consistently.

**Use this pattern for:** tracker_data.py, weekly_hitter_data.py,
hitter_kpi_data.py, org_kpi_data.py, drift_hitting.py (if it ever
gets xwoba), and any future SQL-aggregate surface.

### Pattern B — Python compute_xwoba with per-PA weight columns (for Python row-walkers)

For surfaces that iterate per-PA in Python (postgame is the live
example), the helper signature MUST accept per-PA weight columns on
the pa_df. **This is a pending refactor of `xwoba_canonical.py`.**

Target signature:

```python
def compute_xwoba(pa_df, pitch_df, exps, *, weights_dict=None):
    """
    Two calling conventions:

    Multi-level (REQUIRED for any batter who may have played
    multiple leagues/levels): pa_df has per-PA weight columns
    `w_bb`, `w_1b`, `w_2b`, `w_3b`, `w_hr` populated upstream
    (typically via SQL JOIN to mlbam.Schedule + Guts.woba_lwts).
    `weights_dict` is None or ignored. compute_xwoba reads weights
    from the row.

    Single-level (legacy fallback — DEPRECATED, only use when you
    can prove every PA is from one league): pass `weights_dict`,
    the helper applies it to every PA.
    """
```

Each PA row carries its own weights (from per-pitch JOIN at SQL
fetch time). compute_xwoba reads `row['w_bb']`, `row['w_1b']`, etc.
for the per-PA contribution calculation.

Callers fetch per-PA weights via the same per-pitch JOIN as Pattern A,
then pass the joined dataframe into `compute_xwoba`. The helper does
the rest.

**Migration step before adopting Pattern B:** every existing call site
of `compute_xwoba(pa_df, pitch_df, weights, exps)` needs an audit. If
the batter could be multi-level, the caller needs to switch to the
per-PA-weights convention. Single-level calls keep working via the
fallback for now but should migrate eventually so there's truly one
source of truth.

### Pattern C — Wrapper for SUM/COUNT in SQL (lowest-effort migration for some scripts)

For batch scripts that need just the combined xwoba number for a
batter and don't need per-PA detail, the simplest fix is to do the
entire xwoba aggregation in SQL with Pattern A's per-pitch JOIN and
return `SUM(xwoba_contrib) / NULLIF(COUNT(xwoba_contrib), 0) AS xwoba`.
No Python helper needed.

Use this for one-off analysis scripts that don't share any logic with
the live apps. Don't use this for live app surfaces — Pattern B keeps
the Python helper as the single source of truth.

---

## Migration map — FULL STATE (May 18 2026 — MIGRATION COMPLETE)

### ✅ ALL DONE — every xwoba surface now uses per-pitch JOIN or per-PA helper

**Pattern A — SQL per-pitch JOIN** (`LEFT JOIN MLBAM.Schedule + Guts.woba_lwts` on `(year, league)`):

| Surface | File | Commit |
|---|---|---|
| Weekly Hitter PDF | `barrelsville/src/weekly_hitter_data.py` | `459e4384` |
| Hitter KPI Weekly chart | `barrelsville/src/hitter_kpi_data.py::_ORG_DAILY_QUERY` | `f64431f4` |
| Hitter KPI Weekly per-batter | `barrelsville/src/hitter_kpi_data.py::_XWOBA_QUERY` | `f64431f4` |
| Affiliate Tracker season | `barrelsville/src/tracker_data.py::_XWOBA_QUERY` | `2e732b46` |
| Affiliate Tracker monthly | `barrelsville/src/tracker_data.py::_MONTHLY_XWOBA_QUERY` | `2e732b46` |
| Affiliate Tracker weekly | `barrelsville/src/tracker_data.py::_WEEKLY_XWOBA_QUERY` | `2e732b46` |
| Affiliate Tracker org components | `barrelsville/src/tracker_data.py::_ORG_XWOBA_COMPONENTS_QUERY` | `2e732b46` |
| Tracker wRC+ pool | `barrelsville/src/tracker_data.py::_get_league_wrcplus_distribution` | `2e732b46` |
| PD Goals Org KPI hitting | `pd-goals/src/org_kpi_data.py::_HITTING_ORG_QUERY` | `792282ec` |
| PD Goals wRC+ by level | `pd-goals/src/org_kpi_data.py::wrc_by_level_query` | `792282ec` |
| **Postgame percentiles** | `barrelsville/src/postgame_percentiles.py::_BATTER_XWOBA_QUERY` | `c83d8aac` |
| **Sugar Land matrix** | `barrelsville/src/sugar_land_la_ev_data.py` | `f74c42e4` |
| **PoC research** | `barrelsville/src/poc_research_data.py` | `f85274b1` |
| **dsl_to_a batch** | `barrelsville/scripts/dsl_to_a_analysis.py` (2 SQL blocks) | `7cf92f04` |
| **heart_zone batch** | `barrelsville/scripts/heart_zone_report.py` (3 SQL blocks) | `7cf92f04` |
| **zsw exploration** | `barrelsville/scripts/exploration/zsw_analysis.py` | `7cf92f04` |
| **splitter batch** | `pd-goals/scripts/splitter_analysis.py` | `d851a86e` |
| **Postgame heatmap pool** (`xwoba_pa` enrichment) | `barrelsville/src/postgame_data.py::_get_season_heatmap_data` + `_enrich_season_heatmap` | `d3e8218d` |
| **`_query_timeframe.pitch_query`** (powers hitter_analysis zone heatmaps + hitter_whiff_analysis + kpi_snapshot_3 + diagnose_xwoba via `_enrich_season_heatmap` calls) | `barrelsville/src/postgame_data.py::_query_timeframe` | `231a07b8` (May 22 2026) |

**Pattern B — Python helper with per-PA weight columns:**

| Surface | File | Commit |
|---|---|---|
| Canonical helper upgrade | `barrelsville/src/xwoba_canonical.py` + `pd-goals/src/xwoba_canonical.py` | `a6c81ebe` + `be1bd919` (sibling sync) |
| **Postgame xwoba (per-batter)** | `barrelsville/src/postgame_data.py::_compute_xwoba` + pa_query | `d3e8218d` |
| Canonical Python weights helper | `barrelsville/src/woba_weights.py` + `pd-goals/src/woba_weights.py` | `0f133c70`, `a0f46c0a` |

**Confirmed clean (no migration needed):**

| Surface | Note |
|---|---|
| Arm Farm pitcher tracker | No xwoba computation — verified via grep |
| Intangibles (BR/OF/IF/Catcher) | No xwoba — wrong domain |
| `pd-goals/src/drift_hitting.py` | No xwoba — only wOBA via Python formula |
| `barrelsville/scripts/diagnose_xwoba*.py` (3 files) | Diagnostic tools — meant to compute different variants, leave alone |
| `barrelsville/scripts/generate_slg_vs_xslg_heatmap.py` | No xwoba — only xSLG (uses total-base weights 1/2/3/4, not wOBA weights) |
| `barrelsville/scripts/generate_yoy_hitter_report.py` | No xwoba — only xSLG (same as above) |

**Audit verification (May 18 2026):**
```
grep -lrnE ":w_bb|:w_1b|:w_2b|:w_3b|:w_hr" src/ scripts/   # all 4 worktrees
# → ZERO results — every :w_* SQL param has been replaced by woba.woba_* JOIN reference
```

---

## Required upgrade — `xwoba_canonical.py::compute_xwoba`

This is the **first task** of the next session. Without this upgrade,
Pattern B isn't available and postgame can't be fixed properly.

### Target signature

```python
def compute_xwoba(
    pa_df: pd.DataFrame,
    pitch_df: pd.DataFrame,
    exps: Dict[str, float],
    weights_dict: Optional[Dict[str, float]] = None,
    bip_codes: tuple = (12, 13, 14),
) -> Optional[float]:
    """Canonical xwOBA. Two modes:

    MULTI-LEVEL (preferred): pa_df has per-PA weight columns w_bb, w_1b,
    w_2b, w_3b, w_hr populated by SQL JOIN upstream. Reads weights
    per-row. `weights_dict` is None.

    SINGLE-LEVEL (deprecated, fallback): pa_df has no weight columns,
    caller passes `weights_dict` — helper applies it to every PA.
    """
```

### Per-PA weight column SQL fetch pattern (callers use this)

```sql
SELECT
    ev.sched_id, ev.event_id,
    ev.bb, ev.ibb, ev.hbp, ev.ab, ev.sf, ev.[1b] AS h1b, ev.[2b] AS h2b, ev.[3b] AS h3b, ev.hr,
    woba.woba_bb AS w_bb,
    woba.woba_1b AS w_1b,
    woba.woba_2b AS w_2b,
    woba.woba_3b AS w_3b,
    woba.woba_hr AS w_hr
FROM Astros.Events_View ev
JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND pv.cur_event_id = ev.event_id
JOIN Astros.Schedule_View sv ON ev.sched_id = sv.sched_id
LEFT JOIN mlbam.Schedule ms ON ms.game_pk = sv.mlbam_game_pk
LEFT JOIN Guts.woba_lwts woba
    ON woba.year = sv.year AND woba.league = ms.league
WHERE pv.batter_id = :batter_id
  AND ...
```

`pitch_df` separately holds the per-pitch BIP rows with HP probabilities
(unchanged from current shape).

### What changes inside compute_xwoba

`_compute_pa_contribution(pa, hp_by_event, weights, exps)` becomes
`_compute_pa_contribution(pa, hp_by_event, exps, weights_dict=None)`.
When `weights_dict is None`, read weights from `pa['w_bb']`, `pa['w_1b']`,
etc. Otherwise read from `weights_dict['bb']`, etc. (legacy path).

The `_actual_outcome_weight` fallback inside the helper reads from the
same source (per-PA columns or weights_dict).

### Sibling sync

Both barrelsville and pd-goals copies of `xwoba_canonical.py` get the
same upgrade in one commit each. md5sum verify byte-identical.

### Callers post-upgrade

| Caller | Update |
|---|---|
| `barrelsville/src/postgame_data.py::_compute_xwoba` | Refactor SQL fetch to include per-PA weight columns. Drop `weights = get_woba_weights(...)` and pass nothing to `weights_dict`. Helper reads per-row. |
| `barrelsville/scripts/diagnose_xwoba_vs_gc2.py` | Update if it calls compute_xwoba (verify) |
| `barrelsville/scripts/diagnose_xwoba.py` | Same |

---

## Diagnostic test cases — verify EVERY migration

Run after EACH surface migration. Three test cases cover the matrix:

1. **Single-league single-level**: Xavier Neyens (244959), 2026, A
   level. Expected xwoba = .415 (GC2 verified May 18 2026).

2. **Single-league at higher level**: Sacco AA 2026. Expected xwoba
   ≈ .332 gcOBA matches; xwoba should match GC2 (any tiny drift =
   bug).

3. **Multi-level (THE Salas case)**: Hector Salas, 2026, all three
   levels (Low A + A+ + AA, 52 PA total). Expected xwoba = .364
   (GC2). Anything else = bug.

Diagnostic script: `barrelsville/scripts/diagnose_xwoba_vs_gc2.py`.
Add Salas multi-level test if not already there.

---

## Same discipline applies to wOBA + gcOBA

xwoba is the focus today. But:

- **wOBA**: same league-first weight requirement. Multi-level batters
  also drift here. Currently several Python paths use level-AVG
  `_get_woba_weights(season, level_code)`. List in `multi-level-rollup.md`.
- **gcOBA**: matches GC2 today (postgame Sacco .332 perfect). Don't
  touch without diagnostic verification. The formula has many
  components; any drift would compound.

A future sweep needs to apply the same per-PA weight discipline to
wOBA computations. Same Pattern A / Pattern B split applies (SQL
surfaces JOIN per-pitch; Python helpers accept per-PA columns).

Don't ship a wOBA migration without diagnostic verification on the
same three test cases (Neyens, Sacco, Salas).

---

## Canonical SQL constant — `WOBA_WEIGHTS_JOIN`

`xwoba_canonical.py` exports `WOBA_WEIGHTS_JOIN`, a single SQL fragment
that every wOBA / xwOBA / wRC+ surface MUST inject instead of
duplicating the JOIN. Sibling-synced byte-identical across
`barrelsville/src/` and `pd-goals/src/`.

```python
from .xwoba_canonical import WOBA_WEIGHTS_JOIN

query = """
SELECT ev.batter_id,
    woba.woba_bb AS w_bb, woba.woba_1b AS w_1b, woba.woba_2b AS w_2b,
    woba.woba_3b AS w_3b, woba.woba_hr AS w_hr, woba.woba_hb AS w_hb,
    woba.woba_overall, woba.woba_scale, woba.runs_per_pa  -- wRC+ inputs
FROM Astros.Events_View ev
JOIN Astros.Pitches_View pv ON pv.sched_id = ev.sched_id AND pv.cur_event_id = ev.event_id
JOIN Astros.Schedule_View sv ON sv.sched_id = ev.sched_id
""" + WOBA_WEIGHTS_JOIN + """
WHERE ...
"""
```

**Contract (BLOCKING)**:
- Caller MUST have `Astros.Schedule_View sv` already joined (alias `sv`).
- Constant produces aliases `ms` (MLBAM.Schedule) and `woba` (aggregated Guts.woba_lwts).
- AVG-aggregate baked in via subquery for safety against multi-row
  `(year, league)` entries (AL/NL split rows at MLB level).
- Each PA gets THIS PA's GAME's league weights → matches GC2 exactly.

## WOBA_WEIGHTS_JOIN injection — BLOCKING f-string trap (May 18 2026)

When injecting `WOBA_WEIGHTS_JOIN` into a query via `""" + WOBA_WEIGHTS_JOIN + """`,
the SECOND triple-quote MUST match the f-string status of the ORIGINAL query.

```python
# Module-level .format()-style query → second half STAYS """ (NOT f""")
_XWOBA_QUERY = """
SELECT ...
""" + WOBA_WEIGHTS_JOIN + """
WHERE {level_filter}     ← stays literal until .format() runs at runtime
"""

# Function-body f-string query → second half MUST be f"""
def fetch_xwoba(batter_id, level_filter):
    xwoba_sql = f"""
    SELECT ...
    """ + WOBA_WEIGHTS_JOIN + f"""
    WHERE {level_filter}    ← f-string interpolates Python local
    """
```

**Wrong f-string status → broken queries:**
- `"""` on second half of a function f-string → `{level_filter}` stays LITERAL → SQL syntax error
- `f"""` on second half of a module-level .format() query → NameError at module import

**Identify which is which BEFORE editing**: read the query's opening line.
- `_NAME = """` → module-level, use `"""` after WOBA
- `_NAME = f"""` → module-level f-string (rare, usually a config), use `f"""` after WOBA
- `name = f"""` inside a function → function-body f-string, use `f"""` after WOBA
- `name = """` inside a function → function-body .format(), use `"""` after WOBA

**Current state per file (verified May 19 2026):**

| File | Site | Type | Required suffix |
|---|---|---|---|
| `barrelsville/src/postgame_data.py` | 3 sites | function-body f-string | `f"""` |
| `barrelsville/src/weekly_hitter_data.py` | 1 site | function-body f-string | `f"""` |
| `barrelsville/src/sugar_land_la_ev_data.py` | 1 site | module-level f-string | `f"""` |
| `barrelsville/src/poc_research_data.py` | 1 site | module-level f-string | `f"""` |
| `barrelsville/src/hitter_kpi_data.py` | 2 sites | module-level .format() | `"""` |
| `barrelsville/src/tracker_data.py` | 4 sites | module-level .format() | `"""` |
| `barrelsville/src/postgame_percentiles.py` | 1 site | module-level .format() | `"""` |
| `pd-goals/src/org_kpi_data.py` line ~842 | module-level .format() | `"""` |
| `pd-goals/src/org_kpi_data.py` line ~1036 | function-body f-string (wrc_by_level_query) | `f"""` |

## TODO — future canonicalization (not done as of May 19 2026)

The above per-file checklist is fragile. The right architectural fix is to
switch from concat-based injection to a sentinel-based pattern that works
uniformly across both f-string and .format() queries:

```python
# In xwoba_canonical.py:
WOBA_WEIGHTS_JOIN_PLACEHOLDER = "/*__WOBA_WEIGHTS_JOIN__*/"  # SQL-safe sentinel

# In every query file (no triple-quote concat needed):
_XWOBA_QUERY = """
SELECT ...
/*__WOBA_WEIGHTS_JOIN__*/
WHERE {level_filter}
"""

# At module load (one line per file):
_XWOBA_QUERY = _XWOBA_QUERY.replace(WOBA_WEIGHTS_JOIN_PLACEHOLDER, WOBA_WEIGHTS_JOIN)
```

This works for both styles because:
- The sentinel `/*__WOBA_WEIGHTS_JOIN__*/` is a valid SQL comment (won't choke parsing if .replace() misses)
- It has no `{` so f-string and .format() don't interfere
- One `.replace()` per file, no concat magic

When the metric churn slows, refactor every site to this pattern.

**Even better**: a single `build_xwoba_query(driver, scope_filter, ...)` Python
function that returns the complete SQL string with CASE + WOBA_WEIGHTS_JOIN +
filters all injected. Like `clean_bat_speed_per_player` — one function, every
caller imports. Half-day refactor; eliminates this entire bug class permanently.

## What NOT to do

- **Don't write a new inline xwoba formula** anywhere. Period. Every
  surface routes through canonical `compute_xwoba` (Python) or the
  per-pitch JOIN SQL pattern.
- **Don't duplicate the wOBA weights JOIN** — use `WOBA_WEIGHTS_JOIN`
  constant from `xwoba_canonical.py`. Per-pitch JOIN to MLBAM.Schedule +
  Guts.woba_lwts is centralized so future changes are one-edit.
- **Don't exclude IBB from xwoba.** GC2 treats IBB as walk in xwoba
  (`when bb=1 or hbp=1 then 1.0 * Woba.woba_bb` — no IBB filter). Our
  schema has BB=1 on IBB rows, so IBB falls into the BB/HBP branch
  naturally. **DIFFERENT from wOBA** where IBB IS subtracted from both
  numer (`BB - IBB`) and denom (`AB + BB - IBB + SF + HBP`). May 18
  2026 fix to match GC2 (Sacco AA case).
- **Don't pass a single weights dict** to compute_xwoba for any
  batter who might be multi-level. Use per-PA weights. If you don't
  know whether a batter is multi-level, use per-PA weights anyway —
  it works for single-level too.
- **Don't use `level_code = X` AVG-across-leagues** as a weight
  source. Ever. League-first only.
- **Don't key hp_by_event on `event_id` alone** — must be
  `(sched_id, event_id)`. Cross-game contamination bug (Sacco .350 →
  .423 incident, fixed `dc7a7c97`).
- **Don't ship a migration without all three diagnostic cases
  passing** (Neyens single-league, Sacco single-league, Salas
  multi-level). If any of the three drift, the surface is broken.
- **Don't diverge the sibling `xwoba_canonical.py` copies**. md5sum
  before commit. Same with `woba_weights.py`.
- **Don't add or modify `compute_xwoba`'s IBB handling without
  explicit user direction.** GC2 includes IBB at woba_bb weight; we
  exclude. Documented divergence — change only if asked.
- **Don't claim a migration is "everywhere" without running the full
  grep audit.** Audit command lives below.

---

## Audit command — run before every "done" claim

```bash
# Find every file still computing xwoba in any form
for wt in /c/Users/Owner/bsb-resources/pd-goals \
         /c/Users/Owner/bsb-wt-hitting/barrelsville \
         /c/Users/Owner/bsb-wt-bullpen/bullpen-report \
         /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/intangibles; do
    echo "=== $wt ==="
    grep -lrn ":w_bb\|:w_1b\|:w_2b\|:w_hr\|prob_hr\|xwoba_contrib\|xwoba_numer" \
        "$wt/src/" "$wt/scripts/" 2>/dev/null | grep -v __pycache__ | sort -u
done
```

Every result that isn't in the "DONE" list above is unfinished work.
The audit is the source of truth for migration completeness — not
my claim, not a memo, the audit.

---

## Bug history

- **May 22 2026 — `_query_timeframe` was missed in the original May 18
  migration; surfaced when hitter_analysis zone heatmaps went blank.**
  `_enrich_season_heatmap` (commit `d3e8218d`) upgraded to require
  `season_year` + per-pitch `w_bb`/`w_1b`/`w_2b`/`w_3b`/`w_hr` columns
  on its input df. But `_query_timeframe.pitch_query` (used by
  `hitter_analysis.py:1115` + several other scripts) was never updated
  in that sweep — its SELECT lacked all those columns. Result: the
  early-return guard at `postgame_data.py:548` (`year is None`) fired,
  `xwoba_pa` stayed all-NaN, `_compute_zone_xwoba` filtered to empty,
  heatmaps rendered blank. Fixed in `231a07b8` on `feature/barrelsville`
  by adding `YEAR(sv.sched_date) AS season_year` + `CAST(ev.pa AS int)
  AS is_pa` + per-pitch `woba.woba_*` columns to `_query_timeframe`'s
  pitch_query SELECT and injecting `WOBA_WEIGHTS_JOIN` (replaced the
  standalone `LEFT JOIN MLBAM.Schedule ms` which the WOBA_WEIGHTS_JOIN
  now provides). Migration map updated to register `_query_timeframe`
  as a fixed surface.

  **Lesson for the next agent:** when a downstream consumer
  (`_enrich_*` helper) gets upgraded to require new columns, audit
  ALL of its upstream callers in the same commit. Grep for every
  function that builds pitch_df / pa_df and passes them in. Today's
  bug went undetected for 4 days because the original migration
  audit only checked surfaces that directly computed xwoba, not
  surfaces that fed into the helper.

- **May 18 2026 (late evening — MIGRATION COMPLETE, all 10 outstanding
  files + helper upgrade shipped)**: After the audit revealed Salas
  .367 in postgame (vs GC2 .364), executed the full migration sweep
  in one session.
  - `a6c81ebe` + `be1bd919` — upgraded `compute_xwoba` helper to accept
    per-PA weight columns (`w_bb`, `w_1b`, ...) on pa_df. Single-dict
    mode preserved for backward compat. Sibling copies byte-identical.
  - `d3e8218d` — postgame `_compute_xwoba` + heatmap pool migrated to
    per-pitch JOIN. Fixes Salas multi-level bug. Per-pitch weights ride
    on pa_df via SQL JOIN to mlbam.Schedule + Guts.woba_lwts. Drops
    mode-league single-dict lookup entirely.
  - `c83d8aac` — postgame_percentiles `_BATTER_XWOBA_QUERY` per-pitch JOIN.
  - `f74c42e4` — Sugar Land matrix per-BIP JOIN.
  - `f85274b1` — PoC research per-BIP JOIN.
  - `7cf92f04` — dsl_to_a_analysis (2 SQL blocks) + heart_zone_report
    (3 SQL blocks) + zsw_analysis per-pitch JOIN.
  - `d851a86e` — splitter_analysis per-pitch JOIN with per-row weight
    computation in Python.
  - Audit verification: `grep -lrnE ":w_bb|:w_1b|..." src/ scripts/`
    across all 4 worktrees returns ZERO. Every xwoba surface now uses
    Pattern A (SQL per-pitch JOIN) or Pattern B (Python helper per-PA
    mode). MIGRATION COMPLETE.
  - Salas verification deferred to next work-laptop session (DB
    access). Expected: postgame should report .364 (matching GC2)
    instead of .367.

- **May 18 2026 (evening — audit + Salas case revealed scope gap)**:
  Hector Salas multi-level test exposed that postgame's compute_xwoba
  applies ONE weights dict to all PAs, breaking multi-level batters.
  Diagnostic showed Salas .367 in postgame vs GC2 .364 (PA-weighted
  per-level math = .365 ≈ .364 rounding). This rule rewritten to
  capture the full migration scope including the helper upgrade and
  all 13 outstanding files. User direction: every surface must match
  GC2 within ±.001, no exceptions, document everything in one place,
  next session executes the rest.

- **May 18 2026 (afternoon — migration sweep partial)**: All 4
  SQL-aggregate surfaces (tracker, weekly_hitter, hitter_kpi,
  org_kpi_data) migrated to per-pitch league JOIN. Canonical
  woba_weights.py helper created. 5 surfaces done; postgame +
  postgame_percentiles + 8 other files still pending. Commits:
  `0f133c70`, `a0f46c0a`, `459e4384`, `f64431f4`, `2e732b46`,
  `792282ec`, `a97eda0c` (rule update).

- **May 18 2026 (morning — postgame fixes)**: Two postgame xwoba bugs.
  1. hp_by_event keyed on event_id alone → cross-game contamination.
     Sacco AA .350 → .423. Commit `dc7a7c97`.
  2. get_woba_weights averaged across leagues within level. Neyens A
     .408 → .415 to match GC2. Commit `3d820583`.

---

## Cross-references

- `woba-rules.md` — wOBA formula + weights + GC2 SQL reference. Note
  the rule says "for per-level aggregation use level + AVG" — that
  was the PRE-MAY-18 canon. As of May 18 2026 the new direction is
  league-first PER-PA via per-pitch JOIN, matching GC2 exactly. The
  woba-rules.md text needs updating in the next pass.
- `three-surface-parity.md` — tracker ↔ KPI weekly ↔ PD Goals
  parity. After this migration all three surfaces match each other
  AND match GC2 (instead of matching each other at a drifted level-
  AVG value).
- `bat-speed-canonical.md` — pattern reference. xwoba follows the
  same "ONE place, every caller imports" discipline.
- `multi-level-rollup.md` — multi-level aggregation rules including
  the per-metric n_obs weighting iron rule. xwoba aggregates by PA
  count which is naturally additive across levels.
- `rules/reference-impl-index.md` — quick lookup for canonical
  implementations per metric. Update after each migration.
- `rules/event-vs-pitch-anchored.md` — event vs pitch driver
  decision. xwoba SQL is event-anchored (drives from Events_View).
