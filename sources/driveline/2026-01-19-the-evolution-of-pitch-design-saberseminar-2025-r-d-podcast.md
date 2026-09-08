---
type: source
source: driveline
medium: video
title: The Evolution of Pitch Design | Saberseminar 2025 | R&D Podcast EP 111
url: "https://www.youtube.com/watch?v=2fjpL_BraVU"
published: 2026-01-19
author: Driveline Baseball
duration_s: 2606
domain: [pitching]
kind: research
value: high
status: approved
raw: sources/_raw/driveline/2fjpL_BraVU.md
cues: []
drills: []
concepts: [pitch-design-logic, independent-value-family, execution-run-value, pitching-development-philosophy]
confidence: zac
---
# The Evolution of Pitch Design | Saberseminar 2025 | R&D Podcast EP 111

## TL;DR
- Driveline extends the "fingerprint" idea, historically just a fastball-based pronation/supination heuristic, into a "blob of blobs": the full space of pitch shapes and velocities a pitcher can produce, built from every pitch he already throws, not just his fastball.
- They score each point in that space with a feasibility percentage and a predicted outcome, then use an RE-288 (game-state run expectancy) model to recommend which achievable pitch to throw in each count and base-out state, instead of defaulting to the highest-whiff pitch.
- Case example: Hunter Greene's four-seamer grades below league average when he's behind in the count, so the model recommends his sinker be used over 50% of the time in those deep-count, runners-on spots.

## Claims
- [07:02](https://youtu.be/2fjpL_BraVU?t=422) Current industry heuristics are simple: a low-efficiency fastball with a supination bias suggests a sinker or sweeper; a pronation bias suggests a changeup. Driveline is trying to go beyond these rules of thumb.
- [09:20](https://youtu.be/2fjpL_BraVU?t=560) Pitch shape is a function of arm slot and ball manipulation (spin efficiency, spin axis); the same manipulation produces different shapes at different arm slots, and the same shape requires different manipulations at different arm slots.
- [10:26](https://youtu.be/2fjpL_BraVU?t=626) A three-pitch arsenal gives three data points to predict achievable shapes; a full arsenal like Seth Lugo's gives nine.
- [19:45](https://youtu.be/2fjpL_BraVU?t=1185) Darvish example of the velo-shape tradeoff: his curveball has about 20 inches of total movement and is about 20 mph slower than his fastball; his slider has about 5 inches of movement and is about 7 mph slower.
- [20:46](https://youtu.be/2fjpL_BraVU?t=1246) Each point in the shape/velocity space gets a feasibility score, e.g. "85% confidence" a pitcher can achieve a given shape.
- [23:54](https://youtu.be/2fjpL_BraVU?t=1434) They map each achievable pitch's outcome distribution onto RE-288 (a 288-state run expectancy matrix by count/base/out) to find which pitch minimizes expected run value in that state, rather than assuming the highest-CSW pitch is always correct.
- [26:08](https://youtu.be/2fjpL_BraVU?t=1568) RE-288 does not account for score or leverage index; the hosts say pitch selection should differ in a tie game with a runner on third and no outs versus a 10-run lead with a runner on first and one out.
- [31:42](https://youtu.be/2fjpL_BraVU?t=1902) Cutters (and to a lesser extent sinkers) can produce a wide range of outcomes across many RE-288 states, which can justify very high single-pitch usage; Joey Wentz is cited as an example of near-exclusive cutter usage working well.
- [38:19](https://youtu.be/2fjpL_BraVU?t=2299) Hunter Greene's fastball grades around average or slightly below league average in behind-count states; the model recommends adding a sinker for those counts.
- [39:20](https://youtu.be/2fjpL_BraVU?t=2360) For Hunter Greene, the usage model recommends the sinker be thrown over 50% of the time with runners on base and deep in the count.

## Cues
- none given

## Drills
- none shown

## Evidence cited
- Athletic article (Chad Jennings, Dennis Lin, Eno Saris) on the rise of the "rising fastball," discussed for background context, not authored by Driveline.
- Internal Driveline pitch-shape and RE-288 models, illustrated with Yu Darvish's pitch movement/velocity numbers and Hunter Greene's projected usage rates.
- Named case examples of usage-driven improvement: Lance Lynn (Cardinals to Dodgers, 2022) and Luke Weaver (Reds to Yankees; Reds-era rate quoted as "70 RA" (sic)), both cited without further method detail.

## Open questions
- RE-288 explicitly excludes score and leverage index, which the hosts flag as a gap for score-differentiated situations (tie game vs. blowout) without offering a fix.
- The framework projects new pitch shapes from pitches a pitcher has already thrown, which the hosts acknowledge limits its ability to identify truly novel shapes he's never demonstrated.

## Zac


## Links
[[MOC-training-knowledge]]
[[MOC-pitching]]
[[pitch-design-logic]]
[[independent-value-family]]
[[execution-run-value]]
[[pitching-development-philosophy]]
