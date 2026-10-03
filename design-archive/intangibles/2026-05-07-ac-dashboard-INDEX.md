# AC Dashboard — INDEX (start here)

**Date:** 2026-05-07
**Status:** Design complete · Build pending
**Branch:** `feature/astros-intangibles`
**Commits:** `63d54d4` (foundation) · `33a1f38` (tab specs) · this commit (index + parity)
**Author:** Design session 2026-05-07

---

## What this is

Single entry point for the Astros Catching ("AC") dashboard plan. Read
the docs in the order below. Every other AC doc references this one
as its table of contents.

The AC dashboard is a HOU-internal tool that ports the visual layout
of KDB (https://kdbbeta85v2.netlify.app/) onto our existing catching
data. Lives as a 4th sub-view in `intangibles/pages/4_Catching.py`
under `?view=dashboard`. Six tabs covering Catcher Cards, Gameday,
Pitch Calling, Pitchers, Stats, Scoreboard. Year/level/catcher
selectors. AC-branded.

**This is design phase.** No `.py` code has been written yet. All
tab specs include build checklists ready to execute when the user
gives the go.

---

## Read in this order

| # | Doc | Purpose | Lines |
|---|---|---|---|
| 1 | [`2026-05-07-ac-visual-primitives.md`](./2026-05-07-ac-visual-primitives.md) | Color tokens, typography, components — foundation referenced by all tab specs | ~270 |
| 2 | [`2026-05-07-ac-dashboard-master-spec.md`](./2026-05-07-ac-dashboard-master-spec.md) | Architecture, routing, module structure, data layer map, build order | ~310 |
| 3 | [`2026-05-07-ac-tab-landing.md`](./2026-05-07-ac-tab-landing.md) | Catcher Dash entry — 6-tile grid + extra-strike leaders rail | ~270 |
| 4 | [`2026-05-07-ac-tab-catcher-cards.md`](./2026-05-07-ac-tab-catcher-cards.md) | **BUILD FIRST** — single-catcher hero card | ~430 |
| 5 | [`2026-05-07-ac-tab-gameday.md`](./2026-05-07-ac-tab-gameday.md) | Per-game framing review w/ click-to-video | ~310 |
| 6 | [`2026-05-07-ac-tab-pitch-calling.md`](./2026-05-07-ac-tab-pitch-calling.md) | Pitch mix by count/handedness/zone — first new SQL | ~250 |
| 7 | [`2026-05-07-ac-tab-pitchers.md`](./2026-05-07-ac-tab-pitchers.md) | Pitcher arsenal × catcher pivot view | ~210 |
| 8 | [`2026-05-07-ac-tab-stats.md`](./2026-05-07-ac-tab-stats.md) | Year-by-year defensive (hitting deferred) | ~180 |
| 9 | [`2026-05-07-ac-tab-scoreboard.md`](./2026-05-07-ac-tab-scoreboard.md) | HOU affiliate slate — click to Gameday | ~250 |
| 10 | [`2026-05-07-ac-dashboard-parity-test-plan.md`](./2026-05-07-ac-dashboard-parity-test-plan.md) | Cell-by-cell verification protocol — required before any tab ships | ~210 |
| 11 | [`2026-05-07-ac-dashboard-prebuild-checklist.md`](./2026-05-07-ac-dashboard-prebuild-checklist.md) | Consolidated open questions — walk through with user before first code commit | ~260 |

Total: 11 docs, ~3200 lines of design.

---

## High-level summary

### What we're building

A new `?view=dashboard` route on `4_Catching.py` with six tabs:

```
Intangibles/
└── 4_Catching.py
    ├── ?view=postgame    (existing)
    ├── ?view=tracker     (existing)
    ├── ?view=kpi         (existing)
    └── ?view=dashboard   (NEW)
        ├── (no tab — landing 6-tile grid + leaders rail)
        ├── &tab=cards          → Catcher Cards
        ├── &tab=gameday        → Gameday
        ├── &tab=pitch-calling  → Pitch Calling
        ├── &tab=pitchers       → Pitchers
        ├── &tab=stats          → Stats
        └── &tab=scoreboard     → Scoreboard
```

Branded "AC — Astros Catching" in body, "CATCHER DASH" on landing.

### Where the code lives

```
intangibles/src/ac_dashboard/
├── __init__.py            # Exports route(tab_name)
├── styling.py             # CSS tokens + inject_css()
├── components.py          # Shared renderers
├── click_video.py         # Lifted from 4_Catching.py
├── selectors.py           # Year/level/catcher chrome
├── landing.py             # 6-tile grid
├── tab_catcher_cards.py
├── tab_gameday.py
├── tab_pitch_calling.py
├── tab_pitchers.py
├── tab_stats.py
├── tab_scoreboard.py
└── data/
    ├── __init__.py
    ├── catcher_facts.py   # Catcher Card data assembler
    ├── leaders.py         # Yesterday's extra strike leaders
    ├── pitch_calling.py   # NEW pitch mix aggregator
    ├── pitchers.py        # NEW pitcher arsenal aggregator
    └── scoreboard.py      # NEW slate fetcher
```

13 new files. Plus 2 surgical edits to existing files:
- `intangibles/pages/4_Catching.py` — add `elif _view == "dashboard"` branch
- `intangibles/src/tracker_page.py::render_domain_landing` — add optional `dashboard_desc/tag` kwargs

### What stays untouched

- All existing data modules (`catching_tracker_data.py`, `catcher_data.py`,
  `c_kpi_data.py`, `catcher_percentiles.py`, `catcher_report.py`)
- Existing `?view=postgame`, `?view=tracker`, `?view=kpi` routes
- Other domains (BR/OF/IF) — `render_domain_landing` extension is
  backwards-compatible
- Three-surface parity invariants — AC is a 4th VIEW, not a 4th SURFACE.
  Reads existing data; recomputes nothing.

---

## Build sequencing

| # | Phase | Tabs / artifacts | Estimate |
|---|---|---|---|
| 1 | Foundation | `styling.py`, `components.py`, `click_video.py`, `selectors.py`, `__init__.py` | 1 day |
| 2 | Routing | `4_Catching.py` edit + `render_domain_landing` extension | 0.5 day |
| 3 | Landing | `landing.py` + `data/leaders.py` + 6-tile grid + rail | 1 day |
| 4 | Catcher Cards | **BUILD FIRST** — primary value moment | 3-4 days |
| 5 | Gameday | Existing postgame panel reuse + zone plot CTV | 2-3 days |
| 6 | Pitch Calling | NEW SQL aggregator + pivots + zone heatmaps | 2-3 days |
| 7 | Pitchers | Per-pitcher arsenal + heatmaps | 2 days |
| 8 | Stats | Year-by-year tables + sparklines | 1-2 days |
| 9 | Scoreboard | Schedule_View slate + game cards | 1-2 days |
| 10 | Polish + parity audit | Per `parity-test-plan.md` | 1 day |

**Total:** 14-19 working days. Phase 4 (Catcher Cards) is the MVP value
moment — could ship that alone first if needed.

---

## What's locked vs open

### Locked decisions

- Architecture: new sub-view under existing catching page, not new top-level page
- Module home: `intangibles/src/ac_dashboard/` subpackage
- Year selector drives roster
- All 7 affiliates (mlb / aaa / aax / afa / afx / rok / dsl) in scope
- Default sched_type: R only (advanced filter for others)
- AC branding: KDB neutral palette + Astros orange (`#EB6E1F`) + Astros navy (`#002D62`)
- Locked typography: KDB's 5-font stack (JetBrains Mono / Space Grotesk /
  Special Gothic Expanded One / Inter), drop Playfair (no blog)
