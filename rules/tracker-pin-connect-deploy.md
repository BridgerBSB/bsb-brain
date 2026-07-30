---
paths:
  - "**/connect_pins*/**"
  - "**/pin_*.py"
---
# Tracker Parquet Pins — Connect-Scheduled Daily Refresh + Future Expansions (parent section 12)

> **Extracted from `tracker-parquet-pins.md` 2026-05-19** to keep the
> parent rule under the article-recommended discoverability threshold.
> Parent has section pointers to this file. Auto-loaded with the parent
> on any tracker-related Python edit.

---

## 12. Connect-scheduled daily refresh — full setup playbook (Apr 29 2026)

The Apr 29 Barrelsville pilot proved out the full Connect-scheduled
refresh path. Step 1 of the strategy in §11 is now LIVE for Barrelsville.
This section is the complete playbook for replicating to other trackers.

### 12.1. What got built (Barrelsville reference impl)

| Piece | Location | Purpose |
|---|---|---|
| `connect_pins/` | `barrelsville/connect_pins/` | Self-contained deploy bundle dir |
| `pin_tracker_2026.ipynb` | `connect_pins/pin_tracker_2026.ipynb` | Notebook wrapper that imports + calls `pin_tracker_seasons.main()` |
| `deploy.ps1` | `connect_pins/deploy.ps1` | PowerShell deploy automation (copy + manifest gen + rsconnect) |
| `.gitignore` | `connect_pins/.gitignore` | Excludes bundled-at-deploy-time copies |
| Connect content | `barrelsville-pin-tracker-2026` (GUID `83ae2fde-df7e-4365-adcb-ff3ca429c878`) | The deployed scheduled job |

Reference commits on `feature/barrelsville`: `ad71d35` (PINNED_YEARS),
`cf737e3` (initial notebook), `2e98785` (subdir restructure), `753a0d0`
(cwd-agnostic), `2552455` (em-dash fix), `9df837c` (https scheme),
`bcf9b24` (.python-version), `262f5e6` (python-script attempt),
`830675e` (BOM fix), `aff741d` (jupyter-static), `eddf6b7`
(requirements.txt order), `93fd302` (entrypoint field).

### 12.2. Required Connect content vars — BLOCKING

Without all three, the deployed content fails on first run.

| Var | Purpose | Source |
|---|---|---|
| `CONNECT_API_KEY` | Pin write auth | Same key already used for the existing Streamlit app |
| `DB_USER` | FreeTDS user (e.g. `rs_connect_ro`) | Existing Streamlit app's Vars tab |
| `DB_PASS` | FreeTDS password | Existing Streamlit app's Vars tab |

Easiest way to find the values: open the existing Streamlit app's
Vars tab in Connect UI, copy `DB_USER` and `DB_PASS` from there, paste
into the new pin-tracker content's Vars tab.

### 12.3. Eight bugs hit during the Barrelsville pilot — how to avoid

**12.3.1. Streamlit manifest.json poisons notebook deploys.** Running
rsconnect deploy notebook from a project root that has a Streamlit
manifest.json makes Connect classify the new content as Streamlit too.
Schedule tab gets greyed out. Fix: deploy from a clean subdirectory
(connect_pins/) where rsconnect cannot bundle the parent Streamlit
manifest.

**12.3.2. rsconnect-python rejects appmode python-script.** Nick
Arrivo's pin_wizardry uses appmode python-script but he publishes via
RStudio IDE. rsconnect-python CLI raises ValueError: No app mode
named python-script. Fix: use appmode jupyter-static with a notebook
wrapper that imports + calls the .py script's main() function.

**12.3.3. Local Python version mismatched with Connect runtime.**
rsconnect bundles metadata using whatever Python is running rsconnect.
If local is 3.14 and Connect only has 3.11/3.12, deploy fails with
Cannot find compatible environment. Fix: hand-write manifest.json
with explicit platform 3.11.0 + python.version 3.11.0. Do not rely
on rsconnect auto-detection.

**12.3.4. PowerShell Set-Content -Encoding utf8 writes BOM.** Python
json.loads rejects UTF-8 BOM with Unexpected UTF-8 BOM. Fix: use
.NET File.WriteAllText with UTF8Encoding(false) to write
manifest.json without the BOM.

