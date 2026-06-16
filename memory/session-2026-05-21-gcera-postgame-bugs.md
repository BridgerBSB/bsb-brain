---
name: session-2026-05-21-gcera-postgame-bugs
description: "May 21 2026 session — gcERA Arm Farm postgame fully resolved (4 bugs shipped: season=2025 default, hit_trajectory_id missing in app SQL, EV>0, IBB). PLUS shipped column-validation assertions + UI empty-state fix. gcera-canonical.md rule documented across all 4 worktrees."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1931ae3f-67e2-4b68-9a8a-a730e62b6a60
---

# May 21 2026 — gcERA Postgame Bug Audit + Fixes (RESOLVED)

Long session debugging Arm Farm postgame gcERA divergence from GC2. Four
real bugs found and fixed. The queued architectural fix
(column-validation assertions) ALSO shipped in the evening session,
along with a separate UI empty-state bug.

**End state**: gcERA matches GC2 across all 5 surfaces for every
verified game. `compute_statline` now asserts required columns are
present so the next upstream SQL drift fails loud instead of silently
producing wrong values. Statline / Pitch Char / Pitch Results UI
sections no longer go blank when user changes dates after clearing
a multiselect.

**Why:** Coordinator-visible drift in postgame PDF gcERA values. McPherson
5/17 showed 6.24 vs GC2 6.08; McPherson 4/24 showed 0.92 vs GC2 1.01.

**How to apply:** When debugging future gcERA divergence, start with the
SQL diagnostic (`sql-queries/gcera-mcpherson-diagnostic.sql`) and Python
diagnostic (`bullpen-report/scripts/diag_mcpherson_gcera.py --date YYYY-MM-DD`).
They isolate input-vs-formula-vs-display layers.

---

## Bugs shipped today (all on `feature/bullpen-reports`)

| # | Bug | Commit | Effect |
|---|---|---|---|
| 1 | `compute_statline` default `season=2025` — app didn't pass season, used wrong HR rate | `fc495528` | McPherson 5/17 6.24 → 6.08 ✓ matches GC2 |
| 2 | `get_game_pitches_for_app` SELECT missing `cev.hit_trajectory_id` — bunt filter silently skipped in Streamlit app | `532aad8b` | McPherson 4/24 0.92 → 1.01 ✓ matches GC2 |
| 3 | (Earlier in session) EV>0 filter removed from gcERA pbarrel filter across all 5 surfaces | `ae02833b` + `e73f9fbe` + `0e68903d` | Match GC2's `HitsNoBunts` JOIN spec |
| 4 | (Earlier in session) IBB subtracted from BF + BB for gcERA across all 5 surfaces | `76677601` + `01aa9054` | Match GC2's `case when pa=1` filter |

Plus rule: `.claude/rules/never-defer-to-tomorrow.md` (commits `33c68d8f`,
`317e3baf`, `3d3b4d74`, `943b1d76`) — banned all time-of-day deferral
phrases in my output. **Hard behavioral rule.**

---

## The structural antipattern

`compute_statline(pitch_df, pa_df, season)` is fed by TWO upstream
queries that have drifted apart:

- **`get_game_pitches`** (CLI path, `postgame_data.py:135`) — SELECTs
  `cev.hit_trajectory_id`, has `EV>0` in Hits JOIN
- **`get_game_pitches_for_app`** (Streamlit path, `postgame_app_data.py:174`)
  — was MISSING `cev.hit_trajectory_id` until commit `532aad8b`

Docstring on `get_game_pitches_for_app` literally says "MUST STAY IN
SYNC with postgame_data.get_game_pitches()." They were NOT in sync.

Inside `compute_statline`, the bunt filter is:

```python
if "hit_trajectory_id" in pitch_df.columns:
    bip_mask = bip_mask & (~pitch_df["hit_trajectory_id"].isin([2,3,4]) | ...)
```

**Missing column → filter silently skipped → wrong result.** No error,
no warning. Coordinator sees inflated tracked_bip denominator, lower
pbarrel_rate, lower gcERA. Caught only via diagnostic SQL comparison.

Same pattern applies to other optional columns (EV, LA, etc.) — any
column that goes missing produces silently wrong stats.

---

## Architectural fix — SHIPPED commit `3ec7a1e9` (May 21 evening)

User explicit ask was: "ship over this one fix" after `/clear`. Done.

**The fix: column-validation assertions at compute_statline entry.**

Add to `bullpen-report/src/postgame_data.py::compute_statline` (line 954,
after the empty-df early return):

