---
paths:
  - "**/src/*report*.py"
  - "**/src/*report.py"
  - "**/src/plots.py"
---

# PDF & Plottable Rendering Patterns

## Plottable Null Fix — `_fix_null_bbox(table)`
When ALL values in a column are `None` (dtype=object), plottable skips cmap (it checks `isinstance(cell.content, Number)` — None fails). Matplotlib default bbox facecolor `#1f77b4` (blue) shows through.

**Fix:** Post-processor that hides bbox for null cells:
```python
def _fix_null_bbox(table):
    for row in table.rows.values():
        for cell in row.cells:
            if hasattr(cell, "_text") and cell._text and cell._text.get_text().strip() in ("—", ""):
                rect = cell._text.get_bbox_patch()
                if rect:
                    rect.set_visible(False)
```
Call AFTER `Table()` construction, BEFORE `table.plot()`.

## Per-Row Percentile Coloring (BLOCKING — silent failure)

When switching from plottable `cmap` (whole-column) to per-row coloring,
you MUST add explicit `bbox` to `textprops` on every column you intend
to color. Without it, `cell.text.get_bbox_patch()` returns `None` and
`set_facecolor()` is **silently skipped — no error, just no color**.
This is the most common "my coloring loop ran but the PDF is white"
trap in this codebase.

```python
# Define bbox once, share across the columns that need coloring.
# dict() per ColumnDefinition — don't share a single object;
# matplotlib mutates it.
_bbox = {"boxstyle": "round,pad=0.3",
         "edgecolor": "none", "facecolor": "#FFFFFF"}

col_defs = [
    # Columns that DO get colored: bbox required
    ColumnDefinition(name="PL @ 2B", textprops={
        "ha": "center", "bbox": dict(_bbox)}),
    ColumnDefinition(name="SL @ 2B", textprops={
        "ha": "center", "bbox": dict(_bbox)}),
    ColumnDefinition(name="Org",     textprops={
        "ha": "center", "weight": "bold", "bbox": dict(_bbox)}),
    # Columns that stay default: no bbox needed
    ColumnDefinition(name="Rank",    textprops={"ha": "center"}),
    ColumnDefinition(name="SB 2->3", textprops={"ha": "center"}),
]

# After Table() render — override facecolor per cell.
# Use column-name access (not numeric index) so the hidden index column
# below doesn't shift indices.
for row_idx in range(len(df)):
    cell = table.columns["PL @ 2B"].cells[row_idx]
    bp = cell.text.get_bbox_patch()
    if bp is not None:
        bp.set_facecolor(color_for_rank(...))
```

**Diagnostic when coloring "doesn't work":**
1. Did you set `bbox` in textprops on the coloring target columns? If not, that's the bug.
2. Print `bp = cell.text.get_bbox_patch(); print(type(bp))` — should be `FancyBboxPatch`, not `NoneType`.
3. After `bp.set_facecolor(color)`, print `bp.get_facecolor()` — should be the new RGB tuple, not white.

If all three pass and the PDF still looks white, the bug is in the
color logic, not the rendering wiring.

## Hidden Index Column — Suppress plottable's Leftmost Default

Plottable shows the DataFrame's index as the leftmost column by
default. With a default `RangeIndex` (`reset_index(drop=True)`), that
shows `0, 1, 2, ...` next to your real data — usually unwanted.

**Canonical fix:** name the index `"idx"`, set every value to `""`,
then add an invisible `ColumnDefinition(name="idx")` as the first
col_def.

```python
def _hide_df_index(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.index = [""] * len(df)
    df.index.name = "idx"
    return df

_HIDDEN_INDEX = ColumnDefinition(
    name="idx", width=0.001,
    textprops={"fontsize": 0.1, "color": "white"},
)

# Usage:
display_df = _hide_df_index(my_df)
col_defs = [_HIDDEN_INDEX, ColumnDefinition(name="Org", ...), ...]
table = Table(display_df, column_definitions=col_defs, ...)
```

**Why both halves matter:**
- `_hide_df_index()` alone → plottable still renders the index column
  with whatever name pandas had; defaults to "index" or no name, takes
  visible width.
- `_HIDDEN_INDEX` ColumnDefinition alone → plottable shows the index
  values themselves (`0, 1, 2, ...`); width=0.001 + tiny white text
  hides the values but the column still consumes a sliver of layout.

Together: column has width 0.001 inches (effectively zero), index
values are empty strings, fontsize=0.1 white text means even those
empty strings render imperceptibly.

