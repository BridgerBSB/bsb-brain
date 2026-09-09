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
- [[2025-12-09-why-swinging-faster-doesnt-mean-missing-more-how-the-blue]] - Why Swinging Faster Doesn’t Mean Missing More | How The Blue Jays Fixed Their Hitters
- [[2026-01-14-can-an-mlb-all-star-break-our-smash-bat-ev-record-ft-brent]] - Can an MLB All-Star Break Our Smash Bat EV Record? (ft. Brent Rooker)
- [[2026-03-14-cleaner-swing-path-more-barrels-vs-velo-lefties-swing]] - Cleaner Swing Path = More Barrels vs Velo & Lefties (Swing Design ft. ABL MVP)
- [[2026-03-21-stop-getting-greedy-on-your-pitch-swing-design]] - Stop Getting Greedy on Your Pitch (Swing Design)
- [[2026-03-28-his-bat-path-is-costing-him]] - His bat path is costing him
- [[2026-05-16-cues-drills-to-let-your-body-deliver-the-barrel-to-the-ball]] - Cues & Drills to Let Your Body Deliver the Barrel to the Ball
- [[2026-06-15-the-royals-just-recalled-this-28-year-old-slugger-john-rave]] - The Royals Just Recalled This 28-Year-Old Slugger | John Rave Cage Session
- [[2026-08-15-why-1-mph-is-worth-millions-to-mlb-players]] - Why 1 MPH Is Worth Millions to MLB Players