**12.3.5. requirements.txt must exist BEFORE manifest checksums.** If
the manifest's files block references requirements.txt but the file
does not exist when the bundle uploads, Connect's build step fails
with FileNotFoundError. Fix: generate requirements.txt FIRST, then
compute manifest checksums.

**12.3.6. Manifest must have metadata.entrypoint.** Without it,
Connect's launch step fails with Missing entrypoint in manifest. Fix:
set metadata.entrypoint to the .ipynb filename, matching the pattern
the existing Streamlit manifest.json uses for its Barrelsville.py.

**12.3.7. Connect's Linux container cannot do Windows Auth.** The
script's database.py already has dual-mode logic (checks DB_USER /
DB_PASS env vars first, FreeTDS path; falls back to Windows Auth).
Fix: set DB_USER + DB_PASS in the Connect content's Vars tab. Without
them, the FreeTDS branch never fires and Windows Auth fails with
No Kerberos credentials available.

**12.3.8. Em-dashes in .ps1 get mangled by Windows encoding.** Em
dash becomes mojibake after git checkout, PowerShell parser breaks
with Array index expression is missing or not valid. Fix: ASCII-only
in .ps1 files. Use plain hyphens, not em-dashes or en-dashes.

Plus minor friction:
- PowerShell execution policy blocks unsigned scripts: per-session
  `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
- `--server` arg requires `https://` scheme prefix or rsconnect
  raises URL scheme is not supported
- `.\connect_pins\deploy.ps1` works from `barrelsville/` only; from
  inside `connect_pins/` use `.\deploy.ps1`. The script uses
  $PSScriptRoot so it is cwd-agnostic once it starts; only the
  invocation path matters.

### 12.4. Step-by-step replication for new tracker (~30 min)

When porting Barrelsville's setup to another tracker (Arm Farm,
Intangibles BR/OF-IF/Catcher), follow these steps IN ORDER.

**Step 1: Add 2026 to PINNED_YEARS** (1 min)
```python
# {app}/src/pins_config.py
PINNED_YEARS = (2022, 2023, 2024, 2025, 2026)
```

**Step 2: Initial 2026 backfill on work laptop** (5-15 min depending
on tracker size)
```powershell
cd C:\Users\zbridger\<worktree>\<app>
git pull
$env:CONNECT_API_KEY = "..."
python scripts/pin_{app}_tracker_seasons.py --year 2026
```
Verify with `load_tracker_bundle(...)` Python one-liner.

**Step 3: Build `{app}/connect_pins/` directory**

Three files to create, copying templates from `barrelsville/connect_pins/`:

- `pin_tracker_2026.ipynb` — verbatim copy works for any tracker; the
  notebook uses `importlib.util.spec_from_file_location` and looks for
  `pin_tracker_seasons.py` in the cwd, which deploy.ps1 copies in.
  Edit only the markdown cell description to name the new tracker.

- `deploy.ps1` — copy from barrelsville and update three things:
  - `$srcFiles` array — list every `src/*.py` module the pin script imports
  - script name in the `Copy-Item` for `pin_tracker_seasons.py` if the
    new tracker calls it something else (e.g.
    `pin_br_tracker_seasons.py`)
  - `--title "{app}-pin-tracker-2026"` so each tracker's Connect
    content has a unique title

- `.gitignore` — verbatim copy

Commit + push on the worktree's feature branch.

**Step 4: Run deploy.ps1 from work laptop** (~5 min first deploy,
~2 min subsequent)

**🚨 BLOCKING — execution-policy bypass MUST be Step 1 of every PowerShell
deploy session.** Default Windows PowerShell blocks unsigned local
scripts. Without the bypass, `.\deploy.ps1` errors with
"running scripts is disabled on this system." Always show this command
FIRST in any walkthrough, with **hyphens clearly visible** before
`Scope` and `ExecutionPolicy` — without the dashes PowerShell raises
"A positional parameter cannot be found that accepts argument 'Scope'."

```powershell
# Step 1 (per session — closes when shell closes, safe)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Step 2 — set API key
$env:CONNECT_API_KEY = "..."

# Step 3 — go to the worktree dir + deploy
cd C:\Users\zbridger\<worktree>\<app>
git pull
.\connect_pins\deploy.ps1
```

**The bypass is per-session only.** It expires when you close that
PowerShell window. Re-run it for every new shell you open. If you
deploy 4 trackers from 4 separate windows, the bypass goes in all 4.

