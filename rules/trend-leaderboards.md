---
paths:
  - "**/pages/*Affiliate_Tracker*.py"
  - "**/pages/*Tracker*.py"
  - "**/pages/*Catching*.py"
  - "**/*tracker_page.py"
  - "**/*tracker_data.py"
---

# Trend Leaderboards — Affiliate Tracker Sub-Tab (reusable across all 6 trackers)

A tracker sub-tab that ranks entities (HOU players / all 30 orgs) by how they've
**trended** on ONE selected metric, as 3 side-by-side boards (Week-over-Week,
Month-over-Month, Year-over-Year). **Improvers up top, decliners at the bottom**,
direction-aware. Built in Arm Farm Jun 23-24 2026 as the reference impl; the
SAME pattern ports to Barrelsville / BR / Catching / OF / IF.

**Reference impl:** `bullpen-report/pages/3_Affiliate_Tracker.py`
(`with tab_trend_leaderboards:` block). Commits `73bbf63d` (initial) →
`c16dd1ad` (Org scope + YoY fallback + @st.fragment + narrow selectbox) →
Rank column. Status memory: `arm-farm-trend-leaderboards-status.md`.

---

## Core principle — ZERO new pins, ZERO new SQL

The boards are **pure presentation on the trend frames the Trends tab already
loads** (weekly / monthly / yearly, player + org — all pin-served). The ONLY new
compute is the per-entity **latest-vs-prior Δ + sort**. This is what makes it
fast to ship and free on the pin side. NEVER add a pin grain or a query for this.

- All-levels selection → served from the existing pin (instant).
- Level subset → the existing live-query path the Trends tab already uses (NOT a re-pin).
- Reactive to the sidebar **Level + Season** (a full rerun reloads the frames).

## Anatomy (mirror these pieces per tracker)

1. **Tab order:** move "Level Pools" to the END; slot "Trend Leaderboards" before
   it. Visual order = the `st.tabs([...])` label-list order ONLY — the `with tab_x:`
   code blocks do NOT move. Add the new tab var to the unpack.
2. **Placement:** put the `with tab_trend_leaderboards:` block in the code AFTER the
   `with tab_trends:` block so the loaded trend frames + helper vars are in scope
   (Python `with` does NOT scope; `st.tabs` runs every block each render).
3. **`@st.fragment` wrapper (BLOCKING for UX):** wrap the whole tab body in an
   `@st.fragment def _render_...(): ...` and call it. Changing the metric/scope
   then reruns ONLY this tab — NOT the page's heavy AgGrids/charts (that full-page
   rerun is a ~20s stall). Sidebar changes still do a full rerun (keeps reactivity).
   `st.fragment` is available (already used in `bullpen-report/pages/2_Postgame.py`).
4. **Scope toggle:** keyed `st.radio(["HOU (players)", "Org (all 30)"], key=...)`.
5. **Metric selector:** single `st.selectbox` inside `st.columns(3)[0]` so it's ~one
   board width, NOT full page. Options = the tracker's player/org trend-metric union
   (`_trends_metrics_union` / `_trends_org_metrics_union`). Prune stale session value.
6. **Per-(entity, period) one-value frame:**
   - **HOU/player** = primary level that period: `sort_values(weight_col, desc)
     .drop_duplicates(["<id>"] + period_cols)`.
   - **Org** = pool across the org's selected levels, **weighted** (`bf` if the metric
     is PA-weighted else `n_pitches` — mirror that tracker's Org-mode trend-chart
     aggregation; the weight column is tracker-specific).
7. **Shared `_board`:** sort distinct periods, take the **last two**, slice prev/cur,
   inner-join per entity (needs BOTH periods), `delta = now - prev`, then
   `sort_values("delta", ascending = not hib)` — **direction-aware via the tracker's
   `HIGHER_IS_BETTER_MAP`** (improvement on top: ↑-metric biggest +Δ; ↓-metric biggest
   drop). This auto-handles "more whiff lost = better" on the hitting tracker.
