---
type: concept
domain: pitching
source: astros-docs
---
gcPerf (gcPerformance) — a **pitch-level, context-neutral** performance score grading the quality of an individual pitch by its result, independent of count/leverage.

## Model form
A linear run-value sum over 6 primary pitch results, expressed **per 1000 pitches**, then converted to a 20–80 scout grade. Heart-of-zone uses an in-zone/out-of-zone-style split (Heart here includes the Meatball zone).

## Run values (per 1000 pitches)
- In-Heart whiff: **−10**
- Out-of-Heart whiff: **−8**
- Called strike: **−2**
- Ball (+ HBP): **+2**
- pBarrel BBE: **+9**
- non-pBarrel BBE: **−2**

## Why it exists
Designed to out-predict **RVGainHS** at forecasting a pitch's *future* efficacy. Fit to future RVGHS, gcPerf correlates better to next-half RVGHS than RVGHS itself does (test: 75+ pitches of one type vs a handedness, 1st-half → 2nd-half). Simpler and more predictive — a results-based pitch measure.

## Distribution note
Fit on **all pitches at once**, not by pitch type — so grades aren't centered at 50 per type. Good shapes (same-sided SL) shift high; weak shapes (opposite-sided FT) shift low. Sibling to [[gcera]] (pitcher-level run estimate) vs gcPerf (pitch-level grade).

## Links
[[MOC-baseball-analytics]] · [[MOC-astros-engineering]] · [[gcera-canonical]] · [[gc2-metrics]] · [[gcera]] · [[gcperf]] · [[fip]] · [[era]] · [[stuff-plus-4s-pitching]]
