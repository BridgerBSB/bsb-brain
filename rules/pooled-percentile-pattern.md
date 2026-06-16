# Pooled-Percentile Pattern — Universal (BLOCKING)

Every per-player percentile metric in every affiliate tracker MUST use
**raw-obs pooling** for multi-level and multi-year aggregation. The
weighted-mean-of-per-slice-percentiles approximation is forbidden.

This applies to:
- P01, P05, P10, P25, P50, P75, P90, P95, P99 — any percentile target
- Per-player tier (Arm P99 per fielder, Pop2B P01 per catcher, TopSpd P95
  per runner, etc.)
- Both single-level + multi-level + multi-year scopes (math is identical
  shape — pool the raw observations selected by the user's scope, then
  `np.percentile` ONCE)

---

## The iron rule (memorize this)

For ANY per-player percentile metric:

```
individual_value = np.percentile(player.raw_obs_in_selected_scope, P)

org_value        = weighted_mean(
                        per_player_individual_values,
                        weights = per_player_n_obs   # NOT comp_plays,
                                                      # NOT n_pitches,
                                                      # NOT games
                   )
```

**Individual tier ALWAYS pools raw observations** across whatever scope
the user picked (any combination of levels × years). **Org tier ALWAYS
weighted-means individuals by per-metric n_obs** (the Iron Rule from
`multi-level-rollup.md`).

Same shape whether user picks 1 level × 1 year, 7 levels × 5 years, or
anything in between.

---

## The math drift (why approximation is forbidden)

Real case (Nunez Arm, 2025+2026 multi-year):

| Path | Math | Result |
|---|---|---|
| **Weighted-mean approximation** | `(87.5 × 40 + 84.1 × 30) / 70` | **86.0 mph** ⚠️ |
| **True pooled (raw-obs)** | Pool all 70 throws → `np.percentile(70_throws, 99)` | **~87.2 mph** ✅ |

The weighted-mean is biased LOW because the hardest throws from the
heavier-volume slice (the top 1% of 40 = 0.4 throws) get "diluted" by the
lower per-slice P99 from the smaller slice when averaged. Pooling
correctly keeps elite throws in the top 1% of the combined population.

Direction of drift: weighted-mean approximation typically biases TOWARD
the lower-volume slice's value. For P99 / P95 (where the player wants
their hardest throw), drift is LOW. For P01 / P10 (where the player
wants their fastest pop time / quickest reaction), drift is HIGH.
Either direction = wrong.

---

## Status by tracker (May 23 2026)

| Tracker | Per-player P-metrics today | Multi-level pooling state |
|---|---|---|
| **Fielding (OF/IF)** | TopSpd P95, Accel Up P75, Accel Down P75, React P25, UseReact P25, ReactRad P25, ReactAccRad P25, Arm P99, Exch P10 (9 metrics) | ✅ **TRUE pooled** via raw_obs pin + pre-computed combo keys (LIVE May 23 2026). Every canonical level combo × contiguous year range × 3 H/A = instant pin lookup. Non-canonical combos fall through to raw_obs compute (~1-2 sec). |
| **Catcher** | Arm P99, Exch P10, Pop2B P01, Pop3B P01, AugPop P01 (5 metrics) | ⚠️ Weighted-mean approximation — **PORT REQUIRED** |
| **BR** | TopSpd P95, React P25, T22 P25, Split1 P25, Accel P75 (5 metrics) | ⚠️ Weighted-mean approximation — **PORT REQUIRED** |
| **Hitter** | None today | N/A — rule applies the moment one gets added |
| **Pitcher** | None today | N/A — rule applies the moment one gets added |

Migration plans for catcher + BR live at:
- `docs/plans/2026-05-23-catcher-pooled-percentile-port.md`
- `docs/plans/2026-05-23-br-pooled-percentile-port.md`

---

## The 6-piece implementation (canonical, mirror fielding)

