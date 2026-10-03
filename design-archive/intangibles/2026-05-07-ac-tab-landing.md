# AC Dashboard — Landing Page Spec

**Date:** 2026-05-07
**Tab:** Catcher Dash landing (`?view=dashboard` no `&tab=`)
**Module:** `intangibles/src/ac_dashboard/landing.py`
**Mirrors KDB:** Home page (`https://kdbbeta85v2.netlify.app/`)
**Reference visual:** `Screenshot 2026-05-05 143607.png` (provided)
**Builds first AFTER:** primitives + master spec done; landing comes
before tab specs because it's the entry point users see.

---

## 1. Layout sketch

Top-down composition:

```
┌────────────────────────────────────────────────────────────────────┐
│   [← BACK]                                                         │
│                                                                    │
│              CATCHER DASH                                          │
│              Astros Catching · Internal Tool                       │
│                                                                    │
│   ┌────────────────────────────────────────────────────────┐       │
│   │  [Search catcher...   ▼]    YEAR: [2026 ▼]            │       │
│   └────────────────────────────────────────────────────────┘       │
│                                                                    │
│   ── 6-TILE NAV GRID ─────────────────────────────────────         │
│                                                                    │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                 │
│   │ CATCHER     │ │ GAMEDAY     │ │ PITCH       │                 │
│   │ CARDS       │ │             │ │ CALLING     │                 │
│   │             │ │             │ │             │                 │
│   │ Single-     │ │ Per-game    │ │ Pitch mix   │                 │
│   │ catcher     │ │ framing +   │ │ by count,   │                 │
│   │ scouting    │ │ click-to-   │ │ handedness, │                 │
│   │ card        │ │ video       │ │ location    │                 │
│   │ [LIVE]      │ │ [LIVE]      │ │ [LIVE]      │                 │
│   └─────────────┘ └─────────────┘ └─────────────┘                 │
│   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                 │
│   │ PITCHERS    │ │ STATS       │ │ SCOREBOARD  │                 │
│   │             │ │             │ │             │                 │
│   │ Pitcher     │ │ Year-by-    │ │ HOU         │                 │
│   │ arsenal     │ │ year        │ │ affiliate   │                 │
│   │ paired w/   │ │ defensive + │ │ slate +     │                 │
│   │ catcher     │ │ hitting     │ │ click-to-   │                 │
│   │             │ │             │ │ Gameday     │                 │
│   │ [LIVE]      │ │ [LIVE]      │ │ [LIVE]      │                 │
│   └─────────────┘ └─────────────┘ └─────────────┘                 │
│                                                                    │
│   ── YESTERDAY'S EXTRA STRIKE LEADERS ──────────────              │
│                                                                    │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐│
│   │ [head]   │ │ [head]   │ │ [head]   │ │ [head]   │ │ [head]   ││
│   │ Y. DIAZ  │ │ C.SALAZ  │ │ S.SCHIA  │ │ B.WILSON │ │ V.LOPEZ  ││
│   │ AAA      │ │ AAX      │ │ MLB      │ │ AFA      │ │ AFX      ││
│   │  +6      │ │  +5      │ │  +4      │ │  +3      │ │  +3      ││
│   │  EXTRA   │ │  EXTRA   │ │  EXTRA   │ │  EXTRA   │ │  EXTRA   ││
│   │  STRIKES │ │  STRIKES │ │  STRIKES │ │  STRIKES │ │  STRIKES ││
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘│
│                                                                    │
│   [VIEW FULL RANKINGS →]                                          │
│                                                                    │
│   ── FOOTER ───────────────────────────────────────                │
│   Houston Astros Player Development · 2026                         │
└────────────────────────────────────────────────────────────────────┘
```

KDB has 8 tiles + featured-articles strip. We **drop**:
- "Blog" tile (no internal blog)
- "KDB Live" tile (we don't have a separate live-leaderboards page;
  Stats tab covers it)
- "Featured articles" strip (no blog content)

Net: 6 tiles + leaders rail.

---

## 2. KDB → AC visual mapping

| KDB element | AC equivalent |
|---|---|
| Top nav bar (HOME / SCOREBOARD / GAMEDAY / etc.) | None — Streamlit page selector + back link suffice. Landing acts as the nav. |
| "Search catchers" input + year dropdown | `selectors.render_filter_chrome()` minimal mode (catcher + year only) |
| 8-card nav grid | 6-card `ac-tile` grid (per `visual-primitives.md` §5.1) |
| Green "+9 EXTRA STRIKES" chips on leader rail | Astros orange chips (`--accent-positive`) — same shape, AC color |
| Featured Articles strip | DROPPED |

---

## 3. Components used

