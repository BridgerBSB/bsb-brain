# Pitch Similarity — Expansion Roadmap (experimental)

Status: **v2 (Similarity % + z-score) is SHIPPED** as an opt-in toggle — the
original tolerance-band behavior remains the default and untouched. Items below
marked ✅ are live; the rest (v2.1 / v3 / robustness) are still forward-looking
and prototyped on the side in `scripts/explore_pitch_similarity_v2.py` — nothing
unmarked ships into the live page until proven there and Zac signs off. (Zac
direction, Jun 21 2026: keep the working app; add z-score alongside, validate in
the app via the toggle.)

## What the live app does today (the baseline)

Nearest-neighbor on pitch shape. 11 match metrics (velo, IVB, HB, spin, eff,
ext, VAA, HAA, rel height, rel side, **arm angle**), each with a user ± tolerance
that acts as BOTH a hard gate (must fall in the band) AND the distance scaler
(`(diff/tol)²` summed → Euclidean distance, closest first). Multi-pitch-type
"combination" matching (every selected type must match). One row per
pitcher-season-level. This IS the standard industry approach — see Sources.

## The expansion items (priority order)

### v2 — Similarity % + population z-score normalization ✅ SHIPPED (Jun 21 2026, commit `b2337a95`)
Shipped as an **opt-in "Scoring" toggle** in the live app — default "Tolerance
bands" is the original behavior (untouched); "Similarity %" mode is the z-score
version. Decisions (Zac): **pure ranking** (no hard gate, top N shown) +
**z-score basis = the selected pool, per pitch type**. `sim% = 100·exp(−dist/√n_dims)`
(run-independent: 100% identical, ~37% ≈ 1 SD off avg). Impl:
`rank_similar_zscore` in `src/pitch_similarity.py`. The two coupled pieces were:

1. **Similarity score (0–100%)** — convert the ranked distance into "92%
   similar." Every public tool surfaces a % instead of a raw distance. Candidate
   scalings to test in the sandbox: `100·exp(−dist/k)`, `100·(1 − dist/dist_ref)`,
   or pool-percentile rank of the distance. Pick by what reads sensibly to DJ.
2. **z-score normalization** — standardize each metric by the **population
   standard deviation** across the pool, then Euclidean in z-space, so "1 mph"
   and "100 rpm" are comparable units. Today's tolerance doubles as the scaler;
   v2 **decouples** them: tolerance stays an OPTIONAL hard gate, the ranking
   distance is computed in z-space. (Model 284 + Baseball Analytica both
   normalize-before-distance for exactly this reason.)

### v2.1 — More comparison axes
- **Bauer Units** = `spin_rate / release_speed` (spin adjusted for velo) — a
  standard industry axis; trivial derived column.
- **Spin axis / tilt** — we already have `tilt` (clock) + can derive spin
  direction; needs circular-distance handling (12:00 vs 11:55 are close).
- (Arm angle already shipped in the live app, Jun 21 2026.)

### v3 — heavier methodology (pair with the modeling backend)
- **Mahalanobis distance** — IVB/HB/VAA/release/arm are physically correlated, so
  plain Euclidean double-counts movement. Covariance-aware distance fixes it.
  Watch for singular/ill-conditioned covariance on small pools (use pseudo-
  inverse + shrinkage). Cheaper interim already in the live app: don't
  default-check redundant axes together.
- **Era normalization** — a 2018 FB ≠ a 2026 FB (league velo/movement drift).
  z-scoring *within each season's population* fixes this automatically; fold
  into v2's standardization (group the pool by season before computing μ/σ).
- **Arsenal-level usage weighting** — when matching a full arsenal, weight each
  pitch type by usage% so same-shapes + same-mix rank above same-shapes +
  wildly-different-mix (tjStats / Model 284 do this).

## Engineering robustness (separate from methodology)
- **✅ Arm-angle daily pin (SHIPPED Jun 22 2026, commit `1c6f66ac`)** — arm angle
  was recomputed live from raw HawkEye tracking across the whole pool (~3-min
  cold load when Arm checked). Now precomputed offline into a tiny per-season pin
  (`zbridger/arm_farm_arm_angle_{year}`, one row/pitcher) by
  `scripts/pin_arm_angle.py`; `get_candidate_pool` reads it pin-first (skip the
  heavy joins) with a live fallback. Connect bundle: `connect_pins_arm_angle/`,
  scheduled ~2am. Reuses the tracker pin/deploy template.
- **Pin the whole pool to parquet** (e.g. all-MLB 2021–2026) — the non-arm pool
  query is lighter but still a cold cost; same pin pattern could extend to it.
  See `.claude/rules/tracker-parquet-pins.md` + `query-performance.md`.
- **Surface exclusions** — "37 candidates dropped for missing VAA/arm" so
  sparse-tracking MiLB gaps are visible, not silent.
- **Low-sample flag** on matches with few pitches of a type.
- **Shareable query** via URL params so DJ can send a comp.

## How to run the experiment
```
cd bullpen-report
python scripts/explore_pitch_similarity_v2.py --gc-id 269548 --season 2026 \
    --pitch-types FF FT --levels mlb --yr-from 2018 --yr-to 2026
```
Prints the LIVE-method ranking next to each experimental scorer (z-score,
similarity %, Bauer-augmented, era-normalized, Mahalanobis) on the SAME pool, so
we can see what each change actually does to the comps before touching the app.
Requires DB (work laptop). Not in `manifest.json` — never deploys.

## Sources (methodology)
- Pitcher Similarity Score Methodology — Model 284: https://model284.com/pitcher-similarity-score-methodology/
- A New Approach to Pitcher Similarity Scores — Baseball Analytica: https://baseball-analytica.com/posts/2024-04-12/pitcher-similarity-scores/
- Pitch Similarity Tool — TJStats: https://tjstats.ca/pitch-similarity/
- Similarity-Based Pitch Recommendations — Christian Hook: https://medium.com/@ChristianHook/similarity-based-pitch-recommendations-882278a2991f
- Pitch Arsenal Scores — The Hardball Times/FanGraphs: https://tht.fangraphs.com/pitch-arsenal-scores/
- Statcast Pitch Arsenal Stats — Baseball Savant: https://baseballsavant.mlb.com/leaderboard/pitch-arsenal-stats
