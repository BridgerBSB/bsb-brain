---
type: concept
domain: pitching
source: personal-bsbres/statistical-models
---
# Independent Location Value (ILV)

The **"command/location" component** of Driveline's intrinsic pitch model — value of a pitch based purely on **where it crosses the plate**, ignoring how it moves. Gives insight into a pitcher's control of the ball and ability to throw into the zone. It is the location-only complement to [[independent-stuff-value]] (ball-flight only) and a child of [[independent-pitch-value]]. FanGraphs analog: Location+.

## Architecture & inputs
Same tree-based event-probability ensemble as [[independent-pitch-value]] (p(event) × v(event) → run value), but **removes all ball-flight metrics and uses only plate location**. **Pitches aren't thrown to zones proportionally** — pitchers most commonly throw to the **Shadow and Chase** zones (steal strikes, induce whiffs, avoid hard contact), so the model has the most data — and the most year-to-year signal — there.

## Zone framework (heart / subheart / shadow / chase / waste)
Same-year correlations reflect intuition: **waste** pitches carry poor RV; **shadow and subheart** are where a called strike is likely but contact is less likely than the heart. The **one exception is offspeed in the heart**, which can gain value because the batter may be sitting fastball and be early. The emphasis of ILV is **controlling the strike zone**, so its strongest same-year correlate is **walk rate** (also K%, K-BB%).

## Run value by count (the interesting part)
- **Early & full counts:** value requires locating to **heart/subheart/shadow** to avoid falling behind or walking the batter.
- **Hitter's counts:** real value comes from the need to throw strikes — RV is *lost* in chase/waste where called-strike probability is low.
- **Pitcher's counts (the surprise):** when ahead, the **only** place to *gain* value is the **shadow** zone. Throwing to the **heart on a pitcher's count is the worst** location (free chances for the batter); shadow is neutral, waste is less punishing. A pitcher can afford a worse pitch when ahead. Note: the location model says chase is the only place a pitcher generates RV in a pitcher's count, and the hitter's-count behavior matches intuition less.

## Predictiveness & reliability
- **Self-stickiness:** ILV → next-year ILV is **r ≈ 0.65 at 1000 pitches** — use ILV to predict next-year ILV, *not* other stats (for walk/K rate, use the actual stat).
- **By zone (next-year ILV, 100 pitches):** heart r=0.64, **subheart r=0.69 (highest)**, shadow r=0.47, chase r=0.57, waste r=0.61. Heart and waste become highly correlated as the sample grows.
- **Reliability:** ILV as a whole ≈ **425 pitches**. Notably, **shadow is reliable *slowest* despite having the most pitches** — the outcome there is often up to the umpire, so ILV is more reliable in more "defined" zones (heart/waste). Most of a pitcher's ILV data lives in shadow/chase, which gives higher year-to-year trends.
- **Vs. FanGraphs Location+:** the two go back and forth on next-year prediction; *both* are insufficient for predicting these stats next year compared to just using the actual stat. (Top common pitchers across models include Tommy Milone, Keone Kela, John Means, Jacob deGrom, Chris Sale, Julio Urías, Hyun Jin Ryu.)

## Relationship to Execution RV
ILV ≠ [[execution-run-value]] (IPV Lost). **ILV** = the RV the pitch generated *solely from its final location*. **Execution RV** = the ability to generate value by *hitting the intended target* (`ActualLocationRV − IntendedLocationRV`). A pitcher who misses middle-middle by an inch has **good** execution RV (located his target) but **bad** location RV (likely hard contact). Output is run value per pitch; gradient-boosted trees ([[lightgbm-baseball-modeling]]).

## Links
- [[MOC-baseball-analytics]]
- [[independent-pitch-value]], [[independent-stuff-value]], [[execution-run-value]], [[independent-value-family]]
- [[stuff-plus-4s-pitching]], [[lightgbm-baseball-modeling]], [[re24-run-expectancy]], [[xwoba]]
