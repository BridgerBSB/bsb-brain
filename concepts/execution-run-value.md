---
{type: concept, domain: pitching, source: personal-bsbres/statistical-models}
---
# Execution Run Value (IPV Lost)

The run value a pitcher **loses by missing his intended target**. Each pitch has an intended location; this model estimates how the pitch *would have performed* if thrown to that intended location, and takes the difference. The "command-miss" sibling in Driveline's intrinsic family — distinct from [[independent-location-value]] (which values only the *final* location) and a component of [[independent-pitch-value]].

## Definition / formula
```
ExecutionRV (IPV Lost) = ActualPitchLocationRV − IntendedLocationRV
```
It reuses the [[independent-location-value]] tree-based event models to value **both** the actual pitch and the would-be intended pitch, then differences them. Because it's the gap between two location-RV outputs, it measures *command execution* rather than pitch quality.

## ILV vs Execution RV — the key distinction (two examples)
- **Example 1:** Pitcher intends middle-middle on a hitter's count and misses by an inch. → **Good Execution RV** (he located his target) but **poor ILV** (the pitch is likely getting hit hard). "Pitchers with good misses" minimize the runs they give when they miss.
- **Example 2:** Same intent, but the miss hits the batter. → **Poor ILV** (located in the batter's box) *and* **poor Execution RV** (the miss was way off target).

## Same-year correlations
Like ILV, Execution RV depends on putting the ball in the right places, so it shares ILV's correlates — **but with stronger swing/whiff signal**: **Whiff rate r = 0.30, Swing rate r = 0.40.** Throwing to the intended location with fewer misses translates to generating swings and whiffs.

## Predictiveness & reliability
- **Self-stickiness:** Execution RV → next-year Execution RV is **r ≈ 0.7 at 1000 pitches** (a sticky stat).
- **Best non-self predictor: walk rate.** In *early* samples, **IPV Lost beats walk rate at predicting next-year walk rate up to ~600 pitches** (at 500 pitches: IPV Lost → next-yr BB% r = 0.46 vs BB% → next-yr BB% r = 0.42). Once the sample grows, use walk rate.
- For Swing/Whiff/K rate next year, the actual stat beats Execution RV — like ILV, it's best at predicting *itself* into the future, while [[independent-pitch-value]] is the one to use for predicting *different* season stats.
- **Reliability:** ~**300-325 pitches** overall (matches IPV's pace). By pitch type, most take **150-300 pitches**, and **offspeed (CH, FS) converges fastest** of all pitch types.
- **Best-season examples:** Ranger Suárez cutter **−0.23 runs**; Clay Holmes (same pitch flagged across IPV/ILV) **−0.15 runs**.

Output is run value per pitch (a.k.a. *IPV Lost*); together with [[independent-stuff-value]] and [[independent-location-value]] it rounds out the per-pitch IPV breakdown. Gradient-boosted trees ([[lightgbm-baseball-modeling]]).

## Links
- [[MOC-baseball-analytics]]
- [[independent-pitch-value]], [[independent-stuff-value]], [[independent-location-value]], [[independent-value-family]]
- [[stuff-plus-4s-pitching]], [[lightgbm-baseball-modeling]], [[re24-run-expectancy]], [[xwoba]]

## From sources
- [[2026-01-19-the-evolution-of-pitch-design-saberseminar-2025-r-d-podcast]] - The Evolution of Pitch Design | Saberseminar 2025 | R&D Podcast EP 111
