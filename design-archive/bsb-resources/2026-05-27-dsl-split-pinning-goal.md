# DSL Split Pinning — All 5 Affiliate Trackers (Next-Session Goal)

**Status:** Goal spec for autonomous execution next session.
**Owner:** Zac Bridger (PD analyst)
**Created:** 2026-05-27
**Branches:** `feature/barrelsville`, `feature/bullpen-reports`, `feature/astros-intangibles`
**Coordinates with:** DuckDB A/B pilot (`intangibles/docs/plans/2026-05-27-duckdb-fielding-pilot-goal.md`) — see "Coordination" section below.

---

## THE FULL PROMPT (hand this to next-session Claude)

### GOAL — THE FINAL OUTCOME

Make the DSL Sub-Team Split toggle on the Org Rankings tab **pin-backed** (instant load) instead of live-DB (5-15 sec cold load) on all 5 affiliate trackers: Barrelsville (hitter), Arm Farm (pitcher), BR, Fielding (OF + IF), Catcher. The non-split path is already pinned today via the canonical multi-level pattern — extend that pattern to cover the split path. After this lands, the DSL toggle (Off / Split) becomes a pin lookup either way, no live DB on toggle flip.

### CONTEXT

**The user-visible problem.** This session (2026-05-27) shipped DSL split feature to all 5 trackers and the user verified `"literally everything you added is amazing"` — EXCEPT one complaint: `"its just slow when we split dsl cuz we have to pin"`. Toggle Off = instant (existing pin). Toggle Split = 5-15s live DB hit because the split path was designed as live-DB v1.

**Why this is the right level of optimization.** The user said: `"this kinda needs to be there before you use DuckDB to make our processes quicker"`. The DuckDB A/B pilot (separate goal doc) speeds up the *existing pin compute path*. This goal adds a *new pin key* for a path that currently has no pin coverage. Different optimizations, additive, both compatible.

**Current state per tracker (live-DB only):**

| Tracker | Worktree | Split helper (live-DB) | Pin CLI |
|---|---|---|---|
| Barrelsville | `bsb-wt-hitting/barrelsville` | `src/tracker_data.py::get_org_rankings_dsl_split` | `scripts/pin_tracker_seasons.py` |
| Arm Farm | `bsb-wt-bullpen/bullpen-report` | `src/tracker_data.py::get_org_rankings_dsl_split` | `scripts/pin_tracker_seasons.py` |
| BR | `bsb-wt-intangibles/astros-intangibles/intangibles` | `src/br_tracker_data.py::get_org_rankings_dsl_split` | `scripts/pin_br_tracker_seasons.py` |
| Fielding (OF+IF) | same | `src/fielding_tracker_data.py::get_org_rankings_dsl_split` | `scripts/pin_fielding_tracker_seasons.py` |
| Catcher | same | `src/catching_tracker_data.py::get_org_rankings_dsl_split` | `scripts/pin_catching_tracker_seasons.py` |

**Each tracker's existing non-split pin pattern is the reference impl** (look at `get_org_rankings` in the same tracker's `tracker_data.py`):
- `_try_pin_bundle(season, PREFIX_ORGS, level_codes, sched_types, ha_split, hand_split=hand_split)` at function top
- Pin gate matches canonical 7-level set + default sched_types + valid H/A + valid hand split
- Falls through to live DB on pin miss
- Pin CLI loops `for ha in HA_SPLITS_ALL: for hand in HAND_SPLITS_ALL: write bundle_key(PREFIX_ORGS, ha, hand)`

**Stack:** Python 3.11 (Connect runtime) / 3.13 (work laptop), joblib pins on Posit Connect, SQL Server via FreeTDS/pyodbc, Streamlit. NO new dependencies needed.

