# Render-and-Look — Never Ship a Visual You Haven't Seen (BLOCKING)

Any change that affects what a chart/figure/PDF **looks like** — text
position, font size, a logo/headshot, axes, colors, a new page, panel
layout, a spray chart, a zone grid — MUST be rendered to an image and
**visually inspected** before you claim it works or commit it.

`python -m py_compile` and unit tests verify *logic*. They are blind to
layout. They cannot see text sliding under a logo, a label clipped off
the edge, two panels overlapping, an empty axis, or a color that
vanishes against its background. The ONLY thing that catches those is
generating the image and looking at it with the image-viewing Read tool.

User directive, Jun 17 2026: *"how can we prevent excuses like this in
the future — this is killing time."* The answer is this rule. Stop
reasoning about coordinates in your head; render it and look.

---

## The bug that created this rule

Switch-hitter advance pages got a "vs RHP" tag right-aligned at figure-x
`0.985`. The Astros logo is a `figimage` spanning figure-x ≈ `0.915–0.982`
at the top-right, drawn ON TOP. The tag ran leftward under the logo;
only the trailing "P" of "RHP" cleared the logo's right edge. Shipped a
stray "P" floating beside the logo. Compile + unit test both passed. A
30-second render-and-look would have caught it before the first commit.
It took two user round-trips instead.

---

## The procedure (BLOCKING — do this before claiming a visual works)

1. **Render with synthetic data.** Layout does NOT need the live DB.
   Build a dummy row + a tiny fake dataframe with the columns the draw
   function reads, call the SAME draw function the report/app uses, and
   `savefig` to a temp PNG. Match production `dpi` (usually 150) and
   `bbox_inches` — fixed-pixel `figimage` logos/headshots move with dpi,
   so a 110-dpi render will NOT show the real logo position.
2. **Actually look.** Open the PNG with the Read tool (it views images).
   Do not skip this because "the math looks right."
3. **Check the failure modes** that logic tests miss:
   - text overlapping a logo / headshot / another text element
   - labels clipped at a figure edge
   - the **worst case**, not just the happy case — longest name, most
     pitch types, zero-data panel, the empty side of a split
   - panels overlapping or mis-positioned; legend off-canvas
   - color/contrast (white text on light fill, etc.)
4. **Only then** claim it works / commit.

### Recipe (advance report is the reference)

```python
import os, tempfile, numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from src.hitter_advance_report import get_hitter_page_specs, _draw_hitter_page

rng = np.random.default_rng(7); n = 60
bip = pd.DataFrame({"hit_bearing": rng.uniform(-45,45,n),
                    "distance": rng.uniform(40,340,n),
                    "hit_vertical_angle": rng.uniform(-10,40,n),
                    "pitcher_throws": rng.choice(["R","L"], n)})
# Stress the WORST case: long name + switch-hitter split + show_images
h = pd.Series({"first_last":"Maximiliano Hernandez-Castellanos","bats":"S",
               "org_code":"hou","mlbam_id":None})
sub, lab = get_hitter_page_specs(h, bip)[0]
fig = plt.figure(figsize=(11,8.5)); fig.patch.set_facecolor("white")
_draw_hitter_page(fig, h, sub, "dsl", "range", show_images=True, hand_label=lab)
p = os.path.join(tempfile.mkdtemp(), "smoke.png")
fig.savefig(p, dpi=150, bbox_inches="tight"); plt.close(fig); print(p)
# -> then Read p and LOOK
```

`mlbam_id=None` skips the network headshot fetch but keeps the local
logo, so the logo↔text geometry is faithful.

---

## Positioning hygiene (prevents the collision class up front)

- **Know where the fixed elements are before placing text.** The advance
  logo occupies figure-x ≈ `0.915–0.982`, top. Any header text must end
  left of `~0.90`. Don't right-align text into a region a `figimage`
  covers — `figimage` ignores `zorder` vs. text in the way you expect and
  is painted at fixed pixels regardless of `bbox_inches='tight'`.
- **Prefer inline composition over a second free-floating artist.** Folding
  "vs. RHP" into the existing title string (one left-anchored `fig.text`)
  can't collide with the logo; a separate right-anchored tag can.
- **When in doubt, render and look.** This rule supersedes cleverness.

---

## Cross-references

- `new-visual` skill — Step 8 ("Render and Look") is the gate that points
  here. Runs on every visual create/modify.
- `visual-standards.md` — canonical dimensions/colors/construction.
- `pdf-patterns.md` / `pdf-last-in-script.md` — PDF assembly + ordering.
- `superpowers:verification-before-completion` — the general principle
  (evidence before assertions); this is its visual specialization.

---

## What NOT to do

- **Don't** claim a layout works after only `py_compile` + a logic unit
  test. They are blind to layout.
- **Don't** reason about pixel/fraction coordinates in your head and ship.
  Render it.
- **Don't** render at a convenience dpi (110) and trust the logo/headshot
  position — fixed-pixel `figimage` is calibrated for the production dpi.
- **Don't** test only the happy case. The long name / empty panel / most-
  pitch-types case is where layout breaks.
