# Parity Fix Plan — 2026-05-20

Executable plan for the **11 BLOCKING drift items** from:
- `docs/parity-audit-2026-05-20.md` (weekly KPI audit)
- `docs/parity-audit-snapshots-2026-05-20.md` (snapshot audit)

Grouped by worktree so each `git pull` covers one batch. Every fix is
surgical (no architecture changes, no schema changes, no pin re-runs).
Total ~50 LOC across 4 files in 3 worktrees.

**Order of operations across worktrees: doesn't matter. They are independent. Pick whichever you're on.**

---

## Worktree 1: `bsb-wt-bullpen` (Arm Farm) — branch `feature/bullpen-reports`

4 fixes. All in `bullpen-report/`.

### Fix B1 — Pitcher Whiff% `did_swing=1` gate (4 sites)

**Rule violated:** `gc2-metrics.md` BLOCKING #4 — `is_whiff MUST be gated by did_swing`.

**Files + lines to change:**

| File | Line | Current (BUG) | Fix |
|---|---|---|---|
| `bullpen-report/src/tracker_data.py` | ~574 (`_PITCH_LEVEL_QUERY`) | `SUM(CASE WHEN pv.pitch_result_id IN ({whiff_codes}) THEN 1 ELSE 0 END) AS n_whiffs` | Add `AND did_swing = 1` inside CASE WHEN (or use the recovery-gated swing expression matching the denominator) |
| `bullpen-report/src/tracker_data.py` | ~1927 (`_ORG_PITCH_QUERY`) | same shape | same fix |
| `bullpen-report/src/tracker_data.py` | ~2186 (`_ORG_MONTHLY_PITCH_QUERY`) | same shape | same fix |
| `bullpen-report/src/pitcher_kpi_data.py` | 503-504 (`_PLAYER_QUERY`) | `SUM(CASE WHEN pv.pitch_result_id IN (10,16,21,22,23,25) THEN 1 ELSE 0 END)` | same fix |

**Canonical reference (PDG, already correct):** `pd-goals/src/org_kpi_data.py:503` uses `SUM(CASE WHEN is_swing=1 AND is_whiff=1 ...)`.

**Verification:** Grep the 4 sites post-fix:
```bash
grep -n 'pitch_result_id IN.*whiff' bullpen-report/src/tracker_data.py bullpen-report/src/pitcher_kpi_data.py
```
Every match line should include `did_swing = 1` (or be inside an `is_swing=1`-gated outer context).

---

### Fix B2 — Pitcher KPI weekly gcERA `bip_rate` direct → derived + missing bunt filter

**File:** `bullpen-report/src/pitcher_kpi_data.py`

**Change 1 — line ~653 (`bip_rate` formula):**
- **Current**: `bip_rate = bip_count / bf`
- **Fix**: `bip_rate = max(1.0 - so_rate - bb_hbp_rate, 0)` (mirrors PDG `org_kpi_data.py:549` and tracker pattern)

**Change 2 — lines ~544-548 (`tracked_bip_count` SQL):**
- **Current**: `tracked_bip_count` SUM CASE without bunt filter
- **Fix**: Add `AND (h.hit_trajectory_id NOT IN (2,3,4) OR h.hit_trajectory_id IS NULL)` to the CASE WHEN condition. Mirror tracker `tracker_data.py:557-561`.

---

### Fix B3 — Pitcher KPI weekly EW% BIP codes

**File:** `bullpen-report/src/pitcher_kpi_data.py`
**Lines:** 518, 523

- **Current**: `pitch_result_id IN (12,13,14)`
- **Fix**: `pitch_result_id IN (12,13,14,18,19,20)`

Mirrors tracker `tracker_data.py:606,1948,2207` and PDG `org_kpi_data.py:397,402`.

---

### Fix B4 — Pitcher snapshot K%/BB% BF denominator IBB inclusion

**File:** `bullpen-report/scripts/pitcher_kpi_snapshot.py`
**Lines:** 253-277 (`_collect_pitcher_data` BF/K%/BB% block)

