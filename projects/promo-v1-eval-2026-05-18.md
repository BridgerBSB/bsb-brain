---
type: artifact
created: '2026-05-18'
source: v1 eval_report.md (pasted in chat 2026-06-23)
tags:
  - modeling
  - v1
  - eval
  - artifact
---
# v1 Promotion Models — Eval (2026-05-18)

Persisted from chat (was only ever pasted, never saved). The **priority model**:
release / hold / promote / stickiness, 14 specs (7 outcomes × H/P).
Parent: [[promotion-release-models]] · register: [[artifacts-register]].
Train = 2022–2024 (val 2024), Test = 2025.

## Headline metrics (test 2025)

| spec | side | AUC | cal_slope | pos_rate | sanity |
|---|---|---|---|---|---|
| h_promoted_12mo | H | 0.775 | **0.442** | 0.200 | ❌ cal |
| h_promoted_3mo | H | 0.839 | 0.937 | 0.178 | ✅ |
| h_released_12mo | H | 0.820 | 1.212 | 0.118 | ✅ |
| h_stuck_variant_a | H | 0.943 | **0.646** | 0.564 | ❌ cal |
| h_stuck_variant_b | H | nan | nan | 0.000 | ⚠️ degenerate |
| h_stuck_variant_c | H | 0.948 | 0.824 | 0.772 | ✅ |
| h_reached_mlb_12mo | H | 0.943 | **0.547** | 0.225 | ❌ cal |
| p_promoted_12mo | P | 0.817 | 0.909 | 0.231 | ✅ |
| p_promoted_3mo | P | 0.848 | 0.849 | 0.212 | ✅ |
| p_released_12mo | P | 0.832 | 1.110 | 0.129 | ✅ |
| p_stuck_variant_a | P | 0.934 | 0.820 | 0.408 | ✅ |
| p_stuck_variant_b | P | nan | nan | 0.000 | ⚠️ degenerate |
| p_stuck_variant_c | P | 0.957 | 0.930 | 0.700 | ✅ |
| p_reached_mlb_12mo | P | 0.943 | 0.704 | 0.219 | ✅ |

## ⚾ + 🔬 council read

- **Pitchers > hitters, on calibration:** every pitcher model passed; **3 hitter
  models failed** the 0.70 cal-slope floor (h_promoted_12mo cal **0.44** is the
  flagship). AUCs comparable; calibration is the gap. (Pitcher "stuff" is stable;
  hitter offense noisier + leans on scarcity/defense the model can't see.)
- **Suspiciously high stickiness** (precision@k 0.99–1.0) → 🧨 Skeptic flag: possible
  leakage / trivially-separable label. Verify before trusting.
- **variant_b degenerate** (WAR unwired) → ships as 0.
- **Open tuning leads:** hitter calibration; whether **age over-dominates the hitter
  side** (SHAP TBD — raw-age vs age-relative-to-level); widen features with all
  affiliate tracker metrics (additive, behind a flag).

Artifacts (work laptop): `data/models/*.joblib`, `data/models/importance/*.csv`,
`data/eval_report.md`. Needed for the SHAP study → see [[promotion-release-models]].