**Working dirs:**
- `C:\Users\Owner\bsb-wt-hitting\barrelsville\` (`feature/barrelsville`)
- `C:\Users\Owner\bsb-wt-bullpen\bullpen-report\` (`feature/bullpen-reports`)
- `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles\` (`feature/astros-intangibles`)

**Audience:** Zac (PD analyst). Coaches see "DSL split toggle is fast now." Internal change.

---

### SUCCESS CRITERIA — ALL MUST BE TRUE

1. **All 5 trackers have `PREFIX_ORGS_DSL_SPLIT` constant** in their `tracker_pins.py` + key count in bundle docstring bumped by `+9` per (H/A × Hand) per year.
2. **All 5 `get_org_rankings_dsl_split` functions check pin first.** `_try_pin_bundle` call inserted at function top BEFORE the live-DB compute. Gate identical to the non-split path: canonical 7-level set, default `sched_types=("R",)`, valid `ha_split ∈ {None, 0, 1}`, valid `hand_split ∈ {None, "all", "l", "r"}`. Pin miss falls through to current live-DB compute (no behavior change).
3. **All 5 pin CLIs write the split bundle.** In `_run_df_queries_for_combo(year, ha, hand)`, add one `get_org_rankings_dsl_split(_all_level_codes(), year, sched_types=["R"], ha_split=ha, hand_split=hand)` call writing to `bundle_key(PREFIX_ORGS_DSL_SPLIT, ha, hand)`. Same shape as the existing `PREFIX_ORGS` write block.
4. **All historical years re-pinned on work laptop.** PINNED_YEARS = 2022/2023/2024/2025 (verify per tracker's `pins_config.py`). After re-pin, every pin bundle has 9 new `orgs_dsl_split_*` keys (3 H/A × 3 Hand) per year.
5. **App load time on Toggle Split ≤ 1 sec** (warm, post-redeploy) for any canonical 7-level pin combo. Currently 5-15 sec live-DB. Measured by manual stopwatch on a real Connect-deployed test.
6. **Existing non-split path unchanged.** Toggle Off behaves byte-identically to today. Existing pin keys (`orgs_all_all`, etc.) untouched.
7. **Parity verification.** For one known multi-level HOU pick, the split path returns the same numeric values pin vs live-DB. Tolerance: ±0.001 on rates / floats. Use a diagnostic script per tracker (one-off, doesn't ship — just verify before shipping).
8. **Deploy succeeds + no Connect schedule disruption.** Each tracker's Connect-scheduled pin job (existing `connect_pins*/deploy.ps1`) runs the new CLI version on its 6-hour cadence and completes without nbconvert/rsconnect timeout. Pin storage grows by ~10-15% (9 new keys per bundle, smaller-than-orgs-bundles each because DSL has fewer rows).

---

### OPERATING RULES — NON-NEGOTIABLE

1. **NO HALLUCINATIONS** — read each tracker's existing non-split pin code path before mirroring. Don't assume function names or argument shapes — every tracker has subtle variations. `git grep` is your friend.
2. **MINIMAL DIFFS** — exactly 3 file edits per tracker (5 trackers × 3 files = 15 total edits). Don't refactor unrelated code.
3. **ONE atomic commit per tracker** — clear commit message naming the tracker + the bundle key added. 5 commits total across 3 branches.
4. **VERIFY before claiming done** — for each tracker, after the code lands, run a one-off parity check (pin vs live-DB on a known HOU multi-level scope). User has DB access for this; agent can write the diag script but Zac runs it.
5. **STAY IN BOUNDS** — DO NOT touch:
   - The DSL split feature itself (already shipped this session — works correctly, just slow)
   - Non-split pin path (already fast)
   - DuckDB pilot files (`intangibles/src/fielding_duckdb.py`, the DuckDB goal doc)
   - Other tabs (Leaderboard, Trends, Level Pools, Trend Visuals) — already pinned via `batters_*`
   - Per-batter percentile coloring path (separate concern, deferred to a future Phase 2)
6. **PRESERVE bailout** — if anything goes wrong on a tracker, revert that tracker's commit cleanly. Each tracker is independent.
7. **HANDLE Catcher v1 limitation** — Catcher's `get_org_rankings_dsl_split` has documented limitations (per-catcher merged metrics inherit parent org). Pinning doesn't fix that — but it should pin the SAME data the live-DB path returns. Don't try to fix Catcher's split-fidelity in this commit; out of scope.
8. **COORDINATION with DuckDB pilot** — Fielding tracker has the DuckDB pilot in flight. Either:
   - (a) Ship Fielding's DSL split pinning FIRST (small additive change, lands cleanly before pilot)
   - (b) Ship Fielding's DSL split pinning LAST after pilot lands and merge the changes
   - **Recommendation: (a). Order = Barrelsville (pilot) → Arm Farm → BR → Catcher → Fielding (just before DuckDB pilot ships).**

---

### IMPLEMENTATION PLAN — per tracker (mechanical mirror)

Walk this checklist per tracker. Estimated time: ~30 min code + ~15-45 min per-year re-pin × N years per tracker. Total session: ~3-4 hours of code + ~hours of pin time on work laptop.

#### 1. `tracker_pins.py` (or shared module for Intangibles)

Add prefix constant near the other `PREFIX_*` lines:

```python
PREFIX_ORGS_DSL_SPLIT = "orgs_dsl_split"
```

Update the bundle schema docstring (top of file) to mention the new key. Bump documented key count if explicit (e.g., "63 keys" → "72 keys" for Arm Farm).

Add to `ALL_DF_PREFIXES` tuple (if it exists in that tracker — check).

#### 2. `*_tracker_data.py` — pin-first gate in `get_org_rankings_dsl_split`

Find the existing function. Insert at the top of the body, BEFORE the live-DB compute:

```python
def get_org_rankings_dsl_split(
    level_codes: List[str],
    season: int,
    sched_types: Optional[List[str]] = None,
    ha_split: Optional[int] = None,
    hand_split: Optional[str] = None,
) -> pd.DataFrame:
    """..."""
    if sched_types is None:
        sched_types = ["R"]
    # Pin-first gate: canonical 7-level set + default sched_types + valid H/A + valid hand
    if _TRACKER_PINS_AVAILABLE:
        _pinned = _try_pin_bundle(
            season, PREFIX_ORGS_DSL_SPLIT, level_codes, sched_types, ha_split,
            hand_split=hand_split,
        )
        if _pinned is not None:
            return _pinned
    # ... existing live-DB compute below unchanged ...
