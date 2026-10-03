# Contact-Quality Metrics — AA 4-16% / Squared-Up % / Smash Factor (design + prep)

**Date:** 2026-06-21 · **Branch:** `feature/barrelsville` · **Owner:** Zac
**Goal:** add three new **general metrics** to the affiliate trackers (alongside
`aa_con` / `vba_con` / `hba_con` / `bat_speed`), then propagate via the standard
`tracker-new-metric` 7-place checklist. Same pattern as the HBA_con rollout.

Reference impls to mirror: `barrelsville/src/tracker_data.py` — `aa_con`
(`_AACON_QUERY`), `vba_con` (`_VBA_QUERY`), `hba_con` (`_HBA_QUERY`),
`bat_speed` (`_BS_QUERY` + `clean_bat_speed_per_player`).

---

## Disambiguation answers (Zac, 2026-06-21 questionnaire)

| Q | Answer |
|---|---|
| Square% source | **Compute** it (Statcast/Fangraphs formula) — NOT GC2 id 984 (that's MLB-only pose, NULL for MiLB). |
| Square% & Smash denominator | **Per BBE** (batted balls with a measured EV), "just like Driveline." |
| AA 4-16% denominator | **All swings** (every swing with a measured `aa_con`) to start. (Could later split into a per-BBE variant too.) |
| Coloring | **All three colored, higher = better.** |

---

## Shared GC2 sources

- **Attack angle at contact** `aa_con` = `90 − DEGREES(ACOS(batvz_con / |batv_con|))`
  (already computed; `swing_contact_values`). Range gate already used: [−50, 50].
- **Bat speed at contact (mph)** = `|batv_con| × 0.681818` (already computed,
  `_BS_QUERY`; canonical clean via `clean_bat_speed_per_player`).
- **Exit velocity (EV)** — use the SAME source the tracker's `avg_ev/max_ev` use
  for consistency (`Astros.Hits.hit_exit_speed`; GC2's Barrel/Damage use this).
  EV-misread cleaning (Filter I) already applied upstream.
- **Pitch speed** — `Pitches_View.plate_speed` (or `release_speed`); confirm which
  the tracker already exposes before wiring (read `_PITCH_LEVEL_QUERY`).

---

## 1. AA 4-16% (`aa_ideal_pct`, label "AA4-16%")

- **Definition:** share of swings whose attack angle at contact is in the ideal
  **4°–16°** window (inclusive). Matches the Frey PPTX query.
- **Formula (count-derived):**
  `aa_ideal_pct = 100 × SUM(aa_con BETWEEN 4 AND 16) / SUM(aa_con IS NOT NULL)`
  i.e. numerator = swings with `aa_con ∈ [4,16]`, denominator = **all swings with
  a measured `aa_con`** (contact-frame swings; whiffs have a nearest-pass contact
  frame so they're included).
- **Format:** `pct1` · **Coloring:** higher = better · **Gate:** ~20 swings.
- **Rollup (multi-level):** count-derived → expose `n_aa_ideal` + `n_aa` counts,
  re-derive `100 × Σn_aa_ideal / Σn_aa`. Org: pool.
- **Source:** `aa_con` only — no new table.

## 2. Smash Factor (`smash`, label "Smash") — FORMULA LOCKED (Driveline, 2026-06-22)

- **Definition:** Driveline Smash Factor — how much of the pitch+swing energy
  transferred into exit velocity, per BBE, then averaged.
- **Canonical source:** Driveline, "Smash Factor: A Data-Driven Approach to
  Assessing the Hit Tool" (drivelinebaseball.com, 2021).
- **Formula (per BBE):**
  `smash_i = 1 + (EV_i − BatSpeed_i) / (PitchSpeed_i + BatSpeed_i)`
  which algebraically simplifies to
  `smash_i = (PitchSpeed_i + EV_i) / (PitchSpeed_i + BatSpeed_i)`
  → player `smash` = **mean of per-BBE `smash_i`** over BBE with EV + bat speed +
  pitch speed all present. (Mean-of-ratios, NOT Σ/Σ.)
  - **⚠ Correction:** the original Jun 21 spec had `smash = EV / BatSpeed` —
    WRONG. Replaced with the Driveline formula above (it needs pitch speed too).
- **Format:** `f2` (e.g. 1.45) · **Coloring:** higher = better · **Gate:** ~20 BBE.
- **Rollup (multi-level):** **BBE-weighted mean** of per-level `smash` (weight =
  per-level `n_cq_bbe`). Org: BBE-weighted mean (pool).
- **Sources:** EV = `Astros.Hits.hit_exit_speed`; BatSpeed = SCV
  `SQRT(batvx²+batvy²+batvz²)×0.681818`; PitchSpeed = `Pitches_View.release_speed`.
  BBE-only (same eligibility as Square%).

## 3. Squared-Up % (`squared_up_pct`, label "Square%")

- **Definition (Statcast/Fangraphs):** share of BBE that are "squared up" — i.e.
  achieved ≥ **80%** of the *potential* EV for that bat speed + pitch speed.
- **Formula (count-derived, per BBE):**
  - `potential_EV_i = a × bat_speed_i + b × pitch_speed_i`  ← **a, b = OPEN (see below)**
  - `squared_up_i = (hit_exit_speed_i / potential_EV_i) ≥ 0.80`
  - `squared_up_pct = 100 × SUM(squared_up_i) / SUM(BBE with EV+batspeed+pitchspeed)`
- **Format:** `pct1` · **Coloring:** higher = better · **Gate:** ~20 BBE.
- **Rollup:** count-derived (`Σn_squared / Σn_bbe`). Org: pool.
### Squared-Up — canonical definition + sources (documented 2026-06-21)

Searched the vault (`bsb-brain`) + all repos: there is **no prior squared-up
*formula* doc** — only GC2's stored `Percent Squared Up` (id 984, MLB-only pose,
in `2026-06-16-biomech-measurements-schema-reference.md`) and generic glossary
links. So we use the **public Statcast/FanGraphs definition** below; if Zac has a
specific source with different constants, swap them in and re-verify.

**Canonical Statcast/FanGraphs squared-up (bat-tracking era, 2024+):**
- Measures how much of the *available* exit velocity a swing captured.
- **Potential (max) EV** for a given bat speed + pitch speed (the collision model):
  `potential_EV = 1.23 × bat_speed + k × pitch_speed`
  where **`k ≈ 0.2116`** (Statcast's published value; some write ≈ 0.23 — **verify
  exact `k` on refresh** before shipping).
- **Squared-up ratio** per BBE = `hit_exit_speed / potential_EV` (capped at 1.0).
- **"Squared up"** = ratio **≥ 0.80** (the 80% threshold).
- **Square%** = `100 × SUM(squared_up) / SUM(BBE with EV+batspeed+pitchspeed)`.

**Reference links to confirm `k` + threshold on refresh:**
- FanGraphs glossary: https://www.fangraphs.com/glossary  (Squared-Up Rate)
- Baseball Savant (bat tracking): https://baseballsavant.mlb.com/leaderboard/bat-tracking
- (Tango/Statcast write-up on the 1.23·batspeed + k·pitchspeed collision model)

**✅ RESOLVED (2026-06-22) — constants confirmed from FanGraphs/MLB sources (Zac):**
- `Squared-Up % = EV / ((BatSpeed × 1.23) + (0.2116 × PitchSpeed))`, squared up if
  ratio ≥ **0.80**. So `a = 1.23` (bat speed), `b = 0.2116` (pitch speed),
  threshold `0.80`. (k = 0.2116, NOT 0.23.)
- Sources: MLB Statcast glossary (mlb.com/glossary/statcast/squared-up) +
  FanGraphs "Squared-Up Rate and Launch Angle" / "When Squaring It Up Goes Sideways."
- PitchSpeed = `Pitches_View.release_speed`. Ratio capped at 1.0 for display sanity
  (a few BBE can exceed potential_EV from measurement noise).

---

## Propagation plan (per metric, `tracker-new-metric` 7-place checklist)

All three are **count-derived / weighted** (not percentile P*), so the 7-place
path (not the 9-place raw-obs path):

1. `LEADERBOARD_COLS` — add `("aa_ideal_pct","AA4-16%","pct1",True,True)`,
   `("smash","Smash","f2",True,True)`, `("squared_up_pct","Square%","pct1",True,True)`.
2. **4 SQL sites** — add the per-BBE / per-swing raw inputs (counts + sums) to the
   season + monthly + org season + org monthly queries. AA4-16 rides the existing
   SCV/aa_con join; Smash + Square need EV (Astros.Hits) + pitch speed joined per BBE.
3. **Python derivation** — count-derived: `aa_ideal_pct`, `squared_up_pct`;
   mean-of-ratios: `smash`. Mirror `gb_pct` derivation location.
4. **Multi-level rollup** (`aggregate_org_across_levels`): `aa_ideal_pct` +
   `squared_up_pct` → `count_derived` (add numer/denom accumulators); `smash` →
   BBE-weighted block.
5. **Page `_PITCH_WEIGHTED_KEYS` / count-derived handling** in `2_Affiliate_Tracker.py`.
6. **Stale-pin shim** (all 5 sites) — add the 3 metric cols + their count cols.
7. **`METRIC_TOOLTIPS`** — one factual sentence each.

**Three-surface parity (Q9):** tracker-only to start. (Postgame app + KPI weekly
could get them later; flag if/when.) **Re-pin required** before deployed trackers
show real values; stale-pin shim keeps old pins from KeyError'ing (NaN until re-pin).

**Never round mid-pipeline** — carry full precision, round at display (`pct1`/`f2`).

---

## 4. NEXT PASS — Statcast batted-ball-type metrics (Topped% / Flare-Burner%)

Decided 2026-06-22 (Zac): build the 3 core metrics this pass; add the batted-ball
**type** metrics in a follow-up so we get them right. Key fact: **Topped, Flare/Burner,
Solid Contact, and Barrel are all one classification** — Statcast's 6-bucket
EV×LA grid (Barrel · Solid Contact · Flare/Burner · Poorly-Under · Poorly-Topped ·
Poorly-Weak), NOT independent formulas. The user's "Topped = negative launch angle"
is the simplified version; Savant's real grid is EV-dependent. Next pass: implement
the full 6-bucket EV×LA classifier (one CASE → all six rates) so Topped% +
Flare-Burner% match Baseball Savant. Barrel% likely already covered by `barrel_pct`/
pBrl%. Sources to mirror the grid: Baseball Savant batted-ball-type leaderboard +
Tango's classification write-up. Topped is lower=better; Flare/Burner is productive
(higher generally good). Defer coloring/gate decisions to that pass.

## Status

- **Ready to implement now (all unambiguous, formulas LOCKED 2026-06-22):**
  AA 4-16%, Smash Factor (Driveline), Squared-Up % (1.23 / 0.2116 / 0.80).
- **Next pass (separate build):** Topped% + Flare-Burner% via the Statcast 6-bucket
  EV×LA grid.
