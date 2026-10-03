# AC Dashboard — Scoreboard Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=scoreboard`
**Module:** `intangibles/src/ac_dashboard/tab_scoreboard.py`
**Mirrors KDB:** Scoreboard page
**Build order:** SIXTH
**Build estimate:** 1-2 days
**New SQL?** YES — but minimal (Schedule_View)

---

## 1. Goal

Show HOU's affiliate slate for a given date (or recent date range).
Click any game → opens the catcher who caught that game in the
Gameday tab. Replaces "what game do I want to review?" friction with
a one-click portal.

---

## 2. User flow

1. User selects a date (default: most-recent date with HOU games)
2. Tab renders 1-7 game cards (one per affiliate playing that day)
3. Each card shows: matchup, score, status, catcher who caught it,
   abbreviated framing summary
4. Click card → routes to Gameday for that (sched_id, catcher)

---

## 3. Layout sketch

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK]                              [Date ◄ 2026-05-06 ►]         │
│                                                                     │
│   HOU AFFILIATE SCOREBOARD — 5/06/2026                              │
│   5 of 7 affiliates played · 1 doubleheader · 2 in progress         │
│                                                                     │
│ ┌─ MLB · HOU vs SEA · FINAL 6-3 ────────────────────────────────┐  │
│ │  [HOME]                                                        │  │
│ │  ┌─────────────────────────────────────────────────────────┐  │  │
│ │  │ Catcher: V. CARO    Pitches: 142   NetK: +1.6           │  │  │
│ │  │ ────────                                                 │  │  │
│ │  │ Frm Buckets: 8 EStl, 21 Stl, 14 Mid+, ...                │  │  │
│ │  │ Throws: 1/1 caught   Blocks: 6/6 saved                   │  │  │
│ │  │ [▶ Open Gameday]                                         │  │  │
│ │  └─────────────────────────────────────────────────────────┘  │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ ┌─ AAA · SUG vs OKC · FINAL 5-3 ────────────────────────────────┐  │
│ │  [HOME]                                                        │  │
│ │  ┌─────────────────────────────────────────────────────────┐  │  │
│ │  │ Catcher: Y. DIAZ    Pitches: 122   NetK: +1.8 (LEAD)    │  │  │
│ │  │ Throws: 2/3 caught  Blocks: 4/4 saved                    │  │  │
│ │  │ [▶ Open Gameday]                                         │  │  │
│ │  └─────────────────────────────────────────────────────────┘  │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ ┌─ AAX · CC vs ARK · FINAL 7-1 ────────────────────────────────┐  │
│ │  [AWAY]                                                        │  │
│ │  ┌─────────────────────────────────────────────────────────┐  │  │
│ │  │ Catcher: C. SALAZAR Pitches: 118   NetK: +0.4           │  │  │
│ │  │ Throws: 0/0          Blocks: 2/2 saved                   │  │  │
│ │  │ [▶ Open Gameday]                                         │  │  │
│ │  └─────────────────────────────────────────────────────────┘  │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ ┌─ AFA · ASH off ──────────────────────────────────────────────┐   │
│ │  No game scheduled                                            │   │
│ └───────────────────────────────────────────────────────────────┘   │
│                                                                     │
│ ┌─ AFX · FAY vs HUN · 7-3 IN 6TH ───────────────────────────────┐  │
│ │  Live game — limited data                                     │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ ┌─ ROK / DSL ─────────────────────────────────────────────────┐    │
│ │  (collapsed by default)                                      │    │
│ └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data — new aggregator

### 4.1. New file: `ac_dashboard/data/scoreboard.py`

