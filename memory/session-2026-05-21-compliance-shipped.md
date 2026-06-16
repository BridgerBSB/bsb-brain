---
name: session-2026-05-21-compliance-shipped
description: PD Engine Goal Compliance tab + pin support shipped. 6 commits on feature/pd-goals. User running pin CLI on work laptop at session close. Catcher snapshot + season/H2H NetK fix also shipped earlier same session.
metadata: 
  node_type: memory
  type: project
  originSessionId: 54c1afb6-242b-4907-ac5c-d2786d46085b
---

# May 21 2026 — PD Engine Goal Compliance + Catcher Season-Stats Fix

## Resume here

User is **running `python pd-goals/scripts/pin_compliance.py --season 2026`** on the work laptop at session close. They'll redeploy PD Engine after that. The Compliance tab should load from the pin instantly after.

Next session: ask if the pin run completed cleanly + the tab loaded fast. If yes → propose building `pd-goals/connect_pins_compliance/` Connect-scheduled bundle (deferred this session; ~30 min mechanical work per `rules/tracker-pin-connect-deploy.md` playbook).

## What shipped this session

### Track A — PD Engine Goal Compliance tab (NEW, on `feature/pd-goals`)

Six commits in order:

| Commit | What |
|---|---|
| `3594aa86` | Initial 3-tab layout (`🎯 Goals | ✅ Goal Compliance | 📤 Upload Goals`) + Compliance data layer + 8x3 matrix UI |
| `5bbd10fb` | Compound shape goals (FT IVB+HB, FC IVB+HB) — both legs must meet target. Single SQL fetch per goal. |
| `47d6ef8a` | **Critical bug fix:** `parse_goal()` doesn't take `player_type=` kwarg — was silently failing every parse. Plus `Platoon` enum → string coercion. Diagnostic strip added. |
| `eddccb69` | Pin support: `try_load_pinned_compliance` reader, `attach_pin_meta` writer, `compliance_pin(season)` helper, pin_compliance.py CLI. App reads pin first, falls back to live. |
| `8d1ba405` | Rename "Hitter" → "Position Player" column. Math unchanged (203 measurable goals across org). |
| `49e2880f` | Side-by-side layout: matrix left 42% + sortable colored Table right 58%. Status: Met (green) / Close ±5% (yellow) / Off (red) / Subjective (grey) / — (missing data, light grey). |

### Files created/modified

**NEW:**
- `pd-goals/src/compliance.py` — org compliance data layer
- `pd-goals/scripts/pin_compliance.py` — pin write CLI

**EDITED:**
- `pd-goals/pages/1_PD_Goals.py` — 3-tab layout + Compliance tab block (~200 lines added)
- `pd-goals/src/pins_config.py` — `compliance_pin(season)` helper
- `pd-goals/manifest.json` — registered new files for Connect deploy

### Architecture in one paragraph

App's Compliance tab → click "Compute compliance" button → `_cached_compliance(season, start_iso, end_iso)` (`@st.cache_data(ttl=3600)`) → **`try_load_pinned_compliance` first** (reads `zbridger/pd_compliance_<season>` parquet pin, validates `pin_season/pin_start_date/pin_end_date` cols match request, calls `_aggregate_from_detail`) → on miss/mismatch falls back to **`compute_compliance` live SQL path** (`get_pitcher_stats` / `get_hitter_stats` per player × goal). Same `_aggregate_from_detail` builds the 8x3 matrix + counts from the detail DataFrame either way.

### Math definitions (locked)

