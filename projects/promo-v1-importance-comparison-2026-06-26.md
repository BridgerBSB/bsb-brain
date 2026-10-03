---
type: artifact
created: '2026-06-26'
source: models.zip + comparison.zip (v1 winner bundles + compare_models outputs)
tags:
  - modeling
  - v1
  - shap
  - feature-importance
  - artifact
---
# v1 Importance + Class-Comparison — council read (2026-06-26)

From `models.zip` (14 winner bundles) + `comparison.zip` (compare_models outputs).
These are **real per-spec winners** (LogReg/ExtraTrees/RF/LightGBM), newer than the
all-LightGBM [[promo-v1-eval-2026-05-18]]. Parent: [[promotion-release-models]].
Method note: bundles need numpy≥2 + `models/` on path to unpickle. True SHAP
(beeswarm/direction) still needs `promo_features_h.parquet` — not in these zips.

## 🔬 The age question — answered (gain importance)

Raw `age` is **tiny everywhere (1.5–3.3%)**. Age influence is almost all
**age-relative-to-level** (`age_pctile_at_level`, `age_zscore_at_level`,
`age_minus_level_median`):

| spec (class) | age-family % | raw age % | top feature |
|---|---|---|---|
| h_released_12mo (ExtraTrees) | 15.2% | 1.5% | age_pctile_at_level 5.4% |
| h_reached_mlb_12mo (ExtraTrees) | 6.6% | 3.3% | **modal_level_mlb 21.8%** |
| p_promoted_12mo (LightGBM) | 5.3% | 1.9% | **modal_level 25.5%** |
| p_released_12mo (RandomForest) | 16.4% | 2.0% | fip 4.0% |

**⚾ Scout verdict:** this is the *legit* age signal, not a bug. A 24yo in AA ≠ a
20yo in AA. Raw age barely registers. Don't "fix" it.

## 🛠️ ML-Engineer / 🔬 DS — the `_pct` columns are NOT bloat (correction)

Initial read called `x`/`x_pct` "redundancy bloat." **Wrong — corrected.** `_pct`
comes from `features/percentile_transformer.py`
(`AgeBandLevelSeasonPercentileTransformer`): each feature ranked vs its
**(age_band × modal_level × season)** peers, fit on TRAIN only (no test leakage).
That's the **cross-level comparability fix** (a .280 wOBA in A ≠ AAA) — KATOH-style
peer normalization, real signal a tree can't derive from raw `x`. **KEEP it.**
The ONLY genuine redundancy: features that are *already* percentiles getting a
second `_pct` (e.g. `age_pctile_at_level_pct`, `xwoba_mlb_grad_pctile_at_level_pct`)
— double-transformed; prune those specifically. Otherwise audit raw↔pct correlation
and drop a *raw* only where its `_pct` fully subsumes it.

## 🧨 Skeptic flag — `modal_level` dominance = near-circular

`modal_level` is the **top feature for reached-MLB (22%) and pitcher-promote (25%)**.
The 0.94 AUCs on reached-MLB/stickiness are partly just "what level are you at" —
a level-reader, not a talent model. Test whether these models add anything beyond
modal_level. (Same smell as v2's MLB-row inflation.)

## 🔬 BIG finding — model class barely matters

`by_class_summary` mean test AUC: **LightGBM .880 · RF .875 · ExtraTrees .874 ·
LogReg .869** — all within ~1pp. Per-spec "winner" lifts are **0.02–1.28 pp AUC**
(noise). The bake-off is picking winners inside the noise band.

**Implication:** stop optimizing class choice. Pick for **calibration +
interpretability**. And note: **ExtraTrees has the best mean cal_slope (0.840)** vs
LightGBM/LogReg (0.797) — directly relevant to the hitter calibration failures in
[[promo-v1-eval-2026-05-18]]. A calibration-first pick may beat the AUC-first winner.

## Winners per spec (for reference)

LogReg: h_promoted_12mo, p_stuck_c · ExtraTrees: h_reached_mlb, h_released_12mo ·
RandomForest: p_released_12mo · LightGBM: the rest. stuck_variant_b degenerate.

## Next (real-team deep pass)
1. Get **`promo_features_h.parquet`** → true SHAP (direction + interactions) + a
   modal_level-leakage ablation (does AUC survive dropping modal_level?).
2. Prune the `_pct` duplicates; re-eval.
3. Calibration-first model selection for the 3 failing hitter specs.

Register: [[artifacts-register]] · voices: [[advisory-council]]


---

# 🧪 Council deep-dive — SHAP + modal_level ablation (2026-06-26)

Run by `council-data-scientist` (SHAP) + `council-skeptic` (ablation) on the real
`promo_features_h.parquet` (60,754×209). Method: clean **LightGBM surrogates**
(class barely matters), TRAIN 2022–24 / TEST 2025. Surrogates overfit (train AUC
0.999) → trust only top features + directions confirmed by univariate observed-rate
slices. Surrogate TEST AUC matched known headlines (promote 0.773, release 0.807)
and beat an age+level baseline by **+0.124 AUC** → features genuinely add signal.

## PROMOTE (h_promoted_12mo)
- `modal_level` is the top feature (27% SHAP) but **NOT load-bearing** — ablation Δ
  only +0.003 (level is reconstructable from the ~21 `*_at_level` features).
- **Age signal is mostly RAW age** (younger → promote, univariate Q1 0.21 → Q5 0.11).
- ⚠️ **The age-relative features are weak AND point the "wrong" way:** observed promote
  rate *rises* with `age_pctile_at_level` (Q1 0.178 → Q5 0.242) — i.e. **OLD-for-level
  promotes MORE**, opposite of the "young-for-level fast riser" intuition (likely
  roster mechanics). **Do not market this model as rewarding young-for-level.**
- Production (`wrc_plus`, `woba`, `slg`) ↑ promote, correctly.

## RELEASE (h_released_12mo)
- **Age-relative-to-level IS the top driver, correctly signed:** `age_minus_level_median`
  (6.9%), `age_zscore_at_level` (4.6%), `age_pctile_at_level` (3.4%) — old-for-level → release.
- Contact **quality** drives it correctly (`xba`/`xwoba`/`woba`/`wrc_plus`/`n_barrel` ↓ release).
- Raw plate-discipline (`whiff_pct` r114, `chase_pct` r79, `barrel_pct` r126) is
  **near-zero** — production stats subsume them.
- `modal_level` irrelevant (0.8%); dropping the whole level family *improves* AUC (Δ −0.005).

## reached_mlb_12mo — 🚨 headline AUC is inflated by trivial rows
- Reported 0.944, but **60.4% of positives are players already at `modal_level == mlb`**
  — the label largely restates "is already in the majors." `modal_level` ALONE scores 0.930.
- **Restricted to non-MLB prospects (the population that matters): AUC = 0.925** (still
  strong; talent features carry it), modal_level ablation Δ only 0.004.
- **Rule: never quote 0.944 as prospect skill — it's ~0.92 on prospects.** (Same pattern
  as the v2 MLB-row inflation — a recurring trap.)