Canonical reference: `intangibles/src/fielding_tracker_data.py` (commits
`b084ce6f` → `d1a9b129` → `dc96c669`, parity-verified May 23 2026).
Every new percentile metric in any tracker must implement these 6 pieces.

**The full pattern combines:**
1. **Raw observation pin** (cheap to build, ~6 min/year, allows correct math) — Pieces 1-3
2. **Pre-computed combo pin** (built from raw obs in Python at pin time, ~6 min compute per (year, H/A), gives instant app reads) — Piece 5b
3. **3-tier cascade in app** (combo pin first → raw_obs fallback → live SQL) — Piece 3

This is the architecture you want — fast reads in the app, no DB risk during pin builds, math always correct.

### Piece 1 — Raw observation SQL queries

Pull one row per qualifying observation across the FULL canonical level
set in one shot. No PERCENTILE_CONT in SQL, no per-level pre-aggregation.

```sql
-- _RAW_<METRIC>_QUERY shape (mirror fielding's _RAW_TDM_QUERY)
SELECT
    <player_id_col>,
    <org_col>,
    <level_col>,
    <season_col>,
    <position_or_scope_cols>,
    <metric_value_col>,
    <any_gate_flag_cols>   -- e.g., competitive_play, ignore_flag
FROM <source_table>
JOIN Schedule_View sv ON ...
JOIN <other_required_tables> ...
WHERE sv.year IN (<all PINNED_YEARS>)
  AND <Tier 1 gate or equivalent>
  AND <range filter if applicable>
  -- NO percentile computation here
```

One raw query per "raw bundle key" — e.g., fielding has raw_tdm /
raw_dcbp / raw_games. Most percentile-metric implementations will need
just 1-3 raw queries.

### Piece 2 — Pin schema + `_try_pin_raw_obs` gate

Add prefix constants to `tracker_pins.py`:
```python
PREFIX_RAW_<METRIC> = "raw_<metric>"
```

Add to `ALL_<DOMAIN>_PREFIXES` so `write_tracker_bundle` enforces presence.

Write `_try_pin_raw_obs(domain, seasons, sched_types, ha_split)` in the
data module. Gates:
- pins module importable
- every season in PINNED_YEARS
- sched_types canonical (`('R',)`)
- ha_split in (None, 0, 1)
- every season bundle has all required raw_obs keys

Returns tuple of raw DataFrames OR None. Multi-year concats year
bundles. Caller falls through to live SQL on miss.

### Piece 3 — `_compute_pooled_from_raw_obs` helper(s)

Two helpers per domain:
- `_compute_pooled_indiv_from_raw_obs(raw_dfs, level_codes, seasons, ...)`
  returns per-player DataFrame
- `_compute_pooled_org_from_raw_obs(raw_dfs, level_codes, seasons, ...)`
  returns per-org DataFrame

Both:
1. Filter raw DFs by user's selected (level_codes, seasons)
2. Per-player: groupby player_id → `np.percentile(values, P)` per metric
3. Per-metric n_obs count (NON-NULL after range filter, NOT total
   observations). Used as outer-tier weight.
4. Org tier: weighted-mean per-player values by per-metric n_X
5. Apply same display gates (min_plays, range filters) as the SQL path
   so output rows match the existing path 1:1

### Piece 4 — Parity diagnostic

`scripts/diag_pooled_parity.py` runs both paths side-by-side:
- Path A: new raw_obs path
- Path B: existing PERCENTILE_CONT SQL path
- Asserts ±0.05 mph on percentile metrics, ±0.01 on sums, ±0.5 on counts
- Test cases: known multi-level player, single-level sanity check,
  multi-year case

Parity MUST pass before pin CLI runs in production. If parity fails,
fix the helper math — do NOT ship.

### Piece 5 — Pin CLI integration

Update `pin_<tracker>_seasons.py`:
- Keep existing per-level pin keys (those are still used for non-multi-
  level scenarios and other surfaces)
