---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---

# wOBA / xwOBA Rules

## wOBA Weights (`Guts.woba_lwts`)
- WE HAVE DB ACCESS. Query by `level_code` + `year`
- One blanket set per level per year. NO sched_type filtering
- **Columns:** `woba_bb`, `woba_hb` (NOT `woba_hbp`!), `woba_1b`, `woba_2b`, `woba_3b`, `woba_hr`
- Python dict key is `"hbp"` but DB column is `woba_hb`. Audited Mar 12 — `woba_hbp` crashes
- Hardcoded fallback: `_DEFAULT_WOBA_WEIGHTS = {"bb": 0.69, "hbp": 0.72, "1b": 0.88, "2b": 1.24, "3b": 1.56, "hr": 2.01}`

### BLOCKING — Always AVG() when querying Guts.woba_lwts
`Guts.woba_lwts` can have multiple rows per `(year, level_code)` for league splits (AL/NL at MLB level, etc.). Every query must aggregate:
```sql
SELECT AVG(woba_bb), AVG(woba_hb), AVG(woba_1b), ...
FROM Guts.woba_lwts WHERE year = :y AND level_code = :lc
```
Never `SELECT woba_bb` + `.iloc[0]` — picks up an arbitrary league split. Same rule for the `wOBA`/`wOBA_scale`/`runs_per_pa` league environment columns.

### BLOCKING — Weights are per-level, never blended
Org-level queries across multiple levels MUST resolve the weight PER-LEVEL, not average the weights across levels first.
- Tracker pattern: query each level separately, pass that level's weights as flat `:w_bb`, `:w_1b` params.
- PD-Goals pattern: single query across all levels, JOIN `Guts.woba_lwts` per-pitch on `(year, level_code)` with `AVG()` per-pair in the subquery.
- **Never** compute `AVG(woba_bb) FROM Guts.woba_lwts WHERE level_code IN (...)` and apply the blended result to every pitch. Distorts per-level xwOBA/wOBA for any org with mixed-level PAs.

### BLOCKING — Weight lookup_year falls back to season-1 before May
`Guts.woba_lwts` typically doesn't have current-year rows until mid-season. If current month < 5, use `season - 1` as lookup year. Both tracker (`_get_woba_weights`) and PD-Goals (`_lookup_year_for_weights`) must agree on this behavior. If the JOIN/query silently produces NULL weights, xwoba_numer becomes NULL and pitches drop from the numerator — drift is asymmetric and hard to diagnose.

## xwOBA Exponents (`Guts.hit_specs_ratios`)
- DB ACCESS GRANTED (Feb 23). `lru_cached` query by season
- Exponents are global (no level dimension)

### BLOCKING — xwOBA exponents do NOT fall back to prior year
Unlike wOBA weights (which DO fall back before May), xwOBA exponents query `:season` DIRECTLY. Tracker's `_get_hit_specs_exponents` has no prior-year fallback. If PD-Goals or any other helper adds one, they diverge from tracker year-round (produces ~0.003 xwoba gap — verified Apr 20 2026, see `memory/hitting-org-parity-apr20.md`).

If the current-year row is missing in `Guts.hit_specs_ratios`, fall back to `{exp_1b: 1.0, exp_2b: 1.0, exp_3b: 1.0, exp_hr: 1.0, exp_fo: 1.0}` (identity — makes POWER a no-op). **Never** the `{5.0, 5.0, ...}` fallback currently in `hitter_kpi_data.py` — that's a latent inconsistency pending standardization.

## wOBA Denominator — BLOCKING
**Always `AB + BB - IBB + HBP + SF`** (FanGraphs standard). Excludes SH.

NEVER substitute `COUNT(pa=1 AND ibb=0)` or `SUM(is_pa)` — those INCLUDE SH because `ev.pa=1` for sacrifice hits in Astros DB. A SH has no bb/hbp/ab/sf flag but `ev.pa=1`, so a simple "PA count" inflates the wOBA denom and drops wOBA (and wRC+) by ~1 point.

