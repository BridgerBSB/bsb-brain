---
paths:
  - "**/*tracker*.py"
  - "**/pages/*.py"
---
# Tracker "Stat (Rank)" Display Mode

LIVE on all 5 affiliate trackers as of 2026-05-25. Combined display
mode that renders `.385 (3)` / `11.8% (27)` / `4.2 (5)` in each metric
cell — pre-formatted string of stat value + rank in parens. Set as
the DEFAULT (first radio option) per user direction.

Pure reactive UI — uses existing per-metric stat values + rank columns
already computed in `ranked_df`. **No pin re-runs needed.**

---

## Display modes (radio options, in order)

```
Display Mode: ( Stat (Rank) | Stat | Percentile | Rank )
                  ^^^^^^^^^^^
                  default (index=0)
```

| Mode | Cell renders | Sort behavior | Notes |
|---|---|---|---|
| **Stat (Rank)** | `.385 (3)` / `11.8% (27)` / `-` | Lex sort on strings | Default. NEW May 25 2026. |
| Stat | `.385` / `11.8%` | Numeric sort | Pre-existing |
| Percentile | `75` | Numeric sort | Pre-existing — bare integer 1-100 |
| Rank | `3` | Numeric sort | Pre-existing — bare integer rank |

`higher_is_better` is honored across ALL modes:
- Lower-is-better metrics (Whiff%, Pop Time, React, Exch) → rank=1 for the LOWEST value
- Higher-is-better metrics (Stat (Rank), Arm, TopSpd) → rank=1 for the HIGHEST value
- Coloring uses `percentile_to_color(pct, higher_is_better=hib)` — flipped per metric

---

## The 5 tracker page files (each implements the same 6-7 touchpoints)

| Tracker | Worktree | File | Commit |
|---|---|---|---|
| Barrelsville (hitter) | `bsb-wt-hitting` | `barrelsville/pages/2_Affiliate_Tracker.py` | `1be405ea` on `feature/barrelsville` |
| Arm Farm (pitcher) | `bsb-wt-bullpen` | `bullpen-report/pages/3_Affiliate_Tracker.py` | `827df2f3` on `feature/bullpen-reports` |
| Intangibles BR | `bsb-wt-intangibles/astros-intangibles` | `intangibles/src/br_tracker_page.py` | `11527f9b` on `feature/astros-intangibles` |
| Intangibles OF + IF | same | `intangibles/src/fielding_tracker_page.py` | same commit |
| Intangibles Catcher | same | `intangibles/src/catching_tracker_page.py` | same commit |

---

## The 6 (or 7) touchpoints per file

When changing how `Stat (Rank)` renders (cell format, sort behavior,
adding ordinal "#" prefix, etc.), update ALL touchpoints in lockstep
across ALL 5 files. Same discipline as `slack-channels-sync.md`.

### 1. Radio definition (1 site per file)
```python
display_mode = st.radio(
    "Display Mode",
    ["Stat (Rank)", "Stat", "Percentile", "Rank"],   # Stat (Rank) FIRST
    index=0,                                          # default
    key="<file>_display_mode",
    horizontal=True,
)
```

### 2. `_stat_fmt_string(key)` helper (module-level)
Returns the printf format string for a metric's stat value. Extracted
from the inline logic previously inside `_build_styler_format`. Some
files have format-specific extensions:

| File | Extra format kinds |
|---|---|
| Barrelsville | `pct1`, `f0-f3`, `int` |
| Arm Farm | + `pct2`, `ip_thirds` (baseball notation X.Y where Y∈{0,1,2}) |
| BR | + `str` (passthrough for fraction-string metrics like 1B PL/SL display) |
| Fielding | standard |
| Catcher | + `pctN` for any N digits (multi-decimal pct) |

### 3. `_format_stat_rank_cell(stat_val, rank_val, fmt_str, ...)` helper
The combined string builder. Returns:
- `"-"` when stat is None/NaN/inf
- `stat_str` alone when rank is missing
- `f"{stat_str} ({int(rank_val)})"` when both present

Per-file extensions for special format kinds (`ip_thirds`, `frac_str`).

### 4. `_build_styler_format` — passthrough for "Stat (Rank)"
```python
if display_mode == "Stat (Rank)":
    # Cells already pre-formatted as strings — passthrough formatter
    fmt[label] = lambda v: v if isinstance(v, str) else "-"
elif display_mode in ("Percentile", "Rank"):
    ...
```

### 5. `_build_leaderboard_display` / `_build_org_display` (or per-file equivalents)
Add a `Stat (Rank)` branch BEFORE the existing `Percentile` branch that
builds pre-formatted string cells:

```python
if display_mode == "Stat (Rank)":
    rank_col = f"{key}_rank"
    stat_vals = source_df[key]
    if rank_col in ranked_df.columns:
        rank_vals = ranked_df[rank_col]
    else:
        rank_vals = source_df[key].rank(
            ascending=not hib, method="min", na_option="bottom",
        )
    fmt_str = _stat_fmt_string(key)
    display[label] = [
        _format_stat_rank_cell(s, r, fmt_str)
        for s, r in zip(stat_vals.values, rank_vals.values)
    ]
```

Also update the early-return for missing-column case:
```python
if key not in source_df.columns:
    if display_mode == "Stat (Rank)":
        display[label] = "-"
    else:
        display[label] = _sentinel
    continue
```

### 6. `_trend_annotation` — combined branch
```python
if display_mode in ("Stat", "Stat (Rank)"):
    # ... compute stat_txt as before ...
    if display_mode == "Stat":
        return stat_txt, "#888888"

    # "Stat (Rank)" — append rank in parens
    rank_int = None
    if peer_values is not None:
        # mirror the existing "Rank" branch's peer-based rank logic
        ...
    elif trend_dists and level_code and season is not None:
        # mirror the existing "Rank" branch's pool-based rank logic
        ...
    if rank_int is not None:
        return f"{stat_txt} ({rank_int})", "#888888"
    return stat_txt, "#888888"
```