**Never:**
- Use `index_col=None` thinking it suppresses the index — it doesn't,
  it controls which DATA column to use as the index.
- Add a "Rank" or "#" column thinking that replaces the index — it
  doesn't; plottable still adds its own index column to the left of it.
  Use the `_HIDDEN_INDEX` pattern AND your visible Rank column if you
  want both.

## plottable Column ORDER = DataFrame column order (BLOCKING)

**plottable renders columns in the order of the DataFrame's `df.columns`,
NOT in the order of the `column_definitions` list.** `ColumnDefinition`
controls per-column STYLING (width, font, alignment, bbox); it does not
reorder anything. The visual left-to-right column order is determined by
the dict insertion order in `display_rows.append({...})` (which becomes
`df.columns` order via `pd.DataFrame(display_rows)`).

This costs hours every time it's relearned. Document the rule, follow it.

### The trap

```python
# Reordering col_defs alone — DOES NOTHING for visual order:
col_defs = [
    _HIDDEN_INDEX,
    ColumnDefinition(name="Date"),     # styling only
    ColumnDefinition(name="Name"),
    ColumnDefinition(name="React"),
    ColumnDefinition(name="ReRad"),    # I "moved" this here
    ColumnDefinition(name="Main"),     # I "moved" this to end
    ColumnDefinition(name="Side"),
]

# But the dict still has Main/Side BEFORE ReRad:
display_rows.append({
    "Date": ..., "Name": ..., "React": ...,
    "Main": ..., "Side": ...,    # ← these still render at idx 4-5
    "ReRad": ...,                 # ← this renders at idx 6
})
# Visual order: Date | Name | React | Main | Side | ReRad
# (NOT Date | Name | React | ReRad | Main | Side)
```

### The fix

To change visual column order, you MUST reorder the dict-key insertion in
`display_rows.append({...})`. Reorder the col_defs to match for clarity,
and update any column-index constants (`_MAIN_COL_IDX` etc.) and
`_KPI_COL_MAP` lookups in the same commit.

### Audit checklist when changing visual column order

1. Reorder dict-key insertion in `display_rows.append({...})` — this
   actually moves the column.
2. Reorder `col_defs` list to match — for source-readability, not because
   it affects layout.
3. Update column-index constants (`_MAIN_COL_IDX`, `_SIDE_COL_IDX`, etc.)
   to reflect new positions.
4. Update `_KPI_COL_MAP` (or equivalent) so percentile-coloring lookups
   land on the right cells.
5. Verify ALL FOUR are updated before commit. The combination is what
   moves the column AND keeps coloring + video links wired.

### Reference implementation

Standard daily OF report `_make_display_df()` at `intangibles/src/of_postgame_report.py:495`
puts Main/Side LAST in the dict (after all 10 KPI metrics). The Mazzo
Special variant in the same function mirrors that ordering. If a future
report needs Main/Side at the end, follow that template; if it needs
them after Description (older daily reports), follow the per-app pattern
but always cross-check the dict order matches the col_def order.

### Bug history

- 2026-05-02 (Mazzo Special): Added 8 OF tracking metrics. First fix
  attempt only reordered col_defs; Main/Side still rendered after React
  because dict order was unchanged. Second fix reordered the dict and
  index constants in lockstep. Lesson: col_defs are styling, dict
  insertion is layout.

**Reference implementations:**
- `pd-goals/src/wpa_plays_report.py` — original canonical
- `pd-goals/scripts/generate_org_2b_3b_sb.py` — one-off org ranking PDF

## Click-to-Video Pattern (Streamlit)
- `st.components.v1.html` with `window.open()` — do NOT pass `key=` param (crashes on Posit Connect)
- `st.markdown` with `<script>` does NOT work (Streamlit strips script tags)
- Track **pitch identity**, NOT selection count (count-based fails on pitch swap)
- Video URL stored in Plotly `customdata` at known indices per chart type

## Images in PDF
- `BboxImage` + `TransformedBbox` at figure coords WORKS
- `AnnotationBbox` / `fig.add_axes` FAIL SILENTLY
- Unicode (U+2605) for star symbols in table cells

## Video Link in Table Cells
`tab.cells[row_idx, col_idx].text.set_url(url)` — clickable in PDF

## Click-to-Video on PDF Plot Markers — BLOCKING (Apr 27 2026)