**Current** (per-pitcher computation, also mirrored in percentile-pool SQL at ~lines 359/362):
```python
pa_rows = df[df["cur_event_id"].notna() & (df["pa"] == 1)]   # excludes IBB
pa_total = len(pa_rows)
bb_no_ibb = bb - ibb
k_pct = so / pa_total
bb_pct = bb_no_ibb / pa_total
```

**Fix** (match tracker `tracker_data.py:690`):
```python
# BF includes IBB rows (pa=0 AND ibb=1 contribute to BF)
pa_total = int(df["pa"].fillna(0).sum() + df["ibb"].fillna(0).sum())
k_pct = so / pa_total if pa_total > 0 else 0.0
bb_pct = bb / pa_total if pa_total > 0 else 0.0   # bb includes IBB rows (no subtraction)
```

**Also fix the percentile-pool SQL** at lines ~359/362 — `bf = SUM(pa) + SUM(ibb)`, `bb` numerator = `SUM(CASE WHEN bb=1 ...)` (no `AND ibb=0` exclusion). Otherwise pool and per-player diverge.

---

### Worktree 1 commit/push

```powershell
cd C:\Users\Owner\bsb-wt-bullpen
git status
# 4 fixes can be 1 commit ("fix(pitcher): parity sweep — Whiff%, gcERA, EW%, snapshot K%/BB%")
# OR 4 separate commits, your call
git push origin feature/bullpen-reports
```

---

## Worktree 2: `bsb-wt-hitting` (Barrelsville) — branch `feature/barrelsville`

3 fixes. All in `barrelsville/scripts/kpi_snapshot_3.py`.

### Fix H1 — Hitter snapshot wOBA: per-PA-league weights (Salas fix)

**File:** `barrelsville/scripts/kpi_snapshot_3.py`
**Function:** `_collect_hitter_data`
**Buggy lines:** ~485 (`get_woba_weights(used_season, level_code=lv)` — level-AVG fallback path)

**Root cause:** Snapshot is re-fetching level-AVG weights when `pa_df` ALREADY HAS per-PA `w_bb / w_1b / w_2b / w_3b / w_hr` columns from `postgame_data.py:1862`'s `WOBA_WEIGHTS_JOIN`. Just use those columns.

**Fix approach (mirror `_compute_xwoba` per-PA pattern):**

Replace the per-level wOBA aggregation loop with a per-PA SUM:
```python
# Drop the per-level wOBA computation entirely.
# Compute wOBA via per-PA contribution from pa_df:
def _woba_numer(row):
    bb = row["bb"] - row["ibb"]
    return (
        row["w_bb"] * bb
        + row["w_hb"] * row["hbp"]
        + row["w_1b"] * row["h1b"]
        + row["w_2b"] * row["h2b"]
        + row["w_3b"] * row["h3b"]
        + row["w_hr"] * row["hr"]
    )

def _woba_denom(row):
    return row["ab"] + row["bb"] - row["ibb"] + row["sf"] + row["hbp"]

pa_df["_woba_numer"] = pa_df.apply(_woba_numer, axis=1)
pa_df["_woba_denom"] = pa_df.apply(_woba_denom, axis=1)
total_numer = pa_df["_woba_numer"].sum()
total_denom = pa_df["_woba_denom"].sum()
woba = total_numer / total_denom if total_denom > 0 else float("nan")
```

**Verify:** `pa_df.columns` should include `w_bb`, `w_1b`, `w_2b`, `w_3b`, `w_hr`, `w_hb` post-`_query_timeframe`. If not, check that `postgame_data.py::_query_timeframe` is exposing them on the returned dataframe (it does as of the May 18-19 xwOBA migration; reference `barrelsville/src/postgame_data.py:1862` for the JOIN).

---

### Fix H2 — Hitter snapshot wRC+ (auto-fixed by H1)

**File:** `barrelsville/scripts/kpi_snapshot_3.py`
**Lines:** ~507-511

**No code change needed** — once H1 lands, `_compute_wrc_plus` receives the canonical wOBA value and produces correct wRC+. **Verify post-H1** by computing wRC+ for a known multi-level batter (Salas, Holy) and comparing to tracker.

---

### Fix H3 — Hitter snapshot K%/BB% pool BB% IBB exclusion

