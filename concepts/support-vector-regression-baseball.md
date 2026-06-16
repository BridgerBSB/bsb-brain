---
type: concept
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# Support Vector Regression — baseball biomech

SVR predicting **`bat_speed_mph`** (and `pitch_speed_mph`) from force-plate features. The 41 KB `best_svr_model.pkl` and `trained_svr_model_pitchers.pkl` come from this group. Part of the [[dsproj-data-science-examples]] corpus.

## Model

- **Library:** `sklearn.svm.SVR` (Python); `e1071`/`caret` `svmRadial` (R, `SVR1.R`).
- **Tuning:** `GridSearchCV(scoring='r2', cv=5, verbose=1)`.
- **Grid (every Python SVR script identical):**
  ```python
  param_grid = {'C': [0.1, 1, 10],
                'epsilon': [0.1, 0.2, 0.5],
                'kernel': ['rbf', 'poly']}
  ```
  R port: `expand.grid(C=c(0.1,1,10), epsilon=c(0.1,0.2,0.5), kernel=c("radial","polynomial"))`.
- **Split:** `train_test_split(test_size=0.2, random_state=123)`; R uses `caret::createDataPartition(p=0.8)` with `set.seed(123)`.

## Target & features

- **Features (the canonical 5 — no extended set here):**
  ```python
  ['peak_power_[w]_mean_cmj', 'peak_power_[w]_mean_sj',
   'net_peak_vertical_force_[n]_max_imtp',
   'best_rsi_(flight/contact_time)_mean_ht',
   'body_weight_[lbs]']
  ```
- **Target:** `bat_speed_mph` in `SVR.py`, `SQL_SVR_comb_2.py`, `SQL_pull_test.py`, `SVR1.R` (saved `trained_svr_model_hitters.pkl/.rds`). `svr2.py` targets `pitch_speed_mph` (with the `not_pitchers` exclusion) → `trained_svr_model_pitchers.pkl`.

## Script variants

| Script | Data source | Target | Notes |
|---|---|---|---|
| `SVR.py` | CSV `hp_test.csv` | bat speed | bare SVR, no SHAP |
| `svr2.py` | CSV `hp_test_data.csv` | pitch speed | applies `not_pitchers`; carries the commented closed-form `lm` coeffs (the linear baseline) |
| `SQL_SVR_comb_2.py` | CSV | bat speed | **adds KernelExplainer SHAP** |
| `SQL_pull_test.py` | **live pymysql** `hp_data.hp_tests` | bat speed | pulls features directly from DB, then SVR + SHAP |
| `SVR1.R` | `data.table::fread` | bat speed | `caret`/`e1071` R port, `saveRDS` |

## Evaluation

`mean_squared_error`, `r2_score`, plus (the SHAP variants) `mean_absolute_error` and `pearsonr` correlation coefficient; prints `best_params_`.

## SHAP for SVR — KernelExplainer (key technique)

SVR is not tree-based, so it can't use `TreeExplainer`. The scripts use the model-agnostic **`shap.KernelExplainer`** with a **background sample for tractability** (KernelExplainer is O(2^features) per-row, so they subsample):

```python
X_train_sample = X_train.sample(50, random_state=123)        # background distribution
explainer = shap.KernelExplainer(best_svr.predict, X_train_sample)
X_test_sample = X_test.sample(50, random_state=123)          # explain a 50-row slice
shap_values = explainer.shap_values(X_test_sample)
shap.summary_plot(shap_values, X_test_sample, feature_names=...)        # beeswarm
shap.summary_plot(shap_values, X_test_sample, ..., plot_type="bar")     # mean |SHAP|
shap.force_plot(explainer.expected_value, shap_values[0], X_test_sample.iloc[0])
```

This 50-row background / 50-row explain pattern is the reusable lesson: KernelExplainer can't run on the full set, so pick a small representative background + explain a sample.

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[velo-prediction-rf]] · [[decision-trees-baseball]] (sibling models)
- [[lightgbm-baseball-modeling]] · [[statcast-pipeline]] · [[stuff-plus-4s-pitching]]
- [[biomech-scores]]
