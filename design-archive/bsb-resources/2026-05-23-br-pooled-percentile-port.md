# BR Pooled-Percentile Port — Migration Plan

**Status:** Pending — gated on fielding deploy verification + catcher port completion (or parallel).
**Worktree:** `bsb-wt-intangibles/astros-intangibles/intangibles/` (branch `feature/astros-intangibles`).
**Canonical reference:** `intangibles/src/fielding_tracker_data.py` raw-obs refactor (May 22-23 2026).
**Driving rule:** `.claude/rules/pooled-percentile-pattern.md` (BLOCKING).

---

## Scope

Port the fielding raw-obs pooled-percentile pattern to **BR's 5 per-runner percentile metrics**:

| Metric | Current weighting | Source | Notes |
|---|---|---|---|
| TopSpd P95 | weighted-mean by `n_speed` | `groundcontroltracking.Tracking.Baserun_Tracking_Metrics` (btm) | Per-play raw |
| React P25 | weighted-mean by `n_react` | btm | Lower = better |
| Time-to-22 P25 | weighted-mean by `n_t22` | btm | Lower = better |
| Split 1 P25 | weighted-mean by `n_s1` | btm | Lower = better |
| Accel Overall P75 | weighted-mean by `n_accel` | btm | Higher = better |

**OUT of scope (don't touch):**
- SB, CS, 1→3, 2→H — cumulative SUMs, naturally additive across levels
- 1B PL/SL, 2B PL/SL — AVG lead distances (means, not percentiles). Hand-split applies here (real pitcher-handedness effect on runner lead posture) — STAYS.
- TimesOn, BasesOn — cumulative counts

---

## Hand-dependence decision

**Skip hand-split on the new raw_obs BR pins.** TopSpd, React, T22, Split1, Accel are pitcher-hand-AGNOSTIC physically — same sprint motion regardless of who threw the pitch.

Existing hand-split keys for lead metrics (`runners_l`, `runners_r`) STAY — those handle PL/SL/lead-related metrics where pitcher handedness genuinely changes runner posture. The new raw_obs keys live alongside as hand-agnostic pins.

Pin keys:
- Existing: 63 (7 prefixes × 3 H/A × 3 hand) — unchanged
- New: 9 raw_obs keys (3 prefixes × 3 H/A × 1 hand) — added
- **Total:** 72 keys per (year, domain)

---

## Implementation plan (mirrors fielding refactor exactly)

### Phase 1 — SQL queries (Task)

In `intangibles/src/br_tracker_data.py`, add a raw-obs query below the existing `_ORG_*_QUERY` block:

**`_RAW_BTM_RUNNER_QUERY`** — every qualifying Baserun_Tracking_Metrics row:
```python
_RAW_BTM_RUNNER_QUERY = """
SELECT
    btm.runner_groundcontrol_id AS runner_id,
    UPPER(mt.org_abbrev) AS org,
    CASE WHEN sv.gc2_level_code = 'dsl' THEN 'dsl'
         ELSE sv.level_code END AS level,
    sv.year AS season,
    btm.top_speed,
    btm.reaction_time,
    btm.time_to_22,
    btm.split_1,
    btm.acceleration_overall
FROM groundcontroltracking.Tracking.Baserun_Tracking_Metrics btm
JOIN Astros.Schedule_View sv ON btm.sched_id = sv.sched_id
JOIN Astros.Events_View ev ON btm.sched_id = ev.sched_id AND btm.event_id = ev.event_id
LEFT JOIN MLBAM.Teams mt
    ON mt.team_id = ev.batting_team_id AND mt.season = sv.year
WHERE sv.year IN (<PINNED_YEARS>)
  AND sv.sched_type = 'R'
  AND sv.level_code NOT IN (<junk codes>)
  AND btm.runner_groundcontrol_id IS NOT NULL
  AND (btm.top_speed IS NOT NULL
       OR btm.reaction_time IS NOT NULL
       OR btm.time_to_22 IS NOT NULL
       OR btm.split_1 IS NOT NULL
       OR btm.acceleration_overall IS NOT NULL)
{level_filter} {sched_filter} {ha_filter}
"""
```

Plus thin wrapper:
- `_get_raw_btm_runner(season, sched_types, ha_split)`

### Phase 2 — Pin schema

In `intangibles/src/tracker_pins.py` (or wherever BR prefix constants live):

```python
PREFIX_RAW_BTM_RUNNER = "raw_btm"
```

Add to `ALL_BR_PREFIXES` so `write_tracker_bundle` enforces presence.

`_try_pin_raw_obs_br(season, ha_split)` gate function — mirror fielding's:
- Gates: pins importable, season in PINNED_YEARS, sched_types canonical, ha_split in (None, 0, 1)
- Returns `raw_btm_df` or None
- Multi-year concats year bundles

### Phase 3 — Pooled compute helpers

Two helpers in `br_tracker_data.py`:

```python
def _compute_pooled_indiv_runner_from_raw_obs(
    raw_btm: pd.DataFrame,
    level_codes: List[str],
    seasons: List[int],
    min_plays: int = 1,
    ...
) -> pd.DataFrame:
    """Filter raw obs to scope. Per-runner np.percentile on the 5
    tracking metrics. Per-metric n_X count. Apply same display gates
    (min_plays) as SQL path."""

def _compute_pooled_org_runner_from_raw_obs(
    raw_btm: pd.DataFrame,
    level_codes: List[str],
    seasons: List[int],
    ...
) -> pd.DataFrame:
    """Per-runner percentile → org weighted-mean by per-metric n_X."""
```

Wire into existing `get_runner_leaderboard` + `get_org_rankings`:
- Check `_try_pin_raw_obs_br` FIRST when multi-level OR multi-year
- Fall back to existing SQL path on miss
- Single-level + single-year → use existing per-level pins (faster for that case)

### Phase 4 — Parity diagnostic

`scripts/diag_pooled_parity_br.py` mirrors `scripts/diag_pooled_parity.py`:
- Path A: new raw_obs path
- Path B: "true pooled" reference SQL (NOT the existing weighted-mean approximation, which is what we're correcting)

```sql
-- "True pooled" reference SQL (parity TARGET)
SELECT runner_id,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY top_speed)
        OVER (PARTITION BY runner_id) AS top_speed_p95,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY reaction_time)
        OVER (PARTITION BY runner_id) AS reaction_p25,
    -- ... t22, split1, accel
FROM groundcontroltracking.Tracking.Baserun_Tracking_Metrics btm
JOIN Schedule_View sv ON ...
WHERE sv.year IN (:seasons)
  AND sv.level_code IN (:levels)
  AND sv.sched_type = 'R'
```

Tolerance:
- ±0.05 ft/s on TopSpd
- ±0.005 sec on React / T22 / Split1
- ±0.05 ft/s² on Accel
- ±0.5 on counts

### Phase 5 — Pin CLI integration

In `intangibles/scripts/pin_br_tracker_seasons.py`, after the existing per-level pin writes per H/A, add:

```python
# Raw observations for pooled percentile metrics (hand-agnostic — no hand variant)
print(f"  [BR/{year}/{tag}] raw_btm ...", end=" ", flush=True); t0 = time.time()
df = _get_raw_btm_runner(season=year, sched_types=sched, ha_split=ha)
print(f"{len(df)} rows ({time.time() - t0:.1f}s)")
out[bundle_key(PREFIX_RAW_BTM_RUNNER, ha)] = df
```

No pooled-combo loop to remove — BR never had one (it was always weighted-mean approximation).

---

## Verification sequence (user, work laptop)

```powershell
cd C:\Users\zbridger\bsb-wt-intangibles\intangibles

# 1. Pull
git pull

# 2. Parity check — MUST pass before pin CLI runs
python scripts/diag_pooled_parity_br.py

# 3. If parity green, re-pin 2026
python scripts/pin_br_tracker_seasons.py --year 2026

# 4. Spot-check in app:
#    - Pick known multi-level runner (any prospect promoted mid-season)
#    - Compare TopSpd P95 / React P25 values to pre-port (should drift toward TRUE pooled)

# 5. Backfill historical years
python scripts/pin_br_tracker_seasons.py --year 2025
python scripts/pin_br_tracker_seasons.py --year 2024
python scripts/pin_br_tracker_seasons.py --year 2023
python scripts/pin_br_tracker_seasons.py --year 2022

# 6. Redeploy Connect-scheduled pin job
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "..."
.\connect_pins_br\deploy.ps1
```

---

## Expected impact on display values

Runners who played multiple levels in a single season will see TopSpd P95 / React P25 / T22 P25 / Split1 P25 / Accel P75 shift by 0.5-2% (typically toward the more-tracked level's value, since true pooled gives that level proportional weight via raw observation count rather than via weighted-mean of per-slice P-values).

Per-org HOU rollup values will shift correspondingly.

Single-level + single-year displays unchanged.

---

## Estimated effort

- Phase 1 (SQL queries): ~1 hr (simpler than catcher — 1 query vs 2)
- Phase 2 (pin schema + gate): ~30 min
- Phase 3 (compute helpers): ~2 hr (mirror fielding/catcher closely)
- Phase 4 (parity diag): ~1 hr
- Phase 5 (CLI integration): ~30 min
- Re-pin time: ~6 min/year × 5 years = ~30 min user wait
- **Total dev effort:** ~5 hours

---

## What NOT to do

- **Don't add hand-split to raw_obs BR pins.** TopSpd/React/T22/Split1/Accel are hand-agnostic. PL/SL hand-split STAYS on existing pins — those metrics are NOT in this port.
- **Don't touch lead metrics (PL/SL).** Those are means, not percentiles, hand-dependent (real pitcher-handedness effect). Outside this rule.
- **Don't replace existing per-level pins** — they still serve single-level scenarios + KPI weekly + PD-Goals org. Raw_obs is ADDITIVE.
- **Don't ship without parity passing** against the "true pooled" reference SQL.
- **Don't bias the parity diagnostic toward the existing weighted-mean approximation** — we want to verify the new path matches TRUE pooled SQL, NOT the existing approximation (which is what we're correcting).

---

## Cross-references

- `.claude/rules/pooled-percentile-pattern.md` — canonical pattern + 5-piece implementation
- `.claude/rules/multi-level-rollup.md` — Iron Rule for per-metric weighting
- `intangibles/src/fielding_tracker_data.py` — canonical reference (raw_obs refactor, May 22-23 2026)
- `intangibles/src/br_tracker_data.py` — current implementation (weighted-mean approximation in `aggregate_org_across_levels`)
- `scripts/diag_pooled_parity.py` — template for parity diagnostic
- `docs/plans/2026-05-23-catcher-pooled-percentile-port.md` — sibling port for catcher