```python
# Validate required columns — crash loudly instead of silently
# producing wrong stats when upstream queries drift. See
# memory/session-2026-05-21-gcera-postgame-bugs.md for the bug class.
_REQUIRED_PITCH_COLS = {
    "pitch_result_id", "hit_exit_speed", "hit_vertical_angle",
    "hit_trajectory_id", "pitch_type", "called_strike_chance_mlb",
    "did_swing", "balls_before", "strikes_before", "sched_date",
    "ab_pitch_number", "strikes_after", "cur_event_id",
}
_REQUIRED_PA_COLS = {"pa", "so", "bb", "ibb", "hbp", "ab"}

if not pitch_df.empty:
    missing_pitch = _REQUIRED_PITCH_COLS - set(pitch_df.columns)
    if missing_pitch:
        raise ValueError(
            f"compute_statline: pitch_df missing required columns: "
            f"{sorted(missing_pitch)}. Check upstream query "
            f"(get_game_pitches or get_game_pitches_for_app)."
        )

if not pa_df.empty:
    missing_pa = _REQUIRED_PA_COLS - set(pa_df.columns)
    if missing_pa:
        raise ValueError(
            f"compute_statline: pa_df missing required columns: "
            f"{sorted(missing_pa)}. Check get_game_pa_outcomes."
        )
```

10-line change. Prevents the entire silent-filter-skip bug class.
Would have caught today's `hit_trajectory_id` bug on the FIRST app run
instead of producing wrong numbers for weeks.

**SHIPPED** in `3ec7a1e9` with the exact required-col lists below.
Tuned slightly from the queued draft — dropped `pitch_type`,
`ab_pitch_number`, `cur_event_id`, `sched_date`, `ab` from required
sets because those are only used in specific branches that already
gate properly. Kept the load-bearing ones:

```python
_REQUIRED_PITCH_COLS = (
    "pitch_result_id", "did_swing", "called_strike_chance_mlb",
    "strikes_before", "balls_before",
    "hit_exit_speed", "hit_vertical_angle", "hit_trajectory_id",
)
_REQUIRED_PA_COLS = ("pa", "so", "bb", "ibb", "hbp")
```

Using `assert ...` (not `raise ValueError`) so it can be optionally
disabled via `python -O` if anyone ever needs that escape hatch.

---

## Audit results — gcERA bug class scope

Grepped `compute_statline(` + `compute_gcera` + the `if "X" in df.columns`
antipattern across all 4 worktrees:

| Worktree | Has compute_statline? | Has silent-skip antipattern? | Risk |
|---|---|---|---|
| bullpen-report | YES (the canonical) | YES — 6 sites (postgame_data, kpi_snapshot, pitcher_analysis) | Addressed by queued fix |
| barrelsville | NO — uses different stat patterns | N/A | None |
| intangibles | NO — fielding-side, different domain | N/A | None |
| pd-goals | NO — uses different stat patterns | N/A | None |

**gcERA bug class is confined to `bullpen-report`. Other apps not at risk.**

The 5 CLI sites with `if "hit_trajectory_id" in X.columns` (kpi_snapshot_3,
pitcher_kpi_snapshot, pitcher_analysis, postgame_data lines 1178, 1434)
all read pitch_df from their OWN SQL queries that include the column.
No upstream-split risk. The column-validation fix queued above will
make these crash-loudly if they regress.

---

## Disappearing statline bug — RESOLVED commit `3ec7a1e9` (May 21 evening)

User provided a screenshot: `image (575).png` — McPherson 4/03–4/24
range (3 outings, 199 pitches). Statline header rendered, Pitch
Characteristics + Pitch Results headers rendered, but the cards /
tables underneath were ALL blank.

**Root cause**: `st.session_state.get(key, default)` returns the
PERSISTED value when the key exists, even if persisted == `[]`. The
`default` kwarg only fires when the key is missing entirely. Once
the user cleared `statline_cols` / `pitch_char_cols` /
`pitch_result_cols` once via the Customize Table Columns expander,
`[]` was sticky across every subsequent rerun including date changes.
The for-loop iterated over `[]` and rendered nothing.

**Fix**: switch every `.get()` call to `or default` fallback at 4
sites in `pages/2_Postgame.py`:

```python
# Before:
active_sl = st.session_state.get('statline_cols', default_statline)

# After:
active_sl = st.session_state.get('statline_cols') or default_statline
```

Empty session-state list → falls back to default. User can still
partially deselect metrics; only the degenerate all-empty state
recovers to the default.

