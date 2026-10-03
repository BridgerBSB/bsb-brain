---
name: arm-farm-pitch-efficiency-shipped
description: "P/Out, P/PA, P/K, P/BB efficiency metrics added to Arm Farm affiliate tracker (Jun 23 2026)"
metadata: 
  node_type: memory
  type: project
  originSessionId: aca677f8-14ad-46d9-9cf3-db44531ca919
---

**Arm Farm affiliate tracker — 4 pitch-efficiency metrics SHIPPED Jun 23 2026** on
`feature/bullpen-reports` (worktree `C:\Users\Owner\bsb-wt-bullpen`). Zac ask
(outreach from coaches), P/K + P/BB definition from Sean Buchanan.

**Metrics (all `f1`, SELECTABLE in the Metric Columns picker but OFF by default —
opt-in like GB%/BABIP, NOT in `_DEFAULT_METRICS` per Zac Jun 23; available in every
grain — season leaderboard, org rankings, MoM/WoW/YoY trend pickers player+org, DSL split):**
- **P/Out** = total pitches / outs — lower=better
- **P/PA** = total pitches / BF — lower=better
- **P/K** = pitches in K-ending PAs / strikeouts — lower=better (quick putaways)
- **P/BB** = pitches in BB-ending PAs / walks — HIGHER=better (no cheap 4-pitch walks)

**Two commits:** `aa6bff96` (initial add, total-pitches numerators) → `7b194c25`
(fix per Sean: P/K & P/BB count ONLY pitches in the specific K/BB PAs — "avg pitches
per strikeout/walk PA", NOT total_pitches/K). Numerators `n_pitch_k_pa`/`n_pitch_bb_pa`
= `SUM(CASE WHEN ev.so/bb=1 THEN pv.ab_pitch_number)` on PA-final pitch (cur_event_id;
ab_pitch_number 1-indexed = PA pitch count). NO new SQL for P/Out/P/PA (counts already
summed); P/K/P/BB added 2 cols to 4 base PA queries (weekly inherits via
`_monthly_to_weekly_sql`). Shared helper `_add_pitch_efficiency_metrics()` +
`_merge_org_pa_metrics()` + page `_combine_multi_level` + org rollup all in lockstep;
carried through col_order + 7 stale-pin shims. Tooltips spell out the K/BB-PA defn.

**Reference doc:** graduated to `arm-farm.md` "Affiliate Tracker — Pitch-Efficiency
Metrics" section (BLOCKING note on the K/BB-PA numerator). See also
[[feedback_metric_specificity]] (FB%-incident class — disambiguate before coding).

**Standalone one-off query** (current HOU pitchers, all levels incl MLB, 2026):
`sql-queries/hou-current-pitchers-efficiency-2026.sql` — same defns, DECIMAL(5,1) =
1 decimal, gamelog-gold outs w/ PA fallback. Uncommitted (scratch).

**STATUS — UNTESTED on live DB. PENDING work-laptop:**
1. `git pull` bullpen-report (load-bearing — pins old cols otherwise)
2. re-pin: `python scripts/pin_tracker_seasons.py --year 2026` (or full ~2-3h) — IDENTICAL
   procedure to the Barrelsville hitting re-pin (mirror scripts; only diff = directory/branch +
   writes the pitcher pin). `connect_pins/deploy.ps1` redeploys the daily 2026 refresh job.
3. redeploy Arm Farm app. Pin + app deploy are ORDER-INDEPENDENT.
4. **Instant preview without re-pin:** any SUBSET level view (deselect a level) hits live DB → shows cols immediately.

**Open (ask Sean):** P/BB coloring direction under the new "pitches per walk PA" defn
— kept HIGHER=better (longer battles > cheap walks); one-line flip if he reads it
the other way. Not-yet-done: propagate to postgame / KPI weekly / org KPI ("everywhere
eventually" per Zac — those surfaces already carry the counts; same cheap add).
