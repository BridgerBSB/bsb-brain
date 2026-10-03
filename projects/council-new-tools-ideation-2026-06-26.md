---
type: project
created: '2026-06-26'
tags:
  - ideas
  - research
  - advisory-council
  - tools
  - roadmap
  - baseball-analytics
---
# 🧠 New Tools & Algorithms — Council Ideation (Jun 26 2026)

**What this is:** the first full convening of the [[advisory-council]] as real subagents
(scout · data-scientist · ML-engineer · skeptic), each tasked to brainstorm tools /
dashboards / algorithms the Astros PD ecosystem **does not have** but should, grounded in
the data we actually own. 32 raw ideas across four lenses, synthesized here into a ranked
backlog with cross-lens consensus calls.

**Prompt that triggered it:** "using our newly designed team formulate ideas and do research
on algorithms/tools… helpful tools or dashboards we don't currently have… the most recent
tool created was the simple pitch similarity z-score tool."

**Ecosystem baseline (what already exists, so these don't duplicate):** 4 live apps — PD
Engine (Goals), Arm Farm (pitching), Intangibles (fielding), Barrelsville (hitting) — plus
the 14-model LightGBM promote/release/stickiness scores, Injury Tracker (retrospective),
Swing Path 3D, Contact Map, and the [[pitch-similarity-finder]] (z-score / normalized-distance
comps) as the most recent build. Data: Pitches_View, Events_View, HawkEye tracking (64 tables,
~50% sparse at non-HawkEye MiLB venues), bat speed (SCV), EBIS/PP_MASTER, SportsMed.DL_Stints +
TR_HISTORY, R4_Draft_Query, MLBAM gamelogs — league-wide DSL→MLB, all 30 orgs.

Related: [[advisory-council]] · [[MOC-baseball-analytics]] · [[promotion-release-models]] ·
[[connect-offload-migration]] · [[context-library]]

---

## The meta-finding (where all four lenses converged)

> We are **excellent at measuring and delivering raw numbers**, and we have built almost
> nothing that **adjusts** (park / level / age / competition), **infers cause** (did a dev
> intervention work?), or **quantifies uncertainty** (reliability / shrinkage). We ship
> *precisely-computed contaminated comparisons* — a number byte-identical across four
> surfaces that still answers the wrong question because nobody adjusted for the level the
> player just jumped to.

Three gaps were named **independently by 3–4 of the four agents** — those are the highest-
confidence bets:

| Convergent gap | Named by | The bad decision it causes today |
|---|---|---|
| **No level / park / age adjustment** | Scout, DS (×2), Skeptic (×2) | Promote/hold/release on contaminated cross-level deltas; "is he improving or just facing weaker comp?" is unanswerable |
| **No forward-looking workload / injury risk** | Scout, DS, ML, Skeptic (**all 4**) | Flying blind on the most expensive event in pitcher dev (UCL) when the data already exists |
| **Hard count gates instead of reliability/shrinkage** | DS (×2), Skeptic | 35-PA hot streaks painted green as if true talent; LightGBM models inherit noisy features |

---

## TIER 0 — Foundational infrastructure (cheap, hardens everything already shipped)

Build these first; everything downstream (including the existing trackers and the LightGBM
models) gets better for free.

### 0A. Reliability / Stabilization layer + Empirical-Bayes shrinkage
*(DS #1 + DS #5, Skeptic #5)* — **Low effort, highest value-to-effort on the whole list.**
- Per-metric, **per-level** stabilization atlas: split-half (r=0.707 crossover) / variance-
  components to find the sample `n*` where each metric becomes trustworthy at each level
  (DSL BABIP ≠ MLB BABIP). Then shrink every displayed value toward the level/age prior by
  `w = n/(n+n*)` (Beta-Binomial for rates, Normal-Normal for continuous); percentile on the
  **shrunk** value, with a credible band.
- Replaces the current flat hard gates (n≥3, ≥30/pitch, "10+ Tier-1 events"). Directly kills
  the small-sample mirage that created the council in the first place.
- Carry full float (respect `never-round-until-display`). Validate: shrunk predicts next
  season better than raw, out-of-fold.

### 0B. Level / Park / Age adjustment layer
*(Scout #1, DS #2 + DS #3, Skeptic #1 + #2)* — **Medium effort, poisons everything if absent.**
- **Park factors** for MiLB (compute from our own pitch-level data, TJStats-style; BA
  publishes these precisely because parks distort power eval).
- **Level-translation factors** (DSL→MLB) via **matched difference-in-differences** (Glazer
  2026, JQAS) — nets out the survivorship inflation that makes naive same-player ratios too
  pessimistic about low levels. Per-metric (walk rate translates very differently than power).
- **Age-relative-to-level** as a first-class column everywhere, plus **survivorship-corrected
  aging curves** (mixed-effects `metric ~ ns(age) + (1|player) + (1|level)` + inverse-attrition
  weights).
- ⚠️ Leakage guard: do **not** feed level-translations back into the promotion model — they're
  derived from promotion outcomes (circular). Reporting layer only.

---

## TIER 1 — Highest value-to-effort new tools

### 1. Workload / Injury-Risk system — ACWR monitor → survival model
*(ALL FOUR: Scout #5, DS #7, ML #1, Skeptic #3)* — **the unanimous pick.**
- **Phase 1 (days, raw query):** rolling Acute:Chronic Workload Ratio (7–9d ÷ 28d throw load
  from `MLBAM.Gamelog_Pitching.outs`/pitch counts), flagged against the validated 0.8–1.3 band,
  joined to `SportsMed.DL_Stints` to validate thresholds on **our own arms**.
- **Phase 2:** gradient-boosted **survival / time-to-IL** model (LightGBM `objective="cox"` or
  discrete-time hazard on player-weeks). Features: workload trajectory, **velo drop vs personal
  baseline** (the DJ Engle YoY-velo query is the seed), spin/movement drift, arm angle, age,
  prior-IL. **Label genuinely exists** (DL_Stints body part/diagnosis + TR_HISTORY dates) —
  most orgs can't build this; we can.
- ⚠️ The traps everyone flagged: **healthy-worker survivor bias** (hurt guys stop accruing
  workload → workload looks protective), **label leakage** (already-hurt pitcher has truncated
  recent workload → reads "low risk"), and **calibration not AUC** (low base rate → AUC lies).
  Ship as *monitoring* behind a flag; never a single "X% chance of injury" to staff. Also adds
  the **Injury × Performance "return-to-form" bridge** (Scout #5): is the velo/EV actually back
  post-IL? — baseline window must exclude the weeks leading into the stint.
- Pipeline: heavy labeled table → **SQL Agent materialized view, NOT a Connect pin** (this is
  the exact CPU/RAM load the [[connect-offload-migration]] is removing). Reader tab in Arm Farm.

### 2. Prospect Comp / Doppelgänger + Acquisition engine
*(Scout #4, ML #2, ML #5)* — **generalizes the pitch-similarity z-score; reuses proven code.**
- **Whole-player comps:** lift `pitch_similarity.rank_similar` (normalized distance) from one
  pitch's shape to a **player feature vector** (age-adjusted, per-level-standardized) — or use
  the internal layer of the trained promotion/wRC+ LightGBM as a **learned embedding** + ANN
  (PECOTA's core mechanic: neighbors' realized careers = the implicit forecast).
- **Acquisition board (S-tier, ~hours):** the v2 wRC+ projection model is **org-agnostic** —
  add a `--scope all-orgs` flag and point it at the other 29 orgs' MiLB players for trade /
  Rule-5 / MiLB-FA targeting. Also a hitter/BR **acquisition comp** ("players like ours we
  could buy low").
- ⚠️ Standardize within level/age cohort and **pin the scaler** (train/serve scaler skew is the
  classic bug); restrict neighbor pool to age ≤ anchor; apply `org-codes` CASE remap on the
  cross-org join or 4 orgs silently drop. On-demand kNN over a pinned historical matrix — no
  nightly job.

### 3. Age-Relative-to-Level "Young & Producing" board
*(Scout #1, DS #3, Skeptic #2)* — standalone decision surface on top of Tier 0B.
- 2×2 quadrant: x = age-relative-to-level (younger → right), y = age-adjusted production. Top-
  right = real prospects; bottom-left = old-for-level + struggling = release candidates.
- Fixes the Promo Pressure v2 flaw where age is **blended into a 5-component average** and gets
  crowded out — this *isolates* the age axis. Pieces already exist in raw SQL
  (`average-ages-by-level.sql`, `org-age-rank-opening-day.sql`).
- ⚠️ Must be age-*relative-to-level*, never raw age (raw age flags every teenager).

### 4. Trend / Trajectory detector (sustained vs hot; "stuff ticked, results haven't")
*(Scout #2 + Scout #8)* — the recency guardrail the whole council keeps demanding.
- Trailing-90d vs season-to-date vs same-window-last-year, with a **sample-size badge** and a
  flag: SUSTAINED RISE / HOT STREAK (noise) / REGRESSING / FLAT. Trend the **underlying skill**
  (xwOBA, K-BB%, EV) alongside the outcome so we don't promote on BABIP luck.
- Inverse companion: **breakout early-warning** — tools jumped (velo/EV/bat-speed/swing-decision)
  but results lag → "don't release the guy whose stuff just jumped." Generalizes the existing
  one-off velo-jump queries into a standing board. PD Engine already has `rolling_stats.py`.

---

## TIER 2 — High value, more effort or narrower scope

5. **Intervention / Change-Point tool** *(Skeptic #4)* — "did the dev change actually work?"
   Log dated interventions (PRP/goal infra already captures dev plans), then pre/post comparison
   with a **stabilization-aware** test + matched non-intervened controls. This is literally how
   PD learns whether its own work works — currently *zero* causal/intervention analysis exists.
6. **Catcher Framing CSAA + game-calling value** *(DS #4, Skeptic #7)* — GLMM
   `P(strike) ~ s(loc) + count + (1|catcher) + (1|umpire) + (1|pitcher) + (1|batter)`; the
   pitcher random effect falls out as a free command metric. Genuine gap (we have Arm P99, no
   framing). ⚠️ Capped by HawkEye sparsity at the MiLB levels we most want it.
7. **Mechanics-change anomaly detector** *(ML #4)* — unsupervised drift (Mahalanobis on release
   point / extension / arm angle / swing-plane vs personal baseline). **No label needed** → S-tier.
   Early-warning that often precedes injury or slump; feeds #1. ⚠️ Strict gate: only flag when
   both windows have enough **HawkEye-covered** obs, tag venue source, or it fires on a HawkEye→
   non-HawkEye park flip.
8. **Stuff+ / Location+ pitch-quality** *(DS #6)* — grade pitch on physics independent of outcome;
   **stabilizes an order of magnitude faster** than outcome metrics (great for a 40-IP teen).
   ⚠️ Cross-validate **by pitcher not by pitch**; keep features strictly physical (leakage);
   ~0.10–0.20 R² is normal and useful, not weak.
9. **Pitch-sequencing / attack-plan run-value** *(ML #3, Skeptic #7)* — LightGBM on Δrun-expectancy
   with within-PA lag features; advance reports currently say *who* we face, never *how to attack*.
   ⚠️ `LAG() OVER (PARTITION BY pa)` must not read its own outcome; heavy join in the DB, not Connect.
10. **Position-scarcity "Bat vs Body"** *(Scout #3)* — fuse offensive value with **earned**
    defensive value (Tier-1-gated OAA/PAA-EO/Arm), weight premium positions (C/SS/CF). Defense
    Matrix exists but isn't fused with the bat or weighted by scarcity.

---

## TIER 3 — Useful, lower priority / soft labels / dependent on above

11. **Org depth-chart / pipeline heatmap** *(Scout #7)* — position × level/ETA grid colored by
    quality; the offseason/deadline "where are we thin?" view. Depends on #3 + #10 for scoring.
12. **Reliever/Starter role-fit profiler** *(Scout #6, ML #8)* — velo-decay-across-outing + arsenal
    depth → SP/RP/swingman. ⚠️ ML flags the label is soft (usage-imitation, not value) — descriptive.
13. **Hierarchical projection baseline** *(DS #8)* — transparent Marcel-class forecast whose job is
    to be the **baseline-lift yardstick** for the 14 LightGBM models. If ML doesn't beat it
    out-of-fold, the complexity isn't earning its keep.
14. **Under-served populations** *(Skeptic #6)* — position-player arm projection + baserunning-value-
    beyond-leads (first-to-third, extra-bases-taken) + a non-tracking fallback estimator for sparse
    DSL/FCL venues.
15. **Release-model decomposition + promotion-calibration backtest** *(Skeptic #8)* — split the
    Release model's roster-mechanics signal from the performance-decline signal (caveat #4 in
    [[promotion-release-models]]); backtest whether our own past promotions were early/late.
16. **Matchup xwOBA grid** *(ML #7)* — hitter-profile × pitcher-archetype xwOBAcon (bucket to escape
    H2H sparsity); folds into advance reports.
17. **Player-archetype clustering** *(ML #6)* — data-driven archetypes for dev-plan templating + as
    the cohort gate for the comp engine. ⚠️ Seed KMeans + pin centroids or players "change type" each run.

---

## Recommended sequencing (council synthesis)

**Quick wins (ship in days, reuse existing infra):**
1. **ACWR workload monitor** (#1 Phase 1) — raw query, data already there, catastrophic-downside coverage.
2. **Acquisition board** (#2) — `--scope all-orgs` flag on the existing v2 wRC+ model.
3. **Prospect comp engine** (#2) — pitch-similarity code lifted to player vectors, one pinned matrix.

**Foundational (build to harden everything already shipped):**
4. **Reliability + EB-shrinkage layer** (#0A) and **Level/Park/Age adjustment** (#0B).

**Highest single-tool value (label genuinely exists — a real moat):**
5. **Injury time-to-IL survival model** (#1 Phase 2).

**Cross-cutting build rules for whoever executes any of these:**
- GroupKFold **by player**, never by row; seed + pin everything (deterministic artifacts).
- Heavy labeled tables → **SQL Agent materialized views, not Connect pins** (the offload migration).
- Lead Connect deploys with the **DB Vars** (`DB_USER`/`DB_PASS`/`CONNECT_API_KEY`) or score jobs SSPI-fail.
- Every predictive claim: adjusted/out-of-fold vs an **age+level+draft-round baseline**; calibration before AUC/R².
- New tools default to a **tab/card in the relevant domain app**, not standalone (confirm placement first).
- ⚠️ Skeptic's caveat: these gaps were verified against `.claude/rules/` + the modeling vault doc, not every
  `src/*.py` line. Before acting on #0B / #1 / #5, grep `bsb-wt-modeling` for `park`, `acwr`/`workload`,
  `intervention`/`pre_post` to confirm the silence is real and not just undocumented.

---

## Provenance

Four `council-*` subagents run in parallel Jun 26 2026; full per-lens outputs (with the
web sources each cited — stabilization r=0.707, Glazer JQAS league-translation DiD, BP mixed-
effects framing CSAA, ArmCare/ACWR, BA MiLB park factors, KATOH, PECOTA-style comps) live in
the originating Claude Code session transcript. This note is the synthesized, de-duplicated,
ranked digest. Next action: promote the "quick wins" set to `/goal`s or a roadmap when Zac picks
which to build.


---

> [!tip] This backlog is now a LIVE board (Jul 1 2026)
> Every idea below is now its own note in `ideas/` with `status` / `tier` / `domain` /
> `effort` / `lens` frontmatter, rendered as a filterable Base at [[Command-Center]]
> (`Idea-Backlog.base`). Advance an idea by editing its `status`
> (backlog to scoping to building to shipped) and it moves on the board. This note stays
> the narrative source of truth; the board is the operational view for the L3
> backlog-governance loop.
