# Tracker Parquet Pins — Pattern, Playbook, and BLOCKING Rules

Pre-aggregated tracker data pinned as joblib bundles on Posit Connect for
near-instant cold load on historical years. Piloted on Barrelsville
(feature/barrelsville, Apr 21 2026). Ready to replicate to the other 5
affiliate trackers.

---

## 1. What and why

### The problem
Every affiliate tracker's cold load runs heavy SQL against GCSQL02:
5-30 seconds for the default view, 30-60 seconds when multiple queries
are layered (org rankings, monthly breakdowns, yearly trends, league
distributions). Users select a prior-season tracker, then sit and wait.

### The solution
For **frozen historical years** (never-changing data — 2022-2025 as of
Apr 21 2026), precompute the tracker's DataFrame outputs once and pin
them on Posit Connect. Each app's data module checks the pin first;
falls through to live DB for current-year / non-default filters.

**Cold load drops from 5-60 s → sub-second** for any year in
`PINNED_YEARS` at default filter state.

### Functionality is byte-identical
The pin holds the exact DataFrame a SQL query would produce. Downstream
rendering, filtering, percentile ranking, and display code is unchanged.
No data drift, no schema reshuffle, no surprises.

---

## 2. Status per app (Apr 24 2026)

| App | Worktree | Branch | Status |
|---|---|---|---|
| **Barrelsville (Hitter)** | `bsb-wt-hitting/barrelsville` | `feature/barrelsville` | **LIVE** — pilot complete |
| Arm Farm (Pitcher) | `bsb-wt-bullpen/bullpen-report` | `feature/bullpen-reports` | Not started |
| **Intangibles (OF + IF)** | `bsb-wt-intangibles/astros-intangibles/intangibles` | `feature/astros-intangibles` | **LIVE** — 2022/23/25 clean, 2024 partial (see §10) |
| Intangibles (BR) | same | same | Not started |
| Intangibles (Catcher) | same | same | Not started |

OF + IF share the `fielding_tracker_data.py` module, so the two domains
get covered by one pin family via `render("OF")` / `render("IF")`
dispatch. Still one pin per year (joblib bundle of DFs for both domains).

---

## 3. Architecture (per app)

### Pin shape
One joblib pin per (app, year) on Connect:
`zbridger/{app}_tracker_{year}` — e.g. `zbridger/barrelsville_tracker_2024`.

Each pin is a dict bundle of ~16 keys covering the H/A × metric-kind
matrix at default sched_types:

```
batters_{all,home,away}                 # 3 DF keys
monthly_batters_{all,home,away}         # 3 DF keys
orgs_{all,home,away}                    # 3 DF keys
monthly_orgs_{all,home,away}            # 3 DF keys
yearly_orgs_{all,home,away}             # 3 DF keys
league_distributions                    # 1 dict key (H/A-independent)
```

Exact key names depend on the tracker's public API (BR tracker uses
`runners` instead of `batters`, etc.). Keep the suffix pattern
`_all` / `_home` / `_away` regardless.

### Filter gate
Pin hits only when ALL of:
- `year` in `PINNED_YEARS` (historical, frozen)
- `level_codes` set equals the canonical level set for that tracker
- `sched_types == ("R",)` (default regular season)
- `ha_split` in `(None, 0, 1)` — None/All, 0/Home, 1/Away
- No subset filter (`batter_ids=None`, etc.)
- `min_pa <= 1` for batter-prefixed pins (pin written at min_pa=1)

Any deviation falls through to live DB. Simple, predictable, safe.

### Always-warm current year
Tracker page background-warmup fires for `selected_seasons ∪ {current_year}`
so flipping to 2026 feels instant even when user started on a historical
year. Runs once per Streamlit session — first warmup still takes the live
DB hit, subsequent flips are cached.

---

## 4. File inventory (per app)

Every app needs these 5 components. Names and paths may differ per app.

### 4a. `src/pins_config.py` — board connection + SSL workaround

Copy from Barrelsville (`barrelsville/src/pins_config.py`). Adjust the
pin name format constant for the specific app.

**MUST pass `allow_pickle_read=True`** to `pins.board_connect()` for joblib
bundle pins. Without it, reads raise `PinsInsecureReadError`.

### 4b. `src/tracker_pins.py` — pin read/write helpers

Copy from Barrelsville. Key contents:
- `PINNED_HA_SPLITS = (None, 0, 1)` constant
- `PREFIX_*` constants for each DataFrame kind
- `bundle_key(prefix, ha_split)` → `"batters_home"` etc.
- `is_pinned_combo(sched_types, ha_split)` gate
- `load_tracker_bundle(year)` with `_pin_cache` memoization + `[PIN]` diagnostic prints
- `try_load(year, prefix, sched_types, ha_split)` with legacy-key fallback
- `try_load_league_dists(year, level_code)` (if tracker uses league distributions)
- `write_tracker_bundle(year, bundle)` for the CLI

### 4c. `src/{app}_tracker_data.py` — existing module, add pin-first wraps

For each **public** function the tracker page imports:
1. Add pin-first check at the top of the function body (before any DB work).
2. Pass PREFIX_* constant and all filter args to `_try_pin_bundle`.
3. Fall through to existing SQL path on pin miss.

Wrap these: `get_batter_leaderboard` (or equivalent), `get_monthly_X_stats`,
`get_org_rankings`, `get_monthly_org_stats`, `get_yearly_org_stats`,
`get_league_distributions` (if present).

Also add at module import:
```python
try:
    from .tracker_pins import (...)
    _TRACKER_PINS_AVAILABLE = True
    print("[PIN-INIT] tracker_pins imported OK -- _TRACKER_PINS_AVAILABLE=True")
except Exception as e:
    _TRACKER_PINS_AVAILABLE = False
    print(f"[PIN-INIT] FAILED to import tracker_pins: {type(e).__name__}: {e}")
```

