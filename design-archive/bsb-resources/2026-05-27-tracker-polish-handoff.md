# Tracker Polish Session — Work-Laptop Handoff + Test Checklist

**Date:** 2026-05-27
**Branches touched:** `feature/barrelsville`, `feature/bullpen-reports`, `feature/astros-intangibles`, `feature/pd-goals`
**Apps affected:** Barrelsville (hitter), Arm Farm (pitcher), BR, Fielding (OF + IF), Catcher — all 5 affiliate trackers
**Re-pin required:** No (see "Pin decision" below)

---

## What shipped this session (universal polish + DSL split propagation)

### Universal across all 5 trackers

| # | Change | Why |
|---|---|---|
| U1 | **DSL split toggle** on Org Rankings tab | Sub-team rows when DSL is in selected level set (Off / Split radio) |
| U2 | **CLUBSHORTNAME sub-team labels** | Renders `HOU - DSHOUB` / `HOU - DSASOR` / `COL - DSCOL` etc. — works for all 30 orgs |
| U3 | **Level Pools tab always renders all 7 levels** | Sidebar level filter intentionally ignored on that tab — it's a reference panel |
| U4 | **HOU bold on sub-team rows** | `.str.startswith("HOU")` mask covers `HOU - DSHOUB` / `HOU - DSASOR` etc. |

### Barrelsville-only

| # | Change | Why |
|---|---|---|
| B2 | **Stat (Rank) HOU sub-tab fix** | Was rendering `-` for every metric cell. Added missing Stat (Rank) branch to HOU sub-tab's inline display builder. |
| B4 | **Extended `league_distributions` pin** (infrastructure only — no consumer change) | Added compute helper + extended `_LEAGUE_DIST_METRICS_ALL` covering all ~30 pool metrics. **DORMANT** — no current app code reads the extended dict. See "Pin decision" below. |

### Per-tracker DSL split known limitations (v1, by design)

| Tracker | Limitation |
|---|---|
| Arm Farm | IP/S + AOL inherit parent org value on sub-team rows (gamelog helpers query at team granularity) |
| Fielding | Pooled multi-level SQL path bypassed when DSL split ON (multi-level + DSL-split combination falls to live single-year compute) |
| Catcher | Per-catcher merged metrics (`framing_raa`, `blocking_raa`, `surpp`, `blocking_raa_650`) inherit parent org value on sub-team rows. Org-direct metrics (NetK, framing buckets, R2K%, throwing P99, pop, augpop, depth) DO split correctly. |

---

## Commits trail (most recent → oldest per branch)

### `feature/barrelsville` (Barrelsville hitter)

| Commit | What |
|---|---|
| `488a4915` | Graduation log sync |
| `872886e7` | B4 — extended `league_distributions` pin (dormant infrastructure) |
| `b55d341d` | B3/U3 — Level Pools always 7 levels |
| `b50fd179` | B2 — Stat (Rank) HOU sub-tab fix |
| `6047444d` | B1/U2 — CLUBSHORTNAME labels |
| Earlier session | DSL split data + UI (pilot ship), HOU bold mask |

### `feature/bullpen-reports` (Arm Farm pitcher)

| Commit | What |
|---|---|
| `04c90805` | Graduation log sync |
| `2381ec6d` | U3 — Level Pools always 7 levels |
| `6140e4f8` | DSL split + CLUBSHORTNAME + HOU bold mask (full port) |

### `feature/astros-intangibles` (BR + Fielding + Catcher)

| Commit | What |
|---|---|
| `9b8cc1b0` | Graduation log sync |
| `2afd9e1b` | U3 — Level Pools always 7 levels (all 3 trackers) |
| `c8cd3f56` | DSL split — Catcher |
| `9d5d46ec` | DSL split — Fielding (OF + IF) |
| `19571ed8` | DSL split — BR |

### `feature/pd-goals` (main repo, docs only)

| Commit | What |
|---|---|
| `b7e3cf51` | Graduation log entry |
| `9500e605` | Discovery SQL fix |
| `5a96bcb9` | Rule docs + discovery SQL |

---

## Pin decision — re-pin is OPTIONAL, recommended SKIP

I flip-flopped on this during the session. Final honest state:

- The B4 extended `league_distributions` pin is **infrastructure only**. No app code currently reads the extended dict (Level Pools tab still computes `np.percentile` inline from `full_df`; per-batter percentile coloring still uses `pandas.rank()` at app load time).
- Running `python barrelsville/scripts/pin_tracker_seasons.py --league-only` populates the extended dict (~15-25 min). Pin gets richer data nobody reads. Safe, no regression, but no user-visible win.
- Skipping the re-pin = pin stays at 3 pre-existing metrics (`bb_pct`, `k_bb_pct`, `wrc_plus`). Existing consumers (per-batter bisect-percentile coloring for those 3 metrics) keep working.

**Recommendation: SKIP the re-pin.** Phase 2 (wiring the Level Pools tab + per-batter percentile coloring to consume the extended pin) is a separate refactor — when that lands, run `--league-only` then.

---

## Work-laptop ladder (in order)

```powershell
# 1. Pull all 3 worktrees
cd C:\Users\zbridger\bsb-wt-hitting && git pull
cd C:\Users\zbridger\bsb-wt-bullpen && git pull
cd C:\Users\zbridger\bsb-wt-intangibles\astros-intangibles && git pull

# 2. Redeploy each app via rsconnect (your standard deploy flow per app)

# 3. (SKIP unless populating extended pin for future Phase 2 use)
#    $env:CONNECT_API_KEY = "<key>"
#    cd C:\Users\zbridger\bsb-wt-hitting
#    python barrelsville/scripts/pin_tracker_seasons.py --league-only
```

