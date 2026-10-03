---
type: project
domain: modeling
created: 2026-07-04
status: research complete — shapes the FCL extension build
tags:
  - project
  - modeling
  - fcl
  - dsl
  - deep-research
---
# FCL/DSL Modeling — Deep-Research Findings (Jul 4 2026)

Deep-research run (101 agents, adversarially verified, KATOH/BP/FanGraphs sources) on extending
Promote/Release to complex leagues. Feeds the FCL build in
`2026-07-03-promote-release-bigger-picture.md`. All claims 3-0 verified unless noted.

## The verified recipe

1. **Split K-BB% — walk rate is ~ZERO signal at rookie level** (hitters AND pitchers; low-minors
   pitchers have no command, so BB% doesn't measure skill). Keep K%; drop/down-weight BB at FCL/DSL.
   This breaks our pitcher qual rep (K-BB%) at complex level — needs a per-level qual swap.
2. **Age matters MORE at the bottom, not less**: age-18 already past rookie ball → ~62.5% reach
   MLB vs ~9.4% for age-18 rookie-ball peers; age-21 still at rookie → 6.3%. Age-for-level should
   carry MORE weight at FCL/DSL than A-AAA (note: E9 found it redundant at A-AAA — level-dependent!).
3. **Minimal rookie-level feature set (KATOH probit): age, K%, ISO.** Caveat: sample was the
   domestic AZL (FCL-analog); DSL is extrapolation. The full KATOH feature list does NOT survive
   at rookie tiers (BABIP/SB claim refuted 0-3).
4. **Empirical-Bayes shrinkage is mandatory** on 50-150 PA samples — raw within-level percentiles
   on tiny samples predict WORSE than the level mean. Shrink toward level mean scaled by PA, with
   heavy-tailed prior so true outliers survive. (Same shrinkage the round-2 judge wants for the
   board gate — one mechanism, two uses.)
5. **Frame FCL/DSL output as reach-next-level / reach-MLB probability, not FV tiers** — even KATOH
   admits rookie-level discrimination compresses to a 1-15% MLB-probability band. Base rates:
   ~9% MLB, ~2% 5-WAR for age-18 rookie hitters. Don't promise fine-grained release grades there.

## Build implications
- FCL rows get their OWN per-level config (qual = K% not K-BB% for P; shrunken inputs; heavier age).
- Board copy at FCL: probability framing + wide-uncertainty labeling.
- Blocked on: label SQL level-scope extension (pattern exists in `09_promote_ready.sql`
  gc2_level_code IN ('dsl','rok') + asx→afx) → `run_label_validation.py` → `run_feature_etl.py`.

Related: [[release-v3-shipped-2026-07-02]] · [[promotion-release-models]] · [[context-library]]
