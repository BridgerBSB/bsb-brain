# AC Dashboard — Gameday Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=gameday`
**Module:** `intangibles/src/ac_dashboard/tab_gameday.py`
**Mirrors KDB:** Gameday page (per-game framing review)
**Build order:** SECOND
**Build estimate:** 2-3 days

---

## 1. Why this tab second

1. Reuses everything Catcher Cards established (KPI tiles, percentile
   bar) PLUS introduces the click-to-video zone plot — the second
   high-value primitive.
2. Existing postgame stack (`catcher_data.py` + `_render_postgame()`
   in `4_Catching.py`) already builds every panel we need; Gameday is
   a re-skin of that data into KDB's per-game layout.
3. Click-to-video pattern unlocks Pitch Calling + Pitchers tabs (same
   plot mechanic).

---

## 2. User flow

1. User arrives at Gameday from:
   - Catcher Card recent-games row click → `&sched_id=NNNNN` deep link
   - Scoreboard tab click → same deep link
   - Direct nav (no sched_id) → prompts game selector
2. With sched_id + catcher in URL: renders the per-game framing review
3. Game selector available to switch games without leaving tab

---

## 3. Layout sketch

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK]                              [Year ▼] [Catcher ▼] [Game ▼] │
│                                                                     │
│   YAINER DIAZ vs OKC · 5/06/2026 · AAA                             │
│   Final: SUG 5, OKC 3   ·   8.2 IP caught   ·   122 pitches received│
│                                                                     │
│ ┌─ GAME-LEVEL KPI ROW ─────────────────────────────────────────┐   │
│ │ NetK     Frm Buckets    R2K%    SBA Throws   Blocks         │   │
│ │ +1.8      see below     33%     2/3 (67%)    4/4 (100%)     │   │
│ │ ████░░░░  -              ███░░░  ████░░       ██████        │   │
│ │ +1.2 lvl  vs +0.0 lvl    +5pp   even          +1.0          │   │
│ └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│ ┌─ ZONE PLOT — CALLED PITCHES (click to view video) ────────────┐ │
│ │                                                                │ │
│ │   • = called strike    × = called ball   ↗ = bucket coloring   │ │
│ │                                                                │ │
│ │       ┌───────────────────────┐                                │ │
│ │       │   ░░░░░░░░░░░░░░░░░   │                                │ │
│ │       │  ░ ⊙   ⊙  ⊙ ⊙ ⊙ ⊙   ░                                │ │
│ │       │ ░    ◉  ●        ●  ░                                  │ │
│ │       │ ░  ⊕     STRIKE      ░                                 │ │
│ │       │ ░         ZONE       ░                                 │ │
│ │       │ ░              ⊕    ░                                  │ │
│ │       │  ░ ●  ●          ●  ░                                  │ │
│ │       │   ░░░░░░░░░░░░░░░░░   │                                │ │
│ │       └───────────────────────┘                                │ │
│ │                                                                │ │
│ │   Legend: 7-bucket framing palette                             │ │
│ │   E Stl · Stl · Mid+ · Exp · Mid- · Loss · B Loss              │ │
│ └────────────────────────────────────────────────────────────────┘ │
│                                                                    │
│ ┌─ RECEIVING TABLE (by pitcher × bucket) ──────────────────────┐  │
│ │ Pitcher       Pitches  EStl  Stl  Mid+  Exp  Mid-  Loss BLs │  │
│ │ J. France       43      2     8    11    7    9     5    1  │  │
│ │ B. Garcia       31      1     6     7    5    7     4    1  │  │
│ │ ...                                                          │  │
│ └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│ ┌─ THROWS ──────────────────────┐ ┌─ BLOCKS ──────────────────┐  │
│ │ Pop  Exch  Vel  Acc  Result  ⏵│ │ Bounce  Result  Vel  ⏵    │  │
│ │ 1.91 0.69  85.2 ✓   CS  ⏵   │ │ ✓        BLK   77.1 ⏵    │  │
│ │ 1.95 0.71  84.8 ✓   CS  ⏵   │ │ ✓        BLK   80.3 ⏵    │  │
│ │ 2.02 0.76  82.4 ✗   SB  ⏵   │ │ ✓        BLK   78.9 ⏵    │  │
│ │                              │ │ ✗        WP    79.6 ⏵    │  │
│ │ Summary: 2/3 (67%) caught    │ │ Summary: 4/5 (80%) saved │  │
│ └──────────────────────────────┘ └────────────────────────────┘  │
│                                                                    │
│ ┌─ FIP / PA OUTCOMES ────────────────────────────────────────┐    │
│ │ Catcher FIP this game: 3.42                                │    │
│ │ Pitcher Hand   PA   K%   BB%   xwOBA                       │    │
│ │ vs LHP         18   33%  11%   .312                        │    │
│ │ vs RHP         24   25%   8%   .288                        │    │
│ └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. KDB → AC visual mapping