This applies to EVERY tracker — Barrelsville, Arm Farm, BR, Catcher
all use `connect_pins*/deploy.ps1` and all are unsigned. May 3 2026
burned user time twice on missed dashes during the handedness rollout.

**Step 5: Configure Connect UI for the new content** (5 min)
1. Open `https://connect2.astros.com` → Content → `{app}-pin-tracker-2026`
2. Vars tab: add `CONNECT_API_KEY`, `DB_USER`, `DB_PASS` (copy from
   existing Streamlit app)
3. Schedule tab: add cadence (recommended every 6 hours OR twice daily
   at 6 AM + 12 PM CST)
4. Email tab (optional): enable failure notifications
5. Click Run Now to verify, watch Logs tab for `Done in ~Xs` and
   `Exit code: 0`

**Step 6: Verify the deployed app loads fast** (1 min)
- Open the {app} Streamlit page in a fresh browser tab
- Affiliate Tracker page → 2026 season
- Cold load should feel instant (1-2 sec) instead of 30-60 sec

### 12.5. Verification — what success looks like in Connect logs

```
[DB] Connecting as <USER> to GCSQL02.ASTROS.COM (FreeTDS)
=== 2026 ===
  [2026/all] batters ... NNNN rows (~30s)
  ... (15 more lines, one per slice) ...
  writing pin '<pin name>' ... OK (~290s total)

Exit code: 0
```

The `(FreeTDS)` line is the key proof DB_USER/DB_PASS got picked up.
If you see `Windows Auth` instead, the env vars are not set in Vars tab.

### 12.6. Things that must match the Barrelsville pattern

- Notebook uses `importlib.util.spec_from_file_location` to load
  `pin_tracker_seasons.py` (not a regular import — script is not a
  Python package).
- Notebook overrides `sys.argv` BEFORE loading the script so argparse
  picks up `--year 2026`.
- Notebook adds cwd to sys.path so `from src.X import Y` works inside
  the script.
- deploy.ps1 copies `pin_tracker_seasons.py` + needed `src/*.py` into
  `connect_pins/` at deploy time, runs rsconnect, then deletes the
  copies.
- Manifest hardcodes `platform: "3.11.0"` regardless of local Python.
- All .ps1 files ASCII-only.

### 12.7. What NOT to do (BLOCKING summary)

- Do NOT deploy from project root. Streamlit manifest.json poisons the deploy.
- Do NOT try appmode python-script. rsconnect-python rejects it.
- Do NOT trust .python-version to override rsconnect's local Python detection.
- Do NOT write manifest.json with PowerShell `Set-Content -Encoding utf8`. BOM breaks Connect.
- Do NOT generate requirements.txt AFTER manifest. Checksums miss it.
- Do NOT omit metadata.entrypoint. Connect needs to know which file to launch.
- Do NOT forget DB_USER/DB_PASS in Connect Vars tab. Linux containers cannot do Windows Auth.
- Do NOT commit bundled file copies. They regenerate each deploy.
- Do NOT use em-dashes or other non-ASCII in .ps1 files.

### 12.10. Apr 29 2026 rollout status — all 5 trackers LIVE on Connect schedule

Single-day rollout completed. All affiliate trackers now have
Connect-scheduled current-year pin refresh firing every 6 hours.

| Tracker | Worktree | Connect-pins dir | Connect content title | Pin name |
|---|---|---|---|---|
| Barrelsville (hitter) | `bsb-wt-hitting/barrelsville` | `connect_pins/` | `barrelsville-pin-tracker-2026` | `zbridger/barrelsville_tracker_2026` |
| Arm Farm (pitcher) | `bsb-wt-bullpen/bullpen-report` | `connect_pins/` | `arm-farm-pin-tracker-2026` | `zbridger/arm_farm_tracker_2026` |
| Intangibles BR | `bsb-wt-intangibles/astros-intangibles/intangibles` | `connect_pins_br/` | `intangibles-pin-tracker-2026-br` | `zbridger/intangibles_br_tracker_2026` |
| Intangibles Fielding (OF+IF) | same | `connect_pins_fielding/` | `intangibles-pin-tracker-2026-fielding` | `zbridger/intangibles_of_tracker_2026` + `zbridger/intangibles_if_tracker_2026` |
| Intangibles Catcher | same | `connect_pins_catcher/` | `intangibles-pin-tracker-2026-catcher` | `zbridger/intangibles_catcher_tracker_2026` |

