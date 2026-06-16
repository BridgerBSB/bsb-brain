---
name: session-2026-05-21-evening-status
description: "Status at end of May 21 2026 evening session. Compliance regression fixed, L14 design decisions locked, ready to write design doc + ship L14 next session."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a9f009c-bd21-4ff4-91d7-4137388d2385
---

# May 21 2026 Evening Session — Where We Are

Read this first after /clear.

## What we did today (chronologically)

1. **Earlier session shipped Goal Compliance tab** to PD Engine (8x3 matrix + Individual Compliance table side-by-side). Commit `49e2880f` on `feature/pd-goals`.

2. **Built and shipped the Connect-scheduled compliance pin bundle** `pd-goals/connect_pins_compliance/`. Commit `5f50f2bd`. Mirrors the existing `connect_pins_defense/` template. Three files: `deploy.ps1`, `pin_compliance_2026.ipynb`, `.gitignore`. User deployed it from work laptop. First deploy failed with the standard `tracker-pin-connect-deploy.md` section 12.3.7 Linux Kerberos error (Connect can't do Windows Auth). User set `DB_USER` + `DB_PASS` in the Connect content's Vars tab and clicked Run Now — pin now writes successfully on schedule.

3. **Three UI fixes to Compliance tab** in commit `4a4b2cf7`:
   - Auto-load on tab open (removed the "Compute compliance" button)
   - Left matrix gets "Org Compliance" header
   - Right detail table renamed "Table" to "Individual Compliance"
   - Added dispatch by `parsed.goal_type` to call `get_catcher_stats` and `get_defense_stats` so NetK / React / PAA / EO / TopSpd / Arm goals would actually populate currents (they were rendering as light gray)

4. **REGRESSION caught and fixed** in commit `a7f3a263`. The goal_type dispatch in step 3 broke hitter K% / BB% / Damage / SwDec etc. because the parser hard-codes `k%` and `bb%` to `GoalType.PITCHING` regardless of who the player is. So hitter Walker Janek's "Increase BB% to 10% or more" goal routed to `get_pitcher_stats(janek_id)` and returned wrong data. Fix: mirror `1_PD_Goals.py::fetch_stats` exactly. Always fetch pitcher OR hitter primary by `player_type` from roster, then conditionally merge catcher / defense based on `position_category`. Never dispatch by parser's goal_type.

5. **TCP retry fix shipped to intangibles `database.py`** in commit `42665642` (work-laptop git pull needed). Same canonical pattern as Barrelsville from May 8. The fielding pin job was hitting TCP drops on the new 5-10 minute pooled-combo queries from May 21's pooled-pinning rollout. Retry was never ported to intangibles. Done now. After pull, can run `repair_tracker_pin.py --domain OF --year 2022 --per-level` to recover the sparse slices from the failed runs.

## Work-laptop steps still needed

In order:

a. `git pull` on the intangibles worktree. Pick up the TCP retry fix.
b. Decide if to let the in-progress fielding pin job finish, OR kill it and restart with the retry now in place. Either works. Run `repair_tracker_pin.py` after.
c. `git pull` on the pd-goals worktree.
d. Re-run `python pd-goals/scripts/pin_compliance.py --season 2026` so the persisted pin reflects the regression fix (hitter K% / BB% / etc. populating, catcher / defense metrics still populating from step 3).
e. Redeploy the PD Engine Streamlit app so users get the new Compliance UI (auto-load, renamed headers, dispatch fix).
f. Verify the Compliance tab in the app. Specifically check:
   - Tab auto-loads sub-second on open
   - Left matrix shows "Org Compliance" header
   - Right table shows "Individual Compliance" header
   - Catchers' NetK rows are colored Met / Close / Off (not light gray)
   - Hitters' BB% / K% rows are colored Met / Close / Off (not light gray)

## L14 design decisions locked

User's boss asked for "every goal should be viewable over the last 2 weeks" — carbon copy of the L2W pattern from KPI weekly individual reports.

Locked answers from the brainstorming chat tonight:

| Decision | Answer |
|---|---|
| Which surfaces get L14 | Player view bar charts. PD Flag Tracker fielding extension. NOT Compliance ("later"). NOT rolling chart ("we can already see existing one"). |
| Bar chart UI shape | Stacked Goal Period above, L14 below. Same width. Carbon copy of existing KPI weekly individual reports. |
| L14 window | Last 14 days from today |
| Cumulative SUM display in L14 column | Raw delta plus percent of remaining gap closed. Example: `+3.2 last 14d (+13.8% gap closed)`. User said this is fancy and to be careful. |
| Percentile pool for L14 values | Full season pool — same as everything else. Universal rule per user. Matches what individual OF and IF weekly reports do (`get_of_percentile_distributions` queries `YEAR(sv.sched_date) = :season`). |
| Sample size policy | Always show, no minimum. Inherits the existing "PD Goals has no player minimum" rule. |
| Tier 1 6-term gate | Inherited automatically via `fielding_base.filter_tier1()`. No separate decision. |

## L14 design doc NOT YET WRITTEN

Brainstorming session was paused before writing the design doc to `docs/plans/2026-05-22-pd-goals-l14-design.md`. Next session: write the design doc using the locked decisions, then ask user before implementing. Implementation plan would also include extending PD Flag Tracker (`drift_alert.py` family) to fielding metrics with the same 14-day window.

## Open bug to investigate next session

User reported BB% / K% bar charts in PD Goals player view show the bar but no percentile rank text. The compliance regression fix above addresses Compliance, but the bar chart percentile is a separate concern.

Bar chart calls `get_percentile_rank(metric, value, level, year, player_type='H', ...)`. For hitter BB% / K%, this routes through SplitsBat. Likely either:

1. `MLBAM.SplitsBat` 2026 data sparse for certain levels (FCL / DSL especially)
2. Routing or scaling bug in `_get_splitsbat_distribution`
3. `is_higher_better` direction wrong, so percentile computes but color is wrong

Investigation steps for next session:

1. After re-pin and redeploy, screenshot a specific hitter K% or BB% goal showing the broken percentile.
2. Run the SplitsBat distribution lookup standalone for that level / year / metric. See if dist is empty or populated.
3. If empty, fall back to prior-year SplitsBat (same pattern as wOBA weights — `lookup_year = season - 1` before May).
4. If populated, trace what `get_percentile_rank` actually returns.

## Pending from earlier in session

User mentioned a forgotten "#4" at the start of the evening but never got to it. Ask them what it was if it comes up again.

## Files touched this session

| File | Commit | What |
|---|---|---|
| `pd-goals/connect_pins_compliance/.gitignore` | `5f50f2bd` | Bundle setup |
| `pd-goals/connect_pins_compliance/deploy.ps1` | `5f50f2bd` | Bundle setup |
| `pd-goals/connect_pins_compliance/pin_compliance_2026.ipynb` | `5f50f2bd` | Bundle setup |
| `pd-goals/src/compliance.py` | `4a4b2cf7` | Initial dispatch by goal_type (broken) |
| `pd-goals/pages/1_PD_Goals.py` | `4a4b2cf7` | Auto-load + rename labels |
| `pd-goals/src/compliance.py` | `a7f3a263` | Regression fix — dispatch by player_type + position_category |
| `intangibles/src/database.py` (in `bsb-wt-intangibles`) | `42665642` | TCP retry pattern |