- Write 3 raw keys per H/A iteration (`_get_raw_X(...)`)
- **Piece 5b**: after raw_obs writes, call `_compute_all_combos_for_year`
  to compute every (combo × prefix) for the current year and write as
  pre-computed combo pin keys. This is in-memory Python compute, no DB.
- **Piece 5c (multi-year)**: for each contiguous year range ENDING at
  the current year, load earlier years' raw_obs from prior pins, concat,
  compute combos for the range, write keys under
  `<prefix>_<year_range>_<combo>_<ha>`. Multi-year keys live in the
  LATEST year's bundle. Nightly Connect refresh of current year
  naturally updates all ranges ending at it.

App reads via 3-tier cascade:
1. `_try_pin_pooled_combo` (instant pin lookup for canonical combos)
2. `_try_pin_raw_obs` (compute from raw rows, ~1-2 sec)
3. Live SQL fallback

Connect-scheduled refresh runs the new CLI on current year. Build
time: ~6 min raw_obs + ~6 min per single-year combo set + ~8 min per
multi-year range. For 2026 with 4 prior years: ~38 min per H/A
× 3 H/A = ~2 hr per (domain, current_year). Full 5-year backfill:
~10-12 hours unattended.

---

## Hand-dependence decision (ask at metric-add time)

When adding a new percentile metric to ANY tracker, the skill MUST ask:
"Does this metric vary by pitcher / batter hand?"

| Answer | Raw-obs pin shape |
|---|---|
| **No (hand-agnostic)** — physical sprint, throw, exchange time, etc. | Single raw_obs key per H/A (no hand variant). Example: fielding Arm, catcher Pop, BR TopSpd. |
| **Yes (hand-dependent)** — platoon-sensitive measurement | Raw_obs key × 3 hand variants (raw_X_all, raw_X_l, raw_X_r). Example: hypothetical "hitter EV P95 vs LHP" — would need hand-split pin to compute per-hand percentile pool correctly. |

Default for current trackers:
- **Fielding**: hand-agnostic — no hand split anywhere
- **Catcher Arm/Pop/Exch/AugPop**: hand-agnostic on the catcher's side
  (the throw / pop / exchange is the same physical motion regardless of
  pitcher hand). NO hand split on the raw_obs pin. Framing percentile
  metrics WOULD need hand split if added (umpire calls differ vs L/R
  hitter), but no per-catcher framing percentile exists today.
- **BR TopSpd/React/T22/Split1/Accel**: hand-agnostic (same physical
  sprint regardless of pitcher hand). NO hand split on the raw_obs pin.
  Lead distance metrics (PL/SL) ARE hand-dependent but they're means,
  not percentiles, so they live outside this rule.
- **Hitter/Pitcher**: when a P-metric eventually gets added, ASK at
  add-time — most batter-side metrics ARE hand-dependent (platoon
  splits), most pitcher mechanics metrics are NOT.

---

## When this rule triggers

A new metric being added triggers this rule if:

1. Display label contains `P\d+` (P01, P10, P25, P75, P95, P99, etc.)
2. SQL aggregation uses `PERCENTILE_CONT(0.XX)` or `PERCENTILE_DISC`
3. Python computation uses `np.percentile`, `df.quantile`, or any
   `interpolation='linear'` percentile call
4. Conceptually: "best Nth-percentile reading" (a player's hardest
   throw / fastest sprint / quickest reaction) rather than a mean

If unsure → ASK. Wrong classification = silent multi-level drift,
caught months later when a coach files a parity bug.

---

## What NOT to do

- **Don't ship a P-metric via weighted-mean-of-per-slice-percentiles.**
  Math diverges from true pooled. Caught by parity diag.
- **Don't compute PERCENTILE_CONT per (player, level, year) in SQL,
  then weighted-average across slices in Python.** Same bug class.
