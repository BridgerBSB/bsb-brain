# Click-to-Video PDF System — Engineering Reference

**Status:** LIVE on 5 surfaces across 3 worktrees as of 2026-04-27.

This doc is the comprehensive deep-dive on how matplotlib-generated PDFs in
this codebase carry clickable per-pitch hyperlinks to the sporty-clips video
of each pitch. Use it when extending click-to-video to a new report, when
debugging "click does nothing" reports from coaches, or when an agent
proposes a different mechanism (so you can shut that conversation down with
the empirical evidence below).

The actionable summary of this doc lives at
`.claude/rules/pdf-patterns.md` § "Click-to-Video on PDF Plot Markers"
(synced across all 4 worktrees). This is the long-form reference.

---

## 1. What we shipped

Five reports got clickable per-pitch / per-throw / per-BIP hyperlinks on
every visual. Click any dot in any plot in any of these PDFs → browser
opens the sporty-clips video of that exact pitch.

| Surface | Worktree | Branch | Commit |
|---|---|---|---|
| Catcher postgame | bsb-wt-intangibles | feature/astros-intangibles | `00ef27b` (final, after 4-commit journey) |
| Arm Farm pitcher postgame | bsb-wt-bullpen | feature/bullpen-reports | `39e16d3` |
| Barrelsville hitter postgame | bsb-wt-hitting | feature/barrelsville | `ba819d7` |
| Barrelsville weekly hitter | bsb-wt-hitting | feature/barrelsville | `86b9473` |
| Barrelsville advance scouting | bsb-wt-hitting | feature/barrelsville | `c238f43` |

Per-surface plot inventory in §7.

