# DuckDB A/B Pilot — OF/IF Fielding Tracker

**Status:** Goal spec for autonomous execution next session.
**Owner:** Zac Bridger (PD analyst)
**Created:** 2026-05-27
**Worktree:** `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles`
**Branch:** `feature/astros-intangibles`

---

## THE FULL PROMPT (hand this to next-session Claude)

### GOAL — THE FINAL OUTCOME

Ship a DuckDB-backed query path for OF/IF fielding tracker that runs **alongside** the current combo-precompute path (toggle in sidebar), passes parity diag against the existing pooled SQL path to ±0.05 mph on every percentile metric, and reduces pin-build time from ~2 days to ~30–45 min per (domain, year). Current joblib pin write stays untouched — DuckDB is dual-write only during pilot. After 1 week of A/B use, Zac decides keep / revert / iterate.

### CONTEXT

**Project:** Intangibles Affiliate Tracker — OF + IF fielding leaderboards on Posit Connect. Coaches click multi-level + multi-year scopes; current architecture pre-computes 120 level-combos × 2 prefixes × 3 H/A × 4 multi-year ranges per (domain, year) to make multi-level Org Rankings + Indiv Leaderboard tabs feel instant. Build takes ~12 hrs per (domain, year) and Connect-scheduled deploys hit nbconvert/rsconnect log-tail timeouts during the long pin job.

**Stack:** Python 3.11, Streamlit, pandas 2.3, numpy 1.26, joblib pins on Posit Connect, SQL Server via pyodbc/FreeTDS. Adding: `duckdb` (≥ 0.10), `pyarrow` (≥ 16.1 — same version as `pd-goals/connect_pins_defense`).

**Current state:**
- Fielding pin CLI = `intangibles/scripts/pin_fielding_tracker_seasons.py` (365 lines, writes ~3,630 keys per (domain, year)).
- Canonical pooled SQL = `intangibles/src/fielding_tracker_data.py::_get_pooled_org_stats` + `_get_pooled_indiv_stats` (~line 4759).
- Raw_obs Python compute = `_compute_pooled_from_raw_obs` + `_compute_pooled_org_from_raw_obs` (~line 3894).
- App dispatch = `intangibles/src/fielding_tracker_page.py::_load_org_rankings_pooled` + `_load_indiv_leaderboard_pooled` (~line 180–215). 3-tier cascade: combo-precompute pin → raw_obs pin → live SQL.
- Parity diag = `intangibles/scripts/diag_pooled_parity.py` (compares raw_obs Python vs PERCENTILE_CONT SQL — already validates ±0.05 mph).
- Connect content = `intangibles-pin-tracker-2026-fielding` (GUID `f28bc164-2a0a-42d0-aef7-f90532b5624e`). Schedule: every 6 hr.

