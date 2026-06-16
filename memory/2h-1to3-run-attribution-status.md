---
name: 2h-1to3-run-attribution-status
description: 2→H (Jun 5) + 1→3 (Jun 7) run-attribution fixes BOTH SHIPPED + BR tracker RE-PINNED + user-VERIFIED ("it all works") Jun 7 2026. Includes DSL-split re-pin hotfix (9416ce34). Commits + audit SQL here.
metadata: 
  node_type: memory
  type: project
  originSessionId: 7bc7f154-f673-4313-ac8e-4de955a6c252
---

# 2→H / 1→3 Run-Attribution Fix — status + 1→3 resume plan

## The bug class (both metrics)
Old success test = `ev.outs_after = ev.outs_before` ("no out on the play")
as a proxy for "did the runner advance/score." WRONG — an out can be made
on a DIFFERENT runner (batter stretching, backside runner) while our
runner still succeeded. Systematically UNDER-counts. Camden's 41-play AAX
video review confirmed ~30 were real successes scored as 0.

## 2→H — DONE (Jun 5 2026), all live surfaces
Replaced the proxy with run-attribution: runner scored iff a run crossed
for him — `>=1` run normally, `>=2` if a runner was already on 3B at the
pitch (his run crosses first). The out (anyone) is no longer consulted.

Canonical SQL swap (replaces the `AND ev.outs_after = ev.outs_before` line
in every 2→H `s2h_success` block, keeping the two runner_2b guard lines):
```
AND (CASE WHEN ev.top_of_inning = 1
          THEN ev.away_team_score_after - ev.away_team_score_before
          ELSE ev.home_team_score_after - ev.home_team_score_before END)
    >= CASE WHEN ev.runner_3b IS NOT NULL THEN 2 ELSE 1 END
```
Python (`_compute_2h` in br_data.py): new `_runs_on_play(row)` helper +
`need = 2 if pd.notna(row.get("runner_3b")) else 1`; success =
`dest == 0 and _runs_on_play(row) >= need`. Score cols + top_of_inning
added to its two feeding SELECTs.

Commits: `be50d464` + `ccb631e8` (feature/astros-intangibles:
br_tracker_data, br_kpi_data, br_data, snapshot_data, br_percentiles,
scripts/mlb_advances_leaderboard) · `856ba57c` (feature/pd-goals:
org_kpi_data) · `257fdfa0` (feature/promotion-models: org_kpi_data parity).
Verified: zero `runner_2b` 2→H blocks retain the outs proxy anywhere;
all .py parse. Arm Farm + Barrelsville don't compute 2→H (confirmed).

### 2→H work-laptop steps STILL PENDING (not yet live)
1. `git pull` intangibles + main (+ modeling).
2. **Re-pin BR tracker** (`intangibles/scripts/pin_br_tracker_seasons.py`) — app reads the pin, won't reflect fix until re-pinned.
3. Redeploy Intangibles (tracker/KPI/snapshot) + PD Engine (org KPI). Daily/postgame + leaderboard scripts just need the pull.
4. Validate with `c:\Users\Owner\Downloads\SQLQuery32.sql` (AAX 2→H decision harness, run-attribution) — rate should rise by the plays Camden confirmed.

## 1→3 — SHIPPED Jun 7 2026 (all live surfaces + modeling parity)

Audited first via `sql-queries/ft3-1to3-run-attribution-audit.sql` (AAX 2026):
old 51.9% vs new 52.0%, ONE disagreeing play — sched_id 1289944, 2026-05-23,
TB, runner 172155, RF single. **Zac pulled the SportyClips video and confirmed
it a REAL success**: runner scored from 1st (1→3 *and more*, all the way home);
the OUT was the **batter thrown out at third**, not the runner. Textbook bug.

I initially (wrongly) recorded "not worth shipping, only 0.1pp." Zac
overruled: **a wrong call on a coach-facing metric ships regardless of rate
movement.** Correct. SHIPPED the full swap (success branch + opportunity gate
+ Python `_compute_13`). The audit had already proven it safe: opp_delta = 0
(denominator unchanged), success_delta = +1 (exactly that play). See
[[feedback_ship_correctness_not_just_rate_movement]].

What shipped (the swap applied at every `AND ev.outs_after = ev.outs_before`
in a 1→3 block — runner_1b/:gc_id guarded — across all surfaces):
```
AND (CASE WHEN ev.top_of_inning = 1
          THEN ev.away_team_score_after - ev.away_team_score_before
          ELSE ev.home_team_score_after - ev.home_team_score_before END)
    >= 1 + CASE WHEN ev.runner_2b IS NOT NULL THEN 1 ELSE 0 END
         + CASE WHEN ev.runner_3b IS NOT NULL THEN 1 ELSE 0 END
```
Python `_compute_13` (br_data.py): `need_13 = 1 + (runner_2b present) +
(runner_3b present)`; `scored_home = dest==0 and _runs_on_play(row) >= need_13`
replaces the old `no_extra_outs`. Added `ev.runner_2b` to the two per-game
statline SELECTs (it was missing; runner_3b was already there). Reached-3rd
(`runner_3b_after = runner_1b`) branch LEFT UNCHANGED — always correct.

