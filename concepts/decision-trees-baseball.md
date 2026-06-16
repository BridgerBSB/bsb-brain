---
type: concept
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# Decision Trees — baseball biomech

`DecisionTreeRegressor` predicting `pitch_speed_mph` / `bat_speed_mph` from force-plate features — the simplest model family in the [[dsproj-data-science-examples]] corpus and the baseline against which RF/SVR were judged. Artifacts: `best_decision_tree_model.pkl` (45 KB), `best_dec_tree_model.pkl`.

## The four scripts (escalating sophistication)

### 1. `basic_DT.py` — toy single-feature demo
Pedagogical stub. Loads `hp_test.csv`, drops `not_pitchers`, then does a positional-index single-feature tree (`X = dataset.iloc[:, 1:2]`, `y = dataset.iloc[:, 2]`) on a `DecisionTreeRegressor(random_state=0)` with **no train/test split, no tuning** — `regressor.predict([[3750]])` prints "Predicted Velo". Carries a commented hard-coded video-game dataset (Asset Flip / RPG / MMORPG) — it's literally a sklearn tutorial adapted to the velo data. Not a real model.

### 2. `dttest.py` — real single tree + SHAP
```python
dtree = DecisionTreeRegressor(min_samples_split=20, random_state=123)
```
- Target `bat_speed_mph`, the canonical 5 features, 80/20 split (`random_state=123`).
- Eval: MSE, MAE, R², `pearsonr`. Saves `best_decision_tree_model.pkl`.
- SHAP: `TreeExplainer` → `summary_plot` + bar + `force_plot(..., matplotlib=True)`.
- The `not_pitchers` exclusion is **commented out** here (bat-speed target keeps everyone).

### 3. `dec_tree_real.py` — GridSearch-tuned tree + SHAP
```python
param_grid = {'n_estimators': [100, 200, 300, 500],   # (no-op for a single tree)
              'max_depth': [1, 5, None],
              'min_samples_split': [2, 5, 10, 20]}
dt = tree.DecisionTreeRegressor(min_samples_split=20)
grid_search_dt = GridSearchCV(dt, param_grid, cv=10, scoring='r2', verbose=1)
```
- Target `pitch_speed_mph`, applies `not_pitchers`. Saves `best_dec_tree_model.pkl`. Full SHAP (TreeExplainer beeswarm/bar/force).
- **Gotcha worth noting:** `n_estimators` is in the grid but `DecisionTreeRegressor` ignores it (that's a forest param) — a copy-paste artifact from the RF script. It still runs because GridSearchCV passes it and the estimator silently... actually `set_params` would error; in practice this is the kind of latent bug the corpus contains.

### 4. `dec_tree_iteration.py` — tree + R²-gated CSV writeback
Trains a plain `DecisionTreeRegressor(random_state=42)` (the GridSearch/SVR setup at the top is dead scaffolding — `svr_model`/`grid_search` are built but never fit). Then the **conditional ship gate**:
```python
r2 = r2_score(y_test, y_pred)
if r2 > 0.65:
    df['predicted_pitch_speed'] = model.predict(df[features])
    df.to_csv('hp_test_with_predictions.csv', index=False)
    print("Success: 'predicted_pitch_speed' added to the dataset.")
else:
    print("Model Failure")
```
This is the **0.65 R² acceptance threshold** for the whole corpus — only write a predicted-velo column back if the model clears it. (It has a latent bug: `X = df[features]` / `y = df[target]` index a DataFrame by a DataFrame, which would raise — the working path is `df_clean[features.columns]`.)

## Common pattern

`replace('\\N', pd.NA)` → optional `not_pitchers` drop → `dropna(subset=features+[target])` → 80/20 split (`random_state=123`) → `min_samples_split=20` is the recurring regularizer → MSE/MAE/R²/pearson → `joblib.dump` → SHAP TreeExplainer.

## Links

- [[dsproj-data-science-examples]] (parent index)
- [[velo-prediction-rf]] (the RF these trees baseline against) · [[support-vector-regression-baseball]]
- [[lightgbm-baseball-modeling]] (the Astros production GBM — same TreeExplainer SHAP loop)
- [[statcast-pipeline]] · [[stuff-plus-4s-pitching]]