8. **`_render`:** Styler with **Rank as the leftmost column** (`disp.insert(0, "Rank",
   range(1, len+1))` — Rank = sorted position, 1 = biggest improver), then
   `Entity | prior-period | now | Δ`. Δ formatted with sign + ▲/▼ and colored green
   (improved) / red (declined) by goodness. Height = fit-all (`35*(n+1)+3`, capped) →
   no internal scroll = "no height cap".
9. **YoY single-season fallback:** if the yearly frame has only one season, load the
   PRIOR year from the pin (`_load_all_yearly((yr-1,), ...)` / the org equiv) and
   concat, so YoY shows latest-vs-year-before on load. ≥2 seasons → use the latest two
   present (unchanged).

## Period semantics

| Board | period identity | "last two" |
|---|---|---|
| WoW | `(season, week_start)` | most recent week vs the week before |
| MoM | `(season, game_month)` | this month vs last month |
| YoY | `(season,)` | latest vs prior season (auto-pulls prior if only 1 selected) |

Each board needs the entity present in BOTH periods (a Δ needs two points — free
`dropna`, not a min-sample gate). Inherited per-period minimums differ by grain and
come from the existing trend loaders — DO NOT add new gates (no added compute).

## Enhancement (Jun 27 2026) — Start/End selectors + bold HOU + year labels (LIVE all 6)

Shipped to all 6 trackers (Barrelsville hitting, Arm Farm pitching, BR, Catching,
OF, IF). Three additions on top of the original last-two-periods board:

1. **Start/End period dropdowns per board.** `_board` no longer hardcodes the last
   two periods — it takes explicit `(prepped, period_cols, start_key, end_key)` and
   returns ONLY the sorted DataFrame (labels come from the caller). A `_one_board(col,
   frame, period_cols, grain, key_prefix, title)` helper renders two narrow
   `st.selectbox`es (Start / End) above each board, options built by a new `_periods()`
   helper (distinct period keys + labels from the frame). **Default index = len-2 /
   len-1 → latest two, so on-load behavior is UNCHANGED.** Keyed selectboxes persist
   the pick across fragment reruns; a stale-key prune (`del st.session_state[k]` when
   the stored value left the options) prevents a Streamlit error after a Season change.
2. **Bold HOU on Org boards.** `_bold_hou_row(row)` is a Styler `.apply(axis=1)` that,
   in Org scope only, bolds the HOU row + peach fill (`#FCE9D6`) + navy left accent
   (`border-left:3px solid #002D62`). Chained AFTER the Δ `_color` apply so HOU's Δ
   keeps its green/red. `_render` signature became `_render(res, prev_lbl, cur_lbl)`.
3. **Weekly labels carry the year** (`_plabel` weekly → `strftime("%b %d '%y")`) so
   multi-season weeks (`Jul 22 '25` vs `'26`) are unambiguous in BOTH the dropdowns
   and the column headers. Matches the monthly format.

### Speed model — reuse Trends' frames; NEVER load all years eagerly (BLOCKING)

The boards reuse the frames the **Trends tab already loaded** (`_weekly_*_result`,
`_monthly_*_result`, `_yearly_*_result`), so the leaderboards can't be slower than
Trends. YoY needs ≥2 seasons but the sidebar defaults to one, so `_augment_yoy` pulls
the **single prior season** (pin-served, cached) — the only extra load.

- **DON'T** eagerly load all pinned years (`range(_MIN_SEASON, current_year+1)`) just to
  populate the year dropdown — that was a Jun 27 misstep that made the tab fire up
  3-4 cold pin reads slower than Trends. Reverted. To compare further-back years, the
  user adds the season in the **sidebar** (the same full-page-reload cost Trends pays —
  shared, cached). Week/Month live inside a season → free once that season is loaded.
- A `[TL-YoY]` timing `print` wraps the `_augment_yoy` loader call so Connect logs show
  cache-hit (~0s) vs pin-read (~few s) vs **live-SQL fallback (~30s = a missing
  historical pin → one-time `pin_tracker_seasons` backfill, NOT a code bug)**.
- The grey-out on a sidebar change is normal Streamlit full-rerun dimming (every tab
  does it); fragment-internal changes (metric/scope/Start-End) rerun only the tab.

