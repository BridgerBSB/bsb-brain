---
type: project
created: '2026-06-27'
tags:
  - modeling
  - v1
  - runbook
  - calibration
---
# v1 — Honest Scorecard + Next-Phase Runbook (2026-06-27)

Closes tasks A (calibration re-pick), B (drop leak), D (honest reporting). C
(feature expansion) is the work-laptop runbook below. Parent:
[[promotion-release-models]] · deep dives: [[promo-v1-importance-comparison-2026-06-26]].

## 🎯 The goal (north star — don't lose this again)
A **decision aid for Player Development**: per HOU hitter/pitcher, give trustworthy
**Promote / Hold / Release** (+ reach-MLB / stickiness) reads on the PD Engine app, so
staff make faster, more consistent, recency-bias-free promote/demote/release calls and
catch the non-obvious case. The model only matters if **a coach can believe the number.**

## ✅ Confirmed this session
- **Leak (`*_mlb_grad_pctile`, ×10): real but REDUNDANT.** Dropping it changes AUC by ~0.
  Remove it anyway — it can't be reproduced for live players (serving hygiene), not an accuracy fix.
- **The hitter "calibration failures" were an evaluation-window artifact, NOT the model.**
  2025's 12-mo-forward labels are half-resolved (positive rate ~half of 2021–24). On a
  **resolved TEST=2024 split, all classes clear the 0.70 calibration floor.**
- **Pitcher models are production-driven** (K-BB%/FIP/gcERA dominate); FF velo = release
  floor only, in-zone% ≈ noise; `fb_velo_p90`/`p10` are 100% NaN (dead columns).
- **reached_mlb's headline (~0.94) is inflated by already-in-MLB rows** (~60%); honest
  prospect number is **~0.92** (and it holds leak-free).

## 📏 Procedural rule (new, important)
**Evaluate + calibrate ONLY on seasons whose 12-month forward window has fully resolved.**
As of 2026-06 the newest safe TEST season is **2024**. Keep 2025 out of calibration/eval
until ~late 2026. (This is why the 5/18 eval looked broken.)

## Honest v1 scorecard (leak-free, resolved-season)
| spec | rec. class | AUC | cal_slope | status |
|---|---|---|---|---|
| h_promoted_12mo | **RandomForest** | 0.82 (TEST24) | 0.82 ✅ | fixed via resolved-season calib |
| h_reached_mlb_12mo | **RandomForest** | 0.96 (TEST24) | 0.96 ✅ | ⚠️ report non-MLB (~0.92); baseline-lift check owed |
| h_stuck_variant_a | **ExtraTrees** | 0.94 | 0.82 ✅ | clean |
| pitcher specs | LightGBM (mostly) | 0.82–0.96 | — | production-driven; recalib on resolved season |

> Note: LightGBM tops AUC but calibrates worst every time — don't let an AUC-only pick choose it.

## 🛠️ Next-phase runbook — WORK LAPTOP (needs DB + Connect pins)
1. **Pin 2021** (Barrelsville + Arm Farm tracker CLIs) — adds a resolved season of training data.
2. *(optional)* add new / previously-unused affiliate tracker metrics to the catalog (behind a flag).
3. `run_feature_etl.py --side both` (incl. 2021 + any new metrics) — set `$env:CONNECT_API_KEY` first.
4. **Retrain** with: leak cols dropped, **resolved split** (TRAIN ≤2022, VAL 2023, TEST 2024),
   recommended classes (RF for promote + reached_mlb, ET for stuck_a), isotonic-on-VAL.
5. Evaluate — confirm calibration passes + AUC holds; report reached_mlb on **non-MLB** rows.
6. Side-by-side vs current v1; **adopt only if it lifts.** v1-as-is never breaks meanwhile.
7. **Eye-test on the PD Engine app** (Scout gate) — do the scores match baseball intuition?

## Open checks (carry-forward)
- Baseline-lift for reached_mlb 0.96 (age + modal_level only) — real signal or near-MLB rows?
- `pa_trailing_90d`: confirm its window closes before the 12-mo label window.
- Consolidate the 4 redundant age metrics (release model is ~18% age, sliced 4 ways).

Artifacts: `Downloads/calibration_repick.csv` (2025 split), `calibration_repick_resolved.csv`
(2024 split), `repick.py`, `repick_resolved.py`. Registered in [[artifacts-register]].


---

## ✅ Baseline-lift check — RESOLVED (reached_mlb, TEST=2024)

age+modal_level baseline vs full leak-free model:

| spec | rows | age+level AUC | full AUC | **lift** |
|---|---|---|---|---|
| h_reached_mlb | all | 0.944 | 0.967 | +0.024 |
| h_reached_mlb | **non-MLB prospects** | 0.877 | 0.930 | **+0.053** |
| p_reached_mlb | all | 0.927 | 0.962 | +0.035 |
| p_reached_mlb | **non-MLB prospects** | 0.859 | 0.930 | **+0.070** |

**Verdict:** On *all rows* the model is mostly age+level (lift only +0.02–0.035) — the
"0.96" is largely level-reading. **But on actual prospects (non-MLB), the performance/tracker
features add a real +0.05–0.07 over age+level** → the model has genuine prospect-evaluation
skill beyond "older + higher level." So reached_mlb is NOT just a level-reader once scoped to
prospects. **Report it as ~0.93 on non-MLB prospects; never quote the all-rows ~0.96.**


---

## 🆕 Direction (2026-06-27 pm): debut label + standalone private app

**Label redesign (Sam+Zac call):** replace `reached_mlb_12mo` (any MLB appearance →
~60% already-in-MLB inflation) with **`mlb_debut_12mo` = first-ever MLB debut within
12mo**, population = **not-yet-debuted candidates only**. Kills the inflation at the
source. Built: `pd-goals/modeling/sql/08_label_mlb_debut.sql` (reuses MIN(mlb game)
debut date; **DIAG 1 validates pre-2021 history** — if censored, source debut from
MLBAM). 2021 included for sample.
- Pre-flight check to run first (SSMS): `SELECT MIN(sched_date), SUM(CASE WHEN sched_date<'2021-01-01' THEN 1 ELSE 0 END) FROM Astros.Schedule_View WHERE level_code='mlb' AND sched_type='R';`

**Standalone PRIVATE app:** `pd-goals/promo-engine/` (app.py + requirements + README).
Separate Posit Connect app (own GUID/URL, access = Sam + Zac only), reads the existing
scored pin. **No new repo** — Connect deploys a bundle as its own app. Deploy via
`rsconnect deploy streamlit . --entrypoint promo-engine/app.py --new` then restrict
access in the Connect UI. Honest guardrails baked in (reach-MLB prospect-only; Release
never player-facing).

Status: both pushed on `feature/promotion-models`. Next = run on work laptop (validate
debut history → 01+08 → retrain with debut target on resolved split → deploy private app)
+ eye-test.