**File:** `barrelsville/scripts/kpi_snapshot_3.py`
**Function:** `_get_hitter_pa_percentiles`
**Lines:** ~848-851

**Current** (BB numerator includes IBB):
```sql
100.0 * SUM(CASE WHEN ev.pa = 1 AND ev.bb = 1 THEN 1 ELSE 0 END)
       / NULLIF(SUM(CASE WHEN ev.pa = 1 THEN 1 ELSE 0 END), 0) AS bb_pct
```

**Fix** (strip IBB from numerator, matching per-player BB% at line 459):
```sql
100.0 * SUM(CASE WHEN ev.pa = 1 AND ev.bb = 1 AND CAST(ISNULL(ev.ibb, 0) AS int) = 0 THEN 1 ELSE 0 END)
       / NULLIF(SUM(CASE WHEN ev.pa = 1 THEN 1 ELSE 0 END), 0) AS bb_pct
```

Mirrors the pattern at line ~947-948 (pitcher pool) where IBB is correctly excluded from BB.

---

### Worktree 2 commit/push

```powershell
cd C:\Users\Owner\bsb-wt-hitting
git status
# H1+H2+H3 → 1 commit recommended ("fix(hitter-snapshot): per-PA wOBA weights + K%/BB% pool IBB")
git push origin feature/barrelsville
```

---

## Worktree 3: `bsb-wt-intangibles` (Intangibles) — branch `feature/astros-intangibles`

4 fixes. Touches 2 files: `br_kpi_data.py` + `snapshot_data.py`.

### Fix I1 — BR KPI weekly `_DATE_RANGE_PLAYER_QUERY` `leads` CTE missing PBL gates

**File:** `intangibles/src/br_kpi_data.py`
**Lines:** ~847-896 (`leads` CTE inside `_DATE_RANGE_PLAYER_QUERY`)

**Current** (no PV JOIN, no `pitch_id > 0`, no `ignore_flag = 0`):
```sql
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Schedule_View sv ON pbl.sched_id = sv.sched_id
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_2b ...
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_3b ...
WHERE ({level_filter})
  AND CAST(sv.sched_date AS DATE) BETWEEN :start_date AND :end_date
  AND {sched_filter}
GROUP BY pbl.groundcontrol_id
```

**Fix** (mirror tracker `br_tracker_data.py:507-525` + PDG `org_kpi_data.py:1880-1906`):
```sql
FROM Astros.Pitches_Baserunner_Leads pbl
JOIN Astros.Pitches_View pv
    ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_2b ...
LEFT JOIN Astros.Pitches_Baserunner_Leads nbo_3b ...
WHERE ({level_filter})
  AND CAST(sv.sched_date AS DATE) BETWEEN :start_date AND :end_date
  AND {sched_filter}
  AND pv.pitch_id > 0
  AND pbl.ignore_flag = 0
GROUP BY pbl.groundcontrol_id
```

---

### Fix I2 — BR KPI weekly chart `_ORG_DAILY_SB_CS_QUERY` CS canon

**File:** `intangibles/src/br_kpi_data.py`
**Lines:** 156, 168

**Current**:
- Line 156: `SUM(CASE WHEN ev.event_result_id IN (4, 5, 6) THEN 1 ELSE 0 END) AS cs`
- Line 168: `AND ev.event_result_id IN (42, 43, 44, 4, 5, 6)`

**Fix**:
- Line 156: `SUM(CASE WHEN ev.event_result_id IN (4, 5, 6, 7, 29, 30, 31) THEN 1 ELSE 0 END) AS cs`
- Line 168: `AND ev.event_result_id IN (42, 43, 44, 4, 5, 6, 7, 29, 30, 31)`

Matches `db-columns.md` SB/SBA Count Rule canon.

---

### Fix I3 — Intangibles BR snapshot `leads` CTE (same bug as I1 but worse)

**File:** `intangibles/src/snapshot_data.py`
**Lines:** ~1123-1148 (`_BR_SNAPSHOT_QUERY` leads CTE)

**Same fix as I1** — add `JOIN Astros.Pitches_View pv ON pbl.sched_id = pv.sched_id AND pbl.pitch_id = pv.pitch_id`, plus `AND pv.pitch_id > 0` and `AND pbl.ignore_flag = 0` in WHERE.

