---
name: promotion-models-status
description: Status pointer for the Promotion/Release/MLB-Stickiness modeling project on feature/promotion-models branch. All 8 phases shipped 2026-05-18; deploy execution is what's left. Read pd-goals/modeling/STATUS.md + DEPLOY.md to resume.
metadata: 
  node_type: memory
  type: project
  originSessionId: d5e5877c-0a27-47a0-bdec-8af8f61bb755
---

# Promotion / Release / MLB-Stickiness Models — CODE COMPLETE, NEEDS DEPLOY

**Branch:** `feature/promotion-models`
**Worktree:** `C:\Users\Owner\bsb-wt-modeling`
**Last touched:** 2026-05-18 (Phase 8d wrap)

**Why:** PD Engine page showing every active HOU prospect 3 scaled scores (Promote / Release / MLB-Stickiness) backed by 14 trained models (LightGBM by default, with multi-class comparison framework). 128,803 player-month snapshots, 2021–2025, league-wide A-and-up.

**How to apply:** When user references this project (promotion models / stickiness / promo labels), read `pd-goals/modeling/STATUS.md` FIRST (authoritative handoff) — then `DEPLOY.md` for the 9-step runbook. `HISTORY.md` has per-phase narrative; `MODEL_CARD.md` documents the production models.

## Phase status (updated 2026-05-18 — ALL 8 SHIPPED)

- ✅ Phase 0: Scaffolding
- ✅ Phase 1: Labels — `promo_labels.parquet` 128,803 rows
- ✅ Phase 2: Feature ETL — pivoted to read tracker pins (`2dbd9399`), EV P95 7hr-hang killed (`27e61a15`), AA/A+/A pin-label mapping fixed (`cd8babb2`)
- ✅ Phase 3: LightGBM training (14 specs) — `fd2621f0`
- ✅ Phase 4: Evaluation — `fd2621f0`
- ✅ Phase 5: Serving (model pins + scorer + class-agnostic inference) — `ab1f8399`
- ✅ Phase 6: PD Engine page `pages/7_Promotion_Models.py` + landing card — `a4a7bb8d`
- ✅ Phase 7: Connect deploy bundle `connect_pins_scoring/` + DEPLOY.md — `43a5daf6`
- ✅ Phase 8a: Multi-model comparison (5 classes × 14 specs) — `c7487e4e`
- ✅ Phase 8b: Promotion-prediction research summary — `3b295d23`
- ✅ Phase 8c: Age × level × YoY-deterioration features (+27/side) — `057da844`
- ✅ Phase 8d: Winner-class trainer + MODEL_CARD — `63a969d1`

## What's actually left — DEPLOY EXECUTION (9 steps in DEPLOY.md)

Not phases. Work-laptop runbook to bring v1 live:

1. `git pull`
2. (annual) refresh features — `run_feature_etl.py --side both` (~30m)
3. (annual) compare classes — `compare_models.py` (~25–50m)
4. Train winners — `train_winners.py` (~5–25m)
5. Evaluate — `evaluate_models.py` (~1–2m)
6. Publish pins — `publish_models.py` (writes 14 `promo_model_<spec>` pins)
7. Smoke score — `score_active_roster.py` (~30s)
8. Connect deploy nightly scoring — `connect_pins_scoring/deploy.ps1` + UI schedule (~5m)
9. Redeploy PD Engine — `rsconnect deploy streamlit pd-goals --app-id 79f52369-...` (~3–5m)

Steps 2 & 3 only at annual retrain time (locked decision C). Steps 4-9 run every retrain.

## Open one-line follow-up

`feature/pd-goals` branch's `pd-goals/requirements.txt` still has no upper bounds on streamlit/pandas/numpy. Whenever someone next deploys PD Engine FROM that canonical branch, the same cascade breaks it. Mirror the `daa24171` cap fix on `feature/pd-goals`. Not blocking modeling work.

## Locked user decisions

- **A:** Released label = `URREL`+`RELES` only positive; `FAOTH`/`ELFA` = separate flag
- **B:** App shows 3 separate 0-100 scaled scores + composite toggle
- **C:** Train-once-yearly + nightly score
- **D:** 3 parallel stickiness variants (PA/IP, WAR shelved, multi-year survival)
- **E:** SQL-first validation done

## Execution mode

Hybrid: subagents handle code, USER runs SQL/training on work laptop. Pause at work-laptop boundaries.

## Reference docs in worktree

- `pd-goals/modeling/STATUS.md` — handoff doc (read first on resume)
- `docs/plans/2026-05-15-promotion-models-v1-plan.md` — 8-phase plan
- `pd-goals/modeling/research/` — 6 docs (~4,000 lines) from research phase
- `pd-goals/modeling/research/SYNTHESIS_VALIDATED.md` — empirical label rates from QC pass
- `pd-goals/modeling/research/qc_outputs/*.csv` — 14 validation CSVs
- `pd-goals/modeling/sql/01-06_*.sql` — label SQL files (back to #temp tables post-pivot)
- `pd-goals/modeling/run_label_validation.py` — runner with parquet export step

Related rules: [[tracker-parquet-pins]] (parquet pin pattern we mirror), [[multi-level-rollup]] (per-metric n_obs iron rule), [[bat-speed-canonical]] (helper used in features), [[three-surface-parity]] (don't drift from trackers).
