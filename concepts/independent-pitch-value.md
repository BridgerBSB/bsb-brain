---
type: concept
domain: pitching
source: personal-bsbres/statistical-models
---
# Independent Pitch Value (IPV)

The all-encompassing pitching metric in Driveline's 2025 "intrinsic value" family. IPV is the total **run value of a single pitch evaluated in a vacuum** — graded on the full set of physical characteristics AND plate location, but with no knowledge of what came before/after (no sequencing) and no credit for arsenal effects. It is the parent of [[independent-stuff-value]] (ISV, location stripped out), [[independent-location-value]] (ILV, ball flight stripped out), and [[execution-run-value]] (IPV Lost). The hitter-side mirror is [[independent-outcome-value]].

## Architecture — one big model split into 6 small ones
The new approach **abandons a single monolithic model** (which "lacked the ability to predict events solely based on pitch characteristics") in favor of a **tree-based ensemble of 6 smaller models**, each estimating the *probability* that a given event occurs plus the *value* of that event. Splitting outcome by event type narrows the focus, improves accuracy, and — critically — gives **interpretability of where the value came from** (e.g. "this pitch's value is from a high called-strike chance" vs. "high whiff chance" vs. "weak contact").

## The composition formula (bottom-up)
A single pitch's run value is built from a decision tree of p(event) × v(event):

```
Single-Pitch RV = p(Swing)·v(Swing) + p(Take)·v(Take)
  v(Swing)      = v(Contact)·p(Contact) + v(Whiff)·p(Whiff)
  v(Take)       = v(Umpire Call)·p(Umpire Call) + v(HBP)·p(HBP)
  v(Umpire Call)= v(Called Strike)·p(Called Strike) + v(Not Called Strike)·p(Not Called Strike)
  v(Contact)    = v(BIP)·p(BIP) + v(Foul)·p(Foul)
  v(BIP)        = v(Out)·p(Out)+v(1B)·p(1B)+v(2B)·p(2B)+v(3B)·p(3B)+v(HR)·p(HR)
```

The run value of the pitch is `outcome value − expected outcome value`. Each pitch carries a series of attached values (IPV / ISV / ILV / IPV Lost) that can be totaled. **Worked example** — Clay Holmes sweeper up-and-away to Muncy (one of the best-rated pitches of the season): low swing expectation (33%), high called-strike chance (97%), low hit chance if contact made (17%). Final attached values: **IPV −0.22 RV, ISV −0.03 RV, ILV −0.13 RV, IPV Lost −0.14 RV** (negative = good for the pitcher).

## Stated model limitations
- **No sequencing.** Pitches are valued in isolation; the model has no knowledge of batter expectations or pitches already seen (a Skubal FB-then-CH whiff off timing is invisible to it).
- **No arsenal effects.** A reliable secondary that "buys back" value for a primary, or a wide arsenal that resets batter expectations, can't be captured. The next version aims to add value for a pitch's contribution to the *overall arsenal* and model pitch "degradation" as batters familiarize.

## Predictiveness & reliability (the numbers)
IPV is the **stickiest** pitching stat year-to-year and predicts next-season pitcher stats often *better than the prior-year stat itself*. K-BB% (the known best public predictor) is the closest comparison.
- **Self-stickiness:** IPV → next-year IPV is the highest of any stat. **r ≈ 0.67 at 1000 pitches.**
- **Next-year FIP:** IPV and K-BB% both beat current-year FIP through ~1250 pitches. IPV r = 0.38 vs FIP r = 0.35 (1000 pitches).
- **Next-year xFIP:** IPV/K-BB% win in *small* samples (<~350 pitches); xFIP wins once the sample grows.
- **Next-year run value (Δ run expectancy):** IPV is best all season, especially at large samples. **IPV r = 0.51 vs Δ Run Expectancy r = 0.47 at 2500 pitches.**
- **Next-year xwOBA:** IPV wins below ~500 pitches; xwOBA wins above. (At 250 pitches: IPV r = 0.41 vs ΔRE r = 0.39.) **Rule of thumb: <500 pitches use IPV, >500 use xwOBA.**
- **Reliability (Cronbach's Alpha, >50% of value determined):** IPV and Execution RV ≈ **350 pitches**; ILV ≈ 425; **stuff/ISV is fastest at ~30 pitches.** Per pitch type, IPV converges in: FB 212, SL 217, CB 184, **CH 105**, FC 200, SI 243, **SP 103**, ST 166 (offspeed roughly half as many).
- **Whiff/chase:** xWhiff IPV out-predicts xWhiff ISV and actual whiff rate until ~800 whiffs (xWhiff IPV r=0.77, xWhiff ISV r=0.75, Whiff r=0.76 at 800). For *predicting next-year* whiff/chase, prefer the actual rate.

## Versus FanGraphs (industry standard)
FanGraphs' model (Eno Sarris write-up; Max Bay et al.) also switched to a tree-based, many-small-models approach. All Driveline pitching models correlate highly to their similarly-named ones; **fastballs are the closest, near-linear** relationship; the **biggest disparity is cutters**. Pitching+ beats IPV on most next-year metrics *except K-BB%*, and IPV only beats Pitching+ through the first ~1200 pitches before Pitching+ pulls ahead — small gaps attributable to model selection and parameter tuning. Implemented as gradient-boosted trees ([[lightgbm-baseball-modeling]]).

## Links
- [[MOC-baseball-analytics]]
- [[independent-stuff-value]], [[independent-location-value]], [[execution-run-value]], [[independent-value-family]]
- [[stuff-plus-4s-pitching]], [[lightgbm-baseball-modeling]], [[re24-run-expectancy]], [[xwoba]]