**Naming convention:** Single-tracker apps (Barrelsville, Arm Farm) use
`connect_pins/` (one per app root). Multi-tracker apps (Intangibles) use
suffixed sibling dirs (`connect_pins_{br,fielding,catcher}/`) so each
tracker is an independent deploy unit.

**Schedule on all 5:** every 6 hours (timezone America-Chicago in
Connect UI). Schedules can be adjusted independently per content.

**Vars on all 5:** `DB_USER` + `DB_PASS` set in each Connect content's
Vars tab (copied from each app's existing Streamlit Vars tab).
`CONNECT_API_KEY` auto-injected by Connect — not required to set
manually but doesn't hurt.

**Combined OF + IF rationale:** `pin_fielding_tracker_seasons.py` writes
both pins in one run when `--domain` isn't passed. Single Connect
content + single schedule = both pins refreshed every 6 hours. No
reason to split into separate `_of` / `_if` deploys unless we ever
need OF and IF on different cadences.

### 12.11. Lessons + reusable patterns for future Connect-scheduled jobs

This entire pattern is reusable for ANY Python job that needs to run
on a schedule against GCSQL02 and write results to a Connect pin
(or similar persistent storage). Future projects:

- Daily metric snapshots (e.g., daily KPI roll-ups for Slack delivery)
- Weekly drift detection (the PD Drift Alert design in
  `docs/plans/2026-04-26-pd-drift-alert-design.md` could use this same
  Connect-scheduled pattern)
- Materialized view refreshes (e.g., daily wOBA league environment
  recomputation)
- Any "run a Python script every N hours against the DB" job

The setup is **content-type-agnostic**: as long as the script is wrapped
in a notebook (`appmode: jupyter-static`), the pattern works. Replace
`pin_tracker_seasons.main()` with whatever main function you want
scheduled.

**The 5-file template:**
```
{app}/{job_dir}/
├── pin_tracker_2026.ipynb   # 2-cell notebook wrapping the .py main()
├── deploy.ps1               # PowerShell deploy automation
├── .gitignore               # excludes bundled-at-deploy copies
```

Files generated at deploy time (NOT committed):
```
├── manifest.json            # generated by deploy.ps1
├── requirements.txt         # generated by deploy.ps1
├── {script}.py              # copied from {app}/scripts/
└── src/                     # copied from {app}/src/, only the modules the script imports
```

**The 8 reusable rules** (every future job follows these):
1. Deploy from a clean subdirectory (no parent Streamlit manifest)
2. Use `appmode: jupyter-static` (rsconnect-python supports it)
3. Hand-write `manifest.json` with `platform: "3.11.0"` (matches Connect)
4. Write manifest as UTF-8 without BOM (`UTF8Encoding($false)`)
5. Generate `requirements.txt` BEFORE computing manifest checksums
6. Set `metadata.entrypoint` to the .ipynb filename
7. Set `DB_USER` + `DB_PASS` in Connect Vars tab (Linux can't do Windows Auth)
8. ASCII-only in `.ps1` files

### 12.9. KNOWN LIMITATION — pin only covers Regular season (sched_type='R')

The pin filter gate (§3) only matches when `sched_types == ("R",)`. This
means **Spring (S), Exhibition (E), Instructional (I), or any multi-
sched-type selection (R+S, etc.) bypasses the pin and falls through to
live DB**, which is slow.

Coordinator-visible symptom: when they pick "Spring 2026" in the
Affiliate Tracker, the page reverts to the old 30-60s cold load. Same
when they uncheck the sched_type filter entirely (empty tuple).

**Why we shipped it this way (Apr 21 2026 pilot decision):**
- Pinning every sched_type combination explodes the pin matrix
  exponentially (R, S, E, V, I, plus combos)
- Regular season is ~90%+ of coordinator workflow year-round
- Spring is only relevant ~6 weeks (Feb-March)
- Storage + nightly refresh time both balloon if we pin all combos

**FUTURE FEATURE — Spring pin (deferred until next February):**

Add a parallel pin written with `sched_types=("S","I")` so Spring
training and Instructional ball get the same fast-load treatment.

Implementation pattern (when we get to it):
1. New pin name suffix: `zbridger/{app}_tracker_{year}_spring`
2. Update `tracker_pins.py` to register a second filter gate for the
   spring sched_types tuple
3. Update each pin CLI to write BOTH the R pin AND the spring pin in
   the same run (one shared SQL pull, two saved bundles)
4. Update each pin script's notebook wrapper / Connect content if a
   separate scheduled refresh is needed (probably the same daily run
   handles both)
5. App data module's `_try_pin_bundle` checks both gates — R for
   regular, _spring for S/I

Cost estimate: +50% pin write time (different SQL filter on same base
data), +1 pin per app per year, +negligible storage. Worth doing in
late January when teams convene at spring training facilities.

**Apr 29 2026 status:** R-only is shipped + working for Barrelsville.
Other tracker rollouts (Arm Farm, Intangibles BR/OF-IF/Catcher) match
the same R-only scope. Spring pinning queued as a future workstream.

If a coordinator complains about Spring being slow before next Feb,
that's the trigger to prioritize this work.

### 12.12. Other queued future expansions — handedness, date range, week-over-week

Three additional axes the user has flagged for "soon" (Apr 29 2026 heads-up).
Each expands the pin matrix and needs the same shape of work as §12.9 Spring:
new bundle-key suffixes, new filter gate in `_try_pin_bundle`, CLI emits the
new variants, no schema break for existing pins.

#### 12.12.1. Handedness (L/R batter / pitcher splits) — SHIPPED May 3 2026

**Status:** LIVE on 4 trackers (Barrelsville, Arm Farm, BR, Catcher).
Fielding (OF/IF) intentionally skipped per design.

**Design doc:** `docs/plans/2026-05-03-tracker-handedness-splits-design.md`
in the bsb-resources main repo. Read end-to-end before touching any
hand-related code.

**Per-app handedness mapping shipped:**

| App | Filter dimension | UI label | SQL source |
|---|---|---|---|
| **Barrelsville** | pitcher hand | `vs LHP / vs RHP / All` | `pv.pitcher_throws` (direct on Pitches_View) |
| **Arm Farm** | batter side | `vs LHH / vs RHH / All` | `pv.bat_side` (direct on Pitches_View) |
| **BR** | pitcher hand | `LHP / RHP / All` | `pv.pitcher_throws` direct + LEFT JOIN PV from Events_View where pv not present |
| **Catcher** | pitcher hand | `LHP / RHP / All` | LEFT JOIN `Astros.Players p_pitcher ON pv.pitcher_id = p_pitcher.groundcontrol_id` + `p_pitcher.throws` |

**Pin matrix:** 16 keys → 46 keys per app per year. Pool stays single
(Path C deferred — see §6 of design doc).

**Commits:**
- Arm Farm: `837789c` + `a2524df` (b_side→bat_side fix) on `feature/bullpen-reports`
- Barrelsville: `8afc44c` on `feature/barrelsville`
- Catcher: `3119f84` on `feature/astros-intangibles`
- BR: `976f2fe` on `feature/astros-intangibles`

**Bug history:**
- May 3 2026 — Arm Farm initial impl used `pv.b_side` (a guess, common
  MLBAM/Statcast variant) instead of `pv.bat_side` (Astros DB canonical).
  Caught at re-pin time. Fixed in `a2524df`. Lesson: grep DB columns
  before typing them in design docs / agent prompts. Encoded in
  `memory/feedback_no_design_doc_column_assertions.md`.

**Future expansion: Path C (pool splitting).** Currently deferred. When
a coach reports "vs-LHP percentile coloring is misleading" on a
platoon-sensitive metric, revisit. Implementation note from design §6:
- `league_distributions` matrix grows from 1 set per level → 9 sets
  (3 H/A × 3 Hand)
- Pin write +30-60 sec/year/app (cheap PERCENTILE_CONT)
- Storage modest (distributions are short arrays)
- App data module matches pool to displayed scope at percentile lookup
- Backwards compat: fallback to single overall pool when split-pool
  variant missing

**Open question for design time:** Pitcher tracker = pitcher handedness is
obvious. But for Barrelsville (hitter tracker), the ask is most likely
**vs L pitchers / vs R pitchers** (batter splits). Confirm with user
which direction the split goes per tracker before building.

#### 12.12.2. Custom date range / windowed views

**The matrix:** Date range is open-ended — `(start_date, end_date)` is two
free parameters. Cannot pre-pin every combination.

**Two strategies:**

**Strategy A — pin "last N days" rolling windows.** Common windows the user
asks for: L7 / L14 / L30 / month-to-date / season. Pin a fixed enum of
window labels. Cheap, predictable, doesn't explode storage.

**Strategy B — let custom ranges fall through to live DB.** Pin only
season-to-date (current behavior). When user picks a custom date range, the
filter gate doesn't match → falls through. Slow but correct.

**Recommended approach:** Strategy A for the common windows (L7/L14/L30/MTD),
Strategy B fallback for everything else. New pin key suffix: `_l7`, `_l14`,
`_l30`, `_mtd` alongside the existing season-wide key.

**Cost estimate:** +4 bundle keys per existing slice = ~4× write time for
the non-season views. Storage grows linearly. Worth it if these windows are
frequently used in the UI.

**Implementation hook:**
1. Add `PINNED_DATE_WINDOWS = ("season", "l7", "l14", "l30", "mtd")` constant
2. Pin CLI computes each window's start_date relative to the pin run's
   `as_of_date` and queries each separately
3. Pin metadata stores the `as_of_date` so the app knows whether the
   window is fresh enough (e.g., L7 written 8 hours ago is stale by 1 day)
4. App's `_try_pin_bundle` matches the user's selected window label to the
   bundle key

**Critical scheduling rule:** Rolling windows mean the schedule cadence
matters more. Today's L7 is different from yesterday's L7. Connect-scheduled
6-hour refresh handles this naturally — every 6 hours the L7 window
slides forward.

#### 12.12.3. Week-over-week trend pinning

**Use case:** "Show me how Pena's contact rate has changed over the last
4 weeks." Either a small chart or a delta column.

**The matrix:** Per-player time series, weekly grain. Computing on cold
load means N weeks × M players × ~10 metrics — tractable but slow.

**Pin shape:** New top-level bundle keys for trend data:
- `trend_batters_weekly` — long-form DataFrame: one row per (player, week, metric)
- `trend_orgs_weekly` — same shape but per-org

These are independent of the H/A / hand splits — trend is "what happened
on R games week over week." Single pin variant per (year, prefix).

**Cost estimate:** ~10–20% additional pin write time. Storage modest
(weekly grain compresses well in parquet). The big win is interactive
trend rendering — sub-second instead of 10–30s on cold load.

**Implementation hook:**
1. Add new prefix constants: `PREFIX_TREND_BATTERS_WEEKLY`,
   `PREFIX_TREND_ORGS_WEEKLY`
2. New CLI step that runs the existing per-week aggregation loop
   (similar to `kpi-weekly-charts.md` §canonical-shape but at tracker grain
   not KPI grain)
3. App `get_trend_data(player_id, weeks=4)` reads the pin, filters by
   player + last N weeks, returns the slice
4. Falls through to live DB for window > pinned year span

**Open question for design time:** Does the user want week-over-week as
a tracker page tab (selectable with same H/A toggle), or as a standalone
view? The pin shape is the same either way; UI placement determines
which page imports the helper.

#### Combined matrix size if all three ship

If we eventually pin all of: H/A (3) × Hand (3) × Date Window (5) +
Trend (1 standalone), the per-tracker pin balloons from today's
**16 keys** → roughly **180 keys** + trend (1). Storage is still small
(parquet compresses), but write time stretches to ~30–60 min per
tracker per year.

**Mitigations to consider before that point:**
- Pin only the most-used permutations (e.g., All-H/A × All-Hand × Season +
  current selectable hand splits). Skip the long tail of L/R × Home × L7
  combinations until evidence shows they're hit.
- Move to DB-side materialized table (§11.2 Step 3). At that storage
  scale, materializing once per night and querying is more efficient than
  pre-computing every permutation client-side.

**Don't ship all three at once.** Build handedness first (highest demand),
add date windows next (most operational value), trend last (nice-to-have).
Re-evaluate matrix size and refresh cost after each ships.

#### Status: queued, no shipped code

Apr 29 2026: User flagged these as upcoming. None are blocking, none have
a deadline. When the ask comes in concretely ("we need vs L splits in the
hitter tracker by Friday"), open this section + §5.7 schema-evolution
playbook + §12.9 Spring template, and pick whichever expansion is needed.
The infrastructure (pin gates, legacy fallback, deploy automation) already
supports adding new bundle-key dimensions cleanly — no architectural
rework required.
