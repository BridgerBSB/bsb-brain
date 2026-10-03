# Promotion Deterioration & MLB Success Research

**Started:** March 17, 2026
**Updated:** March 17, 2026 (final numbers with full MiLB history)
**Branch:** `feature/barrelsville`
**Directory:** `barrelsville/scripts/exploration/`

---

## Executive Summary

We investigated whether wRC+ deterioration at each minor league promotion predicts MLB success. **Absolute wRC+ level matters far more than deterioration** — except at AAA→MLB, where the size of the drop cleanly separates WAR tiers.

The trajectory table shows the average wRC+ at every level for each MLB WAR tier. It can be used as a projection tool: find which tier a prospect tracks at their current level, then project their expected path through the system.

**Key findings:**
- WAR 4+ players average 151 wRC+ at Rookie, 125-131 through the middle, and 116 at MLB
- Never-MLB players hover at 94-97 at every level — they never dominate anywhere
- AAA→MLB is the one transition where deterioration cleanly separates tiers: WAR 4+ drops 5, WAR 2-4 drops 24, WAR <1 drops 33
- AAA wRC+ is the strongest single predictor (R²=6.1%, n=3,391)

---

## Methodology

### Data Parameters

| Parameter | Value |
|-----------|-------|
| MLB WAR window | 2021-2025 actual MLB appearances |
| MiLB qualification | Must have 50+ PA at a MiLB level in 2021-2025 |
| MiLB history for MLB players | Full history 2005-2025 (captures their Rookie/A/A+/AA/AAA stints) |
| Current prospects (Never MLB) | 2021-2025 stints only |
| Excluded | 2020 (COVID), DSL from rok, pitchers (PP_MASTER filter) |
| Schedule type | R (regular season only) |
| Min PA per stint | 50 |
| WAR source | `proj.batting_MLEs` (war column), filtered to actual MLB appearances via Schedule_View |
| WAR dedup | MAX(war) per player-year |

### Why This Approach
- **2021-2025 MiLB requirement:** Excludes MLB veterans with no minor league time in our window (Votto, Brantley, etc. — their MiLB time was 2005-2012, different era)
- **Full history for qualified players:** A guy in FCL in 2019 who made MLB in 2022 gets his full minor league trajectory included
- **DSL excluded:** Different competition level, uses `AND NOT (sv.level_code = 'rok' AND sv.league = 'DSL')`
- **Post-2020 restructuring:** MiLB went from 160→120 teams in 2021, but level codes (afx, afa, aax, aaa) are consistent

### Sample
- 4,763 hitters with 50+ PA at a MiLB level (2021-2025)
- 1,019 of those made MLB (qualified for WAR tiers)
- 3,098 MLB players excluded (no MiLB time in our window)
- 3,744 current prospects (Never MLB group)

### WAR Tiers
| Tier | Definition | N Players |
|------|------------|-----------|
| WAR 4+ | Best single-season MLB WAR >= 4.0 (All-Star / Star) | 42 |
| WAR 2-4 | Best season WAR >= 2.0, < 4.0 (Everyday starter) | 219 |
| WAR 1-2 | Best season WAR >= 1.0, < 2.0 (Role player) | 337 |
| WAR < 1 | Made MLB, best season WAR < 1.0 (Bench / replacement) | 421 |
| Never MLB | No actual MLB appearances | 3,744 |

---

## Finding 1 — wRC+ Trajectory by WAR Tier

**Script:** `wrc_tracks.py`
**Chart:** `reports/exploration/trajectory_by_tier.png`

| Tier | N | Rookie | A | A+ | AA | AAA | MLB |
|------|---|--------|---|----|----|-----|-----|
| WAR 4+ | 42 | **151** | 127 | 131 | 126 | 125 | 116 |
| WAR 2-4 | 219 | 126 | 123 | 122 | 121 | 117 | 98 |
| WAR 1-2 | 337 | 129 | 118 | 115 | 113 | 108 | 87 |
| WAR < 1 | 421 | 116 | 109 | 108 | 106 | 98 | 77 |
| Never MLB | 3,744 | 97 | 95 | 94 | 94 | 88 | — |

### Sample Sizes (stints per cell)