Commits: `96459d62` (feature/astros-intangibles: br_tracker_data, br_data,
br_kpi_data, snapshot_data, br_percentiles, scripts/mlb_advances_leaderboard) ·
`98f559d1` (feature/pd-goals: org_kpi_data + the audit SQL harness) ·
`dbd9c4fa` (feature/promotion-models: org_kpi_data parity). All 8 files
ast.parse clean; zero bare `outs_after = ev.outs_before` left in any 1→3 block.

### Work-laptop re-pin — DONE + VERIFIED Jun 7 2026
BR tracker re-pinned all years (2022–2025 in the full run; 2026 separately
after the DSL-split hotfix below). User confirmed "it all works." KPI weekly
verified live (it's live-DB, no pin). Remaining (if not already done): redeploy
Intangibles app + PD Engine so the deployed surfaces read the fresh pin / new
org-KPI code — tracker reads the pin (re-pinned ✓), KPI weekly + org KPI are
live-DB (reflect on redeploy/pull).

### DSL-split re-pin hotfix (Jun 7 2026, commit `9416ce34`)
The 2026 BR re-pin crashed in `_get_single_level_dsl_split_org_stats._safe_merge`
with `ValueError: merge on object and float64 columns for key 'org'`. Cause:
early-season DSL sub-split (DSL hasn't started in 2026) returns rows whose
`org` key is entirely null → float64 column → clashes with base's object `org`.
Pre-existing DSL-split bug, NOT from the 1→3/2→H change (different query path —
SB/CS merge). Fix: `_safe_merge` now treats an all-null `org` add-frame as empty
(NaN-fill value cols, skip merge — matches nothing anyway). Zero effect on
2022–2025 (full seasons have real DSL org data). After the fix, `--year 2026`
re-pinned clean.

### Mechanics (kept for reference) — the 1→3 swap detail
1→3 success has TWO branches:
- **(a) reached 3rd**: `WHEN ev.runner_3b_after = ev.runner_1b THEN 1` —
  POSITION-based, already CORRECT, immune to the bug. **LEAVE IT.**
- **(b) "scored all the way from 1st"**: gated by `outs_after = outs_before`
  — SAME bug. Rarer (scoring from 1st on a single needs error/deep gap).
  Fix = run-attribution generalized: a runner from 1st is behind anyone on
  2nd AND 3rd, so his run is `(#runners ahead)+1`:
  ```
  AND (CASE WHEN ev.top_of_inning = 1
            THEN ev.away_team_score_after - ev.away_team_score_before
            ELSE ev.home_team_score_after - ev.home_team_score_before END)
      >= (1 + CASE WHEN ev.runner_2b IS NOT NULL THEN 1 ELSE 0 END
            + CASE WHEN ev.runner_3b IS NOT NULL THEN 1 ELSE 0 END)
  ```
- Python `_compute_13` (br_data.py): reached-3rd return stays; scored-home
  branch swaps `no_extra_outs` for the generalized `_runs_on_play(row) >= need`
  (helper already exists in br_data.py from the 2→H fix).

### EXPLORATION needed BEFORE shipping 1→3 (user wants this)
- **1→3 OPPORTUNITY (denominator) also embeds `outs_after = outs_before`**
  in its "scored" sub-clause (e.g. br_tracker_data.py ~646-669). This makes
  the 1→3 rate read slightly HIGH (drops some thrown-out attempts from the
  denom). The two bugs push OPPOSITE directions: success-bug deflates,
  opp-bug inflates → they partially cancel. So **fix success first, MEASURE
  net with a 1→3 validation query, THEN decide whether to also clean the
  denom.** Don't fix both blind (can't attribute the movement).
- Build a 1→3 validation harness like SQLQuery32 (position-based: did runner
  reach 3rd; for scored-home use the run threshold). Validate vs Camden's
  1→3 video if he has it.

### Exact 1→3 block locations (the `runner_1b` / `:gc_id` blocks left untouched)
All in intangibles worktree unless noted:
- `br_tracker_data.py`: per-runner ft3 opp 646-669 + success 670-678; org ~1280s
- `br_kpi_data.py`: per-runner ~250-275; org ~820-840
- `br_data.py`: per-runner 264-277; org 595-611; variants ~1836-1852, ~1979-1995; python `_compute_13` ~1377
- `snapshot_data.py`: ~1214-1226
- `br_percentiles.py`: ~101-103
- `scripts/mlb_advances_leaderboard.py`: 46-47, 57-58
- pd-goals `org_kpi_data.py` (feature/pd-goals) + modeling copy: ~1727-1752

Grep to re-find: `outs_after = ev.outs_before` -B1 → every hit preceded by
`!= ev.runner_1b` or `!= :gc_id` is a 1→3 block.

### Reference
- Plan: `docs/plans/2026-06-05-2h-1to3-run-attribution-fix.md`
- 1→3 metric is SINGLE-ONLY by design (`CAST(ev.[1b] AS INT)=1`) — see
  `rules/reference-impl-index.md` "1→3 / 2→H" (Yamal case).
- After 1→3 ships: re-pin BR tracker + redeploy (same as 2→H).
