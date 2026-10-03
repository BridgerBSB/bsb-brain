---
type: reference
domain: modeling/methodology
source: deep-research 2026-07-14 — 22 sources, 23/25 claims adversarially confirmed
tags:
  - modeling
  - cross-validation
  - imbalanced
  - promo-model
  - compare-models
---
# Imbalanced Model Comparison — Methodology (research synthesis)

The statistical spine for the `[[lineage-skill|/compare-models]]` skill: how to build/compare
candidate promotion-release models WITHOUT fooling ourselves. Deep-research pass, 22
sources, 23/25 claims confirmed 3-0. Primary sources noted.

## 1. Cross-validation — leakage-safe BY CONSTRUCTION
- **Never let a player straddle train/test** → `GroupKFold`, or `StratifiedGroupKFold`
  to also preserve the rare-class balance per fold. *(scikit-learn — primary)*
- **If the extract has repeated player-season rows**, a naive row-level split also
  leaks *temporally* (future seasons train the model) → **severe** overstatement. Add a
  **draft-year / time holdout** (`TimeSeriesSplit`, expanding window). *(Cerqua/Letta/Pinto, Oxford Bull. Econ. — primary)*
- ⚠️ **No single sklearn splitter does group + time.** Need a **custom combined splitter**
  (group-by-player within an expanding draft-year window). *(caveat, high-confidence)*
- The *same* leakage rule applies to the CV used for **tuning**, not just final eval.
- ⚠️ **REFUTED (0-3):** "a draft-year time-holdout is strictly REQUIRED." Grouping is the
  firm requirement; time-holdout depends on whether the extract actually has repeated
  player-seasons. → **Open Q: check the data shape first** (one row/player vs player-season).

## 2. Ranking criteria — AUC alone is misleading
- Under imbalance, AUC can rate a useless model highly (case: ROC-AUC .968 while F2 .09,
  MCC .13). Use **MCC + F2 primary**, **PR-AUC + H-measure** supplements. *(Imani et al. 2026 — flag: MDPI, but reproduced & mainstream)*
- Promotion = a **ranked top-N decision** → weight **precision@k / lift@k** (F2 is
  recall-weighted, a loose fit for a precision-oriented promote list). *(recommended by analogy — not directly sourced; net-benefit/precision@k need a follow-up source, e.g. Vickers & Elkin.)*
- **Calibration** governs thresholds (not who's in the top-N — that's ranking). Don't rank
  on raw Brier (it conflates calibration/discrimination — decompose, Murphy). **Isotonic**
  calibration once **>~1000 samples**, else sigmoid (isotonic overfits small sets). *(sklearn — primary)*

## 3. Fair comparison — same folds + the nested-CV question
- Compare all candidates on **identical folds**. Tune with **nested CV** (re-tune afresh
  inside every trial) — selection bias can be **as large as the true gap between algorithms**.
  *(Cawley & Talbot 2010, JMLR — primary)*
- **Cost nuance (resolved tension):** the nested **outer loop is "overzealous" for the
  SELECTION decision** — **flat CV picks a practically-equivalent model when algorithms
  have FEW hyperparameters.** Use **flat CV to pick, nested CV only when the unbiased
  performance NUMBER is the deliverable** — or when tuning a heavy XGBoost. *(Wainer & Cawley 2021 — primary)*
- **Don't pick the raw best score** → **one-standard-error rule**: least-complex candidate
  within 1 SE of the best. The defensible way to collapse many criteria into one pick.
  *(Yates et al. 2023, Ecol. Monographs — primary)*

## 4. Anti-fabrication (reasoned, not source-verified)
Every candidate run emits a **provenance record**: fixed seed · data hash · git commit ·
exact fold indices · per-fold metric arrays. The skill reports **only** metrics parsed from
that record — never an agent-stated number. Ties to [[council-skeptic]] / [[verifier]] and
the ~80%-fabrication finding in [[agent-modeling-workflow-patterns]].

## 5. Retrain / drift loop — usually NOT worth it here
Confirmed by finding [2]'s logic: re-running is **pointless without materially new labels**.
Promo labels (draft→MLB) arrive **seasonally** → shelve the loop; on-demand `/compare-models` is right.

## Open questions (resolve before/while building)
1. **Data shape** — one row per player, or player-season? Dictates the exact splitter. *(checkable now)*
2. Source precision@k / net-benefit for the top-N ranking criteria.
3. Hyperparameter budget → flat-CV-select vs full-nested. (Few-param → flat ok; heavy XGB → nested.)
4. Exact provenance schema for the run record.

## Links
[[agent-modeling-workflow-patterns]] · [[lineage-skill]] · [[promotion-models-STATUS]] · [[promotion-release-models]] · [[council-data-scientist]] · [[council-skeptic]] · [[MOC-astros-engineering]]