### 7. Inline HOU-by-level sub-tab (Arm Farm + BR + Fielding + Catcher ONLY)

Barrelsville does NOT have this — the other 4 files have an inline
per-level HOU sub-tab block (around line 2055 in Arm Farm, similar
locations elsewhere) that mirrors the org-display branching. When
you patch the main display functions you must ALSO patch the inline
block — it has its own `if at_display_mode == "Stat":` / `Percentile`
/ `Rank` branches.

---

## What does NOT change

- **`_apply_percentile_bg` / `_color_dataframe` / coloring helpers** — already read from a separate `ranked_df` with pctile columns. Honor `higher_is_better` via `percentile_to_color(pct, higher_is_better=hib)`. Unaffected by display mode.
- **`column_config_for_metrics`** — all 5 files use generic `st.column_config.Column(label, help=...)` for metric cells. Generic Column accepts string content. Do NOT switch to `NumberColumn` or `TextColumn` — that would override the Styler.format-driven rendering.
- **Underlying data, pins, percentile pools, weighted-mean aggregation** — display mode is purely a presentation layer. Pin contents identical.
- **Other 3 display modes** (Stat / Percentile / Rank) — same behavior as before. Pure additive change.

---

## Known quirks

### Lex sort on string cells (BY DESIGN)

When the user clicks a metric column header in `Stat (Rank)` mode,
Streamlit sorts the string cells lexicographically — not numerically.

For most metrics this gives the intuitive sort because the stat-value
leading characters dominate (`.385 (3)` lex-sorts before `.391 (1)`
which is what a descending stat sort would do anyway). But for mixed-
magnitude metrics — e.g., comparing `.385 (3)` against `1.054 (1)` —
lex sort breaks because `'.' < '1'` in ASCII.

User explicitly accepted this trade-off May 25 2026 in design
discussion. If a user needs strict numeric sort, they switch to `Stat`
or `Rank` mode.

### "-" fallback semantics

The passthrough formatter returns `"-"` for any non-string cell. This
covers:
- Metric column missing from source_df (early-return sets `"-"`)
- Some upstream edge case where `display[label]` was populated with a
  non-string value (shouldn't happen, but the formatter is defensive)

Both cases render visually as a single dash. NOT a crash.

---

## Bug history

- **May 25 2026** — Initial implementation. User request: "add a fourth
  period dot that's gonna be the default... metric (rank) just gonna be
  a combination of the two pretty much." Pattern verified across all 5
  tracker page files (identical `display_mode` branching structure).
  Implemented on Barrelsville canonically (commit `1be405ea`); ported
  verbatim to the other 4 files via subagent (Arm Farm `827df2f3`,
  Intangibles `11527f9b`). All 5 files parse clean; 12-13 `"Stat (Rank)"`
  occurrences per file. Zero pin re-runs needed.

---

## What NOT to do

- **Don't** drop the `"Stat (Rank)"` from `index=0` position on the radio. User direction: this IS the default. Putting any other mode first reverts the UX.
- **Don't** switch `_column_config_for_metrics` to `NumberColumn` or `TextColumn` for metric cells. Generic `Column()` is REQUIRED so Styler.format-driven string cells render correctly.
- **Don't** add `'#'` prefix to the rank in parens (`.385 (#3)`). User chose bare integer `.385 (3)` in design — change requires re-confirmation.
- **Don't** change the format-string mechanism (`%.0f` for rank). Always render rank as integer; never decimal.
- **Don't** drop the `isinstance(v, str)` check from the passthrough formatter. A non-string slip-through must render `"-"`, not crash.
- **Don't** forget the inline HOU-by-level patch in Arm Farm / BR / Fielding / Catcher (touchpoint #7). Barrelsville doesn't have this so it's easy to miss when porting.
- **Don't** add `"Stat (Rank)"` to the `_pool_styler_format` call in any file's Level Pools sub-tab. That sub-tab uses the literal string `"Value"` as display_mode — different code path.
- **Don't** try to enable numeric sort on string cells via Streamlit's column_config. No supported API; would require custom JS in `st.components.v1.html`. Not worth the complexity.

---

## Cross-references

- `slack-channels-sync.md` — same cross-worktree sync discipline applies to this rule file (lives in all 4 worktrees byte-identical).
- `tracker-save-screen.md` — sibling tracker-wide UI rule (browser print PDF export). Same byte-identical sync pattern.
- `tracker-new-metric-checklist.md` — when adding a NEW metric column to a tracker, that metric's display in `Stat (Rank)` mode comes for free (uses the same per-metric `fmt` lookup). No additional work needed for the new mode beyond standard metric-add steps.
- `streamlit-tracker-column-pinning.md` — pixel-width column pinning rule. Independent of display mode; same pinned info cols regardless.
- `pdf-last-in-script.md` — Streamlit page convention. Tracker pages comply; display mode doesn't change this.

---

## Cross-worktree sync (this rule file)

Lives byte-identical in all 4 worktrees:
- `bsb-resources/.claude/rules/tracker-stat-rank-display.md`
- `bsb-wt-hitting/.claude/rules/tracker-stat-rank-display.md`
- `bsb-wt-bullpen/.claude/rules/tracker-stat-rank-display.md`
- `bsb-wt-intangibles/.claude/rules/tracker-stat-rank-display.md`

When this rule changes, sync all 4 in lockstep. See
`slack-channels-sync.md` for sync mechanics.
