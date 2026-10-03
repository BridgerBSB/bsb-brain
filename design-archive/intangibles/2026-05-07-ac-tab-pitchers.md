# AC Dashboard — Pitchers Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=pitchers`
**Module:** `intangibles/src/ac_dashboard/tab_pitchers.py`
**Mirrors KDB:** Pitchers page
**Build order:** FOURTH
**Build estimate:** 2 days
**New SQL?** YES — pitcher arsenal aggregator

---

## 1. Goal

Show the pitchers a catcher caught + their arsenal usage paired with
this catcher. Helps coaches see "who threw what to Diaz, and where
did Diaz call them."

This is the catcher-as-receiver view of pitch data — the inverse of
Pitch Calling (which is catcher-as-caller).

[NOTE: KDB tile description says "Arsenal breakdowns, location heatmaps,
and count tendencies" — this overlaps Pitch Calling's heatmap panel.
The differentiator is the LENS: Pitch Calling = catcher-driven view
of all pitches; Pitchers = pitcher-driven (per-pitcher arsenal +
mix). Same underlying data, different cuts.]

---

## 2. User flow

1. User selects catcher + year + level
2. Tab shows list of pitchers caught (sorted by pitches caught, desc)
3. Click a pitcher row → expands to show that pitcher's arsenal +
   location heatmap + count tendency table

---

## 3. Layout sketch

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK]                              [Year ▼] [Catcher ▼]          │
│                                                                     │
│   YAINER DIAZ — PITCHERS CAUGHT                                     │
│   2026 · AAA · 18 pitchers · 1822 pitches                           │
│                                                                     │
│ ┌─ PITCHERS LIST ──────────────────────────────────────────────┐   │
│ │ Pitcher          Hand   Pitches    NetK    Strikes  AvgVel  │   │
│ │ J. France         R       243      +0.6    62.4%    93.2    │   │
│ │ B. Garcia         R       198      +0.4    63.8%    91.8    │   │
│ │ A. Bracho         L       186      +0.5    64.5%    89.1    │   │
│ │ ... (sortable)                                              │   │
│ │                                                             │   │
│ │ Click row → expand below                                    │   │
│ └─────────────────────────────────────────────────────────────┘   │
│                                                                    │
│ ┌─ SELECTED PITCHER: J. FRANCE ─────────────────────────────────┐  │
│ │                                                               │  │
│ │   Arsenal     Pitches    Usage%   Whf%   Avg Velo   Avg IVB │  │
│ │   FF             98       40%     22%      94.1       16.2  │  │
│ │   SI             54       22%     10%      92.8       13.4  │  │
│ │   SL             58       24%     38%      85.4        2.1  │  │
│ │   CH             21        9%     30%      87.2        9.8  │  │
│ │   CB             12        5%     50%      78.3       -8.4  │  │
│ │                                                               │  │
│ │ ┌─ LOCATION HEATMAPS BY PITCH TYPE ────────────────────────┐ │  │
│ │ │   FF        SI        SL        CH        CB             │ │  │
│ │ │  ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐              │ │  │
│ │ │  │░██│    │██▒│    │░░ │    │ ░ │    │   │              │ │  │
│ │ │  │██▒│    │░██│    │░ ░│    │ ░ │    │░░ │              │ │  │
│ │ │  │ ░ │    │   │    │░░░│    │   │    │ ░ │              │ │  │
│ │ │  └───┘    └───┘    └───┘    └───┘    └───┘              │ │  │
│ │ └──────────────────────────────────────────────────────────┘ │  │
│ │                                                               │  │
│ │ ┌─ COUNT TENDENCIES (this pitcher × Diaz) ───────────────────┐│  │
│ │ │  Count   FF    SI    SL    CH    CB    Total              ││  │
│ │ │  0-0     45%   24%   18%   10%    3%    32                ││  │
│ │ │  0-1     30%   22%   34%   10%    4%    25                ││  │
│ │ │  ...                                                      ││  │
│ │ └────────────────────────────────────────────────────────────┘│  │
│ │                                                               │  │
│ │ [▶ Open Gameday for first appearance]                         │  │
│ └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data — new aggregator

### 4.1. New file: `ac_dashboard/data/pitchers.py`

```python
@dataclass
class PitcherRow:
    pitcher_id: int
    name: str
    hand: str            # 'R' / 'L'
    pitches: int
    netk: float
    strike_pct: float
    avg_velo: float
    appearances: int     # distinct sched_ids
    first_sched_id: Optional[int]


@dataclass
class PitcherDetailFacts:
    pitcher_id: int
    pitcher_name: str
    catcher_id: int
    season: int
    
    # Arsenal table
    arsenal: pd.DataFrame   # cols: pitch_type, n, usage_pct, whiff_pct, avg_velo, avg_ivb
    
    # Location KDE per pitch type
    locations: Dict[str, np.ndarray]
    
    # Count tendencies
    by_count: pd.DataFrame  # pivot count × pitch_type
    

def list_pitchers_caught(
    catcher_id: int,
    season: int,
    level_codes: Tuple[str, ...],
    sched_types: Tuple[str, ...] = ("R",),
) -> List[PitcherRow]:
    """List all pitchers this catcher caught, sorted by pitches desc."""


def get_pitcher_detail(
    pitcher_id: int,
    catcher_id: int,
    season: int,
    level_codes: Tuple[str, ...],
    sched_types: Tuple[str, ...] = ("R",),
) -> PitcherDetailFacts:
    """Per-pitcher arsenal + location + count detail, scoped to pitches
    THIS catcher caught for THIS pitcher."""
```

