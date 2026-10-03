# Catcher Pooled-Percentile Port — Migration Plan

**Status:** Pending — gated on fielding deploy verification.
**Worktree:** `bsb-wt-intangibles/astros-intangibles/intangibles/` (branch `feature/astros-intangibles`).
**Canonical reference:** `intangibles/src/fielding_tracker_data.py` raw-obs refactor (commits `b084ce6f` → `d1a9b129`, May 22-23 2026).
**Driving rule:** `.claude/rules/pooled-percentile-pattern.md` (BLOCKING).

---

## Scope

Port the fielding raw-obs pooled-percentile pattern to **catcher's 5 per-catcher percentile metrics**:

| Metric | Current weighting | Source | Range filter |
|---|---|---|---|
| Arm strength P99 | weighted-mean by `n_arm` | `Astros.Tracking_Defensive_Metrics` (pos_id=2 catcher throws) | 60-94 mph |
| Exchange P10 | weighted-mean by `n_exch` | TDM | ≥ 0.4 sec, arm ≥ 60 |
| Pop2B P01 | weighted-mean by `n_throws_2b` | TDM | 1.70-2.35 sec |
| Pop3B P01 | weighted-mean by `n_throws_3b` | TDM | 1.40-1.85 sec |
| AugPop P01 | weighted-mean by `n_sba_events` | `Astros.CatcherDefense_SBA_Metrics` | aug_pop populated |

