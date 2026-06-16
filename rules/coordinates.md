---
paths:
  - "**/src/*.py"
  - "**/scripts/*.py"
---

# Coordinate Conventions

## plate_x / HorzBreak / Release_x — CRITICAL
**Raw DB (HawkEye/Statcast) = catcher's perspective.** Positive plate_x = right from catcher's view.

| Project | Convention | How | Why |
|---------|-----------|-----|-----|
| **Barrelsville** (postgame hitting) | Catcher's view | Raw DB values (no flip) | Hitting plots are naturally catcher's perspective |
| **Arm Farm postgame** | Pitcher's view | `enrich_pitches()` flips: `plate_x = -plate_x`, `horzbreak = -horzbreak`, `release_x = -release_x` | Pitching reports show pitcher's perspective |
| **Advance Scouting** (`barrelsville/src/advance_report.py`) | **Pitcher's view** | Per-call sites flip manually: `px = -plate_x.values` for density plots; `flip_df["horzbreak"] = -flip_df["horzbreak"]` for break charts | Despite living in Barrelsville, the advance report is pitcher-focused (scouts what the pitcher does); home plate drawn point-UP confirms pitcher's view convention |

**Rules:**
- **Pitching reports** (postgame, pitcher analysis, bullpen): Flip to **pitcher's view**
- **Hitting postgame reports** (Barrelsville postgame, hitter analysis): Keep raw = **catcher's view**
- **Advance scouting**: Flip to **pitcher's view** (yes, even though it's in the Barrelsville app — the report is pitcher-focused)
- `enrich_pitches()` in `bullpen_data.py` handles the flip for Arm Farm. Other scripts flip manually.
- **NEVER assume plate_x orientation** — always check which convention the current script uses
- **When adding a new plot to advance_report.py**: GREP existing plots in the same file FIRST and mirror what they do. Visual consistency across pages of the same report > guessing from this rule alone.
- **Home plate pentagon must match the view.** Pitcher's view = point UP. Catcher's view = point DOWN.

## matplotlib Figure Coordinates
`fig.add_axes([x, y, width, height])` — y is the BOTTOM edge of the axes box.

**Direction rules (figure coordinates 0-1):**
- y=0 = bottom of page, y=1 = top of page
- Increasing y → moves element UP
- Decreasing y → moves element DOWN
- Increasing x → moves element RIGHT
- Decreasing x → moves element LEFT

**CRITICAL:** When adjusting positions, ONLY change the y value. Do NOT simultaneously change height, or the visual top edge moves unpredictably. When user says "move down 0.03", ONLY subtract 0.03 from y. Always state before/after y values so the user can verify direction.