## 🚩 Leakage / proxy flags (investigate before this informs a real decision)
- **`*_mlb_grad_pctile_at_level` family** (top suspect): percentile vs *players who
  graduated to MLB from that level* — denominator built from the outcome being predicted.
  Verify how the grad cohort is computed and whether it includes future seasons.
- `was_promoted_prior_year` / `was_demoted_prior_year`, `metric_jump_on_promotion_*` —
  conditioning artifacts (only defined for movers).
- `pa_trailing_90d` — playing-time proxy, top driver in both models; **confirm the PA
  window closes before the 12-mo label window opens** (else partial leakage).
- `delta_yoy_crosses_2023_boundary` — calendar seam; verify it isn't separating train (≤2024) from test (2025).

## Corrections to earlier claims in this note
1. "`_pct` is bloat" → **wrong** (peer percentile, keep) — already corrected above.
2. "age influence is the legit age-relative signal" → **only true for RELEASE.** PROMOTE
   runs on raw age + production; its age-relative features are weak and counterintuitive.
3. Importance discrepancy to reconcile: bundle reports `modal_level` ~22% gain; surrogate
   shows 59.5% gain-share on reached_mlb → different importance type / model class; reconcile.

## Artifacts saved
- `Downloads/shap_h_promoted_12mo.png` · `shap_h_released_12mo.png` (beeswarms)
- `Downloads/shap_h_promoted_12mo.csv` · `shap_h_released_12mo.csv` · `shap_results.json`
- Scripts: `C:/Users/Owner/shap_study.py` (DS) · ablation probes (skeptic)

## Next
1. Investigate the `*_mlb_grad_pctile_at_level` leakage (highest priority).
2. Confirm `pa_trailing_90d` window vs label window.
3. Reframe reached_mlb reporting to non-MLB-prospect AUC (~0.92).
4. Calibration-first re-pick for the 3 failing hitter specs (ExtraTrees calibrates best).


---

# 🔴 CONFIRMED LEAKAGE + pitcher SHAP (2026-06-26, council)

## 🔴 `*_mlb_grad_pctile_at_level` IS target leakage — must fix before any deploy

`council-skeptic` traced the code. Verdict: **LEAKAGE on three independent counts.**