This is distinct from the **"PA" display column** (K%, BB% denom) which uses `SUM(ev.pa) + SUM(ev.ibb)` = total PA including IBB and SH. Both conventions coexist — apply the right one per metric.

**xwOBA denom** = `AB + BB + HBP + SF` per GC2 reference (May 19 2026 update). **IBB IS counted in xwoba denom AND contributes woba_bb to numer — GC2 treats IBB as walk in xwoba.** OPPOSITE of wOBA which subtracts IBB from both. See `xwoba-canonical.md` for canonical helper + WOBA_WEIGHTS_JOIN constant.

## wOBA Numerator — Two Canonical Patterns

Two valid shapes for computing the numerator. Pick based on whether you're aggregating in SQL or Python. **Both produce identical values when weights are constant within the GROUP** — which they are for per-batter-per-level aggregation.

### Pattern A: Inline SQL `AVG(weight) * SUM(event)` (GC2 production pattern)
Use when aggregating entirely in SQL:
```sql
SELECT pv.batter_id,
    (AVG(w.woba_bb) * SUM(CAST(ev.bb AS INT) - CAST(ev.ibb AS INT))
   + AVG(w.woba_hb) * SUM(CAST(ev.hbp AS INT))
   + AVG(w.woba_1b) * SUM(CAST(ev.[1b] AS INT))
   + AVG(w.woba_2b) * SUM(CAST(ev.[2b] AS INT))
   + AVG(w.woba_3b) * SUM(CAST(ev.[3b] AS INT))
   + AVG(w.woba_hr) * SUM(CAST(ev.hr AS INT)))
   / NULLIF(SUM(CAST(ev.ab AS INT) + CAST(ev.bb AS INT) - CAST(ev.ibb AS INT)
              + CAST(ev.hbp AS INT) + CAST(ev.sf AS INT)), 0) AS woba
FROM Astros.Events_View ev
LEFT JOIN Astros.Pitches_View pv ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
...
LEFT JOIN Guts.woba_lwts w ON ...
GROUP BY pv.batter_id
```
Canonical ref: GC2's Event query (per user's Apr 22 reference dump).

### Pattern B: Python post-fetch from component counts (app pattern)
Use when the app already has PA-component columns (ab, bb, ibb, hbp, sf, h1b, h2b, h3b, hr) per batter in a DataFrame:
```python
weights = _get_woba_weights(season, level_code)  # fetches AVG'd weights as dict
ibb = df["ibb"].fillna(0)
woba_denom = df["ab"] + df["bb"] - ibb + df["hbp"] + df["sf"]
woba_numer = (weights["bb"] * (df["bb"] - ibb)
              + weights["hbp"] * df["hbp"]
              + weights["1b"] * df["h1b"]
              + weights["2b"] * df["h2b"]
              + weights["3b"] * df["h3b"]
              + weights["hr"] * df["hr"])
df["woba"] = np.where(woba_denom > 0, woba_numer / woba_denom, np.nan)
```
Canonical refs: `barrelsville/src/tracker_data.py` line ~1080, `barrelsville/src/hitter_kpi_data.py::get_player_table_data` line ~1270.

### Never: `SUM(weight × event)` via CROSS JOIN pre-averaged subquery
```sql
-- ANTI-PATTERN — shipped as a bug Apr 22 2026, source of PA inflation + wrong results
CROSS JOIN (SELECT AVG(woba_bb) AS w_bb, ... FROM Guts.woba_lwts ...) w
SELECT SUM(w.w_bb * CAST(ev.bb AS INT) - ...) AS woba_num
```
Algebraically looks equivalent but breaks if weight ever varies within the GROUP (multi-league batter, multi-level batter with different weights per level). Always use Pattern A (inline AVG) or Pattern B (Python post-fetch with per-level weights).

## Weight JOIN Key — BLOCKING

The wOBA weights JOIN key depends on scope:

| Scope | JOIN key | Canonical ref |
|---|---|---|
| **Per-level aggregation** (what our apps do) | `wl.year = sv.year AND wl.level_code = sv.level_code`, AVG across league splits | `pd-goals/src/org_kpi_data.py:_HITTING_ORG_QUERY` |
| **GC2-parity replication** (per-league granularity) | `wl.year = ms.year AND wl.league = ms.league` via `mlbam.schedule ms` | GC2 production Event query |
| **Single batter, single level** | Fetch weights once via `_get_woba_weights(season, level_code)` as dict, apply in Python | `barrelsville/src/hitter_kpi_data.py:_get_woba_weights` |

**For per-level aggregation (our primary app pattern), ALWAYS use `level_code` + AVG across league splits.** This is what all three app surfaces (tracker, KPI weekly, PD-Goals org KPI) agree on, and it's what the three-surface-parity audit verified.

**Only use `league` JOIN when explicitly replicating a GC2 production report** — not for our standard app outputs.

## GC2 Production SQL — How They Actually Compute These (verified May 19 2026 from Salas's player page SQL)

User pulled GC2's actual production SQL for the Salas/Sacco multi-level
wOBA/wRC+/gcOBA computation. Documented for future reference so we know
exactly what we're matching against.

### wOBA pattern: GC2 uses **Pattern A** (`AVG(weight) × SUM(events)`)
```sql
(AVG(Woba.woba_BB) * SUM(BB - IBB)
 + AVG(Woba.woba_HB) * SUM(HBP)
 + AVG(Woba.woba_1B) * SUM([1B])
 + AVG(Woba.woba_2B) * SUM([2B])
 + AVG(Woba.woba_3B) * SUM([3B])
 + AVG(Woba.woba_HR) * SUM(HR))
/ NULLIF(SUM(AB + BB - IBB + SF + HBP), 0)
```

### Math equivalence ONLY when weights are constant within the GROUP
GC2 player page **GROUPs BY `BattingTeam.league`** — every row is one
league (TEX, PCL, CAR, etc). Within each row, weights are constant,
so `AVG(weight)` is identity. Pattern A and our Pattern B
(`SUM(per-PA-weight × per-PA-event) / SUM(per-PA-denom)`) give
**identical numbers per-stint**.

For a TRUE multi-level combined value (Salas across CAR + SAL + TEX):
GC2 displays per-stint rows; no rollup query for combined was shown
in their player-page SQL. **Our Pattern B SUM-per-PA approach gives
the correct combined value automatically** — each PA carries its
game's league weight.

This explains the May 18-19 multi-level bug we just fixed: the old
codepath applied ONE level-AVG weight set to all PAs (worst of both
patterns). Now Pattern B per-PA matches GC2 per-stint AND aggregates
correctly across stints.

### wRC+ formula: byte-identical
GC2: `100 * ((player_woba - AVG(Woba.wOBA)) / AVG(Woba.wOBA_scale) + AVG(Woba.runs_per_pa)) / AVG(Woba.runs_per_pa)`
Ours: `compute_wrc_plus()` in `xwoba_canonical.py` — same formula.

### gcOBA formula: byte-identical (uses `mlbam.YTD_Team_Batting_Stats` MLB OBP)
GC2 fetches league OBP from `mlbam.YTD_Team_Batting_Stats` with the
year-month-5 fallback. Our Python `_get_level_obp(season, "mlb")`
applies the same fallback. Both produce identical lg_obp inputs.

### wOBA weight JOIN key: GC2 uses `mlbam.schedule.year/league`, we use `sv.year`
GC2's JOIN:
```sql
left join mlbam.schedule MlbamSchedule on Schedule.mlbam_game_pk = MlbamSchedule.game_pk
left join guts.woba_lwts Woba on MlbamSchedule.year = Woba.year and MlbamSchedule.league = Woba.league
```

Ours (`WOBA_WEIGHTS_JOIN` in `xwoba_canonical.py`):
```sql
LEFT JOIN MLBAM.Schedule ms ON ms.game_pk = sv.mlbam_game_pk
LEFT JOIN Guts.woba_lwts (AVG'd subquery) woba ON woba.year = sv.year AND woba.league = ms.league
```

