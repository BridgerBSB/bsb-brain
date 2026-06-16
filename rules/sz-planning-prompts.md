---
paths:
  - "**/src/*plots*.py"
  - "**/src/*report*.py"
  - "**/pages/*.py"
  - "**/scripts/*.py"
---

# Strike Zone Planning Prompts — ALWAYS ASK BEFORE BUILDING/MODIFYING

Before writing or modifying ANY strike-zone visual, data classification, or % stat in any app, the agent MUST confirm answers to these 5 decisions with the user first. Do not start coding a zone visual without them.

---

## Decision 1: Which variant?

Identify which of the 6 known SZ variants you are working on. If you cannot place the task into one of these, STOP and ask.

- **A — Hitter-specific (1 named batter).** Postgame PDF/app zone grid, hitter_analysis per-player heatmap. Uses that batter's height.
- **B — Generic pooled (league view, many batters).** Weekly hitter heart chart, bat speed pooled scatter, heart_zone_report org comparison. Uses MLB average height.
- **C — Per-hitter-target (Arm Farm pitcher vs. 1 hitter).** Advance pitching matchup heatmap. Uses that opposing hitter's height. OUT OF SCOPE for Tango refactor — different formula today.
- **D — Pitcher-view generic (LVA, location scatter).** Arm Farm postgame, LVA grid cells. SZ rectangle only, no Heart/Shadow.
- **E — Catcher framing 4-panel.** Intangibles catcher report. SZ rectangle + CSC 7-bucket coloring (not Heart/Shadow).
- **F — hitter_analysis 13/17-zone grid.** Savant-style polygon zones. Uses generic SZ with wider axis limits. All 4 Tango zones are drawn as grid cells.

## Decision 2: Which framework(s)?

