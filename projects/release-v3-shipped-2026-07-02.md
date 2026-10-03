---
type: project
domain: modeling
created: '2026-07-02'
status: shipped (committed+pushed feature/promotion-models); work-laptop deploy pending
tags: [ project, modeling, release-model, player-development ]
---
# Release Model v3 — SHIPPED (2026-07-02)

The **should-release / no-future** model — the mirror of [[promotion-release-models|Promote v3]].
Committed + pushed on `feature/promotion-models` (commit `176346ec`). Lives in the SAME app as
Promote (two columns, one board). Work-laptop deploy is the only remaining step.

## What it is
Predict each player's **FUTURE VALUE** (climb + hold + reach MLB) and flag the **bottom** — NOT
"who the org cuts" (that was v1, which re-learned the org's age bias). Same engine as Promote, read
from the opposite end. **Not** `1 - Promote` — a real HOLD middle + longer horizon + censoring.

## Why v3 over v1 (the head-to-head that settled it)
Each model wins at its OWN target. On the **real outcome** (did he actually wash out):
**v3 = H 0.799 / P 0.754  vs  v1 = H 0.720 / P 0.703.** On the transaction (who got cut) v1 wins
(0.75/0.78) — but that bakes in 40-man/age politics. The JOB is the outcome → v3. v1 is a good model
aimed at the wrong target. Trailing-PA adds only +0.01 and is a leak + absent at serve → dropped.

## The recipe (DS-adjudicated)
- M4 inverse-projection framing (regressor, release = 1 - future value) trained on M3's CENSORED label
  (drop young-unresolved). Combine at the LABEL layer, never a score-blend.
- **7 serve-safe features, one per axis:** gcOBA / K-BB% (one quality rep) + age + age-for-level +
  level + 3 process (whiff/barrel/bat_speed | stuff+/velo/whiff). Weights LEARNED (gcOBA/K-BB ~52%).
- Serve = PA/BF≥gate + young/masher badges + within-level GRADE. Frozen per-level median-age table.

## Files (worktree bsb-wt-modeling)
- `pd-goals/modeling/research/release_v3_model.py` — model (smoke-verified)
- `pd-goals/modeling/score_active_roster_release_v3.py` — scorer → pin `zbridger/promo_v3_release_scored`
- `pd-goals/promo-engine/app.py` — Grade→Promote + new Release column (graceful if pin absent)
- `pd-goals/promo-engine/RELEASE_MODEL_DOC.pdf` (5pp) + `docs/plans/2026-07-02-release-v3-outcome-label-design.md`

## Key findings / notes
- **DeVos "contradiction" = stale data, not a flaw:** K-BB 4.0 (2025) → 14.7 (2026). Release scored
  his bad 2025, promote his good 2026. Score the CURRENT season → he drops off. (most-recent-stint rule)
- Can predict the CUT cleanly too (7 feats → 0.73/0.75, within 0.05 of v1) if we ever want an
  anticipation column.
- **Deploy:** work laptop → git pull → `python score_active_roster_release_v3.py` → `rsconnect deploy
  manifest pd-goals\promo-engine`. Then Promote | Release show side by side.

## Backlog
FCL/DSL (needs `--use-sql` rebuild; judged on own level so A-AAA unaffected) · multi-season/full-stint ·
H↔P calibration to a common no-future probability before trusting the cross-position merge (21P/4H skew) ·
hybrid transaction+projection target test · release-doc SHAP page · drawer "Hold Prob"→Release swap.

Related: [[promotion-release-models]] · [[advisory-council]] · [[milb-mlb-promotion-calendar]]


---

## Jul 3 2026 — RISK 61/39 blend FINALIZED (the big evolution)

One night, whole arc: E-round (5 experiments + DS judge) → Zac's one-score challenge → blend
sweep → promote-grade rigor → one-view boards → productionization plan.

- **Headline score locked: RISK = 0.611·NoFuture + 0.389·CutRisk (H) / 0.607/0.393 (P)** on the
  UNION target (Zac's question verbatim: "released OR profile won't improve"). Weight LEARNED via
  fold-safe logistic stacker (GroupKFold by player); grid sweep independently optimal at 0.6;
  cluster bootstrap Δ CI [+0.007,+0.016], p(no gain)=0.000. Honest cost on pure-washout AUC:
  0.846→0.835 H. Weights FROZEN — re-learn only on retrain, never at serve.
- **E-round verdicts (judge):** SHIP E2 (released+gone young = resolved; +316 H/+394 P training
  rows, in `release_v3_model._forward` now) + E5 (quadrant board, display-only). REJECT E3 (label
  fusion strictly worse — "released AND never resurfaced" is one-sided, can't be disproven) + E6
  (stint features = masher penalty; washout-by-prior-releases is NON-monotone: 19→33→18.5→3.3%).
  E1 = validation: v3's rank surface already encodes protection asymmetry; transaction model's #1
  feature is age_for_level (org cutting = an age policy — v1's whole flaw in one number).
- **Council on the blend:** DS ENDORSE ("stable ridge, honest price, split must never be collapsed
  away — CutRisk teaches yesterday's habits"). Scout: passes eye test ("what a real release list
  looks like"); flags Janek (1st-rd defense-first C — model can't see pedigree/glove) + J.P. France
  (injury-return arm) → context columns backlog. "Ranks who to DISCUSS, not who to cut."
- **Boards:** combined top-25 (15 P / 10 POS — sane, old 21/4 skew gone via within-side rank merge;
  true H↔P probability calibration still open). Camilo Diaz #1 (avg-age A-baller, 52% whiff — NOT
  protected because he's not young: A median age 21.5). Marcus Brown drops OUT of top-20 under the
  blend (CutRisk 7) — the guard passing by construction.
- **Also shipped same session:** cross-org same-season pooling (the Moss lapse — pin has per-org
  rows; scorers were double-scoring or arbitrary-slicing; now pooled, Moss = 133 PA one row),
  release driver BARS in drawer (share-of-signal, red=toward), Promote|Release hero squares,
  score-history pin + drawer sparkline (Option A), Add-columns picker.
- **Plan to production:** `pd-goals/modeling/docs/plans/2026-07-03-release-risk-productionization.md`
  (5 tasks: scorer+pin → app → PDF to Promote standard → docs → work-laptop go-live). Boards/receipts
  in git: `pd-goals/modeling/research/e_round/final/` (one_view_*.csv, blend_rigor_summary.json,
  blend_sweep_*.csv, top_compare_*.csv).

Related: [[promotion-release-models]] · [[advisory-council]] · [[context-library]]


## Jul 4 evening — FCL data LANDED + standing directives (pre-wrap capture)

- **FCL/DSL population EXISTS as of tonight**: Zac ran the extended label SQL + feature ETL;
  new panel = H 68,975 rows (dsl 7,727 / rok 5,269) + P 50,898 (dsl 3,494 / rok 2,783), labels
  119,873 (dsl 11,221 / rok 8,052). Installed to `pd-goals/modeling/data/` (features H/P,
  percentile transformers H/P, promo_labels). NEXT (mine): retrain with rok/dsl in LORD/MILB
  ladders, complex-level config per the research (K% not K-BB% at complex, EB shrinkage,
  probability framing), un-filter scorers + app level filter.
- **DIRECTIVE (Zac): daily pin refresh for ALL models** — the nightly scheduled scoring job must
  run BOTH scorers (i.e., `score_all_v3.py`, not just promote) so eBis roster moves flow into
  Promote Grade AND Release Grade daily. Check `fc15cb30` wiring / connect_pins_scoring bundle.
- **DIRECTIVE (Zac): do NOT touch PROMOTE_MODEL_DOC.pdf until directly told.** Release doc v2
  work proceeds; promote doc frozen.
- **Colleague question to answer (capture, /research later):** "How do you take into account
  players that played for different clubs in the same year at the same level in the ETL?"
  Our serve-side answer = `_pool_multi_org_rows` (Moss case, PA/BF-weighted same-season pooling).
  OPEN: training-side parity — `_forward()` dedupes (player, season, level) keep-last, which may
  arbitrary-slice multi-org seasons in TRAINING the same way serving used to. Audit next block.
- Jul 4 late session also shipped: app UNION row-universe fix (Collins bug — release-scored/
  promote-gated players vanished), NaN color guards, drop-report (names every unscored HOU player
  + reason — worked perfectly on first live run), lens dropdown folded into Add columns,
  Promote-grade expander rename, FCL label SQL (01/02/07, 09-pattern), `score_all_v3.py`.
- Artifacts: `Downloads/stuff.zip` (label validation output — unreviewed), fresh parquets
  installed. App redeploy still pending for the union fix (pull + rsconnect deploy manifest;
  pins already current — repin NOT needed, deploy ≠ repin).
