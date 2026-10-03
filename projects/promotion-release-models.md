---
type: project
domain: modeling
created: '2026-06-23'
status: code-complete — deploy/exploration on work laptop
branch: feature/promotion-models
tags:
  - project
  - modeling
  - player-development
---
# Promotion / Release / MLB-Stickiness Models

**The PD Engine modeling brain** — for every HOU-rostered prospect, predict where
they're headed. Two workstreams on `feature/promotion-models`
(worktree `C:\Users\Owner\bsb-wt-modeling`). Both **code-complete**; remaining work
runs on the **work laptop** (hybrid mode — Zac runs SQL/training, subagents wrote
the code).

> Authoritative handoff lives in the worktree, not here. This note is the
> **concept + map**; for execution read `pd-goals/modeling/STATUS.md` first, then
> `DEPLOY.md` (v1) or `RUNBOOK_V2.md` (v2). Memory pointer: [[promotion-models-status]].

---

## The concept

Turn the org's player-development question — *"who's about to move up, who's at
risk, who will actually stick in the majors?"* — into calibrated, coach-facing
scores on the [[pd-goals|PD Engine]] app.

**v1 — three 0–100 scores per player** (the shipped system):
- **Promote** — P(moves up a level within 12 months). Composite of a 12-month and
  3-month horizon model (0.7 / 0.3).
- **Release** — P(`URREL` or `RELES` transaction within 12 months). Single model.
- **Stickiness** — P(reaches a sustained MLB role). Mean of variant_a (PA/BF
  threshold by age 27) + variant_c (≥2 distinct MLB seasons), with a
  `reached_mlb_12mo` fallback.

