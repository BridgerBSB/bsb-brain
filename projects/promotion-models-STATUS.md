---
type: project
created: '2026-06-27'
tags:
  - modeling
  - v1
  - status
  - north-star
---
# 🧭 Promotion Models — STATUS BOARD (single source of truth)

The one note to open when lost. Goal + the 4 tracks + what's left + who does what.
Deep detail: [[promo-v1-fixes-and-runbook-2026-06-27]] · [[promotion-release-models]].

## 🎯 Goal
A **decision aid for Player Development** (private to Zac + Sam for now): per HOU
hitter/pitcher, trustworthy **Promote / Release / Stickiness** reads on a Posit app
→ faster, consistent, recency-bias-free promote/hold/demote/release calls. The model
only matters if **a coach can believe the number.**

## The 4 tracks
| # | Track | Status | Owner | Next |
|---|---|---|---|---|
| **A** | Calibration re-pick | ✅ **DONE** | — | apply on retrain |
| **B** | Drop leak features (`*_mlb_grad_pctile`) | ✅ **DONE (decided)** | — | apply on retrain |
| **C** | Expand: **debut label + 2021 + new metrics + retrain** | 🔶 **IN PROGRESS** | Zac (work laptop) | run the sequence below |
| **D** | Honest reporting / write-up | ✅ **DONE** | — | — |

**A result:** the "calibration failures" were an incomplete-2025-label artifact, not the
model. On a resolved season (TEST=2024) all pass → recommended classes **RF (promote),
RF (reached/debut), ExtraTrees (stuck_a)**. Rule: calibrate/eval only on resolved seasons (≤2024).
**B result:** leak is redundant (AUC unaffected) → drop as hygiene.
**D result:** reached-MLB reported on **prospects only (~0.92)**, never the inflated ~0.96.

## 🔶 What's actually left (all in track C + the app + the eye-test)
1. **Debut-label redesign** — `mlb_debut_12mo` = first-ever debut in 12mo, candidates only.
   SQL written (`sql/08_label_mlb_debut.sql`); debut history validated (DB goes back to 1974 ✅).
   → NOT yet run / integrated into the retrain.
2. **Standalone private app** — `pd-goals/promo-engine/` (manifest workflow, Py 3.11).
   → deploying; then set access (Zac+Sam) + `CONNECT_API_KEY` Var.
3. **Eye-test** — Zac, PENDING. **The validation gate.** Do the promote/release names match belief?

## ▶️ The single sequence to get going (work laptop)
1. **Finish the app deploy** → Connect UI: Access = Zac+Sam, add `CONNECT_API_KEY` Var → open it.
2. **EYE-TEST** the rankings → give Claude feedback. *(gates whether we trust any of this)*
3. **Run the debut label:** `01_population.sql` → `08_label_mlb_debut.sql` (same session) → paste DIAG 1–3.
4. **Retrain** (Claude preps): leak dropped · debut target · **2021 included** · resolved split
   (TRAIN ≤2022 / VAL 2023 / TEST 2024) · classes RF/RF/ET · isotonic-on-val.
5. **Eval** → confirm calibration holds + report reached/debut on prospects. **Adopt only if it lifts.**
6. Wire the new scores into the private app.

## Carry-forward checks (low priority)
- baseline-lift for debut (age+level vs full) on prospects · `pa_trailing_90d` window · collapse the 4 age metrics.