**OUT of scope (don't touch):**
- NetK, FramRAA, BlockRAA, SurPP, framing buckets, R2K%, Depth — all SUM/COUNT/MEAN metrics, naturally additive across levels, already correct
- Framing buckets if/when they become per-catcher percentiles (e.g., "framing P25 vs LHP")
- Hand-split on existing framing/non-percentile catcher metrics — KEEPS hand split (real platoon effect, umpire call differences vs L/R hitter)

---

## Hand-dependence decision

**Skip hand-split on the new raw_obs catcher pins.** Arm, Pop, Exchange, AugPop are pitcher-hand-AGNOSTIC physically — the throw / pop / exchange motion is the same regardless of pitcher hand.

Existing hand-split keys (`catchers_l`, `catchers_r`, etc.) STAY for the existing framing/NetK/non-percentile metrics. The new raw_obs keys live alongside as hand-agnostic pins.

Pin keys:
- Existing: 63 (7 prefixes × 3 H/A × 3 hand) — unchanged
- New: 9 raw_obs keys (3 prefixes × 3 H/A × 1 hand) — added
- **Total:** 72 keys per (year, domain)

---

## Implementation plan (mirrors fielding refactor exactly)

### Phase 1 — SQL queries (Task 8a)

In `intangibles/src/catching_tracker_data.py`, add 2 raw-obs queries below the existing `_ORG_*_QUERY` block:

**`_RAW_TDM_CATCHER_QUERY`** — every qualifying TDM throw for catchers:
```python
_RAW_TDM_CATCHER_QUERY = """
SELECT
    tdm.groundcontrol_id AS catcher_id,
    UPPER(mt.org_abbrev) AS org,
    CASE WHEN sv.gc2_level_code = 'dsl' THEN 'dsl'
         ELSE sv.level_code END AS level,
    sv.year AS season,
    tdm.arm_strength,
    tdm.exchange,
    tdm.pop_time_2b,
    tdm.pop_time_3b
FROM Astros.Tracking_Defensive_Metrics tdm
JOIN Astros.Schedule_View sv ON tdm.sched_id = sv.sched_id
LEFT JOIN MLBAM.Teams mt
    ON mt.team_id = tdm.fielding_team_id AND mt.season = sv.year
WHERE tdm.pos_id = 2          -- catcher only
  AND sv.year IN (<PINNED_YEARS>)
  AND sv.sched_type = 'R'
  AND sv.level_code NOT IN (<junk codes>)
  AND tdm.groundcontrol_id IS NOT NULL
  AND (tdm.arm_strength IS NOT NULL
       OR tdm.exchange IS NOT NULL
       OR tdm.pop_time_2b IS NOT NULL
       OR tdm.pop_time_3b IS NOT NULL)
{level_filter} {sched_filter} {ha_filter}
"""
```

**`_RAW_AUGPOP_CATCHER_QUERY`** — every qualifying AugPop event:
```python
_RAW_AUGPOP_CATCHER_QUERY = """
SELECT
    sba.groundcontrol_id AS catcher_id,
    UPPER(mt.org_abbrev) AS org,
    CASE WHEN sv.gc2_level_code = 'dsl' THEN 'dsl'
         ELSE sv.level_code END AS level,
    sv.year AS season,
    sba.aug_pop
FROM Astros.CatcherDefense_SBA_Metrics sba
JOIN Astros.Schedule_View sv ON sba.sched_id = sv.sched_id
LEFT JOIN MLBAM.Teams mt
    ON mt.team_id = sba.fielding_team_id AND mt.season = sv.year
WHERE sv.year IN (<PINNED_YEARS>)
  AND sv.sched_type = 'R'
  AND sv.level_code NOT IN (<junk codes>)
  AND sba.aug_pop IS NOT NULL
{level_filter} {sched_filter}
"""
```

Plus thin wrappers:
- `_get_raw_tdm_catcher(season, sched_types, ha_split)`
- `_get_raw_augpop_catcher(season, sched_types)` — NO `ha_split` for AugPop since SBA events are H/A-independent at metric level

### Phase 2 — Pin schema (Task 8b)

In `intangibles/src/tracker_pins.py` (or wherever catcher prefix constants live):

```python
PREFIX_RAW_TDM_CATCHER = "raw_tdm"      # follows fielding naming convention
PREFIX_RAW_AUGPOP_CATCHER = "raw_augpop"
```

Add both to `ALL_CATCHER_PREFIXES` so `write_tracker_bundle` enforces presence.

`_try_pin_raw_obs_catcher(season, ha_split)` gate function — mirror fielding's:
- Gates: pins importable, season in PINNED_YEARS, sched_types canonical, ha_split in (None, 0, 1)
- Returns `(raw_tdm_df, raw_augpop_df)` or None
- Multi-year concats year bundles

### Phase 3 — Pooled compute helpers (Task 8c)

Two helpers in `catching_tracker_data.py`:

```python
def _compute_pooled_indiv_catcher_from_raw_obs(
    raw_tdm: pd.DataFrame,
    raw_augpop: pd.DataFrame,
    level_codes: List[str],
    seasons: List[int],
    min_throws: int = 1,
    ...
) -> pd.DataFrame:
    """Filter raw obs to scope. Per-catcher np.percentile on
    arm/exch/pop/augpop. Per-metric n_X count. Mirror SQL display gates."""

def _compute_pooled_org_catcher_from_raw_obs(
    raw_tdm: pd.DataFrame,
    raw_augpop: pd.DataFrame,
    level_codes: List[str],
    seasons: List[int],
    ...
) -> pd.DataFrame:
    """Per-catcher percentile → org weighted-mean by per-metric n_X."""
```

Wire into existing `get_catcher_leaderboard` + `get_org_rankings`:
- Check `_try_pin_raw_obs_catcher` FIRST when multi-level OR multi-year
- Fall back to existing SQL path on miss
- Single-level + single-year + no special filter → still goes through existing per-level pins (those are faster for that case)

### Phase 4 — Parity diagnostic (Task 8d)

`scripts/diag_pooled_parity_catcher.py` mirrors `scripts/diag_pooled_parity.py`:
- Path A: new raw_obs path
- Path B: existing `_get_pooled_indiv_stats` / `_get_pooled_org_stats` SQL (the current weighted-mean approximation)

**Expected:** parity will FAIL initially because the existing path uses weighted-mean approximation that is mathematically wrong. The fix path should diverge by 1-3% on multi-level catchers. **This is the goal** — we want the new path to match TRUE pooled, not the existing approximation.

Adjust the parity test to compare new raw_obs against **direct PERCENTILE_CONT computed on the full pooled scope** (skip the existing per-level + weighted-mean step):

```sql
-- "True pooled" reference SQL (parity TARGET, not the existing path)
SELECT catcher_id,
    PERCENTILE_CONT(0.99) WITHIN GROUP (
        ORDER BY CASE WHEN arm_strength BETWEEN 60 AND 94
                      THEN arm_strength END
    ) OVER (PARTITION BY catcher_id) AS arm_p99,
    -- ... pop, exch
FROM Astros.Tracking_Defensive_Metrics tdm
JOIN Schedule_View sv ON ...
WHERE tdm.pos_id = 2
  AND sv.year IN (:seasons)
  AND sv.level_code IN (:levels)
  AND sv.sched_type = 'R'
```

Tolerance: ±0.05 mph on arm, ±0.01 sec on pop/exch, ±0.5 on counts.

### Phase 5 — Pin CLI integration (Task 8e)

In `intangibles/scripts/pin_catching_tracker_seasons.py`, after the existing per-level pin writes per H/A, add:

```python
# Raw observations for pooled percentile metrics (hand-agnostic — no hand variant)
print(f"  [catcher/{year}/{tag}] raw_tdm ...", end=" ", flush=True); t0 = time.time()
df = _get_raw_tdm_catcher(season=year, sched_types=sched, ha_split=ha)
print(f"{len(df)} rows ({time.time() - t0:.1f}s)")
out[bundle_key(PREFIX_RAW_TDM_CATCHER, ha)] = df

# AugPop is H/A-independent at metric level, only write for ha=None
if ha is None:
    print(f"  [catcher/{year}/all] raw_augpop ...", end=" ", flush=True); t0 = time.time()
    df = _get_raw_augpop_catcher(season=year, sched_types=sched)
    print(f"{len(df)} rows ({time.time() - t0:.1f}s)")
    out[bundle_key(PREFIX_RAW_AUGPOP_CATCHER, None)] = df
```

No pooled-combo loop to remove — catcher never had one (it was always weighted-mean approximation, not pre-aggregated).

---

## Verification sequence (user, work laptop)

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles

# 1. Pull
git pull

# 2. Parity check — MUST pass before pin CLI runs
python scripts/diag_pooled_parity_catcher.py

# 3. If parity green, re-pin 2026
python scripts/pin_catching_tracker_seasons.py --year 2026

# 4. Spot-check in app:
#    - Pick known multi-level catcher (Salazar shuffles AAA↔MLB, Salas multi-level 2026)
#    - Compare Arm/Pop/Exch values to pre-port (should drift slightly toward TRUE pooled)
#    - Compare HOU MLB-only AAA Arm P99 to fielding OF Arm P99 sanity check

# 5. Backfill historical years (~6 min each)
python scripts/pin_catching_tracker_seasons.py --year 2025
python scripts/pin_catching_tracker_seasons.py --year 2024
python scripts/pin_catching_tracker_seasons.py --year 2023
python scripts/pin_catching_tracker_seasons.py --year 2022

# 6. Redeploy Connect-scheduled pin job
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "..."
.\connect_pins_catcher\deploy.ps1
```

---

## Expected impact on display values

Catchers who played multiple levels in a single season will see Arm/Pop/Exch values shift by 1-3% (typically toward the more-thrown level's value, since true pooled gives that level proportional weight via raw observation count rather than via weighted-mean of per-slice P-values).

Per-org HOU rollup values will shift correspondingly. Same direction.

Single-level + single-year displays unchanged (math identical for that scope).

---

## Estimated effort

- Phase 1 (SQL queries): ~1 hr
- Phase 2 (pin schema + gate): ~30 min
- Phase 3 (compute helpers): ~2 hr (mirror fielding closely)
- Phase 4 (parity diag): ~1 hr
- Phase 5 (CLI integration): ~30 min
- Re-pin time: ~6 min/year × 5 years = ~30 min user wait
- **Total dev effort:** ~5 hours

---

## What NOT to do

- **Don't add hand-split to raw_obs catcher pins.** Arm/Pop/Exch/AugPop are hand-agnostic. Adding hand-split = 3× pin work for zero analytical value.
- **Don't replace the existing per-level pins** — they still serve single-level scenarios + KPI weekly + PD-Goals org. Raw_obs is ADDITIVE.
- **Don't ship without parity passing** against the "true pooled" reference SQL. Expected to diverge from EXISTING SQL (which is wrong) — that's the fix.
- **Don't change framing percentile metrics if any get added later** without re-asking the hand-dependence question. Framing IS hand-dependent (umpire call differences vs L/R hitter).
- **Don't run the new pin CLI in production until parity passes** + at least one multi-level catcher hand-eyeball test confirms reasonable values.

---

## Cross-references

- `.claude/rules/pooled-percentile-pattern.md` — canonical pattern + 5-piece implementation
- `.claude/rules/multi-level-rollup.md` — Iron Rule for per-metric weighting
- `.claude/rules/three-surface-parity.md` — tracker / KPI weekly / PD-Goals invariants (catcher percentile parity will tighten after this port)
- `intangibles/src/fielding_tracker_data.py` — canonical reference (raw_obs refactor, May 22-23 2026)
- `scripts/diag_pooled_parity.py` — template for parity diagnostic
- `docs/plans/2026-05-23-br-pooled-percentile-port.md` — sibling port for BR