**v2 — one cleaner projection per hitter** (the exploratory thread):
- *"If this MiLB hitter reaches MLB, what's his projected career MLB **wRC+** (or
  **xwOBA**)?"* A two-target bake-off — both targets computed in one SQL pass and
  trained in parallel; the eval report decides which to ship. Component features
  only (no wRC+/xwOBA as inputs — they're outputs of the same components),
  MiLB-only scoring, **MLB players are the answer key.** Pitcher target deferred
  (leaning ERA-, pending internal-metric check). v2 is **additive** — v1 stays live.

---

## What it's built on

- **[[lightgbm-baseball-modeling|LightGBM]]** — the workhorse classifier across the
  whole analytics portfolio (same family as [[send-from-2b]]). Dominates tabular
  n≈30K. Phase 8a adds a 4-alternative comparison framework; per-spec winner is
  picked, LightGBM is the known-good fallback.
- **Tracker parquet pins** ([[tracker-parquet-pins]]) — features come from the
  already-nightly-pinned **Barrelsville** (hitters) and **Arm Farm** (pitchers)
  tracker pins. Reuses proven hot-path infra instead of re-pulling.
- **Labels from GroundControl** — `PP_MASTER` (roster/transaction) + `TR_HISTORY`,
  materialized to `promo_labels.parquet` (128,803 rows, league-wide A-and-up,
  2021–2025).
- **Promotion-research literature** — KATOH (age × level priors), FanGraphs FV
  base rates, etc. → motivates the Phase 8c deterioration features. See
  `research/PROMOTION_RESEARCH_SUMMARY.md`.
- **Posit Connect serving** — one pin per model spec, a Connect-scheduled scoring
  job, surfaced on the PD Engine Streamlit app. Connect deploy playbook:
  [[tracker-parquet-pins]] §12 (BLOCKING).
- **Portfolio precursor** — [[dsproj-data-science-examples]] (force-plate → velo/
  bat-speed RF/SVR/DT + SHAP) is the same GridSearch → best-estimator → attribution
  loop, done earlier with sklearn.

---

## The 14 specs (v1)

7 outcomes × 2 sides (H/P). Source of truth: `models/config.py::MODEL_SPECS`.

| Outcome | Horizon | Resolved-only | Label semantics |
|---|---|---|---|
| `promoted_12mo` | 12mo | no | LEVELOFPLAY changed to higher tier |
| `promoted_3mo` | 3mo | no | same, 3-month window |
| `released_12mo` | 12mo | no | `URREL` or `RELES` (Decision A) |
| `stuck_variant_a` | n/a | yes | reaches PA/BF threshold by age 27 |
| `stuck_variant_b` | n/a | yes | WAR threshold by age 27 — **degenerate**, ships as 0 (WAR not wired) |
| `stuck_variant_c` | n/a | yes | ≥2 distinct MLB seasons on roster |
| `reached_mlb_12mo` | 12mo | no | first MLB appearance within 12mo |

---

## Architecture (v1)

```
GroundControl2 ─► Phase 1 labels (PP_MASTER + TR_HISTORY) ─► promo_labels.parquet
                                                                   │
        tracker pins (Barrelsville/Arm Farm) ─► Phase 2 ETL ◄──────┘
        + Phase 8c deterioration features (5 categories, +27/side)
                                                                   │
                                                   promo_features_{h,p}.parquet
                                                          ├─ Phase 8a compare_models ─► winner_summary.csv
                                                          └─ Phase 8d train_winners ─► 14 × {spec}.joblib
                                                                   │
                                          Phase 5 publish_models ─► zbridger/promo_model_{spec} × 14 pins
                                                                   │
                                  Phase 5 score_active_roster (every 6h, Connect) ─► promo_scored_prospects
                                                                   │
                                          Phase 6 pages/7_Promotion_Models.py (PD Engine) ─► Coach / PD staff
```

**Methodology highlights:** time-based split (TRAIN 2022–23 / VAL 2024 / TEST 2025
— right-censoring-safe), isotonic-on-val calibration uniform across all 14 specs,
class-agnostic inference (`serve/inference.py::score_one` — LightGBM `Booster.predict`
vs sklearn `predict_proba`, detected from the bundle's `winner_class`). Imbalance
handled via clipped `scale_pos_weight` (LGBM) / `class_weight='balanced'` (sklearn).
Sanity AUC floors (promote 0.65, release 0.60) auto-revert a weak winner to LightGBM.

---

## Status & what's left

| Workstream | Status | Next action (WORK LAPTOP) |
|---|---|---|
| **v1 — 14 specs** | All 8 phases shipped | `DEPLOY.md` 9-step runbook: train → compare → pick winners → eval → publish 14 pins → smoke score → schedule nightly → redeploy PD Engine |
| **v2 — wRC+/xwOBA** | All code shipped | `RUNBOOK_V2.md` Steps 1–6. **Step 1 is the only DB step**; Step 4 emits `data/wrc_eval_report.md` (pick the headline model from it) |

⚠️ **Verify live state:** `STATUS.md`'s workstream table marks v1 **LIVE**, but the
v1 TL;DR and the [[promotion-models-status]] memory pointer both say deploy
execution is still the remaining step. Confirm whether the 14 pins + nightly score
+ PD Engine page are actually serving before assuming v1 is in production.

Retrain cadence is **annual** (locked decision C) + nightly scoring. Steps 2–3
(feature ETL + class comparison) only at retrain; steps 4–9 every retrain.

---

## Locked decisions (A–E)

- **A** — Released label = `URREL` + `RELES` only positive; `FAOTH`/`ELFA` separate flag.
- **B** — App shows 3 separate 0–100 scores + composite toggle.
- **C** — Train once yearly + nightly score.
- **D** — 3 parallel stickiness variants; compared in eval report.
- **E** — SQL-first validation before plan (`research/SYNTHESIS_VALIDATED.md`).

---

## Known caveats (document with coaches)

1. `stuck_variant_b` degenerate (WAR source unwired) → ships as 0; composite uses mean(a, c).
2. 2026 features partial mid-season → compare vs 2024 cohort, not 2025.
3. DSL/ROK feature coverage ~50% → DSL scores noisier than AAA; show app caveat.
4. Release model conflates org decisions (regime change, 40-man math, salary) with
   performance → **never player-facing, never directly thresholded.**
5. Single-class production until `compare_models.py` runs on real data (all 14 fall
   back to LightGBM until then).
6. End-of-season aggregates only; no trailing-90d windows yet (v2 backlog).

---

## Reference docs (in worktree `pd-goals/modeling/`)

| Doc | Purpose |
|---|---|
| `STATUS.md` | Project status + reference index (read first) |
| `DEPLOY.md` | v1 9-step deploy runbook |
| `RUNBOOK_V2.md` | v2 8-step work-laptop sequence |
| `MODEL_CARD.md` | Google-format production model card (intended use, caveats) |
| `HISTORY.md` | Per-phase changelog |
| `research/WRC_PROJECTION_DESIGN.md` | v2 design (both targets in parallel) |
| `research/PROMOTION_RESEARCH_SUMMARY.md` | Phase 8b literature scout (KATOH, FV) |
| `research/MISSION.md` | Locked design decisions (v1) |
| `models/config.py` | The 14 `MODEL_SPECS` + tunable hyperparams |
| `docs/plans/2026-05-15-promotion-models-v1-plan.md` | Full 8-phase plan |

---

## Links

[[promotion-models-status]] (memory pointer) · [[lightgbm-baseball-modeling]] ·
[[tracker-parquet-pins]] · [[multi-level-rollup]] · [[three-surface-parity]] ·
[[dsproj-data-science-examples]] · [[promotion-velocity-status]] ·
[[promotion-deterioration-research]] · [[MOC-baseball-analytics]]


---

# Deep dive (added 2026-06-26)

## v1 vs v2 — the goal split

- **v1 = the decision.** "What's about to *happen* to this player?" — Promote / Release /
  Stickiness, as *event probabilities* (classification, 12-/3-mo horizon, hitters **and**
  pitchers, 14 models). This is the promote/hold/demote/release engine.
- **v2 = the input.** "If he reaches MLB, how *good* will he be?" — a career MLB **xwOBA / wRC+**
  projection (regression, hitters only so far). Not a promote score; an *upside* number that
  feeds the v1 decision. v2 is additive — v1 stays.
- Design idea on the table: a single **ceiling score** (v2) as the spine, with promote/release
  as decision *bands* on top. But note promote≠inverse-of-release — there's a real **hold**
  state, which is why v1 keeps the scores separate (locked decision B).

## Metrics actually used (per side)

**Hitter (v2, ~31 component features)** — *process, never outcomes:*
- Discipline (11): swing/whiff/chase%, contact% (zone/out), zone-swing%, heart swing/take%, **swing-decision (swdec)**
- Contact quality (10): avg/max EV, hard%, barrel%, avg LA, pull-air%, damage%, point-of-contact depth/x/y
- Bat tracking (3): bat speed, attack angle, vertical bat angle
- Rates + bio: K%, BB%, K-BB%, age, handedness, level

**Pitcher (v1, ~60 features):** Stuff+ (20-80) + location grade + FF hop + extension + arm
angle; FB velo + P90/P10 + velo separations; strike%/in-zone%/usage; two-strike whiff; recency deltas.

**The gcOBA / leakage rule (BLOCKING):** `gcoba`, `woba`, `xwoba`, `wrc_plus`, `avg/obp/slg`,
`xslg`, `xba` are **explicitly dropped from features** (`DROPPED_AGGREGATE_COLS`) — they're
*outcomes*; feeding them leaks the target. Predict results from process only. (So: **we do not
use gcOBA as a feature** — we *compute* xwOBA/wRC+ as the target.)

## Finding: v1 works better for pitchers than hitters

From the v1 eval — it's a **calibration** story, not AUC:
- **Pitchers:** zero calibration failures; promote AUC 0.817 (cal 0.91).
- **Hitters:** h_promoted_12mo, h_reached_mlb, h_stuck_a all **failed** the 0.70 slope floor
  (h_promoted_12mo cal **0.44**).
- **Why:** pitcher "stuff" is intrinsic + stable (97 mph is 97 in any sample); hitter offense
  is noisier and leans on scarcity/defense a model can't see.
- **Implication:** for hitters, v2's xwOBA *projection* (reached-MLB R²≈0.41) may be more
  trustworthy than v1's hitter *promote classifier*. v2 fills the hitter gap.

## Recency bias — current state

- **v1 already fights it:** trailing-90d snapshots + deterioration deltas
  (`delta_whiff_pct_l30d`, `delta_*_yoy`) ask "real change or recency noise?"
- **v2 is recency-naive:** flat season aggregates, no trend features yet. → porting v1's
  l30d/YoY deltas into v2 is an open, concrete upgrade and directly serves the
  "eliminate recency bias" goal.

## Reading R² honestly (domain-calibrated)

Prospect→MLB projection sits in the **social-science regime (~0.30–0.50)**, not physics
(0.90+). So reached-MLB **R²≈0.41 is promising for this domain, NOT "strong" in the abstract.**
Before celebrating, the [[advisory-council]] Data Scientist checks owed: (1) lift over an
age+level baseline, (2) **adjusted** R², (3) train-vs-OOF overfit gap, (4) is 0.41 inflated by
easy rows. The earlier wRC+↔xwOBA corr of 0.876 (< 0.90 band) is the actual-vs-expected gap,
not a broken formula (stars validate tightly).

## Exploration map (all-affiliate-tracker-metrics)

Barrelsville pin = **76 cols; v2 uses ~31** → ~45 untapped hitter metrics. Threads:
1. **Widen hitter features** — enumerate the unused ~45, screen for leakage + redundancy.
2. **Add recency/trend features to v2** — port v1 l30d / YoY → attacks recency bias.
3. **Pitcher v2** — quality-projection twin (proj. ERA-/xFIP-), currently deferred.
4. **Fix v1 hitter calibration** — recalibrate the 3 failing models or sub in v2's projection.
5. **SHAP + R² rigor** — what drives the 0.41 (baseline lift, adj-R², overfit) before adding 45
   features. Lean on `swing-path/examples/data-science-projects` + `tjstats-pitching`
   (see [[context-library]]).

Recommended order: **5 → 2** (understand the 0.41, then add recency).

Related: [[context-library]] · [[advisory-council]] · [[lightgbm-baseball-modeling]]


---

# ⚠️ CRITICAL FINDING + PRIORITY RESET (2026-06-26)

**v1 (release/hold/promote) is THE priority. v2 (wRC+/xwOBA projection) is PARKED.**

## v2's headline R² was a mirage (verified on OOF data)

The v2 eval sold `reached_mlb_oof_r2 = +0.412` (xwOBA×LightGBM). It's inflated:

| slice | R² | note |
|---|---|---|
| headline (all reached-MLB) | +0.412 | what the report shows |
| MLB-level input rows | +0.602 | **circular** — big-league stats → big-league target |
| **MiLB-only (the real task)** | **+0.089** | project MLB bat from the *minors* |
| age+level baseline (MiLB) | −0.005 | what the 28 features must beat |

**51% of "reached-MLB" rows were MLB-level seasons.** Strip them → the honest
minor-league-projection signal is **R² ≈ 0.09 (xwOBA)** and **−0.07 (wRC+, i.e.
worse than the mean)**. The 28 tracker features add only ~+0.09 over age+level.
Methodology bug: the eval's "metric that matters" pooled MLB rows — the metric
that *actually* matters is **MiLB-only, player grain**. (Goal was always
MiLB→MLB; we agree on that — the eval just credited itself for non-projection rows.)

## Priority going forward

- **v1 tuning** is the work: release + promote (hitter side especially). Don't
  break v1 from where it is — expand carefully.
- **Open v1 leads:** (1) hitter calibration failures (h_promoted_12mo cal 0.44);
  (2) **age may dominate the hitter side** — verify via SHAP whether it's
  *age-relative-to-level* (legit signal, KATOH-style) vs *raw age* crowding out
  performance; (3) experiment with **all affiliate tracker metrics** (hitting +
  pitching) as added features.
- **v2** → at most a descriptive "xwOBA/wRC+ deterioration per level" curve later;
  not a shipped model.

Related: [[advisory-council]] · [[context-library]]


---

# 🔴 PRODUCTION BUG — leakage (2026-06-26, council-confirmed)

**`*_mlb_grad_pctile_at_level` (×10 features) leak the target.** Cohort = `reached_mlb_12mo==1`
(a model label), pooled across ALL seasons incl. held-out 2025, with self-inclusion, and it
can't even be reproduced at serve time. **Must drop (add to `LABEL_AND_LEAK_COLS`) + retrain
before v1 informs any real promote/demote call.** Full trace + fix + pitcher-SHAP findings:
[[promo-v1-importance-comparison-2026-06-26]]. Also: `fb_velo_p90/p10` are 100% NaN (dead cols).
Pitcher models are production-driven (K-BB%/FIP/gcERA); raw velo/command matter little.


---

# ✅ UPDATE 2026-06-27 — A/B/D done → [[promo-v1-fixes-and-runbook-2026-06-27]]

- **Leak is empirically REDUNDANT** (dropping the 10 `*_mlb_grad_pctile` cols changes AUC ~0).
  Drop as serving hygiene, NOT an accuracy fire (earlier "must fix before any call" was overstated).
- **The hitter calibration "failures" were an incomplete-2025-label artifact, not the model.**
  2025's 12-mo-forward labels are ~half-resolved → base rate collapses → calibration looks broken.
  On a **resolved TEST=2024 split, all classes clear the 0.70 floor.**
- **Recommended leak-free, calibration-first picks:** h_promoted_12mo → RandomForest, h_reached_mlb_12mo
  → RandomForest, h_stuck_variant_a → ExtraTrees.
- **New procedural rule:** calibrate/evaluate ONLY on resolved seasons (≤2024 as of now).
- **C (2021 pin + new affiliate metrics + retrain)** = work-laptop runbook in the fixes note.
- Eye-test on the PD Engine app is the Scout gate before adopting anything.


## Domain knowledge — promotion timing (added 2026-06-29)
See [[milb-mlb-promotion-calendar]] — MiLB seasons end at **different dates by level**
(AAA Sep 20 / AA Sep 13 / A+/A Sep 6, 2026); MLB call-ups cluster on **Sep 1 roster
expansion**. Consequence: the "0.000 promotions in Sept-2025" is **partly real
structure**, not pure right-censoring. Label-maturity cutoff should be **level-aware**,
and late-season snapshots down-weighted/excluded — folds into the split rework.


## Promote v2 design — "Promotion Readiness" (2026-06-29, council-synthesized)
Decision: **Promote = overhaul.** Target = "who will **hold up at the next level**" (readiness/FLOOR),
paired with MLB Proj (ceiling). **Advancement = inclusion GATE, not the label** (kills the escalator:
A-ball advances >50%, the old `promoted_12mo` was saturated). Label = "advanced AND held," but
(scout) **don't measure month-1** (challenge dip), use **survival + months 2–6**, **park/league-adjust**.
Bands on the **AA seam** (Complex | A/A+ | AA | AAA). Features = skills that travel (discipline,
command-vs-stuff, **defense/gc2**), age-relative-to-level first-class; avoid AVG/ERA/BABIP.
Caveat: full version needs trailing-90d feature grain (season-grain pin path leaks). Matured cohorts:
2021–23; 2025 unusable. Ship **survival-proxy v2.0 first**, full relative-decline v2.1 after.
Release: keep v1 frozen, v2 = retrain on expanded world (2021+DSL/FCL). Full plan in repo
`pd-goals/PROMO_REWORK_PLAN.md`. See [[milb-mlb-promotion-calendar]].


## Promote v2.0 label VALIDATED (2026-06-29)
Ran `09_promote_ready.sql` on the DB. The survival-proxy de-escalators correctly — "held the jump"
rate by band (resolved rows, pooled 2021–23): **complex ~75% · A ~73% · AA ~63% · AAA ~17%** (a real
gradient, vs the old `promoted_12mo` ~100% at low levels = dead escalator). Maturity gate confirmed:
**2025 fully censored, MLB fully excluded** (both by design). Samples workable (hundreds–thousands/band
in 2021–23). Open: low bands still soft (~75%) → v2.1 relative-decline sharpening planned; AAA Promote
≈ "sticks in MLB" overlaps [[milb-mlb-promotion-calendar|MLB Proj]]. Results saved:
`pd-goals/modeling/docs/09_promote_ready_diagnostic_2026-06-29.csv`. Also: 2021 fully integrated into
features (both H/P parquets clean, all seasons ~0% null on key cols).


## Promote v2.1 WINS — ship it (2026-06-29)
Performance-held label (`sql/10_promote_held.sql`, ran clean) + `train_promote_held.py`, trained on
real data (2021 integrated), test=2023. **Within-band AUC improved on 5/6 cells** vs v2.0:
H A 0.61->0.66, AA 0.53->0.62; P A 0.63->0.71, AA 0.62->0.67, AAA 0.55->0.77 (H AAA regressed
0.67->0.52, small n + overlaps MLB Proj). Overall AUC intentionally lower (honest, not level-gamed).
**Core win: `modal_level` fell out of the top features — v2.1 ranks on `xwoba`(H)/`k_bb_pct`(P), real
travel-skills, not org cadence.** Verdict: ship v2.1 as Promote. Next: app wiring (score roster -> pin
-> app column) + DSL/FCL feature coverage (population expansion). Details: `docs/promote_v21_vs_v20_2026-06-29.md`.


## v2.1 SHIPPED (2026-06-30)
**Promote v2.1 "Promotion Readiness" is the model.** Performance-held target (advanced AND held
age/level-relative performance at the new level — xwOBA for H, K-BB% for P), replacing the
escalator-driven v2.0. Within-band AUC ~0.61–0.73, **stable across 2023 AND 2024 held-out years**;
`modal_level` no longer dominates (xwoba_pct / k_bb_pct lead). 2021 integrated. Beta app rebranded
("Promotion Model · BETA", no "PD Engine") with **Readiness as the lead column**. Pipeline runs
end-to-end on the work laptop. Full handoff: repo `pd-goals/PROMOTE_V21_HANDOFF.md`.

Pipeline files: `sql/09_promote_ready.sql` (v2.0 + temp tables), `sql/10_promote_held.sql` (v2.1
label), `run_promote_held_labels.py` (DB→csv runner), `train_promote_held.py` (trainer),
`score_active_roster.py` (emits `promotion_readiness` to the pin), `promo-engine/app.py` (beta).

**Level difficulty** is handled via percentile-within-(age,level,season) features + the held
comparison being vs the NEW (harder) level — NOT via the raw `modal_level` flag (which we
deliberately made level-flat so it can't shortcut the answer). See [[milb-mlb-promotion-calendar]].

**⚠️ Deploy the beta from `pd-goals\promo-engine`, NOT `pd-goals`** (the latter is the full PD
Engine). See [[deploy-promo-beta-folder]].

**NEXT — v2.2 = DSL/FCL coverage.** Complex band has labels but no features (season-grain pins
don't carry dsl/rok). Fix = the `--use-sql` feature rebuild in `run_feature_etl.py` (also closes a
v2.1 leakage gap). The open piece of ask #3.


---

## 🔄 v3 "Deserves It" rework STARTED (2026-06-30) — next-level projection COUNCIL-VALIDATED

**Trigger:** v2.1 (shipped earlier 2026-06-30) **fails the eye test** — Xavier Neyens (A / SS /
19.6yo, mashing) lands at **Promote 28**, below younger-but-worse hitters — because v2.1 stripped
`modal_level` and scored strictly within-band, throwing away the two axes Zac's eye uses: **age +
level-relative dominance**. Data confirms: among 2021-24 hitters, raw `age` (|AUC| 0.69) is as
predictive of promotion as `wrc_plus` (0.69), and age × performance **compound** (younger→promote
AUC: low-perf 0.64 → high-perf 0.75). Young + performing = top of the board = the Neyens fix.

**Design locked (full re-derive, H & P are SEPARATE models for both Promote and Release):**
- **Promote** = **next-level projection [heavy]** + advanced-and-held (historical) + age (compounds
  w/ perf) + **slight** level prior. **MLB-Proj stays ceiling-only, NOT a promote input** (AAA-bias).
- **Release** = profile-match to the **actually-released cohort** (1,324 H identified: older 25.9 vs
  24.7, wRC+ 81 vs 100, K% 26.6 vs 23.7, ~90 fewer PA). Label = URREL/RELES + min-stint. Needs
  **work-laptop Org-Board cross-check** for the definitive released-individual list.
- **Features:** raw + within-(level,season) z + age term; **"no metric twice"** decorrelation
  (within-level z beat age-for-level buckets).
- **Next-Level Projection (new spine):** project performance at the **immediate next rung**
  (A→A+→AA→AAA→MLB), NOT MiLB→MLB.

**Council-validated results (cached 2021-25, OOF GroupKFold-by-player, Ridge, decorrelated):**
- **Hitter xwOBA proj:** A→A+ **0.20**, A+→AA **0.20** (promote-relevant rungs), AA→AAA 0.06,
  AAA→MLB neg → display-only. AUC good-next-perf 0.69→0.72.
- **Pitcher:** K-BB% target **FAILS** (R² 0.03, noise). **Pivot to `stuff_plus` target → R²
  0.65–0.69 at ALL rungs** (incl AAA→MLB; stuff travels). whiff% = confirmation term only.
- **Data Scientist verdict: GO-WITH-FIXES.** Overfit killed (gap 0.005 ridge, was 0.54 on LGB).
  Selection bias real but **estimand is correct if labeled "projection CONDITIONAL on promotion"**
  + **support-gate the bottom ~13%** (out-of-support → shrunken age/level prior). Decorrelate
  features first; per-rung models; demotion-direction guard on SQL rebuild; IPW sensitivity check
  on work-laptop full population.
- **Pitching landmine:** `is_starter*` flags DEAD (all 0/UNK) → derive role from `ip_per_start`;
  15.5% switch role across a jump, **SP→RP +0.6 mph** (don't undervalue future relievers). Cached
  parquet missing `fb_velo_p90/p10`, `delta_fb_velo_l30d` → work-laptop rebuild must supply.

**Artifacts (worktree `pd-goals/modeling/`):** design `docs/plans/2026-06-30-pd-models-v3-design.md`;
research `research/correlate_promote_release.py`, `next_level_projection_v1.py` (+proto h/p);
outputs `research/qc_outputs/{released_cohort_hitters_2021_24.csv, next_level_proj_pairs_h.parquet}`.

**NEXT — local (no work laptop needed):** assemble **Promote v3** on projection + within-level
perf + age (compounding) + slight level prior; eye-test the ranking (young+dominant low-level
hitters must rank top); build **Release v3** profile-match. **Work laptop:** DSL/FCL `--use-sql`
rebuild, Org-Board released-list validation, regen advanced-and-held label (SQL 09→10), score
active roster → confirm Neyens lifts, deploy beta, MODEL_CARD → PDF in app.


### v3 Promote — assembled + eye-tested + documented (2026-06-30, later)
- **Promote v3 assembled** (hitters): `PROMOTE = 0.45·proj_next + 0.25·current-level-dominance +
  0.20·youth-for-level + 0.10·slight-level-prior`, support-gated. **Eye-test PASSED** — 2024 board
  top = Eldridge/Campbell/Baldwin/Holliday/Emerson/Anthony/Mayer/Wood (real top prospects); young+
  dominant low-level guys rank top. **Synthetic Neyens (A,19.6,.380) → Promote 97** (was 28 in v2.1).
  Full distribution sane: old+dominant capped (Walton 30yo .348→P42), old+struggling floored.
- **Bake-off (next-level xwOBA proj, OOF GroupKFold):** LGB-reg **0.223** (A→A+ 0.226) best honest R²;
  Ridge 0.173 most stable (gap 0.005). Pick: **LGB-reg serve + Ridge transparent fallback.**
  **Calibration** slope **1.13**, deciles track tightly.
- **Logic-map doc written:** `pd-goals/modeling/docs/PROMOTE_V3_LOGIC_MAP.md` (the "shape map" +
  model selection + worked examples + caveats) → becomes **MODEL_CARD.pdf** + app "How to read" panel.
- Research scripts: `research/{promote_v3_assembly.py, promote_v3_bakeoff.py, next_level_projection_v1.py}`.
- **Weights are an eye-test-validated DEFAULT, not yet optimized.** NEXT local: pitcher Promote
  (stuff-led), Release profile-match, optional weight tuning. Work-laptop: held-label blend, DSL/FCL,
  Org-Board released list, live Neyens score, deploy, MODEL_CARD pdf.


### v3 Promote — LEARNED weights + visuals (2026-06-30, later still)
- **Best practice answer to "how to weight":** let a model learn it. **Learned logistic on the 4
  components BEATS hand-tuning AND the black-box GBM**, stays interpretable:
  - Hitters AUC: hand 0.774 → **learned 0.782** (GBM 0.778). Learned weights **proj 33 / curr 41 /
    youth 4 / level 21**.
  - Pitchers AUC: hand 0.751 → **learned 0.754** (GBM 0.741). Learned weights **proj 15 / curr 62 /
    youth 8 / level 15**.
  - Takeaways: current results lead but NOT as extreme as AUCmax; projection + a real level term
    matter; **youth ≈ 0 standalone** (its value flows through the projection). **Recommend adopting
    learned weights** (calibrated-probability output, 0–100 display).
- **Pitcher Promote** assembled: components proj(next-level Stuff+) / curr(K-BB% now) / youth / level.
  Stuff travels (proj R² 0.69) but predicts *results-held* weakly (AUC 0.58); current K-BB% leads.
  Stuff-vs-results fork visible (Brito high-stuff vs Carrera low-stuff results).
- **Boards exported (sortable CSV, latest cached season per player):**
  `Downloads/hou_promote_board_weights_2026-06-30.csv` (121 H, 4 weight cols),
  `Downloads/hou_PITCHER_promote_board_2026-06-30.csv` (156 P, 3 weight cols). Zac: "looks pretty
  solid." Hunter Brown surfaces from 2022 AAA (sanity ✓).
- **Visuals/MODEL_CARD:** `Downloads/PROMOTION_MODEL_CARD_2026-06-30.pdf` (map/hitting/pitching) +
  PNGs, copied to `pd-goals/modeling/docs/`. Logic-map text in `docs/PROMOTE_V3_LOGIC_MAP.md`.
  Scripts: `research/{learned_vs_handweights, make_model_visuals, hou_board_weights, hou_pitcher_board,
  pitcher_promote_tune}.py`.
- **OPEN:** adopt learned weights (regen boards/visuals if yes) · whether to add an MLB-success slice
  to Promote (currently 0 by design) · build **Release** model next. Work-laptop: live eBis scoring,
  DSL/FCL, advanced-and-held SQL regen, deploy, MODEL_CARD→app panel.


### v3 Promote — CALIBRATED-PROBABILITY resolution (2026-06-30, evening)
- **Zac's AAA question = the key insight.** Levels are NOT equal difficulty: hitter advance-and-hold
  rate by rung = **A 29% · A+ 28% · AA 21% · AAA→MLB 10%** (3× harder at the top). A percentile board
  (hand OR learned) can't reflect that. **Resolution = output the LEARNED model's CALIBRATED
  PROBABILITY of advance-and-hold**, level as a *learned* feature (not a hand prior) so AAA correctly
  becomes the higher bar. A "70" = 70% likely to advance-and-hold at ANY level → true same-scale.
- **Within-level proj-percentile fix** (rank projection vs same-rung peers) RAISED hitter AUC
  0.782 → **0.803**, then calibrated model **0.812**. Per-rung calibration near-perfect (pred≈actual:
  A .33/.29, A+ .25/.28, AA .18/.21, AAA .12/.10).
- **Within-level board now correct:** AAA → Jacob Melton **44%** (.414) #1 (was buried before);
  AA Yainer Diaz 60%; A+ Will Bush/Sullivan 73%; A Ethan Frey/Daudet 82%. Cross-level board puts
  A-mashers on top (easiest jump) — app should offer BOTH cross-level + within-level (level filter).
- **Learned weights** (interpretable, beat hand + black-box GBM): H proj33/curr41/youth4/lvl21,
  P proj15/curr62/youth8/lvl15. SHAP: H projection led by xwoba+age; P by stuff+/velo.
- **All visuals + CSVs in workspace:** `pd-goals/modeling/docs/model_visuals/` (also Downloads):
  PROMOTE_APPROVAL_PACKET (4pp), promo_calibrated_hitters.png, logic map, hitting/pitching 1-pagers,
  HOU boards (weights / learned-vs-hand / calibrated). Scripts in `research/`.
- **STATUS:** awaiting Zac's approval of the calibrated form. **NEXT if approved:** pitcher calibrated
  board → lock Promote → build **Release** (profile-match to released cohort). Work-laptop: live eBis
  scoring, DSL/FCL rebuild, deploy, MODEL_CARD→app panel.


### Hitting FEATURE bake-off (model-level) + PDF v2 (2026-06-30, late)
- **Ran the proper model-level feature bake-off** (not univariate) — the "did you actually test this" dig:
  - **gcOBA vs xwOBA: DEAD EVEN at model level (0.6621 vs 0.6622).** gcOBA's univariate edge (0.706 vs
    0.688) vanishes once other features are in → **keep xwOBA** (evidence, not convention). Swapping
    gcOBA would NOT help. (wRC+ 0.653, wOBA 0.650 lower.)
  - **whiff% > K-BB%** (0.673 vs 0.662) as discipline rep; **barrel% > avg-EV** (0.669 vs 0.662) as
    contact-quality rep; **bat-tracking adds ~0** (bat_speed vs none: 0.6622 vs 0.6620).
  - **Wins stack:** current set 0.662 → IMPROVED [xwoba, whiff%, barrel%, bat_speed, age] **0.681**
    (+0.019). ADOPTED. In the FULL calibrated pipeline this raised **Learned AUC 0.803 → 0.823** and
    projection R² (A→A+ 0.24, A+→AA 0.25). Script: `research/hitting_feature_bakeoff.py`.
- **Approval packet PDF regenerated → 5 pages** with Zac's doc fixes: NEW **glossary/title page**
  (defines lord=level rank + the **two-layer structure**: Layer 1 projection=SHAP, Layer 2 blend=weights),
  **Year column** on both board pages, `lord`→"level" on SHAP, two-layer caption on drivers page.
  `Downloads/PROMOTE_APPROVAL_PACKET_2026-06-30.pdf` + PNGs, copied to `docs/model_visuals/`.
- **Clarified the earlier confusion (Zac's catch):** SHAP explains the projection sub-model ONLY;
  the current/youth/level components live in Layer 2 (the weight bars), which is why they weren't in SHAP.
- **OPEN:** get 2026 Barrelsville/ArmFarm parquet → score live roster incl real Neyens · lock model ·
  build Release · pitcher current-Stuff+ co-component test (internal only, keep display simple).


### v3 CONSOLIDATED model + 2026 live scoring (2026-06-30, night) — council-driven fixes
- **Council (DS + ML-eng) verdicts applied:**
  - **Youth = guardrail, not signal.** Age's predictive value lives in the projection; standalone youth
    adds ~0.000 AUC. Keep it ONLY as an explicit cap (old masher can't outrank the kids); document as a
    value rule, not a learned weight. Define `age` from one fixed reference (train/serve skew).
  - **Level sign was a REPORTING BUG.** `learned_vs_handweights.py:52` reported |coef| (sign stripped),
    making an increasing prior look like "+level". True learned level coef is **NEGATIVE** (higher level
    harder). Zac was right: A-ball is the easy/high rung. DELETE the {40,50,62,72} increasing prior.
  - **Consolidate to ONE model** = the calibrated logistic P(advance-and-hold); retire the 3 floating
    weight vectors. Use FOLD-SAFE projection (calibrated_board had an in-sample leak → 0.82 was optimistic).
  - **gcOBA:** tie on accuracy (0.0001) — adopt as a CONSISTENCY choice, re-calibrate from scratch
    (corr xwoba/gcoba=0.85, scores move), verify DSL/FCL coverage + IBB convention on work laptop.
- **Built `research/score_v3_2026.py`** (SSOT): gcOBA damage, fold-safe, level learned-negative, youth
  guardrail, isotonic calibrated; scores the live 2026 pins.
- **BUG found + fixed:** inner-join dropped non-advancers → trained on advancers only (base rate ~50%),
  flipped level positive, crowned ex-MLB Biggio at AAA. LEFT-join (non-advancers=0) fixed it.
- **Honest fold-safe AUC: H 0.771 / P 0.704.** Level coef H −0.47 / P −0.63 (correct).
- **2026 live board (real names) eye-test PASS:** A-ball **Xavier Neyens #1 (19%)**, Biggio correctly
  low (6%), AAA<A. Pitcher metric = **StuffRelVel** (col `stuff_plus`) + current K-BB%. Boards:
  `Downloads/hou_HITTER_2026_v3.csv`, `hou_PITCHER_2026_v3.csv`.
- Display note: calibrated P is honest but compressed (rare event); board will show within-level rank
  alongside P. **NEXT:** regenerate the 9-page doc on the corrected model (all Zac's fixes + 2026 names).


### 🧭 HANDOFF — v3 done, app upgrade next (2026-07-01)
**Full plan:** repo `pd-goals/modeling/docs/V3_APP_UPGRADE_AND_BACKLOG.md` (read this to resume).
- **v3 Promote model: BUILT, validated, documented.** SSOT = `research/score_v3_2026.py`. gcOBA damage,
  StuffRelVel pitcher target, fold-safe, level learned-negative, youth guardrail, calibrated → 0–100
  GRADE. Honest AUC H 0.77 / P 0.70. Weights H proj72/curr7/youth1/level21, P proj13/curr47/youth8/level32.
  9-pg end-user doc + logic map done. Live 2026 eye-test passes (Neyens #1 A-ball).
- **NEXT = wire v3 into the app** (`promo-engine/app.py`): single **Grade** column, level-filter default
  (within-level), **🚩 injury flag** (eBis IL), **current-level/graduated fix** (Miguel), **sample-size
  guard** (min PA/BF + shrink thin samples), label "v3", MODEL_CARD→new doc. New scorer
  `score_active_roster_v3.py` (work laptop, live pins + eBis) → pin `zbridger/promo_v3_scored`. Freeze
  projection + percentile transformers (train/serve skew).
- **PARKED research:** injury post-stint date-windowed grading (interim = 🚩); PA/IP-threshold rabbit-hole
  (reps don't signal readiness AUC~0.54 — but explore good-vs-bad & by-level, Mayer/Lawlar push strategy,
  what min-reps SHOULD gate a promo suggestion); Release model (v3); MLB-Proj v3 column; pitcher
  current-StuffRelVel co-component test; DSL/FCL rebuild; SHAP bar color fix; pull in kepano/obsidian-skills.
- **THEN:** app → Release model → the other ideas.


### ✅ APP UPGRADE BUILT (2026-07-01) — code-complete, verified locally
Committed on `feature/promotion-models` (`feat(promote-v3): wire v3 Grade into the app`). Three pieces:
- **`research/promote_v3_model.py`** — v3 model as importable SSOT with **FROZEN per-level percentile
  transformers** (fixes the train/serve skew where `score_v3_2026.comp()` re-ranked within the live
  frame). Honest GroupKFold OOF, 0 player overlap → frozen transform RAISES AUC **H 0.771→0.823,
  P 0.704→0.776** (all delta is the transform; NOT the old in-sample 0.82 leak).
- **`score_active_roster_v3.py`** — production scorer → pin `zbridger/promo_v3_scored`. Miguel
  current-level fix (`get_roster`, drop MLB-graduated), sample-size guard (hard floor + shrink thin
  toward level base rate), eBis IL 🚩. Verified on 2026 parquets (Neyens #1 A-ball G97/84%).
- **`promo-engine/app.py`** — single color-graded **Grade** column, within-level default, Odds%
  secondary, 🚩/⚠ inline, drawer component bars, v3 badge, MODEL_CARD PDF bundled.
- **Eye-test for Zac (work laptop):** AAA topped by 29–31yo vets (Biggio G100/37%) — decide explicit
  youth cap vs honest odds (current-level fix may drop MLB-rostered vets anyway). Low levels look right.
- **Remaining = work laptop only:** run scorer w/ real pins+eBis+`CONNECT_API_KEY` → deploy `promo-engine`
  (Access Zac+Sam). Full plan: repo `pd-goals/modeling/docs/V3_APP_UPGRADE_AND_BACKLOG.md` (§BUILT 2026-07-01).


### 🔬 Council review — model fit + freeze plan (2026-07-01)
DS + ML-eng + skeptic reviewed the v3 fit before freezing. **Not broken, but 3 fixes + a gate.**
- **Hitter Layer-2 is collinear/redundant.** `corr(projection%, current-form%) = 0.94`, VIF ≈ 9.8 —
  because `gcoba` is the projection TARGET, an input, AND the "current form" component (current coef
  even flips negative = suppressor artifact). **Dropping current+youth for hitters costs 0 AUC
  (0.8402 → 0.8402 with just [projection, level]).** → **Fix: Layer-2 side-specific — hitters =
  [projection, level]; pitchers KEEP all 4** (K-BB% current form independent of Stuff+ projection,
  VIF ≈ 1.0, load-bearing: dropping craters 0.778→0.662).
- **Youth is NOT a separate signal — age lives INSIDE the projection.** Univariate age matters
  (AUC 0.69) but adds ~0 on top of a projection that already uses age. Display fix: hitter drawer =
  projection + level as the 2 drivers, projection's ingredients (gcoba/whiff/barrel/age) listed
  beneath (the SHAP layer). Stop showing 4 bars where 2 are duplicates.
- **The weight "wobble" (72/7/1/21 vs 67/1/4/28) IS this collinearity across data snapshots**, not
  run-to-run randomness (deterministic on same machine+data). Freeze pins one artifact; the Layer-2
  fix removes the instability at the source.
- **Never forward-validated (the gate).** Data check 2026-07-01: hitter parquet has **2022-2025**
  (2021 NOT in this copy — Zac: 22-25 is fine). Currently trains on ~2 resolved years (2022-23);
  **2024 = 785 advancers sitting unused.** Plan: **test on held-out 2024 → if AUC holds, train the
  final frozen model on 2022-24** (biggest honest sample + proven to predict a year it never saw).
- **Isotonic calibration is in-sample** → "Hold Prob" is optimistic until OOF predicted-vs-observed
  is plotted. Verify before trusting the % as a real probability.
- **Freeze plan (AFTER the above):** `train_v3_bundle.py` → versioned joblib + Connect pin
  `zbridger/promo_v3_bundle_{h,p}` (model + train-data hash + git SHA + trained_at + pinned lib
  versions). Serve LOADS, never refits. Annual retrain. Then regen the model-card PDF from the frozen
  bundle so page 5 = app.
- **App shipped 2026-07-01:** Odds hidden from the table → renamed **"Hold Prob"** (player card only);
  Level multiselect (A/A+/AA/AAA default-on), PA/IP stint column, row-click drawer, drawer title +
  Level-ease-bar fixes. Feedback logged: **document non-obvious modeling decisions in the vault, not
  just chat.**


### 🔬 Session — dropped Youth, MLB-success tiers, ROC, current-metric bake-off (2026-07-01, cont.)
- **SHIPPED: dropped Youth → 3-bar `[proj, current, level]` BOTH sides**; window extended **2021→2024**
  (2024 now resolvable via 2025). Edited SSOT `research/promote_v3_model.py` + `score_active_roster_v3.py`
  + `promo-engine/app.py` (three-surface parity, no phantom Youth bar). Verified OOF **H 0.819 / P 0.763**.
  Archived 16 dead `research/*.py` scratch → `_archive/` (only `promote_v3_model.py` is imported; the
  xwoba/hand-weight protos caused repeated "which file is the model" confusion). Rewrote
  `docs/PROMOTE_V3_LOGIC_MAP.md` to gcOBA / 3-bar / learned weights + lineage. Added `research/README.md`
  SSOT pointer.
- **WAR is DEAD in the parquet** (`career_mlb_war` all zeros — never wired, per Phase-1). MLB-success
  tiers use the **playing-time proxy** (`career_mlb_pa`/`bf`, `n_mlb_seasons`).
- **Tiered predictive check** (within-level pctile → MLB-success tier, n≈8.5–8.8k/side). Usable tiers:
  reached (33–34%) / 500+ (11–13%) / 1500+ (2.4–2.9%); **≥3000 PA/BF too small (N≤35) → noise, ignore.**
  - Pitchers: **K-BB% best/tied at every usable tier** (reached .650, 500+ .652, 1500+ .645); gcERA
    fades at the top (.643/.638/.624); FIP rises (.627/.634/.639).
  - Hitters: **gcOBA best at every tier** (reached .647, 500+ **.681**, 1500+ .672) — *sharpens* at the
    "sticks" bar. xwOBA ~tied. Validates the gcOBA choice against real MLB outcomes.
- **gcERA vs K-BB% (pitcher current):** gcERA edges for *next-level hold* (0.731 vs 0.713, part circular —
  gcperf-family label); K-BB% wins for *reaching MLB* at every tier; corr −0.91. A 9-metric modeled current
  = 0.748 (small gain, kills the transparent card). **Verdict: keep K-BB%** (or a transparent K-BB%+gcERA
  blend); do NOT black-box the current bar.
- **ROC generated** (OOF): `docs/model_visuals/roc_v3_2026.png` — H 0.819 / P 0.763.
- **⚠️ OPEN decision (gates PDF regen):** council (2026-07-01, above) already found **hitter current is
  collinear** (corr proj%↔curr% = 0.94, VIF ≈ 9.8, current coef flips negative = suppressor) and recommended
  **hitters = 2-bar `[proj, level]`** (costs 0 AUC). We currently ship **3-bar both sides**. Zac's instinct
  = 2-bar hitters. NOT yet locked — resolve before regenerating the PDF (which also gets a ROC page + a
  page-2 "what feeds each bar" feature map + real AUC 0.819/0.763).


### ✅ v3 LOCKED + PDF v3 + app-deploy ready (2026-07-01, final)
**Model (locked):** 3-bar `[projection, current, level]` both sides, Youth dropped, window 2021-2024.
Learned logistic weights **H proj/curr/level = 71/2/27 (fold-safe OOF AUC 0.82)**, **P = 16/55/29 (AUC 0.76)**.
Hitters proj+current metric = gcOBA; pitchers current = K-BB%, projection target = stuff_plus.
- **K-BB% vs gcERA (DECIDED, kept K-BB%):** in-model K-BB% **0.763** > blend 0.760 > gcERA **0.749**; 91%-corr twins.
  Validated vs real MLB **MLE WAR** (`Proj.Pitching_MLEs.war` / `Proj.Batting_MLEs.war`, TOTAL-row filter
  `bat_side='-' AND role='--'` / `pitcher_throws='-'`, MLB team_id only, rehab-vet **debut filter** = drop MiLB rows
  at/after MLB debut). Current metrics predict VALUE not just reaching, and **SHARPEN with the WAR bar**
  (gcOBA 0.71→0.78 at 3+ WAR; K-BB% 0.71→0.73 at 4+). gcERA edges K-BB% only at the 2+ WAR tiers. Script:
  `modeling/explore/war_bucket_analysis.py` (queries GC2 directly via `sql-queries/db_connection`).
- **Weight claim CORRECTED:** learned does NOT "beat" hand-tuned/black-box — it **ties** them (H 0.832, P 0.764).
  Value = auto-finds weights + interpretable. Best hand-tuned for hitters = **80/0/20 (current=0)** → hitter current
  is pure redundancy; proj+level is the whole story (matches the ablation image).
- **"Level in twice" (Zac's confusion, resolved):** level is in the projection (how much the line discounts on the
  jump) AND the blend (the advance-and-hold **base rate collapses 29%→10%**, a separate promote fact). NOT redundant
  → 27%. Age/youth appeared twice too but its 2nd job was empty → ~0 → dropped. Same empirical test, data decides.
**PDF** (`modeling/research/make_model_doc.py` → `PROMOTE_MODEL_DOC_2026-07-01.pdf`, 11pp, rendered+viewed each page):
3-bar diagram + feed-map (p2), learned weights (p5), **NEW p6** K-BB%-vs-gcERA + WAR, **NEW p7** ROC, math 6-step,
**p10 = 2021-25 best-graded eye-test** (top-3/level all affiliates: Volpe/Wood/Holliday/Caminero H,
Misiorowski/Jobe/DL-Hall P), glossary defines all 20 metrics. Style rules enforced: **no em-dashes, no "honest"**;
the level feature is labeled **"lord"** everywhere (its projection-model name). PDF is bundled into `promo-engine/`.
**Council pre-deploy (2026-07-01):** ML-eng **GO-WITH-FIXES** — (1) `score_active_roster_v3` refits `fit_side(oof=True)`
every run, no `random_state` → pin the bundle or `oof=False`+seed (version drift); (2) DB failure silently falls back
to stale current levels (defeats Miguel fix) → stamp resolution-mode + require `--allow-fallback`; (3) all-NaN feature
column imputes to noise → add a NaN-coverage guard. DS review pending. **None block a beta.**
**Deploy (work laptop, VS Code closed):**
- Repin: `cd pd-goals\modeling; git pull; $env:CONNECT_API_KEY="…"; python score_active_roster_v3.py` → pin `zbridger/promo_v3_scored`.
- Host: `cd bsb-wt-modeling; rsconnect deploy manifest pd-goals\promo-engine --server https://connect2.astros.com --api-key <k> --title "Promo Model (BETA)"` (add `--new` only for a first/fresh app).
All commits pushed to `feature/promotion-models` on `bsb-resources`.


---

## Next design add — release multi-level + trajectory + YoY (Jul 4 2026)

→ [[release-multilevel-yoy-carryover-2026-07-04]] — approved direction, pending /spec.
Release must stop keying on current-level current-year stats: (A) promote visible "new-level"
tag instead of silent drop, (B) level-adjusted rolling multi-level pool + trajectory feature,
(C) year-over-year carryover (prior-season performance in the release call). Surfaced by the
Guillemette just-promoted-to-AAA drop in `score_all_v3.py`.


---

## Jul 9 2026 — grade-parity fixes SHIPPED + clean-room research → KEEP v3

**Shipped (code, review-clean):** the Jul 8 code-review Group A + B2 all fixed on
`feature/promotion-models` (commits `1cf3d944` then `c10dfa69`, the latter addressing the
high-effort whole-diff review's own 6 findings). A1 org-wide rank spans the side (new
`orgwide_view` helper, recomputed post-concat); A2 promote history logs `GRADE_ABS`; A3
just-promoted release fallback = absolute 61/39 blend, `pd.NA` when `cut_raw` missing
(matches `grade_views` + "put None"); A4 `_append_history` stores only raw driver
ingredients (not the score col again); B2 release `_forward` uses a guarded GLOBAL
`max_season` (byte-identical to hardcoded 2025 on current data). `tests/test_grade_parity.py`
4/4. **Remaining = work-laptop re-pin both scorers + ONE-TIME history-pin reset
(`zbridger/promo_v3_score_history` via `src.pins_config.get_board().pin_delete(...)`) +
redeploy; no app UI change.** Plan: `modeling/docs/plans/2026-07-09-promo-engine-a1-a4-grade-parity-fixes.md`.

### ⭐ FUTURE POTENTIAL ADD (Zac-flagged, true candidate) — pitcher k_bb_pct + gcperf
The ONLY honest feature gain the clean-room pass found: **pitchers (milb band) adding
`k_bb_pct` + `gcperf` = ~+0.03 OOF AUC with a STABLE train-OOF gap** (not a gap artifact).
Both features are 100% covered. Scoped **v3.1** candidate — architecture untouched, just a
pitcher feature add. Everything else washed out. Do this before any bigger rework if we
pick up model work again.

### v4 research verdict = KEEP v3 (Zac's final call). Do NOT reopen without new data.
Clean-room DS pass first looked like "pool the bands = +0.02 AUC everywhere," but that was a
**weak-baseline artifact** (compared vs a reconstructed 0.771/0.704). Decision-grade bake-off
vs the REAL v3 fit code + production HELD label: **v3's true OOF = 0.820 H / 0.758 P (milb)**.
Against real v3 the pooled challenger's OWN overfit gap (H +0.023 / **P +0.056**) exceeds
every per-level delta → **zero levels clear an honest-win bar**. v3 wins/ties where it has
data (AAA H −0.003, **FCL P −0.021**, AA P). **Never pool pitchers** (they overfit). Only
soft signal = complex-band HITTERS (DSL/FCL +0.014-0.018), still inside noise; if ever
chased, test a **leaf-reined pooled HITTER model scoped to DSL/FCL/A only**, NOT a wholesale
swap. Lesson: always bake off vs the REAL model, never a reconstructed baseline.

### Swing-craft features = overfit noise (hitters)
`swdec` / PoC / `pull_air_pct` / AACon each add +0.001-0.004 OOF while the train-OOF gap
widens 0.056→0.081 = the model memorizing training noise, not skill. They're **redundant
with whiff%/gcOBA/bat-speed already in**, and **24-53% null at complex**. Do not
productionize them as promotion features. (Confirms the earlier feature-scout ~+0.005.)

### Odds% == Player-basis Promote grade (by construction, not a bug)
On the default **Player** grade basis, the Promote column = `GRADE_ABS`, and `GRADE_ABS` is
defined as the calibrated advance-and-hold probability rounded (`= round(odds_pct)`). The
**Odds%** column is that same `odds_pct` (`%.0f`). So they match for every player. They
diverge only on **Org-wide** (`GRADE_ORG`, a rank) or **Within-level** (`GRADE`, a rank)
basis. Mild UX redundancy on Player basis (could hide Odds% or relabel Promote as
"Promote (odds %)"); not a data error.

**Reproducible scripts + docs (worktree, nothing live touched):**
`modeling/research/discovery/2026-07-09-clean-room-findings.md` +
`2026-07-09-pooled-vs-v3-bakeoff.md` + the `q*_*.py` / `*_bakeoff.py` scripts.

### Study A (Jul 9) - sample size does NOT predict promotion success
Council DS, whole historical population. Median origin-level PA/BF for SUCCESS vs FAILURE
promotions sit within a handful of reps at every level and the direction flips around; success
rate flat across PA tertiles (H .335/.354/.337); PA-vs-quality corr ~0 (H) / slightly neg (P).
The "more PA = played longer because good" confound was TESTED and rejected. So reps banked and
post-promotion holding are orthogonal. Release is the mirror (released players had fewer reps,
release rate 24%->9% bottom-to-top PA quartile) but that is mechanical/reverse-causal (getting
cut truncates the season), NOT a forward screen. **Implication: the sample floor's only job is
measurement RELIABILITY, not success prediction.** Flat floor defensible (50 PA / 45 BF drops
2-8% of stints); do NOT raise at DSL/FCL (short seasons); don't tune off AAA (thin success n).
One supported change: raise the PITCHER floor 45->~60 BF to match the model read gate (ns=60) -
PENDING Zac (he set 45 on purpose Jul 5). Files: `discovery/2026-07-09-sample-size-vs-success.md`
+ `_ss_promo.csv` / `_ss_release.csv`.

### Study B (Jul 9) - validation vs REAL org promote/release decisions
Council ML-eng. Every HOU player-season the org acted on, scored OUT-OF-FOLD by player on the
frozen v3 code (no leakage), grade at the decision snapshot. **RELEASE validates strongly:**
released players cluster high on risk (median 61 vs population 51; 85% at risk >= 50) - the model
had already flagged most real cuts. **PROMOTE agrees directionally** (promoted median 24 vs 16;
69% above the line) but is a looser fit BY DESIGN - the promote grade targets advance-AND-HOLD,
so it correctly does NOT rubber-stamp org promotions that did not hold. Inspect list (model
disagreed): promotions rated near the floor = Everette Cooper / Josue Payano / Andrews Sosa;
low-risk releases = Mauricio Maican (24) / Yorbin Ceuta (27) / Victor Mascai (35). Files:
`discovery/2026-07-09-hou-promote-release-validation.png/.pdf/.md` + `score_hou_promote_release_oof.py`.

### Regression to the mean - how promote handles it (Jul 9, grepped)
Two mechanisms: (1) the Layer-1 projection LEARNS regression from data (trained on current->actual
next-level, so extreme lines map to regressed outcomes; never linearly extrapolates a hot streak);
(2) thin-sample output shrink toward the per-level HELD base rate (`w = clip(n/firm)`, firm =
100 PA / 60 BF). Release adds a 3rd: EB stat-shrink toward the level mean (`_shrink_qual`, w=n/(n+n0))
but ONLY complex-band pitchers (`CX_N0={"H":0,"P":50}` - H disabled because the e12 sweep found it
HURT hitters). NOT done: full per-metric stabilization (each input regressed by its own reliability
curve). Evidence says that is unlikely to help (e12 EB hurt hitters; Study A shows sample orthogonal
to success). Testable if ever wanted, but low expected payoff.

### Jul 9 (session 2) - board REDESIGN shipped + move studies + complex-command finding

**Board redesign SHIPPED** (`a032126c` -> `102c9be4`, promo-engine/app.py): killed the confusing
Grade-basis toggle; the board now shows 4 explicit labeled columns **Promote | Org %ile (Pro) |
Release | Org %ile (Rel)** (main score then its all-org %ile). Key fixes: **Org %ile = all-org
percentile across every player** (computed in-app from odds/RISK, no re-pin) which fixes the
within-side leapfrog (a low-odds pitcher was outranking a high-odds hitter because the old
"org-wide" was secretly within-side); **Promote = GRADE_ABS** (masked to NA for insufficient/thin -
a Jul 9 regression used raw odds_pct and graded thin players, fixed in `102c9be4`); **Sort-by/Order
controls removed** (use the player multiselect). Level %ile (Pro/Rel) + Proj (Pro) selectable.
Needs Zac's redeploy + eyeball. Contract locked in `modeling/docs/plans/2026-07-09-board-redesign-and-validation-SPEC.md`.

**2026 data source (durable):** the current season lives in the **Barrelsville + Arm Farm tracker
pins**; `run_feature_etl.py --years ...,2026` pulls it (NOT the stale promo_features parquet). See
memory [[promo-2026-data-from-tracker-pins]].

**Move studies (discovery/):** (a) validation - release model matches real HOU cuts strongly, promote
directionally; (b) move-outcomes - release model has real signal (mistake-releases Stubbs/Perez/Kato/
Stevens/Santana hit at AA/AAA elsewhere on middling risk), promote HONEST but blind at AAA->MLB
(Siri/Julks/Korey Lee/Blanco/Arrighetti/Bielak reached MLB from bottom-half grades; **Level %ile is
the mitigation**); (c) move-stats table - grade at move vs real next-level production, releases =
HOU-cuts-who-went-elsewhere ONLY (drop re-signs like Edwin Diaz + washouts), tables are
AT-TIME-OF-TRANSACTION (promote: Curr=from-level, Next=to-level; release: Curr + Top-after + (year)).

**COMPLEX PITCHER COMMAND GAP (next-session workstream):** the cx (DSL/FCL) pitcher models use
`k_pct`, NOT `k_bb_pct`/`bb_pct` - no command feature - so they are blind to walks and MISSED the
walk-driven releases (Maican RelRisk 24; De La Cruz K-BB% -2.2 graded 52; Edwin Gonzalez >15% BB, cut
2024). NOT a revamp/reband (cx already trains on DSL/FCL and uses level). Fix = add command to the cx
models + validate (OOF lift, does it flag the misses, is BB% reliable at complex, why k_pct originally).
`/spec` + `/deep-research` + `/plan` per `modeling/docs/plans/2026-07-09-NEXT-SESSION-spec.md`.
Also next session: Position %ile board column (H/P different scales).

Related: [[promotion-models-status]] · [[advisory-council]] · [[context-library]] ·
[[lightgbm-baseball-modeling]]


---

## 2026-07-23 — PROMOTE model: the lever is DIRECT current-form (projection is a lossy bottleneck)

Worktree `C:\Users\Owner\bsb-wt-modeling`, branch `feature/promotion-models`. All scripts under `pd-goals/modeling/research/discovery/2026-07-23-*`; full detail in `pd-goals/modeling/LINEAGE.md` (two 2026-07-23 entries). Naming: **StuffRelVel**, never "Stuff+".

**The question Zac asked:** can a NEW signal (velo-trend, workload, arsenal change, YoY deltas) improve the pitcher promote model?

**The answer:** No — the lever is using the current-form features the model ALREADY has, directly.

**Why:** production projects the flat trait **StuffRelVel** (Layer 1) then blends [projection, K-BB%, level] (Layer 2). But projecting StuffRelVel ranks who-holds at a **coin flip (0.545)** — 62% of that projection is just StuffRelVel predicting itself (autoregressive). The projection is a lossy bottleneck: it compresses 9 current-form features (velo/whiff/command/StuffRelVel/...) into one near-useless scalar.

**Promote bake-off (4 architectures × 2 rulers, OOF StratGroupKFold×player):**

| arch | HELD (proxy) | promoted_12mo (REAL) |
|---|---|---|
| A production proj(StuffRelVel)+K-BB%+lvl | 0.763 | 0.743 |
| B gcERA-retarget proj(gcERA)+K-BB%+lvl | 0.767 | 0.741 |
| **C DIRECT current-form (no projection)** | **0.786** | **0.770** |
| D DIRECT + proj(gcERA) | 0.776 | 0.770 |

- **+0.023 (proxy) / +0.027 (REAL transaction) — the gain HOLDS on the actual `promoted_12mo` ruler**, not just the proxy. Caveat cleared.
- gcERA is a better projection **target** than StuffRelVel (B>A) — Zac's instinct right — BUT **D<C**: adding the gcERA projection on top of direct current-form HURTS (collinear with the FE it's built from). So the winning promote architecture is **C = DIRECT current-form, projection leg DROPPED**. Predicting future gcERA is the right orientation; feed the drivers direct rather than compress to one forecast.

**New-signal hunt (all ~noise over the current-form baseline):** velo/stuff/perf YoY trend +0.0026 (only 57% coverage, returners) · workload +0.001 · trajectory/spin-shape/contact-allowed ≈ 0 or negative. DEAD in parquet: all `usage_*` (arsenal mix), `*_l30d`, `arsenal_size`, `velo_diff_fb_*`, `arm_angle_ff`.

**Feature-pool answers (Zac's Qs):**
- **IP/start is NaN for 36% of pop** (pure relievers, no registered starts) → imputed to a starter's median (meaningless for them). Hygiene fix for productionize: swap for `is_starter` + universal workload (BF/outs), or let LGBM eat the NaN.
- **Breaking-ball spin** (cb_spin 63% / sl_spin 82%, not a model feature): tested, adds nothing (−0.0004). FB VAA stays, brk-spin out.
- **K-BB% as a projection input** helps predict next gcERA (+0.018 R²) — another under-used current-form signal the promote projection FE omits.

**Model class doesn't matter:** logit and LGBM both land at 0.786 → the gain is the FEATURE SET, not the model. Shippable in the existing logistic Layer 2.

**Deliverable:** 9-page findings deck `pd-goals/modeling/output/projection-anatomy/pitcher-model-findings.pdf` (cover + 6 projection-anatomy pages + new-signal-hunt + the-lever decomposition).

**Next (before ship):** productionize C into promote Layer 2 (drop the StuffRelVel projection for pitchers), decide the IP/start swap, council-DS pass. **RELEASE model deferred** (Zac's call — attack promote first). Release is structurally different anyway (a direct future-value regressor, no projection bottleneck; its sibling opportunity is that it lacks the command/shape features loc_grade/fpinz/extension/fb_vaa).

Related: [[advisory-council]] · [[MOC-baseball-analytics]] · earlier promote/release notes in this project.
