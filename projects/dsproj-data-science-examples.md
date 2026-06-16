---
type: project
domain: modeling
source: personal-bsbres/examples
created: '2026-06-15'
---
# DS Projects — Data Science Examples Corpus

Index of the `personal-bsbres/examples/data-science-projects/` code corpus. This is Zac's **pre-Astros / portfolio** body of work: biomechanics-driven velocity & bat-speed prediction (Driveline-style "Open Biomechanics" force-plate data), a Blue Jays player-valuation scoring exercise, and supporting SQL/viz plumbing. It predates the GroundControl2 production codebase but shows the same instincts — GBM/tree models + SHAP attribution, percentile scoring, radar/web visual comps — that later show up in the Astros [[promotion-models-status|promotion models]] and the BSB report apps.

Everything here trains on **force-plate + body-comp features** to predict **on-field velocity** (`pitch_speed_mph`) or **bat speed** (`bat_speed_mph`). This is the inverse of the Astros production stack, which works from *outcome* data (Statcast/Hawkeye pitch + BIP) — here the inputs are weight-room/athletic-testing measurements and the target is the velocity they "buy."

## The data

| Dataset | What | Source |
|---|---|---|
| `hp_test.csv` (4 MB) / `hp_test_data.csv` (357 KB) | **High-Performance testing** — one row per athlete test. Force-plate aggregates (CMJ, SJ, IMTP, plyo pushup, hop test) + `body_weight_[lbs]` + `pitch_speed_mph` + `bat_speed_mph` + `athlete_name`. | DigitalOcean MySQL `hp_data.hp_tests` |
| `boddy_twt.csv` (4.7 MB) | Biomechanics/strength by competition `level` ("17u/16u/15u/14u" → "high school", "college", "milb"). Driveline ("Boddy" = Kyle Boddy / Driveline) Twitter-recreation data. | local CSV |
| `bluejays_q/Player Valuation Exercise 2 Player List.csv` | Toronto Blue Jays take-home: ~33 college draft prospects, full hitting + pitching + per-pitch-type scouting columns (xwOBAcon, AirPullPct, FB Velocity, etc.). | provided by TOR |

The HP data lives in two MySQL instances queried via SQLAlchemy / pymysql:
- `hp_data` @ `computer-vision-cluster-do-user-286562-0...ondigitalocean.com:25060` — force-plate test results.
- `theia_hitting_db` @ `10.200.200.107:3306` — Theia markerless biomech (`poi`/`trials`/`sessions`/`users`), `blast_bat_speed_mph`.

## The feature set (canonical across nearly every model)

Five-to-fourteen force-plate / body-comp columns. The **core 5** reused everywhere:

- `peak_power_[w]_mean_cmj` — countermovement-jump peak power (W)
- `peak_power_[w]_mean_sj` — squat-jump peak power (W)
- `net_peak_vertical_force_[n]_max_imtp` — isometric mid-thigh pull, net peak vertical force (N)
- `best_rsi_(flight/contact_time)_mean_ht` — reactive strength index from hop test
- `body_weight_[lbs]`

Extended runs add `concentric_peak_force_[n]_mean_cmj`, `eccentric_peak_force_[n]_mean_cmj`, `peak_takeoff_force_[n]_mean_pp` (plyo pushup), `jump_height_(imp-mom)_[cm]_mean_{cmj,sj}`, `peak_power_/_bm_[w/kg]_mean_{cmj,sj}`, `eccentric_braking_rfd_[n/s]_mean_cmj`, `rsi-modified_[m/s]_mean_cmj`, `best_rsi_(jump_height/contact_time)_[m/s]_mean_ht`, `ShoulderERR`, `pitching_max_hss`.

A hard-coded **`not_pitchers` exclusion list** (~26 names — Ohtani, Darvish, position players, female athletes, etc.) is stripped from the pitcher (`pitch_speed_mph`) models so the velocity target reflects actual pitchers. Bat-speed models keep everyone.

## The models (see atomic concept notes)