### 4d. `scripts/pin_{app}_tracker_seasons.py` — CLI to write pins

Copy from Barrelsville `pin_tracker_seasons.py`. Adjust imported function
names to match the app's tracker_data. Must produce the 16-key bundle
(5 prefixes × 3 H/A + league_dists).

CLI flags to preserve:
- `--year YYYY` — single-year mode for testing
- `--dry-run` — compute + describe but skip pin_write
- `--ha-incremental` — keep existing H/A=All + league_dists, run only Home+Away
- `--league-only` — refresh only league_distributions

### 4e. `manifest.json` — **MUST list pins_config.py + tracker_pins.py**

**BLOCKING:** rsconnect only deploys files listed in `manifest.json.files`.
New modules are silently excluded otherwise. Add BOTH new files:
```json
"src/pins_config.py": {"checksum": ""},
"src/tracker_pins.py": {"checksum": ""},
```

This was the Apr 21 2026 gotcha: pins were written, code was pushed,
deploy succeeded, but the app logged
`ModuleNotFoundError: No module named 'src.tracker_pins'` on every load.
Tracker fell through to live DB every single request.

### 4f. `pages/{tracker_page}.py` — always-warm current year

In the background warmup block, change the iteration target from
`selected_seasons_tuple` to `set(selected_seasons) | {current_year}`.
Add `_load_all_leaderboard` to the warmup futures so the main leaderboard
pre-warms too.

---

## 5. BLOCKING rules (gotchas we hit)

All of these were real bugs discovered during the Barrelsville pilot. Do
not repeat them.

### 5.1. manifest.json — new files must be listed
rsconnect uses the `files` dict in `manifest.json` as an allow-list. New
Python modules added to `src/` are silently excluded from the deploy
bundle unless explicitly listed. Symptoms: `ModuleNotFoundError` in
Connect app logs, tracker falls through to live DB as if pin-first
didn't exist. Fix: add entries to manifest.json alongside the code
change.

### 5.2. allow_pickle_read=True on board_connect
Pins 0.9+ raises `PinsInsecureReadError` on joblib pin reads by default.
Tracker bundles are joblib (dict-of-dataframes — parquet can't hold that
shape). Board must be created with `allow_pickle_read=True`. The
`pd_goals_data` pin is NOT affected because it's written as a single
parquet DataFrame, not joblib.

### 5.3. Print, don't log, for diagnostics
`logger.info`/`logger.debug` are hidden by default WARNING level on both
local and Connect. Any diagnostic that needs to be visible in Connect
app logs MUST use plain `print()`. Applies to all pin read/write paths.

### 5.4. `[PIN-INIT]` at module import
Module-level try/except with visible `print()` at tracker_data import
time is the fastest way to detect a broken import on Connect (usually
caused by 5.1). Without it, a missing module silently disables pin-first
with zero indication.

### 5.5. H/A convention
`ha_split = 0` → `top_of_inning = 0` → bottom of inning → **batter is HOME**.
`ha_split = 1` → `top_of_inning = 1` → top of inning → **batter is AWAY**.
`ha_split = None` → All (no filter). Key suffixes: `home`, `away`, `all`.

### 5.6. Pin gate uses PREFIX, not full key name
`try_load()` signature takes `(year, prefix, sched_types, ha_split)`, not
a baked-in key like `"batters"`. Internally builds the H/A-suffixed key.
This is how one function serves all three H/A variants. NEVER hardcode
full keys at the call site.

### 5.7. Legacy-key fallback during schema transitions
When the pin schema evolves (e.g., adding H/A variants to a pre-H/A bundle),
`try_load` falls back to the unsuffixed legacy key for `ha_split=None`. This
keeps the app functional during the window between code deploy and CLI
re-pin. After a full CLI rebuild lands, the legacy keys are gone and the
fallback never fires.

### 5.8. Per-app pins, not one mega-pin
Temptation: bundle all 5 trackers' data into one pin per year (4 pins
total instead of 20). Don't. Coupled refresh kills you — fixing a
pitcher metric bug forces re-running hitter + fielding + BR + catcher
queries for the same year, 5× the runtime, 5× the correctness risk.

Per-app pins: independent refresh, independent deploys, targeted rollback,
clean ownership. Cross-app use cases (postgame hitter reading barrelsville
tracker pins for season-to-date context) still work fine — just read the
other app's pin.

### 5.9. Min_pa filtering happens client-side on pin hit
Pin is written with `min_pa=1` (permissive — all batters). Callers
passing stricter `min_pa` (e.g. `get_yearly_batter_stats` with
`min_pitches=50`) still hit the pin; the wrapper post-filters the
returned DataFrame on the `pa` column. Preserves behavior for all
callers without requiring a separate pin per min_pa threshold.

### 5.10. CONNECT_API_KEY lives in two places (usually)
- **Work laptop PowerShell:** needed to run the pin CLI (write path).
  `$env:CONNECT_API_KEY = "..."`
- **Connect app Vars tab:** MAY be needed for the deployed app to read pins.

**Empirical finding Apr 22 2026:** Arm Farm works with pins **without**
`CONNECT_API_KEY` manually set in its Vars tab. Connect appears to inject
some auth context for content calling its own instance's pins board in
certain configurations. Intangibles ALSO works without it (verified after
Phase 2–4 shipped). So in practice, **Vars tab setting is not required
on our Connect instance** — but documenting as optional in case the
behavior differs in future deploys.

`rsconnect's --api-key` CLI flag authenticates the DEPLOYER, not the
running app. Those are distinct settings.

### 5.11. `pins>=0.8.0` MUST be in requirements.txt — BLOCKING

Symptom: `[PIN-INIT] tracker_pins imported OK` at app startup, but every
tracker page load is slow as hell. No pin reads happen despite pins
existing on Connect.

