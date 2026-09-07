---
{type: concept, domain: hitting, created: '2026-06-15'}
---
# Swing path / bat tracking

3D reconstruction of the bat through the zone from Statcast bat-tracking (2023+):
attack angle, swing length, tilt, attack direction. Arc built via **Hermite
interpolation** (back-foot start → contact point, sloped by tilt + attack angle,
rotated by direction); per-batter strike zone; coordinate origin at home-plate tip.

**Used in:** [[swing-path]] (the 790k-swing 3D visualizer + catcher-interference
origin).
**Related:** [[statcast-pipeline]] · [[strike-zone-kde]] · [[xwoba]] (contact outcomes).
**Astros tie-in:** bat-speed / attack-angle work — see `rules/bat-speed-canonical`
and the hitter tracker. The Hermite arc + per-batter zone are reusable for
swing-plane coaching overlays.

## From sources
- [[2026-08-21-swing-design-fixing-an-fsu-infielder-s-bat-path]] - Swing Design: Fixing an FSU Infielder's Bat Path
- [[2026-09-04-how-a-struggling-juco-player-worked-with-driveline-to-reach]] - How a struggling JUCO player worked with Driveline to reach his dream
