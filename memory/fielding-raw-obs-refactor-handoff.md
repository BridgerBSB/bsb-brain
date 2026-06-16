---
name: fielding-raw-obs-refactor-handoff
description: "Fielding raw-obs pin refactor — replaces 120-combo POOLED_LEVEL_COMBOS pin pattern (12+ hr/year) with raw-obs pin (~6 min). PARITY PASSING after May 23 fixes (2beafceb + d1a9b129). Awaits user pin re-run + deploy."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3edb5f3a-5769-45bf-8c1d-54ecd4fda7cf
---

# Fielding Raw-Obs Pin Refactor — Handoff (May 23 2026)

## Status: PARITY EXPECTED GREEN after 2 May 23 fixes — awaiting user re-run + production re-pin

### May 23 2026 fixes (post-parity-diag-failure debugging)

User ran `diag_pooled_parity.py` and got 277 failures, then after first
fix got 85 failures down to 5 fielders. Two commits this session resolved
the math:

1. **`2beafceb` — TRUE pooled PAA/RAA/expected_outs math in raw_obs path.**
   Both `_compute_pooled_from_raw_obs` (per-fielder) and
   `_compute_pooled_org_from_raw_obs` (org). Naive SUM-of-per-slice-paa_cal
   drifts ~2% because each per-slice paa_cal carries per-slice AVG(offset)
   baked in. Correct math: pooled_paa_cal = (SUM(paa)/SUM(out_prob)
   − pooled_AVG_offset) × SUM(out_prob) × pooled_AVG_eo_scalar, where
   pooled_AVG_X = SUM(per_slice_sum_X) / SUM(per_slice_n_X_rows). Mirrors
   SQL AVG() exactly. Both helpers carry sum_offset / sum_eo_scalar /
   n_offset_rows / n_eo_scalar_rows columns through the groupby, then
   re-derive at the pooled tier. Per-org parity moved from 277 failures
   to clean GREEN.

2. **`d1a9b129` — Mirror SQL min_plays>=1 filter.** `_get_pooled_indiv_stats`
   in SQL applies `comp_plays >= min_plays` with default 1. Raw-obs path
   had `if min_plays > 1:` — only fired when caller passed >1, leaving 5
   stragglers with 0 competitive plays in raw_obs output that SQL drops.
   Changed to `if min_plays >= 1:`. Cleans up the last 5 per-fielder
   discrepancies.

### NEXT (user, work laptop)

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles
git pull
python scripts/diag_pooled_parity.py
```

Expected: `PARITY PASS — 0 failures, all green.` If green, proceed to
pin re-run + deploy steps below. If still failing, paste output for
diagnosis.

7 of 8 tasks complete. All code on `feature/astros-intangibles`
(`C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles\`).

| Task | Status | Commit |
|---|---|---|
| 1. Write raw_obs SQL queries | ✅ SHIPPED | `b084ce6f` |
| 2. Build `_compute_pooled_from_raw` helper | ✅ SHIPPED | `9b5404bf` |
| 3. Build `_compute_pooled_org_from_raw` helper | ✅ SHIPPED | `9b5404bf` |
| 4. Pin schema + integration (`_try_pin_raw_obs`, wired into both pooled getters) | ✅ SHIPPED | `cda6af72` |
| 5. Update pin CLI (drop POOLED_LEVEL_COMBOS loop, write 3 raw keys/HA) | ✅ SHIPPED | `ad2fb6c3` |
| 6. Parity diagnostic vs PERCENTILE_CONT SQL | ✅ SHIPPED | `388f9c0e` |
| 7. Commit + push refactor | ✅ DONE (commits above) | — |
| 8. Update rule docs + cross-worktree sync | DEFERRED — next session housekeeping | — |

## NEXT: User work-laptop steps (in order)

```powershell
# 1. Pull latest
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles
git pull

# 2. Run parity diagnostic against live DB — verifies raw_obs path
#    matches existing PERCENTILE_CONT path within tolerance. DO NOT
#    proceed if this fails.
python scripts/diag_pooled_parity.py

#    Optional: spot-check IF and other years
python scripts/diag_pooled_parity.py --domain IF
python scripts/diag_pooled_parity.py --year 2025