DSL split is live-DB by design v1 — no pin involvement on any of the 4 newly-ported trackers. Per-tracker pin CLIs (`pin_*_tracker_seasons.py`) are byte-identical to before this session (except Barrelsville's `_run_league_dists`, which extended the helper but stays back-compat).

---

## Test checklist (per deployed app)

### Universal — run on ALL 5 trackers after redeploy

For each of Barrelsville / Arm Farm / BR / Fielding / Catcher:

#### Org Rankings tab

- [ ] **DSL toggle HIDDEN** when DSL is NOT in your selected level set
- [ ] **DSL toggle visible (Off default)** when DSL IS selected
- [ ] **Toggle OFF** → exact same row count as before (30 orgs at single-level DSL)
- [ ] **Toggle SPLIT → ALL sub-tab** → 30+ rows; HOU shows as `HOU - DSHOUB` + `HOU - DSASOR`; other multi-team DSL orgs (Dodgers, Cardinals, etc.) show real CLUBSHORTNAME suffixes (no `Team N` placeholder)
- [ ] **Toggle SPLIT → HOU sub-tab** → DSL row expands into 2 rows (`DSL - DSHOUB`, `DSL - DSASOR`); other 6 affiliate rows unchanged → 8 rows total
- [ ] **Sort by metric** → sub-team rows scatter naturally
- [ ] **Sort by ORG column header** → sub-teams group adjacent under parent org
- [ ] **HOU bold** on ALL `HOU - <SHORTNAME>` rows (verify across ALL + HOU sub-tabs)
- [ ] **H/A toggle** orthogonal to DSL split (works in both states)

#### Level Pools tab

- [ ] **All 7 levels render** even when sidebar has fewer selected (try: select 1-2 levels in sidebar, switch to Level Pools, confirm MLB/AAA/AA/A+/A/Rookie/DSL all visible)
- [ ] **Empty-selection guard** still works for metrics ("Select at least one metric in the sidebar") — but level guard is gone

#### Leaderboard + Trends + Trend Visuals tabs

- [ ] Existing behavior unchanged (no regressions from the session's changes)

### Barrelsville-only

- [ ] **Stat (Rank) display mode → HOU sub-tab on Org Rankings** populates real values (was rendering `-` for every metric cell). Should show `.385 (3)` / `11.8% (27)` style
- [ ] **Stat (Rank) on ALL sub-tab** unchanged from before (already worked)

### Per-tracker DSL split limitation checks (these are EXPECTED, not bugs)

- [ ] **Arm Farm**: when DSL split ON, both HOU DSL sub-team rows show the SAME `IP/S` and `AOL` value (both inherit parent org). v1 limitation, documented.
- [ ] **Fielding**: Multi-level + DSL split ON → falls back to single-year compute (multi-year pool path bypassed). Single-year + DSL split ON → works fine.
- [ ] **Catcher**: when DSL split ON, both HOU DSL sub-team rows show the SAME `FramRAA` / `BlockRAA` / `SurPP` / `BlockRAA650` (per-catcher merged metrics inherit parent org). NetK / framing buckets / R2K% / SteaL% / SBA / throwing P99 / pop / augpop / depth DO split correctly.

---

## What was NOT done this session (deferred)

1. **Stat (Rank) HOU "-" check on the other 4 trackers** — B2 was Barrelsville-only. The HOU sub-tab inline display builder pattern exists in other trackers and may have the same gap. Quick audit needed per tracker.
2. **Phase 2 — wire app to consume extended `league_distributions`** — refactor Level Pools tab + per-batter percentile coloring to read precomputed sorted lists / per-(batter, level) percentiles from pin instead of computing inline. Would eliminate `pandas.rank()` and `np.percentile` from the hot path. Real architecture work; deserves its own scoped goal.
3. **Per-tracker percentile pinning beyond Barrelsville** — none of the other 4 trackers have a `league_distributions` pin pattern at all (their `tracker_pins.py` explicitly says "No league_distributions"). Adding it would be new infrastructure per tracker.

---

## If anything fails in deployed app

1. **DSL toggle missing** when DSL is selected → check the app redeployed; verify the page file has the new `with tab_org:` block with DSL radio
2. **Sub-team labels show as `Team N`** → `_load_dsl_team_labels` either failed (DB error) or `CONNECT_API_KEY` issue at runtime; check Connect content logs
3. **HOU rows NOT bold on sub-team variants** → the `.startswith("HOU")` mask change didn't land; check the file for `_apply_percentile_bg` (or `_color_dataframe` in some trackers) HOU mask line
4. **Level Pools tab missing levels** → check that the `if _lc not in selected_level_codes: continue` block was removed from `with tab_pools:` in that tracker's page
5. **Barrelsville Stat (Rank) HOU still shows `-`** → check `pages/2_Affiliate_Tracker.py` around the HOU sub-tab block has the new `if at_display_mode == "Stat (Rank)":` branch

---

## Honest scoping note on session flip-flopping

I made several conflicting statements during the session about re-pinning:

1. Initial framing: "B4 extends the pin, re-pin required for full benefit"
2. Mid-session: "Re-pin required (--league-only, fast path)"
3. After user audit push: "Re-pin is optional — extended pin is dormant infrastructure with no consumer"

The final state (option 3) is correct based on actual grep audit. The earlier framings overstated the user-visible impact of B4. Apologies for the noise. The pin extension is unused; skip the re-pin unless populating for future use.