- Drawing the SZ rectangle → **Framework 1 (ABS 17")** — width ±0.708 ft, Z = `0.27×h` to `0.535×h`, no pad.
- Computing Heart/Shadow/Chase/Waste % stats → **Framework 2 (Tango)** — X fixed ±0.558/±1.108/±1.667, Z bands from Tango-extended zone (ABS + 1.5" pad) at 67%/133%/200%.
- Most Barrelsville hitting visuals use BOTH (SZ rect drawn at Framework 1 dimensions, Heart/Shadow rects drawn at Framework 2 dimensions).

See `.claude/rules/visual-standards.md` → "Strike Zone — Two Frameworks" for full formulas.

## Decision 3: Visual layers to draw

- **SZ only** — variants D (LVA, location scatters), E (catcher framing), density heatmaps, advance density. One solid black rectangle.
- **SZ + dotted Heart + dotted Shadow** — variants A, B, C. The default for hitting zone grids. Colors + linewidths below.
- **SZ + all 4 Tango zones as grid cells** — variant F (hitter_analysis 13/17-zone grid). Each cell is a polygon, not a nested rectangle.

### Rendering specs for the dotted-Heart/Shadow pattern (Apr 21, 2026 lock):

| Layer | Line | Edge | LW | Fill (mpl) | Fill (Plotly) |
|---|---|---|---:|---|---|
| SZ | solid | black | 2.0 | none | none |
| Heart | dotted (`":"` / `"dot"`) | `#555555` | 0.9 | `#90EE90` | `rgba(76,175,80,0.1)` |
| Shadow | dotted | `#888888` | 0.7 | `#f5f5f5` | `rgba(200,200,200,0.1)` |

## Decision 4: Height source

- **Hitter-specific (variant A, C):** `get_batter_zone_bounds(batter_id)` in Barrelsville; queries `mlbam.players` via `_lookup_batter_height`. Falls back to `MLB_AVG_HITTER_HEIGHT_FT = 6.0212` ft if no height.
- **Generic pooled (variant B, D, E, F):** `abs_zone_bounds(MLB_AVG_HITTER_HEIGHT_FT)` or `abs_zone_bounds(None)` (same result). NEVER hardcode 1.5–3.5.
- **Per-batter in SQL:** JOIN on `mlbam.players`, expose `height_ft`, and compute Tango Z formulas in the CTE. NEVER hardcode Z bounds in SQL.

## Decision 5: Data + visual MUST match (Apr 18 BLOCKING rule, Tango-aware)

Per the Apr 18, 2026 BLOCKING rule (see `.claude/rules/barrelsville.md` + `visual-standards.md`): if you draw a zone at certain bounds, classification stats for that zone MUST use the same bounds.

- Both sides (rendering AND Hrt Sw% / Hrt Tk% / Shd% / Chase% / Waste% computations) MUST call `plots.abs_zone_bounds()` — same dict, same height input.
- Never re-derive inline. Never hardcode a "close enough" legacy value alongside the real calculation.
- SQL classification CTEs must compute the same Tango X + Z formulas per batter.

---

## Common Mistakes to Catch

- **Drawing SZ at ±0.83 (20") instead of ±0.708 (17").** SZ display is ALWAYS 17" (ABS plate width).
- **Computing Heart at SZ-inset-by-ball-radius (old `±0.587`).** Heart X is now Tango `±0.558` (6.7"). Different number, different framework.
- **Using `1.5–3.5` ft hardcoded default.** Retired. Use `MLB_AVG_HITTER_HEIGHT_FT` → `abs_zone_bounds()` → `[1.626, 3.221]` for the pooled default.
- **Using old ball-radius Z formula** (`0.27h + BALL_RADIUS` / `0.535h - BALL_RADIUS`). Retired. Heart Z is now `0.313725×h - 0.08375` to `0.491275×h + 0.08375`.
- **Drawing Heart at Framework 1 bounds then classifying pitches at Framework 2 bounds** (or vice versa). Visual and data MUST come from the same `abs_zone_bounds()` call.
- **Using `±0.121` anywhere.** Retired ball-radius constant. No Tango formula references it.
- **Adding a `1.5` or `3.5` magic number to handle "default height".** Always go through `abs_zone_bounds()`.

---

## Variants A–F Reference

| # | Variant | Height source | Tango rings drawn? | Example files |
|---|---|---|---|---|
| A | Hitter-specific (1 named batter) | `get_batter_zone_bounds(batter_id)` via `mlbam.players` | Yes — dotted Heart + Shadow | `postgame_report.py`, `1_Postgame.py` zone grid, `hitter_analysis.py` |
| B | Generic pooled (league view) | `MLB_AVG_HITTER_HEIGHT_FT` via `abs_zone_bounds()` | Yes — dotted Heart + Shadow | `weekly_hitter_report.py` heart chart, `heart_zone_report.py` |
| C | Per-hitter-target (Arm Farm) | `get_hitter_zone_bounds(hitter_id)` | Arm Farm today uses ±0.83 + legacy Z; NOT Tango — OUT OF SCOPE | `advance_pitching_report.py` |
| D | Pitcher-view generic (LVA, location scatter) | SHOULD be MLB avg via `abs_zone_bounds(None)`. Arm Farm currently hardcodes 1.5–3.5 — flagged for fix. | No — SZ only | Arm Farm `postgame_report.py`, `plots.py` LVA cells |
| E | Catcher framing 4-panel | SHOULD be MLB avg via `abs_zone_bounds(None)`. Intangibles currently hardcodes 1.5–3.5 — flagged for fix. | No — SZ only, CSC buckets instead | Intangibles `catcher_report.py` |
| F | hitter_analysis 13/17-zone grid | MLB avg for pooled | All 4 Tango zones as polygon grid cells (wider axis limits) | `hitter_analysis.py::_draw_zone_heatmap()` |

---

## Reference

- Full framework spec: `.claude/rules/visual-standards.md` → "Strike Zone — Two Frameworks"
- Barrelsville BLOCKING rule: `.claude/rules/barrelsville.md` → "Strike Zone Framework — BLOCKING RULE"
- Source of truth: `barrelsville/src/plots.py::abs_zone_bounds()`
- Per-batter height lookup: `barrelsville/src/postgame_data.py::_lookup_batter_height()` / `get_batter_zone_bounds()`
- Implementation history: `docs/plans/2026-04-21-tango-sz-refactor.md`
- Rollback anchor: git tag `pre-tango-sz-refactor` on commit before Wave 2
