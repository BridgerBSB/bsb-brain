---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---
# Damage% — Cross-App Rounding Standard + Known Filter Divergences

## Rounding standard — BLOCKING (Apr 25 2026)

**Damage% MUST be rounded in PERCENTAGE space, not decimal space, on every
surface that displays it. Canonical pattern:**

```python
# Python (matches Barrelsville canonical):
dmg_pct_display = round(damage_value_decimal * 100, 1)        # if storing % form
# OR
dmg_pct_decimal = round(damage_value_decimal * 100, 1) / 100  # if storing decimal form
```

**NEVER use** `round(damage_decimal, 4)` (the old PD Goals stats.py
pattern). The two strategies diverge by 0.1% at boundary values because
of float representation:

- raw mean `0.045500001` → `round(x, 4)` = `0.0455` → format `4.55` → `"4.5%"` (float repr is `4.5499...`)
- raw mean `0.045500001` → `round(x*100, 1)/100` = `0.046` → format `4.60` → `"4.6%"`

The post-percentage round is **canonical** because it matches what
Barrelsville does in every hitter surface (postgame, weekly, KPI), and
because the displayed precision (`%.1f%`) is already 1 decimal in
percentage space — rounding at the same precision pre-display avoids
boundary-induced display drift.

### Where the canonical pattern lives

| Surface | File | Status |
|---|---|---|
| **PD Goals bar chart** | `pd-goals/src/stats.py:971` | ✓ aligned `c5eaa1b` |
| **PD Goals rolling chart** | `pd-goals/src/rolling_chart.py::compute_cumulative_at_ticks` | ✓ aligned `c5eaa1b` |
| Barrelsville postgame | `barrelsville/src/postgame_data.py:1408` | ✓ canonical (always was) |
| Barrelsville weekly hitter | `barrelsville/src/weekly_hitter_data.py:562` | ✓ canonical |
| Barrelsville hitter KPI | `barrelsville/src/hitter_kpi_data.py` (per-batter `dmg_sum_total / dmg_count_total` then format) | ✓ canonical (no pre-round, format does it) |
| Barrelsville tracker / postgame_percentiles | full precision in SQL, format at display | ✓ canonical |

### Why this matters

A coordinator pulls Frey's Damage% from PD Goals bar chart and from
Barrelsville hitter postgame side-by-side. Same underlying BIPs, same
formula, same filter — but if rounding strategies differ, the displays
can read 4.5% vs 4.6%. Users assume that's a real metric difference and
file it as a bug. It's not — it's float-quantization mismatch.

**Whenever you add a new surface that displays Damage%:** mirror the
canonical post-percentage round. NEVER pre-round in decimal space.

---

## Filter Divergences (KNOWN, NOT YET FIXED)

**Audit date: 2026-04-25.** Audited every Damage% computation across all
four worktrees after fixing the pd-goals rolling chart drift (commit
`6c0f135`). Two divergences remain — explicitly **DEFERRED**, do NOT
fix without user direction.

## Canonical formula

The reference Python implementation is
`pd-goals/src/metrics.py::calculate_damage_vectorized`:

```python
exp_term = (
    np.cos(-0.34) * (ev - 98.0)
    - np.sin(-0.34) * (la - 27.0)
    - 0.02 * (
        2 + np.sin(-0.34) * (ev - 98.0)
        + np.cos(-0.34) * (la - 27.0)
    )**2
)
damage = 1.6 * np.power(1.3, exp_term) / (7.0 + np.power(1.3, exp_term))
```

The canonical BIP filter (matching `pd-goals/src/stats.py:674-697`
hits_query) requires:
- `pitch_result_id IN (12,13,14)`
- `hit_exit_speed IS NOT NULL`
- `hit_exit_speed > 0 AND hit_exit_speed < 125`
- `hit_vertical_angle IS NOT NULL`
- `(hit_trajectory_id NOT IN (2,3,4) OR hit_trajectory_id IS NULL)` (bunt exclusion)
- `NOT (hit_vertical_angle < -25 AND level_code IN ('hsb','sum','bbc'))` (EV misread)

`hit_vertical_angle IS NOT NULL` is the trap. Many existing queries
either (a) rely on NULL propagation through the formula + AVG/SUM
patterns to skip NULL-LA rows implicitly, or (b) fillna(0) / ISNULL(la,0)
which incorrectly treats missing LA as line-drive level and contributes
~0.001 spurious damage per leaked BIP. (b) is the bug. (a) is correct.

## Cross-app status

