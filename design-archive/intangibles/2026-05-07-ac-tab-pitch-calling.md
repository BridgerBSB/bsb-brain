# AC Dashboard — Pitch Calling Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=pitch-calling`
**Module:** `intangibles/src/ac_dashboard/tab_pitch_calling.py`
**Mirrors KDB:** Pitch Calling page
**Build order:** THIRD
**Build estimate:** 2-3 days
**New SQL?** YES — first tab requiring a new aggregator

---

## 1. Goal

Show a catcher's pitch-call tendencies: which pitch types they call in
each count, by batter handedness, by zone location. Identify
"signature" calls (pitch they prefer in a given context) and surface
unusual choices.

This tab introduces pitch calling as a metric category — not a
defensive metric per se, but a tactical/decision metric. Pure
presentation aggregations; doesn't touch existing parity invariants.

---

## 2. User flow

1. User selects a catcher + year + level
2. Tab loads all R-game pitches caught by that catcher
3. Renders 4 main panels: count heatmap, handedness pivot, zone
   heatmap, sequencing tendencies

---

## 3. Layout sketch

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK]                              [Year ▼] [Catcher ▼]          │
│                                                                     │
│   YAINER DIAZ — PITCH CALLING                                       │
│   2026 · AAA · 1822 pitches called                                  │
│                                                                     │
│ ┌─ PITCH MIX BY COUNT ─────────────────────────────────────────┐   │
│ │                                                              │    │
│ │  Count    FF    SI    SL    CH    CB    Total              │    │
│ │  0-0      48%   18%   22%    8%    4%    218                │    │
│ │  1-0      52%   16%   18%    8%    6%    142                │    │
│ │  2-0      62%   24%    8%    4%    2%     78                │    │
│ │  3-0      78%   20%    2%    0%    0%     35                │    │
│ │  0-1      32%   14%   34%   12%    8%    198                │    │
│ │  ... (12 counts, hitter/even/pitcher leverage colored)      │    │
│ │                                                              │    │
│ │  Cell color: gradient by % within count                      │    │
│ │  Row color hint: hitter-count rows tinted blue,              │    │
│ │                  pitcher-count rows tinted orange            │    │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                    │
│ ┌─ PITCH MIX BY HANDEDNESS ─────────────────────────────────────┐  │
│ │                                                                │  │
│ │  Pitcher Hand × Batter Hand pivot                             │  │
│ │             FF    SI    SL    CH    CB                         │  │
│ │  RHP→LHB    44%   12%   24%   16%    4%                        │  │
│ │  RHP→RHB    50%   18%   20%    6%    6%                        │  │
│ │  LHP→LHB    52%   14%   20%    8%    6%                        │  │
│ │  LHP→RHB    46%   18%   18%   12%    6%                        │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                    │
│ ┌─ ZONE LOCATION HEATMAP (per pitch type) ──────────────────────┐  │
│ │                                                                │  │
│ │   FF        SI        SL        CH        CB                  │  │
│ │  ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐                   │  │
│ │  │   │    │   │    │   │    │   │    │   │                   │  │
│ │  │ ▒ │    │   │    │ ▒ │    │   │    │   │                   │  │
│ │  │░██│    │██▒│    │░░ │    │   │    │   │                   │  │
│ │  │██▒│    │░██│    │░░ │    │ ░ │    │   │                   │  │
│ │  └───┘    └───┘    └───┘    └───┘    └───┘                   │  │
│ │                                                                │  │
│ │  KDE density per pitch type within strike zone view           │  │
│ │  Reference quantile contours for each pitch type              │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                    │
│ ┌─ SEQUENCING — PITCH N+1 GIVEN PITCH N ────────────────────────┐  │
│ │                                                                │  │
│ │  Prev pitch    Next pitch transition probabilities            │  │
│ │           →FF    →SI    →SL    →CH    →CB                     │  │
│ │  FF        38%   18%   22%    14%    8%                        │  │
│ │  SI        32%   24%   24%    12%    8%                        │  │
│ │  SL        42%   12%   28%     8%   10%                        │  │
│ │  CH        46%   14%   22%    14%    4%                        │  │
│ │  CB        40%   16%   28%     8%    8%                        │  │
│ │                                                                │  │
│ │  Tendency: returns to FF after every off-speed type            │  │
│ └────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data — new aggregator

