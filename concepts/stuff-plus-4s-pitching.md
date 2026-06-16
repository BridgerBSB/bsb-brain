---
type: concept
domain: pitching
created: '2026-06-15'
---
# Stuff+ / 4S Pitching

The umbrella note for **public pitch-grading model families** — the "+" pitch models that grade a pitch/pitcher vs league average (**100 = average, like IQ**; >100 better, <100 worse) — and the **4S** decomposition that splits a pitcher into shape, command, release, and sequencing.

## The "+" model stack (Stuff+ / Location+ / Pitching+)
These are nested, location-aware vs location-agnostic cuts of the same idea — score pitch quality from physical traits, scaled to 100 = league average. The canonical public lineage is FanGraphs (Eno Sarris) and Driveline (Chris Langin); the Astros internal Stuff/Proj grades are the org's version.

- **Stuff+** — *location-agnostic* pitch quality from **ballflight only**: velocity, induced vertical & horizontal break, release height/extension, spin, tilt, spin efficiency, plus fastball-relative deltas. Filters out plate location entirely (command lives in a separate metric). Pitch types compete **within buckets** (Fastballs / Breaking Balls / Offspeed) that are *not* equivalent across groups — a FF Stuff+ 150 ≠ a slider Stuff+ 150 in raw value. Converges fast and is the most reliable in small samples. See [[stuff-plus-deep-learning]] (the deck + 2021 Langin article), [[tjstuff-plus]] (open-source LightGBM build), and Driveline's [[independent-stuff-value]] (ISV).
- **Location+** — *ballflight-agnostic* — grades **where the pitch is located** over the plate, by zone (heart / subheart / shadow / chase / waste) and count. Strongest correlate is walk rate; it measures **zone control / command of the strike zone**. Driveline analog: [[independent-location-value]] (ILV). Command-execution residual (intended vs actual location): [[execution-run-value]].
- **Pitching+** — the **full pitch**: Stuff+ × Location+ combined into one all-encompassing grade — the public twin of Driveline's [[independent-pitch-value]] (IPV). Pitching+ is generally the **strongest next-year predictor** among the "+" stack (beats Stuff+/Location+ on most stats), edged only on K-BB% in some comparisons.

All are tree-based now (FanGraphs switched to many-small-models, mirroring Driveline's p(event)×v(event) engine) and output is anchored to run value / [[re24-run-expectancy]]. How they're trained: [[lightgbm-baseball-modeling]].

## 4S Pitching — Shape+ / Spot+ / Slot+ / Sequence+
**4S Pitching** (Johnny Nienstedt) decomposes a pitcher's effectiveness into **four orthogonal "S" components**, each a "+" grade vs league:
- **Shape+** — the **movement/shape** of the pitches (the Stuff+-adjacent axis): velocity + induced break profile, how nasty the raw shapes are. Answers "how good is the *stuff*?"
- **Spot+** — **command / location** ("spotting" the pitch): the Location+-adjacent axis — how well pitches are placed in valuable zones for the count. Answers "how well is it *located*?"
- **Slot+** — **release / arm slot** consistency & deception: how the release point and arm angle add (or subtract) value — release height/side, extension, slot repeatability and how shapes play *from that slot*. Answers "how does the *delivery/release* play?"
- **Sequence+** — **pitch sequencing & arsenal interaction**: the value created by *how pitches are mixed* (tunneling, pairing, usage, resetting batter expectations) — exactly the **arsenal/sequencing effects the single-pitch models can't see** (the IPV writeup's stated blind spot). Conceptually adjacent to Driveline's [[mix-plus-sync]] (Match+/Mix+) and decay/buyback usage modeling. Answers "how well is the arsenal *deployed*?"

Together the 4S split lets you say *where* a pitcher's value comes from — elite shape but poor sequencing, or average stuff with elite command + deceptive slot — rather than a single black-box grade.

## Used in / people / tie-ins
- **Used in:** [[personal-bsbres]] (templates + research), [[swing-path]] examples.
- **People:** [[johnny-nienstedt]] (4S Pitching), [[jack-kelly]] (public Stuff+), Chris Langin / Eno Sarris (Stuff+/Pitching+ public lineage).
- **Related:** [[pitch-design-logic]] (design side) · [[lightgbm-baseball-modeling]] (training) · [[independent-value-family]] (Driveline's intrinsic-RV analog of the whole stack).
- **Astros tie-in:** internal Stuff/Proj grades (`rules/pd-goals` pitcher pools, `rules/gcera-canonical`). The public models are the open analog of the org's. See [[stuff-grade]].

## Links
- [[MOC-baseball-analytics]] · [[independent-pitch-value]] · [[independent-stuff-value]] · [[independent-location-value]] · [[execution-run-value]] · [[independent-value-family]]
- [[stuff-plus-deep-learning]] · [[tjstuff-plus]] · [[mix-plus-sync]] · [[driveline-hitting-models]] · [[pitch-design-logic]] · [[lightgbm-baseball-modeling]] · [[stuff-grade]]