# 3. If parity passes — run pin CLI. Should take ~6 min for 2026
#    (3 raw_obs queries × 3 H/A × 2 domains) instead of 12+ hours.
python scripts/pin_fielding_tracker_seasons.py --year 2026

# 4. Verify in app: open intangibles Streamlit, OF/IF tracker page,
#    select 2026 + multi-level (e.g. AAA + AA + A+). Org Rankings +
#    Indiv Leaderboard should be sub-second + values should match
#    pre-refactor. Look for [PIN] raw_obs(...) SERVED FROM PIN in
#    Connect logs.

# 5. Backfill historical years (each ~6 min instead of 12+ hours)
python scripts/pin_fielding_tracker_seasons.py --year 2025
python scripts/pin_fielding_tracker_seasons.py --year 2024
python scripts/pin_fielding_tracker_seasons.py --year 2023
python scripts/pin_fielding_tracker_seasons.py --year 2022

# 6. Redeploy connect_pins_fielding so the Connect-scheduled 6-hour
#    refresh runs the new CLI on current year going forward.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "..."
.\connect_pins_fielding\deploy.ps1
```

**Total estimated time:** ~5 min parity verification, ~60 min full
backfill, ~5 min Connect redeploy. **Vs. the 12+ hour failing runs
the user was hitting on home VPN before this refactor.**

**Why:** The user's 2026 fielding pin backfill on home VPN repeatedly failed
after 6-8+ hours. 120 multi-level combos × 2 prefixes × 3 H/A = 720 pin
keys, each running `PERCENTILE_CONT OVER (PARTITION BY fielder_id)` —
massive redundant work because the same raw observations get re-sorted
into dozens of overlapping percentile pools.

**The user's intuition was right:** the correct math (per
`multi-level-rollup.md` iron rule "Individual = ALWAYS pool raw obs")
points to a much simpler architecture — pin the raw rows once, compute
percentiles client-side via `np.percentile` whenever a user picks a
combo. Same output as the existing SQL (verified math-equivalent for
Nunez Arm 2025+2026 example), ~50× less pin work.

## What's in commit `b084ce6f`

Three new SQL queries inserted in `src/fielding_tracker_data.py` right
after `_ORG_GAMES_QUERY` (around line 1810). All use the existing
`_build_pooled_tracking_query` / `_build_pooled_nontracking_query`
substitution helpers (`{pos_ids}`, `{exchange_col}`, `{level_filter}`,
`{year_filter}`, `{sched_filter}`, `{ha_filter}`, `{arm_lo}`).

| Query | Output |
|---|---|
| `_RAW_TDM_QUERY` | One row per qualifying TDM event after Tier 1 6-term gate. Cols: `fielder_id, org, level, season, pos_id, top_speed, accel_up, accel_down, reaction_time, useful_reaction, reaction_radius, reaction_accuracy_radius, arm_strength, exchange, tdm_cp, tdm_ct, dcbp_cp, dcbp_ct`. `level` collapses DSL/FCL split via `CASE WHEN sv.gc2_level_code = 'dsl' THEN 'dsl' ELSE sv.level_code END`. `org` is per-play (multi-org fielders surface multiple rows). |
| `_RAW_DCBP_QUERY` | Per `(fielder_id, pos_id, level, org, season)` DCBP sums. paa_cal + expected_outs + raa already calibration-adjusted (the JOIN keys on `(pos_id, positional, season)` — level-additive per `pd-goals-defense.md` + GC2 source SQL verification May 20). |
| `_RAW_GAMES_QUERY` | Per `(fielder_id, pos_id, level, season)` game counts. `ha_filter` NOT applied (game counts H/A-independent). Sum-by-level on client side works because each sched_id is at exactly one level. |

Plus 3 new prefix constants in the pin schema:
- `PREFIX_RAW_TDM = "raw_tdm"`
- `PREFIX_RAW_DCBP = "raw_dcbp"`
- `PREFIX_RAW_GAMES = "raw_games"`

**Not yet added to `ALL_FIELDING_PREFIXES`** — that's part of Task 5
(pin CLI update). When added there, `write_tracker_bundle`'s
`expected_prefixes=ALL_FIELDING_PREFIXES` check will require the CLI
to write all 3 new keys per (domain, year, ha).

## What Tasks 2-8 must rebuild client-side

The existing `_INDIV_POOLED_TRACKING_QUERY` does in SQL what we now
need to do in Python. Five pieces, **all of which must match exactly**:

1. **Per-fielder percentile with range filters.** 4 distinct filter
   shapes:
   - `top_speed` P95 with `top_speed <= 34` cap
   - `accel_up`, `accel_down` P75 (no range filter)
   - `reaction_time`, `useful_reaction`, `reaction_radius`,
     `reaction_accuracy_radius` P25 (no range filter)
   - `arm_strength` P99 with `BETWEEN {arm_lo} AND {arm_hi}` (IF=70-108,
     OF=75-108)
   - `exchange` P10 with `exchange >= 0.4 AND arm_strength >= {arm_lo}`
2. **Per-metric count columns** (`n_speed`, `n_accel_up`, `n_react`,
   `n_useful_react`, `n_react_rad`, `n_react_acc_rad`, `n_arm`, `n_exch`)
   — these are the counts of NON-NULL observations passing each
   metric's range filter. Used as the weight column for org-tier
   weighted-mean (per `multi-level-rollup.md` iron rule).
3. **`org_primary` per fielder.** Across the user-selected (level,
   year) scope, count plays per (fielder, org), pick org with most
   plays. SQL uses `ROW_NUMBER OVER (PARTITION BY fielder_id ORDER BY
   n_plays DESC)`.
4. **DCBP rollup** (`_aggregate_dcbp` in fielding_tracker_data.py
   line 2648) — currently takes per (fielder_id, pos_id) rows and:
   - Saves per-position `paa_cal_{pos_label}` + `raa_{pos_label}` cols
     before aggregation (lf/cf/rf for OF, 1b/2b/3b/ss for IF)
   - Sums additive metrics across positions (oaa, raw_paa,
     total_out_prob, outs_made, weighted_drv_sum, dcbp_comp_plays,
     paa_cal, raa, expected_outs)
   - Picks `primary_pos_id` (most dcbp_comp_plays)
   - Re-derives `paa_eo = paa_cal / expected_outs`,
     `raa_eo = raa / expected_outs`
   The raw_obs version takes per (fielder, pos, level, org, season)
   rows. Client-side: filter by selected (level, year) → groupby
   `(fielder_id, pos_id)` → SUM additive → then apply same
   `_aggregate_dcbp` logic.
5. **Org tier weighted-mean.** For each percentile metric, the org
   value is `SUM(per_fielder_value × per_fielder_n_X) / SUM(per_fielder_n_X)`
   where `n_X` is the per-fielder count for THAT metric. NOT
   `comp_plays`. NOT `n_pitches`. Per-metric n_X — see
   `_ORG_POOLED_TRACKING_AGG_QUERY org_agg` CTE (line 1673) for the
   verbatim weighted-mean SQL.

**Plus per-position PAA/RAA pivot at org tier** (`_pivot_per_pos_org_dcbp`
line 3241) — for each org, paa_cal restricted to plays at LF / CF /
RF (or 1B/2B/3B/SS). Filter raw_dcbp by selected levels →
groupby `(org, pos_id)` SUM paa_cal + raa → pivot to columns
`paa_cal_lf` etc.

## Pin design

ONE bundle per (domain, year). Three NEW keys per ha_split (all / home /
away):

```
raw_tdm_all      raw_tdm_home      raw_tdm_away
raw_dcbp_all     raw_dcbp_home     raw_dcbp_away
raw_games_all    raw_games_home    raw_games_away
```

Total 9 new keys per (domain, year). Replaces 720 pooled-combo keys.

Pin write time per (domain, year, ha): ~2 min (3 queries, ~30-60 sec
each). For 3 H/A × 2 domains × 5 years = ~60 min for full backfill.
Not the "~25 min" I optimistically quoted before the deep read.
Connect's 6-hour refresh runs the SAME 3-query CLI for current year
in ~6 min.

Size estimate: raw_tdm ≈ 50-100K rows × 16 cols × ~8 bytes/col = ~10
MB/year/domain (uncompressed). Parquet compresses to ~3-5 MB. raw_dcbp
and raw_games are much smaller. Total bundle size per (domain, year)
should stay under ~50 MB. Fine for Posit Connect pins.

## Pin-first integration design (Task 4)

New helper `_try_pin_raw_obs(domain, season, ha_split)` returns
`(raw_tdm_df, raw_dcbp_df, raw_games_df)` tuple OR None. Gates:
- pins module importable
- single-year selection (multi-year loads multiple bundles + concats)
- canonical sched_types `('R',)`
- ha_split in `(None, 0, 1)` matching pinned combo

Wire into both pooled getters BEFORE the existing PERCENTILE_CONT SQL
fallback:

```python
def get_org_rankings_pooled(domain, level_codes, season, ...):
    raw = _try_pin_raw_obs(domain, season, ha_split)
    if raw is not None:
        return _compute_pooled_org_from_raw(*raw, level_codes, [season], domain)
    # existing SQL fallback (PERCENTILE_CONT path)
    return _get_pooled_org_stats(...)
