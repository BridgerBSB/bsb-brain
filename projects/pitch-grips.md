---
type: project
status: active
created: 2026-09-25
tags: [pitching, pitch-design, grips, app]
---
# Pitch Grip Database

**What it is:** a grip library for coaches (grips, movement by arm slot, bullpen targets, cues), built at `C:\Users\Owner\pitch-grips` (remote `BridgerBSB/pitch-grips`). Personal first, then ported into Astro World as the internal grip database.

**Reference it's modeled on:** https://rasmussenbaseball.com/tools/pitch-grips (Nate Rasmussen). Catalogued 2026-09-25:
- 104 grips in 13 shape groups (slider, slurve, sweeper, gyro, "death ball"/vertical slider, curveball, changeup, splitter, forkball, cutter, sinker, four-seam, modifiers).
- Filters: shape, bias fit (pronator / supinator / neutral), movement goal (velo, sweep, depth, tighter, command), hand size. RHP/LHP toggle mirrors zones.
- Each card: looping grip mp4, seams/fingers, perks, cues, tradeoffs, source link; a circular induced-break plot with three arm-slot zones (3/4 solid, low and high approximate); bullpen targets (velo off FB, spin eff, tilt, gyro, seam reliance, "working when").
- Named MLB entries show a Savant 2026 profile (velo, spin, spin vs movement axis, seam shift) instead of generic targets.

**How ours differs:** our own write-ups and estimates (no copied text or media); cues/drills come from this vault's approved Driveline/Tread notes via `scripts/sync_kb.py` (read-only). Grip clips = files dropped in `public/grips/` named by grip id.

**Not built yet:** named-MLB/Savant entries; coach editing in-app (comes with the Astro World port); per-pitcher "who throws this".

Links: [[MOC-pitching]] [[MOC-training-knowledge]]