| Technique | Target | Lib | Note |
|---|---|---|---|
| Random forest (GridSearch + SHAP) | `pitch_speed_mph` | scikit-learn | [[velo-prediction-rf]] |
| Random forest | `bat_speed_mph` (`hp_test_gpt`-style swap) | scikit-learn | [[velo-prediction-rf]] |
| Support vector regression (RBF/poly, GridSearch) | `bat_speed_mph` / `pitch_speed_mph` | scikit-learn / e1071 (R) | [[support-vector-regression-baseball]] |
| Decision tree regressor (single + GridSearch) | both | scikit-learn | [[decision-trees-baseball]] |
| Linear regression (closed-form coeffs) | velo + bat speed | base R `lm` (Shiny app) | [[velo-prediction-rf]] §linear baseline |
| Radar / "web" comp chart (90+ vs 95+ vs min) | n/a (viz) | matplotlib polar | [[radar-chart-viz]] |
| Percentile rank scoring | composite "simple_score" | pandas `.rank()` | [[percentile-rank-scoring]] |

All three saved `.pkl` artifacts (`best_random_forest_model.pkl` 4.1 MB, `best_svr_model.pkl` 41 KB, `best_decision_tree_model.pkl` 45 KB, `trained_svr_model_pitchers.pkl`) come from these scripts.

## Script-group map

- **Random forest:** `random_forest.py`, `velo_pred_rf.py`, `hp_test_gpt.py`, `backup.py` — all RF velo predictors, varying feature lists + `param_grid`. `velo_pred_rf.py` is the richest (14 features incl. `ShoulderERR`).
- **SVR:** `SVR.py`, `svr2.py`, `SQL_SVR_comb_2.py`, `SVR1.R` — RBF/poly SVR with KernelExplainer SHAP. `SQL_pull_test.py` is the live-DB SVR variant. `SVR1.R` is the R/`caret`/`e1071` port.
- **Decision trees:** `basic_DT.py` (toy single-feature demo), `dec_tree_real.py` + `dttest.py` (real DT regressors + SHAP), `dec_tree_iteration.py` (DT with R²>0.65 gate that writes predictions back to CSV).
- **Radar/web viz:** `radar_90mph.py`, `radar_final.py`, `rct.py`, `test_MIN.py` — polar comps of 90+ vs 95+ vs minimum across 6–7 force-plate axes.
- **Bat-speed correlation viz:** `recreating_bs_twt.py` — seaborn boxplots of force-plate metrics by competition level (recreating a Driveline "Boddy" tweet).
- **SQL / plumbing:** `sql_setup.py`, `SQL_pull_test.py`, `expanded_sql.py` (cross-DB outer-join of Theia bat speed ↔ HP peak power), `90plus.sql`.
- **R / Shiny:** `r_hp_test1.R` (interactive scatter+`lm` explorer), `disclude_p_linear.R` (same Shiny app, level-checkbox version), `SVR1.R`.
- **Blue Jays exercise:** `bluejays_q/bluejays.py` (percentile scoring), `bluejays_q/jays_image.py` (red/white/blue heat-styled table).

## How it relates to the Astros work

- **Same modeling DNA** as [[lightgbm-baseball-modeling]] / [[statcast-pipeline]]: tree-ensemble P(target) + SHAP attribution. The Astros [[promotion-models-status|promotion models]] are LightGBM where these are sklearn RF/DT/SVR, but the GridSearch→best_estimator→SHAP loop is identical.
- **Percentile scoring** ([[percentile-rank-scoring]]) is the direct ancestor of the report-app "P-metric" coloring and the org-KPI rank tables.
- **Radar comps** ([[radar-chart-viz]]) prefigure the report "web chart strength" visuals.
- The **biomech→velo causal direction** is what the production [[biomech-scores]] / [[hitting-biomechanics]] notes describe from the *measurement* side; this corpus is the *predictive* side.

## Links

- [[MOC-baseball-analytics]]
- [[lightgbm-baseball-modeling]] · [[statcast-pipeline]] · [[stuff-plus-4s-pitching]]
- [[biomech-scores]] · [[hitting-biomechanics]] · [[driveline-hitting-models]]
- Concept notes: [[velo-prediction-rf]] · [[support-vector-regression-baseball]] · [[decision-trees-baseball]] · [[radar-chart-viz]] · [[percentile-rank-scoring]]