```python
@dataclass
class ScoreboardGame:
    sched_id: int
    sched_date: date
    level: str
    home_team: str
    away_team: str
    is_hou_home: bool      # is HOU affiliate the home team?
    home_score: Optional[int]
    away_score: Optional[int]
    status: str            # 'final' / 'live' / 'scheduled'
    
    # HOU catcher who played
    catcher_id: Optional[int]
    catcher_name: Optional[str]
    pitches_caught: Optional[int]
    netk: Optional[float]
    is_netk_leader: bool   # true if highest NetK across HOU slate that day
    throws_caught: Optional[int]
    throws_attempts: Optional[int]
    blocks_saved: Optional[int]
    blocks_opportunities: Optional[int]


def get_hou_scoreboard(date_: date) -> List[ScoreboardGame]:
    """Return list of ScoreboardGame for HOU affiliates on date_.
    Sorted by level: MLB → AAA → AAX → AFA → AFX → ROK → DSL.
    Includes off-day rows when a level has no game."""


def get_latest_hou_game_date() -> date:
    """Find most-recent date with at least one HOU affiliate game."""
```

### 4.2. SQL — slate query

```sql
SELECT
    sv.sched_id,
    sv.sched_date,
    sv.level_code,
    sv.gc2_level_code,
    sv.home_team_name,
    sv.away_team_name,
    sv.home_team_id,
    sv.away_team_id,
    sv.home_score,
    sv.away_score,
    sv.is_final,            -- column exists per existing patterns
    -- HOU affiliate detection: home_team_id or away_team_id maps to HOU org
    CASE WHEN sv.home_team_id IN (SELECT team_id FROM MLBAM.Teams WHERE org_abbrev = 'HOU')
         THEN 1 ELSE 0 END  AS is_hou_home
FROM Astros.Schedule_View sv
WHERE sv.sched_date = :date_
  AND sv.sched_type = 'R'
  AND (sv.home_team_id IN (SELECT team_id FROM MLBAM.Teams WHERE org_abbrev = 'HOU')
       OR sv.away_team_id IN (SELECT team_id FROM MLBAM.Teams WHERE org_abbrev = 'HOU'))
ORDER BY sv.level_code
```

[NOTE: HOU affiliate detection — actually simpler to hardcode a per-
level HOU team_id map. The 7 affiliates (Astros, Sugar Land, Corpus
Christi, Asheville, Fayetteville, FCL Astros, DSL Astros) have stable
team_ids. Hardcode in `data/scoreboard.py` or pull from
`pd-goals/data/slack_channels.csv` — already used for affiliate-level
mapping elsewhere.]

### 4.3. Catcher attribution per game

For each sched_id, find HOU catcher. Reuse pattern from
`catcher_app_data.get_catcher_game_sessions()` — returns catcher_id +
pitches_caught per game.

NetK / throws / blocks summaries: lighter aggregation than full
postgame view. Could call `compute_netk` over `get_catcher_game_pitches`
per game, but for slate (5-7 games × 1-2 catchers each), that's 7-14
function calls per scoreboard load. Cacheable but heavy.

Lighter: write a dedicated SQL query that aggregates NetK + frm_buckets
+ throws + blocks per (sched_id, catcher_id) in one shot. Returns 5-7
rows. Cached `@st.cache_data(ttl=600)`.

### 4.4. NetK leader flag

After fetching all rows for the date, mark the row with max NetK
as `is_netk_leader=True`. Used to highlight the leader card.

---

## 5. Visual rendering

### 5.1. Game cards

Each game = one `ac-card` (full width). Top: blue header strip with
matchup + score. Body: catcher summary panel. Footer: "Open Gameday"
button.

Off-day affiliates: collapsed `<details>` element or grey-style card
saying "Off day."

ROK/DSL: collapsed by default (smaller font, can expand). These often
have less data + more gaps.

### 5.2. Date navigator

Top of page: previous/next day arrows + date picker. Default = latest
HOU game date. Don't allow future dates.

### 5.3. Leader chip on NetK

If `is_netk_leader=True`, show small Astros-orange chip "DAY LEAD"
next to the NetK value.

---

## 6. Components reused

- `ac-card` — game cards
- `ac-chip-leader` — DAY LEAD badge
- `ac-game-meta-header` — repurposed for matchup strip
- KPI tile compact — for catcher summary stats

---

## 7. CSS additions