Verified empirically against matplotlib's PDF backend (`backend_pdf.py`)
with `pypdf` annotation inspection. **Only `Text` and `Annotation`
artists actually write `/Link` annotations to the output PDF.** Every
other artist's `set_url()` call is silently dropped.

| matplotlib artist | `set_url` writes `/Link` annotation? |
|---|---|
| `Text` (`ax.text(...)`) | **YES** |
| `Annotation` (`ax.annotate(...)`) | **YES** |
| `PathCollection` (`ax.scatter(...)`) | NO — silently dropped |
| `Line2D` (`ax.plot(...)`) | NO — silently dropped |
| `Patch` (Rectangle, Circle, Polygon) | NO — silently dropped |

That's why the existing video-triangle table cells work (plottable
uses `cell.text.set_url`, a Text artist) and naive `scatter.set_url()`
or `Line2D.set_url()` overlays do not — the URL is stored on the artist
in memory but never serialized into the PDF.

### Canonical recipe

Render the visual marker as usual (scatter / plot / whatever), THEN
overlay an invisible `Text` "X" at the same data coordinate carrying
`set_url`. Empty text yields a zero-area `/Rect` (unclickable), so use
a single character with near-zero alpha:

```python
def _attach_clickable(ax, x, y, url, fontsize: int = 14) -> None:
    if not _is_valid_url(url):
        return
    t = ax.text(x, y, "X", fontsize=fontsize,
                color=(0, 0, 0, 0.001),  # 0.1% opacity — imperceptible
                ha="center", va="center", zorder=100)
    t.set_url(str(url))


def _attach_clickable_3d(ax, x, y, z, url, fontsize: int = 14) -> None:
    """Same recipe in Axes3D — Text3D URL is also honored by PDF backend."""
    if not _is_valid_url(url):
        return
    t = ax.text(x, y, z, "X", fontsize=fontsize,
                color=(0, 0, 0, 0.001),
                ha="center", va="center", zorder=100)
    t.set_url(str(url))
```

`fontsize=14` produces roughly a 14×16 point clickable bbox — generous
enough to hit reliably without overlapping neighbors at typical plot
density. Tune up for sparser plots (release scatter, throws 3D), down
for dense ones.

### URL guard

```python
def _is_valid_url(url) -> bool:
    if url is None:
        return False
    try:
        if pd.isna(url):
            return False
    except Exception:
        pass
    return str(url).startswith("http")
```

So callers can pass `row.get('pitch_video_url')` without guarding NaN
or missing columns.

### Verification — every PDF that wires this should pass

```python
import pypdf
r = pypdf.PdfReader("path/to/report.pdf")
n = sum(1 for p in r.pages for a in (p.get('/Annots') or [])
        if str(a.get_object().get('/A', {}).get_object().get('/URI', '')).startswith('http'))
print(f"{n} link annotations")
```

Expected: total dot count + table-triangle count. If the count matches
table triangles only, the overlay isn't producing annotations.

### What NOT to do

- **Don't** call `scatter.set_url()` on the visual marker. It does
  nothing in PDF backend. (Also true for `plot.set_url()` and
  `Patch.set_url()`.)
- **Don't** use `ax.text(x, y, "")` — empty text writes a zero-height
  `/Rect` that no PDF reader honors as a click target.
- **Don't** use Rectangle/Circle Patch overlays. They do not produce
  PDF link annotations even though they look like the right tool.
- **Don't** use a high-alpha or visible color for the click overlay —
  it'll be a faint X mark on every dot. Stick with `alpha=0.001`.
- **Don't** rely on Slack preview / Gmail preview / browser-tab inline
  PDF view to test click behavior. They flatten link annotations. Use
  Acrobat / Preview / Chrome's full-tab PDF viewer / Edge.

### Reference implementation