**Working dir:** `C:\Users\Owner\bsb-wt-intangibles\astros-intangibles\intangibles\`

**Constraints:**
- ZERO touch to other 4 trackers (Barrelsville hitter, Arm Farm pitcher, BR, Catcher) during pilot.
- ZERO removal of existing joblib pin write — DuckDB is ADDITIVE (dual-write).
- ZERO change to default app path — current users see current behavior unless they tick the sidebar toggle.
- Bailout = delete the new DuckDB module + revert one sidebar widget. No state pollution if pilot fails.
- Must work on Posit Connect's Linux container (Python 3.11.1, no native compile available).
- Must work on Zac's work laptop (Windows, Python 3.13, FreeTDS for DB) for pin CLI runs.
- Pin CLI runs on work laptop only (no DB access from personal laptop). App tested locally on personal laptop then deployed.
- No new Connect content unless absolutely necessary — reuse existing fielding pin content's schedule + Vars.

**Audience:** Zac (sole PD analyst). Pilot validates the architecture; coaches don't see the toggle yet (or see it labeled "experimental — do not use").

---

### SUCCESS CRITERIA — ALL MUST BE TRUE

1. **Pin CLI dual-writes successfully.** `pin_fielding_tracker_seasons.py --year 2026` finishes in ≤ 45 min per (domain, year), writes both the existing joblib bundle AND 6 new parquet pins (3 tables × 2 domains: `raw_tdm`, `raw_dcbp`, `raw_games`). Existing joblib bundle byte-equivalent to a pre-change run.
2. **DuckDB query path returns shape-identical DataFrames.** `intangibles/src/fielding_duckdb.py::get_org_rankings_pooled_duckdb` and `get_indiv_leaderboard_pooled_duckdb` return DataFrames with identical column names + dtypes + row counts as `fielding_tracker_data.get_org_rankings_pooled` / `get_indiv_leaderboard_pooled` for the same args.
3. **3-way parity passes ±0.05 mph.** Extended `diag_pooled_parity.py` runs raw_obs Python ↔ PERCENTILE_CONT SQL ↔ DuckDB on test cases: (a) Hector Salas multi-level 2026 [Low A + A+ + AA], (b) Nunez Arm 2025+2026 multi-year AAA, (c) HOU IF 4-MiLB pool single year 2026, (d) HOU OF all 7 levels multi-year. All 4 cases match within ±0.05 mph on every percentile metric, ±0.01 on SUMs (OAA, FramRAA, PAA Cal), ±0.5 on counts.
4. **Sidebar toggle works.** New checkbox in `fielding_tracker_page.py` sidebar: "🧪 DuckDB backend (experimental)". Default OFF. When ON, `_load_org_rankings_pooled` + `_load_indiv_leaderboard_pooled` dispatch to the DuckDB path. When OFF, current 3-tier cascade. Toggle persists across page changes via `st.session_state`.
5. **First-click latency ≤ 10 sec (cold), ≤ 1 sec (warm).** First click after session start downloads parquets + loads into DuckDB (target ≤ 10s). Subsequent clicks on any combo (single-year, multi-year, single-level, multi-level) target ≤ 1s. Measured via `time.perf_counter` printed to Streamlit info bar when toggle is ON.
6. **Connect deploy succeeds without nbconvert/rsconnect timeout.** New deploy bundle includes `duckdb` + `pyarrow` in `requirements.txt` + `manifest.json`. Deploy completes; app launches; toggle visible in sidebar. Pin CLI deploy unchanged (no DuckDB needed in `connect_pins_fielding/`).
7. **Final deliverable runs without errors.** End-to-end smoke: re-pin 2026 on work laptop → deploy app → flip sidebar toggle → click "All 7 levels, 2025+2026" → see populated org rankings + indiv leaderboard with sensible values matching current path.
8. **Proof artifact.** Commit a parity diag log showing 4 test cases passing, screenshot of toggle in sidebar, screenshot of populated tab under DuckDB backend, build-time before/after numbers in a graduation log entry.

---

### OPERATING RULES — NON-NEGOTIABLE

- **PLAN FIRST.** Output a numbered TaskCreate list of every step before touching code. Update task status to `in_progress` when starting, `completed` when done.
- **WORK AUTONOMOUSLY.** Don't ask clarifying questions unless paralyzing blocker. Defaults below cover all open questions.
- **SELF-VERIFY.** After every edit run: (a) the parity diag, (b) a Python smoke import (`python -c "from src.fielding_duckdb import get_org_rankings_pooled_duckdb; print('OK')"`), (c) for pin CLI changes, a single-year dry-run.
- **DEBUG YOURSELF.** If parity fails, diagnose by printing intermediate values per fielder. Don't shrug back to user. Common drift sources: float dtype differences (cast everything to float64 before compare), NaN handling (DuckDB nulls vs pandas NaN), percentile interpolation method (DuckDB default = linear, matches numpy default).
- **USE EVERY TOOL.** Read existing files (especially `_get_pooled_org_stats` SQL — copy it verbatim into DuckDB), grep for callers before changing signatures, run smoke tests at every checkpoint.
- **NO PLACEHOLDERS.** Every function written must work end-to-end. No `pass`. No `# TODO`. No mocked return values.
- **PROGRESS LOG.** Use TaskCreate/TaskUpdate religiously. Mark blockers explicitly.
- **STAY ON GOAL.** If you find other bugs in fielding code, log them in a follow-up memory file but don't fix them in this PR.
- **IF BLOCKED.** Log the wall, continue everything parallelizable. Only stop entirely for an irrecoverable dependency issue (e.g., DuckDB wheel won't install on Connect's Python 3.11.1).
- **CHECK SUCCESS BEFORE STOPPING.** Re-read the 8 success criteria. Confirm each is met. If any fail, fix before claiming done.
- **NEVER REMOVE THE JOBLIB PIN WRITE.** Dual-write. Both pins must coexist. The current path stays the user-visible default until Zac flips the toggle.