Already has floor 5.0 / ceiling 20.0 / 2B ceiling 25.0 (per `data-cleaning.md` §2) — leave those alone.

---

### Fix I4 — IF snapshot arm-strength floor 75 → 70

**File:** `intangibles/src/snapshot_data.py`
**Line:** 118 (`SNAPSHOT_CONFIGS["IF"]["arm_range"]`)

**Current**: `"arm_range": (75, 108),`
**Fix**: `"arm_range": (70, 108),`

Per `fielding.md` IF arm floor = 70 (OF = 75). Tracker `fielding_tracker_data.py` uses 70-108 for IF. One-line config fix.

---

### Worktree 3 commit/push

```powershell
cd C:\Users\Owner\bsb-wt-intangibles\astros-intangibles
git status
# I1+I2+I3+I4 → 1 commit or 2 (BR + IF) — your call
git push origin feature/astros-intangibles
```

---

## Verification After All Fixes Land

### Spot-check matrix
Pick 2-3 known players and confirm values match across surfaces:

| Test | Player | Surfaces to compare | Expected |
|---|---|---|---|
| Pitcher Whiff% | Any pitcher with non-zero IBB or bunts in 2026 | Arm Farm tracker ↔ Pitcher KPI weekly ↔ PDG | All 3 match within rounding |
| BR 1B PL | Any HOU MiLB baserunner | BR tracker ↔ BR KPI weekly ↔ BR snapshot ↔ PDG | All 4 match within rounding |
| Hitter wOBA (multi-level) | **Hector Salas** (Low A + A+ + AA) | Hitter snapshot ↔ Hitter KPI weekly ↔ tracker ↔ PDG ↔ GC2 | Snapshot now matches GC2 .364 |
| IF Arm P99 | Any HOU IF with borderline 70-74 mph throws | IF snapshot ↔ Fielding tracker ↔ IF KPI weekly ↔ PDG | All 4 match |
| BR CS (chart cumsum vs table) | Any HOU MiLB baserunner with pickoffs | BR KPI weekly chart line ↔ BR KPI weekly Season table | Now match (both use 7-code canon) |

### Pin re-runs (work laptop only)
**None required.** All fixes are SQL/Python logic changes; pinned DataFrames don't carry these intermediate computations. The next scheduled refresh will pick up the new code via Connect deploy.