- 7-bucket framing palette: NEVER override (canonical per rules)
- Multi-year support: catcher list rebuilt per selected year
- `theme-color: #dce3eb` confirmed from KDB head
- Build order: Cards first, then Gameday, then everything else
- Parity contract: 4th view, never recomputes metrics

### Open questions parked for next session

Top 5 (full lists in each tab spec's "Open questions" section):

1. **KDB Catcher Cards screenshot** — needed for layout fidelity. Inferred
   layout in `tab-catcher-cards.md` is provisional.
2. **KDB Live screenshot** — needed for Stats tab leaderboard styling and
   Catcher Cards rank-context mini-panels.
3. **Defensive grade composite formula** — z-score-mean default in spec,
   `[PROVISIONAL]` label until coach buy-in.
4. **PDF export** — Phase 1 of original brainstorm or follow-on? Master
   spec defers to follow-on.
5. **Click-to-video URL source** — direct `Astros.Video` vs MLB Film Room
   GraphQL. Default: 3-tier fallback per `rules/video-angles.md`.

---

## Key cross-references in HOU codebase

### Rules referenced (auto-loaded for `intangibles/**`)

- `.claude/rules/intangibles.md` — 7-bucket framing palette, click-to-video pattern, parity rules
- `.claude/rules/three-surface-parity.md` — invariants AC must NOT break
- `.claude/rules/multi-level-rollup.md` — per-metric n_obs weighting
- `.claude/rules/kpi-roster-filter.md` — current-roster filter pattern
- `.claude/rules/video-angles.md` — 3-tier video URL fallback
- `.claude/rules/tracker-parquet-pins.md` — pin caching layer (AC inherits via tracker)
- `.claude/rules/sz-framework-savant-zones.md` — strike zone framework
- `.claude/rules/pitfalls.md` — `did_swing` whiff gate + BIT casting
- `.claude/rules/db-columns.md` — pitch_type, c_id, count, scoreboard columns
- `.claude/rules/db-joins.md` — `cur_event_id` vs `ab_event_id`
- `.claude/rules/feedback_age_formatting.md` — age display

### Source modules AC reads (NEVER MODIFIES)

- `intangibles/src/catching_tracker_data.py` (3786 lines) — primary data layer
- `intangibles/src/catcher_data.py` (1273 lines) — per-game data
- `intangibles/src/c_kpi_data.py` (1028 lines) — weekly KPI
- `intangibles/src/catcher_percentiles.py` (810 lines) — pool gates
- `intangibles/src/catcher_report.py` (1935 lines) — PDF panels (reuse refs)
- `intangibles/src/catcher_app_data.py` (139 lines) — game session helpers
- `intangibles/src/br_percentiles.py` — `percentile_to_color` helper
- `intangibles/src/roster.py` — `get_player_photo_url`, `get_levels`
- `intangibles/src/tracker_page.py` — `render_domain_landing` (extend)

### Source modules AC TOUCHES (extends only)

- `intangibles/pages/4_Catching.py` — add new route branch
- `intangibles/src/tracker_page.py::render_domain_landing` — add optional kwargs

---

## Pickup notes for next session

When resuming:

1. **Read the INDEX (this doc).** Confirms scope, locked decisions,
   open questions still outstanding.
2. **Confirm screenshots arrived.** If KDB Catcher Cards / KDB Live
   screenshots are now available, update `tab-catcher-cards.md` and
   note the screenshot reference path.
3. **Resolve open questions** — go through master spec §12 and tab
   specs' open-questions sections; lock any that user has answered.
4. **Choose build start point.** Default: Phase 1 (foundation) → Phase 2
   (routing) → Phase 3 (landing) → Phase 4 (Catcher Cards). Could
   reorder to land Catcher Cards as a vertical slice w/ minimal
   landing if we want fastest "see something working" moment.
5. **Run parity check protocol.** Before committing any tab as
   complete, follow `parity-test-plan.md` for that tab.

---

## Status grid

| Doc | Written? | Reviewed? | Locked? |
|---|---|---|---|
| INDEX (this) | ✓ | — | — |
| Visual Primitives | ✓ | — | — |
| Master Spec | ✓ | — | — |
| Tab — Landing | ✓ | — | — |
| Tab — Catcher Cards | ✓ | — | — |
| Tab — Gameday | ✓ | — | — |
| Tab — Pitch Calling | ✓ | — | — |
| Tab — Pitchers | ✓ | — | — |
| Tab — Stats | ✓ | — | — |
| Tab — Scoreboard | ✓ | — | — |
| Parity Test Plan | ✓ | — | — |
| Pre-Build Checklist | ✓ | — | — |

---

## Open todo list (carries from session 2026-05-07)

- [ ] User reviews all 10 design docs
- [ ] User provides KDB Catcher Cards screenshot
- [ ] User provides KDB Live screenshot
- [ ] User locks defensive-grade composite formula (or accepts provisional z-score-mean)
- [ ] User confirms build sequencing (Cards-first MVP vs full-build)
- [ ] User confirms PDF export deferral
- [ ] Build kickoff: foundation phase

---

## References

- KDB site: https://kdbbeta85v2.netlify.app/
- Reference screenshots: user's `OneDrive\Pictures\Screenshots\` folder
- HOU brand: `#002D62` navy, `#EB6E1F` orange
- Existing AC graduation log: `.claude/rules/.graduation-log.md` (no AC entries yet)