### Per-tracker hooks for THIS enhancement (already adapted in each file)

| Tracker | selectbox key prefix | `_augment_yoy` loader-call arity |
|---|---|---|
| Barrelsville | `at_tl_*` | `loader((yr-1,), sched_types_tuple, ha_split=, hand_split=)` |
| Arm Farm | `at_tl_*` | same (ha/hand split) |
| BR | `br_tl_*` | `loader((yr-1,), sched_types_tuple)` |
| Catching | `c_tl_*` | `loader((yr-1,), sched_types_tuple)` |
| OF + IF (one file) | `{domain}_at_tl_*` (`of_`/`if_` keep OF/IF distinct) | `loader(domain, ha_split, (yr-1,), sched_types_tuple)` |

What's IDENTICAL across all 6: `_periods`, `_board` (start/end), `_bold_hou_row`,
`_render`, `_one_board`, the 3 board calls, the weekly year label, the caption.
What DIFFERS (pre-existing): entity id col, Org weight col, direction map, metric
default — all already in each file's `_prep_*` / if-else.

Commits: Barrelsville `47e856d9`→`b680429d`→`4773993c`; Arm Farm `15962c79`;
Intangibles (BR+Catching+OF+IF) `be4bd4c6`.

## Per-tracker port recipe (Barrelsville / BR / Catching / OF / IF)

Same code, swap the tracker's hooks. For each tracker, find and wire:

| Hook | What it is |
|---|---|
| Page + tabs | the tracker's `pages/*Tracker*.py` (or `fielding_tracker_page.py`); reorder its `st.tabs([...])` (pools last, leaderboards before) |
| Trend frames | the weekly / monthly / yearly **player** loaders the Trends tab already calls + the **org** equivalents |
| Entity id / name | per-player id + display name map (Arm Farm: `_player_names_all` on `pitcher_id`); hitting uses `batter_id`, fielding/catcher/BR use the fielder/runner id |
| `HIGHER_IS_BETTER_MAP` | the tracker's own direction map (drives the sort + ▲/▼; each tracker's good-direction differs, e.g. hitter Whiff% ↓) |
| Weight column / PA-weighted set | for Org pooling — `bf` vs `n_pitches` for Arm Farm; hitting/fielding/catcher/BR use their own (`n_pa`, `n_throws`, `n_plays`, etc.) — mirror that tracker's existing Org-mode trend aggregation |
| `selected_level_codes` | the sidebar level selection (already present in every tracker page) |
| YoY prior-year loader | the tracker's `_load_all_yearly` / `_load_yearly_org` equivalents |

What is IDENTICAL across all 6: the `@st.fragment` wrapper, scope radio, narrow
selectbox, `_board` (Δ + direction-aware sort), `_render` (Rank + colored Δ),
`_augment_yoy`. What DIFFERS: the frame loaders, the entity id column, the weight
column for org pooling, and the direction map — all already exist in each tracker.

## Gotchas

- **Multi-level in one period:** player board uses the **primary** (most-volume) level
  that period — a deliberate approximation (most players are single-level per period).
  Refine to a pooled value only if a coach flags it.
- **Org level-filter:** orgs span levels; the Org board pools the org's *selected*
  levels per period. Filtering to one level shows that level's org pool.
- **New metrics need the re-pin** to appear in the metric dropdown (the pinned trend
  frames must carry the column). Existing metrics work immediately.
- **Three-surface parity does NOT apply** — this is a display-only reshape of existing
  data, not a new metric. No new metric definition is introduced.

## What NOT to do

- **Don't** add a new pin grain or SQL query for trends deltas — reuse the loaded frames.
- **Don't** skip `@st.fragment` — without it every metric toggle reruns the whole page
  (the ~20s stall). It's the single most important UX piece.
- **Don't** hardcode the sort direction — always read the tracker's `HIGHER_IS_BETTER_MAP`
  so lower-is-better metrics flip correctly.
- **Don't** move the `with tab_x:` code blocks to reorder tabs — reorder the
  `st.tabs([...])` label list only.
- **Don't** place the leaderboards block before `with tab_trends:` — its frames/vars
  won't be defined yet.
