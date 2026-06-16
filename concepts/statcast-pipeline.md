---
type: concept
domain: data
created: '2026-06-15'
---
# Statcast pipeline

Pulling pitch/swing/batted-ball data from MLB Statcast (Baseball Savant) via
`pybaseball` (Python) or `baseballr` (R): playerid lookup → `statcast_search` →
clean → categorize (pitch group, outcome) → metric layer.

**The shared spine** under nearly every personal project:
[[og-pena]] (R/baseballr), [[swing-path]] (pybaseball, bat-tracking 2023+),
[[send-from-2b]] (5-yr league pull), [[pitch-design-colby]] (2025 movement),
[[dudz-batter-pitcher]] (2024 pitch CSV).

**Related:** [[xwoba]] · [[strike-zone-kde]] · [[swing-path-bat-tracking]]
**Astros analog:** GroundControl2 / `Astros.Pitches_View` (the internal equivalent —
see `rules/db-columns`). Porting any of these = swap Savant → GroundControl.
