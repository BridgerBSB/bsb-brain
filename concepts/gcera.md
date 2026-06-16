---
type: concept
domain: pitching
source: astros-docs
---
gcERA — GroundControl R&D's best **predictive** estimate of a pitcher's future runs allowed, built from descriptive, in-season events: strikeouts, walks/HBP, and batted balls split by barrel quality.

## Model form
A linear run-value model summed over every plate appearance, divided by total batters faced (TBF) — an expected unearned-runs-per-9 figure:

`gcERA = (7.6·pBarrel + 3.5·nonPbarrel − 3.3·SO + 9.9·BB) / TBF`

## Run values (per PA result)
- Strikeout: **−3.3**
- Walk + HBP: **+9.9**
- non-pBarrel BBE: **+3.5**
- pBarrel BBE: **+7.6** *(shifts slightly by season's run environment)*

Worked example — Hunter Brown 9/2/2023 vs NYY (4.0 IP, 21 TBF, 5 K, 4 BB, 5 pBarrels): `(7.6·5 + 3.5·7 − 3.3·5 + 9.9·4)/21 = 4.08`.

## vs FIP / ERA
A **product-of-averages** run model, not a fielding-independent count (contrast [[fip]]). In the R&D test it out-correlates ERA, RA9, FIP, K-BB%, and the PRS scouting grades against next-season RA9 — the best forward predictor R&D has. Every surface must match GC2 within ±0.005 — see [[gcera-canonical]].

## Links
[[MOC-baseball-analytics]] · [[MOC-astros-engineering]] · [[gcera-canonical]] · [[gc2-metrics]] · [[gcperf]] · [[fip]] · [[era]] · [[stuff-plus-4s-pitching]] · [[barrel-pct]]