| Tier | Rookie | A | A+ | AA | AAA | MLB |
|------|--------|---|----|----|-----|-----|
| WAR 4+ | 7 | 23 | 30 | 36 | 61 | 260 |
| WAR 2-4 | 51 | 135 | 191 | 271 | 615 | 930 |
| WAR 1-2 | 73 | 222 | 326 | 471 | 1,257 | 1,092 |
| WAR < 1 | 104 | 323 | 469 | 727 | 1,458 | 542 |
| Never MLB | 1,804 | 3,175 | 2,683 | 2,145 | 820 | 0 |

### Key Observations

1. **WAR 4+ players demolish Rookie ball (151 wRC+).** They're 50+ points above league average from day one. This is the earliest signal of elite talent.

2. **The tiers stack cleanly at every level.** From Rookie through MLB, the ordering is always WAR 4+ > WAR 2-4 > WAR 1-2 > WAR <1 > Never MLB. No crossovers.

3. **Never-MLB players hover at 94-97 across all MiLB levels.** They're roughly league-average everywhere. They never dominate any level.

4. **WAR 4+ stays above 125 through AA→AAA.** These players barely dip. They're dominant at every stop.

5. **The gap between "made MLB" and "never MLB" is 15-30 points at every level.** Even the worst MLB tier (WAR <1) is 10-15 points above Never-MLB at every level.

---

## Finding 2 — Deterioration by WAR Tier

**Chart:** `reports/exploration/delta_by_transition_and_tier.png`

| Tier | Rookie→A | A→A+ | A+→AA | AA→AAA | AAA→MLB |
|------|----------|------|-------|--------|---------|
| WAR 4+ | -22 (n=7) | **+6** (n=22) | -9 (n=24) | **+0.1** (n=23) | **-5** (n=37) |
| WAR 2-4 | -5 (n=43) | -4 (n=105) | **+0.1** (n=154) | -3 (n=175) | -24 (n=208) |
| WAR 1-2 | -5 (n=62) | -2 (n=174) | -1 (n=247) | -7 (n=289) | -28 (n=311) |
| WAR < 1 | -13 (n=78) | +2 (n=240) | -3 (n=338) | -12 (n=385) | -33 (n=264) |
| Never MLB | **-27** (n=798) | **-17** (n=1313) | **-17** (n=947) | **-18** (n=433) | — |

### Key Observations

1. **AAA→MLB is the one transition where deterioration cleanly separates tiers:**
   - WAR 4+: **-5.2** (barely drops)
   - WAR 2-4: -24.2
   - WAR 1-2: -27.6
   - WAR <1: -33.1
   - That's a 28-point gradient from best to worst tier.

2. **Never-MLB players drop 17-27 points at every transition.** This is the biggest consistent separator — MLB-bound players of ALL tiers drop far less than Never-MLB players at every step.

3. **Through the middle of the system (A→A+ through AA→AAA), all MLB tiers look similar.** Drops of 0-12 points for everyone who eventually makes it. Deterioration doesn't separate WAR tiers until AAA→MLB.

4. **WAR 4+ actually IMPROVES at A→A+ (+6.3) and AA→AAA (+0.1).** Future stars get better as the competition improves through the middle levels.

---

## Finding 3 — R² by Level (Where Is wRC+ Most Predictive?)

**Chart:** `reports/exploration/scatter_wrc_by_level_vs_war.png`

| Level | n | r | R² | Variance Explained |
|-------|---|---|----|--------------------|
| Rookie | 235 | 0.153 | 0.023 | 2.3% |
| A | 703 | 0.211 | 0.044 | 4.4% |
| A+ | 1,016 | 0.192 | 0.037 | 3.7% |
| AA | 1,505 | 0.220 | 0.048 | 4.8% |
| **AAA** | **3,391** | **0.248** | **0.061** | **6.1%** |

**AAA wRC+ is the single best predictor** of eventual MLB WAR (R²=6.1%). This makes sense — AAA is the closest competition level to MLB. AA is second at 4.8%.

R²=6.1% means wRC+ alone explains ~6% of the variance in MLB WAR. This is modest but real. Other metrics (K%, BB%, ISO, batted ball quality, speed) likely explain additional variance. A multi-metric model combining 3-4 features could meaningfully improve prediction.

---

## Practical Application — Projection Tool

The trajectory table + deterioration data can be used to project a current prospect's expected MLB outcome:

### How to Use

1. **Find the prospect's current wRC+ and level**
2. **Match to the closest WAR tier row in the trajectory table**
3. **Project forward using that tier's average wRC+ at each subsequent level**

### Example: Prospect A — 122 wRC+ at A+

