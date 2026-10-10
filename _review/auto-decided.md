# Auto-decided notes

Written by `kb.py decide` 2026-10-10 14:26.

**To overturn:** open the note and change `status:` to `rejected` (on an auto-approved note) or `approved` (on an auto-rejected one). The next nightly run files it and the model learns from it.

## Model

- Trained on **126** of your grades (100 approved / 26 rejected), high and med notes only.
- Tested on your past grades (each note scored by a model that never saw it): agrees with you **83%** of the time; passing every note as approvable would agree 79%.
- Ranks your approves above your rejects 82% of the time (the writer's high/med rating: 77%; on med notes alone, the model: 74%).
- Auto-approves at p >= 0.57: on your past grades that zone held 64 notes, 3 of which you rejected (budget: 1 in 20).
- Auto-rejects at p <= 0.37: that zone held 4 notes, 0 of which you approved (budget: 1 in 50).

**Last run:** auto-approved 28, auto-rejected 0, left for you 12.

Overturned by you so far: 0.

## Auto-approved (28)

- [[2020-01-23-the-tennis-racket-drill-a-simple-arm-action-fix]] p 0.73 - like [[2026-06-30-how-to-fix-your-pushy-arm-action-pushy-arm-action-part-two]] (approved), [[2018-02-12-how-i-cue-my-arm-action]] (approved), [[2019-01-13-upgrading-your-j-band-routine-part-2b-patterning-fixing-a]] (rejected)
- [[2020-05-26-us-vs-korean-baseball-are-there-mechanical-differences]] p 0.61 - like [[2026-08-23-how-to-throw-hard-as-a-short-pitcher]] (approved), [[2016-08-05-throw-harder-fastballs-by-improving-your-external-rotation]] (approved), [[2016-11-10-customized-mechanics-lateral-power]] (approved)
- [[2019-03-14-the-theory-behind-the-yips-in-baseball]] p 0.58 - like [[2017-04-06-why-dominicans-are-dominating-baseball]] (approved), [[2026-03-28-his-bat-path-is-costing-him]] (approved), [[2012-07-30-supramaximal-training-with-weighted-baseballs]] (approved)
- [[2014-05-02-glove-side-elevation-drill-w-overload]] p 0.71 - like [[2025-12-13-6-drills-to-fix-your-posture-hinge-and-rotation-feat-logan]] (approved), [[2026-03-28-his-bat-path-is-costing-him]] (approved), [[2026-05-16-cues-drills-to-let-your-body-deliver-the-barrel-to-the-ball]] (approved)
- [[2014-07-19-brady-aiken-s-elbow-change-up-grips-youth-pitching-q-a-w]] p 0.61 - like [[2026-06-30-how-to-fix-your-pushy-arm-action-pushy-arm-action-part-two]] (approved), [[2010-03-07-mechanics-the-effects-of-loading-rate]] (approved), [[2026-01-09-why-pushing-his-hands-led-to-this-mlb-draft-prospects-power]] (approved)
- [[2014-03-07-voodoo-flossing-the-elbow-for-baseball-pitchers-driveline]] p 0.65 - like [[2026-05-21-the-ultimate-pitcher-s-guide-to-j-bands]] (approved), [[2019-01-13-upgrading-your-j-band-routine-part-2b-patterning-fixing-a]] (rejected), [[2012-05-01-weighted-baseballs-wrist-weights-and-arm-injuries-q-a-with]] (approved)
- [[2014-11-01-how-do-weighted-baseballs-work-total-vs-peak-force]] p 0.62 - like [[2012-07-30-supramaximal-training-with-weighted-baseballs]] (approved), [[2012-05-01-weighted-baseballs-wrist-weights-and-arm-injuries-q-a-with]] (approved), [[2018-02-08-the-case-for-lifting-weights-a-declaration-for-the-youth]] (approved)
- [[2010-08-09-closed-chain-vs-open-chain-motion]] p 0.75 - like [[2010-02-11-link-should-pitchers-bench-press]] (approved), [[2018-02-02-roll-ins-variations]] (approved), [[2026-07-29-these-6-lifts-are-non-negotiable-for-pitchers]] (approved)
- [[2010-08-27-elbow-injuries-and-what-causes-tommy-john-surgery]] p 0.68 - like [[2010-03-07-mechanics-the-effects-of-loading-rate]] (approved), [[2010-01-17-kinematic-analysis-wrist-to-elbow-relationship]] (approved), [[2026-07-21-how-pros-use-pulse-and-what-it-means-for-the-rest-of]] (approved)
- [[2010-09-15-myth-strength-training-is-not-specific-to-baseball-pitching]] p 0.60 - like [[2010-02-11-link-should-pitchers-bench-press]] (approved), [[2015-07-30-gain-muscle-to-pitch-harder-and-increase-velocity]] (approved), [[2018-02-08-the-case-for-lifting-weights-a-declaration-for-the-youth]] (approved)
- [[2010-10-04-nutrition-pre-post-workout-guidelines-alan-aragon]] p 0.60 - like [[2017-12-23-bulking-on-a-budget]] (approved), [[2017-12-08-weight-gain-shake-i-drank-this-every-night-for-4-years]] (approved), [[2015-12-22-how-pitchers-can-gain-weight]] (approved)
- [[2010-05-26-our-stance-on-nutrition]] p 0.60 - like [[2017-12-23-bulking-on-a-budget]] (approved), [[2015-12-22-how-pitchers-can-gain-weight]] (approved), [[2017-12-08-weight-gain-shake-i-drank-this-every-night-for-4-years]] (approved)
- [[2010-04-06-pitching-decelerator-exercises]] p 0.64 - like [[2026-08-30-6-upper-body-lifts-for-pitchers]] (approved), [[2026-07-29-these-6-lifts-are-non-negotiable-for-pitchers]] (approved), [[2016-02-12-strength-training-for-baseball-and-isolation-exercises]] (approved)
- [[2010-09-03-the-inverted-w-and-pitching-mechanics]] p 0.68 - like [[2016-08-05-throw-harder-fastballs-by-improving-your-external-rotation]] (approved), [[2010-01-17-kinematic-analysis-wrist-to-elbow-relationship]] (approved), [[2018-05-28-reverse-throw-our-favorite-cues]] (approved)
- [[2010-08-26-supplements-for-baseball-part-two]] p 0.62 - like [[2009-10-13-basic-baseball-supplements]] (approved), [[2015-12-22-how-pitchers-can-gain-weight]] (approved), [[2017-12-23-bulking-on-a-budget]] (approved)
- [[2016-08-19-wrist-weight-drills]] p 0.71 - like [[2012-05-01-weighted-baseballs-wrist-weights-and-arm-injuries-q-a-with]] (approved), [[2012-07-30-supramaximal-training-with-weighted-baseballs]] (approved), [[2018-05-28-reverse-throw-our-favorite-cues]] (approved)
- [[2019-01-17-how-to-fix-a-pushing-arm-action-7-causes-and-solutions]] p 0.67 - like [[2026-06-09-throw-harder-by-fixing-your-pushy-arm-action]] (approved), [[2026-06-30-how-to-fix-your-pushy-arm-action-pushy-arm-action-part-two]] (approved), [[2018-02-21-throwing-concept-syncing-arms-into-the-plane-of-rotation]] (approved)
- [[2019-02-26-do-different-arm-slots-different-mechanics]] p 0.61 - like [[2026-06-23-the-plane-of-rotation-how-elite-throwers-use-it-to-throw]] (approved), [[2016-08-05-throw-harder-fastballs-by-improving-your-external-rotation]] (approved), [[2010-01-17-kinematic-analysis-wrist-to-elbow-relationship]] (approved)
- [[2018-05-10-problem-solving-your-lower-half-pitching-mechanics-to-throw]] p 0.66 - like [[2026-09-09-the-best-and-worst-lower-half-pitching-drills-ranked]] (approved), [[2019-02-11-the-drift-how-to-shift-your-weight-like-a-pro]] (approved), [[2018-02-02-roll-ins-variations]] (approved)
- [[2019-01-30-how-does-hip-anatomy-affect-your-mechanics]] p 0.69 - like [[2018-02-02-roll-ins-variations]] (approved), [[2010-03-07-mechanics-the-effects-of-loading-rate]] (approved), [[2016-08-05-throw-harder-fastballs-by-improving-your-external-rotation]] (approved)
- [[2019-03-13-is-playing-video-games-linked-to-arm-pain]] p 0.63 - like [[2010-03-07-mechanics-the-effects-of-loading-rate]] (approved), [[2012-05-01-weighted-baseballs-wrist-weights-and-arm-injuries-q-a-with]] (approved), [[2026-07-21-how-pros-use-pulse-and-what-it-means-for-the-rest-of]] (approved)
- [[2019-01-09-3-new-ways-to-use-j-bands-for-arm-health-and-velocity]] p 0.71 - like [[2019-01-13-upgrading-your-j-band-routine-part-1-overloaded-eccentrics]] (approved), [[2019-01-13-upgrading-your-j-band-routine-part-2a-patterning-front-leg]] (approved), [[2019-01-13-upgrading-your-j-band-routine-part-3-low-load-isometrics]] (approved)
- [[2019-01-23-the-3-types-of-muscling-up-and-how-it-s-hurting-your]] p 0.71 - like [[2019-01-28-the-3-types-of-muscling-up-how-it-s-hurting-your-pitching]] (approved), [[2019-02-11-the-drift-how-to-shift-your-weight-like-a-pro]] (approved), [[2026-08-28-6-drills-to-improve-your-posture-easy]] (approved)
- [[2019-03-07-how-to-sync-the-arm-into-the-plane-of-shoulder-rotation]] p 0.72 - like [[2018-02-21-throwing-concept-syncing-arms-into-the-plane-of-rotation]] (approved), [[2026-06-23-the-plane-of-rotation-how-elite-throwers-use-it-to-throw]] (approved), [[2026-06-09-throw-harder-by-fixing-your-pushy-arm-action]] (approved)
- [[2019-02-19-the-top-10-do-s-and-don-ts-for-optimal-recovery]] p 0.68 - like [[2009-12-15-overtraining-a-serious-problem]] (approved), [[2010-01-09-what-s-a-good-workout-kyle]] (approved), [[2010-02-08-proper-warmups-for-weight-training]] (approved)
- [[2018-12-28-rethinking-periodization-principles-of-energy-in-training]] p 0.70 - like [[2010-02-08-proper-warmups-for-weight-training]] (approved), [[2010-01-15-compound-movements-use-them]] (approved), [[2018-03-05-how-to-manage-in-season-lifting]] (approved)
- [[2019-02-20-all-about-tempo-is-it-a-key-to-unlocking-velocity]] p 0.61 - like [[2026-07-21-how-pros-use-pulse-and-what-it-means-for-the-rest-of]] (approved), [[2019-02-11-the-drift-how-to-shift-your-weight-like-a-pro]] (approved), [[2015-08-01-simple-hacks-to-throw-faster]] (approved)
- [[2018-02-28-the-top-12-reasons-for-velocity-fluctuations-part-1]] p 0.58 - like [[2026-07-21-how-pros-use-pulse-and-what-it-means-for-the-rest-of]] (approved), [[2017-01-19-should-i-play-summer-ball-weighing-the-pros-and-cons]] (rejected), [[2018-02-08-the-case-for-lifting-weights-a-declaration-for-the-youth]] (approved)

## Auto-rejected (0)

- none

