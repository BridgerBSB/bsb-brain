---
type: reference
created: '2026-06-29'
tags:
  - player-evaluation
  - pitching
  - big-4
  - scouting
---
# Pitching Reports

Part of [[Player-Evaluator-Agent]]. Evaluate every pitcher through the Big 4.

## The Big 4
1. **Velocity**. A hard threshold that sets margin for error. Avg velo, peak velo, rolling velo,
   and the ability to hold velo.
2. **Stuff**. Stuff+, Shape+, pitch shapes, iVB, HB, spin, release height, release side,
   extension, VAA/HAA, axis/spin efficiency, and pitch separation. Stuff+ style models use
   physical pitch characteristics to grade quality outside of command and context.
3. **Command**. K/BB, zone%, strike%, first-pitch strike%, and ideally miss distance from the
   catcher's target. Separate stuff problems from execution problems.
4. **Projection / development opportunity**. Age, physicality, athleticism, delivery
   adaptability, pitch-design upside, starter/reliever path, biomechanical growth areas.

## Pitcher metric list
Velo and max velo, IVB, HB, spin, release height, release side, extension, Stuff+, Location+,
K%, BB%, K-BB%, Whiff%, Chase%, IZ%, IZ-Miss%, FIP, SLG allowed, Barrel%, GB%, platoon splits.

## Pitcher report logic
- ERA is a poor predictor of future success here. Trust strikeout, damage-limiting, and whiff
  indicators more than surface run prevention.
- Command is often a clearer development opportunity than trying to add impact stuff.
- A starter profile usually has 3+ usable pitches, with 2 that miss bats and 1 that can be
  thrown in the zone.
- The pitch can be good while the issue is usage and access.
- The arsenal may benefit from a bridge pitch.
- Throw the fastball less if its xRV or damage profile lags the secondaries.
- He needs to throw the breaking ball in the zone early so he is not predictable.

## Pitcher language (use these)
- "ERA is a poor predictor of future success here."
- "I would trust strikeout, damage limiting, and whiff indicators more than surface run prevention."
- "The walk rate is a concern, but it is a clearer development opportunity than trying to add impact stuff."
- "He is starting with a better foundation of stuff and damage prevention."
- "The pitch is good, but the issue is usage and access."
- "The arsenal would benefit from a bridge pitch."
- "The fastball should be thrown less if the xRV or damage profile lags behind his secondaries."

## Pitcher Comparison Format
Player X. He misses more bats across the board: (K%), (FB miss%), and (best secondary miss%). He
also allows less damage: (SLG/Barrel/EV) while sitting (velo), which gives him a stronger
foundation. Command is a concern, but I see that as a clearer development opportunity than trying
to add whiff or impact stuff. ERA is noisy here, so I would trust the strikeout, damage-limiting,
and whiff indicators more than surface run prevention. With him, you are starting from better
stuff and damage prevention, then working to tighten command and role fit.

See [[Report-Formats-and-Examples]] for templates, [[Biomechanics]] for delivery checkpoints,
[[Vocabulary-Bank]] for the full phrase set, and [[Decision-Analyst-and-Modeling]] for Stuff+
modeling notes.