**Exception**: if Worktree 1 (Arm Farm) changes propagate to the `connect_pins/` deploy bundle, redeploy that bundle so scheduled refresh uses the new code (per `tracker-parquet-pins.md §5.15`):
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "..."
.\connect_pins\deploy.ps1   # Arm Farm
```

Defense Matrix pin redeploy already in queue (separate work, not affected by this plan).

---

## What's Intentionally NOT In This Plan

These are real divergences but were classified as documented-intentional, scope-decision, or deferred. Don't touch without explicit user direction:

- **Pitcher snapshot K/BB ratio vs KPI K-BB% subtraction** — different metric labeled with similar header. Coach confusion risk; not a parity bug per se. (Action: maybe rename column for clarity.)
- **Pitcher snapshot global AL FIPConstant vs tracker per-level FIPConstant** — documented intentional in `pitcher_kpi_snapshot.py:55-58` for "internal percentile consistency."
- **Catcher Mid% framing bucket — per-catcher CS-only vs org NET formula** — needs user yes/no on which form is canonical before fixing.
- **Catcher multi-level percentile pooling not applied** — documented deferred in `multi-level-rollup.md`. Same fix pattern as OF/IF May 16 2026 commit `2d3d9da9`; ~6-8 hr.
- **Catcher snapshot omits Depth + AugPop2B entirely** — coverage gap, not parity bug.
- **Hitter wRC+ aggregation strategy** (PDG per-level-then-average vs tracker per-batter) — math equivalent when batter stays at one level; Salas-class concern conceptually but no evidence of meaningful drift today.
- **Per-PT pitcher Velo/IVB/HB/Spin/Usage org rollup** — no surface today; coverage gap not drift.
- **Arm Angle / Release Height / Release Side org rollup** — no surface today; coverage gap not drift.
- **Hitter AACon BIP whitelist in KPI weekly** (`hitter_kpi_data.py:1004`) — one-line follow-up per Apr 26 2026 standardization. Worth fixing but not BLOCKING.
- **Side observation H4** — hitter snapshot's PITCHER section uses inline level blacklist instead of `_build_level_filter`. Bypasses DSL/FCL `gc2_level_code` split. Separate bug class.

---

## Resume Checklist (after /clear)

When you come back to execute:

1. **Read this file first** (`docs/parity-fix-plan-2026-05-20.md`).
2. **Read the two audit docs** for context:
   - `docs/parity-audit-2026-05-20.md` (weekly KPI)
   - `docs/parity-audit-snapshots-2026-05-20.md` (snapshots)
3. **Pick a worktree**, follow that section's fixes in order.
4. **Commit + push** per worktree.
5. **Update this file** at the bottom as each worktree lands:

   ```
   ## Execution Log
   - 2026-MM-DD — Worktree 1 (Arm Farm) shipped — commits abc1234, def5678
   - 2026-MM-DD — Worktree 2 (Barrelsville) shipped — commit ...
   - 2026-MM-DD — Worktree 3 (Intangibles) shipped — commit ...
   ```

6. **Final verification** — run the spot-check matrix above.
7. **Once verified** — consider adding parity test cases (e.g., a script comparing the 5 test cases in the matrix above) so this drift doesn't sneak back in.

---

## Execution Log

- 2026-05-20 — **Worktree 1 (Arm Farm)** shipped — commit `e0065b95` on `feature/bullpen-reports`
  - B1 (Whiff% gate, 5 sites incl. one not in plan), B2 (gcERA bip_rate derived), B3 (EW% BIP codes), B4 (snapshot K%/BB% + pool IBB)
- 2026-05-20 — **Worktree 2 (Barrelsville)** shipped — commit `ffb2b448` on `feature/barrelsville`
  - H1 (snapshot wOBA per-PA weights + added w_hb to postgame_data.py pa_query), H2 (wRC+ auto-fix), H3 (pool BB% IBB exclude)
- 2026-05-20 — **Worktree 3 (Intangibles)** shipped — commit `cc166bd5` on `feature/astros-intangibles`
  - I1 (BR KPI player leads PBL gates), I2 (BR chart CS canon 7-code), I3 (BR snapshot leads PBL gates), I4 (IF snapshot arm floor 75→70)

### Notes from execution

- **B1 site count**: plan listed 3 tracker sites (574/1927/2186) + 1 KPI site. Found a 4th tracker site at line 3395 (per-pitcher monthly query, same bug class). Fixed all 5 sites for consistency. Used the recovery-aware swing expression (plan's option 2) for full denominator parity — `n_whiffs <= n_swings` guaranteed.
- **B2 Change 2**: plan claimed bunt filter missing on `tracked_bip_count` lines 544-548. Verified — lines 544-549 are `pbarrel_count` (no bunt filter, consistent with tracker `n_pbarrel`); `tracked_bip_count` (lines 550-554) already had the bunt filter at line 553. Change 2 was a no-op. Only Change 1 (bip_rate derived) needed.
- **H1 w_hb**: plan claimed `pa_df` already had `w_hb` column post-May-18-19 migration. Verified — only `w_bb/w_1b/w_2b/w_3b/w_hr` were in the pa_query SELECT. Added `woba.woba_hb AS w_hb` to `postgame_data.py::_query_timeframe` (one-line additive change, no breaking risk to other callers). Kept the legacy `get_woba_weights` fallback path as defensive guard.
- **No SQL ran on personal laptop** — all changes are syntactic/structural. Verification against GC2 (Salas case, pitcher Whiff% w/ IBB, etc.) deferred to work-laptop session with DB access. See spot-check matrix in the plan.

### Pin re-runs

None required for any of the 11 fixes per plan §"Pin re-runs". Connect-scheduled pin refreshes will pick up the new code automatically on next cycle. If Arm Farm `connect_pins/` deploy needs explicit redeploy, run `.\connect_pins\deploy.ps1` on work laptop (per `tracker-parquet-pins.md §5.15`).
