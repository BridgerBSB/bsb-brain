# AC Dashboard — Visual Primitives Reference

**Date:** 2026-05-07
**Status:** Foundation spec — all tab specs reference this
**Scope:** Component / token library for the Astros Catching ("AC") dashboard
**Source:** KDB visual port (https://kdbbeta85v2.netlify.app/) + Astros brand overlay

---

## 1. What this doc is

A single source of truth for the AC dashboard's visual language. Tokens
(color, type, spacing), components (card, chip, percentile bar, headshot
frame, KPI tile), and how each renders inside Streamlit.

Every tab spec (`2026-05-07-ac-tab-*.md`) references components and
tokens defined here. If a token changes (e.g. user swaps the leaderboard
chip color), update **here once**, propagates to every tab.

[NOTE: needs browser inspect on https://kdbbeta85v2.netlify.app/ for
exact hex values, padding, border-radius, line-height. Values below
marked `[CONFIRMED-FROM-HEAD]` came from the page's `<meta>` tags or
visible CSS in the source dump. Values marked `[FROM-SCREENSHOT]` are
inferred from the home-page screenshot and need inspect to lock.
Values marked `[ASTROS-OVERRIDE]` are HOU-branded, replacing KDB's
defaults.]

---

## 2. Color tokens

### Base palette

| Token | Hex | Source | Purpose |
|---|---|---|---|
| `--bg-base` | `#dce3eb` | [CONFIRMED-FROM-HEAD] meta theme-color | Page background, neutral panel base |
| `--bg-panel` | `#f1f4f8` | [FROM-SCREENSHOT] | Card / nav-tile panel fill (slightly lighter than bg) |
| `--bg-panel-hover` | `#e6ebf1` | [FROM-SCREENSHOT] | Hover state on clickable nav tiles |
| `--bg-elev` | `#ffffff` | [FROM-SCREENSHOT] | Elevated cards (single-catcher card body, KPI tiles) |
| `--border` | `#c4cdd6` | [FROM-SCREENSHOT] | Subtle 1px panel borders |
| `--border-strong` | `#9aa6b2` | [INFERRED] | Heavier borders (table headers, focused inputs) |

### Text palette

| Token | Hex | Purpose |
|---|---|---|
| `--text-primary` | `#1a2332` | [FROM-SCREENSHOT] | Main body text |
| `--text-secondary` | `#5a6675` | [FROM-SCREENSHOT] | Secondary labels, descriptions |
| `--text-muted` | `#8a96a5` | [FROM-SCREENSHOT] | Meta text, footnotes |
| `--text-mono-label` | `#6b7884` | [FROM-SCREENSHOT] | Monospace small-caps labels (KDB style) |

### Accent palette — AC brand (KDB → Astros swap)

| Token | KDB Original | AC Override | Purpose |
|---|---|---|---|
| `--accent-positive` | green chip `~#22c55e` [INFERRED] | **`#EB6E1F`** [ASTROS-OVERRIDE] | Leaderboard chips (+N extra strikes), positive deltas, "above expected" |
| `--accent-negative` | red `~#ef4444` [INFERRED] | `#dc2626` (kept) | Below-expected, negative deltas |
| `--accent-emphasis` | KDB blue-grey | **`#002D62`** [ASTROS-OVERRIDE] Astros navy | Page titles, primary headers, emphasis text |
| `--accent-secondary` | KDB neutral | **`#1a4d8a`** [ASTROS-OVERRIDE] | Secondary emphasis, link hover |

### Framing bucket palette (LOCKED — already canonical, do NOT swap)

These match `.claude/rules/intangibles.md` "Catcher Report — 7-Bucket Framing System".
Never override. Used in zone plot dots + receiving table cells + framing chip stacks.

| Bucket | CSC Range | Hex | Meaning |
|---|---|---|---|
| E Stl | 0-5% | `#1B5E20` | Extra steal (dark green) |
| Stl | 5-25% | `#66BB6A` | Steal (green) |
| Mid+ | 25-50% | `#42A5F5` | Mid gain (blue) |
| Exp | matched | `#BBBBBB` | Expected (grey) |
| Mid− | 50-75% | `#FDD835` | Mid loss (yellow) |
| Loss | 75-95% | `#FF9800` | Loss (orange) |
| B Loss | 95-100% | `#F44336` | Bad loss (red) |

### Percentile gradient (LOCKED — match existing `br_percentiles.percentile_to_color()`)

For percentile-bar fills + cell coloring. Don't reinvent — call the
existing helper. Reverse the gradient for lower-is-better metrics.

---

## 3. Typography

### Font stack [CONFIRMED-FROM-HEAD]

KDB loads:
```
JetBrains Mono       — labels, ranks, mono-numeric (small caps)
Space Grotesk        — body text, secondary headers
Special Gothic Expanded One — display headers (catcher names, hero text)
Inter                — UI labels, table cells
Playfair Display     — feature article titles (won't use — internal tool)
```

We adopt all except Playfair (no blog).

### Streamlit injection

```python
st.markdown("""
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700;800&family=Space+Grotesk:wght@400;500;600;700&family=Special+Gothic+Expanded+One&family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
""", unsafe_allow_html=True)
```

### Type scale

| Token | Family | Size | Weight | Line-height | Use |
|---|---|---|---|---|---|
| `--type-display-xl` | Special Gothic Expanded One | 32px | 400 | 1.1 | Page hero (catcher name on card) |
| `--type-display-lg` | Special Gothic Expanded One | 24px | 400 | 1.15 | Section headers |
| `--type-h1` | Space Grotesk | 22px | 700 | 1.25 | Tab titles |
| `--type-h2` | Space Grotesk | 18px | 600 | 1.3 | Card sub-headers |
| `--type-body` | Inter | 14px | 400 | 1.5 | Body text |
| `--type-body-sm` | Inter | 12px | 400 | 1.5 | Table cells, descriptions |
| `--type-mono-label` | JetBrains Mono | 10px | 600 | 1.0 | Small-caps labels above values |
| `--type-mono-value` | JetBrains Mono | 18px | 600 | 1.0 | KPI values (FramRAA: 3.2) |
| `--type-mono-rank` | JetBrains Mono | 11px | 700 | 1.0 | Leaderboard chip text |

[NOTE: sizes from screenshot inference — confirm with browser inspect]

### Mono-label convention

Small-caps labels above every value (KDB pattern):
```html
<span class="label-meta">FRAMING RUNS</span>
<span class="value-mono">+3.2</span>
```
`label-meta` = JetBrains Mono 10px, weight 600, letter-spacing 0.5px,
text-transform uppercase, color `--text-mono-label`.

---

## 4. Spacing + radius scale

| Token | Value | Use |
|---|---|---|
| `--space-1` | 4px | Tight icon gaps |
| `--space-2` | 8px | Inside-component padding |
| `--space-3` | 12px | Card inner padding tier 1 |
| `--space-4` | 16px | Card inner padding tier 2 |
| `--space-5` | 24px | Section gaps |
| `--space-6` | 32px | Page-level gaps |
| `--radius-sm` | 4px | Chips, small badges |
| `--radius-md` | 8px | Cards, panels |
| `--radius-lg` | 12px | Hero cards, headshot frames |

[NOTE: spacing scale inferred from screenshot — confirm pixel values
with browser inspect on KDB live site]

---

## 5. Components

### 5.1. Nav tile (8-grid landing)

**KDB reference:** Home page nav cards (Scoreboard, Gameday, Blog, etc.)
**Used by:** AC Dashboard landing (`?view=dashboard` no sub-tab)

```
┌─────────────────────────┐
│  TITLE (mono small-caps)│  ← --type-mono-label
│                         │
│  Description text...    │  ← --type-body-sm, --text-secondary
│  Two short lines.       │
│                         │
└─────────────────────────┘
```

- bg: `--bg-panel`, border: 1px solid `--border`, radius: `--radius-md`
- padding: `--space-4`
- hover: bg `--bg-panel-hover`, border `--border-strong`, cursor pointer
- click: routes to `?view=dashboard&tab=<name>`

### 5.2. Leaderboard chip (top-right green badge)

**KDB reference:** "+9 EXTRA STRIKES" chips on home rail
**Used by:** Landing rail, Catcher Cards summary, KPI tile delta

```
┌──────────┐
│   +9     │
│  EXTRA   │
│ STRIKES  │
└──────────┘
```

- bg: `--accent-positive` (Astros orange `#EB6E1F`) for positive
- bg: `--accent-negative` for negative
- color: white
- font: JetBrains Mono 600
- value: 18-22px; label: 9-10px uppercase
- padding: `--space-2` `--space-3`
- radius: `--radius-sm`

### 5.3. Catcher card (single-catcher hero)

**KDB reference:** [needs screenshot from user] Catcher Cards page
**Used by:** Catcher Cards tab (primary build), shareable PNG export

```
┌─────────────────────────────────────────────────┐
│  ┌────┐  CATCHER NAME                           │
│  │HEAD│  TEAM · LEVEL · YEAR                    │
│  └────┘                                         │
│  ─────────────────────────────────────────────  │
│  KPI grid: FramRAA / BlockRAA / Pop2B / Arm /   │
│            Exch / R2K%  (each: label + value +  │
│            percentile bar + rank chip)          │
│  ─────────────────────────────────────────────  │
│  Framing breakdown (7-bucket horizontal bar)    │
│  ─────────────────────────────────────────────  │
│  Throwing detail (Pop split by 2B/3B, by hand)  │
└─────────────────────────────────────────────────┘
```

- bg: `--bg-elev` (white)
- border: 1px solid `--border`
- radius: `--radius-lg`
- padding: `--space-5`
- shadow: subtle (`0 1px 3px rgba(26,35,50,0.08)`)
- header headshot: 80×100px, `--radius-md`, 2px border `--accent-emphasis`

### 5.4. KPI tile (per-metric)

**Used by:** Catcher Cards KPI grid, Stats tab year-over-year tiles, KDB-Live-style leaderboards

```
┌──────────────────────┐
│  FRAMING RUNS        │  ← mono small-caps label
│  +3.2                │  ← mono value, large
│  ████████░░░  72nd   │  ← percentile bar + rank
│  Lvl: 4/22  Org: 1/3 │  ← rank breakdown
└──────────────────────┘
```

- bg: `--bg-panel`
- border: 1px solid `--border`
- radius: `--radius-md`
- padding: `--space-3`
- value color: `--accent-emphasis` (navy) for HiB-positive, `--accent-negative` for negative deltas

### 5.5. Percentile bar

**Used by:** KPI tile, Catcher card grid
**Backed by:** `br_percentiles.percentile_to_color()` for fill color

```
████████░░░  (10-segment, fill = pctile/10)
```

- segment width: 8px
- segment gap: 1px
- height: 6px
- fill color: from existing percentile gradient helper
- empty segment: `--border` at 0.4 opacity
- direction-aware (HiB: fill from left; LiB: fill from right OR flip gradient)

### 5.6. Headshot frame

**Used by:** Catcher card header, leader rail tiles, scoreboard pitcher entries

```
┌────────┐
│        │  ← 80×100px or 60×75px (rail)
│  IMG   │
│        │
└────────┘
```

- aspect: 4:5
- border: 2px solid `--accent-emphasis` (navy), or `--accent-positive` (orange) if HOU
- radius: `--radius-md`
- placeholder: silhouette SVG when no headshot URL

### 5.7. Section divider

```
─────────────────────────────────
```

- 1px solid `--border`
- margin: `--space-4` 0

### 5.8. Selector chrome (year/level/catcher)

KDB uses dropdown with subtle styling. We reuse Streamlit `st.selectbox`
inside a `st.container()` styled with our tokens.

---

## 6. Streamlit render strategy

### Where to put the CSS

A new module `intangibles/src/ac_dashboard/styling.py` exposes a
`inject_css()` function called once at the top of every AC tab render.
Defines `:root { --bg-base: #dce3eb; ... }` then component classes.

```python
def inject_css():
    st.markdown(f"""
    <style>
    :root {{
        --bg-base: #dce3eb;
        --bg-panel: #f1f4f8;
        ...
    }}
    .ac-card {{ ... }}
    .ac-tile {{ ... }}
    ...
    </style>
    """, unsafe_allow_html=True)
```

### When to use HTML vs Streamlit native

| Component | Streamlit native | Custom HTML |
|---|---|---|
| Nav tiles | — | YES (anchor with `?view=` href, like existing `domain-card`) |
| Catcher card | `st.container(border=True)` partly works | YES (need full layout control) |
| KPI tile | partial via columns | YES (compact label/value/bar/rank stack) |
| Percentile bar | — | YES (10 inline-block segments) |
| Tables | `st.dataframe` w/ Styler | OK for KDB-Live-style leaderboards |
| Plots | Plotly (existing pattern) | Plotly (zone plot, click-to-video) |
| Headshot | `st.image` works | Custom HTML for border-color logic |

### Click-to-video reuse

Existing `_handle_chart_click()` in `4_Catching.py:162` already wraps
the Plotly click→open-URL flow. Lift to `ac_dashboard/click_video.py`
unchanged so AC tabs reuse without duplication.

---

## 7. Module structure (proposed)

```
intangibles/src/ac_dashboard/
├── __init__.py
├── styling.py            # CSS tokens + inject_css()
├── components.py         # Helpers: render_kpi_tile(), render_card(), render_chip()
├── click_video.py        # Lifted from 4_Catching.py _handle_chart_click
├── landing.py            # Catcher Dash landing (8-tile grid + leaders rail)
├── tab_catcher_cards.py  # Catcher Cards tab
├── tab_gameday.py        # Gameday tab
├── tab_pitch_calling.py  # Pitch Calling tab
├── tab_pitchers.py       # Pitchers tab
├── tab_stats.py          # Stats tab
├── tab_scoreboard.py     # Scoreboard tab
└── data/                 # NEW data fetchers (when existing modules don't cover)
    ├── __init__.py
    ├── pitch_calling.py  # New: pitch mix by count/hand pivot
    ├── pitchers.py       # New: per-catcher pitcher arsenal aggregator
    └── scoreboard.py     # New: HOU affiliate slate fetcher
```

[NOTE: subfolder vs flat module debate — going with subfolder since 6
tabs + helpers + data shims will be ~12 files and ac_dashboard cleanly
namespaces them.]

---

## 8. What NOT to do

- **Don't** duplicate metric math. Every metric value comes from
  `catching_tracker_data.py` / `catcher_data.py` / `c_kpi_data.py`.
  AC dashboard is a 4th surface that READS, never RECOMPUTES.
- **Don't** override the 7-bucket framing palette. It's canonical.
- **Don't** use Streamlit's default theme colors anywhere visible.
  Inject the AC tokens via `:root` and use them.
- **Don't** ship without browser-inspect tuning. Visual fidelity to
  KDB requires exact values for spacing/border-radius/font-weight.
- **Don't** introduce a new percentile-color helper. Reuse
  `br_percentiles.percentile_to_color()`.
- **Don't** swap the Astros navy/orange tokens once locked. Every
  spec depends on `--accent-emphasis = #002D62` and
  `--accent-positive = #EB6E1F`.

---

## 9. Open visual questions

[NOTE: parking lot — answer when screenshots arrive]

1. KDB uses dark mode anywhere? (theme-color is light; assume light-only)
2. Do KDB nav tiles have icons or just text? Screenshot suggests text-only.
3. Leaderboard chip on home page — is it a flat color or gradient?
   Astros orange swap should match whatever depth KDB has.
4. Card hover/click animations — port the spinner/transitions from
   existing `domain-card` CSS or copy KDB's? KDB feels static; existing
   `domain-card` has retro-arcade pulse. Mismatch — pick one for AC.
5. Mobile breakpoints — KDB scales; do HOU coaches view on phones?
   If yes, need media queries on the tile grid.

---

## 10. References

- KDB site: https://kdbbeta85v2.netlify.app/
- `.claude/rules/intangibles.md` (catcher framing palette, click-to-video)
- `intangibles/pages/4_Catching.py` (existing CSS, routing pattern)
- `intangibles/src/tracker_page.py` (`render_domain_landing` extended for new card)
- `intangibles/src/br_percentiles.py` (percentile_to_color)
