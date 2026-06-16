---
name: ALWAYS read coordinates.md AND the surrounding helpers before adding plate_x/horzbreak plots
description: coordinates.md says Advance = catcher's view (no flip), but the live advance_report.py per-pitch-type plots all negate plate_x (pitcher's view). Visual consistency wins; rule is outdated. When adding ANY new plot to advance_report.py, mirror what the existing plots do — never trust the rule alone.
type: feedback
originSessionId: 44c2c027-e9d6-4099-a6c7-f4e7e13c5eed
---
When adding a new plot to `barrelsville/src/advance_report.py` (or any
report file that already has plate_x / horzbreak plots), do BOTH of
these BEFORE writing the helper:

1. **Read `coordinates.md`** for the project convention.
2. **Grep the file you're editing** for existing `plate_x` / `horzbreak`
   usage. If the existing plots negate (or don't), MIRROR them. Visual
   consistency across pages of the same report > rule compliance.

**The May 5 2026 trap:** I built `_draw_top3_heatmap_row` in
advance_report.py reading `coordinates.md` (Advance = catcher's view =
no flip) but NOT reading the existing `_draw_pitch_type_page` density
plots in the same file (which negate plate_x for pitcher's view). My
heatmaps came out mirrored relative to every other plot on the same
report. User caught it visually after I shipped.

**Why the rule and code disagree:** the per-pitch-type plots have shipped
for ~a month with positive coach feedback. They draw the home plate
pentagon point-UP (pitcher's view per the rule's own home-plate clause)
AND negate plate_x. So the report is FULLY pitcher's view, not catcher's.
The `coordinates.md` line saying "Advance = catcher's view" is stale.
DO NOT trust it for advance plots.

**Correct check before adding any plot to advance_report.py:**
```bash
grep -n "plate_x\|horzbreak\|home_plate\|pitcher's view\|catcher's view" \
    barrelsville/src/advance_report.py
```
And mirror what the existing plots do, not what the rule says.

**Same trap risk in:**
- `barrelsville/src/postgame_report.py` (different convention again)
- `bullpen-report/src/postgame_report.py` (Arm Farm pitcher = pitcher's view via enrich_pitches; rule + code agree)
- Any new module that adds a per-pitch density heatmap

**Bug history:**
- May 5 2026: shipped `_draw_top3_heatmap_row` with raw plate_x; user
  spotted mirror; fixed in `e19e058`.

**Cross-reference:**
- `.claude/rules/coordinates.md` — the rule (note: stale on advance entry)
- `barrelsville/src/advance_report.py::_draw_density_heatmap` — home plate
  point-UP confirms pitcher's view convention in this file
- `barrelsville/src/advance_report.py::_draw_pitch_type_page` line ~1299
  — `px = -loc_df["plate_x"].values` is the canonical pattern to mirror