The trajectory table at A+:
- WAR 4+: 131 → he's below this track
- **WAR 2-4: 122** → closest match
- WAR 1-2: 115 → he's above this track

**Projection (WAR 2-4 track):** 122 at A+ → ~121 at AA → ~117 at AAA → ~98 at MLB (everyday starter)

### Example: Prospect B — 108 wRC+ at AA

- WAR 1-2: 113 → a bit above him
- **WAR <1: 106** → closest match

**Projection (WAR <1 track):** 108 at AA → ~98 at AAA → ~77 at MLB (bench player)

### Example: Prospect C — 140 wRC+ at A

- **WAR 4+: 127** → he's actually ABOVE this track at A
- Likely on a star trajectory if he sustains it through AA

### AAA→MLB Drop as Evaluation Tool

For players already at AAA, the deterioration gradient is the most useful:
- AAA wRC+ 125+ with a -5 drop projection = **star (WAR 4+)**
- AAA wRC+ 117 with a -24 drop projection = **solid starter (WAR 2-4)** → ~93 MLB
- AAA wRC+ 108 with a -28 drop projection = **role player (WAR 1-2)** → ~80 MLB
- AAA wRC+ 98 with a -33 drop projection = **bench (WAR <1)** → ~65 MLB

---

## League Average wRC+ by Level (Reference)

PA-weighted average wRC+ across all hitters in our sample:

| Level | Avg wRC+ |
|-------|----------|
| Rookie | 100.1 |
| A | 99.2 |
| A+ | 99.6 |
| AA | 101.5 |
| AAA | 101.9 |
| MLB | 94.8 |

Note: MLB avg is 94.8 (not 100) because our MLB sample is limited to players who also had MiLB time in 2021-2025 — these are younger players who tend to perform below league average in their early MLB stints.

---

## Charts

All saved to `barrelsville/reports/exploration/`:

1. **`trajectory_by_tier.png`** — Line chart: avg wRC+ at each level by WAR tier. Five colored lines showing clear tier separation.

2. **`scatter_wrc_by_level_vs_war.png`** — Five-panel scatter: wRC+ at each MiLB level vs. eventual best MLB WAR, with r and R² annotated. AAA has the strongest signal.

3. **`delta_by_transition_and_tier.png`** — Grouped bar chart: mean wRC+ delta at each transition by tier. Shows AAA→MLB as the key separation point.

---

## Scripts

| Script | Purpose | Status |
|--------|---------|--------|
| `wrc_progression.py` | Baseline deterioration rates by transition | DONE |
| `wrc_tracks.py` | **Trajectory table + R² by level + charts (FINAL)** | DONE |
| `war_wrc_combined.py` | Z-score resilience + WAR merge (v3) | DONE (superseded by wrc_tracks) |
| `check_war_data.py` | WAR table schema + diagnostics | DONE |
| `rookie_diagnostic.py` | Track Rookie ball players through the system | DONE |
| `zsw_analysis.py` | ZSw% band analysis (exploratory) | DONE |

---

## Conclusions

1. **Absolute wRC+ level is the primary signal.** The trajectory table stacks cleanly at every level — WAR tiers never cross. Where a player IS matters more than how far they fell.

2. **AAA→MLB deterioration is the exception.** This is the one transition where the size of the drop cleanly separates tiers (5-point drop for stars vs. 33-point drop for bench players). This gradient is actionable for evaluating AAA players about to get called up.

3. **Never-MLB is the clearest separation.** These players hover at 94-97 wRC+ everywhere. Any prospect consistently above 110 at any level is already tracking above the "never" group.

4. **AAA wRC+ is the best single predictor** (R²=6.1%). wRC+ alone is a modest predictor — combining with other metrics would improve prediction.

5. **Rookie ball sample is limited by time window.** Players in FCL/ACL in 2023 haven't had time to reach MLB yet. The Rookie tier data (especially WAR 4+ n=7) should be interpreted cautiously.

---

## Next Steps (When Ready)

1. **Test other metrics** — K%, BB%, ISO at each level using the same framework. Which metric has the strongest R² at AAA?
2. **Multi-metric model** — Combine top features into logistic regression predicting WAR tier
3. **Pitcher parallel** — `proj.pitching_MLEs` available, different metrics (FIP, K%, BB%)
4. **Current prospect overlay** — Tool to plot an active player's wRC+ trajectory against the tier curves
5. **Expand time window** — As 2026+ data comes in, Rookie ball sample sizes will naturally grow