| KDB element | AC equivalent |
|---|---|
| Game header w/ score + IP | Same — game-meta header strip |
| Game KPI strip | KPI tile row (smaller, 5-up) |
| Zone plot w/ color-coded called pitches | Plotly scatter on strike zone, colored by 7-bucket framing palette, click-to-video |
| Receiving table (pitches by pitcher × bucket) | `compute_receiving_table()` already returns this; render as table |
| Throws + Blocks panels | Existing postgame Plotly panels — wrap in AC styling |
| FIP + PA outcomes | Existing `compute_fip()` + `get_catcher_pa_outcomes()` |

---

## 5. Data sources (all existing)

100% reuse of `catcher_data.py`:

| Element | Function |
|---|---|
| Game pitches | `get_catcher_game_pitches(catcher_gc_id, sched_id)` |
| NetK + Frm Buckets | `compute_netk()` + `compute_framing_buckets()` |
| Receiving table | `compute_receiving_table()` |
| Throws data + summary | `get_throws_data()` + `compute_throwing_summary()` |
| Blocks data + summary | `get_blocks_data()` + `compute_blocking_summary()` |
| AugPop | `get_augpop_game()` |
| FIP | `compute_fip()` |
| PA outcomes | `get_catcher_pa_outcomes()` |
| Catcher setup | `get_catcher_setup()` |
| Game depth | `get_catcher_depth()` |
| Pitchers caught | `get_pitchers_caught()` |
| Game metadata (date, opp, score) | NEW — light wrapper over `Schedule_View` |

---

## 6. Zone plot — click-to-video

### 6.1. Plot construction

Plotly scatter:
- X axis: `plate_x` (-1.5 to 1.5 ft)
- Y axis: `plate_z` (1.0 to 4.5 ft)
- Markers: one per called pitch (`pitch_result_id IN (4,5,6,3,24,30,31)`)
- Color: by CSC bucket per `intangibles.md` 7-bucket palette
- Marker symbol: filled circle for called strike, open circle for called ball
- Strike zone overlay: per `sz-framework-savant-zones.md` — ABS 17"
  rectangle (per-batter Z) + Tango 20" envelope outlined dashed

### 6.2. Click-to-video

Each marker `customdata` = `[pitch_id, video_url, ...]`. On click,
`_handle_chart_click(event, video_url_index=1)` opens the URL.

Video URL resolved via `rules/video-angles.md` 3-tier fallback chain
(Astros.Video angle_id=1 → Video_Network 'v' → Video_Network 'a').
Already wired in existing postgame; lift the SQL fragment.

### 6.3. Hover detail

Hover shows: pitcher, pitch type, velocity, CSC, called result, bucket.

### 6.4. Legend + annotations

Below plot:
- Bucket palette key (matches `compute_framing_buckets()` output)
- Click hint: "Click any pitch to open video"
- Total counts: "122 called pitches · NetK +1.8 · 7 extra strikes"

---

## 7. Game KPI row

5 KPI tiles, simplified format (game value + season-to-date for context):

| Tile | Game value | Sub-line |
|---|---|---|
| NetK | `+1.8` (this game) | `season +24.5` |
| Frm | bucket counts | `vs season distribution` |
| R2K% | `33% (12/36)` | `season 28%` |
| SBA Throws | `2/3 caught` | `season 18/26 (69%)` |
| Blocks | `4/4 (100%)` | `season 87/92 (95%)` |

Smaller than Catcher Cards tiles (1.5 lines tall instead of 4).

---

## 8. Existing patterns to lift

`_render_postgame()` in `4_Catching.py` (lines 207-1755) already
contains every panel we need rendered with Plotly. The Gameday tab is
ESSENTIALLY a re-orchestration of `_render_postgame()` panels into the
KDB layout.

**Approach:** extract the panel-rendering helpers from `_render_postgame()`
into reusable functions in `ac_dashboard/components.py` or
`ac_dashboard/postgame_panels.py`. Both `_render_postgame()` (existing
postgame view) AND `tab_gameday.py` call the same helpers — guaranteed
parity, no duplication.

[NOTE: this is a real refactor of `4_Catching.py` — the inline
`_render_postgame()` becomes a thin wrapper that calls the extracted
helpers in the same order. Carefully preserve existing behavior. Test
both views render identically before/after.]

If extraction risk is too high, alternative: copy the panel functions
into `ac_dashboard` and document the duplication as a known parity
risk. Refactor later. Decide at build time.

---

## 9. Game selector