---

### ARCHITECTURE DECISIONS — LOCKED (don't second-guess)

**Parquet pin naming convention:**
- `zbridger/intangibles_of_raw_tdm_<year>` (e.g., `_2026`)
- `zbridger/intangibles_of_raw_dcbp_<year>`
- `zbridger/intangibles_of_raw_games_<year>`
- Same 3 for `if` domain.
- 6 pins per (year, pin run). Type = `"parquet"`. Each table has `ha_split` as a COLUMN (values: 0/1/NULL for home/away/all — match current `_get_raw_X` query's `ha_split` arg semantics; `NULL` = "all" combined).
- Multi-year app load: DuckDB `read_parquet([list_of_year_paths])` reads multiple pin downloads as one virtual table. Concat happens at SQL level, not Python.

**File layout:**
- New module: `intangibles/src/fielding_duckdb.py` — connection cache, parquet load, query helpers.
- Modify: `intangibles/scripts/pin_fielding_tracker_seasons.py` — add parquet write block after existing joblib write.
- Modify: `intangibles/src/fielding_tracker_page.py` — add sidebar toggle, dispatch logic in `_load_org_rankings_pooled` + `_load_indiv_leaderboard_pooled`.
- Modify: `intangibles/scripts/diag_pooled_parity.py` — add 3rd path comparison.
- Modify: `intangibles/requirements.txt` — add `duckdb>=0.10.0,<2.0.0` and `pyarrow==16.1.0` (if not already there).
- Modify: `intangibles/manifest.json` — register both new files (`src/fielding_duckdb.py`) and bump packages block.
- No change to `connect_pins_fielding/deploy.ps1` or `connect_pins_fielding/requirements.txt` — pin CLI doesn't need DuckDB.

**Cache strategy:**
- `@st.cache_resource` on the DuckDB connection (persists across sessions on same Connect worker).
- Local cache directory: `~/.bsb_cache/duckdb_pins/<domain>_<table>_<year>.parquet`. On read, check if cached file's mtime > 6 hr → re-download from Connect pin. Mirrors Connect schedule cadence.
- `@st.cache_data(ttl=21600)` on the per-query DuckDB result wrappers (`get_org_rankings_pooled_duckdb` etc.) — same TTL as current `_load_org_rankings_pooled`.

**DuckDB query pattern:** Port `_get_pooled_org_stats` SQL verbatim. Replace `Astros.Tracking_Defensive_Metrics` table references with `read_parquet('cache/raw_tdm_<year>.parquet')` (or multi-year list). Replace `Astros.Defense_Combined_By_Pos` with `read_parquet('cache/raw_dcbp_<year>.parquet')`. Same `PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY arm_strength) OVER (PARTITION BY fielder_id)` syntax — DuckDB supports it natively.

**Feature flag:**
- Sidebar checkbox: `st.checkbox("🧪 DuckDB backend (experimental)", key="_use_duckdb_backend", value=False)`
- Placement: bottom of sidebar, separate from existing filters, with caption `"For Zac's A/B test. Leave OFF for production."`
- Dispatch in `_load_org_rankings_pooled` + `_load_indiv_leaderboard_pooled`: `if st.session_state.get("_use_duckdb_backend"): use DuckDB path; else: existing cascade`.

**Parity tolerance:**
- Percentile metrics (Arm P99, Exch P10, TopSpd P95, React P25, AccelCU P75, AccelCD P75, etc.): ±0.05 (mph for arm/top_speed; seconds for react/exch; m/s² for accel — same units as displayed).
- Cumulative SUM (OAA, FramRAA, BlockRAA, PAA Cal): ±0.01 (these are exact sums; should match within float noise).
- Counts (n_arm, n_react, n_plays, comp_plays): ±0.5 (integers; tolerance accounts for boundary cases at range filters — but in practice should be 0).
- ROW COUNT (per fielder): must match exactly. If one path drops a fielder the other includes, that's a bug.

**Test cases for parity diag (extend `diag_pooled_parity.py`):**
1. Hector Salas multi-level 2026 (`gc_id` from existing memory, 3 levels)
2. Nunez Arm multi-year (need `gc_id`; pull from existing memory or roster)
3. HOU IF 4-MiLB pool single year 2026 (org='hou', levels=['aaa','aax','afa','afx'], season=2026)
4. HOU OF all 7 levels multi-year (org='hou', levels=['mlb','aaa','aax','afa','afx','rok','dsl'], seasons=[2025,2026])
5. (Optional, if time) DSL only 2026 (sanity check on single small-pool case)

---

### EXECUTION PHASES — PLAN BEFORE TOUCHING CODE

**Phase 0 — Prep (15 min)**
1. Read these rule files completely:
   - `.claude/rules/tracker-parquet-pins.md` (especially §5.17 pyarrow + §5.15 deploy bundle sync + §5.16 init.py stub)
   - `.claude/rules/pooled-percentile-pattern.md` (full doc — this is the math contract)
   - `.claude/rules/multi-level-rollup.md` (TWO-TIER ARCHITECTURE block at top)
   - `.claude/rules/three-surface-parity.md` (parity invariants)
2. Read these existing impl files:
   - `intangibles/src/fielding_tracker_data.py` lines 4759–5048 (the canonical pooled SQL queries)
   - `intangibles/src/fielding_tracker_data.py` lines 3894–4072 (raw_obs Python compute, for reference comparison)
   - `intangibles/scripts/pin_fielding_tracker_seasons.py` (where to inject parquet write)
   - `intangibles/scripts/diag_pooled_parity.py` (how to extend with 3rd path)
   - `intangibles/src/fielding_tracker_page.py` lines 180–215 (where to add toggle dispatch)
3. Verify on work laptop or via `Bash` from personal: `python -c "import duckdb, pyarrow; print(duckdb.__version__, pyarrow.__version__)"` — install if missing.

**Phase 1 — Dual-write pin CLI (target: 1 work session)**
4. In `intangibles/scripts/pin_fielding_tracker_seasons.py`, after the existing `write_tracker_bundle(...)` call, add a parquet write block:
   - For each H/A split in (None, 0, 1), call existing `_get_raw_tdm` / `_get_raw_dcbp` / `_get_raw_games` (reuses results already in memory if structured right — refactor to compute once, write twice).
   - Tag each row with `ha_split` column (None → -1 sentinel since parquet can't easily hold mixed-null int; or keep null and let DuckDB handle).
   - Decision: use Int8 nullable column for `ha_split` (DuckDB handles parquet nulls cleanly).
   - Concat the 3 H/A variants into one DataFrame per (domain, table_kind), write as parquet via `board.pin_write(df, name=..., type="parquet")`.
   - 6 pins per (year, pin run). Print row count + write time per pin.
5. Test: `python intangibles/scripts/pin_fielding_tracker_seasons.py --year 2026 --domain OF --dry-run` (or whatever single-domain flag exists; add one if not). Verify parquet pin names + sizes look reasonable. Should add ≤ 5 min to total run time (parquet write is cheap; the SQL queries are the bottleneck and they were already running).

**Phase 2 — DuckDB query module (target: 1 work session)**
6. Create `intangibles/src/fielding_duckdb.py`:
   - `_DUCKDB_CACHE_DIR = Path.home() / ".bsb_cache" / "duckdb_pins"` (create if missing)
   - `_get_pin_cache_path(domain, table, year)` — returns local path, downloads from Connect if mtime > 6 hr or missing
   - `_get_duckdb_connection()` — `@st.cache_resource`, returns `duckdb.connect(":memory:")` with PRAGMA threads = 4
   - `get_org_rankings_pooled_duckdb(domain, level_codes, season, sched_types=("R",), ha_split=None)` — mirrors `get_org_rankings_pooled` signature, returns identical DataFrame shape
   - `get_indiv_leaderboard_pooled_duckdb(domain, level_codes, seasons, sched_types=("R",), ha_split=None)` — same pattern
   - Both implement the same two-stage CTE as `_get_pooled_org_stats`: `per_fielder` with `PERCENTILE_CONT OVER (PARTITION BY fielder_id)`, then `org_agg` with `SUM(metric * n_X) / SUM(n_X)`. Port the SQL literally — DuckDB is PostgreSQL-flavored and the SQL Server syntax we use translates 1:1 for these operations.
7. Smoke test from PowerShell on personal laptop: `python -c "from src.fielding_duckdb import get_org_rankings_pooled_duckdb; df = get_org_rankings_pooled_duckdb('OF', ['aaa','aax'], 2026); print(df.head())"` — should NOT work yet because no DB access from personal; expect Connect-side error on pin download. That's fine — only proves import + connection logic.

**Phase 3 — Parity diag extension (target: half session)**
8. Modify `diag_pooled_parity.py`:
   - Add 3rd path C: DuckDB. Wire `_compute_pooled_from_raw_obs` (Path A), `_get_pooled_org_stats` SQL (Path B), DuckDB (Path C).
   - Extend `_diff_report` to handle 3-way: A vs B, A vs C, B vs C.
   - Add 4 test cases listed above (Salas, Nunez, HOU IF 4-MiLB, HOU OF 7-level multi-year).
   - Exit 0 only if all 3 pairwise diffs pass ±0.05 mph.
9. Run on work laptop after pin CLI re-runs. Must pass before Phase 4.

**Phase 4 — App toggle + deploy (target: half session)**
10. In `intangibles/src/fielding_tracker_page.py`:
    - Add sidebar checkbox bottom of sidebar: `st.checkbox("🧪 DuckDB backend (experimental)", key="_use_duckdb_backend", value=False, help="A/B test path. Default OFF.")`.
    - In `_load_org_rankings_pooled`: if `st.session_state.get("_use_duckdb_backend"):` import + call DuckDB path; else existing cascade.
    - Same for `_load_indiv_leaderboard_pooled`.
    - Both paths return same shape DataFrame so downstream rendering needs no changes.
11. Add `duckdb>=0.10.0,<2.0.0` and `pyarrow==16.1.0` to `intangibles/requirements.txt`.
12. Add `src/fielding_duckdb.py` to `intangibles/manifest.json` files block. Add `duckdb` + `pyarrow` to packages block (mirror Defense Matrix pattern from `pd-goals/connect_pins_defense/deploy.ps1`).
13. Bump first line of `intangibles/requirements.txt` comment with date to bust Connect cache.

**Phase 5 — Test + ship**
14. Local Streamlit smoke (personal laptop, no DB): launch app, flip toggle, confirm checkbox state persists, confirm fallback to current path when OFF.
15. Push branch. User pulls on work laptop.
16. User runs pin CLI on work laptop (one-time backfill of parquet pins for 2022-2026 historical years). Time it.
17. User redeploys app to Connect via standard `rsconnect deploy` flow.
18. User flips toggle, clicks multi-level + multi-year scopes, eyeballs values vs OFF, reports parity issues if any.
19. Commit graduation log entry to `.claude/rules/.graduation-log.md` with build time before/after + decision matrix for the 1-week eval period.

---

### COMMITS — ATOMIC + REVERTIBLE

- Commit 1: `feat(fielding): dual-write parquet pins alongside joblib bundle` — Phase 1
- Commit 2: `feat(fielding): DuckDB query module mirroring _get_pooled_org_stats` — Phase 2
- Commit 3: `test(diag): extend pooled parity diag with 3rd path (DuckDB)` — Phase 3
- Commit 4: `feat(fielding): sidebar toggle for DuckDB backend (experimental)` — Phase 4
- Commit 5: `chore(deps): add duckdb + pyarrow to intangibles app requirements` — Phase 4
- Commit 6: `docs(rules): graduation log entry for DuckDB A/B pilot launch` — Phase 5

Each commit independently revertable. If commit 4 breaks app, revert it alone; commits 1-3 are pure additions.

---

### WHEN DONE

- Code: clean, typed where types help, follows existing conventions (snake_case, `_private`, docstrings).
- Design: app sidebar shows the toggle with a clear "experimental" caption; toggle ON state visibly different (e.g., `st.info("🧪 DuckDB backend ACTIVE")` banner at top of Org Rankings tab when ON).
- Output: screenshots of toggle OFF + toggle ON showing identical-looking populated tables; parity diag log showing 4 test cases passing.
- Final deliverable: tested locally + deployed to Connect + toggle flippable + parity diag passes.

---

### FINAL DELIVERABLE CHECKLIST

- [ ] Confirmation each of the 8 success criteria is satisfied
- [ ] Every file created / modified listed
- [ ] Build time before / after numbers in graduation log
- [ ] Parity diag exit code 0 with log saved
- [ ] Screenshot of sidebar toggle
- [ ] Screenshot of Org Rankings tab populated under DuckDB backend
- [ ] How to run pin CLI / app / parity diag (one-liner each)
- [ ] Decisions made + anything Zac needs to know for the 1-week eval
- [ ] Known limitations + follow-ups (e.g., "if pilot wins, migration plan for other 4 trackers in separate spec")

---

### QUALITY BAR

Don't ship "kinda works." Ship "Zac flips the toggle, sees identical values, the page loads in ≤ 10s cold and ≤ 1s warm, and there are zero error banners or stack traces in the Streamlit page or Connect logs." Parity diag MUST exit 0. If you can't make it pass, stop and report the specific drift case — don't ship around it.

Begin by accepting your plan; never stop early without re-reading the 8 success criteria.

---

## OPEN QUESTIONS — NONE BLOCKING

All design decisions locked above. The only thing that could derail this is a Connect-side dependency issue (duckdb wheel won't install) — and even then, the bailout is "delete the new module, leave joblib path untouched, deploy."

If next-session Claude hits a genuine paralyzing blocker, flag it with:
1. Exact error message
2. What was attempted
3. Two proposed paths forward (with trade-offs)

Then continue everything parallelizable while waiting on Zac's call.

---

## FILES TO READ FIRST (in order)

1. `.claude/rules/pooled-percentile-pattern.md` — math contract
2. `.claude/rules/tracker-parquet-pins.md` §5.17 (pyarrow), §5.15 (deploy bundle), §5.16 (init.py stub)
3. `.claude/rules/multi-level-rollup.md` TWO-TIER ARCHITECTURE block
4. `intangibles/src/fielding_tracker_data.py:4759-5048` — canonical pooled SQL (the thing being ported to DuckDB)
5. `intangibles/scripts/pin_fielding_tracker_seasons.py` — pin CLI to extend
6. `intangibles/scripts/diag_pooled_parity.py` — parity diag to extend
7. `intangibles/src/fielding_tracker_page.py:180-215` — app dispatch site
8. Existing Defense Matrix deploy as reference for pyarrow: `pd-goals/connect_pins_defense/deploy.ps1`

---

## REFERENCE — WHY DUCKDB OVER ALTERNATIVES

- vs **SQLite**: SQLite has no native `PERCENTILE_CONT`. Would need Python fallback = same bottleneck we have now. Wrong tool.
- vs **revert to weighted-mean**: Faster to ship (~1 hr vs ~3 days) but accepts 1–3 mph drift on multi-year/multi-level percentile metrics. Zac primary view is multi-year multi-level — drift is visible.
- vs **trim POOLED_LEVEL_COMBOS to ~10 combos + drop multi-year backfill**: Smaller change (~50 lines) but still keeps the precompute layer architecturally. DuckDB is the structurally correct fix.
- vs **DB-side materialized table**: Right long-term answer but IT-dependent + slow to land. DuckDB is the in-house bridge.

---

*Saved to: `intangibles/docs/plans/2026-05-27-duckdb-fielding-pilot-goal.md`. Commit this file to `feature/astros-intangibles` so next-session Claude can find it via `Read` tool.*