**What this is NOT:** in-app Streamlit click-to-video (different mechanism,
documented separately at `.claude/rules/visual-standards.md` § "Click-to-Video
Pattern (Streamlit Apps)").

**What is excluded by design:**
- Bullpen reports (`sched_type='B'`) — `Astros.Video` has no rows for
  bullpen sessions, so there's no URL to link to.
- Heatmaps via `imshow`, KDE `contourf`, density contours — these have no
  per-pitch markers by construction. Cannot be clicked per pitch even
  conceptually.
- Pie charts, aggregated arm-angle plots, summary tables (other than the
  per-pitch row tables which already had video URLs via plottable cells).

---

## 2. The problem we solved

PDFs natively support clickable hyperlinks via `/Link` annotation
dictionaries embedded in each page. Acrobat, Apple Preview, Chrome's
full-tab PDF viewer, and Edge all honor them as clickable regions.

The catcher postgame report already had clickable **table-cell triangles**
(`▶`) in the play-by-play table. Coaches click the triangle → video opens.
That worked because plottable's table cells use matplotlib `Text` artists,
and `Text.set_url()` wires through to the PDF backend's annotation writer.

What didn't exist: clickable **plot markers**. The 100+ pitch dots on each
SZ scatter, the 80-pitch movement chart, the spray BIPs — every one of those
was inert. Coaches had to find the corresponding row in the table and click
the triangle. Multiple-clicks-per-pitch UX. Worse than no click-to-video at
all because it taught coaches that the dots aren't interactive.

Goal: click any dot → video. Same one-click behavior the Streamlit apps
already have via Plotly + `customdata`.

---

## 3. The empirical discovery (took 4 commits)

The naïve approach is `marker_artist.set_url(url)` after every scatter.
That's how the existing table cells work. **It doesn't work for scatter.**

**Verified empirically with `pypdf` annotation inspection** (matplotlib
3.8.0 local; matplotlib 3.10.x on Posit Connect — both produce the same
output):

| matplotlib artist | `set_url()` writes `/Link` annotation? |
|---|---|
| `Text` (`ax.text(...)`) | **YES** ✓ |
| `Annotation` (`ax.annotate(...)`) | **YES** ✓ |
| `PathCollection` (`ax.scatter(...)`) | NO — silently dropped |
| `Line2D` (`ax.plot(...)`) | NO — silently dropped |
| `Patch` (Rectangle, Circle, Polygon) | NO — silently dropped |

The relevant code is in matplotlib's `lib/matplotlib/backends/backend_pdf.py`.
The `RendererPdf.draw_path` method DOES emit annotations via `_writeURLs`,
but `RendererPdf.draw_path_collection` (which scatter goes through) does
NOT call `_writeURLs`. Same for the patch and Line2D rendering paths.

This is matplotlib internal behavior — no flags or backend options change
it. The only artists that produce PDF link annotations are `Text` and its
subclass `Annotation`.

### Why we know this beyond a doubt

The diagnostic test (preserved here for posterity — re-create if you
encounter "set_url isn't working" again):

```python
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from matplotlib.backends.backend_pdf import PdfPages
import pypdf

with PdfPages("test.pdf") as pdf:
    # Scatter
    fig, ax = plt.subplots()
    pc = ax.scatter([1, 2, 3], [1, 2, 3], s=100)
    pc.set_url("https://example.com/scatter")
    pdf.savefig(fig); plt.close(fig)

    # Line2D
    fig, ax = plt.subplots()
    line, = ax.plot([1], [1], marker="o", markersize=20, linestyle="")
    line.set_url("https://example.com/line2d")
    pdf.savefig(fig); plt.close(fig)

    # Annotation
    fig, ax = plt.subplots()
    ann = ax.annotate("CLICK", xy=(0.5, 0.5), xycoords="axes fraction", fontsize=20)
    ann.set_url("https://example.com/annotation")
    pdf.savefig(fig); plt.close(fig)

    # Text
    fig, ax = plt.subplots()
    t = ax.text(0.5, 0.5, "CLICK", fontsize=20, transform=ax.transAxes)
    t.set_url("https://example.com/text")
    pdf.savefig(fig); plt.close(fig)

    # Patch
    fig, ax = plt.subplots()
    rect = Rectangle((0.3, 0.3), 0.4, 0.4, facecolor="red", alpha=0.3,
                     transform=ax.transAxes)
    ax.add_patch(rect)
    rect.set_url("https://example.com/rectangle")
    pdf.savefig(fig); plt.close(fig)

reader = pypdf.PdfReader("test.pdf")
for i, page in enumerate(reader.pages, 1):
    annots = page.get("/Annots") or []
    print(f"Page {i}: {len(annots)} annotations")
    for a in annots:
        obj = a.get_object()
        action = obj.get("/A", {})
        if hasattr(action, "get_object"):
            action = action.get_object()
        print(f"  URI={action.get('/URI')}  Rect={obj.get('/Rect')}")
```

Output (matplotlib 3.8.0):
```
Page 1 (scatter):    0 annotations
Page 2 (Line2D):     0 annotations
Page 3 (Annotation): 1 annotation  URI=https://example.com/annotation
Page 4 (Text):       1 annotation  URI=https://example.com/text
Page 5 (Patch):      0 annotations
```

The catcher report's existing video triangles work because plottable's
table cells use `cell.text.set_url(url)` — which is a `Text` artist call,
the one path that produces annotations.

---

## 4. The canonical recipe

**Render the visual marker as usual** (don't change the existing
`scatter`/`plot`/whatever — visual is fine). **THEN overlay an invisible
`Text` "X" at the same data coordinate carrying `set_url()`.**

```python
def _is_valid_url(url) -> bool:
    """Guard for None / NaN / non-http URLs so callers can pass row values
    without explicit checks."""
    if url is None:
        return False
    try:
        if pd.isna(url):
            return False
    except Exception:
        pass
    return str(url).startswith("http")


def _attach_clickable(ax, x, y, url, fontsize: int = 14) -> None:
    """2D version: attach an invisible Text click target with URL annotation."""
    if not _is_valid_url(url):
        return
    t = ax.text(x, y, "X", fontsize=fontsize,
                color=(0, 0, 0, 0.001),  # 0.1% opacity — imperceptible
                ha="center", va="center", zorder=100)
    t.set_url(str(url))


def _attach_clickable_3d(ax, x, y, z, url, fontsize: int = 14) -> None:
    """3D variant for Axes3D scatter overlays. Text3D URL is honored."""
    if not _is_valid_url(url):
        return
    t = ax.text(x, y, z, "X", fontsize=fontsize,
                color=(0, 0, 0, 0.001),
                ha="center", va="center", zorder=100)
    t.set_url(str(url))
```

### Why each detail matters

- **`"X"` (not empty string).** Empty text writes a zero-area `/Rect`
  in the PDF, which no PDF viewer treats as a click target. A single
  character gives the annotation a non-zero bbox.

- **`color=(0, 0, 0, 0.001)`** — 0.1% alpha is below visual perception
  threshold but the PDF backend still renders the path (and writes the
  annotation). At 100% zoom in any viewer, the X is invisible.

- **`ha="center", va="center"`** — centers the text bbox on the data
  coordinate. Without this, the click bbox is offset from the visual
  marker.

- **`zorder=100`** — puts the click target on top of the visual scatter.
  Doesn't really matter for click behavior (PDF is flat) but consistent
  with "overlay on top".

- **`fontsize=N`** — tunes click target size. `fontsize=14` produces
  roughly a 14×16 point clickable rect — generous enough to hit
  reliably without overlapping neighbors at typical plot density.
  Tune up for sparser plots (release scatter, throws 3D), down for
  dense ones (zone grid cells with many dots stacked).

### Standard fontsize cheat sheet

| Plot density / style | Recommended fontsize |
|---|---|
| Sparse (release scatter, throws 3D, spray with few BIPs) | 12-14 |
| Medium (movement scatter ~80 dots, postgame zone with ~10 per cell) | 10-12 |
| Dense (catcher SZ panel ~50 pitches, weekly hitter heart zone) | 8-10 |

If you go below 8, click targets become finicky. If you go above 14
on a busy plot, click targets overlap and Acrobat picks the topmost
annotation — neighbors become unclickable.

---

## 5. Data layer: the video URL column

The recipe needs a URL per pitch. The DB-side mechanism for getting one
is the **3-tier video URL fallback chain** documented at
`.claude/rules/video-angles.md`:

```sql
-- The canonical V column standard (every app that ships click-to-video uses this):
ISNULL(av.video_url,                       -- 1. Astros.Video angle_id=1  (PRIMARY)
  ISNULL(vn_v.video_url, vn_a.video_url))  -- 2. Video_Network 'v' → 3. 'a'
AS cf_angle_url

-- Required JOINs:
LEFT JOIN Astros.Video av
    ON av.sched_id = pv.sched_id AND av.pitch_id = pv.pitch_id AND av.angle_id = 1
LEFT JOIN Astros.Video_Network vn_v
    ON vn_v.sched_id = pv.sched_id AND vn_v.pitch_id = pv.pitch_id AND vn_v.angle = 'v'
LEFT JOIN Astros.Video_Network vn_a
    ON vn_a.sched_id = pv.sched_id AND vn_a.pitch_id = pv.pitch_id AND vn_a.angle = 'a'
```

Why three tiers: `Astros.Video` is the MLB sporty-clips host — IT-approved
for player phones, only populated for MLB games + Astros-home MiLB games.
`Video_Network` is the Astros internal CDN — broader coverage but RND
inconsistently ingests the V angle. The fallback chain catches both
populated paths.

**Result column name is `cf_angle_url` everywhere.** Every wired report
expects `row.get('cf_angle_url')`. Don't rename it.

### When the data module already has it

Most postgame data modules already had this JOIN before click-to-video
shipped, because the **table-cell video triangles** needed it too.
Specifically:

- `bullpen-report/src/postgame_data.py` — already had
- `barrelsville/src/postgame_data.py` — already had
- `intangibles/src/catcher_data.py` — already had

So for those surfaces, wiring click-to-video on plots was just adding
the helper + overlay loops. No data-layer changes.

### When the data module needs the JOIN added

Two of the five surfaces shipped required adding the JOIN because they
fetched data via different SQL paths that didn't include video columns:

- `barrelsville/src/weekly_hitter_data.py::get_visual_data` — three queries
  (`spray_df`, `heart_df`, `swings_df`) all needed `sched_id`, `pitch_id`,
  and the 3-tier JOIN.
- `barrelsville/src/advance_data.py::_SCOUTING_PITCHES_QUERY` and
  `_MULTI_SEASON_XBH_QUERY` — both needed the JOIN.

When adding the JOIN to a new query, **also update the empty-fallback
DataFrames** so callers that hit "no data" paths still get the new
columns (`'cf_angle_url' in df.columns` checks need to remain truthy).

### Why "inline SQL JOIN" vs "Python merge_video_urls helper"

Two callable patterns exist in this codebase:

- **Inline SQL JOIN** — used in `weekly_hitter_data.py`, `advance_data.py`,
  `intangibles/src/catcher_data.py`. The video JOIN lives directly in the
  query SELECT. Cleanest when there's no pre-fetched `sched_id` list.

- **Python `merge_video_urls` helper** — `barrelsville/src/video.py::get_pitch_videos`
  + `merge_video_urls(df)`. The helper queries video for a known list of
  `sched_id`s, then merges onto the dataframe in Python. Cleanest when you
  already have a pitch dataframe and need to add URLs as a post-step.

Both produce identical `cf_angle_url` output. Match the pattern of the
sibling module you're extending.

---

## 6. Required packages

**No new packages introduced.** The recipe works with what's already in
`requirements.txt`:

| Package | Why we need it | Status |
|---|---|---|
| `matplotlib` | PDF backend writes the annotations | Already required (every report) |
| `pandas` | DataFrame + `pd.isna` for URL guard | Already required |
| `pypdf` | Verification only — count `/Link` annotations in generated PDF | Already in `pd-goals/requirements.txt` for the WPA Plays merger |

Packages we explicitly DID NOT need (despite some coordinator suggestions):

| Package | Why suggested | Why we don't need it |
|---|---|---|
| `html2image` | "Render URL to image/PDF" | Wrong direction — that's URL→PDF, we want PDF→URL clicks |
| `Api2Pdf` | "URL to PDF API" | Same — wrong direction, also a paid API service |
| `pdf2image` | "PDF to image" | Wrong direction, kills interactivity |
| `imgkit` / `wkhtmltopdf` | "HTML to PDF" | Wrong direction |

The native matplotlib PDF backend already supports link annotations.
We just had to figure out which artist types it actually honors.

---

## 7. Wired surfaces — full inventory

### 7.1. Catcher postgame (`intangibles/src/catcher_report.py`)

**Commit chain:** `67d9fcf` (first attempt — scatter set_url, didn't work)
→ `1113fe0` (second attempt — Line2D, didn't work) → `9f4dc54` (Text — works)
→ `00ef27b` (kwarg rename followup).

| Plot | Function | Click target |
|---|---|---|
| Strike Zone — RHP Fastballs panel | `_draw_strike_zone_plots` | Every pitch dot |
| Strike Zone — RHP Off-speed/Breaking | `_draw_strike_zone_plots` | Every pitch dot |
| Strike Zone — LHP Fastballs | `_draw_strike_zone_plots` | Every pitch dot |
| Strike Zone — LHP Off-speed/Breaking | `_draw_strike_zone_plots` | Every pitch dot |
| 2B Throws 3D scatter | `_draw_throws_scatter` | Every throw (CS `o` + SB `x`) |
| Blocks scatter — Block markers | `_draw_blocks_scatter` | Every block `o` |
| Blocks scatter — PB/WP markers | `_draw_blocks_scatter` | Every PB/WP `x` |
| Setup-position scatter (video review page) | `_draw_video_review_page` | Every pitch dot in 9 pitcher × bat-side cells |

Data: `pitch_video_url`, `throw_video_url`, `block_video_url` — all already in `catcher_data.py`.

### 7.2. Arm Farm pitcher postgame (`bullpen-report/src/postgame_report.py`)

**Commit:** `39e16d3`.

| Plot | Line | Click target |
|---|---|---|
| Page 1 — Rolling velocity chart | `~910` | Every pitch dot per pitch type |
| Page 1 — Pitch movement scatter (HorzBrk × IVB) | `~978` | Every pitch dot per pitch type |
| Page 2+ — LVA grid (12 cells: pitch type × count state) | `~2391` | Every pitch dot per result category |
| Page 2+ — LVA grid fallback | `~2403` | Every pitch dot when `pitch_result_id` missing |

Data: `cf_angle_url` from `bullpen-report/src/video.py::get_pitch_videos` +
`merge_video_urls` (already in app path; CLI path also patched in this commit).

**Notable:** Rolling velocity chart in `'avg'` mode plots a smoothed 3-pitch
mean. The clickable Text overlay sits at the smoothed Y, not the raw pitch Y,
so a coach clicking a marker gets the right pitch's video but at a
vertically-offset spot from where their finger landed. Cosmetic.

### 7.3. Barrelsville hitter postgame (`barrelsville/src/postgame_report.py`)

**Commit:** `ba819d7`.

| Plot | Function | Click target |
|---|---|---|
| Zone grid — Pre-2K Takes | `_draw_takes_zone` | Every take |
| Zone grid — 2K Takes | `_draw_takes_zone` | Every take |
| Zone grid — Pre-2K Swings (fouls + BIPs + whiffs) | `_draw_swings_zone` | Every swing |
| Zone grid — 2K Swings | `_draw_swings_zone` | Every swing |
| Zone grid — Pre-2K BIPs | `_draw_bips_zone` | Every BIP |
| Zone grid — 2K BIPs | `_draw_bips_zone` | Every BIP |

Data: `cf_angle_url` already merged onto `pitch_df` via `merge_video_urls`
in both app path (`pages/1_Postgame.py:362`) and CLI path
(`scripts/generate_postgame.py:199` + `:462`).

Coordinate convention: Barrelsville hitter postgame uses **catcher's view**
(raw `plate_x`, home plate point DOWN). Overlay coordinates pass raw
`plate_x` to match.

### 7.4. Barrelsville weekly hitter (`barrelsville/src/weekly_hitter_report.py`)

**Commit:** `86b9473`. Required SQL JOIN additions to
`barrelsville/src/weekly_hitter_data.py::get_visual_data`.

| Plot | Function | Click target |
|---|---|---|
| Spray chart (BIP dots over Minute Maid fence) | `_draw_spray_chart` | Every BIP dot |
| Heart zone (per-pitch dots over zone) | `_draw_heart_zone` | Every pitch dot |
| Swings chart (per-swing dots over zone) | `_draw_swings_chart` | Every swing dot |

**Skipped intentionally:** legend dots at the bottom of the heart-zone
and swings charts (they're keys, not real pitches).

### 7.5. Barrelsville advance scouting (`barrelsville/src/advance_report.py`)

**Commit:** `c238f43`. Required SQL JOIN additions to
`barrelsville/src/advance_data.py` (`_SCOUTING_PITCHES_QUERY` +
`_MULTI_SEASON_XBH_QUERY`).

| Plot | Click target |
|---|---|
| Movement scatter (HorzBrk × IVB) | Every pitch dot |
| LOC density heatmap | Every pitch dot overlaid on KDE |
| DMG density heatmap | Every BIP dot overlaid on KDE (EV-weighted) |
| Spray chart | Every XBH dot overlaid on contour |

**Coordinate convention:** Barrelsville advance uses **pitcher's view** —
inline flips `plate_x` to `-plate_x`. Overlay coordinates must flip too.
The agent that wired this verified each site's flip convention against
its visual scatter line.

**`_draw_density_heatmap` got a new optional kwarg** `urls: Optional[List[str]] = None`
to coordinate with the visual KDE. Used a coordinated `dropna(subset=[...])`
in `_draw_pitch_type_page` so `urls` list stays aligned with `px`/`pz` arrays.

---

## 8. PDF viewer compatibility matrix

The generated PDFs are correct — embedded `/Link` annotations with proper
`/URI` and `/Rect` values, verifiable with `pypdf`. But the user-facing
behavior depends on the viewer.

| Viewer | Click works? | Notes |
|---|---|---|
| Adobe Acrobat (any version) | YES | Reference behavior |
| Apple Preview (macOS) | YES | |
| Google Chrome — full-tab PDF view | YES | What we tested in |
| Microsoft Edge — full-tab PDF view | YES | |
| Firefox built-in PDF viewer | YES | |
| **Slack file preview** | NO | Flattens link annotations. Coach must download first. |
| **Gmail inline preview** | NO | Same — download first. |
| **Outlook inline preview** | NO | Same. |
| iOS Mail attachment preview | NO | Need to "Open in" Acrobat / Preview. |
| Android Gmail preview | Mixed | Some renderers honor, some don't. Download recommended. |

The key user-education message: **download the PDF, then click**. If a
coach reports "click does nothing", first question is always "did you
download or are you viewing in Slack/Gmail preview?"

---

## 9. What CANNOT be wired (and why)

### 9.1. Heatmaps via `imshow`

`ax.imshow(grid)` with a colormap is just an image. There are no per-pixel
or per-cell artists with positions. Even if there were, `Image.set_url()`
is dropped by PDF backend.

**If you need per-pitch interactivity on a heatmap-style visual, you have
to overlay scatter dots.** Then wire those dots normally. The Barrelsville
advance density heatmaps did exactly this — each KDE plot now has a faint
scatter of the underlying pitches, and those scatter dots have invisible
Text overlays for clicks.

### 9.2. KDE `contourf` plots (pure density without scatter)

Same problem as `imshow`. The contour patches are `Patch` artists, which
don't honor URLs. And there's no per-pitch identity to attach to a contour
band anyway.

If a contour plot has an underlying pitch sample, render that sample as
scatter on top, then wire the scatter.

### 9.3. Pie charts

No per-pitch markers. Each wedge represents an aggregate count.

### 9.4. Aggregated lines (smoothed velocity, rolling means)

You CAN wire the underlying per-pitch dots if they're scattered alongside
the smoothed line (Arm Farm rolling velo does this). What you can't do
is make a smooth line itself clickable per pitch — there's no per-pitch
artist to attach to.

### 9.5. Tables (already covered)

Plottable tables already use `cell.text.set_url()` (Text artist) for the
existing video triangle columns. That mechanism predates the plot-marker
work and is documented at `.claude/rules/pdf-patterns.md` § "Video Link
in Table Cells".

---

## 10. Coordinate convention — the gotcha

Different reports use different views:

- **Catcher's view** (raw `plate_x`, home plate point DOWN):
  - Barrelsville hitter postgame
  - Barrelsville hitter analysis
  - Intangibles catcher report

- **Pitcher's view** (`plate_x` flipped to `-plate_x`, home plate point UP):
  - Arm Farm postgame (via `enrich_pitches()` in `bullpen_data.py`)
  - Arm Farm advance pitching (inline flip)
  - Barrelsville advance density (inline flip in `_draw_pitch_type_page`)

**The overlay must use the same coordinate the visual scatter uses.** If
the visual passes `-row['plate_x']` to its `ax.scatter`, then
`_attach_clickable` must receive `-row['plate_x']` too. Otherwise the
click target is mirrored.

When wiring a new surface, inspect the visual scatter line directly above
your overlay loop — match its arguments byte-for-byte.

For 3D plots (catcher throws, etc.), the same rule applies in 3 axes.

---

## 11. Verification methodology

After wiring a new surface, generate a PDF and confirm annotations are
embedded BEFORE asking a user to test. The diagnostic:

```python
import pypdf
r = pypdf.PdfReader("path/to/report.pdf")
n_annot = sum(
    1
    for p in r.pages
    for a in (p.get("/Annots") or [])
    if str(a.get_object().get("/A", {}).get_object().get("/URI", "")).startswith("http")
)
print(f"{n_annot} link annotations")
```

One-liner version for PowerShell:

```powershell
python -c "import pypdf; r=pypdf.PdfReader('reports/<file>.pdf'); print(sum(1 for p in r.pages for a in (p.get('/Annots') or []) if str(a.get_object().get('/A',{}).get_object().get('/URI','')).startswith('http')), 'video link annotations')"
```

**Expected count:** total dot count + table-triangle count.

**If the count matches table triangles only**, the dot overlays aren't
producing annotations — wiring didn't take. Check:
1. Did you use `ax.text(x, y, "X", ...)` with non-empty string?
2. Is `color` alpha low (≤ 0.001)?
3. Are you passing valid http URLs (not None / NaN)?
4. Are you matching the visual's coordinate convention?

**If the count is roughly right but coaches report click misses**, check
the PDF viewer (§8) — Slack preview flattens links.

---

## 12. How to add a new surface

This is the standard procedure when a coordinator asks for click-to-video
on a report we haven't wired yet.

### Step 1: Confirm video URL is available in the data

Grep the data module for existing JOINs:

```bash
grep -E "Astros\.Video|video_url|cf_angle_url" path/to/<app>_data.py
```

- **Already has it:** skip to step 2.
- **Doesn't have it:** add the canonical 3-tier JOIN per §5. Use the
  empty-fallback DataFrame pattern from `barrelsville/src/advance_data.py`
  to keep downstream `'cf_angle_url' in df.columns` checks truthy.

### Step 2: Identify the wireable plot sites

Grep the report file for `ax.scatter` and `ax.plot(..., marker=`:

```bash
grep -n "ax\.scatter\|ax\.plot.*marker=" path/to/<app>_report.py
```

For each match, decide:
- **Per-pitch markers?** Wire it.
- **Legend dots, summary aggregates?** Skip.

### Step 3: Add the helpers

Copy `_is_valid_url`, `_attach_clickable`, `_attach_clickable_3d` from
`bsb-wt-intangibles/astros-intangibles/intangibles/src/catcher_report.py`
verbatim. Place at module top.

### Step 4: Wire each plot site

```python
ax.scatter(...)  # existing visual — DO NOT MODIFY
for _, row in df.iterrows():
    _attach_clickable(ax, row['<x_col>'], row['<y_col>'],
                      row.get('cf_angle_url'),
                      fontsize=<10-14>)
```

Match the visual's coordinate convention (raw vs flipped).

### Step 5: Verify

Generate a PDF on work laptop. Run the pypdf one-liner from §11. Count
should be > existing triangle count.

### Step 6: Commit + push

Match the commit-message structure used in catcher / Arm Farm / Barrelsville:

```
feat(<app>): click-to-video on every <thing> marker in <surface> PDF

Wired plots:
- <plot 1> at <file>:<line>
- ...

Skipped (no per-pitch markers): <list>.

Coordinate convention: <raw / pitcher's-view-flipped>.

matplotlib PDF backend writes /Link annotations only for Text /
Annotation artists. Recipe: ax.text(x, y, "X", color=(0,0,0,0.001),
fontsize=N) + set_url. Visual scatter rendering unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

---

## 13. The iteration history (for posterity / future agents)

Documenting the journey because the wrong-mechanism trap is real and
several intuitions point the wrong way.

### Iteration 1 — naive scatter set_url (`67d9fcf`)

```python
artist = ax.scatter([row['plate_x']], [row['plate_z']], ...)
artist.set_url(row['video_url'])
```

Reasoning: "every artist has set_url; just call it". Worked in synthetic
tests because we didn't actually inspect the resulting PDF — assumed
matplotlib would honor it.

User test: clicks in Chrome did nothing. Triangle table cells worked.
Plot dots inert.

### Iteration 2 — Line2D overlay (`1113fe0`)

Reasoning: "PathCollection (scatter) might be the issue; Line2D
(individual plot) is more granular. Add an invisible Line2D click
target on top of each scatter marker."

```python
line, = ax.plot([x], [y], marker='o', markersize=12,
                markerfacecolor='black', alpha=0.001, linestyle='', zorder=100)
line.set_url(url)
```

User test: still no clicks.

### Iteration 3 — empirical diagnostic (motivation for `9f4dc54`)

Stopped guessing, wrote the diagnostic test (the one in §3). Inspected
generated PDF with pypdf. Found that ONLY Text and Annotation produced
`/Link` annotations. Scatter, Line2D, and Patch were all silently dropped.

### Iteration 4 — Text overlay (`9f4dc54`)

Switched to `ax.text(x, y, "X", color=(0,0,0,0.001), fontsize=N)` +
`set_url`. Diagnostic confirmed annotations were now present in the PDF.

### Iteration 5 — kwarg rename followup (`00ef27b`)

When changing helper signature from `marker_size=` to `fontsize=`, forgot
to update the 5 call sites. TypeError on every pitch in every plot.
Fixed by `sed -i 's/marker_size=/fontsize=/g'`.

### Lessons encoded

1. **"set_url is universal" is wrong** — it's stored on every artist but
   only Text/Annotation propagate to PDF.
2. **Test the artifact** — don't assume your code works because it
   compiles. Inspect the generated PDF with pypdf.
3. **Empty text is not a click target** — bbox is zero-area, no
   annotation written. Use a single character.
4. **Refactor in atomic units** — when renaming a helper kwarg, update
   the call sites in the same edit. Otherwise you ship a broken commit.

---

## 14. Future candidates (not wired yet)

The user has mentioned but not directed work for these:

- **Intangibles OF/IF/BR weekly per-player reports** — same pattern as
  Barrelsville weekly hitter. Will need data-layer JOINs in
  `intangibles/src/of_weekly_data.py` and `if_weekly_data.py`. Plot sites
  in `of_weekly_report.py` / `if_weekly_report.py` (spray chart, heat
  zones, etc.).
- **Intangibles BR daily team / per-runner postgame** — already has
  some video columns (lead displays use it). Plot sites: lead-distance
  scatter, possibly direction rose, possibly tracker setup scatter.
- **Hitter advance (intangibles)** — separate from Barrelsville advance.
  `intangibles/scripts/generate_hitter_advance.py`. Plot sites TBD.

Each follows §12 procedure. Estimate ~30-50 line diff per surface plus
data-layer JOIN if needed. Same agent-dispatch pattern that worked for
the 5 surfaces shipped.

**Out of scope (probably forever):**
- Bullpen reports (`sched_type='B'`) — `Astros.Video` has no rows.
- Pure heatmap / contour visuals without per-pitch overlays.

---

## 15. Cross-references

| Topic | File |
|---|---|
| Quick-reference recipe + artist matrix | `.claude/rules/pdf-patterns.md` § "Click-to-Video on PDF Plot Markers" |
| Streamlit app click-to-video (different mechanism) | `.claude/rules/visual-standards.md` § "Click-to-Video Pattern" |
| Video URL 3-tier fallback chain | `.claude/rules/video-angles.md` |
| Plottable table cell URL pattern (predates this work) | `.claude/rules/pdf-patterns.md` § "Video Link in Table Cells" |
| Coordinate convention per app | `.claude/rules/coordinates.md`, `.claude/rules/visual-standards.md` |
| Per-app file locations | `.claude/rules/<app>.md` (barrelsville, arm-farm, intangibles) |
| Reference implementation (canonical helpers) | `bsb-wt-intangibles/astros-intangibles/intangibles/src/catcher_report.py` |

---

*Last updated: 2026-04-27 by Claude Opus 4.7 after shipping all 5 surfaces.*
