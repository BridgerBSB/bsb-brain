---
name: session-2026-05-22-shipped
description: "May 22 2026 final wrap. 8 commits on feature/pd-goals — compliance decoupled from sidebar, parser fix for hitter-exclusive metrics, OSwing-FB-up-zone subset metric fully wired (pool + sample text). Supersedes session-2026-05-22-l14-aftermath.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: 2bd659b5-ff48-4e8a-a351-5f8ba1915d34
---

# May 22 2026 — Shipped (READ FIRST after /clear)

Long session. User started frustrated about L14 aftermath bugs, ended satisfied after Perez goal wired end-to-end. **8 commits on `feature/pd-goals`**, HEAD `934083bc`.

## Commits in order

| Commit | What |
|---|---|
| `377c438b` | (pre-session) defense + catcher NetK accept start_date/end_date — Trevor Austin React VALUE windowed |
| `187349f6` | get_threshold_counts: window-scoped fielding/PAA/EO/RoutineConv/NetK sample text (Bug A) |
| `1f1d062d` | compliance.py: passes start/end to catcher + defense fetches (initial Bug C fix) |
| `5944072a` | **compliance per-player goal window, season-keyed pin, no sidebar reactivity** (Bug E locked) |
| `e7df4b8a` | diag prints in fetch_player_stats + get_metric_value for hitter K%/BB% blank trace |
| `f58bead9` | **parser hitter-exclusive list** runs BEFORE pitching indicators — fixes "in zone" false-routing |
| `d46f313b` | new metric oswing_fb_up_zone (value + parser override for "FBs up in zone" qualifier) |
| `934083bc` | **full wiring**: percentile pool + sample text for oswing_fb_up_zone |

## Status of original 6 bugs (from session-2026-05-22-l14-aftermath.md)

| # | Bug | Status |
|---|---|---|
| A | T1 plays gray text doesn't update with window | ✅ Fixed `187349f6` |
| B | Hitter BB%/K% blank in Compliance | ⚠️ DIAG-ONLY (`e7df4b8a`) — awaiting user log paste after redeploy |
| C | NetK + RoutineConv blank in Compliance | ✅ Fixed `1f1d062d` + `5944072a` (re-pin required) |
| D | Handedness routing on hitter goals | ✅ Verified working pre-fix (`a7f3a263` yesterday handled it) |
| E | Compliance window semantics | ✅ LOCKED — per-goal-window from goals.csv (`5944072a`) |
| F | Trevor's React value across columns | ✅ User confirmed working |

## Key architectural decisions LOCKED today

### Compliance = pin-only, season-keyed
`try_load_pinned_compliance(season)` ignores start/end window args. Pin written by `pin_compliance.py` encodes per-player goal windows from goals.csv. Sidebar selector does NOT trigger Compliance recompute. **`_cached_compliance(_season)`** in 1_PD_Goals.py — no window in cache key.

On pin miss: returns empty matrix + `source='no_pin'` diag. NO 3-8 min live fallback on auto-load.

### Parser hitter-exclusive list (goal_parser.py)
Runs BEFORE pitching indicators in `detect_goal_type`. Catches hitter-only metrics so "in zone" / "on FBs" qualifiers don't false-route to PITCHING. List: oswing/zswing/zcon/zctct, damage, bat speed, xwoba, hard hit, barrel, heart swing, top 50. Bug history: Perez "Decrease oSwing% on FBs up in zone below 27.5%" was returning unparseable because "in zone" matched the pitching indicators first.

