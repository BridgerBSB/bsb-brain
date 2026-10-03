# AC Dashboard — Catcher Cards Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=cards`
**Module:** `intangibles/src/ac_dashboard/tab_catcher_cards.py`
**Mirrors KDB:** Catcher Cards page
**Build order:** **FIRST — primary value moment**
**Build estimate:** 3-4 days

---

## 1. Why this tab first

1. **Most coach-actionable** — single-catcher scouting card matches
   existing PDF use cases coaches already understand.
2. **Defines visual primitives** — once the card layout locks, every
   other tab reuses the KPI tile, percentile bar, headshot frame, and
   typography choices established here.
3. **Zero new SQL** — pulls entirely from
   `catching_tracker_data.get_catcher_leaderboard()` +
   `compute_percentile_ranks()` + `get_yearly_catcher_stats()`. All
   already exist + already pinned.
4. **Smallest blast radius if we change direction** — pure UI port,
   metric values traceable to existing tracker.

[NOTE: KDB Catcher Cards screenshot is **PENDING** from user. Layout
in §3 below is inferred from KDB home-tile description ("Generate
defensive scouting cards with headshots and percentile bars") and
general scouting-card conventions. Sections marked `[PENDING-SCREENSHOT]`
need confirmation/refinement when KDB Catcher Cards visuals arrive.]

---

## 2. User flow

1. User lands on `?view=dashboard` → clicks CATCHER CARDS tile
2. Lands on `?view=dashboard&tab=cards` with previously-selected
   year + catcher (from session state)
3. If no catcher selected: prompts "Select a catcher to begin" with
   the catcher dropdown highlighted
4. Once catcher + year locked: renders the hero card
5. Card supports: scroll to read all sections; download PNG/PDF
   (Phase 3 add-on); deep-link to Gameday for any specific game

---

## 3. Layout sketch

`[PENDING-SCREENSHOT]` — adjust when KDB Catcher Cards visual arrives.

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK to Catcher Dash]                  [Year ▼] [Catcher ▼]     │
│                                                                     │
│ ┌─ HERO CARD ──────────────────────────────────────────────────┐    │
│ │                                                              │    │
│ │  ┌────┐   YAINER DIAZ                            [↓ PNG]    │    │
│ │  │HEAD│   AAA · SUGAR LAND · 2026                            │    │
│ │  │SHOT│   Throws: R · Bats: R · Age: 27.4                   │    │
│ │  └────┘                                                      │    │
│ │  ──────────────────────────────────────────────────          │    │
│ │                                                              │    │
│ │  DEFENSIVE GRADE         77         (P95 vs all HOU C)       │    │
│ │  ████████████████████░░  Tier: ELITE                         │    │
│ │                                                              │    │
│ │  ──────────────────────────────────────────────────          │    │
│ │                                                              │    │
│ │  RECEIVING                                                   │    │
│ │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │    │
│ │  │ FRAMING RUNS │ │ NetK         │ │ R2K%         │         │    │
│ │  │ +3.2         │ │ +0.04        │ │ 28.4%        │         │    │
│ │  │ ████████░░  │ │ ████████░░  │ │ ███████░░░  │         │    │
│ │  │ 78th  L 4/22 │ │ 72nd  L 5/22 │ │ 65th  L 7/22 │         │    │
│ │  └──────────────┘ └──────────────┘ └──────────────┘         │    │
│ │                                                              │    │
│ │  THROWING                                                    │    │
│ │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │    │
│ │  │ ARM (P99)    │ │ POP 2B (P01) │ │ EXCH (P10)   │         │    │
│ │  │ 86.2 mph     │ │ 1.91 s       │ │ 0.71 s       │         │    │
│ │  │ ███████░░░  │ │ ████████░░  │ │ ██████░░░░  │         │    │
│ │  │ 68th  L 6/22 │ │ 81st  L 3/22 │ │ 55th  L 9/22 │         │    │
│ │  └──────────────┘ └──────────────┘ └──────────────┘         │    │
│ │                                                              │    │
│ │  BLOCKING                                                    │    │
│ │  ┌──────────────┐ ┌──────────────┐                          │    │
│ │  │ BlockRAA     │ │ Bounce% Save │                          │    │
│ │  │ +1.4         │ │ 92.4%        │                          │    │
│ │  │ ████████░░  │ │ ███████░░░  │                          │    │
│ │  │ 76th  L 5/22 │ │ 60th  L 8/22 │                          │    │
│ │  └──────────────┘ └──────────────┘                          │    │
│ │                                                              │    │
│ │  ──────────────────────────────────────────────────          │    │
│ │                                                              │    │
│ │  FRAMING BREAKDOWN (called pitches by CSC bucket)            │    │
│ │  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┐                │    │
│ │  │EStl │ Stl │Mid+ │ Exp │Mid- │Loss │BLoss│                │    │
│ │  │ 5%  │ 18% │ 22% │ 15% │ 18% │ 17% │ 5%  │                │    │
│ │  └─────┴─────┴─────┴─────┴─────┴─────┴─────┘                │    │
│ │  ████ ████ ████ ████ ████ ████ ████   (proportional bar)    │    │
│ │  Net: +3.2 runs                                              │    │
│ │                                                              │    │
│ │  ──────────────────────────────────────────────────          │    │
│ │                                                              │    │
│ │  POP TIME DETAIL                                             │    │
│ │  ┌─────────┬───────┬───────┬───────┐                        │    │
│ │  │         │ Pop2B │ Pop3B │ AugPop│                        │    │
│ │  ├─────────┼───────┼───────┼───────┤                        │    │
│ │  │ vs LHB  │ 1.92  │  -    │ 2.04  │                        │    │
│ │  │ vs RHB  │ 1.89  │ 1.61  │ 2.01  │                        │    │
│ │  │ Overall │ 1.91  │ 1.61  │ 2.03  │                        │    │
│ │  └─────────┴───────┴───────┴───────┘                        │    │
│ │                                                              │    │
│ │  ──────────────────────────────────────────────────          │    │
│ │                                                              │    │
│ │  RECENT GAMES (last 5)         [Click row → Gameday]         │    │
│ │  ┌────────┬─────────┬──────┬───────┬────────┐               │    │
│ │  │ Date   │ Opp     │ NetK │ Throws│ Blocks │               │    │
│ │  ├────────┼─────────┼──────┼───────┼────────┤               │    │
│ │  │ 5/06   │ vs OKC  │ +0.5 │ 1/1   │ 3/3    │               │    │
│ │  │ 5/04   │ @ALB    │ +0.2 │ 0/1   │ 2/2    │               │    │
│ │  │ 5/03   │ @ALB    │ -0.1 │ 1/1   │ 1/1    │               │    │
│ │  │ 5/02   │ @ALB    │ +0.4 │ 2/2   │ 4/4    │               │    │
│ │  │ 5/01   │ vs RNO  │ +0.3 │ 1/1   │ 2/3    │               │    │
│ │  └────────┴─────────┴──────┴───────┴────────┘               │    │
│ └──────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. KDB → AC visual mapping

