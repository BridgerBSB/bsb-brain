---
type: concept
domain: pitching
created: '2026-06-15'
---
# Pitch design logic

Recommending new/improved pitches from a pitcher's traits: blend an ML run-value
model (RV/100 from velo + IVB + HB) with decision-tree baseball rules — VAA from
release height, pronator/supinator typing from spin efficiency, seam-shifted-wake
detection (60–87% spin eff), command guardrails, and movement-matched MLB comps.

**Used in:** [[pitch-design-colby]] (Streamlit recommender) — author [[colby-morris]].
**Related:** [[stuff-plus-4s-pitching]] (the evaluation side) · [[statcast-pipeline]].
**Astros tie-in:** Arm Farm pitch shape/usage (`rules/arm-farm`, `rules/pd-goals`
compound-shape goals). The decision logic could become an internal pitch-design
module on GroundControl movement data.
