---
tags:
  - baseball
  - reference
  - promotion-models
  - labels
created: '2026-06-29'
source: 'Zac (domain knowledge, 2026-06-29)'
---
# MiLB / MLB Promotion Calendar

Reference for **when promotions actually happen** — load-bearing for label maturity
and label *validity* in the [[promotion-release-models]] work. Parent: [[MOC-baseball-analytics]].

## Minor-league season END dates (vary BY LEVEL — 2026)
- **Triple-A (AAA):** regular season ends **Sun Sep 20, 2026**; playoffs + Triple-A Championship (Las Vegas) **Sep 27**.
- **Double-A (AA):** regular season ends **Sun Sep 13**.
- **High-A & Low-A (A+/A):** regular season ends **Sun Sep 6**.

=> Levels stop at **different times**. Late-season (Aug/Sep) snapshots have structurally
near-zero opportunity for an *intra-season level promotion* because the MiLB season is ending.

## MLB call-up timing (no hard deadline, but key dates)
- **Aug 31 — postseason eligibility cut-off:** must be in the org + on the 40-man by 11:59pm ET Aug 31 to be playoff-eligible.
- **Sep 1 — roster expansion:** active MLB rosters go **26 → 28**. THIS is the big prospect call-up / evaluation date.
- **~mid-August — rookie eligibility target:** exactly **45 days before the final game**. Calling a player up *after* this preserves rookie eligibility for next season **and** can earn an extra draft pick via the **Prospect Promotion Incentive (PPI)**.

## Why this matters for OUR models (Zac's note)
- **September shouldn't really "count"** for promotion labels — by then only a tiny number
  of guys can still get promoted (season ending + rosters mostly set). So the observed
  "**0.000 promotions in Sept-2025**" is **partly REAL structure**, not only forward-window
  censoring (see [[promotion-release-models]] — the right-censoring finding).
- **Modeling implications:**
  - Late-season snapshots (esp. Aug/Sep, level-dependent) likely need to be **down-weighted or excluded**.
  - The "matured label" cutoff should be **level-aware** (AAA window closes later than A/A+), **not a flat date**.
  - Reinforces the planned **level-banded / level-stratified** split rework rather than a single flat-temporal split.

Related: [[promotion-release-models]] · [[MOC-baseball-analytics]]
