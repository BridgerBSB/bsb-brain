---
type: concept
domain: pitching
source: personal-bsbres/statistical-models
---
# Independent Stuff Value (ISV)

The **"stuff" component** of Driveline's intrinsic pitch model — quality of a pitch based purely on **how it moves**, ignoring where it's located. Stuff models are "widely regarded as one of the most efficient stats at determining a pitcher's ability." ISV is the ball-flight-only sibling of [[independent-location-value]] (location-only) and a child of [[independent-pitch-value]] (the full pitch). Public analogs: FanGraphs Stuff+, [[tjstuff-plus]], [[stuff-plus-deep-learning]]; Astros internal [[stuff-grade]].

## Architecture & inputs
Same tree-based ensemble of event-probability sub-models as [[independent-pitch-value]] (p(event) × v(event) composed into run value), but **trained without location features**. Inputs are **ball-flight metrics only**: velocity, induced movement (V/H break), release, spin-derived shape, arm slot. Because the expectation is built only on movement, **location noise can't cloud the swing/chase pattern** — which is why ISV dominates whiff/contact *reliability* (the IPV writeup notes "expected whiff and contact is more reliable using ISV, because the model lacks location information").

## Reliability — the standout property
Stuff is not only sticky, it converges **faster than every other model**.
- **Self-stickiness:** ISV → next-year ISV is **r ≈ 0.84 at 1000 pitches** — the highest of any model in the family (more sticky than IPV's 0.67).
- **Reliability (Cronbach's Alpha):** **only ~30 pitches** for all-pitch ISV, and far fewer per pitch type — **FF 13, SL 13, CB 10, CH 8, FC 11, SI 10, SP 8, ST 14 pitches**.
- **Unbiased (context-neutral) ISV** converges even faster — FB 6, SL 3, CB 2, CH 4, FC 5, SI 5, SP 5, ST 4 pitches. (Unbiased models value a strike the same in any count; the standard models weight AB-ending events more heavily because an 0-2 strike is worth more than an 0-0 strike. Unbiasing only matters for reliability, where it helps small samples.)
- **Caveat:** ISV is *not* better than the raw stat at predicting next-year whiff/CSW/chase/swing rate — for those, use the actual rate. ISV's value is being its own sticky, fast-converging metric.

## What the model values (into the weeds)
- **Velocity** drives fastball value: faster FF → higher average value. Cutters & sinkers value speed too, slightly less. Fastball-type pitches gain value by being thrown harder.
- **Breaking balls** don't *require* velocity for high value, but more velo on CB/sweepers returns more value; sliders **level off around 75 mph**. The model generally favors breaking balls of any type.
- **Offspeed is the one exception to the "vacuum" rule** — offspeed pitches get the pitcher's **primary-FB average velocity** as additional context. Velocity *separation* matters: changeup value peaks around **75-80 mph** and the **FB-minus-offspeed velo gap peaks ~11 mph** of benefit. Separation between ~6 mph (league avg) and 11 mph earns better RV; >11 mph degrades (and the sample of such pitchers shrinks). A 98 FB / 88 CH (10 mph gap) badly disrupts timing; a 90/86 gap (4 mph) lets a late hitter still catch up.
- **Spin** matters for breaking balls — curveballs range from low-spin gyro (little movement) to high-spin loopy; the model **values increased spin with no real drop-off**.
- **Shape-by-movement "blob":** Driveline's signature velocity×movement plot, recolored by model value (blue=bad → white=avg → red=good), with the average arm-angle line from the origin. Movement value persists even at slow breaking-ball speeds and amplifies with velocity; high-slot pitchers (e.g. Dylan Cease) still grade elite from atypical movement, so the model values movement *relative to arm slot*.

## Platoon & handedness
Same-handed matchups benefit the pitcher, most prominently **L/L**. Driveline **splits RHP and LHP into two separate models** to avoid lefty-sample bias (FanGraphs instead weights lefties inside one model — "neither approach is right or wrong").

## Versus FanGraphs Stuff+
Top-10 lists overlap (Pete Fairbanks, Félix Bautista, Andrés Muñoz, Jhoan Duran, Mason Miller, Edwin Díaz, Ryan Helsley). **FanGraphs favors cutters more heavily.** FG Stuff+ better predicts swing & chase rate; **ISV better predicts whiff & CSW rate.** Output is run value per pitch (negative = good); implemented as gradient-boosted trees ([[lightgbm-baseball-modeling]]).

## Links
- [[MOC-baseball-analytics]]
- [[independent-pitch-value]], [[independent-location-value]], [[execution-run-value]], [[independent-value-family]]
- [[stuff-plus-4s-pitching]], [[lightgbm-baseball-modeling]], [[re24-run-expectancy]], [[xwoba]]