```

Use the existing `_try_pin_bundle` helper in the same file. Don't reinvent the gate logic.

#### 3. `pin_*_tracker_seasons.py` — write the new bundle key

In `_run_df_queries_for_combo(year, ha, hand)`, add ONE call alongside the existing org-rankings write:

```python
from src.<tracker>_data import (
    ...,
    get_org_rankings_dsl_split,  # NEW
)
from src.tracker_pins import (
    ...,
    PREFIX_ORGS_DSL_SPLIT,  # NEW
    bundle_key,
)

# In _run_df_queries_for_combo, after the existing org write:
print(f"  [{year}/{ha_label}/{hand}] orgs_dsl_split ...", end=" ", flush=True)
t0 = time.time()
df_dsl_split = get_org_rankings_dsl_split(
    _all_level_codes(), year,
    sched_types=["R"], ha_split=ha, hand_split=hand,
)
out[bundle_key(PREFIX_ORGS_DSL_SPLIT, ha, hand)] = df_dsl_split
print(f"{len(df_dsl_split)} rows ({time.time() - t0:.1f}s)")
```

Indent / wrap to match the existing style in that file.

#### 4. Compile + commit + push per tracker

```powershell
python -m py_compile <tracker_pins.py> <tracker_data.py> <pin_cli.py>
cd <worktree>
git add <files>
git commit -m "feat(tracker): pin DSL split path on Org Rankings (<tracker>)"
git push origin <branch>
```

#### 5. Re-pin on work laptop

For each tracker, on work laptop:

```powershell
cd <worktree_on_work_laptop>
git pull
$env:CONNECT_API_KEY = "<key>"
python <tracker>/scripts/pin_<tracker>_tracker_seasons.py
```

`--ha-incremental` likely won't help since the new key is missing in every existing combo — needs a full rebuild. Budget ~hours per (tracker, year). Run overnight or in parallel windows.

After each tracker's re-pin completes: redeploy that tracker's app via rsconnect.

---

### VERIFICATION — per tracker, before claiming done

Write a one-off diagnostic script (one per tracker, doesn't ship — `scripts/diag_dsl_split_pin_parity.py`):

```python
"""Compare DSL split path: pin vs live-DB for a known scope."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.<tracker>_data import get_org_rankings_dsl_split, _ALL_LEVEL_CODES
import src.<tracker>_data as _td

# Live DB (bypass pin)
_orig = _td._TRACKER_PINS_AVAILABLE
_td._TRACKER_PINS_AVAILABLE = False
df_live = get_org_rankings_dsl_split(_ALL_LEVEL_CODES, 2025, sched_types=["R"], ha_split=None, hand_split="all")

# Pin
_td._TRACKER_PINS_AVAILABLE = _orig
df_pin = get_org_rankings_dsl_split(_ALL_LEVEL_CODES, 2025, sched_types=["R"], ha_split=None, hand_split="all")

# Compare
print(f"Live: {len(df_live)} rows, cols={len(df_live.columns)}")
print(f"Pin:  {len(df_pin)} rows, cols={len(df_pin.columns)}")
# Assert numeric cols match within ±0.001
import pandas as pd
import numpy as np
numeric_cols = df_live.select_dtypes(include=[np.number]).columns
merged = df_live.merge(df_pin, on=["org"], suffixes=("_live", "_pin"))
for col in numeric_cols:
    if col in ["pa", "ab", "n_pitches"]:  # counts — exact match expected
        diff = (merged[f"{col}_live"] - merged[f"{col}_pin"]).abs().max()
    else:
        diff = (merged[f"{col}_live"] - merged[f"{col}_pin"]).abs().max()
    print(f"  {col}: max diff = {diff:.6f}")
```

Run on work laptop (DB access required). Diagnostic prints differences; expect zero except for floating-point noise.

---

### COORDINATION with DuckDB pilot (Intangibles Fielding only)

Same `intangibles/` worktree, but different files:
- DuckDB pilot edits: `intangibles/src/fielding_duckdb.py` (new), `intangibles/scripts/pin_fielding_tracker_seasons.py` (dual-write parquet pins for DuckDB)
- DSL split pinning edits: `intangibles/src/tracker_pins.py`, `intangibles/src/fielding_tracker_data.py`, `intangibles/scripts/pin_fielding_tracker_seasons.py`

**Overlap = `pin_fielding_tracker_seasons.py`.** Both goals add code to this file. Merge conflict risk if both ship in parallel.

**Resolution:** Ship Fielding's DSL split pinning **FIRST**, then DuckDB pilot rebases on top. Smaller change goes first. Order:

1. Barrelsville DSL split pin
2. Arm Farm DSL split pin
3. BR DSL split pin
4. Catcher DSL split pin
5. **Fielding DSL split pin (lands before DuckDB pilot picks back up)**
6. DuckDB pilot resumes against current Fielding state

If DuckDB pilot already shipped before this work starts — rebase this goal's Fielding commit on top, resolve `pin_fielding_tracker_seasons.py` conflict (additive only, both adding new write blocks).

---

### BAILOUT

If anything breaks on any single tracker:

```powershell
cd <worktree>
git revert <commit_sha>
git push origin <branch>
```

Each tracker is independent. A bad commit on Fielding doesn't affect Barrelsville etc. Pin storage stays as-is (new keys missing, app falls through to live DB exactly like today).

Worst case: revert all 5 commits, no state pollution.

---

### ROLLOUT ORDER (locked)

1. **Barrelsville** (pilot — smallest scope, fastest iteration)
2. **Arm Farm** (different worktree, no conflict risk)
3. **BR** (Intangibles worktree starts)
4. **Catcher** (Intangibles)
5. **Fielding (OF+IF)** (Intangibles, last to minimize DuckDB conflict)

Per tracker: code commit → push → user re-pins on work laptop → user redeploys app → verify toggle is instant.

---

### FILES TO READ FIRST (next-session Claude — start here)

Required reading before writing any code:

1. **`bsb-resources/docs/plans/2026-05-27-tracker-polish-handoff.md`** — what already shipped this session (the live-DB DSL split feature)
2. **`bsb-resources/.claude/rules/.graduation-log.md`** — 2026-05-27 entries for context
3. **`bsb-wt-hitting/barrelsville/src/tracker_data.py`** — read `get_org_rankings` (pinned, line ~2865) and `get_org_rankings_dsl_split` (live-DB, line ~2916) side by side
4. **`bsb-wt-hitting/barrelsville/scripts/pin_tracker_seasons.py`** — `_run_df_queries_for_combo` is the canonical write loop to extend
5. **`bsb-wt-hitting/barrelsville/src/tracker_pins.py`** — `PREFIX_*` constants + `_try_pin_bundle` + `bundle_key` helpers
6. **`bsb-resources/.claude/rules/tracker-parquet-pins.md`** — the canonical pin pattern doc (especially "Replication playbook")
7. **`bsb-resources/.claude/rules/tracker-new-metric-checklist.md`** — 7-place checklist that applies here too

Per-tracker target reads:

- Arm Farm: `bsb-wt-bullpen/bullpen-report/src/{tracker_data.py, tracker_pins.py}` + `scripts/pin_tracker_seasons.py`
- BR: `bsb-wt-intangibles/astros-intangibles/intangibles/src/{br_tracker_data.py, tracker_pins.py}` + `scripts/pin_br_tracker_seasons.py`
- Fielding: same worktree + `fielding_tracker_data.py` + `scripts/pin_fielding_tracker_seasons.py`
- Catcher: same worktree + `catching_tracker_data.py` + `scripts/pin_catching_tracker_seasons.py`

DuckDB pilot reference:

- `bsb-wt-intangibles/astros-intangibles/intangibles/docs/plans/2026-05-27-duckdb-fielding-pilot-goal.md`

---

### ESTIMATED TIME

- Code: ~30-45 min per tracker × 5 = ~3-4 hours total agent time
- Re-pin: ~hours per tracker × 5 trackers — user-laptop time, can run in parallel windows or overnight
- Total session wall-clock: 1 work day (mostly waiting for re-pins to complete)

---

### CONTEXT FOR THE FLIP-FLOP IN PRIOR SESSION (avoid in next session)

The 2026-05-27 session shipped the live-DB DSL split feature + extended `league_distributions` pin (dormant). I (Claude) confused the user multiple times about whether the `league_distributions` extension was the answer to the slowness. It was NOT. The actual answer is THIS doc — pin the DSL split path itself.

Next-session Claude: do not get distracted by `league_distributions`. That's separate infrastructure (extending the league-pool sorted lists to all metrics — useful for a future Phase 2 percentile-pinning refactor, NOT relevant to DSL split speedup). Focus exclusively on pinning `get_org_rankings_dsl_split` per the plan above.

User direction on framing (paraphrased): "this is just like how we do multiple levels" — meaning: mirror the existing non-split pin pattern verbatim, don't invent a new architecture.

---

### SUCCESS METRIC

User opens any tracker on Posit Connect, selects DSL in sidebar, flips DSL split toggle ON. Org Rankings tab fully renders in ≤ 1 second (warm session). Today: 5-15 seconds. That's the win.
