---
type: concept
domain: modeling
created: '2026-06-15'
---
# LightGBM baseball modeling

Gradient-boosted trees for baseball *decision/outcome* models — interpretable
(shallow `max_depth`), handles mixed features, pairs with SHAP for feature
attribution. The workhorse classifier across the portfolio.

**Used in:** [[send-from-2b]] (send-success classifier, ROC-AUC 0.717; features =
sprint speed, distance-home, arm strength, LA, EV) → [[send-hold-decisions]].
**Related:** [[re24-run-expectancy]] (turns P(success) → xRV) · [[statcast-pipeline]].
**Portfolio precursor:** [[dsproj-data-science-examples]] — same GridSearch→best_estimator→SHAP loop done with sklearn RF/SVR/DT ([[velo-prediction-rf]], [[support-vector-regression-baseball]], [[decision-trees-baseball]]) on force-plate→velo prediction.
**Astros tie-in:** same family as the [[promotion-models-status|promotion models]]
(14 LightGBM models → Promote/Release/Stickiness). Pattern: GBM P(event) + a
value layer (RE24 / run weights) → coach-facing recommendation.
