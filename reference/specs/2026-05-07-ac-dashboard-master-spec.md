# AC Dashboard — Master Spec

**Date:** 2026-05-07
**Status:** Active design — pre-build
**Branch:** `feature/astros-intangibles`
**Lives in:** `intangibles/pages/4_Catching.py` as a 4th sub-view (`?view=dashboard`)
**Audience:** HOU Player Development coaches + coordinators (internal only)
**Source inspiration:** https://kdbbeta85v2.netlify.app/ (KDB)
**Branding:** "AC" — Astros Catching (replaces KDB references)

---

## 1. Goal

Port KDB's catching dashboard into Intangibles, scoped to HOU org
catchers across all 7 affiliate levels. Visual fidelity to KDB; metric
fidelity to existing HOU data layer. Six tabs covering Catcher Cards,
Gameday, Pitch Calling, Pitchers, Stats, Scoreboard.

This is a 4th surface alongside existing Postgame / Tracker / KPI in
the Catching domain. It does NOT recompute metrics — every value comes
from the existing data modules and stays in three-surface parity.

---

## 2. Where it lives

### 2.1. Routing

`intangibles/pages/4_Catching.py` already routes via `?view=...`:

| Existing route | Module |
|---|---|
| `?view=postgame` | inline `_render_postgame()` in `4_Catching.py` |
| `?view=tracker` | `src/catching_tracker_page.render()` |
| `?view=kpi` | `src/c_kpi_page.render()` |
| (no view) | `render_domain_landing(...)` retro arcade tile grid |

**Adds:**

| New route | Module |
|---|---|
| `?view=dashboard` | `src/ac_dashboard/landing.render()` (no sub-tab, lands on tile grid) |
| `?view=dashboard&tab=cards` | `src/ac_dashboard/tab_catcher_cards.render()` |
| `?view=dashboard&tab=gameday` | `src/ac_dashboard/tab_gameday.render()` |
| `?view=dashboard&tab=pitch-calling` | `src/ac_dashboard/tab_pitch_calling.render()` |
| `?view=dashboard&tab=pitchers` | `src/ac_dashboard/tab_pitchers.render()` |
| `?view=dashboard&tab=stats` | `src/ac_dashboard/tab_stats.render()` |
| `?view=dashboard&tab=scoreboard` | `src/ac_dashboard/tab_scoreboard.render()` |

### 2.2. Hooks into `4_Catching.py`

Two surgical edits to `4_Catching.py`:

1. Import: `from src import ac_dashboard`
2. Routing block (line 1762+): add `elif _view == "dashboard":` branch
   that dispatches to `ac_dashboard.route(st.query_params.get("tab"))`.
   `ac_dashboard/__init__.py` exposes `route(tab_name)` which switches
   to the right tab module.

### 2.3. Hooks into `tracker_page.render_domain_landing`

`render_domain_landing()` in `src/tracker_page.py` currently renders
2-4 cards (postgame + tracker + optional kpi + optional weekly). Extend
to support an **optional 5th card "DASHBOARD"** via two new kwargs:

```python
def render_domain_landing(
    *,
    domain_title: str,
    postgame_desc: str, postgame_tag: str,
    tracker_desc: str, tracker_tag: str,
    kpi_desc: str = "", kpi_tag: str = "",
    weekly_desc: str = "", weekly_tag: str = "",
    dashboard_desc: str = "", dashboard_tag: str = "",  # NEW
    logo_b64: str = "",
):
```

If `dashboard_desc` provided, append a 5th `domain-card` linking to
`?view=dashboard`. Card title: `CATCHER DASH`. CSS already supports
arbitrary card counts via grid auto-flow.

**Only `4_Catching.py` passes the new kwargs** — other domains (BR/OF/IF)
are unaffected. Backwards compatible.

---

## 3. Module structure

