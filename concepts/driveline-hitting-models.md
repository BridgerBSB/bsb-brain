---
type: concept
domain: hitting
source: personal-bsbres
created: '2026-06-15'
---
# Driveline Hitting Models (2025)

2025 hitter run-value models (**Jack Lambert / Sam Ehrlich**, Baseball Operations, Jan 28 2025). The hitting-side mirror of the tree-based pitch model, and the production-numbers companion to [[independent-outcome-value]] (IOV).

## What it models
Driveline's newest pitch model follows a **tree-based approach** — not predicting a pitch's run value directly, but **the probability each type of event occurs**, then aggregating value bottom-up (P(event) × value(event), the "green circles"). The hitting side dissects this event-based engine into **hitter component values**, each defined as **the difference between the value of the hitter's choice and the expected value of the situation he's put in.**

## Components
- **Swing Decision RV** — swing/take vs the situation's EV.
- **Contact RV** — comparing the probability/value of a whiff vs contact to whether the hitter actually whiffed or made contact.
- **Power RV** — comparing actual Out/1B/2B/3B/HR probabilities & values to the hitter's **xOut/xSingle/xDouble/xTriple/xHomer based on EV/LA**. A **"quality of batted ball" model** that **replaces the bat-speed portion of the "big 3"** ([[big-3-hitting]]); bat speed explains only **~43%** of power output, so power RV is broader than bat speed alone.
- **Overall Hitter RV** = sum of the three. Worked example: **−0.140 SD + 0.154 contact + 1.344 power = 1.358 total runs.**

## Inputs / method
Pitch location, stuff/quality, swing/take, and EV/LA per BIP — **pitch-by-pitch (~2,500 pitches/season)**, not just the ~600 PA outcomes WAR uses. GBM-style event-probability decision tree → run-value attribution. **Known limitation:** holding location & stuff equal, contact and swing-decision value are treated the same for every hitter — it doesn't model hitter-specific trends, so it can **undervalue proven "bad-ball" hitters** (Rafael Devers crushing below-zone breaking balls, Luis Arraez's elite out-of-zone barrel skill).

## Why the RV scale matters (not equal-weight grades)
Outputs can be viewed as 20-80 grades, but the **run-value scale is the point** — viewing them as 20-80 wrongly implies the components are equal. Per-600-PA standard deviations show they are **not**:
- **Swing Decision: 7.48 runs / 600 PA**
- **Contact: 8.51 runs / 600 PA**
- **Power: 17.75 runs / 600 PA** (≈ 2× the others)
Example: Rafael Devers grades 70+ power in the heart, 30- contact — these **don't cancel; power wins.** The RV scale also makes the model **apples-to-apples with WAR's batting-runs** (strong relationship), but Lambert trusts the model more because it works at the pitch level (~2500 pitches) vs WAR's ~600 final PA outcomes.

## Predictiveness (next-year)
- **Overall Hitter RV → next-year wRC+: r ≈ 0.55 at 1000 pitches** — vs. current-year wRC+ → next-year wRC+ only **r ≈ 0.45.** ("Incredibly meaningful" — the model beats the stat at predicting itself.)
- **Swing Decision RV → next-year walk rate ≈ 0.52** (strong, but doesn't top walk-rate→walk-rate, which hits ~0.7 above 1000 pitches).
- **Contact RV ↔ whiff rate r = −0.79, ↔ strikeout rate r = −0.77** (comparable to whiff→K, but trusted more for incorporating pitch quality).
- **Power RV ↔ ISO: r = 0.57 at min-1000 pitches** — comparable to ISO self-prediction but stronger at lower samples.

## Reliability & stickiness (Cronbach's Alpha; >50% determined)
- **Reliable at:** Swing Decision **440 pitches seen**, Contact **180 swings**, Power **150 BIP**, Overall **1330 pitches seen.**
- **Year-to-year stickiness (min 1000 pitches):** Swing Decision **r = 0.83**, Contact **0.82**, Power **0.76**, Overall **0.72** — "significantly better than wRC+ predicts itself."

## What regular stats correlate
- **Swing decisions** are largely a function of **swing rate by location** — SD RV rises with heart/subheart swing rate, falls with chase/waste swing rate; the **waste zone spans the widest x-axis** → it's the most crucial zone for swing-decision RV.
- **Contact** — less whiffing = better contact; the **chase zone has the largest variance**, so elite contact is *proven in hard-to-hit zones*, not by never whiffing in the heart (high heart-contact is expected).
- **Power** — power RV everywhere on the plate correlates to **xwOBAcon**, with the **heart & subheart** dictating power grades and driving total RV.

## Links
[[MOC-baseball-analytics]] · [[independent-outcome-value]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[lightgbm-baseball-modeling]] · [[driveline]] · [[stuff-plus-deep-learning]] · [[tjstuff-plus]] · [[mix-plus-sync]] · [[big-3-hitting]] · [[xwoba]]