| KDB element | AC equivalent | Token / component |
|---|---|---|
| Card hero w/ headshot + name | Catcher card hero (per §5.3 of primitives) | `--bg-elev`, `--radius-lg`, navy border |
| KPI tile w/ percentile bar + rank | Same — defines the canonical tile shape | `ac-kpi-tile` (§5.4 primitives) |
| Headshot frame | Per §5.6 primitives | `ac-headshot` (80×100 hero size) |
| Section dividers (KDB has subtle horizontal rules) | `--border` 1px | `<hr>` styled |
| KDB green percentile high-end | Astros orange `#EB6E1F` for HiB-positive | `--accent-positive` |
| KDB blue-grey emphasis | Astros navy `#002D62` | `--accent-emphasis` |
| Framing breakdown bar (KDB stacked horizontal) | 7-segment proportional bar w/ canonical bucket palette | locked from `intangibles.md` |

---

## 5. KPI grid structure

8 KPI tiles in 3 sections:

### 5.1. RECEIVING (3 tiles)
- **FramRAA** — Framing runs above average
- **NetK** — Net called strikes (cumulative + per-pitch shown together)
- **R2K%** — 2-strike pitch effectiveness

### 5.2. THROWING (3 tiles)
- **Arm** — P99 throwing velocity (mph)
- **Pop 2B** — P01 pop time to 2B (seconds)
- **Exch** — P10 exchange time (seconds)

### 5.3. BLOCKING (2 tiles)
- **BlockRAA** — Blocking runs above average
- **Bounce% Save** — % of bounce pitches blocked

### 5.4. Tile specifics

Each tile uses the standard `ac-kpi-tile` component. Direction handling:

| Metric | Direction | Display sign | Color anchor |
|---|---|---|---|
| FramRAA | HiB | always show + or − | gradient: red @ <-3, neutral @ 0, orange @ +3 |
| NetK | HiB | always show + or − | same |
| R2K% | HiB | % | gradient |
| Arm | HiB | mph | gradient |
| Pop 2B | LiB (lower=faster) | seconds | reversed gradient |
| Exch | LiB | seconds | reversed gradient |
| BlockRAA | HiB | always show + or − | gradient |
| Bounce% Save | HiB | % | gradient |

Direction passed to `percentile_to_color()` via `higher_is_better`
flag (already supported).

### 5.5. Per-tile layout

```
┌──────────────────────────┐
│  FRAMING RUNS            │  ← --type-mono-label, --text-mono-label
│                          │
│  +3.2                    │  ← --type-mono-value, navy if positive HiB
│                          │
│  ████████░░             │  ← 10-segment percentile bar (per primitives §5.5)
│                          │
│  78th    L: 4/22  O: 1/3 │  ← rank: percentile + level rank + org rank
└──────────────────────────┘
```

Rank string format:
- `78th` — percentile vs catcher KPI pool (1500+ pitches gate)
- `L: 4/22` — rank within selected level(s) at this season
- `O: 1/3` — rank within HOU org at this level/season

Both Lvl + Org ranks come from the existing `compute_percentile_ranks`
output. If pool gate not met (<1500 pitches), display percentile +
ranks as `—` per existing graceful-hide pattern.

---

## 6. Defensive Grade composite

KDB-style "20-80" grade. Computed as average of Z-scores across the 8
KPI metrics, mapped to 20-80 scale (50 = average, 80 = elite).

[NOTE: KDB calls this "20-80 grade" — formula not visible in source
dump. We'll use a simple z-score-mean approach:
```
z_i = (x_i - mean_i) / std_i        per metric
grade = 50 + 10 * mean(z_i across all 8 metrics)
clipped to [20, 80]
```
This is a STARTER. Final formula needs sign-off — could pull from
existing PD-Goals defensive grade if one exists, or develop a HOU-
specific composite. **Mark as `[PROVISIONAL]` in the UI label.**]

---

## 7. Framing Breakdown bar

Horizontal stacked bar, 7 segments, segment width proportional to
% of called pitches in each bucket. Bucket palette LOCKED per
`.claude/rules/intangibles.md`:

```
┌─────┬─────────┬──────────┬─────┬──────────┬──────┬───┐
│EStl │   Stl   │   Mid+   │ Exp │   Mid-   │ Loss │BLs│
└─────┴─────────┴──────────┴─────┴──────────┴──────┴───┘
  5%    18%       22%        15%   18%        17%    5%
```

Bucket counts come from `catcher_data.compute_framing_buckets()`
called over the catcher's full season at selected level. Numbers
above the bar; segment heights uniform; only widths vary.

Caption below: `Net: +X.X framing runs above expectation` —
matches Tango 0.125/strike framing-run convention from existing
canon.

---

## 8. Pop Time Detail table

3-column × 3-row table. Pop time by handedness, three flavors:

| | Pop 2B | Pop 3B | AugPop |
|---|---|---|---|
| vs LHB | 1.92 | — | 2.04 |
| vs RHB | 1.89 | 1.61 | 2.01 |
| Overall | 1.91 | 1.61 | 2.03 |

Source: `catching_tracker_data._ORG_THROWING_DIRECT_QUERY` already
exposes pop time aggregations per (catcher, hand). Need a per-catcher
version — likely already in `_THROWING_AGG_QUERY` or close. If not,
extend `data/catcher_facts.py` with one helper.

[NOTE: Pop 3B vs LHB likely thin (catchers rarely throw to 3B; LHB even
rarer). Empty cell shown as `—` not zero. Confirm Pop3B vs LHB is
worth showing or just collapse to single Pop3B row.]

---

## 9. Recent Games table

Last 5 games, click-row routes to Gameday tab for that sched_id.

Source: `catching_tracker_data.get_yearly_catcher_stats(catcher_id)`
returns per-game rows when called with date-window narrow enough.
Or use `catcher_data` per-game functions iteratively.

Columns:
- **Date** — `MM/DD`
- **Opp** — `vs XXX` or `@XXX`
- **NetK** — game-level NetK from `catcher_data.compute_netk()`
- **Throws** — `caught/total` (CS / SBA total)
- **Blocks** — `blocks/opportunities`

Each row is `<a href="?view=dashboard&tab=gameday&sched_id=...">`.

---

## 10. Header detail (catcher metadata)