### 4.1. New file: `ac_dashboard/data/pitch_calling.py`

```python
@dataclass
class PitchCallingFacts:
    catcher_id: int
    season: int
    levels: Tuple[str, ...]
    total_pitches: int
    
    # Pitch type universe (top 5-7 most common)
    pitch_types: Tuple[str, ...]
    
    # Pivot tables
    by_count: pd.DataFrame    # rows = count strs, cols = pitch types, values = %
    by_hand: pd.DataFrame     # rows = (pitcher_hand, batter_hand) tuple, cols = pitch types
    by_zone: Dict[str, np.ndarray]  # pitch_type -> 2D KDE grid
    sequencing: pd.DataFrame  # rows = prev type, cols = next type, values = transition %


def get_pitch_calling_facts(
    catcher_id: int,
    season: int,
    level_codes: Tuple[str, ...],
    sched_types: Tuple[str, ...] = ("R",),
) -> PitchCallingFacts:
    """Aggregate pitch-call tendencies for a single catcher.
    
    Reads: Astros.Pitches_View directly (per-pitch grain).
    """
```

### 4.2. SQL — base per-pitch fetch

```sql
SELECT 
    pv.sched_id,
    pv.pitch_id,
    pv.pitcher_id,
    pv.bat_side,
    pv.pitcher_throws,
    pv.balls_at_pitch  AS balls,
    pv.strikes_at_pitch AS strikes,
    pv.pitch_type,
    pv.pitch_result_id,
    pv.plate_x,
    pv.plate_z,
    pv.sz_top,
    pv.sz_bot,
    ev.c_id  AS catcher_id
FROM Astros.Pitches_View pv
JOIN Astros.Schedule_View sv ON pv.sched_id = sv.sched_id
LEFT JOIN Astros.Events_View ev
    ON ev.sched_id = pv.sched_id AND ev.event_id = pv.cur_event_id
WHERE ev.c_id = :catcher_id
  AND pv.pitch_id > 0
  AND YEAR(sv.sched_date) = :season
  AND sv.level_code IN ({levels})  -- with DSL/ROK gc2 split per fielding-base.py
  AND sv.sched_type IN ({sched_types})
  AND pv.pitch_type IS NOT NULL
```

[NOTE: `ev.c_id` may be NULL on ~25% of pitches per `db-joins.md`
warnings. Catcher attribution is reliable via `cur_event_id` for
PA-ending pitches. Need to use `ab_event_id` for full coverage —
mirror catcher_data pattern. Confirm by inspecting `catcher_data.get_catcher_game_pitches`
SQL.]

Cached `@st.cache_data(ttl=1800)` on (catcher_id, season, levels, sched_types).

### 4.3. Aggregation

After per-pitch fetch:

**By count pivot:**
```python
df["count_str"] = df["balls"].astype(str) + "-" + df["strikes"].astype(str)
counts = df.groupby(["count_str", "pitch_type"]).size().unstack(fill_value=0)
counts_pct = counts.div(counts.sum(axis=1), axis=0) * 100
```

Order rows by canonical count progression (0-0, 1-0, 2-0, 3-0, 0-1, ..., 3-2).

**By handedness pivot:** group by (pitcher_throws, bat_side) tuple.

**By zone:** for each pitch_type, compute 2D KDE on (plate_x, plate_z)
within strike-zone bounds. Render via Plotly contour or matplotlib
heatmap.

**Sequencing:** within each game × pitcher pairing, walk pitches in
order, build (prev_type, next_type) transition counts. Pivot to
percentage matrix.

---

## 5. Visual rendering

### 5.1. Count heatmap

