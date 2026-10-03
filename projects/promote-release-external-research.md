---
type: project
domain: modeling
created: 2026-07-03
status: capturing — 3 of 5 links saved (Jul 3), 2 unidentified
tags:
  - project
  - modeling
  - external-research
  - promotion-models
---
# Promote / Release Models — External Research Links

External articles Zac found online while building [[promotion-release-models]] /
[[release-v3-shipped-2026-07-02]]. Captured per the external-resource-capture rule
(summary + source link, never a bare URL).

> [!info] Capture status (Jul 3 2026)
> Zac re-pasted 3 URLs after the original capture failure (one was a dupe of link 1).
> Links 1–3 below are now fully captured. **2 of the original 5 remain unidentified** —
> fill in when Zac finds them. The capture failure itself spawned the `/research`
> command (research turns must end with a verified vault write).

## 1. Building a Hitting Prospect Projection Model — FanGraphs Community
**Source:** https://community.fangraphs.com/building-a-hitting-prospect-projection-model/
**Author:** Joshua Mould (CS/Stats student, Villanova)

- **Target:** binary — does a MiLB prospect reach **600+ MLB PA** (a "future value" outcome
  label, same family as our Release v3 no-future label, read from the top instead of the bottom).
- **Features:** age, BB%, K%, BABIP, ISO, GB%, SwStr%, SB% across Rookie→AA levels.
- **Method:** logistic regression + iterative variable selection; excluded active prospects
  and players who never left rookie ball.
- **Results:** AUC 0.955 test (inflated by design choices — see caveats). Upper-level (A+/AA)
  stats carry most signal. Kelenic >0.97; Buster Posey 0.012 (short MiLB tenure exposes the
  "fast riser looks like a washout" failure mode).
- **Takeaways for us:**
  - **93.5% washout base rate** → accuracy is meaningless; they needed custom baselines.
    Mirrors our censoring/base-rate care in the M1–M4 bake-off.
  - Missing-level handling = impute mean + missing-indicator (we solve the same problem with
    within-level features + censoring instead).
  - Variable reduction over kitchen-sink — independently validates our 192→7 feature collapse.
  - Their AUC 0.955 vs our 0.79–0.80 is NOT comparable: their label leaks resolution (only
    resolved careers, PA-based target correlated with the org's own decisions) and has no
    GroupKFold-by-player. Ours is the honest number.

## 2. KATOH: Forecasting MLB Pitching with Minor League Stats — The Hardball Times
**Source:** https://tht.fangraphs.com/katoh-forecasting-major-league-pitching-with-minor-league-stats/
**Author:** Chris Mitchell (Feb 6 2015)

- **Target:** P(MLB appearance by age 28) + P(career WAR > 4/6/8/10/12/16) —
  threshold-family targets, the pitcher-side sibling of our promote/release framing.
- **Method:** probit regressions PER LEVEL (R−, R+, A, A+, AA, AAA); stats
  league-adjusted but NOT park-adjusted.
- **Features:** age, GS%, K% (most predictive, esp. short-season), BB% (meaningless in
  low minors, signal only above Low-A), HR% (only matters ≥AA), handedness, K%² at AAA
  (negative coefficient).
- **Results:** Syndergaard 99% MLB; Urias 49% >6 WAR. AAA projections most reliable;
  low-level pitcher projections have huge error bars.
- **Takeaways for us:**
  - Per-level models with per-level feature validity (BB% worthless in rookie ball,
    HR% only ≥AA) — directly supports our within-level feature design.
  - "No such thing as a pitching prospect" — pitcher-side models need wider
    uncertainty than hitter-side; stats stabilize slower.
  - Their gaps (no height, no park factors) are things our GC2 data CAN supply.

## 3. KILA Projections — Beyond the Box Score
**Source:** https://www.beyondtheboxscore.com/2019/4/3/18292465/kila-projections-major-league-minor-league-prospects-stats-scouting-fernando-tatis-wander-franco
**(Apr 3 2019; named after Quad-A legend Kila Ka'aihue)**

- **Target:** projected career MLB **wRC+** for any prospect (continuous, not binary —
  different family from KATOH/Mould).
- **Method:** peer-group comparison (league + age peers) on six MiLB hitter stats —
  **wRC+, K%, BB%, ISO, BABIP, GB%** — producing a KILA Score, then simple linear
  regression of KILA Score → actual MLB wRC+.
- **Results:** r = .423 between projected and actual MLB wRC+ — an improvement over
  raw minor-league metrics alone.
- **Capture caveat:** site TLS-blocks all our fetch routes (direct, jina, archive) —
  summary reconstructed from search excerpts; read the full article manually for the
  peer-group mechanics + Tatis/Franco examples.
- **Takeaways for us:** age-relative-to-league peer grouping is the load-bearing idea
  (we encode age the same way); r=.423 on a continuous target is the honest ceiling
  this data supports — consistent with our 0.79–0.80 AUC being "good," not "low."

## 4–5. UNIDENTIFIED — 2 of the original 5 still missing
- [ ] link 4 — ? (Zac to re-find)
- [ ] link 5 — ? (Zac to re-find)

Related: [[promotion-release-models]] · [[release-v3-shipped-2026-07-02]] · [[advisory-council]]
