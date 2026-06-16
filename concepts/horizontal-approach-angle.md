---
type: concept
domain: pitching
source: fangraphs-chamberlain-2023
created: '2026-06-16'
---
# Horizontal Approach Angle (HAA)

The lateral analog of [[vertical-approach-angle]] — the angle a pitch crosses
home plate *horizontally*. Source: **Alex Chamberlain**, *A Visual Primer on
HAA*, FanGraphs, **Nov 22 2023**. ([[alex-chamberlain]])

## Geometry / formula
From Statcast release kinematics (at y=50 ft):
```
vy_f = -sqrt(vy0² − 2·ay·(y0 − yf))      # yf = plate, 17/12 ft
t    = (vy_f − vy0) / ay
vx_f = vx0 + ax·t
HAA  = -arctan(vx_f / vy_f) · 180/π
```
Inputs `vx0, ax, vy0, ay` come straight from the [[statcast-pipeline]] pitch row.

## HAAAA — the adjustment that makes it useful
Raw HAA correlates with (and is "obscured by") four things, so Chamberlain
builds **HAA Above Average (HAAAA)**, adjusting for: **pitch type · horizontal
location · pitcher handedness · horizontal release point.** HAAAA = the *excess*
angle beyond what those predict.

## The core insight (memorize this)
> **"VAA(AA) is a swinging-strike weapon, HAA(AA) is a called-strike weapon."**

HAA earns **called strikes** (pitches that break back over the edge — "strikes
that become balls"), not whiffs. It predicts called-strikes + contact quality,
**not** swinging strikes.

## Why HAA is location-dependent (and VAA isn't)
A hitter's swing has a **much wider lateral margin of error than vertical**. A
horizontal miss of inches still makes (degraded) contact; a vertical miss whiffs/
fouls. So **elite [[vertical-approach-angle|VAAAA]] plays up even in bad locations;
elite HAAAA does not** — it only works at the zone *edges*. "Stuff can't exist
without command" for HAA: it needs location, but in return it **broadens the
target / buys wiggle room** (a −0.6° HAAAA four-seamer a ball off the inside edge
draws swings like an average pitch on the black).

## Magnitudes are small
Runniest/sweepiest pitches rarely exceed **±0.5° excess HAA**, vs VAA's flattest/
steepest reaching **1.5–2.0°**. So HAAAA is a finer lever.

## Same raw HAA, different HAAAA (why raw misleads)
2023 four-seamer league avg HAA = 1.3°. All five below sit at 1.3° raw:
Morton −0.49 · Gausman −0.21 · Cole −0.09 · Javier +0.15 · Cease +0.31 (HAAAA).

## The lever — release point on the rubber (Pfaadt case study)
Brent Strom moved Brandon Pfaadt from the 3B side → 1B side of the rubber,
changing his **horizontal release point** → sharper sweeper HAA **without changing
pitch shape**. *"Before, he was throwing balls out of his hand which became
strikes. Now we have pitches that are strikes that can become balls."* Unlike
vertical release (needs a mechanical change), HAA is tunable by literally sliding
on the rubber — a cheap, real [[pitch-design-logic]] intervention.

## Caveats
Binning/averaging is primitive vs regression/ML; breaking-ball taxonomy
(sweeper/slider/slurve) muddies the adjustment; never a sole metric. Prior work:
**Ethan Moore** modeled large run-prevention effects for HAA (cautioned it may
shrink under adjustment).

## Links / brain ties
[[MOC-baseball-analytics]] · [[vertical-approach-angle]] (the sibling) ·
[[pitch-design-logic]] (release-point lever, VAA/arm action) ·
[[stuff-plus-4s-pitching]] (maps to **Slot+** = release + **Spot+** = command) ·
[[statcast-pipeline]] · [[alex-chamberlain]] · Astros: strike-zone edges →
`[[visual-standards]]`, pitch shape/command → `[[arm-farm]]`.
