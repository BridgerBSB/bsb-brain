# AC Dashboard — Stats Tab Spec

**Date:** 2026-05-07
**Tab:** `?view=dashboard&tab=stats`
**Module:** `intangibles/src/ac_dashboard/tab_stats.py`
**Mirrors KDB:** Stats page
**Build order:** FIFTH
**Build estimate:** 1-2 days
**New SQL?** Minimal — mostly leverages existing `get_yearly_catcher_stats`

---

## 1. Goal

Year-by-year stat splits for a single catcher, defensive + hitting,
across all affiliate levels they played at. KDB calls this "Stats —
Year-by-year hitting and defensive stats from FanGraphs, Savant,
BBRef." Our equivalent reads from internal HOU data.

---

## 2. User flow

1. User selects catcher (year selector irrelevant — Stats is multi-year)
2. Tab renders two sections: defensive year-over-year + hitting year-
   over-year
3. Each row = one (year, level) pairing
4. Sparkline column shows trajectory across rows for key metrics
5. Click any row → open Catcher Cards tab for that (catcher, year, level)

---

## 3. Layout sketch

```
┌─────────────────────────────────────────────────────────────────────┐
│ [← BACK]                              [Catcher ▼]                   │
│                                                                     │
│   YAINER DIAZ — CAREER STATS                                        │
│   Throws: R · Bats: R · Age: 27.4                                   │
│                                                                     │
│ ┌─ DEFENSIVE STATS BY YEAR ─────────────────────────────────────┐  │
│ │ Year  Level  Pitches  NetK   FramRAA  Pop2B  Arm   R2K%  BlkR │  │
│ │ 2026  AAA    1822     +24.5  +12.4    1.91   86.2  28.4  +5.2 │  │
│ │ 2025  MLB    3940     +18.2  +9.8     1.93   85.1  26.1  +3.8 │  │
│ │ 2025  AAA     412     +4.8   +2.4     1.92   85.8  29.0  +1.1 │  │
│ │ 2024  MLB    4218     +12.1  +5.4     1.95   84.2  24.8  +2.4 │  │
│ │ 2023  AAA    2104     +8.4   +3.2     1.96   83.9  23.4  +0.8 │  │
│ │ 2023  MLB     820     +1.2   +0.4     1.98   83.1  22.0  -0.4 │  │
│ │ 2022  AAA    1856     +3.6   +1.4     2.01   82.4  21.2  -1.8 │  │
│ │                                                                │  │
│ │ ─── Sparklines ───                                            │  │
│ │ NetK trajectory:    ▁▂▂▃▅▅█                                  │  │
│ │ FramRAA trajectory: ▁▂▃▃▄▆█                                  │  │
│ │ Pop2B trajectory:   █▆▅▄▃▂▁  (lower = better, inverted)      │  │
│ │ Arm trajectory:     ▁▂▄▅▆▆█                                  │  │
│ └────────────────────────────────────────────────────────────────┘  │
│                                                                     │
│ ┌─ HITTING STATS BY YEAR ──────────────────────────────────────┐   │
│ │ Year  Level   PA    AVG   OBP   SLG   K%    BB%   wRC+      │   │
│ │ 2026  AAA    142   .298  .354  .478  16.9  6.3   124        │   │
│ │ 2025  MLB    412   .276  .328  .452  18.2  5.4   118        │   │
│ │ 2025  AAA     98   .315  .378  .520  14.3  6.1   136        │   │
│ │ ...                                                          │   │
│ └──────────────────────────────────────────────────────────────┘   │
│                                                                    │
│ ┌─ MULTI-YEAR ROLLUP (career) ─────────────────────────────────┐   │
│ │   CAREER (all levels combined)                              │   │
│ │   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │   │
│ │   │ Pitches  │ │ NetK     │ │ FramRAA  │ │ Pop2B    │      │   │
│ │   │ 15,172   │ │ +72.8    │ │ +35.0    │ │ 1.95 avg │      │   │
│ │   └──────────┘ └──────────┘ └──────────┘ └──────────┘      │   │
│ └──────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Data sources

### 4.1. Defensive yearly

Already exists: `catching_tracker_data.get_yearly_catcher_stats(...)`.
Returns one row per (catcher, year, level) with all defensive metrics.

Filter call to `catcher_id = selected_id`, all years available
(2022-2026), all levels.

### 4.2. Hitting yearly

NEW — but lightweight. Hitting stats for catchers come from the same
patterns Barrelsville uses. Easiest path: SQL that hits
`Astros.SplitsBat` or per-PA aggregates from `Pitches_View` +
`Events_View`.

[NOTE: hitting stats may not currently live in any catching-specific
module. Could:
(a) Pull via MLBAM.SplitsBat (if mirrored in HOU DB)
(b) Aggregate from Events_View (raw PA outcomes)
(c) Skip hitting on v1 — defensive only — and add hitting when user
    confirms data source preference
Recommend defaulting to (c) for v1: defensive-only with `[NOTE: hitting
deferred]` placeholder for the second section.]

### 4.3. Career rollup

Sum `pitches`, sum `netk`, sum `fram_raa`, sum `block_raa`, weighted-
avg `pop_time` + `arm` + `r2k_pct` by per-row pitch counts (per
`multi-level-rollup.md` rules — weight by per-metric n_obs, not by
n_pitches).

---

## 5. Sparkline rendering

For each metric column with multi-year trajectory:

```python
import altair as alt
spark = alt.Chart(per_year_df).mark_line(strokeWidth=1.5).encode(
    x=alt.X("year:O", axis=None),
    y=alt.Y("netk:Q", axis=None),
).properties(width=100, height=20)
st.altair_chart(spark)
```

Or simpler: use unicode block sparklines (▁▂▃▄▅▆▇█) generated server-
side. Compact, no extra render layer. KDB uses unicode blocks.

[Default: unicode blocks. Faster, simpler, matches KDB feel.]

---

## 6. Visual rendering

### 6.1. Stats tables

`st.dataframe` styled minimally:
- Year column: bold, navy
- Level column: small caps mono
- Metric columns: percentile-colored (lookup season distributions per
  metric × level via `catcher_percentiles.get_catcher_percentiles()`)
- Sparkline: text-rendered unicode blocks in trailing summary row

### 6.2. Career rollup

4 KPI tiles (compact variant from Gameday). Total pitches, NetK, FramRAA,
weighted-avg Pop2B.

---

## 7. Multi-level handling

When a catcher played multiple levels in one year (e.g. 2025 MLB +
AAA), display BOTH rows separately. Don't merge. KDB does this too.

Per `.claude/rules/multi-level-rollup.md`: a single "year total" row
that combines levels would require careful weighted aggregation.
Skip for v1 — career rollup row at the bottom is enough.

---

## 8. Components reused

- `ac-card` — section containers
- `ac-kpi-tile-compact` (from Gameday)
- `ac-pivot-table` styling (from Pitch Calling)
- Section dividers + titles

---

## 9. CSS additions

Minimal — mostly reuses existing tokens.

```css
.ac-stats-section {
    margin: var(--space-4) 0;
}
.ac-stats-sparkline {
    font-family: 'JetBrains Mono', monospace;
    font-size: 14px;
    color: var(--accent-emphasis);
    letter-spacing: 1px;
}
```

---

## 10. Build checklist

- [ ] `ac_dashboard/tab_stats.py` — `render()` orchestrator
- [ ] Defensive table from `get_yearly_catcher_stats(catcher_id)`
- [ ] Hitting table — DEFERRED if no hitting data layer; placeholder w/ `[Hitting stats deferred to v2]`
- [ ] Career rollup tiles via per-metric weighted avg (NOT n_pitches!) per `multi-level-rollup.md`
- [ ] Sparkline column via unicode blocks
- [ ] Row click → routes to Catcher Cards w/ that (year, level) selection
- [ ] Smoke test: Diaz multi-year — values match `?view=tracker` for each (year, level)

---

## 11. Open questions

- Q1: Hitting stats — defer to v2, or pull from existing module? Need
  to confirm if `Astros.SplitsBat` or `MLBAM.SplitsBat` exists for our
  catchers across affiliate levels. Default: defer.
- Q2: Career rollup row — show only on hover, or as a dedicated panel?
  Default: dedicated panel below the table.
- Q3: Sparkline scope — unicode blocks (KDB style) vs Altair line
  charts? Default: unicode blocks for simplicity + KDB visual match.
- Q4: Year sort order — descending (latest first) vs ascending (career
  arc)? Default: descending. Career row at bottom.
- Q5: Display only HOU-org years, or include any year (e.g. trade
  history)? Default: include all years; HOU scope is for the catcher
  pool, not the per-catcher history view.
- Q6: League percentile per row — color cells by season pool, or just
  show raw values? Default: raw values for v1; percentile coloring
  later if asked.

---

## 12. References

- `2026-05-07-ac-visual-primitives.md`
- `2026-05-07-ac-dashboard-master-spec.md`
- `intangibles/src/catching_tracker_data.py::get_yearly_catcher_stats`
- `.claude/rules/multi-level-rollup.md` — per-metric n_obs weighting
- `.claude/rules/feedback_age_formatting.md` — age display
- KDB Stats: https://kdbbeta85v2.netlify.app/ → click STATS