`intangibles/src/catcher_report.py` — `_attach_clickable` +
`_attach_clickable_3d` helpers + 4 wired plot sites (SZ scatter
4-panel, throws 3D scatter, blocks scatter, setup-position scatter).
Commit chain: `67d9fcf` (first attempt — scatter set_url, didn't
work), `1113fe0` (second attempt — Line2D, didn't work), `9f4dc54`
(Text — works), `00ef27b` (kwarg rename followup).

When extending this to other apps (Barrelsville hitter postgame /
weekly hitter, Arm Farm pitcher postgame movement / location / release
plots, Intangibles OF/IF/BR weekly reports), copy the helpers from
catcher_report.py verbatim and call them after each visual scatter
with the appropriate URL column from the data layer. Data-layer video
URL columns already exist in every postgame data module via the
`Astros.Video` LEFT JOIN (`pitch_video_url`, `throw_video_url`,
`block_video_url`, etc.).

### Cross-app rollout status (Apr 27 2026)

| Surface | Worktree | Wired? |
|---|---|---|
| Catcher postgame | intangibles | LIVE |
| Hitter postgame zone grid | barrelsville | TODO |
| Weekly hitter spray + scatter | barrelsville | TODO |
| Pitcher postgame movement / location / release | bullpen-report | TODO |
| OF/IF/BR weekly per-player plots | intangibles | TODO |
| Bullpen sessions (postgame B-type) | bullpen-report | N/A — no video rows in `Astros.Video` for bullpen sched_types |

## 1-Click PDF Download (Streamlit)
Generate PDF bytes BEFORE `st.download_button` renders → button has data on first render. No tab navigation needed.

## App-Reactive PDF (Share Data With On-Screen Chart)

When an app-generated PDF must mirror whatever the user sees on screen (filtered pitch types, custom column selections, derived stats), DO NOT let the PDF generator re-query for that data — it will not know about client-side state.

**Pattern:**
1. PDF generator accepts an **optional kwarg** for the reactive dataset (e.g. `arm_angles_by_type=None`, `goal_overrides=None`). If `None`, fall back to DB fetch (keeps CLI use working). If supplied, use it verbatim.
2. App **pre-fetches + filters** the dataset once before the PDF-generation block so the same dict feeds both the on-screen chart and the PDF.
3. App folds a **fingerprint of the dataset** into the existing `_pdf_fp` fingerprint so the PDF regenerates when the reactive state changes.
4. App **passes the dict** to the generator via the new kwarg.

```python
# ---- PDF generator (src/*_report.py) ----
def generate_postgame_report(
    ..., arm_angles_by_type: dict = None,
) -> Optional[str]:
    ...
    # If the caller (app) handed us a filtered dict, honor it.
    # Otherwise fall back to the DB fetch (CLI path).
    if arm_angles_by_type is not None:
        _arm_by_pt = arm_angles_by_type
    else:
        _arm_by_pt = get_arm_angle_by_pitch_type(gc_id, game_date=game_date)

# ---- App page (pages/N_*.py) ----
# Fetch once, filter to active state
_arm_full = _cached_arm_angle_by_pt(pid, sched_ids=tuple(selected_sched_ids))
_active_pts = set(pitch_df['pitch_type'].unique())
_arm_for_pdf = {pt: s for pt, s in _arm_full.items() if pt in _active_pts}

# Fingerprint must include the dict so PDF regenerates on change
_arm_fp = sorted((pt, round(s.get('avg', 0), 1)) for pt, s in _arm_for_pdf.items())
_pdf_fp = f"{pid}|{sorted(sched_ids)}|...|{_arm_fp}"

# Pass via kwarg
generate_postgame_report(..., arm_angles_by_type=_arm_for_pdf)
```

**Applies to:** Any app/report pair where client-side filters (pitch type toggle, date range, outlier removal) should affect the PDF. First use was Arm Farm postgame arm-angle box (Apr 17 2026). Same pattern fits Barrelsville KPI custom column selection, Intangibles advance overlays, and PD Goals goal overrides.

**What NOT to do:**
- Don't have the PDF generator re-query the DB for data the app already filtered — results diverge.
- Don't forget to include the reactive dict in `_pdf_fp` — the PDF will be stale.
- Don't make the kwarg required — CLI scripts calling the generator directly should still work without it.

## Cumulative PDF over Multi-Select — Postgame-Style Apps (BLOCKING)

**Scope:** This applies ONLY to apps where the on-screen view *pools* the selected items into one cumulative view (the postgame family — Arm Farm postgame, Barrelsville postgame, Catcher postgame). In those apps, the Save button MUST emit ONE PDF that reflects the pooled view — never a ZIP of per-item PDFs. The pool is the deliverable.

**Where ZIPs are CORRECT (do not apply this rule):**
- **Advance scouting** — coaches need individual per-pitcher / per-hitter PDFs to print and hand out. The deliverable shape IS many independent PDFs. ZIP is the right packaging.
- **Batch report generators** (KPI weekly per-level, weekly hitter per-player) — each PDF is a distinct independent artifact by design.
- **Any app where the on-screen view shows individual items** (not a pool) — the save should match the view.

The defining test: *does the on-screen view aggregate the selected items into one combined display?* If yes → cumulative single PDF. If no → individual PDFs (or ZIP) is correct.

**Canonical pattern (mirrors Arm Farm postgame `bullpen-report/pages/2_Postgame.py:1097`):**

1. The on-screen render pools selected items into shared dataframes (`pitch_all`, `throws_all`, etc.) and computes pooled metrics ONCE.
2. Build a `_pdf_fp` fingerprint covering every selection that affects the report (`player_id`, `sorted(selected_ids)`, sched_type, level, active column toggles, etc.).
3. Only regenerate when fingerprint changes; cache bytes in `st.session_state["_<app>_pdf_bytes"]`.
4. Pass the **already-pooled** dataframes + metrics into a SINGLE `generate_*_report()` call.
5. Render one `download_button` into the sidebar placeholder.

```python
_pdf_fp = f"{player_id}|{sorted(selected_ids)}|{sched_type}|{level}|..."

if st.session_state.get("_x_pdf_fp") != _pdf_fp:
    with st.spinner("Generating PDF..."):
        pdf_path = generate_x_report(
            ..., pitch_df=pitch_all, throws_df=throws_all, ...
        )
        if pdf_path:
            st.session_state["_x_pdf_bytes"] = open(pdf_path, 'rb').read()
            st.session_state["_x_pdf_fname"] = Path(pdf_path).name
            st.session_state["_x_pdf_fp"] = _pdf_fp

if "_x_pdf_bytes" in st.session_state:
    save_placeholder.download_button("Save Report",
        data=st.session_state["_x_pdf_bytes"],
        file_name=st.session_state["_x_pdf_fname"],
        mime="application/pdf", use_container_width=True)
```

**Reference impls:** Arm Farm postgame, Barrelsville postgame, Catcher postgame (`intangibles/pages/4_Catching.py` — refactored Apr 30 2026 commit `32c918a` from per-game ZIP to cumulative single PDF).

**For per-section "single-game-only" fields** (opponent name when multi-game, etc.): pre-initialize them at module top with safe defaults (None / 0 / "-") and only overwrite inside `if len(selected_ids) == 1:`. Pass the variable unconditionally to the generator; report renders blank for that field on multi-item PDFs.

**What NOT to do (within the scoped postgame-style apps):**
- NEVER loop per-item and emit a ZIP from a postgame-style app. The on-screen view is already pooled — the save should match it. (ZIPs in advance scouting / batch generators are a different pattern, see scope above.)
- NEVER re-fetch per-item data inside the save handler when pooled vars are in scope.
- NEVER skip the fingerprint cache. Without it the PDF regenerates on every UI tick (checkbox click, hover) and the page feels broken.
- NEVER name your filename / fingerprint key with a generic prefix like `_pdf_*` — collide with other apps. Use app-prefixed (`_pg_pdf_*` Arm Farm, `_c_pdf_*` Catcher).

## Bar Chart Values
Values INSIDE bars (white text, centered) — boss feedback. Applies to all bar/battery charts.

## Multi-Page PDFs — Two Valid Patterns

Both work. Pick based on what's easier for your generator.

### Pattern A — Single `PdfPages` context, multiple figures

Use when you control both page generators in the same module. Most
existing reports in this codebase use this (e.g.
`intangibles/src/if_postgame_report.py:830`):

```python
from matplotlib.backends.backend_pdf import PdfPages

with PdfPages(out_path) as pdf:
    pdf.savefig(fig_page_1)
    pdf.savefig(fig_page_2)
```

No extra library needed. Annotations (video-link `set_url()`) are
preserved natively by matplotlib's PDF backend.

### Pattern B — Render separate PDFs, merge with pypdf / PyPDF2

Use when the two pages come from separate, already-working generators
that each write their own PDF and you don't want to refactor. WPA plays
report uses this (`pd-goals/scripts/generate_wpa_plays.py`):

```python
try:
    from pypdf import PdfReader, PdfWriter
except ImportError:
    from PyPDF2 import PdfReader, PdfWriter

writer = PdfWriter()
for src in (page_1_pdf, page_2_pdf):
    reader = PdfReader(str(src))
    for page in reader.pages:
        writer.add_page(page)
with open(combined_pdf, "wb") as f:
    writer.write(f)
```

**BLOCKING:** use `PdfReader + add_page`, NOT `writer.append(src)`. PyPDF2
3.x's `append()` has a known bug that crashes on PDFs containing
annotations (clickable video links produce annotations):
`AttributeError: 'DictionaryObject' object has no attribute 'indirect_reference'`.

`add_page(page)` preserves annotations verbatim and works with both
`pypdf` and `PyPDF2`.

### When to use which

| Situation | Pattern |
|---|---|
| Pages share a data query or are built in the same module | A (PdfPages) |
| Pages come from two separate `generate_*_report()` functions with their own PDF output | B (PdfReader + add_page) |
| No external deps allowed | A |

## Section Pagination — Row-Budget Across Multi-Section Pages

When a single fixed-height page renders 2+ variable-length tables top-down with a `y_cursor`, long source data on any earlier section will clip the bottom one. Hard row caps + shrink-to-fit guards are band-aids that hide data. Solution: a fixed `ROWS_PER_PAGE` budget shared across all sections, with chunked rendering that page-breaks when the budget hits zero and continues the section on a fresh page.

**Pattern (canonical impl: `intangibles/src/catcher_report.py::_draw_video_review_page`, Apr 30 2026 commit `ed086d5`):**

```python
ROWS_PER_PAGE = 40  # combined cap across all sections on a video page

# Pre-build display dfs upfront so row counts are known
sections = [
    ('throws', "2B Throws", throws_df, throws_disp, "No throws"),
    ('blocks', "Dirtball",  None,      blocks_disp, "No blocks"),
    ('recv',   "Receiving", None,      recv_disp,   "No framing"),
]

fig, y_cursor = _start_page(catcher_name)
rows_used = 0

def _new_page():
    nonlocal fig, y_cursor, rows_used
    _finalize_page(pdf, fig, footer_text)
    fig, y_cursor = _start_page(catcher_name)
    rows_used = 0

for sec_idx, (kind, title, src, disp, empty_msg) in enumerate(sections):
    if sec_idx > 0:
        y_cursor -= 0.04  # inter-section spacing

    if disp.empty:
        # render title + placeholder, no budget consumed
        continue

    rows_remaining = len(disp)
    offset = 0
    is_continuation = False

    while rows_remaining > 0:
        if rows_used >= ROWS_PER_PAGE:
            _new_page()
            is_continuation = True

        chunk_n = min(rows_remaining, ROWS_PER_PAGE - rows_used)
        title_text = f"{title} (continued)" if is_continuation else title
        fig.text(0.04, y_cursor, title_text, fontsize=10, fontweight='bold')
        y_cursor -= 0.015

        chunk = disp.iloc[offset:offset + chunk_n]
        y_cursor = _render_section(kind, fig, y_cursor, chunk, ...)

        rows_used += chunk_n
        offset += chunk_n
        rows_remaining -= chunk_n
        is_continuation = True

_finalize_page(pdf, fig, footer_text)
```

**Helpers (~10 LOC each):**
- `_start_page(name)` — fresh figure with navy header, returns `(fig, initial_y_cursor)`
- `_finalize_page(pdf, fig, footer)` — draw footer, savefig, close

**Per-section render functions** (`_render_throws_table`, `_render_blocks_table`, etc.) take pre-sliced display dfs + `y_cursor`, render exactly those rows, return new `y_cursor`. Build the full display df ONCE upfront so percentile coloring + URL decoration use stable indices.

**Why a fixed row count** (not dynamic y-space measurement): predictable, matches what other PDFs in the codebase already do, no fragile math about title heights / footer reserves / table padding. Slight wasted whitespace on partial pages is fine.

**When sections fill leftover space vs. start fresh:**
- **Default — fill leftover space.** Section N+1 starts on the same page as section N if budget remains. Matches Arm Farm / Barrelsville postgame pagination.
- **Exception — start fresh page** when section is structurally different (e.g., catcher setup grids on their own pages, one per pitcher). Don't mix grid layouts with table flow.

**Anti-patterns to remove when adopting this:**
- Hard row caps (`max_rows = min(len(df), 25)`) + "Showing N of M" footer notes. Pagination obsoletes both.
- Shrink-to-fit guards (`if y_cursor - table_height < min_y: table_height = y_cursor - min_y`). They squish the bottom table instead of paginating.

**Cross-app candidates for this pattern:** Any matplotlib + plottable PDF page that stacks 2+ variable-length tables with a `y_cursor`. As of Apr 30 2026, only catcher postgame has it; Arm Farm postgame and Barrelsville postgame mostly fit on one page so haven't needed it. Apply when a season/cumulative selection starts clipping.