```css
.ac-scoreboard-game {
    margin: var(--space-3) 0;
}
.ac-scoreboard-game-header {
    background: var(--accent-emphasis);
    color: white;
    padding: var(--space-3) var(--space-4);
    border-radius: var(--radius-md) var(--radius-md) 0 0;
    display: flex;
    justify-content: space-between;
    align-items: center;
}
.ac-scoreboard-game-body {
    background: var(--bg-elev);
    border: 1px solid var(--border);
    border-top: none;
    border-radius: 0 0 var(--radius-md) var(--radius-md);
    padding: var(--space-4);
}
.ac-scoreboard-off-day {
    background: var(--bg-panel);
    border: 1px dashed var(--border);
    color: var(--text-muted);
    padding: var(--space-3) var(--space-4);
    border-radius: var(--radius-md);
    text-align: center;
    font-style: italic;
}
.ac-scoreboard-live-badge {
    background: var(--accent-negative);
    color: white;
    font-family: 'JetBrains Mono', monospace;
    font-size: 9px;
    text-transform: uppercase;
    letter-spacing: 1px;
    padding: 2px 6px;
    border-radius: var(--radius-sm);
}
```

---

## 8. Build checklist

- [ ] `ac_dashboard/data/scoreboard.py` — `ScoreboardGame` dataclass + `get_hou_scoreboard(date)` + `get_latest_hou_game_date()`
- [ ] HOU affiliate team_id map (hardcode 7 entries, source from existing slack_channels.csv or PP_MASTER)
- [ ] Per-game catcher summary SQL (NetK + throws + blocks in one query)
- [ ] `ac_dashboard/components.py` — `render_game_card(game)` + `render_off_day_card(level)`
- [ ] `ac_dashboard/tab_scoreboard.py` — `render()` w/ date navigator + 7-row level list
- [ ] Date navigator: prev/next + date picker, default = latest HOU game
- [ ] NetK leader chip on highest-NetK row
- [ ] ROK/DSL collapsed by default
- [ ] Click "Open Gameday" → `?view=dashboard&tab=gameday&sched_id=...&catcher_id=...`
- [ ] CSS additions per §7
- [ ] Smoke test: pick known date with games — all 5-7 levels show, scores match Schedule_View, catcher names attributed correctly

---

## 9. Open questions

- Q1: Doubleheader handling — show both games stacked? Default: yes,
  inline second game card immediately after first.
- Q2: Live games — pull current score + status, or only show 'final'?
  Default: show live with badge; data may be partial.
- Q3: Off-day affiliates — show as collapsed entry, or omit entirely?
  Default: show as `ac-scoreboard-off-day` (visual context — coaches
  know who's off).
- Q4: Pre-2026 dates — selectable? Default: yes, year selector
  unlocked. But scoreboard data depth depends on Schedule_View
  population back to 2022.
- Q5: Show opposing catcher's NetK + comp side-by-side? KDB does this
  in their game cards. Defer to v2 — adds complexity.
- Q6: NetK "DAY LEAD" chip — across HOU slate only, or league-wide?
  Default: HOU slate only (cheap, instantly meaningful).
- Q7: Calendar grid view (alternative to single-day view) — show 7-day
  slate? Defer to v2.
- Q8: Games where NO HOU catcher caught (rare — emergency C from
  position player)? Show game card without catcher summary. Mark
  "No defensive data — non-catcher receiver."

---

## 10. References

- `2026-05-07-ac-visual-primitives.md`
- `2026-05-07-ac-dashboard-master-spec.md`
- `2026-05-07-ac-tab-gameday.md` (target of click-throughs)
- `intangibles/src/catcher_app_data.py::get_catcher_game_sessions` — game session pattern
- `.claude/rules/db-columns.md` — Schedule_View columns
- `.claude/rules/level-codes.md` — affiliate level codes
- `pd-goals/data/slack_channels.csv` — affiliate team mapping reference
- KDB Scoreboard: https://kdbbeta85v2.netlify.app/ → click SCOREBOARD
