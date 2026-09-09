---
{type: concept, domain: pitching, created: '2026-06-15'}
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

## From sources
- [[2026-07-28-what-s-the-next-sweeper]] - What's the Next Sweeper?
- [[2026-01-19-the-evolution-of-pitch-design-saberseminar-2025-r-d-podcast]] - The Evolution of Pitch Design | Saberseminar 2025 | R&D Podcast EP 111
- [[2026-06-09-throw-harder-by-fixing-your-pushy-arm-action]] - Throw Harder By Fixing Your Pushy Arm Action
- [[2026-06-18-6-8-hs-vanderbilt-commit-goes-for-96mph-in-pre-draft]] - 6'8" HS Vanderbilt Commit Goes For 96MPH In Pre Draft Bullpen | RJ Cope
- [[2026-07-16-36-year-old-pitching-coach-starts-a-pro-game]] - 36-Year-Old Pitching Coach Starts A Pro Game
- [[2026-08-02-he-just-skipped-college-to-become-a-pro-keaton-maiorana]] - He Just Skipped College To Become A Pro | Keaton Maiorana
- [[2026-09-06-complete-guide-to-mastering-the-changeup-grips-cues]] - Complete Guide To Mastering The Changeup [Grips, Cues, & Sequencing]