```

Multi-year case: load multiple year bundles, concat the 3 raw DFs,
then run the helper. Each bundle is ~3-5 MB so loading 3-4 years is
~15-20 MB — fine.

## Pin CLI update (Task 5)

In `scripts/pin_fielding_tracker_seasons.py::_run_df_queries_for_ha`,
REPLACE the `for combo in POOLED_LEVEL_COMBOS:` loop (lines 149-181)
with 3 raw_obs writes:

```python
print(f"  [{domain}/{year}/{tag}] raw_tdm ...", ...); t0 = time.time()
df = _get_raw_tdm(domain, year, sched, ha)
print(f"{len(df)} rows ({time.time() - t0:.1f}s)")
out[bundle_key(PREFIX_RAW_TDM, ha)] = df

# same for raw_dcbp + raw_games
```

`_get_raw_tdm`, `_get_raw_dcbp`, `_get_raw_games` are NEW thin wrappers
around the SQL queries — they go in `fielding_tracker_data.py` and use
the existing `_build_pooled_*_query` helpers with `level_codes=list(_POOLED_BASE_LEVELS)`
+ `seasons=[year]`.

Keep the POOLED_LEVEL_COMBOS loop COMMENTED OUT initially (don't
delete) so we can A/B compare during the parity verification phase.

Add to `ALL_FIELDING_PREFIXES`:
```python
PREFIX_RAW_TDM,
PREFIX_RAW_DCBP,
PREFIX_RAW_GAMES,
```
so the write_tracker_bundle's `expected_prefixes` check enforces their
presence.

## Parity diagnostic (Task 6)

Build `scripts/diag_pooled_parity.py`:
- Loads (2026, all-levels) raw_obs DFs
- Computes pooled output via NEW `_compute_pooled_from_raw` + `_compute_pooled_org_from_raw`
- Computes pooled output via EXISTING `_get_pooled_indiv_stats` + `_get_pooled_org_stats` (live DB)
- Asserts ±0.05 mph match on percentile metrics, ±0.01 match on sums
- Test cases:
  - Nunez 2025+2026 Arm (the canonical multi-level test — should be
    pooled P99 of all 80 throws, NOT weighted-mean of per-year P99s)
  - 2-3 other known multi-level players (look up in fielders_all_all
    pin for any with `level` containing comma)
  - A single-level player (sanity check — values should be unchanged)

If parity holds, the refactor is verified.

## Verification timeline (next session)

1. Implement Tasks 2-3 (Python helpers) — ~3 hr
2. Implement Task 4 (pin schema + wire) — ~30 min
3. Implement Task 5 (pin CLI) — ~30 min
4. Implement Task 6 (parity diagnostic) — ~30 min
5. **Local parity test (no DB)** — synthesize fake raw_obs DFs, run
   helper, check output shape matches `_get_pooled_indiv_stats` shape.
   ~30 min.
6. Commit + push as full refactor (Task 7) — ~10 min
7. Update rule docs across 4 worktrees (Task 8) — ~30 min
8. **Hand off to user for work-laptop tasks:**
   - `git pull` on intangibles worktree
   - Run parity diag against LIVE DB on a few cases — verify ±0.05
     match before re-pinning
   - Run `python scripts/pin_fielding_tracker_seasons.py --year 2026`
     — should complete in ~6 min instead of 12+ hours
   - Spot-check 2026 fielding tracker in Streamlit (multi-level
     selection should be sub-second + same Arm/TopSpd values as
     before)
   - Then full backfill: 2022, 2023, 2024, 2025 (~12 min each)
   - Redeploy `connect_pins_fielding/` so the every-6-hour Connect
     schedule runs new CLI

## Risk areas (read carefully before coding Tasks 2-6)

1. **Percentile range filter typos = drift bug.** If `top_speed <=
   34` becomes `< 34`, or `arm_strength BETWEEN 70 AND 108` becomes
   `BETWEEN 75 AND 108` on the IF helper, percentile values drift
   silently. Range filters MUST match the existing SQL CTE definitions
   byte-for-byte. The 5 distinct filter shapes are documented above
   — copy them exactly.

2. **n_X count must be NON-NULL-after-range-filter, NOT raw COUNT.**
   E.g. `n_arm` is `COUNT(CASE WHEN arm_strength BETWEEN 70 AND 108
   THEN 1 END)` — only counts rows where arm passes the range filter.
   Mirroring in numpy: `n_arm = (df.arm_strength.between(70, 108)).sum()`.
   Getting this wrong shifts the org weighted-mean.

3. **np.percentile interpolation kind.** SQL Server's PERCENTILE_CONT
   uses linear interpolation. numpy's `np.percentile` defaults to
   `linear` interpolation. They should match. Verify with the parity
   diagnostic.

4. **Multi-org fielders (mid-season trade).** raw_tdm has one row per
   play. A fielder traded mid-season has plays under both orgs. The
   org_primary computation must take the user-selected (level, year)
   scope into account — e.g. if user picks only 2026 AAA, only count
   that fielder's 2026 AAA plays for org_primary. SQL does this
   automatically via the `{level_filter}` + `{year_filter}` in the
   base CTE. Client-side: filter raw_tdm first, then groupby (fielder,
   org), then ROW_NUMBER equivalent.

5. **Cross-year scope (multi-year selection).** Less common but
   supported. Load 2024 + 2025 + 2026 raw_tdm pins, concat, treat as
   one DataFrame. `_compute_pooled_from_raw` doesn't care about
   year boundaries — it pools all rows the user selected.

6. **PAA/EO offset is per (pos_id, positional, season).** The raw_dcbp
   query already bakes the calibration into the per-row paa_cal sum.
   So additive across (fielder, pos, level, org, season) rows is
   correct — `paa_cal_total = SUM(paa_cal)` and `expected_outs_total
   = SUM(expected_outs)`. paa_eo re-derives as ratio. Don't try to
   re-apply the offset client-side — already done.

## Files modified in `b084ce6f`

- `intangibles/src/fielding_tracker_data.py` (+183 lines, all additive)

## Reference impls (read these first when resuming)

- `_INDIV_POOLED_TRACKING_QUERY` (line 1368) — SQL pattern to mirror
  for per-fielder pooling
- `_ORG_POOLED_TRACKING_AGG_QUERY` (line 1582) — SQL pattern for org
  tier weighted-mean by per-metric n_X
- `_aggregate_dcbp` (line 2648) — Python DCBP rollup logic (already
  exists; we just need to feed it per (fielder_id, pos_id) sums
  from the level-filtered raw_dcbp instead of from the existing
  pooled SQL)
- `_pivot_per_pos_org_dcbp` (line 3241) — per-position org pivot
- `_get_pooled_indiv_stats` (line 3690) — orchestrator we're replacing
- `_get_pooled_org_stats` (line 3379) — org orchestrator we're replacing
- `_round_metrics` (line 2309) — final format step
- `_clean_org_names` (line 2198) — OAK→ATH remap + UNK drop
- `multi-level-rollup.md` "TWO-TIER ARCHITECTURE" — iron rule

## Cross-references

- [[poc-research-shipped]] — unrelated, different domain
- [[session-2026-05-22-shipped]] — concurrent work, different worktree
- See `.claude/rules/multi-level-rollup.md` "Pooled-combo pinning"
  section — explicitly notes the 120-combo cost was known but
  considered acceptable. This refactor supersedes that approach.
- See `.claude/rules/tracker-parquet-pins.md` §9b — pooled-combo pinning
  doc; update with raw-obs supersession after refactor complete.