From `visual-primitives.md`:
- `ac-tile` (§5.1) — 6 nav tiles
- `ac-chip-leader` (§5.2) — leader rail badges (Astros orange swap)
- `ac-headshot` (§5.6, "rail" 60×75 size) — leader rail headshots
- Section headers — `--type-display-lg`, navy

---

## 4. Data sources

### 4.1. Tile data
Static — title + description + tag string per tile. Defined inline.

### 4.2. Year selector
Years 2022-2026 (matches `PINNED_YEARS` constant from
`tracker-parquet-pins.md`). Default: current year per
`catching_tracker_data.get_latest_season_with_games()`.

### 4.3. Catcher search
Populated from `catching_tracker_data.get_hou_catcher_ids(season)` →
join player names via `_get_player_info(season)`. Name search filters
the dropdown options.

### 4.4. "Yesterday's Extra Strike Leaders" rail

NEW assembler in `ac_dashboard/data/leaders.py`:

```python
def get_yesterday_extra_strike_leaders(
    season: int,
    n: int = 5,
) -> List[Dict]:
    """Return top N HOU catchers by NetK delta on the latest day with
    HOU R games.
    
    Each dict has: gc_id, name, level, headshot_url, netk_delta.
    Sorted descending by netk_delta.
    """
```

**Mechanics:**
1. Find latest `sched_date` where any HOU affiliate played a `R` game.
2. For each HOU catcher who caught that day, compute NetK on that
   catcher's pitches via `catcher_data.get_catcher_game_pitches` +
   `compute_netk` (or pull from a pre-aggregated tracker daily table
   if perf is an issue).
3. Top N sorted by NetK descending.
4. Headshot via `roster.get_player_photo_url(gc_id)`.
5. Cached `@st.cache_data(ttl=600)` (10 min — leaders rail can be
   slightly stale).

[NOTE: confirm — should "Yesterday" mean calendar yesterday (might be
no games), or "most recent HOU game day"? Defaulting to most-recent
HOU game day. KDB shows "YESTERDAY'S EXTRA STRIKE LEADERS" but their
data is MLB-only (always games yesterday). Our DSL/FCL slate has
more gaps.]

---

## 5. Render flow

```python
# ac_dashboard/landing.py

def render():
    inject_css()  # AC tokens
    render_back_link("Catching")  # back to ?view= (sub-landing)
    
    # Hero
    st.markdown(_LANDING_HERO_HTML, unsafe_allow_html=True)
    
    # Filter chrome (year + catcher search only — minimal mode)
    selections = render_filter_chrome(
        mode="landing",  # year + catcher only, no level/sched
    )
    
    # 6-tile grid
    _render_tile_grid()
    
    # Leaders rail
    leaders = get_yesterday_extra_strike_leaders(
        season=selections["year"],
        n=5,
    )
    _render_leaders_rail(leaders)
    
    # Footer
    st.markdown(_FOOTER_HTML, unsafe_allow_html=True)
```

`_render_tile_grid()` emits 6 `<a class="ac-tile" href="?view=dashboard&tab=...">`
anchors. Each href targets the right tab.

---

## 6. Tile definitions

```python
TILES = [
    {
        "key": "cards",
        "title": "CATCHER CARDS",
        "desc": "Single-catcher scouting card with headshot, KPI grid, and percentile bars",
        "tag": "[ LIVE ]",
        "icon": None,  # text-only per KDB
    },
    {
        "key": "gameday",
        "title": "GAMEDAY",
        "desc": "Per-game framing review with extra/lost zone plot and click-to-video",
        "tag": "[ LIVE ]",
    },
    {
        "key": "pitch-calling",
        "title": "PITCH CALLING",
        "desc": "Per-catcher pitch mix by count, handedness, and zone location",
        "tag": "[ LIVE ]",
    },
    {
        "key": "pitchers",
        "title": "PITCHERS",
        "desc": "Pitcher arsenal, location heatmaps, and count tendencies (paired w/ catcher)",
        "tag": "[ LIVE ]",
    },
    {
        "key": "stats",
        "title": "STATS",
        "desc": "Year-by-year defensive and hitting stats across all affiliate levels",
        "tag": "[ LIVE ]",
    },
    {
        "key": "scoreboard",
        "title": "SCOREBOARD",
        "desc": "HOU affiliate game slate with click-through to per-game framing review",
        "tag": "[ LIVE ]",
    },
]
```

[NOTE: descriptions copied from KDB tile equivalents and adapted —
adjust copy with user before final lock]

---

## 7. CSS additions to `styling.py`

