---
name: contact-quality-metrics-status
description: "Affiliate tracker new metrics AA 4-16% / Squared-Up% / Smash Factor — spec done, implementation pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: b6d673e7-93fb-4459-a36d-e27297c5aa88
---

**Contact-quality tracker metrics — INDIVIDUAL SURFACE SHIPPED, UNTESTED ON DB
(Jun 22 2026, `feature/barrelsville`, commit `37aad980`).** 3 GENERAL metrics on the
Barrelsville affiliate tracker. **Full spec (formulas LOCKED Jun 22):
`barrelsville/docs/plans/2026-06-21-contact-quality-metrics-design.md`.**

**Jun 22 build (Zac gave canonical formula sources, said "go"):**
- **Smash formula CORRECTED** — Driveline `(PitchSpeed+EV)/(PitchSpeed+BatSpeed)`
  (= `1+(EV-BS)/(PS+BS)`), NOT the original `EV/BatSpeed`. Needs pitch speed.
- **Square% CONFIRMED** — `EV/(1.23*BatSpeed + 0.2116*PitchSpeed) >= 0.80`.
- Shipped to **Individual leaderboard: season + monthly + weekly + multi-level combine**
  + cross-level org rollup (guarded) + both stale-pin shims. AA4-16% derives from
  existing aa_con rows (no new SQL); Smash+Square% = new per-BBE 3-way join
  (`_SMASH_SQ_QUERY` / `_MONTHLY_SMASH_SQ_QUERY`, weekly auto via
  `_monthly_to_weekly_sql`): Pitches_View.release_speed + Hits.hit_exit_speed + SCV
  bat speed; BBE eligibility matches avg_ev (BIP codes, EV 0-125, per-batter P95
  misread, bunts excluded). PitchSpeed col = `pv.release_speed` (NOT pitch_speed).
  Compiles + imports clean (py only, no DB).
- **Org Trends MoM/WoW full-parity fix** (commit `13d6ee54`): discovered org monthly/weekly
  computed pitch+PA only → SIX metrics blank there (bat_speed, xwOBA, gcOBA + my 3), a
  pre-existing gap affecting bat_speed too, NOT just mine. Fix = `_attach_org_trend_extra_metrics()`
  reuses the tested season org supplementary queries with the time bucket passed through the
  `{team_select_*}` placeholders; wired into `_get_single_level_org_monthly` + `_org_weekly`.
  Verified bucket col in SELECT+GROUP BY for all 6 reused queries.
- **Org Rankings (season) NOW WIRED too** (commit `89e93552`): `_ORG_AA_QUERY` +
  `_ORG_SMASH_SQ_QUERY` (org-attributed per game via mlbam.teams/top_of_inning) into
  BOTH `_get_single_level_org_stats` + `_get_single_level_dsl_split_org_stats`;
  cross-level via `aggregate_org_across_levels`; org shim updated. So Individual
  (season/monthly/weekly/multi-level) + Org Rankings (season) ALL covered.
- **NOT done / next:** (1) **re-pin** required before deployed app shows real values
  (stale-pin shims keep old pins NaN-safe); (2) **NO live-DB test yet** — compiles +
  imports clean, but no value computed against real data; (3) **Topped% + Flare-Burner%**
  next pass via full Statcast 6-bucket EV x LA grid; (4) **rate-tune** gates/thresholds;
  (5) org monthly/weekly intentionally untouched (pitch+PA only there, like bat_speed);
  (6) bat-speed used raw (no per-player p10 clean) per spec — possible refinement.

Decisions locked (Zac questionnaire):
- **AA 4-16%** (`aa_ideal_pct`, "AA4-16%"): `100 × count(aa_con ∈ [4,16]) / count(all
  swings with measured aa_con)`. Source = `aa_con` only. pct1, colored higher-better,
  gate ~20 sw, count-derived rollup. **UNAMBIGUOUS — ready to build.**
- **Smash** (`smash`, "Smash"): mean of per-BBE `hit_exit_speed / (|batv_con|×0.681818)`,
  BBE-only. f2, colored higher-better, gate ~20 BBE, BBE-weighted rollup. **READY.**
- **Square%** (`squared_up_pct`, "Square%"): **computed** Statcast/FanGraphs (NOT GC2
  id 984 = MLB-only). Per BBE. `potential_EV = 1.23×batspeed + k×pitchspeed` (k≈0.2116,
  confirm vs 0.23), squared-up if ratio ≥0.80. pct1, colored higher-better, count-derived.
  **ONE OPEN ITEM: confirm exact k + threshold** (FanGraphs glossary / Baseball Savant
  bat-tracking links in the spec doc). No prior squared-up formula doc existed anywhere
  (searched vault+repos) — only GC2 id 984 ref in the biomech schema doc.

Build = `tracker-new-metric` 7-place checklist in `barrelsville/src/tracker_data.py`
+ `pages/2_Affiliate_Tracker.py` (mirror aa_con/hba_con). EV source = `Astros.Hits.hit_exit_speed`
(matches tracker avg_ev); pitch speed = `Pitches_View.plate_speed` (verify col). Re-pin after.
Zac: follow up + rate-tune these next session; wanted it documented before /clear. Three-surface
parity = tracker-only to start.