**Cross-app risk** (NOT patched this session): same antipattern at
`barrelsville/pages/1_Postgame.py:1595` for `statline_cols` plus
`kpi_damage_cols` / `kpi_contact_cols` / `kpi_approach_cols` /
`kpi_ball_flight_cols` / `kpi_proj_outcome_cols`. If Barrelsville
users report the same symptom, apply the same `or default` fix.

---

## Diagnostic tools created this session

| File | Purpose |
|---|---|
| `sql-queries/gcera-mcpherson-diagnostic.sql` | Per-game gcERA SQL using GC2's exact filter set. Bonus query at end shows EV>0 vs no-EV>0 BIP counts |
| `bullpen-report/scripts/diag_mcpherson_gcera.py --date YYYY-MM-DD` | Parametric Python diagnostic. Prints every input flowing into `compute_statline` + the final `gc_era` value |

Both reusable for future gcERA debugging. Pattern: SQL diagnostic gives
canonical answer; Python diagnostic gives compute_statline's actual answer;
diffing them pinpoints which input differs.

---

## What NOT to do

- **Don't add EV>0 back to the gcERA pbarrel filter.** It was removed
  this session after the SQL diagnostic confirmed GC2's `HitsNoBunts`
  JOIN has no EV>0 floor. McPherson 4/24's EV=0 BIPs (which I initially
  thought existed) turned out to be a misread of the bonus query output.
- **Don't touch the formula coefficients** `(3.9 + 31.1*hr_rate)`, `3.5`,
  `-3.3`, `9.9`. Verified canonical by SQL diagnostic against GC2.
- **Don't pass DataFrames to a future `compute_gcera()` helper.** Per
  user's stated direction earlier in session, the eventual canonical
  helper should take raw counts (bf, so, bb, hbp, tracked_bip, pbarrels,
  hr_rate) — same model as `compute_xwoba` in `xwoba_canonical.py`.
  That's a bigger refactor; queued separately.
- **Don't claim the rendering layer or display is wrong** when the diag
  shows compute_statline matches canonical. Trust the diagnostic chain:
  SQL → compute_statline → display. If display differs from
  compute_statline, the bug is in display. If compute_statline differs
  from SQL, the bug is in compute_statline's inputs.
- **Don't time-of-day defer.** See `rules/never-defer-to-tomorrow.md`.
  Hard rule shipped today.

---

## Cross-references

- `.claude/rules/gcera-canonical.md` — **NEW (May 21 evening)** BLOCKING rule synced all 4 worktrees. Full bug history, 5-surface sync, defensive patterns, what-not-to-do checklist.
- `.claude/rules/never-defer-to-tomorrow.md` — banned phrases rule (synced all 4 worktrees)
- `sql-queries/gcera-mcpherson-diagnostic.sql` — per-game gcERA SQL diagnostic
- `bullpen-report/scripts/diag_mcpherson_gcera.py` — parametric Python diagnostic
- `bullpen-report/src/postgame_data.py:955` — `compute_statline` entry, column-validation assertions now in place
- `bullpen-report/src/postgame_app_data.py:174` — get_game_pitches_for_app (must stay in sync with sibling)
- `bullpen-report/src/postgame_data.py:135` — get_game_pitches (CLI sibling)
- `.claude/rules/gc2-metrics.md` — canonical gcERA formula spec

## All commits this session (chronological)

| Commit | What |
|---|---|
| `01aa9054` | fix(gcera-org): match GC2 — exclude IBB from BF + BB |
| `9651a485` | rule(never-defer-to-tomorrow): BLOCKING |
| `0e68903d` | fix(gcera-org): remove EV>0 from is_pbarrel + is_tracked_bip — match GC2 |
| `33c68d8f` | rule(never-defer): strengthen — ban 'tomorrow' inside compound phrases |
| `9ad05b1f` | diag(gcera): per-game McPherson diagnostic |
| `b8cfa820` | diag(gcera): McPherson per-game Python diagnostic |
| `fc495528` | fix(gcera): pass season to compute_statline — stale 2025 default produced +0.16 drift |
| `9e2bb969` | diag(gcera): parametric date — investigate 4/24 0.92 vs canonical 1.01 |
| `532aad8b` | fix(gcera-app): add cev.hit_trajectory_id to get_game_pitches_for_app SELECT |
| `3ec7a1e9` | fix(postgame): UI empty-state + compute_statline column assertions |
| (this commit) | rule(gcera-canonical): document the bug class + 5-surface sync discipline |