Above the divider:
```
[HEADSHOT]   YAINER DIAZ
              AAA · SUGAR LAND · 2026
              Throws: R · Bats: R · Age: 27.4
```

Sources:
- Name + handedness: `catching_tracker_data._get_player_info(season)`
- Level: from selected filter
- Affiliate name: `catcher_data.AFFILIATE_CITY[level_code]` (already exists)
- Age: existing roster pattern (`pd-goals/data/slack_channels.csv` has
  birth date — or PP_MASTER lookup)

[NOTE: Age display per `feedback_age_formatting.md` — one decimal,
NEVER round up.]

---

## 11. Data assembly

Centralize in `ac_dashboard/data/catcher_facts.py`:

```python
@dataclass
class CatcherCardFacts:
    # Identity
    gc_id: int
    name: str
    bats: str
    throws: str
    age: float
    level: str
    affiliate: str
    season: int

    # KPI grid
    fram_raa: float
    fram_raa_pctile: float
    fram_raa_lvl_rank: Optional[Tuple[int, int]]   # (rank, total)
    fram_raa_org_rank: Optional[Tuple[int, int]]
    netk: float
    netk_pctile: float
    netk_lvl_rank: Optional[Tuple[int, int]]
    netk_org_rank: Optional[Tuple[int, int]]
    r2k_pct: float
    r2k_pctile: float
    # ... arm, pop2b, exch, block_raa, bounce_pct ...

    # Composite
    defensive_grade: float  # 20-80

    # Framing breakdown
    framing_buckets: Dict[str, float]  # bucket_name -> pct
    framing_net_runs: float

    # Pop time detail
    pop_time_table: pd.DataFrame  # rows=hand, cols=2B/3B/AugPop

    # Recent games
    recent_games: pd.DataFrame  # date, sched_id, opp, netk, throws, blocks


def get_catcher_card_facts(
    gc_id: int,
    season: int,
    level_codes: Tuple[str, ...],
    sched_types: Tuple[str, ...] = ("R",),
) -> CatcherCardFacts:
    """Assemble all data for the Catcher Card from existing modules.

    Reads:
    - catching_tracker_data.get_catcher_leaderboard() + compute_percentile_ranks()
    - catching_tracker_data._get_player_info()
    - catcher_data.compute_framing_buckets() over season pitch set
    - catcher_data per-game data for recent_games
    """
    ...
```

Cached `@st.cache_data(ttl=1800)` (30 min — values change daily at most).

---

## 12. Components used

From `visual-primitives.md`:
- `ac-card` (§5.3) — hero
- `ac-kpi-tile` (§5.4) — KPI grid (×8)
- `ac-percentile-bar` (§5.5) — inside each tile
- `ac-headshot` (§5.6, "hero" 80×100 size) — header
- `ac-section-divider` (§5.7) — between sections

New component (extracted to primitives if reused elsewhere):
- `ac-framing-bar` — 7-segment proportional stacked bar w/ locked
  bucket palette + labels above

---

## 13. CSS additions to `styling.py`

```css
.ac-card-hero {
    background: var(--bg-elev);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-5);
    box-shadow: 0 1px 3px rgba(26,35,50,0.08);
}
.ac-card-header {
    display: flex;
    gap: var(--space-4);
    align-items: center;
}
.ac-card-header-name {
    font-family: 'Special Gothic Expanded One', sans-serif;
    font-size: 32px;
    color: var(--accent-emphasis);
    margin: 0;
}
.ac-card-header-meta {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--text-mono-label);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin: 4px 0 0;
}

.ac-section-title {
    font-family: 'Space Grotesk', sans-serif;
    font-size: 14px;
    font-weight: 700;
    color: var(--accent-emphasis);
    text-transform: uppercase;
    letter-spacing: 1px;
    margin: var(--space-4) 0 var(--space-2);
}

.ac-kpi-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
    margin: var(--space-2) 0 var(--space-4);
}
.ac-kpi-grid-2col { grid-template-columns: repeat(2, 1fr); }

.ac-kpi-tile {
    background: var(--bg-panel);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
}
.ac-kpi-tile-label {
    font-family: 'JetBrains Mono', monospace;
    font-size: 9px;
    font-weight: 600;
    color: var(--text-mono-label);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 0 0 var(--space-2);
}
.ac-kpi-tile-value {
    font-family: 'JetBrains Mono', monospace;
    font-size: 22px;
    font-weight: 700;
    color: var(--accent-emphasis);
    line-height: 1;
    margin: 0 0 var(--space-2);
}
.ac-kpi-tile-rank {
    font-family: 'JetBrains Mono', monospace;
    font-size: 10px;
    color: var(--text-secondary);
    margin: var(--space-2) 0 0;
}

.ac-pctile-bar {
    display: flex;
    gap: 1px;
    height: 6px;
    margin: 4px 0;
}
.ac-pctile-segment {
    flex: 1;
    border-radius: 1px;
}

.ac-framing-bar {
    display: flex;
    height: 32px;
    border-radius: var(--radius-sm);
    overflow: hidden;
    margin: var(--space-2) 0 var(--space-3);
}
.ac-framing-bar-segment {
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-family: 'JetBrains Mono', monospace;
    font-size: 10px;
    font-weight: 700;
}
```

