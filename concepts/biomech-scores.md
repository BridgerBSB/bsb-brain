---
type: reference
domain: pitching
source: Driveline Mechanical Composite Scores+ — Ray Cebulski report V2
created: '2026-06-15'
---
# Mechanical Composite Scores+ (pitching biomech report)

**Core idea:** Driveline's **Mechanical Composite Scores+** — a pitching-biomech
report that grades a thrower's mechanics independent of physical advantages and
attributes velocity to specific movements. Scores are **normalized to 100** (= avg,
SD-scaled); higher = better mechanics. The exemplar is pitcher **Ray Cebulski** (94.1
mph, V2 dated 2025-12-18).

**Framework — 5 component scores + Total:**
`Arm Action · Center of Gravity (CoG) · Block · Rotation · Posture` → weighted
**Total** (Cebulski: 106). Each feature reports **measured value, change, velocity
contribution (mph), and percentile**.

**Feature-level "velocity added" attribution** (the useful bit): mechanics are
decomposed into per-feature mph contributions, e.g. strengths — Shoulder IR Velo
(4764°/s, +1.12), Hip-Shoulder Sep (31°, +1.03), Torso Rotation Velo (+1.01), Max CoG
Velo (3.1 m/s, +0.74); weaknesses — Layback (177°, −0.81), Lead Knee Ext Velo at BR,
Torso Side Bend at MER. Net: throwing **4.1 mph higher than expected** for his build.

**How used:** a player-facing dev report that says *which mechanical features to train
for velo* and tracks them over time (impact-trend deltas vs prior assessment). The
hitting analog is [[hitting-biomechanics]]; the public pitch-quality analog is
[[stuff-plus-4s-pitching]].

## Links
- [[MOC-baseball-analytics]] · [[driveline]]
- [[hitting-biomechanics]] (hitting-side biomech report) · [[stuff-plus-4s-pitching]]
- [[pitch-design-logic]] · `rules/gcera-canonical` (Astros pitcher grades)
