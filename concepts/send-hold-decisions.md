---
type: concept
domain: baserunning
created: '2026-06-15'
---
# Send / hold decisions

Should the third-base coach send the runner? Model P(safe) from runner speed,
fielder arm, distance, and ball trajectory, then weigh it against the **xRV** of
the resulting base-out states ([[re24-run-expectancy]]). Classify each call:
Optimal Send / Lucky Send / Bad Send / Smart Hold / Missed Opportunity — separating
skill from luck.

**Used in:** [[send-from-2b]] (2nd→home, 2021–2025, LightGBM).
**Related:** [[lightgbm-baseball-modeling]] · [[re24-run-expectancy]] · [[statcast-pipeline]].
**Astros tie-in:** the [[2h-1to3-run-attribution-status|2→H / 1→3 run-attribution]]
work — same advancement events. Natural Astros build: institutional send/hold
thresholds on GroundControl tracking + an in-game P(success)+xRV tool.