`st.dataframe` with pandas Styler:
- Background gradient applied per-row (each count's distribution)
- Cell text shows %
- Column "Total" right-aligned, no gradient
- Row tint: hitter counts (1-0, 2-0, 3-0, 2-1, 3-1) light blue;
  pitcher counts (0-1, 0-2, 1-2) light orange; even (0-0, 1-1, 2-2,
  3-2) neutral

### 5.2. Handedness pivot

`st.dataframe` styled identically to count heatmap — gradient per row.

### 5.3. Zone heatmaps

5-up grid of small Plotly heatmaps, one per pitch type. Each:
- 2D bin: `plate_x` × `plate_z` over strike zone bounds
- Colorscale: white → blue → dark blue (density)
- Strike zone outline overlaid
- Title above each: pitch type abbreviation + count + %

[NOTE: KDE vs 2D histogram — go with 2D histogram (faster, simpler).
KDE is overkill for ~200-500 pitches per type per catcher.]

### 5.4. Sequencing matrix

Same Styler-with-gradient pattern as count/hand pivots. Diagonal
highlights: pitch repeats. Bold cells where transition % > 30% to
draw eye to dominant tendencies.

---

## 6. Components used

From `visual-primitives.md`:
- Section dividers + titles
- Catcher header (light variant)

New for Pitch Calling:
- `ac-pivot-table` — Streamlit Styler wrapper w/ AC color tokens
  (gradient color uses `--accent-positive` for high values)
- `ac-zone-mini` — small Plotly heatmap config helper

---

## 7. CSS additions

```css
.ac-pitchcalling-header {
    margin: var(--space-4) 0 var(--space-3);
}
.ac-pitchcalling-header h2 {
    font-family: 'Special Gothic Expanded One', sans-serif;
    font-size: 22px;
    color: var(--accent-emphasis);
    margin: 0;
}
.ac-pitchcalling-header p {
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    color: var(--text-mono-label);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 4px 0 0;
}

.ac-zone-grid {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: var(--space-2);
    margin: var(--space-3) 0;
}
```

---

## 8. Build checklist

- [ ] `ac_dashboard/data/pitch_calling.py` — `PitchCallingFacts` dataclass + `get_pitch_calling_facts()` + SQL fetch
- [ ] Verify catcher attribution via `cur_event_id` vs `ab_event_id` — match `catcher_data.get_catcher_game_pitches`
- [ ] `ac_dashboard/components.py` — `render_pivot_table_with_gradient(df, accent_color)`
- [ ] `ac_dashboard/components.py` — `render_zone_heatmap(plate_x, plate_z, sz_top_avg, sz_bot_avg, title)`
- [ ] `ac_dashboard/tab_pitch_calling.py` — `render()` orchestrator
- [ ] Pitch type universe selector — only show top N (5? 7?) most-common types per catcher; group rest as "Other"
- [ ] Empty state when catcher has < 100 pitches called at level (insufficient sample)
- [ ] CSS additions per §7
- [ ] Smoke test: Diaz pitch calling — count distribution sums to 100% per row, handedness pivot covers expected (RHP→LHB, RHP→RHB, etc.)

---

## 9. Open questions

- Q1: Show all pitch types or top N? Default: top 5-7 by frequency,
  fold rest into "Other" column.
- Q2: Sequencing — should it be game-level (resets per game) or pitcher-
  level (resets per new pitcher)? Default: pitcher-level (pitch-call
  patterns reset when a new pitcher comes in).
- Q3: Outcome overlay — show whiff% or call% on each cell as secondary
  data? Defer to v2 — start clean with frequency only.
- Q4: Comparison view — overlay catcher's mix vs league average for
  same level? Useful but complex; defer.
- Q5: Pre-2K vs 2K filter — already a primitive in catcher reports.
  Add as toggle at top? Default: no filter, show all counts.
- Q6: Selectable pitcher filter — "show only pitches Diaz called for
  Garcia"? Defer to v2; would crowd UI.
- Q7: Click-to-video on individual pitches — on a heatmap that's
  density-aggregated, individual pitches lose identity. Skip CTV here;
  Gameday is the per-pitch detail view.
- Q8: Min sample gate — when does sequencing start being meaningful?
  At least 200 pitches at level? Hide if below.

---

## 10. References

- `2026-05-07-ac-visual-primitives.md`
- `2026-05-07-ac-dashboard-master-spec.md`
- `intangibles/src/catcher_data.py::get_catcher_game_pitches` — JOIN reference
- `.claude/rules/db-joins.md` — `cur_event_id` vs `ab_event_id` patterns
- `.claude/rules/db-columns.md` — `c_id`, `pitch_type`, count columns
- `.claude/rules/sz-framework-savant-zones.md` — strike zone framework
- KDB Pitch Calling: https://kdbbeta85v2.netlify.app/ → click PITCH CALLING