1. **Cohort = the label, verbatim.** `add_mlb_grad_percentiles` (`features/deterioration.py:484`):
   `grads = labels[labels["reached_mlb_12mo"] == 1]`. The reference cohort is literally the
   positive class of `reached_mlb_12mo` (a model target; it's in `LABEL_AND_LEAK_COLS`).
   The feature is a continuous re-encoding of "how close are you to the players we labeled 1."
2. **Pools ALL seasons incl. held-out 2025** (`run_feature_etl.py:421` reads labels unfiltered;
   `:474-476/:557-559` pass no `train_seasons`). A 2023 row is ranked vs a cohort that includes
   2024–25 graduates → future outcomes leak backward. (The AgeBandLevelSeason transformer 3 lines
   away does it correctly — `tx.fit(train_df)` — this one ignored that discipline.)
3. **Self-inclusion** — no `player_id != self`; positive rows rank against themselves.
4. **Train/serve skew** — `score_active_roster.py` has no resolved 12mo outcome at serve time →
   feature can't be reproduced for live players. Broken scoring on top of leakage.

**Fix (preferred):** drop the 10 `*_mlb_grad_pctile_at_level` columns (add to
`LABEL_AND_LEAK_COLS`, remove from catalog). The AgeBandLevelSeason peer percentiles already
give a clean, label-free "vs peers at level" signal. **Confirm empirically:** retrain
`{h,p}_reached_mlb_12mo` without them; expect AUC drop = leakage signature.
Code: `features/deterioration.py:449-524`, `run_feature_etl.py:421,474-476`, `catalog.py:455-475,914-934`.

## ⚾ Pitcher SHAP — production dominates, stuff/command are minor (Zac was right)

LightGBM surrogates, TEST 2025: p_promoted AUC 0.824, p_released 0.825 (faithful; surrogates
overfit so trust ranks+univariate, not exact %).

**Promote drivers:** modal_level (rank1, 25.6%) → **K-BB% (#2)** → gcera (#7,↓) → fip (#9,↓).
**Release drivers:** fb_velo (#6,↓), fip (#7,↑), stuff_plus (#8,↓), K-BB% (#13,↓).

Direct answers to "do velo / in-zone% matter?":
- **FF velo:** weak for PROMOTE (rank 50, 0.44%, flat univariate — raw mph doesn't predict
  promotion); but a real **release floor** (rank 6, higher velo → less release, 24.9%→7.9%).
- **In-zone% (`inz_pct`):** near-noise (rank 84/63, <0.5%); points up on promote but inconsistent
  on release. **Command is not a meaningful v1 driver.** `fpinz_pct` flat everywhere.
- **Production (K-BB%/FIP/gcERA) out-ranks raw stuff/command ~5–8×.** Stuff matters mainly as a
  release floor (bad stuff → cut).

**Corroborates the leakage:** `fb_velo_mlb_grad_pctile_at_level_pct` is **rank 3 (3.1%)** in
promote → a chunk of the model's apparent "stuff" signal is the *circular* grad-pctile, not real velo.

## 🐛 Data bug: `fb_velo_p90` / `fb_velo_p10` are 100% NaN

Both velo-spread (peak/endurance) columns are empty across all 68,049 rows — never populated.
Inert (don't hurt the model) but anyone citing "we model velo ceiling/floor" should know they're dead.

## Artifacts
`Downloads/shap_p_promoted_12mo.png` · `shap_p_released_12mo.png` ·
`shap_p_promoted_12mo_importances.csv` · `shap_p_released_12mo_importances.csv`

## Action queue (priority order)
1. 🔴 **Drop `*_mlb_grad_pctile_at_level` (×10)** → retrain → confirm reached_mlb AUC drop. Gates everything.
2. Fix/remove the empty `fb_velo_p90/p10` columns.
3. Reframe reached_mlb reporting to non-MLB prospects (~0.92, not 0.944).
4. Verify `pa_trailing_90d` window vs label window.
5. Calibration-first re-pick for the 3 failing hitter specs (ExtraTrees calibrates best).
6. Investigate the promote raw-age / backwards age-relative pattern.


---

# ✅ Empirical leakage test — the leak is REAL but REDUNDANT (2026-06-26)

Retrained `reached_mlb_12mo` h+p, TEST 2025, WITH vs WITHOUT the 10 `*_mlb_grad_pctile_at_level`
features:

| spec | AUC full | AUC no-leak | drop (all) | non-MLB full | non-MLB no-leak | drop |
|---|---|---|---|---|---|---|
| h_reached_mlb_12mo | 0.944 | 0.944 | **+0.001** | 0.925 | 0.923 | +0.002 |
| p_reached_mlb_12mo | 0.946 | 0.946 | **+0.000** | 0.938 | 0.937 | +0.001 |

**Verdict (correcting the earlier expectation): removing the leak barely moves AUC (~0).**
The leaked features are **redundant** — their signal is already carried by `modal_level` + the
other `*_at_level` features. So:
- The code IS leaky/wrong (cohort=label, future-season pooling, self-inclusion, train/serve skew)
  → **still drop them**, but the reason is **serving hygiene** (they can't be reproduced for live
  players → broken live scores), NOT accuracy inflation.
- The earlier "leak inflates everything" framing was **wrong in magnitude** — empirically disproven.
  The real inflation of reached_mlb's 0.944 is the **60%-already-in-MLB trivial rows**; the honest
  prospect number is **~0.92–0.94 and it HOLDS without the leak.**

**Net:** v1 is in better shape than feared — the models do NOT depend on the leak. Dropping it is
clean-up, not a fire. (Lesson logged: confirm magnitude empirically before calling something a
load-bearing bug — same discipline that caught v2's mirage.)