```
intangibles/src/ac_dashboard/
├── __init__.py            # Exports `route(tab_name)`
├── styling.py             # CSS tokens + inject_css() (per visual-primitives.md)
├── components.py          # Shared component renderers
├── click_video.py         # Lifted from 4_Catching.py _handle_chart_click
├── selectors.py           # Shared sidebar: year + level multi + catcher select
├── landing.py             # ?view=dashboard (no tab) → 8-tile grid + leaders rail
├── tab_catcher_cards.py   # ?tab=cards
├── tab_gameday.py         # ?tab=gameday
├── tab_pitch_calling.py   # ?tab=pitch-calling
├── tab_pitchers.py        # ?tab=pitchers
├── tab_stats.py           # ?tab=stats
├── tab_scoreboard.py      # ?tab=scoreboard
└── data/
    ├── __init__.py
    ├── catcher_facts.py   # Per-catcher card data assembler (calls existing modules)
    ├── pitch_calling.py   # NEW: pitch mix pivots by count/hand/loc
    ├── pitchers.py        # NEW: per-catcher pitcher arsenal aggregator
    ├── scoreboard.py      # NEW: HOU affiliate slate fetcher
    └── leaders.py         # NEW: "Yesterday's Extra Strike Leaders" — HOU only
```

---

## 4. Data layer — what feeds each tab

| Tab | Reads from | New code? |
|---|---|---|
| Landing | `catching_tracker_data.get_catcher_leaderboard` (latest day NetK delta) + `data/leaders.py` | thin assembler |
| Catcher Cards | `catching_tracker_data.get_catcher_leaderboard` + `compute_percentile_ranks` + `get_yearly_catcher_stats` | thin assembler in `data/catcher_facts.py` |
| Gameday | `catcher_data.get_catcher_game_pitches` + `compute_framing_buckets` + `get_throws_data` + `get_blocks_data` (existing postgame stack) | reuse — no new SQL |
| Pitch Calling | `Astros.Pitches_View` aggregated by count × hand × pitch_type × catcher | **NEW** in `data/pitch_calling.py` |
| Pitchers | `catcher_data.get_pitchers_caught` + season-level pitcher arsenal aggregator | **NEW** in `data/pitchers.py` |
| Stats | `catching_tracker_data.get_yearly_catcher_stats` + `c_kpi_data` weekly trend (optional) | thin assembler |
| Scoreboard | `Astros.Schedule_View` filtered to HOU affiliates + game date | **NEW** in `data/scoreboard.py` |

**Three-surface parity invariant:** AC tabs READ from the same modules
that power Tracker / KPI / Postgame. They DO NOT redefine metrics. If
a future change to a metric in `catching_tracker_data.py` ships, AC
inherits it free. If a coach asks for a "different" calculation in AC,
that's a rejection — direct them to the canonical surface.

---

## 5. HOU scope filtering

### 5.1. Catcher pool

User direction: **all affiliates** — `mlb / aaa / aax / afa / afx / rok / dsl`.

Roster source: `catching_tracker_data.get_hou_catcher_ids(season)` —
already exists, returns set of HOU catcher gc_ids per season.

Year selector drives roster: pick year → `get_hou_catcher_ids(year)`
→ catcher dropdown filters to that set. Multi-year aggregation tabs
(Stats) iterate the per-year list and union.

### 5.2. Level scope

Multi-select (default: all 7). Mirrors existing tracker pattern.

### 5.3. Sched type

Default `R` (regular season). Selector available but hidden by default
under "Advanced filters" expander. AC dashboard is coach-facing — most
won't toggle.

---

## 6. Year + catcher selector chrome (shared across tabs)

Top of every tab page (under tab title): single horizontal row:

```
┌─────────────────────────────────────────────────────────────────┐
│ YEAR  [2026 ▼]   LEVELS [aaa, aax, afa, afx, rok, dsl ✕]        │
│                                                                 │
│ CATCHER  [Yainer Diaz ▼]   ← only on tabs that need single-c.   │
│                                                                 │
│ [▶ Advanced filters] (sched type, ha split, hand split)         │
└─────────────────────────────────────────────────────────────────┘
```

Implemented in `ac_dashboard/selectors.py::render_filter_chrome(...)`.
Returns a typed dict of selections that each tab consumes.

State in `st.session_state` keyed `ac_year`, `ac_levels`, `ac_catcher_id`.
Persists across tab switches. Catcher picker available on Cards / Gameday /
Pitch Calling / Pitchers / Stats; Scoreboard ignores it (uses date instead).

---

## 7. AC branding

Per `2026-05-07-ac-visual-primitives.md`:

- KDB neutral palette retained (greys, light blue-grey base `#dce3eb`)
- KDB green chips → **Astros orange `#EB6E1F`**
- Display headers + emphasis text → **Astros navy `#002D62`**
- 7-bucket framing palette → **LOCKED, do not swap** (canonical per
  `.claude/rules/intangibles.md`)