Same JOIN topology, year sourced from `Schedule_View` (sv) instead of
MLBAM.Schedule (ms). If those ever disagree on `year` for the same
sched_id, we'd diverge by tiny amounts — unlikely (year on both sides
should match a game's actual calendar year). Document as known
possible edge case; not seen in practice.

### Why we don't perfectly match GC2 on .001 drift
Even with byte-identical formulas, .001 wOBA drift can come from:
1. Float accumulation order (`SUM` order in SQL vs Python aggregation)
2. AVG of woba_lwts rows when GC2 has unsplit single-row leagues vs our
   AVG'd subquery (identity in practice, but the rounding boundary in
   the last decimal can flip)
3. SQL `ROUND` (half-away-from-zero) vs Python `round` (banker's)

**Accept .001 drift as noise floor across surfaces.** The metric-meaningful
bug (level-AVG vs per-PA weights, ~.005-.007 drift on multi-level
batters) is fixed via Pattern B. Below-.001 drift requires a 6-8 hour
unification refactor with marginal coach-visible benefit.

## Reference Implementations — see `rules/reference-impl-index.md`

Before drafting any wOBA / wRC+ / xwOBA / gcOBA SQL, open the canonical implementation:
- wOBA per-batter SQL: `pd-goals/src/org_kpi_data.py::_HITTING_ORG_QUERY` (line ~720)
- wOBA per-batter Python: `barrelsville/src/tracker_data.py` line ~1080
- wOBA weights fetch: `barrelsville/src/hitter_kpi_data.py::_get_woba_weights` line 145
- League env: `barrelsville/src/hitter_kpi_data.py::_get_league_woba_env` line 191
- xwOBA exponents: `barrelsville/src/hitter_kpi_data.py::_get_hit_specs_exponents`

Driver table choice (Events_View vs Pitches_View): see `rules/event-vs-pitch-anchored.md`.

## xwOBA Formula
`POWER(prob, exp) * woba_weight` for each outcome (1b, 2b, 3b, hr, fo), summed per BIP

**Inputs:** `Astros.Hits_Probabilities` (per-BIP probs) + exponents (from DB) + wOBA weights (from DB)

**xwOBA INCLUDES IBB as walk** (May 19 2026 — matches GC2 reference SQL `when bb=1 or hbp=1 then 1.0 * Woba.woba_bb`, no IBB filter). IBB contributes `woba_bb` to numer and +1 to denom. **DIFFERENT from wOBA** which subtracts IBB from both numer (`BB - IBB`) and denom (`AB + BB - IBB + SF + HBP`).

## wRC+ League Context
- `_get_league_woba_env()` uses league-specific row when `mlbam_league` available (Astros=AL)
- Falls back to level_code AVG
- **For outcome weights (bb,1b,2b,3b,hr):** level_code AVG is fine (AL/NL nearly identical)

## zxwOBA (Per-Pitch Expected wOBA)
Per-pitch wOBA-scale delta metric. Every pitch gets a value (mid-AB balls/fouls + BIPs).

**Formula:** `zxwoba(pitch) = (post_rv - pre_rv) * wOBA_scale`
- `pre_rv = Count_RE(balls_before, strikes_before)` from `Guts.Count_RE`
- post_rv depends on outcome: mid-AB → next count RV, K → `run_Minus`, BB → `run_BB`, BIP → expected RV from Hits_Probabilities
- Foul on 2K = 0.0 (no count change)

**DB tables:** `Guts.Count_RE`, `Guts.woba_lwts` (wOBA_scale + run values), `Guts.hit_specs_ratios`, `Astros.Hits_Probabilities`

**Normalization:** Own constant `_ZXWOBA_NORM_RANGE = 0.015` (separate from RV Gain's `_RV_NORM_RANGE = 0.05`)

## Barrel Bunt Filter
All barrel/pBarrel calcs exclude bunts (`hit_trajectory_id NOT IN (2,3,4)`). Audited Mar 12.