```css
.ac-landing-hero {
    text-align: center;
    margin: var(--space-6) 0 var(--space-5);
}
.ac-landing-hero h1 {
    font-family: 'Special Gothic Expanded One', sans-serif;
    font-size: 32px;
    color: var(--accent-emphasis);
    margin: 0 0 var(--space-2);
}
.ac-landing-hero p {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--text-mono-label);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin: 0;
}

.ac-tile-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
    margin: var(--space-4) 0;
}

.ac-tile {
    display: block;
    text-decoration: none;
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    transition: background 200ms, border-color 200ms;
}
.ac-tile:hover {
    background: var(--bg-panel-hover);
    border-color: var(--border-strong);
    cursor: pointer;
}
.ac-tile-title {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    font-weight: 700;
    color: var(--accent-emphasis);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin: 0 0 var(--space-2);
}
.ac-tile-desc {
    font-family: 'Inter', sans-serif;
    font-size: 12px;
    color: var(--text-secondary);
    line-height: 1.4;
    margin: 0;
}
.ac-tile-tag {
    font-family: 'JetBrains Mono', monospace;
    font-size: 9px;
    color: var(--accent-positive);
    margin-top: var(--space-3);
}

.ac-leaders-rail {
    display: flex;
    gap: var(--space-3);
    overflow-x: auto;
    padding: var(--space-3) 0;
}
.ac-leader-card {
    background: var(--bg-elev);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    min-width: 140px;
    text-align: center;
}
.ac-leader-headshot {
    width: 60px;
    height: 75px;
    border: 2px solid var(--accent-emphasis);
    border-radius: var(--radius-sm);
    object-fit: cover;
    margin: 0 auto var(--space-2);
}
.ac-leader-name {
    font-family: 'Inter', sans-serif;
    font-size: 12px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
}
.ac-leader-level {
    font-family: 'JetBrains Mono', monospace;
    font-size: 9px;
    color: var(--text-muted);
    text-transform: uppercase;
    margin: 0 0 var(--space-2);
}
.ac-leader-chip {
    display: inline-block;
    background: var(--accent-positive);
    color: white;
    font-family: 'JetBrains Mono', monospace;
    font-weight: 700;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
}
.ac-leader-chip-value {
    font-size: 18px;
    line-height: 1;
}
.ac-leader-chip-label {
    font-size: 8px;
    text-transform: uppercase;
    letter-spacing: 1px;
    line-height: 1;
    margin-top: 2px;
}
```

---

## 8. Build checklist

- [ ] `ac_dashboard/__init__.py` exposes `route(tab_name)` dispatcher
- [ ] `ac_dashboard/styling.py` defines `inject_css()` with all tokens
- [ ] `ac_dashboard/landing.py` `render()` orchestrates hero + chrome + grid + rail
- [ ] `ac_dashboard/selectors.py` `render_filter_chrome(mode="landing")` for minimal year+catcher
- [ ] `ac_dashboard/data/leaders.py` `get_yesterday_extra_strike_leaders(season, n)`
- [ ] CSS additions per §7 added to `styling.py`
- [ ] `4_Catching.py` extended: `from src import ac_dashboard` + `elif _view == "dashboard": ac_dashboard.route(...)`
- [ ] `tracker_page.render_domain_landing()` extended with optional `dashboard_desc/tag` kwargs
- [ ] `4_Catching.py` final `render_domain_landing()` call passes `dashboard_desc + dashboard_tag`
- [ ] Smoke test: load `?view=dashboard` → see 6-tile grid + leaders rail
- [ ] Smoke test: click tile → routes to `?view=dashboard&tab=cards` (etc.)
- [ ] Visual diff against KDB home screenshot — tiles same proportions, chips same depth

---

## 9. Open questions

- Q1: Tile order — does the grid row order matter to coaches? Default
  to most-used first (Cards / Gameday / Pitch Calling on top row).
- Q2: Search input — start with simple `st.selectbox`, or build typeahead
  later? Start simple.
- Q3: "VIEW FULL RANKINGS" link below leaders rail — points to Stats tab
  with leaderboard view, or its own thing? Point to Stats with a leader
  filter applied.
- Q4: Do we need a "today's games" mini-strip above the leaders rail
  (live game count + list)? KDB doesn't have it; defer.
- Q5: When no HOU games on "yesterday" (off-day, ASB, etc.) — show
  empty state, or backfill to most-recent game day? Empty state with
  "No HOU games in last 24h. Latest game: <date>" string.

---

## 10. References

- `2026-05-07-ac-visual-primitives.md` — token + component definitions
- `2026-05-07-ac-dashboard-master-spec.md` — routing + module structure
- `intangibles/src/tracker_page.py::render_domain_landing` — extend pattern
- KDB home: https://kdbbeta85v2.netlify.app/
- Reference screenshot: `OneDrive\Pictures\Screenshots\Screenshot 2026-05-05 143607.png`
