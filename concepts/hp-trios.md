---
type: concept
domain: hitting
source: personal-bsbres/notebooks
created: '2026-06-15'
---
# HP Trios

**Core idea:** A "trio" is the **three force-plate jump tests** that, together,
snapshot an athlete's lower-body strength/power profile at a point in time:

1. **CMJ — Counter-Movement Jump** → `peak_power_[w]_mean_cmj` (watts).
   Reactive/elastic power with a dip-and-drive. The everyday athleticism marker;
   it's the one metric **every** youth age group has (11U up).
2. **SJ — Squat Jump** → `peak_power_[w]_mean_sj` (watts).
   Concentric-only power from a paused squat (no stretch-shortening cycle).
   CMJ−SJ ≈ how much an athlete gets from elastic/reactive ability.
3. **IMTP — Isometric Mid-Thigh Pull** → `net_peak_vertical_force_[n]_max_imtp`
   (newtons). Max isometric force — raw strength ceiling. Often missing for the
   younger groups (13U–15U lack it).

Together they separate **strength (IMTP)** from **explosive power (CMJ/SJ)** from
**elasticity (CMJ−SJ gap)** — the same force-plate vocabulary as
[[biomech-scores]].

## What a "trio" row is (in the youth data)

`hp_trios.R` → `complete_youth_trios.csv`: **one row per youth athlete at their
most recent test**, carrying the three jump metrics plus context:

```
athlete · coach · playing_level (age group) · height ·
relative_strength · body_weight · predicted_imtp ·
CMJ power · SJ power · IMTP force
```

It's the **cross-sectional "where does each kid stand right now"** snapshot —
the strength counterpart to [[gainers-analysis]]'s "how much did they improve."
Built by: pull youth cohort from `hp_tests`, keep `which.max(test_date)` per
athlete, gate to the current training block, merge the Notion roster
(coach/level/height). See [[youth-hp-analytics]] for the full pipeline.

## Why these three (and what they predict)

- **Power transfers to bat speed / EV / pitch velo.** The whole reason a hitting
  program tracks jump power is the chain *lower-body force → rotational power →
  barrel speed*. ~1 mph bat speed ≈ +1.2 mph EV (see [[big-3-hitting]]), and bat
  speed is downstream of the kind of explosive strength CMJ/SJ measure.
- **Relative strength** (force-to-bodyweight) matters more than raw force for
  youth, who are still adding bodyweight — hence tracking `body_weight_[lbs]`
  alongside, so a "gain" isn't just "got heavier."
- **`predicted_imtp`** lets younger kids who skipped the IMTP pull still get a
  modeled strength number for the trio.

## Cohort metric availability (don't rank across gaps)

| Age group | Has |
|---|---|
| 11U / 12U | CMJ only |
| 13U / 14U / 15U | everything except IMTP |
| 16U / 18U | all three (+ pitch/bat speed) |

This drives how [[gainers-analysis]] ranks: within each group, only on the metrics
that group actually has.

## Astros analog

There's no direct trio metric in the Astros pipeline yet — but the **Force Deck /
twitch / eccentric** development goals catalogued as *unmeasurable* in
`rules/pd-goals-unmeasurable` are exactly this CMJ/SJ/IMTP family. If those force-
plate feeds ever land in GroundControl, the "trio snapshot + gainer deltas" pattern
ports straight over.

## Links
- [[MOC-baseball-analytics]]
- [[youth-hp-analytics]] · [[gainers-analysis]]
- [[biomech-scores]] · [[hitting-biomechanics]] · [[big-3-hitting]]
- [[swing-path-bat-tracking]] · [[statcast-pipeline]]
- Astros tie-in: `rules/pd-goals-unmeasurable` (Force-Deck goals)