Dropdown shows: "5/06 vs OKC · NetK +1.8" style — sched_id under the
hood, human-readable label. Sourced from
`catcher_app_data.get_catcher_game_sessions(catcher_gc_id, season,
level_codes, sched_types)`.

Default selection: most recent game. Override via `&sched_id=` URL
param.

---

## 10. Components used

From `visual-primitives.md`:
- `ac-kpi-tile` (compact variant — 5-up grid)
- Section dividers
- Section titles

New for Gameday:
- `ac-zone-plot` — Plotly figure config helper
- `ac-game-meta-header` — date/score/opponent strip

---

## 11. CSS additions

```css
.ac-game-meta-header {
    background: var(--accent-emphasis);
    color: white;
    padding: var(--space-3) var(--space-4);
    border-radius: var(--radius-md);
    margin: 0 0 var(--space-4);
}
.ac-game-meta-title {
    font-family: 'Special Gothic Expanded One', sans-serif;
    font-size: 22px;
    margin: 0 0 4px;
}
.ac-game-meta-sub {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    opacity: 0.85;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 0;
}

.ac-kpi-row-compact {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: var(--space-2);
}
.ac-kpi-tile-compact { padding: var(--space-2) var(--space-3); }
.ac-kpi-tile-compact .ac-kpi-tile-value { font-size: 16px; }

.ac-zone-plot-container {
    background: var(--bg-elev);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
}
.ac-bucket-legend {
    display: flex;
    gap: var(--space-3);
    margin-top: var(--space-3);
    font-family: 'JetBrains Mono', monospace;
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}
.ac-bucket-legend-swatch {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 2px;
    margin-right: 4px;
    vertical-align: middle;
}
```

---

## 12. Build checklist

- [ ] Extract postgame panel helpers from `4_Catching.py::_render_postgame()` into reusable functions (or duplicate cleanly)
- [ ] `ac_dashboard/components.py` — `render_game_meta_header(catcher, game)`
- [ ] `ac_dashboard/components.py` — `render_kpi_tile_compact(label, value, sub_line, pctile)`
- [ ] `ac_dashboard/components.py` — `render_zone_plot_with_video(pitch_df, sched_id, catcher_id)`
- [ ] `ac_dashboard/components.py` — `render_bucket_legend()`
- [ ] `ac_dashboard/tab_gameday.py` — `render()` orchestrator
- [ ] Click-to-video integration via `click_video.py` lifted helper
- [ ] Game selector dropdown w/ `sched_id` query string deep-link
- [ ] CSS additions per §11 added to `styling.py`
- [ ] Smoke test: load `?view=dashboard&tab=gameday&sched_id=NNNNN` for a known game → verify NetK / framing buckets / throws / blocks all match `?view=postgame` for the same selection
- [ ] Click any pitch on zone plot → video opens in new tab (matches existing postgame click-to-video behavior)

---

## 13. Parity verification

Open AC Gameday for any catcher × game (e.g. Diaz vs OKC 5/06).
Open `?view=postgame` for same catcher × same game.
Verify identical:
- NetK value
- 7-bucket counts
- Throws count + caught/SBA
- Blocks count + saved/opportunities
- AugPop
- FIP
- PA outcomes table

Any divergence = bug in the data layer. Fix at the assembler, never
at the display.

---

## 14. Open questions

- Q1: Game header — show pitcher list + IP each, or just summary? KDB
  defers detail to lower panels. Default: summary only at top.
- Q2: Zone plot view — single full plot, or split into Pre-2K / 2K
  panels? Default: single full plot, with toggle for filter.
- Q3: Receiving table — by pitcher × bucket, or by inning? Default:
  pitcher × bucket (matches `compute_receiving_table` shape).
- Q4: Show opponent catcher's same-game NetK side-by-side (already in
  `_render_postgame()`)? Default: yes — keep the H2H comparison panel.
- Q5: Click any throw row → open throw video? Already supported in
  postgame; keep.
- Q6: PDF export of Gameday review — Phase 1 or follow-on? Defer.
- Q7: When `sched_id` URL param refers to a game where catcher didn't
  play — show "no data" empty state, or auto-correct to a played game?
  Default: empty state with "Catcher did not play in this game" message.

---

## 15. References

- `2026-05-07-ac-visual-primitives.md`
- `2026-05-07-ac-dashboard-master-spec.md`
- `intangibles/src/catcher_data.py` — full per-game data layer
- `intangibles/pages/4_Catching.py::_render_postgame` — panel reference
- `.claude/rules/intangibles.md` — 7-bucket palette, click-to-video patterns
- `.claude/rules/video-angles.md` — 3-tier video URL fallback
- `.claude/rules/sz-framework-savant-zones.md` — strike zone framework
- KDB Gameday: https://kdbbeta85v2.netlify.app/ → click GAMEDAY