- Compliance% = (# measurable goals MET) / (# measurable goals) per (level × type) cell
- Met: INCREASE → current ≥ target. DECREASE → current ≤ target. Target=0 → sign-only check. Damage targets ≥1.0 → /100 normalization.
- **Compound shape goals (FT/FC/SL IVB+HB)**: BOTH legs must meet. Either leg missing → whole goal excluded from denom.
- DESCRIPTIVE / subjective → excluded from %, counted in footer ("📌 N subjective…")
- Missing current value → excluded from denom (not counted as Off)
- Status bucket "Close" = within 5% of target (INCREASE: cur ≥ 0.95×target, DECREASE: cur ≤ 1.05×target). No Close zone for target=0.

### Layout

8 rows: DSL / FCL / A / A+ / AA / AAA / MLB / **Total**
3 cols: Pitcher / **Position Player** / Total
Right panel: sortable table with GC ID, Player, Level, P/H, Goal, Metric, Current, Target, Dir, Status

### Pin scheme

- Name: `zbridger/pd_compliance_<season>`
- Type: parquet (single DataFrame = detail rows + 4 meta cols)
- Meta cols on every row: `pin_season`, `pin_start_date`, `pin_end_date`, `pin_as_of`
- Window matching: reader validates exact (season, start, end) match — sidebar selection diverging from pin → live fallback
- Default CLI window: Jan 1 of season → today

### How to use (work laptop)

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "H9MB6feNB2ccKfmoX9Q3DS7AykVhvNNb"
cd C:\Users\zbridger\bsb-resources
git pull
python pd-goals/scripts/pin_compliance.py --season 2026
```

Then redeploy PD Engine. Compliance tab → Compute compliance → loads in <1s.

Re-run the CLI to refresh the pin (numbers shift daily as PAs accrue + goals get uploaded).

### Deferred (next session, fresh context)

**Connect-scheduled daily refresh:**
- `pd-goals/connect_pins_compliance/pin_compliance_2026.ipynb` (notebook wrapper)
- `pd-goals/connect_pins_compliance/deploy.ps1` (Mirror `connect_pins_defense/deploy.ps1` — pyarrow in requirements per `tracker-parquet-pins.md §5.17`, STUB `src/__init__.py` per §5.16, audit per §5.15)
- Sets `CONNECT_API_KEY`, `DB_USER`, `DB_PASS` in Vars tab
- Schedule: every 6 hours, runs `pin_compliance.main()` with `--season 2026 --start 2026-01-01 --end <today>`
- Source bundle: `database.py`, `pins_config.py`, `compliance.py`, `goals_loader.py`, `roster.py`, `goal_parser.py`, `stats.py`, `metrics.py`, plus their transitive deps — audit via `.claude/scripts/audit_pin_deploy.py` before deploy

Resume instruction: "build the connect_pins_compliance/ bundle for daily refresh" + point at `rules/tracker-pin-connect-deploy.md` + `pd-goals/connect_pins_defense/` as template.

### v1 caveats (in commit msgs)

- Tab requires a player selected (existing `st.stop()` at line 640 in `1_PD_Goals.py` still gates the tab bar). User accepted — they always have a player picked.
- Catcher/fielding-specific metric goals (NetK, PAA/EO, React, etc.) come back as `current=None` in v1 because `compute_compliance` only calls `get_pitcher_stats` / `get_hitter_stats` (not the catcher/defense merge that `fetch_player_stats` does). They appear in the detail table with Current = "—" and Status = "—", excluded from compliance %.

---

## Track B — Catcher season-stats + H2H fix (earlier same session, on `feature/astros-intangibles`)

Five commits on the intangibles worktree. **All catcher season stats now span ALL levels** (user direction: "level is only coloring"). H2H per-game team_id classifier rewritten.

| Commit | What |
|---|---|
| `9116aba3` | `--yoy` flag on `intangibles/scripts/generate_kpi_snapshot.py` (mirrors `--spring`, R season + R season-1, DSL-safe, `_compare_inverse` flag flips arrow direction) |
| `59c4be2f` | 6 catcher_data.py helpers stripped of level filter: `get_season_netk`, `get_season_throwing_summary`, `get_season_blocking_summary`, `get_augpop_season`, `get_season_catcher_depth`, `get_netk_vs_record`. New `SEASON_STAT_JUNK_LEVELS` constant. H2H rewritten with per-game `our_games` CTE so cross-level games classify "ours" correctly. |
| `cea8453b` | Same fix on catcher_percentiles.py: `get_player_depth_distribution`, `get_player_depth_distribution_by_side` (drive the Depth Table Season column). |
| `8670fe7e` | `_CATCHER_NETK_QUERY` had `{{sched_filter}}` (double-brace) instead of `{sched_filter}` → SQLSTATE 42000 syntax error → fixed |

Affects both `intangibles/pages/4_Catching.py` (Catching app) + `intangibles/scripts/generate_catcher_report.py` (postgame CLI) via shared helpers.

**League pool queries** (no `:catcher_gc_id` filter) in `catcher_percentiles.py` **stay level-scoped** for percentile coloring. Per-game stats untouched.

Catcher KPI snapshot CLI now runs clean — user verified.

### Auto-loaded rule files relevant to next session

Compliance work pulls in (via pd-goals/ path):
- `rules/pd-goals.md` + `rules/pd-goals-defense.md` + `rules/pd-goals-flag-tracker.md` + `rules/pd-goals-rolling-chart.md` + `rules/pd-goals-transition.md` + `rules/pd-goals-unmeasurable.md` + `rules/pd-goals-wpa-plays.md`
- `rules/tracker-parquet-pins.md` §5.16 (STUB __init__.py), §5.17 (pyarrow), §5.15 (audit_pin_deploy)
- `rules/tracker-pin-connect-deploy.md` (playbook for connect_pins_compliance/ bundle)
