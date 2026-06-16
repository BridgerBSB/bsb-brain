---
type: concept
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# Velo prediction — Random Forest (force-plate → pitch speed)

Random-forest regression predicting a pitcher's **`pitch_speed_mph`** (and, by target-swap, a hitter's **`bat_speed_mph`**) from **force-plate + body-composition** features. The flagship model of the [[dsproj-data-science-examples]] corpus — its artifact is the 4.1 MB `best_random_forest_model.pkl`.

## Model

- **Library:** `sklearn.ensemble.RandomForestRegressor(random_state=123)`
- **Tuning:** `GridSearchCV(cv=10, scoring='r2', verbose=1)` (5-fold in `hp_test_gpt.py`/`backup.py`)
- **Split:** `train_test_split(test_size=0.2, random_state=123)`
- **Save:** `joblib.dump(grid_search_rf.best_estimator_, 'best_random_forest_model.pkl')`

### Hyperparameter grids (vary per script)

`velo_pred_rf.py` / `random_forest.py`:
```python
param_grid = {
    'n_estimators': [100, 250, 500, 1000],
    'max_depth':    [5, 10, 20, None],
    'min_samples_split': [2, 10, 25, 50]
}
```
`hp_test_gpt.py` (narrower, deeper):
```python
{'n_estimators': [500, 1000, 1500], 'max_depth': [15, 20, None],
 'min_samples_split': [10, 20, 30]}
```
`backup.py`: `{'n_estimators':[100,200,500], 'max_depth':[None,10,20], 'min_samples_split':[2,5,10]}`.

## Target & features

- **Target:** `pitch_speed_mph` (velo models) — note the `not_pitchers` list (~26 names: Ohtani, Darvish, Wei-Yin Chen, position players, female athletes) is `df[~df['athlete_name'].isin(not_pitchers)]`-filtered out so the velo target is clean. `hp_test_gpt.py` swaps target to `bat_speed_mph` in some runs (keeps everyone).
- **Features — `velo_pred_rf.py` (richest, 14):**
  ```python
  features = ['net_peak_vertical_force_[n]_max_imtp',
              'concentric_peak_force_[n]_mean_cmj',
              'eccentric_peak_force_[n]_mean_cmj',
              'peak_takeoff_force_[n]_mean_pp',
              'jump_height_(imp-mom)_[cm]_mean_cmj','peak_power_/_bm_[w/kg]_mean_cmj',
              'eccentric_braking_rfd_[n/s]_mean_cmj','rsi-modified_[m/s]_mean_cmj',
              'jump_height_(imp-mom)_[cm]_mean_sj','peak_power_/_bm_[w/kg]_mean_sj',
              'best_rsi_(jump_height/contact_time)_[m/s]_mean_ht',
              'ShoulderERR']
  ```
  (Note the commented-out `peak_power_[w]_mean_cmj`/`_sj` and `body_weight_[lbs]` — this script was the feature-selection sandbox, with `#<-best, test ->` markers.)
- **Features — `random_forest.py` / `hp_test_gpt.py` / `backup.py` (core ~5–10):** `peak_power_[w]_mean_{cmj,sj}`, `net_peak_vertical_force_[n]_max_imtp`, `best_rsi_(flight/contact_time)_mean_ht`, `body_weight_[lbs]`, plus (random_forest.py) `concentric/eccentric_peak_force`, `peak_takeoff_force`, jump-height + RSI-modified terms.

## Pipeline

1. `df.replace('\\N', pd.NA)` (MySQL null token), drop `not_pitchers`.
2. `df_clean = df.dropna(subset=features + [target])` → `X`, `y`.
3. 80/20 split → GridSearchCV → `best_estimator_`.
4. Eval: `mean_squared_error`, `mean_absolute_error`, `r2_score`, `scipy.stats.pearsonr(y_test, y_pred)` correlation coefficient, print `best_params_`.
5. **SHAP attribution:** `shap.TreeExplainer(best_estimator_)` → `shap_values(X_test)` → `summary_plot` (beeswarm) + `summary_plot(..., plot_type="bar")` + `force_plot(expected_value, ...)`. Outputs `x_pred_batspeed_SHAP.png`, `x_pred_bs_bar.png`, `rf_model_1.png`.

## Linear baseline (sibling models)

`svr2.py` carries (commented) the **closed-form regression coefficients** that an `lm` produced before the ML rewrite — the analytic ancestor of these models, worth quoting:
```python
predicted_velo = (-192.2 + 3.265e-3*peak_power_sj + 1.136e-3*net_peak_vert_force_imtp
                  - 0.2662*body_weight + 58.50*log(body_weight))
predicted_bat_speed = (-138.7 + 3.079e-3*peak_power_sj + 1.420e-3*net_peak_vert_force_imtp
                       - 0.1682*body_weight + 41.58*log(body_weight))
```
Note the **log(body_weight)** term — velo/bat-speed buy a diminishing return on mass. The R Shiny apps (`r_hp_test1.R`, `disclude_p_linear.R`) expose this as an interactive `lm` scatter (`geom_smooth(method="lm")`) with a live correlation coefficient, filtered by `playing_level` (Pro/College/HS). Output `linear_pred_velo.png`.

## Result framing

`dec_tree_iteration.py` documents the implied acceptance bar: it only writes predictions back to CSV **if `r2 > 0.65`** ("Model Failure" otherwise) — so ~0.65 R² was the "good enough to ship a predicted-velo column" threshold for this family.

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[support-vector-regression-baseball]] · [[decision-trees-baseball]] (sibling models, same features/target)
- [[lightgbm-baseball-modeling]] — Astros production analogue (GBM + SHAP)
- [[statcast-pipeline]] · [[stuff-plus-4s-pitching]]
- [[biomech-scores]] · [[hitting-biomechanics]] (measurement side of the same biomech→velo link)