---

## 14. Build checklist

- [ ] `ac_dashboard/data/catcher_facts.py` — `CatcherCardFacts` dataclass + `get_catcher_card_facts()` assembler
- [ ] `ac_dashboard/components.py` — `render_kpi_tile(label, value, pctile, lvl_rank, org_rank, hib)`
- [ ] `ac_dashboard/components.py` — `render_pctile_bar(pctile, hib)`
- [ ] `ac_dashboard/components.py` — `render_framing_breakdown_bar(buckets_dict, net_runs)`
- [ ] `ac_dashboard/components.py` — `render_pop_time_table(df)`
- [ ] `ac_dashboard/components.py` — `render_card_header(name, headshot_url, meta_strs)`
- [ ] `ac_dashboard/tab_catcher_cards.py` — `render()` orchestrator
- [ ] CSS additions per §13 added to `styling.py`
- [ ] Defensive Grade composite calculated + flagged `[PROVISIONAL]` in UI
- [ ] Recent games rows linkable to Gameday tab
- [ ] Empty state when catcher not selected
- [ ] Pool-gate hide-vs-show: ranks display as `—` when <1500 pitches
- [ ] Smoke test: load Diaz card on AAA → values match `?view=tracker` for same selection
- [ ] Visual fidelity check: side-by-side w/ KDB Catcher Cards screenshot once received

---

## 15. Parity verification protocol

After build, before declaring done:

1. Open AC Catcher Card for any catcher (e.g. Diaz, AAA, 2026)
2. Open `?view=tracker` for same season + level
3. Find Diaz row in tracker
4. Verify EVERY numeric value on the card matches the tracker row:
   - FramRAA ✓
   - NetK ✓
   - R2K% ✓
   - Arm (P99) ✓
   - Pop 2B (P01) ✓
   - Exch (P10) ✓
   - BlockRAA ✓
   - Bounce% ✓
5. If ANY value diverges: STOP. Don't ship. Find the divergence,
   document, fix at the data-assembler layer (NOT by adjusting display).

This is the three-surface-parity check applied to a 4th surface.

---

## 16. Open questions

- Q1: Defensive Grade composite formula — z-score-mean (provisional)
  vs custom HOU formula vs hide entirely? Default: ship z-score-mean
  with `[PROVISIONAL]` label, await user direction.
- Q2: Recent games window — last 5 vs last 7 vs last 10? KDB shows 5
  on its card; matching.
- Q3: Show season-to-date stats for games played, or all games at level?
  Default: all R games at selected level, current season.
- Q4: Multi-level selection — if user selects multiple levels, card
  shows... aggregate across levels? Or hide card and prompt single
  level? Default: aggregate (matches tracker multi-level logic).
- Q5: PNG/PDF export — ship Phase 1 or follow-on? Master-spec defers.
- Q6: Click-through from Recent Games row to Gameday — `sched_id` in
  query string OR pass through session state? Default: query string
  (`?view=dashboard&tab=gameday&sched_id=...`) so deep-links work.
- Q7: Show H/A split toggle? Tracker has it; cards COULD inherit.
  Default: skip — keep card simple; advanced filter expander has it.

---

## 17. References

- `2026-05-07-ac-visual-primitives.md` — components used
- `2026-05-07-ac-dashboard-master-spec.md` — routing
- `intangibles/src/catching_tracker_data.py` — primary data source
- `intangibles/src/catcher_data.py` — `compute_framing_buckets`, per-game stats
- `intangibles/src/catcher_percentiles.py` — pool gate logic
- `intangibles/src/br_percentiles.py::percentile_to_color` — color helper
- `.claude/rules/intangibles.md` — 7-bucket palette, parity rules
- KDB site: https://kdbbeta85v2.netlify.app/