Branded as "AC — Astros Catching" or "Catcher Dash" depending on context:
- Landing page hero: "CATCHER DASH"
- Footer / source attribution: "Astros Catching"
- Internal documentation: "AC dashboard"

---

## 8. Build order

1. **Visual primitives module** — `ac_dashboard/styling.py`,
   `components.py`, `click_video.py` (lifted), shared infra. ~1 day.
2. **Selector chrome** — `selectors.py` (year/level/catcher). ~0.5 day.
3. **Landing** — 8-tile grid + leaders rail + filter chrome. ~1 day.
4. **Catcher Cards** — primary tab, defines hero card layout. ~3-4 days.
5. **Gameday** — per-game zone plot + click-to-video. Most plots
   already exist in postgame; rewrap for KDB layout. ~2-3 days.
6. **Pitch Calling** — new SQL aggregator + heatmap visuals. ~2-3 days.
7. **Pitchers** — pitcher arsenal × catcher pivots. ~2 days.
8. **Stats** — year-over-year tables + sparklines. ~1-2 days.
9. **Scoreboard** — slate listing + click-to-Gameday. ~1-2 days.
10. **Polish + parity audit** — verify every value matches its source
    surface. ~1 day.

**Total estimate:** 14-19 working days. Single dev. Phase 1 (1+2+3+4)
is the MVP "value moment" — Catcher Cards on its own delivers the
shareable scouting-card use case and the rest is incremental.

---

## 9. Three-surface parity callouts (BLOCKING)

Per `.claude/rules/three-surface-parity.md` (synced to all worktrees):

> Catcher metrics live in 3 surfaces (tracker, KPI weekly, PD-Goals
> org KPI). Any change to one MUST propagate to the other two before
> the commit ships.

**AC dashboard is a 4th VIEW, not a 4th SURFACE.** Every metric value
must trace back to one of the 3 canonical surfaces. Specifically:

- **FramRAA / BlockRAA / NetK / Pop2B / Arm / Exch / R2K%** — pull
  via `catching_tracker_data.get_catcher_leaderboard()` or
  `get_yearly_catcher_stats()`. Don't re-aggregate.
- **Framing buckets (E Stl / Stl / Mid+ / Exp / Mid− / Loss / B Loss)**
  — pull via `catcher_data.compute_framing_buckets()`. Don't re-bucket.
- **Throws + blocks per game** — pull via `catcher_data.get_throws_data()`
  / `get_blocks_data()`. Don't re-query.

The ONLY new aggregations AC introduces are:
1. **Pitch Calling pivots** (count × hand × pitch_type) — NEW shape, no
   parity exposure since no other surface aggregates it.
2. **Pitcher arsenal × catcher** (which pitchers each catcher caught,
   their pitch mix) — NEW shape, same logic.
3. **Scoreboard slate** (Schedule_View list) — read-only metadata.

These three are pure presentation aggregations and don't touch
catcher-defense metric definitions.

---

## 10. App ↔ Report parity

Future PDF export on Catcher Cards (Phase 3 of original plan — shareable
scouting card) MUST match the on-screen card pixel-for-pixel. Same
data, same layout, same colors. `.claude/rules/intangibles.md` rule.

For now: build the on-screen card first; PDF export deferred to a
follow-on phase. When PDF arrives, it lives in `ac_dashboard/pdf/` and
shares data assemblers with the on-screen card.

---

## 11. Performance + caching

### Tracker pin reuse

`catching_tracker_data.py` already pins per-(season, sched_types_R, ha=None)
to `zbridger/intangibles_catcher_tracker_2026` etc. AC dashboard calls
the wrapped public functions which auto-hit the pin. **Zero extra pin
work for Catcher Cards / Stats** at default filter state.

Filter combos that miss pin (multi-sched-type, hand splits, etc.)
fall through to live DB at slower cold load. Same as existing tracker.

### New data fetcher caching

`data/pitch_calling.py`, `data/pitchers.py`, `data/scoreboard.py` use
`@st.cache_data(ttl=300)` on all SQL fetches. Standard pattern.

Heavy-hitter pivot queries (Pitch Calling per-pitcher × per-count)
should consider parquet pin if cold load > 5 sec. Decide after first
build measures actual perf.

---

## 12. Open questions / decisions parked

[NOTE: collected from earlier conversations + tab specs]

