---
type: concept
domain: pitching
source: personal-bsbres
created: '2026-06-15'
---
# tjStuff+ (v3.0)

Public Stuff+ model by **Thomas Nestico ([@TJStats](https://x.com/TJStats))**. Open repo (`tj_stuff_plus_v3.ipynb`) + Medium write-up + Streamlit app; ships with a 2024 MLB pitch-grade CSV and the model joblibs (`lgbm_model_2020_2022.joblib`, `lgbm_model_2020_2023.joblib`). Goal: "predict the Expected Run Value of a pitch based off its physical characteristics."

## What it models
**Expected Run Value of a pitch from physical characteristics** — pitch quality independent of result. The tree-based open-source counterpart to the [[stuff-plus-deep-learning]] (DL) framing.

## Inputs / features (exactly 10, source-verified)
```python
features = ['start_speed', 'spin_rate', 'extension',
            'az', 'ax',          # vertical & horizontal acceleration = movement
            'x0', 'z0',          # release point (horizontal, vertical)
            'speed_diff', 'az_diff', 'ax_diff']  # vs the pitcher's primary fastball
target   = 'target'              # run value
```
- `az`/`ax` are pitch accelerations (movement proxies); `x0`/`z0` are release coordinates.
- **Fastball-relative deltas** (`speed_diff`/`az_diff`/`ax_diff`) are computed against the pitcher's **primary fastball** — chosen from SI/FF/FC, grouped per (pitcher, year, pitch_type), sorted by **count then avg speed** (most-thrown, hardest).
- **Handedness collapse for LHP:** `ax → −ax` (mirror horizontal break) and **RHP `x0 → −x0`** (LHP `x0` left as-is) so the model is handedness-neutral. Velocity and iVB are the top features.

## Method
A **`LGBMRegressor`** ([[lightgbm-baseball-modeling]]) inside a **`RobustScaler` pipeline** — a gradient-boosted regressor, *not* a neural net. Verbatim hyperparameters:
```python
make_pipeline(RobustScaler(),
  LGBMRegressor(n_estimators=1000, learning_rate=0.01, num_leaves=31,
    max_depth=-1, min_child_samples=20, subsample=0.8, colsample_bytree=0.8,
    reg_alpha=0.1, reg_lambda=0.2, random_state=42))
```
Two models ship: **trained 2020-2022 → tested 2023** (for year-over-year predictiveness) and **trained 2020-2023 → tested 2024** (the production grades).

## Target / units / scaling
- **Target = Run Value**, sourced from Statcast **`delta_run_exp`** keyed by `(event, balls, strikes)` (the bundled `run_values.csv`; e.g. a 0-0 ball = +0.0347, a 0-0 called strike = −0.0389, a 0-0 double = +0.787). Per-pitch RV is reported as **xRV/100** (`target × 100`).
- **Index construction:** z-score the predicted RV, then **`tj_stuff_plus = 100 − (z_score × 10)`.** The **−10** flips the sign (lower RV = better pitch → higher grade) and sets ~100-centered, std ≈ 10 at the pitch level. (The aggregated "All" rows in the 2024 CSV show mean ≈ 99.93, std ≈ 5.0 because per-pitcher season averages compress the spread.)
- Also surfaced as a **20-80 `pitch_grade`** and per-pitcher percentile_1 / percentile_99 columns.

## Key takeaways
A clean, reproducible **open-source Stuff+**. The grade is **higher = nastier** despite the model targeting (lower-is-better) run value, thanks to the sign flip. Useful as a transparent reference for what the proprietary models (FanGraphs, Driveline [[independent-stuff-value]]) approximate.

## Links
[[MOC-baseball-analytics]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[lightgbm-baseball-modeling]] · [[driveline]] · [[stuff-plus-deep-learning]] · [[mix-plus-sync]] · [[driveline-hitting-models]] · [[independent-stuff-value]]