- **Don't pin pre-computed pooled values per (level-combo, year-combo).**
  Combo explosion makes pin maintenance impossible (fielding's old
  120-combo path was this — replaced by raw_obs).
- **Don't skip the parity diagnostic.** EVERY new percentile metric
  needs a parity check against the existing SQL path before pin CLI
  runs in production.
- **Don't weight the org tier by `comp_plays` / `n_pitches` / `games`.**
  Always per-metric `n_X` (the count of qualifying observations for
  THAT specific percentile metric, after its range filter). See
  `multi-level-rollup.md` Iron Rule.
- **Don't change the np.percentile interpolation kind.** Default is
  `linear`, matches SQL Server PERCENTILE_CONT. Don't override unless
  parity diag forces it.
- **Don't add hand-split to a hand-agnostic percentile metric "for
  consistency."** 3× the pin work for zero analytical value. See
  hand-dependence decision above.
- **Don't drop the existing per-level pin keys when adding raw_obs.**
  Per-level keys serve single-level scenarios + other surfaces (KPI
  weekly, etc.). Raw_obs is ADDITIVE, not a replacement.
- **Don't run the new pin CLI in production until parity passes** on
  representative test cases. Bad math at the pin tier propagates to
  every coach-facing surface.

---

## Cross-references

- `multi-level-rollup.md` — Iron Rule for per-metric weighting + canonical
  two-tier architecture. This rule is the implementation pattern for the
  percentile subset of that.
- `tracker-parquet-pins.md` §10b — historical pooled-combo pin pattern
  (DEPRECATED for fielding, scheduled for catcher + BR deprecation).
- `tracker-new-metric-checklist.md` — extended to 7 places when metric
  is percentile (adds raw_obs SQL + pooled helper integration).
- `three-surface-parity.md` — tracker / KPI weekly / PD-Goals invariants;
  percentile metrics MUST give identical values across all three
  surfaces.
- `database-tcp-retry.md` — pin job resilience (transient TCP recovery
  during raw_obs pin write).
- `.claude/skills/tracker-new-metric/SKILL.md` — Q7 percentile branch
  asks the hand-dependence question + enforces 5-piece implementation
  before commit.
- `slack-channels-sync.md` — cross-worktree sync discipline (this rule
  file syncs byte-identical to all 4 worktrees).

---

## Bug history

- **May 16 2026** — Fielding pooled SQL fix shipped (`2d3d9da9`).
  Pre-fix: weighted-mean approximation. Post-fix: correct pooled
  percentile via SQL CTE per (year, level). Solved math but introduced
  live-DB cost on every multi-level selection.
- **May 21 2026** — Fielding pooled-combo pin pattern shipped
  (`83c0d3dd`). Pre-computed all 120 multi-level combos × 3 H/A as
  separate pin keys. Solved speed but pin build took 12+ hours per
  (domain, year) and kept failing on home VPN.
- **May 22-23 2026** — Fielding raw-obs refactor shipped (`b084ce6f`
  → `d1a9b129`). Replaced 120-combo with 3 raw keys per H/A. Pin
  build time dropped from 12+ hours to ~6 min. Parity verified ±0.05
  mph on 831/831 fielders + 30/30 orgs. **This is the canonical
  reference implementation.**
- **(future)** Catcher + BR ports — same pattern, scheduled when
  fielding deploy verifies clean in production.

---

## Cross-worktree sync

This rule file lives in all 4 worktrees:
- `bsb-resources/.claude/rules/pooled-percentile-pattern.md`
- `bsb-wt-hitting/.claude/rules/pooled-percentile-pattern.md`
- `bsb-wt-bullpen/.claude/rules/pooled-percentile-pattern.md`
- `bsb-wt-intangibles/.claude/rules/pooled-percentile-pattern.md`

When this rule changes, update all 4 in the same operation per
`slack-channels-sync.md` discipline. Verify md5 match after copy.