Cause: `pins_config.py.get_board()` runs `import pins` inside a
try/except. If the pins package isn't installed in the deployed
environment, ImportError fires and `get_board()` returns None
silently. `load_tracker_bundle` then returns None, and pin-first falls
through to live DB every single request.

**The trap:** `[PIN-INIT]` print still fires OK because `tracker_pins.py`
imports only from `.pins_config` (not `pins` directly at module top).
So the diagnostic lies about availability.

**Fix:** Add to `requirements.txt` of every app deploying the pin pattern:
```
pins>=0.8.0
```

**Verify after deploy** by scanning the "Packages in the environment"
line in the rsconnect deploy output — must show `pins==X.Y.Z`.

**History Apr 22 2026:** Intangibles shipped Phases 2–4 without pins
in requirements.txt. BR + Catcher pins wrote successfully from the CLI
but the deployed app couldn't read them. Fix commit `fa69d8e`.

### 5.12. UI season selector MUST extend when PINNED_YEARS extends

If `PINNED_YEARS = (2022, 2023, 2024, 2025)` and the tracker page caps
the season selector at `current_year - 3` (default 4-year window), users
never see 2022 in the dropdown even though the pin exists. Wasted work.

**Pattern:** Replace `range(current_year, current_year - 4, -1)` with
```python
_MIN_SEASON = 2022  # match PINNED_YEARS in pins_config.py
season_options = list(range(current_year, _MIN_SEASON - 1, -1))
```

Apply in `pages/{tracker_page}.py`. Applied Apr 22 2026 in all 4
Intangibles tracker pages (`fielding_tracker_page.py`,
`br_tracker_page.py`, `catching_tracker_page.py`) and in Arm Farm
`pages/3_Affiliate_Tracker.py`. Barrelsville had the pattern already
(`_MIN_SEASON = 2022` shipped in `dc196ea`).

### 5.13. Pin CLI MUST bypass _TRACKER_PINS_AVAILABLE — BLOCKING

Every `pin_*_seasons.py` CLI imports the wrapped `get_*` functions from
the tracker's data module. Those wrappers check
`_TRACKER_PINS_AVAILABLE` and serve from the existing pin when the
filter gate matches the canonical write-time params. The CLI then
writes that cached DataFrame back to the pin as if it were freshly
queried. **Net effect: SQL filter changes / metric floor updates /
new column additions never propagate to the pin until the pin is
manually deleted.**

**Required at the top of every pin CLI**, after the LEVEL_TABS import:

```python
from src.{tracker}_tracker_data import LEVEL_TABS  # noqa: E402
import src.{tracker}_tracker_data as _td  # noqa: E402
_td._TRACKER_PINS_AVAILABLE = False  # force DB queries; bypass existing pin
```

Two lines. Set the module flag BEFORE any `get_*` function is called.
Same trick `repair_tracker_pin.py` uses (`§10.4`).

**Applied Apr 27 2026 in all four pin CLIs:**
- `intangibles/scripts/pin_br_tracker_seasons.py` (commit `d26b463`)
- `intangibles/scripts/pin_fielding_tracker_seasons.py` (`d26b463`)
- `intangibles/scripts/pin_catching_tracker_seasons.py` (`d26b463`)
- `barrelsville/scripts/pin_tracker_seasons.py` (`0479f11`)

**Symptom signature when the bypass is missing:**
- User changes a SQL filter (e.g. adds 1B PL > 5.0 ft floor)
- Runs `python scripts/pin_*_tracker_seasons.py`
- Run completes with normal-looking row counts and timings
- App still displays old values — no movement after redeploy
- `[PIN]` diagnostic logs show `SUCCESS, keys=...` (the pin DID get re-written)
- But the data inside the pin is the SAME as before the SQL change

If you see all five signs, the CLI is reading from its own pin. Add
the bypass and re-run.

### 5.14. Pin CLIs need full Events_View JOIN context for ha_filter

If `_build_ha_filter()` returns `AND ev.top_of_inning = X`, every query
that uses `{ha_filter}` MUST `JOIN Astros.Events_View ev ON
ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id`. The
substitution is opaque — adding `{ha_filter}` to a query without a
matching `ev` JOIN throws `multi-part identifier "ev.top_of_inning"
could not be bound` at runtime, and (since pin CLIs catch + log
failures and continue) writes a sparse pin with NULL columns for
that sub-query.

**Apr 27 2026 incident:** `barrelsville/src/tracker_data.py::_BS_QUERY`
+ `_AACON_QUERY` had `{ha_filter}` substitution but no `ev` JOIN. Every
bat speed + attack-angle sub-query failed silently across all
(level, H/A) combos. 2022 pin completed with bat_speed and aa_con
columns blank for half the slices. Fixed in commit `c7bad53` by adding
the standard JOIN pattern.

**Audit checklist when adding `{ha_filter}` to a new query:**
1. Does the FROM/JOIN chain already include `Astros.Events_View ev`? If not, ADD IT.
2. Is the JOIN keyed on `ev.event_id = pv.cur_event_id` (current event = AB/PA-ending pitch)?
3. Run a quick smoke test with `ha_split=0` (Home) before merging — the error surfaces immediately at SQL execution, not at format-string time.

### 5.15. Deploy bundle stays in sync with import graph — BLOCKING

When any `src/X.py` module adds a new `from .Y import Z` (or
`from src.Y import Z`), the new module `Y` MUST appear in both
`$srcFiles` AND `$bundleFiles` of every `connect_pins*/deploy.ps1`
that bundles a module which transitively imports it. Connect deploy
will report `nbconvert succeeded` and then the scheduled content
crashes at LAUNCH with `ModuleNotFoundError: No module named
'src.Y'`. The deploy log is the only place you see it; the rsconnect
push exit code is 0.

**Automated check** — run before every deploy (from any worktree root):

