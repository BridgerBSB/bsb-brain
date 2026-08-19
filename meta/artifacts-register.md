---
type: meta
created: '2026-06-26'
tags:
  - meta
  - artifacts
  - register
  - ways-of-working
---
# 🗂️ Artifacts Register

**Every data file / model / report Zac feeds gets logged here so it stops
vanishing into chat.** Text artifacts get a saved vault copy; big binaries get
their location recorded (and flagged to move to a stable archive). Maintained by
**`/document`**; consumed by the [[advisory-council]].

> ⚠️ **Recurring problem this fixes:** fed CSVs/models/reports were never saved →
> couldn't be reused. (Echoed by @h100envy "Loop Engineering": *persistence —
> results save to disk so they don't vanish when context clears.* See [[context-library]].)

## Register

| Date | Artifact | Type | Lives at | What it is | Saved copy |
|---|---|---|---|---|---|
| 2026-06-26 | `models_wrc.zip` | binary (4 joblib) | `C:\Users\Owner\Downloads\` | v2 bake-off models: wrc_plus/xwoba × lightgbm/ridge | — ⚠️ move to archive |
| 2026-06-26 | `wrc_oof_predictions.parquet` | parquet (19,205×13) | `Downloads\` | v2 out-of-fold preds + actuals + level/age — the file that exposed the MLB-row inflation | — ⚠️ archive |
| 2026-06-26 | `wrc_features_hitter.parquet` | parquet (19,205×41) | `Downloads\` | v2 hitter feature matrix (Barrelsville pins + labels) | — ⚠️ archive |
| 2026-06-26 | `wrc_label_hitter.parquet` | parquet (5,575×18) | `Downloads\` | v2 labels (career MLB wRC+/xwOBA from `07_label_hitter_mlb.sql`) | — ⚠️ archive |
| 2026-06-26 | `wrc_eval_report.md` | text | `Downloads\` | v2 bake-off eval report | ✅ [[promo-v2-wrc-eval-2026-06-26]] |
| 2026-06-26 | `wrc_train_summary.csv` | csv (4 rows) | `Downloads\` | v2 headline metrics | ✅ folded into eval note |
| 2026-05-18 | v1 eval report | text (pasted in chat) | chat only → now saved | v1 14-model promote/release/stickiness eval | ✅ [[promo-v1-eval-2026-05-18]] |
| 2026-06-26 | `models.zip` | binary (14 joblib) | `Downloads\` (extracted → `Downloads\v1_extract\`) | v1 WINNER bundles (real per-spec classes: LogReg/ExtraTrees/RF/LightGBM) | ✅ analysis → [[promo-v1-importance-comparison-2026-06-26]] |
| 2026-06-26 | `comparison.zip` | csv/parquet/md | `Downloads\v1_extract\` | compare_models outputs: winner_summary, by_class_summary, per-spec leaderboards | ✅ [[promo-v1-importance-comparison-2026-06-26]] |
| 2026-06-26 | `bsb-wt-modeling.zip` | full worktree | `Downloads\` → data extracted to worktree | work-laptop worktree incl. gitignored `data/` (promo_features_h/p, promo_labels, models) | ✅ data now at `bsb-wt-modeling/pd-goals/modeling/data/` |
| 2026-06-26 | SHAP outputs (hitter) | png/csv/json | `Downloads\shap_h_*.png/.csv`, `shap_results.json` | council SHAP beeswarms + tables (h_promoted, h_released) | ✅ [[promo-v1-importance-comparison-2026-06-26]] |
| 2026-06-26 | SHAP outputs (pitcher) | png/csv | `Downloads\shap_p_*.png`, `shap_p_*_importances.csv` | council SHAP (p_promoted, p_released) — velo/command vs production | ✅ [[promo-v1-importance-comparison-2026-06-26]] |

## TODO — stable binary archive

Downloads is not durable. Proposed permanent home for fed binaries:
`C:\Users\Owner\bsb-data-archive\<project>\<date>\` (outside any git repo). Until
then, **don't delete the Downloads files above** — they're the only copies.

Related: [[context-library]] · [[advisory-council]] · [[promotion-release-models]]


## 2026-06-27 additions
- `Downloads/calibration_repick.csv` (2025 split) + `calibration_repick_resolved.csv` (resolved 2024 split) — A/B leak-free calibration re-pick. Scripts: `repick.py`, `repick_resolved.py`. → [[promo-v1-fixes-and-runbook-2026-06-27]]

| 2026-07-03 | Release E-round + RISK blend receipts | 5-experiment council round + blend rigor (learned 61/39, bootstrap CI) | git: `bsb-wt-modeling/pd-goals/modeling/research/e_round/` (results.md per exp, `final/*.csv|json`) | The statistical case for the Release RISK headline; every AUC claim traceable | committed `8c526ab7`→`08b5a1ac` |
| 2026-07-03 | One-view release boards (HTML deliverables) | generated from `final/one_view_*.csv` by scratchpad scripts (ephemeral) — REGENERABLE from the CSVs | CSVs in git (durable); HTMLs were session-temp | Top-25 combined + components + blue/green diff shown to Zac | regenerate on demand |

## 2026-07-09 additions

| Date | Artifact | Type | Lives at | What it is | Saved copy |
|---|---|---|---|---|---|
| 2026-07-09 | `2026-07-09-hou-spring-2026-releases.csv` | csv (24 rows) | `bsb-wt-modeling/pd-goals/modeling/research/discovery/` | HOU spring-2026 release list from TR_HISTORY (22 RELES + 2 RETIR; Lambert flagged resigned_30d=1) — input to the release-model backtest | ✅ [[promo-release-spring2026-release-list]] |
| 2026-07-09 | `2026-07-09-hou-spring-2026-departure-codes.csv` | csv (32 rows) | same folder | all HOU PRE_ORG_LK departure codes in window (IL/options/transfers/waivers) — the trade-code diagnostic | ✅ [[promo-release-spring2026-release-list]] |
| 2026-07-09 | EXP1-EXP7 + SYNTHESIS + BACKTEST | research md/py | same folder (`2026-07-09-EXP*`, `-SYNTHESIS-`, `-BACKTEST-`) | promote/release model research arc: one-model verdict, cx command (bb% monotone-down), circular-label audit, spring-2026 backtest | ✅ in git worktree; synthesis = `2026-07-09-SYNTHESIS-promo-release-research.md` |
| 2026-07-09 | **PD-Promote-Release-Models-v3.1.docx** | Word doc (shareable) | delivered to Zac (scratchpad, ephemeral) | v3.1 change record + two-system architecture + repeatable model-update process; for the DS/engineer | ✅ content mirrors git decision log `docs/plans/2026-07-09-cx-pitcher-kbb-swap-v3.1.md` (durable) |
| 2026-07-09 | v3.1 K-BB swap (code + docs) | git commits | `feature/promotion-models` `2f23f289` / `8d30aafc` / DEPLOY.md banner | cx pitchers K%->K-BB% (release+promote), decision log, runbook fix, feature-importance shift | ✅ in git |