### oswing_fb_up_zone metric (NEW)
Carlos Perez goal May 22 2026. Filter: pitch_type IN (FF/FT/SI), plate_z >= 0.4467 * height_ft (2/3 up THIS batter's SZ via mlbam.players JOIN, no ceiling — anything above qualifies), called_strike_chance_mlb < 0.5 (OOZ).

5 touchpoints fully wired:
1. `stats.py::get_hitter_stats` — SUM(swings)/SUM(pitches) on subset, returns `oswing_fb_up_zone` key
2. `stats.py::_empty_hitter_stats` — None default
3. `stats.py::METRIC_MAP` — aliases (oswing_fb_up_zone, oswing_fb_upzone, oswing_fb_up_in_zone, etc.)
4. `stats.py::get_threshold_counts` — branch, unit = "FB hi OOZ"
5. `percentiles.py::PITCHFX_QUERY_TEMPLATES['oswing_fb_up_zone']` + `PITCHFX_METRIC_MAP` + division list (0-100 → 0-1) + `is_higher_better` (hitter wants lower)

Parser override (goal_parser.py): when extract_metric returns 'Oswing' AND text has both an FB qualifier ('fb'/'fbs'/'fastball') AND an up-zone qualifier ('up in zone'/'top 3rd'/etc.), override metric to 'Oswing_FB_UpZone'. Generic 'Oswing' goals unchanged.

Pool gate: 30 subset pitches (vs generic 200) because niche subset.

## Open / Pending

### Bug B — Hitter K%/BB% blank (DIAGNOSTIC SHIPPED)
`e7df4b8a` adds `[FETCH-HITTER]` and `[METRIC-LOOKUP]` prints. After user redeploys and views Kevin Alvarez / Luis Baez, the Connect logs will show:
- `pa_count = 0` → genuinely no PAs in window+platoon (not a code bug)
- `pa_count > 0 but k_pct = None` → kbb_query silently failing
- `pa_count > 0, k_pct = 25, value = None from METRIC-LOOKUP` → routing bug

User has NOT yet pasted logs. **Next session: ask user for the log lines first**, don't guess.

### Work-laptop steps required (NOT yet done as of session end)
User said "I'm at the house" — they have NOT pulled/re-pinned/redeployed yet for the latest commits.

1. `git pull` (gets through `934083bc`)
2. `python pd-goals/scripts/pin_compliance.py` (re-pin with new per-player window logic + parser fixes)
3. `.\pd-goals\connect_pins_compliance\deploy.ps1` (bundle redeploy so next scheduled refresh uses new code; remind: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` per session)
4. Redeploy main PD Engine app

## User feedback this session (encoded as preferences)

- "Don't make Compliance reactive to anything except the pin" → LOCKED architecture
- "Same shit needs to apply everywhere — value + percentile + grey text + CSV path" when wiring a new metric → 5-place checklist now baked into the new metric wiring
- User runs `pin_compliance.py` from work laptop manually; Connect scheduled bundle is the backup
- User explicit on Perez: "no cap on height — anything above the 2/3 cutoff" → floor-only filter confirmed

## Files touched this session (final state)

| File | What changed |
|---|---|
| `pd-goals/src/compliance.py` | Per-player goal window, season-keyed pin, window validation removed |
| `pd-goals/pages/1_PD_Goals.py` | Compliance tab pin-only read, decoupled from sidebar; diag prints |
| `pd-goals/src/stats.py` | get_threshold_counts windowed (fielding/catcher/NetK), oswing_fb_up_zone metric + threshold-counts branch, diag in get_metric_value |
| `pd-goals/src/goal_parser.py` | Hitter-exclusive priority list, Oswing→Oswing_FB_UpZone post-parse override |
| `pd-goals/src/percentiles.py` | Pool template for oswing_fb_up_zone, METRIC_MAP, division list, is_higher_better |
| `pd-goals/src/report.py` | (only commit `377c438b` — PDF generator catcher fetch passes start/end) |

## What NOT to do next session

- **Don't dispatch parallel agents.** User pushed back hard on bug-class shipped via parallel work earlier. Hands-on debugging only.
- **Don't fall back to live compute in `_cached_compliance`** — pin miss returns empty. Live would block 3-8 min on every sidebar change.
- **Don't reintroduce window validation** in `try_load_pinned_compliance`. Pin is season-keyed; per-player windows encoded in detail rows.
- **Don't restore "in zone" to a higher priority** than hitter-exclusive metrics in `detect_goal_type`. The order was deliberate.
- **Don't ask user to grep / paste logs without ASKING for the specific lines.** They want concrete asks, not "tell me what you see."
- **Don't defer anything to "tomorrow" / "sleep" / "morning"** — see `feedback_never_defer_to_tomorrow.md`. Banned phrases.

## Cross-references created/strengthened today

- `rules/pd-goals.md` — already has Per-PT Metric Expansion 5-Place Checklist + parser trap notes; oswing_fb_up_zone is the latest example
- `memory/feedback_never_defer_to_tomorrow.md` — referenced but not edited
- `memory/session-2026-05-22-l14-aftermath.md` — **SUPERSEDED by this file**. Delete on next memory-cleanup sweep.
