---
type: project
created: '2026-06-27'
status: scoping
tags:
  - project
  - pitching
  - injury
  - workload
  - acwr
  - advisory-council
---
# 🩺 ACWR Workload Monitor — project scope + feasibility

**Status:** SCOPING (green-lit by Zac, Jun 27 2026). Council's unanimous #1 from
[[council-new-tools-ideation-2026-06-26]].

**Goal:** a per-pitcher rolling **Acute : Chronic Workload Ratio** watchlist for HOU
MiLB arms — flag who ramped load too fast (the published injury-risk signal) — and
**validate the thresholds against our OWN arms' IL history** before trusting it.

## The decision it serves
Activate / option / handle-with-care / back-off. Used by the **pitching coordinator +
athletic training**. The downside it guards against (a blown UCL) is the single most
expensive event in pitcher development.

## What ACWR is
- **Acute** = throwing load over the last ~7–9 days
- **Chronic** = rolling ~28-day average load
- **Ratio = acute ÷ chronic.** Risk climbs outside the **~0.8–1.3** band, especially
  spikes **> ~1.5** (ramped too fast). These are validated thresholds in the
  sports-science literature (ArmCare / JAT reviews — see [[context-library]]).

## The honest feasibility question (Zac's "limited workload data")
Two very different versions, only one of which we can build today:

| Version | Load measure | Can we build it? |
|---|---|---|
| **Count-based ACWR** | pitches (or outs) thrown per appearance per date | **Almost certainly YES** — we have per-pitch rows (`Astros.Pitches_View`) + dates (`Schedule_View`) + IL events (`SportsMed.DL_Stints`) to validate against. Most orgs can't validate on their own arms; we can. |
| **Effort/torque-based load** | per-pitch elbow torque / biomech | **NO at MiLB** — biomechanical/pose tracking is MLB-only (NULL for prospects, per `tracking-schema.md`). Defer. |

So "is it crackable with limited data?" → **yes, the count-based version is**, and that's
the version with the validated thresholds anyway. We do NOT need biomech to start.

## Feasibility gate (run FIRST, work laptop)
`sql-queries/acwr-feasibility-pitch-count-density.sql` answers: do we actually have
**per-appearance pitch counts at every level (incl. DSL/FCL)**, and how many arm IL
stints do we have to validate against? If DSL/FCL pitch-count density is too sparse,
the monitor ships AAA→A only at first.

## Build plan (phased)
1. **Feasibility diagnostic** (the SQL above) — confirm density + validation sample size.
2. **Phase 1 — count-based monitor (NO model):** rolling acute(7–9d)/chronic(28d) pitch
   load per HOU MiLB pitcher; flag ratio outside 0.8–1.3 / spikes >1.5. A query + a
   watchlist surface (Arm Farm tab or the existing injury tracker).
3. **Backtest the thresholds on our arms:** do our flagged spikes actually precede our
   `DL_Stints` arm injuries? This tells us if the generic thresholds hold for our system.
4. **Phase 2 (only if Phase 1 earns it):** gradient-boosted time-to-IL survival model
   (LightGBM `objective="cox"` or discrete-time hazard on player-weeks). Reuses the
   promotion-model rails ([[promotion-release-models]]).

## Caveats to bake in from day one (all 4 council lenses flagged these)
- **Healthy-worker / survivor bias** — a hurt arm stops throwing → low load looks
  "protective." Don't filter post-injury weeks out; use time-varying load.
- **ACWR is mathematically unstable when chronic load is low** (early season, just
  promoted, just off IL) — the ratio blows up for boring reasons. Use uncoupled
  acute & chronic terms, not just the raw ratio, in those windows.
- **Monitoring signal, NEVER a diagnosis.** Frame to ATs as "eyeball these arms," never
  "X% chance of injury." Player-welfare stakes → calibration over AUC, conservative framing.

## Data sources
- Load: `Astros.Pitches_View` (per-pitch) + `Schedule_View` (date/level) — count-based.
  (`MLBAM.Gamelog_Pitching.outs` is the alt load proxy per `ip-calculation.md`.)
- Injury labels/validation: `SportsMed.DL_Stints` (body part/diagnosis — gold) +
  `TR_HISTORY` (stint dates) — both already wired into the Injury Tracker.

Related: [[council-new-tools-ideation-2026-06-26]] · [[promotion-release-models]] ·
[[MOC-baseball-analytics]] · [[advisory-council]]