```powershell
python .claude/scripts/audit_pin_deploy.py --all
```

Exits 1 on drift, 0 on clean. Single deploy.ps1:

```powershell
python .claude/scripts/audit_pin_deploy.py `
  C:/Users/Owner/bsb-wt-hitting/barrelsville/connect_pins/deploy.ps1
```

Also available as the `/audit-deploys` slash command (Claude Code).

**Bug history:** May 19 2026 — `src/tracker_data.py` started
importing `xwoba_canonical` + `woba_weights` during the May 18 xwOBA
migration. The `$srcFiles` / `$bundleFiles` arrays in
`barrelsville/connect_pins/deploy.ps1` were frozen before those
modules existed. Deploy "succeeded," Connect crashed at launch with
`ModuleNotFoundError: No module named 'src.xwoba_canonical'`. Fix
commit `9dceb3f4` added both modules to both arrays. The audit
script catches this regression class — would have flagged the bug
before the deploy.

**What NOT to do:**
- Don't bypass the audit. The cost is ~50ms; the cost of a broken
  scheduled deploy is a stale 2026 pin until you re-deploy.
- Don't trust rsconnect's exit code. It's 0 even when the deployed
  content crashes at launch. Always read the Connect log on the
  first run after a `src/` edit.
- Don't add modules to only `$srcFiles` or only `$bundleFiles`.
  Both arrays must list the same `src/*.py` files. The audit also
  reports DESYNC between the two arrays.

### 5.16. STUB src/__init__.py when project re-exports — BLOCKING

Python implicitly executes `src/__init__.py` on EVERY `from src.X import
Y` — even before reaching `X.py`. If the project's `src/__init__.py`
re-exports symbols from sibling modules (e.g., `from .goal_parser
import ...`), and the deploy bundle doesn't ship those siblings,
Connect crashes at first import with:

```
ModuleNotFoundError: No module named 'src.goal_parser'
```

This is NOT caught by walking the entrypoint's import graph alone —
`__init__.py` runs implicitly. The audit script (§5.15) was extended
May 19 2026 to walk `__init__.py` AND detect deploy.ps1 stub-writes,
but the fix at deploy time is to **ship a STUB (empty) `__init__.py`
in the bundle**, overwriting the project's real one.

**Pattern in deploy.ps1** (variable-path variant — preferred):

```powershell
# Ship a STUB src/__init__.py (empty) — project's real __init__.py
# may re-export from sibling modules the pin job doesn't need
$utf8NoBomInit = New-Object System.Text.UTF8Encoding($false)
$initPath = Join-Path $srcDest "__init__.py"
[System.IO.File]::WriteAllText($initPath, "", $utf8NoBomInit)
Write-Host "[deploy] wrote STUB src/__init__.py"
```

Place BEFORE the `$srcFiles` copy loop and REMOVE `"__init__.py"`
from `$srcFiles` (so the stub doesn't get overwritten by the project's
real one).

**Who needs this:** any deploy whose project has a non-empty
`src/__init__.py`. PD-Goals's `__init__.py` re-exports `goal_parser`
+ `database`. Barrelsville's is empty — its bundle works without
this pattern. Always check the project's `__init__.py` content
before scaffolding a new connect_pins bundle.

**Bug history:** May 19 2026 — initial `pd-goals/connect_pins_defense/
deploy.ps1` copied the project's real `__init__.py` into the bundle.
Connect crashed on first `from src.paa_eo_matrix_data import ...`
because `__init__.py` ran first and tried `from .goal_parser import
...`. Fix commit `36a0870d` shipped a stub.

### 5.17. pyarrow required when pin_write uses type="parquet" — BLOCKING

Pandas can serialize DataFrames to parquet only when `pyarrow` (or
`fastparquet`) is installed. Posit Connect's base environment does
NOT include either by default — they must be in the bundle's
`requirements.txt` + `manifest.json` packages block.

| Pin shape | Engine | pyarrow needed? |
|---|---|---|
| `board.pin_write(df, name, type="parquet")` | pandas → pyarrow | YES |
| `board.pin_write(bundle_dict, name, type="joblib")` | joblib (stdlib pickle) | NO |

The 5 tracker pin bundles (Barrelsville hitter, Arm Farm pitcher,
Intangibles BR/Fielding/Catcher) write joblib because tracker bundles
are dict-of-DataFrames — parquet can't hold that shape. So those
deploys don't include pyarrow.

Single-DataFrame pins (Defense Matrix, future single-table pins) MUST
use `type="parquet"` and MUST include pyarrow in requirements.

**Pattern in deploy.ps1** — add to BOTH `$reqLines` and `$packages`:

```powershell
$reqLines = @(
    "pandas==2.3.0",
    "numpy==1.26.4",
    ...
    "pyarrow==16.1.0",       # required for type="parquet" pin_write
    ...
)

$packages = [ordered]@{
    ...
    pyarrow = [ordered]@{ description = [ordered]@{
        Package = "pyarrow"; Version = "16.1.0"; Source = "PYPI" } }
    ...
}
```

Symptom when missing:

```
[ERROR] Pin write failed: ImportError: Unable to find a usable engine;
tried using: 'pyarrow', 'fastparquet'.
```

The matrix builds correctly, all SQL runs, only the final
`board.pin_write(...)` step crashes. Recognizable: "Built N rows in
~Ns" appears in the log right before the ImportError.

**Bug history:** May 19 2026 — `pd-goals/connect_pins_defense/
deploy.ps1` initially copied the canonical Barrelsville requirements
block (joblib-based, no pyarrow). Defense Matrix pin write crashed
with the ImportError above after building 71 rows in 77.4s. Fix
commit `204647be` added `pyarrow==16.1.0` to both arrays.

**Picking a pyarrow version:** `16.1.0` is known-compatible with
`pandas==2.3.0` + Python 3.11. Don't go above 17.x without testing.

---

## 6. Replication playbook (step-by-step)

When replicating to a new tracker app (Arm Farm, Intangibles OF/IF, BR,
Catcher), follow these steps IN ORDER.

### Step 0: Identify the tracker's structure
- Read the app's `src/{app}_tracker_data.py` top-to-bottom.
- Grep the page `pages/{tracker_page}.py` for imports from tracker_data.
- Enumerate the **public functions** the page imports that run DB queries.
  These are the wrap targets.
- Note the page's `_load_*` cached wrapper functions and what they call.
- Check for a `get_league_distributions` equivalent (percentile pool
  helper). Not all trackers have one.
- Find the background-warmup block in the page (grep for `_bg_key` or
  `ThreadPoolExecutor.*_warmup`).
- List of canonical level codes — usually in `LEVEL_TABS` constant.

### Step 1: Copy infrastructure (from Barrelsville)
- `src/pins_config.py` — adjust `HITTER_TRACKER_PIN_FMT` → `"{app}_TRACKER_PIN_FMT = "zbridger/{app}_tracker_{year}"`
- `src/tracker_pins.py` — adjust prefix constants if tracker uses different
  DataFrame kinds (e.g., `PREFIX_CATCHERS` for catcher, `PREFIX_RUNNERS`
  for BR). Otherwise copy verbatim.
- `requirements.txt` — add `pins>=0.8.0` if not already there.
- `manifest.json` — add entries for both new files. CRITICAL.

### Step 2: Wrap the public tracker_data functions
- Add the `try: from .tracker_pins import ...` block at module top with
  `[PIN-INIT]` diagnostic prints.
- Add `_CANONICAL_LEVELS = frozenset(...)` constant.
- Add `_try_pin_bundle(season, prefix, level_codes, sched_types, ha_split, ...)`
  helper.
- For each public function: insert pin-first check at the top of the
  function body BEFORE any DB work. Pass the correct PREFIX_* constant.
- For `get_league_distributions`-style helpers: use `_pin_try_load_league_dists`
  which doesn't gate on filters (whole-season pools).

### Step 3: Write the CLI script
- Copy `scripts/pin_tracker_seasons.py` from Barrelsville.
- Rename to `scripts/pin_{app}_tracker_seasons.py`.
- Update imports to match the app's tracker_data function names.
- Preserve the H/A loop structure, `--ha-incremental`, `--league-only`,
  `--dry-run`, `--year` flags.

### Step 4: Page warmup
- In `pages/{tracker_page}.py`, change warmup iteration to include
  `current_year`:
  ```python
  _warm_years = tuple(sorted(set(all_seasons_tuple) | {current_year}))
  ```
- Add `_load_all_leaderboard` (or equivalent) to the warmup futures list.

### Step 5: Commit + push
- One commit covering all files. Reference this rules file in the message.

### Step 6: Work laptop operations
```powershell
cd {worktree path}/{app path}
git pull
$env:CONNECT_API_KEY = "H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb"
# Full rebuild (~1 hour for 4 years):
python scripts/pin_{app}_tracker_seasons.py
```

### Step 7: Connect setup
- Connect → Content → {app} → Vars tab → add `CONNECT_API_KEY`.
- Redeploy the app.

### Step 8: Verify
- Open the tracker page, flip to 2024 or 2025 → should feel instant.
- Flip H/A toggle → should ALSO be instant (pin hits for all 3 H/A).
- Flip to 2026 → falls through to live DB (~5-10s, unchanged).
- Check Connect logs for `[PIN-INIT] tracker_pins imported OK` and
  `[PIN] load_tracker_bundle(...): SUCCESS, keys=...` lines.
- Spot-check a few metric values against what you remember from before
  the pilot to confirm zero drift.

### Step 9: Save a progress memory
Each tracker's completion gets a one-liner in the project memory index.

---

## 7. Maintenance — when metrics change

Pinned data is a snapshot at pin-write time. If the SQL aggregation logic
changes after pinning (bug fix, metric redefinition, schema addition),
historical pins are stale — they carry the OLD numbers.

### What triggers a re-pin

| Change type | Re-pin? |
|---|---|
| Bug fix in metric formula (wOBA, Tier 1 gate, barrel, etc.) | **YES** — full rebuild |
| Add a new metric column to a query | **YES** — column absent from pin |
| Change a query's WHERE or JOIN | **YES** — output differs |
| Change a filter threshold (arm floor, etc.) | **YES** |
| Display formatting / coloring / glossary | No — pure rendering |
| Add new UI filter option not on the pin axis | Depends — if it becomes a default or common toggle, consider pinning |
| 2026-only data refresh (new games) | No — 2026 is never pinned |

### Re-pin workflow
```powershell
cd {worktree path}/{app path}
git pull                                  # pick up the metric fix
$env:CONNECT_API_KEY = "..."
python scripts/pin_{app}_tracker_seasons.py     # full rebuild
# Then redeploy the app.
```

### Incremental refresh paths
Use the narrow flags when only a small part of the bundle changed:
- `--league-only` (~3-5 min) — league distribution formula changed
- `--ha-incremental` (~40 min) — added Home+Away variants to a pre-H/A
  bundle (one-time transition, shouldn't recur)

### Propagation discipline
When a metric fix ships to the code:
1. Identify which apps' trackers compute that metric. Usually 1 app.
2. Re-run the pin CLI for THAT app. ~1 hour per tracker per full refresh.
3. Redeploy just that app.

Never re-pin an app whose SQL didn't change — wasted work + potential to
introduce drift if a latent bug is still in the code.

### Schema evolution
New pin key (e.g., adding L/R splits later):
1. Update `tracker_pins.py` with new PREFIX_* or suffix convention.
2. Update `try_load()` with legacy fallback for the transition window.
3. Update CLI to compute + write the new keys.
4. Update tracker_data pin gate to match.
5. One commit, push.
6. Work laptop: full rebuild CLI (incremental flag works only if
   restricted to the NEW keys, add a flag for it if common).
7. Redeploy.
8. Old app versions still work against new pins via legacy fallback
   during the deploy window.

---

## 8. The pilot commit history (reference)

Full commit chain on `feature/barrelsville` for the Barrelsville pilot:

| Commit | What |
|---|---|
| `47bffb3` | Initial pin infrastructure + 5 wrapped functions + CLI |
| `dc196ea` | Extend tracker UI to 2022+ (deep history now affordable) |
| `ac6dac0` | Wrap `get_league_distributions` + relax min_pa gate |
| `03d30e2` | `_describe()` handles dict bundle values cleanly |
| `9ae180f` | Visible `[PIN]` diagnostics (print vs logger) |
| `83ea0a7` | `allow_pickle_read=True` on board_connect |
| `b692ce1` | `[PIN-INIT]` + board_connect TypeError fallback |
| `c03c105` | Add new files to manifest.json (the "nothing's running" bug) |
| `d281796` | Pin H/A variants + always-warm current year |

Every one of these surfaced a real issue. Read the commit messages when
debugging the other trackers — same classes of bugs are likely.

---

## 9. Things NOT to do

- **Don't build a duplicate season-aggregate pin for another surface.** Tracker pin's `batters_all_all` / `pitchers_all_all` / equivalent DataFrames already contain per-player season aggregates across all 7 levels, refreshed daily on Connect. If you're tempted to build a new percentile / leaderboard / season-stats pin for postgame, KPI weekly, or any other surface — STOP and read the tracker pin's `LEADERBOARD_COLS` first. Almost always the column you need is already there.
  - **What tracker `batters_all_all` already covers (Barrelsville):** Approach (swing_pct, whiff_pct, chase_pct, ctct_pct, zctct_pct, zsw_pct, osw_pct, octct_pct, heart_swing_pct, heart_take_pct, swdec), BIP (avg_ev, max_ev, hard_pct, barrel_pct, pull_air_pct, dmg_pct), wOBA family (woba, xwoba, gcoba), PA-rate (k_pct, bb_pct, k_bb_pct, wrc_plus), Bat tracking (bat_speed, aa_con, vba_con), PoC (poc_depth_in, poc_rel_y, poc_rel_x).
  - **Pattern when reusing the tracker pin:** `bundle = load_tracker_bundle(season); df = bundle["batters_all_all"]; lvl_df = df[df["level"] == level_code]` then apply your surface's min-sample gates Python-side. Zero new pin to maintain.
  - **When you actually DO need a new pin:** the metric isn't in tracker `LEADERBOARD_COLS` AND there's no clean way to compute it from existing columns. In that case, first ask whether to ADD the column to tracker (single source of truth) before building a sibling pin.
  - **Bug history (May 16 2026):** Built `pin_postgame_percentiles.py` + a postgame-specific pin-first read path before checking tracker pin contents. User correctly flagged the duplication ("we have the affiliate tracker percentiles that are the same shit"). Reverted in commit `f5ec5ba0`. Lesson: read `LEADERBOARD_COLS` before designing any new pin for a season-aggregate use case.
- **Don't mega-bundle across apps.** Per-app pins, always. See 5.8.
- **Don't use parquet for dict-of-DataFrame bundles.** Parquet holds one
  tabular schema. Joblib + `allow_pickle_read=True` is the right tool.
- **Don't pin multi-select sched_type combos** (R+S, R+S+E, etc.). Rare,
  falls through to DB cheaply. See the "why not multi-select" discussion
  in the pilot sessions.
- **Don't hardcode full pin key names at call sites.** Use PREFIX_* +
  pass H/A through.
- **Don't forget manifest.json.** This is the #1 cause of "pin infra
  looks right but pin-first isn't running in deploy."
- **Don't re-pin on every deploy.** Pin only when the SQL output changed.
- **Don't skip the `[PIN-INIT]` diagnostic** — it saves hours when a
  deploy behaves weird.
- **Don't skip pooled-combo pinning** for any tracker that has a
  per-fielder/player PERCENTILE_CONT path triggered by multi-level
  selection. The May 21 2026 fielding migration showed this is now
  REQUIRED — without it, every level switch hits live DB. See §9b.
- **Don't exclude levels from pooled-combo coverage.** Pin all 7
  (MLB + 4 MiLB + Rookie + DSL). User direction May 21 2026.

---

## 9b. Pooled-combo pinning — multi-level percentile path (BLOCKING)

LIVE on `feature/astros-intangibles` since May 21 2026 (commit `83c0d3dd`).
Mandatory for any tracker whose multi-level Org Rankings + Indiv
Leaderboard fires a per-fielder/player PERCENTILE_CONT SQL across the
selected level set (the "pooled SQL" pattern from May 16 2026).

### Why this section exists

Pre-May-16, multi-level fielding used a page-side weighted-mean of
per-level pinned percentiles. Fast (pin-backed) but slightly off for
cross-level players (Nunez Arm: weighted-mean said 85.9 mph, true
pooled value 87.5 mph).

May 16 shipped the "correct" pooled SQL fix (per-fielder
PERCENTILE_CONT over the full multi-level pool). Mathematically right
but introduced a live-DB cost on every multi-level combination — no
pin coverage existed for the pooled SQL output.

May 21 2026 closes the gap. Every 2+-level combo of (MLB, AAA, AA,
A+, A, Rookie, DSL) = 120 combos, gets a pin key. Multi-level Org
Rankings + Indiv Leaderboard become pin lookups (instant) for any
level selection.

### Pin shape

| Constant | Value | Purpose |
|---|---|---|
| `_POOLED_BASE_LEVELS` | `("mlb","aaa","aax","afa","afx","rok","dsl")` | All 7 levels |
| `POOLED_LEVEL_COMBOS` | All 120 sorted-tuple combos of size 2+ from base | Iterated by pin CLI |
| `PREFIX_ORGS_POOLED` | `"orgs_pooled"` | Bundle-key prefix, pooled org rankings |
| `PREFIX_INDIV_POOLED` | `"indiv_pooled"` | Bundle-key prefix, pooled per-fielder |
| `pooled_combo_tag(level_codes)` | Sorted `"+"`-joined string | Bundle-key combo segment |

Bundle key format: `<prefix>_<combo_tag>_<ha>_<hand>`
Examples:
- `orgs_pooled_aaa+aax+afa+afx_all_all`
- `indiv_pooled_aaa+aax_home_all`
- `orgs_pooled_aaa+aax+afa+afx+dsl_away_l`

### Pin-first lookup wrapper

`_try_pin_pooled_combo(domain, prefix, season, level_codes, sched_types,
ha_split)` in `fielding_tracker_data.py`. Returns DF on hit, None on
miss. Gates:

- Pins module importable
- Single-year selection only (multi-year not pinned — would 120× combos)
- `sched_types` + `ha_split` match canonical pinned set
- `sorted(level_codes) ∈ POOLED_LEVEL_COMBOS`
- No `fielder_ids` subset filter

Both `get_org_rankings_pooled` and `get_indiv_leaderboard_pooled` check
the pin first; live SQL fallback only on miss.

### Pin CLI enumeration

`pin_fielding_tracker_seasons.py` iterates `POOLED_LEVEL_COMBOS` inside
each `_run_df_queries_for_ha(domain, year, ha)` call:

```python
for combo in POOLED_LEVEL_COMBOS:
    combo_str = pooled_combo_tag(combo)
    df = get_org_rankings_pooled(domain=domain, level_codes=list(combo),
                                  season=year, sched_types=sched, ha_split=ha)
    out[bundle_key(f"{PREFIX_ORGS_POOLED}_{combo_str}", ha)] = df
    df = get_indiv_leaderboard_pooled(domain=domain, level_codes=list(combo),
                                       seasons=[year], sched_types=sched, ha_split=ha)
    out[bundle_key(f"{PREFIX_INDIV_POOLED}_{combo_str}", ha)] = df
```

### Cost

- 120 combos × 2 prefixes × 3 H/A splits = **720 extra keys per (domain, year)**
- Per-combo SQL: ~30-90 sec each
- Per (domain, year): **~12 hours pin time**
- Full backfill 5 years × 2 domains: **~5 days runtime** (overnight loops)
- Connect daily refresh of 2026: same ~12 hr, runs in background

### Replication checklist for catcher (deferred)

When the catcher pooling fix finally ships (May 2026 deferred — see
`multi-level-rollup.md` "Catcher gap noted"):

1. Add `get_org_rankings_pooled` + `get_indiv_leaderboard_pooled`
   equivalents to `catching_tracker_data.py` (mirror fielding's two-stage CTE).
2. Add `_POOLED_BASE_LEVELS` (all 7) + `POOLED_LEVEL_COMBOS` +
   `PREFIX_ORGS_POOLED` + `PREFIX_INDIV_POOLED` + `pooled_combo_tag` +
   `_try_pin_pooled_combo` mirroring fielding (copy-paste).
3. Extend `pin_catching_tracker_seasons.py` with the same per-combo
   iteration block.
4. Re-pin all historical years on work laptop. Same ~12 hr/year cost.

BR doesn't need this — BR uses AVG of per-level pinned data
(mathematically equivalent to pooled for additive metrics, no
percentile pooling needed).

### What NOT to do

- **Don't subset levels** to "save pin time." All 7 levels are
  required per user direction (May 21 2026). Excluding DSL or
  Rookie means cross-tier multi-level selections fall through to
  live DB and feel broken.
- **Don't pin multi-year combos.** 120 × 5 years = 600 combos, plus
  3 H/A + 3 hand = explosion. Multi-year stays live-DB (rare use case).
- **Don't pin MLB-only-2-team or other non-canonical combos.** Only
  combinations of the standard 7 levels get pinned.
- **Don't add pre-warm hacks.** With pin coverage, the previous
  pre-warm pattern (commit `c8a859c1`) became dead code. Reverted
  in `51c98241`. If multi-level still feels slow after a re-pin,
  diagnose the pin hit (`[PIN]` log line) rather than adding
  pre-warm threads.
- **Don't forget the `_try_pin_pooled_combo` gate** when adding new
  pooled-path functions. Every pooled-path SQL caller must check
  the pin first.

### Bug history

- **May 16 2026** — Shipped pooled SQL fix (Nunez Arm bug). Multi-level
  fielding became architecturally inconsistent with rest of codebase.
  Live-DB on every level switch. Commit `2d3d9da9`.
- **May 21 2026** — User flagged the slowness: "why are we different
  than catching + barrelsville + arm farm?" Confirmed all other
  trackers were pin-backed; fielding's pooled path was the outlier.
- **May 21 2026** — Shipped pooled-combo pin coverage. Initially
  scoped to 4 MiLB (11 combos). User direction: include DSL → 5 levels
  (26 combos) → "no, all 7" → final scope = 120 combos. Commits
  `51c98241` → `88897704` → `83c0d3dd`.

---

## 9c. Combo precompute speed + scheduled-refresh PRESERVE (Jun 6 2026 — BLOCKING)

The pooled-combo precompute (§9b) is built by iterating combos and computing
per-fielder pooled percentiles in Python.

### CORRECTION (Jun 7) — vectorize fixed the COMBO stage, NOT the full BUILD
The fix below speeds the **combo precompute stage + live multi-level app reads**.
It does NOT speed the pin BUILD wall-clock, which is dominated by the **8 base SQL
slices** per `(domain, year, ha)` (`monthly_fielders`, `weekly_fielders`,
`monthly_orgs`, `weekly_orgs`, etc.) — each a `PERCENTILE_CONT` window-function
query, 3× base scan, run once per level × 7 levels, *before* combos. Jun 7 laptop
evidence: season `fielders` = 126 s but ONE `monthly_fielders` slice = **8203 s
(2.3 h)**; the build never reached combos. monthly is also far over the CLI's own
~2 h full-build estimate → GCSQL02/laptop-network throttling on top of an inherently
heavy query (laptop builds are the known failure mode, §11.1). Combos depend ONLY on
the cheap `raw_*` slices, so a FULL build to seed combos pays the 2.3 h base SQL
needlessly — seed combos via **`--combos-only`** (SHIPPED Jun 7, commit `f9279a1d`):
rebuild raw_obs + combos, overlay onto the existing pin's base slices, write back
(~<1 h vs multi-hour full build). The daily Connect `--skip-combos` job then
preserves the seeded combos + keeps base fresh. See
`memory/fielding-tracker-perf-session.md`.

### THE combo-stage bottleneck + fix
`fielding_tracker_data.py::_per_fielder_percentile_values` looped
`for gkey, g in tdm.groupby(...)` over ~1,900 (fielder[,org]) groups, calling
`np.percentile` + `.notna().sum()` for 9 metrics each. ×120 combos = the
**combo-stage** cost (NOT the whole build — see correction above), and the same
function made live multi-level loads 15–30s.
**Fixed (commit `b06dd755`)** by vectorizing to one `groupby().quantile()` +
`.count()` per metric. pandas `.quantile()` = same linear interpolation as
`np.percentile`, both skip NaN → **value-identical** (parity-tested old-vs-new:
single-key, fielder×org, all-NaN metric, all-range-filtered group, single-row,
traded multi-org, empty — all PASS). Per-combo: ~10–40s → sub-second.

**DON'T reintroduce a `groupby().apply(pyfunc)` or `for ... in df.groupby()`
loop for percentile/aggregation work.** Use vectorized `groupby().quantile()`/
`.count()`/`.agg()`. If catcher/BR pooled paths have the same loop shape,
port this fix.

### Scheduled refresh PRESERVES combos (do not wipe them)
`--skip-combos` is the SCHEDULED-refresh mode: fast base/raw update (no 404)
that **carries forward the existing pin's `*_pooled_*` combo keys** instead of
overwriting them (`_merge_preserved_combos`, commit `e8a0a379`). A plain
skip-combos write WIPES the combos and the app goes slow (this was the Jun 6
regression). Combos are re-seeded off-Connect (laptop) because seeding them on
Connect would hit the scheduler time limit. A **FULL build** seeds combos but
pays the 2.3 h-per-slice base SQL (see correction above). The seed tool is
**`--combos-only`** (SHIPPED Jun 7, `f9279a1d`): overlays cheap raw_obs + combos
onto the existing pin's base slices (~<1 h), skipping the base SQL.
`--common-combos` (`a1d29f34`) exists but is wrong when users select many combos.

### DuckDB pilot is BROKEN — leave OFF
The DuckDB-over-parquet backend (`fielding_duckdb.py`) never worked: parquet
was never written until pyarrow was added (`b1e0f61c`), and once it was, the
app log proved DuckDB is a net-negative — **org path crashes every call
(`KeyError: 'org'`)**, **indiv path leaks (31s→172s, re-reads parquet per
query)**. Defaulted OFF (`30ecae68`). Don't enable without a real rewrite
(register parquet as a table ONCE; fix org KeyError). With the vectorized
Python path fast, DuckDB is likely unnecessary.

### Lesson
When something was FAST then went SLOW, **diff the fast artifact vs the slow
one first** (here: this-morning's pin bundle had `indiv_pooled_*` keys, the
slow one didn't = combos got wiped). Hours were lost debugging the speed
*symptom* (DuckDB, fallbacks, dtypes) before diffing bundle contents. See
`memory/fielding-tracker-perf-session.md` for the full saga.

> Cross-worktree sync pending: this section edited in bsb-resources only —
> run `/sync-rules` to propagate.

---


## 10. Sparse-pin recovery — when a long run writes incomplete data

**Moved to `rules/tracker-pin-sparse-recovery.md`** to slim this file.
~140 lines covering failure-mode signature, diagnostic row-count
comparison, `repair_tracker_pin.py` + 3 modes (auto / `--force` /
`--rebuild`), the `_TRACKER_PINS_AVAILABLE = False` bypass mechanic,
and idempotent preserve-on-failure semantics.

Run when: pin bundle keys show 0 rows or <50% of a known-good year.


## 11. Daily refresh for current season (2026 strategy)

**Moved to `rules/tracker-pin-daily-refresh.md`** to slim this file.
~250 lines covering the 3-step ladder for current-season refresh:
Step 1 = Connect-scheduled CLI; Step 2 = append-only daily incremental;
Step 3 = DB-side materialized table (long-term).

START WITH STEP 1. User-laptop-network is the actual failure mode on
multi-hour pin builds, not the queries themselves.


## 12. Connect-scheduled daily refresh — full setup playbook (Apr 29 2026)

**Moved to `rules/tracker-pin-connect-deploy.md`** to slim this file.
~500 lines covering: Barrelsville pilot, 8 bugs hit during setup
(Streamlit manifest poison, appmode constraints, Python-version mismatch,
BOM, requirements.txt order, entrypoint, Windows-Auth incompatibility
on Linux, em-dash ASCII traps), step-by-step replication for new
trackers, May 3 2026 handedness §12.12.1 SHIPPED status, known
R-sched_type-only limitation (Spring deferred), queued future
expansions (date range, week-over-week).

For NEW Connect-scheduled jobs (non-trackers), this playbook is the
template — see "Reusable patterns for future Connect-scheduled jobs".