| Worktree | File | Status | Notes |
|---|---|---|---|
| pd-goals | `src/metrics.py` | CANONICAL | Reference Python impl |
| pd-goals | `src/stats.py` (bar chart hits_query) | ✓ MATCH | Filters BOTH ev IS NOT NULL AND la IS NOT NULL in WHERE |
| pd-goals | `src/rolling_stats.py` | ✓ MATCH | Fixed `6c0f135` — BIP_FILTER constant requires LA not null |
| barrelsville | `src/hitter_kpi_data.py` | ✓ MATCH | Uses `dmg_count_total` (NULL-aware via NULL propagation through formula → AVG skips) |
| barrelsville | `src/tracker_data.py` | ✓ MATCH | `AVG(CASE WHEN ... THEN dmg_formula END)` — NULL skipped by AVG |
| barrelsville | `src/weekly_hitter_data.py` | ✓ MATCH | Same AVG+NULL pattern via `_DMG_SQL` shared fragment |
| barrelsville | `src/postgame_percentiles.py` | ✓ MATCH | Same AVG+NULL pattern direct |
| **barrelsville** | **`src/postgame_data.py:1395-1408`** | ⚠️ **DIVERGENT** | `tracked_bip["hit_vertical_angle"].fillna(0).values` → treats missing LA as 0 → ~0.001 contribution per leaked BIP, included in `damage.mean()` denom. ~0.1% drift on samples with missing LA. Same exact bug pattern fixed in pd-goals `6c0f135`. |
| **bullpen-report** | **`src/tracker_data.py`** lines **500, 1321, 1556, 2330** | ⚠️ **DIVERGENT** (4 places) | Pitcher Damage%-allowed has multiple issues: (1) `ISNULL(h.hit_vertical_angle, 0)` treats NULL LA as 0; (2) NO `< 125` EV cap (only `> 0`); (3) NO bunt filter; (4) `_EV_MISREAD_FILTER` is defined in the file but NOT applied to the Damage% blocks (it IS applied to other metrics in the same file, so the omission is selective). Net drift larger than barrelsville's — direction unknown without empirical comparison |
| bullpen-report | `src/postgame_data.py` | N/A | Doesn't compute Damage% |
| bullpen-report | `scripts/pitcher_kpi_snapshot.py` | NEEDS CHECK | grep showed match but not verified — re-audit before any fix |
| intangibles | — | N/A | Not a hitting/pitching damage app |

## Fix recipes (when the user authorizes)

### Barrelsville `postgame_data.py:1395-1408`

Replace:
```python
if "hit_vertical_angle" in tracked_bip.columns:
    ev_v = tracked_bip["hit_exit_speed"].values.astype(float)
    la_v = tracked_bip["hit_vertical_angle"].fillna(0).values.astype(float)
    exp_term = ...
    damage = 1.6 * (1.3 ** exp_term) / (7.0 + 1.3 ** exp_term)
    result["dmg_pct"] = round(float(damage.mean()) * 100, 1)
```

With:
```python
if "hit_vertical_angle" in tracked_bip.columns:
    valid = tracked_bip[tracked_bip["hit_vertical_angle"].notna()]
    if not valid.empty:
        ev_v = valid["hit_exit_speed"].values.astype(float)
        la_v = valid["hit_vertical_angle"].values.astype(float)
        exp_term = ...
        damage = 1.6 * (1.3 ** exp_term) / (7.0 + 1.3 ** exp_term)
        result["dmg_pct"] = round(float(damage.mean()) * 100, 1)
```

Or equivalently use `np.nanmean` after letting NaN propagate through the
formula (both work, the explicit filter version is slightly clearer).

### Arm Farm `tracker_data.py` (4 places)

Each `Damage% ... AS damage_pct` block needs all four canonical filters
added to the CASE WHEN condition AND the `ISNULL(la, 0)` removed:

```sql
100.0 * AVG(CASE WHEN pv.pitch_result_id IN ({bip_codes})
          AND h.hit_exit_speed IS NOT NULL AND h.hit_exit_speed > 0
          AND h.hit_exit_speed < 125                              -- ADD
          AND h.hit_vertical_angle IS NOT NULL                    -- ADD
          AND (ev1.hit_trajectory_id NOT IN (2,3,4) OR ev1.hit_trajectory_id IS NULL)  -- ADD bunt
          {_EV_MISREAD_FILTER}                                    -- ADD (already defined)
         THEN 1.6 * POWER(1.3,
                COS(-0.34) * (h.hit_exit_speed - 98)
              - SIN(-0.34) * (h.hit_vertical_angle - 27)          -- DROP ISNULL(...,0)
              - 0.02 * POWER(2 + SIN(-0.34) * (h.hit_exit_speed - 98)
                                 + COS(-0.34) * (h.hit_vertical_angle - 27), 2))
          / (7.0 + POWER(1.3, ...same exp_term... ))
         ELSE NULL END) AS damage_pct,
```

All 4 occurrences (per-pitcher, monthly per-pitcher, org, monthly org)
need the same patch. Match the bar-chart-canonical formula in
`pd-goals/src/stats.py:674` exactly.

## Why these matter (and why they're deferred)

PD Goals (the user-facing app the coordinator looks at most) is now
internally consistent — bar chart and rolling chart both produce the
same Damage%. That was the immediate user-visible bug.

The Barrelsville and Arm Farm divergences are real but produce small
drift (~0.1% Damage%, single decimal) that hasn't caused a coordinator
complaint. Fixing them touches separate worktrees / branches and
requires:
- Verifying which downstream consumers depend on the current values
- Confirming with the user whether the 4 Arm Farm pitcher-side
  occurrences should match the canonical hitter formula or
  intentionally use a more permissive filter
- Coordinating deploy across affected apps

**Do NOT fix without explicit user direction.** The user knows about
these divergences (audit done together 2026-04-25) and elected to
address PD Goals first.

## Lesson encoded

When auditing rolling/per-game metric implementations against bar chart
canonical, the LA-not-null filter is the most common silent drift
source. Every BIP-tracked metric in the bar chart's `hits_query` uses
`h.hit_vertical_angle IS NOT NULL` in the JOIN/WHERE — any per-game
SQL that omits this filter AND uses `ISNULL(la, 0)` (instead of NULL
propagation) will leak BIPs with missing LA into the average,
contributing ~0.001 damage each.

The fix pattern is one of:
1. Add `hit_vertical_angle IS NOT NULL` to the BIP filter (bar chart
   pattern, what pd-goals rolling now uses)
2. Remove `ISNULL(la, 0)` and let NULL propagate through the formula
   so it returns NULL → AVG skips (Barrelsville hitter pattern)
3. Filter rows in Python BEFORE computing damage (`.notna()` mask)

All three produce identical numeric results. Pick one, document it,
and stick with it.
