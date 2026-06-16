---
type: concept
domain: pitching
source: personal-bsbres
created: '2026-06-15'
---
# Mix+ / Sync (Match+)

Driveline **arsenal-interaction** concepts (Langin, "Sync" deck, 9/9/2024). About **pitch *pairings*, not single-pitch quality** — the layer above [[independent-stuff-value]] / [[stuff-plus-deep-learning]] that the single-pitch models explicitly *can't* see (the IPV writeup names "arsenal effects" as a known blind spot).

## What it models — how pitches relate through the hitter's eyes
- **Match+** — how *similar* two pitches look as they travel **release → home** (do they tunnel?).
  `Match = Σ(Usage × IntegralPct for each comparison pitch in arsenal)`
  `IntegralPct = Integral(last 150 ms of flight) / Integral(entire ball flight)`
  Derived from an **entropy curve** read **every 10 ms** between two pitch-trajectory distributions.
- **Mix+** — how *far apart* two pitches are **when they reach the plate** (do they diverge?).
  `Mix = Σ(Usage × DistAtPlate for each comparison pitch in arsenal)`
- **Ideal pairing = high Match early (looks identical out of the hand) + high Mix late (separates at the plate)** — the classic "tunnel then break."

## Inputs / method
Pitch trajectory distributions, plate-location separation, and arsenal usage weights. This is an **analytic/geometric framework** (integral & entropy comparisons, plate distance) — **not a learned model** — feeding a **usage optimizer**, and rolled up to the arsenal via usage weighting.

## Decay / Buyback & macro-usage optimization
Assuming Mix and Match describe the relationship between two pitches, you can model how different **usage schemes combat the familiarity effect** — pitches **decay** as a batter sees them and get **bought back** by throwing dissimilar looks. Set an objective (**Stuff+, GB%, CalledStrike%, Whiff%**, etc.) and use **Mix/Match as a *cost*** to optimize **macro usage**.

## Deployment thinking (Kress conversation takeaways)
- Macro-usage *prescriptions vs current use* is effective, easy to understand, easy to pitch athletes on; likely a tool used alongside advance reports.
- In-gym rollout works as **bullpen scripting** — either macro-usage subscriptions, or per-pitch **"health bars"** that decay with reuse and refill when similar pitches are thrown.
- Buyback framing for athletes: *"every time you throw pitch X you buy n more uses of pitch Y"* (though high-level usage targets may be easier to grasp).
- Get the metrics into the DB/TruMedia so trainers can experiment.
- Proposal: dial in macro usage, then flag pitchers who deviate significantly from the model.

## Links
[[MOC-baseball-analytics]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[lightgbm-baseball-modeling]] · [[driveline]] · [[stuff-plus-deep-learning]] · [[tjstuff-plus]] · [[driveline-hitting-models]] · [[independent-pitch-value]]
