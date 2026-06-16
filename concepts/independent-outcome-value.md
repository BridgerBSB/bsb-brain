---
type: concept
domain: hitting
source: personal-bsbres/statistical-models
---
# Independent Outcome Value (IOV)

**Intrinsic Offensive Value** — the hitter-side counterpart to the pitching family ([[independent-pitch-value]]). Decomposes a hitter into component run values:

```
SwingDecisionRV + ContactRV + PowerRV = TotalRV
```

Each component is **the value of the hitter's choice − the expected value of the situation he was put in.** Built on the same tree-of-event-probabilities engine. (Closely related to / the same lineage as [[driveline-hitting-models]], which gives the production-side numbers; this note is the IOV writeup's framing.)

## The three components — what each measures
- **Swing Decision RV** — evaluated on **every pitch**. Run value is **gained in the heart & subheart** of the zone (good pitches to attack) and **lost in chase/waste**. Compares swing-vs-take to the situation EV.
- **Contact RV** — evaluated on **every swing**. Quality of contact vs. *potential* contact on all swings. **The biggest costs are poor contact in the chase & waste zones.**
- **Power RV** — evaluated **only on balls in play**. Most runs gained on pitches at the **heart** of the plate; runs lost when putting chase/waste pitches in play. Compares actual Out/1B/2B/3B/HR to xOut/x1B/x2B/x3B/xHR from EV/LA — effectively a "quality of batted ball" model.

Overall, the models value pitches in the **center of the zone**.

## Descriptiveness (same-year correlations)
- **Swing Decision** ↔ walk rate & swing rate (a good swing decision shows up as walk rate).
- **Contact** ↔ **strong negative** with whiff rate & strikeout rate (poor contact → high whiff/K).
- **Power** ↔ positively with **HR rate, ISO, wOBA, wRC+**.
- **Total RV** ↔ same-season HR rate, ISO, wOBA, wRC+ and walk rate.

## Predictiveness (next-year)
- **Swing Decision** has signal predicting next-year walk rate & swing rate.
- **Contact** predicts next-year whiff rate & strikeout rate.
- **Power** hitter in year *n* tends to high HR rate, whiff, walk, K, BABIP, ISO, wRC+ in *n+1*.
- **Total** has slight correlation with next-year HR rate, walk rate, ISO, wOBA, wRC+.

## Reliability (Cronbach's Alpha, 0.7 threshold)
As the hitter sees more pitches, observed value better reflects true talent.
- **Power & Contact converge fastest**; Swing Decision & Total take longer. (~1000 hitters met the threshold between 2021-24.)
- **~150 pitches seen** to know if a batter's **power** generates RV.
- **Heart-zone power is even faster: only ~50 balls in play from the heart** reveal whether the batter generates RV there.
- **Contact & swing decision** also become reliable quickly when looking at the batter's **actions in the chase zone**.
- A separate "better" reliability cut places **Total around ~2500 pitches seen.** Reliability is also broken down by zone (heart/subheart/shadow/chase/waste), by pitch family (FB/breaking/offspeed), and by count (early/pitcher's/hitter's/full).

## Notes / future work
The writeup flags planned additions: year-*n*-to-*n+1* comparisons of each component vs. the matching traditional stat (e.g., SD RV vs next-year walk rate vs walk-rate-to-walk-rate); descriptive-by-zone comparisons (SD RV by zone ↔ swing rate by zone; Contact RV by zone ↔ whiff rate by zone; Power RV by zone ↔ xwOBA by zone); and out-of-zone swing decision (year prior) → walk rate (current). Output is run value; gradient-boosted trees ([[lightgbm-baseball-modeling]]). Astros-side ties: [[swdec]], [[orp-bat]], [[big-3-hitting]].

## Links
- [[MOC-baseball-analytics]]
- [[independent-pitch-value]], [[independent-stuff-value]], [[independent-location-value]], [[execution-run-value]], [[independent-value-family]]
- [[driveline-hitting-models]], [[stuff-plus-4s-pitching]], [[lightgbm-baseball-modeling]], [[re24-run-expectancy]], [[xwoba]]