| # | Question | Default if not answered |
|---|---|---|
| Q1 | KDB Catcher Cards screenshot for layout fidelity | Use available KDB visuals + screenshot rounds during build |
| Q2 | KDB Live (leaderboards) screenshot | Same |
| Q3 | Click-to-video URL source: `Astros.Video` direct vs MLB Film Room GraphQL | Use existing 3-tier fallback per `rules/video-angles.md` |
| Q4 | PDF export of Catcher Card — Phase 1 or follow-on? | Follow-on (after on-screen card lands) |
| Q5 | Mobile responsive (coaches on phone) — required? | Defer; build desktop-first |
| Q6 | Hotkey shortcuts (KDB has H/G/R/S/C/E/M) — port? | Defer; nice-to-have |
| Q7 | "Yesterday's leaders" rail data source — daily NetK delta from previous game day? Or top-of-week? | Yesterday's R-game NetK delta from last calendar day with HOU games |
| Q8 | Stance data (Savant CSV) — include in Phase 1 or defer? | Defer to Phase 2; existing 6 tabs don't need it |
| Q9 | Multi-year stats — stitched line chart per metric, or yearly columns? | Yearly columns + sparkline column to mirror KDB |
| Q10 | Sched type default — R only, or include S+E by default? | R only (matches existing tracker default) |

---

## 13. Tab spec index

Each tab gets its own spec file in this directory:

- `2026-05-07-ac-tab-landing.md` — Catcher Dash landing
- `2026-05-07-ac-tab-catcher-cards.md` — Catcher Cards (build first)
- `2026-05-07-ac-tab-gameday.md` — Gameday
- `2026-05-07-ac-tab-pitch-calling.md` — Pitch Calling
- `2026-05-07-ac-tab-pitchers.md` — Pitchers
- `2026-05-07-ac-tab-stats.md` — Stats
- `2026-05-07-ac-tab-scoreboard.md` — Scoreboard
- `2026-05-07-ac-visual-primitives.md` — Component / token library (foundation)

Read in order: visual-primitives → master-spec (this) → landing →
catcher-cards → other tabs.

---

## 14. What NOT to do

- **Don't recompute metrics inside AC.** Always read from
  `catching_tracker_data.py` / `catcher_data.py` / `c_kpi_data.py`.
- **Don't add a route under a new top-level page.** Stay inside
  `4_Catching.py` so the existing nav structure is preserved.
- **Don't fork the click-to-video pattern.** Lift `_handle_chart_click`
  into `ac_dashboard/click_video.py` and reuse.
- **Don't introduce a "dashboard-only" filter or scope semantic.**
  Year/level/sched_type all match what tracker uses.
- **Don't ship without verifying every value matches its source.**
  Open `?view=tracker` next to `?view=dashboard&tab=cards` for the same
  catcher and confirm cell-by-cell.
- **Don't put new metric SQL in `catching_tracker_data.py`.** AC's
  new fetchers (pitch_calling, pitchers, scoreboard) live in
  `ac_dashboard/data/` so they don't pollute the tracker module.
- **Don't deploy the dashboard before `Catcher Dash` card appears on
  the Catching domain landing.** Otherwise users won't find it.

---

## 15. Glossary / abbreviations

- **AC** — Astros Catching (this dashboard's brand)
- **KDB** — Kick Dirt Baseball (the source visual reference)
- **HiB / LiB** — Higher-is-better / Lower-is-better metric direction
- **CSC** — Called Strike Chance (zone probability per pitch)
- **gc_id / groundcontrol_id** — primary player ID across HOU codebase

---

## 16. References

- `.claude/rules/intangibles.md` — catcher framing palette, click-to-video, parity rules
- `.claude/rules/three-surface-parity.md` — 3-surface invariants
- `.claude/rules/kpi-roster-filter.md` — current-roster filtering pattern
- `.claude/rules/video-angles.md` — 3-tier URL fallback (Astros.Video → VN 'v' → VN 'a')
- `.claude/rules/tracker-parquet-pins.md` — pin caching layer
- `intangibles/pages/4_Catching.py` — host page
- `intangibles/src/tracker_page.py::render_domain_landing` — extend for 5th card
- `intangibles/src/catching_tracker_data.py` — primary data source (3786 lines)
- `intangibles/src/catcher_data.py` — postgame per-game data (1273 lines)
- `intangibles/src/c_kpi_data.py` — weekly KPI data (1028 lines)
- KDB site: https://kdbbeta85v2.netlify.app/