### 4.2. SQL — pitchers list

Aggregates over the same per-pitch fetch from Pitch Calling, but
grouped by pitcher_id. Reuse the base SQL fragment; just regroup in
Python or hit DB with grouped query.

[NOTE: pitchers list query is small enough (~20-50 pitchers per catcher
per season) that grouping in Python is fine. Pitcher detail query for
arsenal needs metric columns from Pitches_View: `release_speed`,
`induced_break_z` (IVB), `pitch_result_id` for whiff calc.]

### 4.3. Whiff% gating

Per `.claude/rules/pitfalls.md`: `is_whiff = (did_swing == 1) AND
pitch_result_id IN (10, 16, 21, 22, 23)`. WITHOUT did_swing gate,
Ctct% + Whf% > 100%.

`did_swing` comes from `pv.did_swing` BIT column — `CAST(... AS int)`
before any aggregation per `pitfalls.md`.

```python
df["is_swing"] = df["did_swing"].fillna(0).astype(int) == 1
df["is_whiff"] = df["is_swing"] & df["pitch_result_id"].isin([10, 16, 21, 22, 23])
arsenal["whiff_pct"] = (
    df.groupby("pitch_type")["is_whiff"].sum() /
    df.groupby("pitch_type")["is_swing"].sum() * 100
)
```

---

## 5. Visual rendering

### 5.1. Pitchers list

`st.dataframe` with selection mode `single-row`. `on_select="rerun"`
to capture selection in session state. Selected pitcher_id drives
the detail panel.

Columns sortable. Default sort: pitches desc.

### 5.2. Detail panel

Below list, gated on `selected_pitcher_id` in session state. Three
sub-sections inside `ac-card`:
1. Arsenal table (Styler-formatted, percentile coloring on
   usage/whiff/velo within league)
2. 5-up location heatmap grid (same component as Pitch Calling §5.3)
3. Count tendency pivot table (same Styler pattern as Pitch Calling §5.1)

---

## 6. Components reused

From other tab specs:
- `ac-zone-mini` — heatmap grid (from Pitch Calling)
- `ac-pivot-table` — gradient pivot (from Pitch Calling)
- `ac-card` — detail panel container (from Catcher Cards)
- Styled `st.dataframe` for pitcher list

---

## 7. CSS additions

Minimal — most styling reuses Pitch Calling tokens. New only:

```css
.ac-pitchers-list-wrapper {
    background: var(--bg-elev);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
}
.ac-pitcher-detail-arsenal {
    margin: var(--space-3) 0;
}
```

---

## 8. Build checklist

- [ ] `ac_dashboard/data/pitchers.py` — `PitcherRow` + `PitcherDetailFacts`
  dataclasses + `list_pitchers_caught()` + `get_pitcher_detail()`
- [ ] Whiff% gated by `did_swing` per `pitfalls.md`
- [ ] BIT casts on `did_swing` per `pitfalls.md`
- [ ] `ac_dashboard/components.py` — reuse `render_pivot_table_with_gradient` + `render_zone_heatmap`
- [ ] `ac_dashboard/tab_pitchers.py` — `render()` w/ pitcher selection state
- [ ] Pitcher list selection → detail panel (st.session_state)
- [ ] CSS additions per §7
- [ ] Smoke test: Diaz × France detail — Whf% per pitch type ≤ 100%, usage % sums to 100%, velocities + IVBs in range

---

## 9. Open questions

- Q1: Pitcher arsenal columns — keep simple (5 cols) or add Avg HB,
  Spin, etc? Default: 5 (usage%, whf%, velo, ivb, n_pitches) for v1;
  expand later if asked.
- Q2: League comparison — show how this pitcher's arsenal stacks vs
  league? Defer; would need league pool aggregation.
- Q3: Multi-pitcher comparison — overlay 2 pitchers' arsenals? Defer
  to v2; not in KDB UI as far as we can tell.
- Q4: Click pitcher row → open Gameday for first / most recent
  appearance? Default: button under detail panel.
- Q5: Filter to current-rostered pitchers only (per `kpi-roster-filter.md`)?
  Default: NO — show every pitcher this catcher caught (historical).
- Q6: Min pitches threshold for inclusion in pitcher list? Default:
  ≥10 pitches caught (filters out one-time emergency relievers).

---

## 10. References

- `2026-05-07-ac-visual-primitives.md`
- `2026-05-07-ac-dashboard-master-spec.md`
- `2026-05-07-ac-tab-pitch-calling.md` (shared SQL pattern + heatmap component)
- `intangibles/src/catcher_data.py::get_pitchers_caught` — per-game pitcher list
- `.claude/rules/pitfalls.md` — `did_swing` gate + BIT casting
- `.claude/rules/db-columns.md` — pitch_type, release_speed, induced_break_z columns
- KDB Pitchers: https://kdbbeta85v2.netlify.app/ → click PITCHERS
