---
status: active research — feeds the Range & Difficulty v2 spec (Mazzo asks)
created: 2026-07-09
project: Savant fielding visuals (intangibles worktree, feature/astros-intangibles)
---
<!-- STATUS 2026-07-21: OF Range & Difficulty DASHBOARD SHIPPED (feature/astros-intangibles). IF savantification PARKED / near-future — Zac checking Savant for IF ideas. See "BUILD STATUS + IF NEXT" section at bottom. -->

# Savant OF Dash Research — how Baseball Savant builds the fielding visuals Mazzo wants

Captured 2026-07-09 from Zac's screenshots + screen-recording of the live Savant
player page, plus web sources. Feeds the v2 /spec for our Range & Difficulty
views (v1 code-complete Jul 9 — see memory `savant-fielding-visuals-status`).
Related: [[fielding-advance-spray-grid]], [[prp-player-review-process]].

## Source 1 — Savant player fielding page (Cam Smith, live)

URL: https://baseballsavant.mlb.com/savant-player/cam-smith-701358?stats=statcast-r-fielding-mlb
Fetched via WebFetch (partial — page is JS-heavy) + Zac's 4 screenshots + 111s
screen recording (`C:\Users\Owner\Downloads\OF DASH EXAMPLE.mp4`, frames
analyzed 2026-07-09). The page's two interactive charts, verbatim behavior:

### Chart A — "Responsible Plays" field view (the one with the red ring)
- Field outline with wall distances; player headshot + "Responsible Plays for 2026".
- Plays are BINNED into small squares at ball-landing locations. **Square size =
  number of opportunities in that bin** (legend: "4 Opps." big, "2 Opps" small,
  "1 Opp." smallest). Green dot = player's typical **Start Pos**.
- Per-bin tooltip: `Opportunities: 4 | Exp. Catch Rate: 99% | Actual Catch Rate: 75%`
  — i.e. each bin carries expected (model) vs actual catch rate. Red fill
  intensity tracks the bin's outcome mix.
- **Hulls** ("Show Hulls" checkbox): RED convex hull = perimeter of plays where
  the player MADE THE OUT; GRAY hull = the hits (uncaught responsible plays).
  The red ring Zac referenced = the outs hull, i.e. demonstrated range envelope.
- **"Sprint Speed Range?" checkbox** (seen in the video): overlays translucent
  red CONCENTRIC RINGS centered on Start Pos — a modeled reach radius from the
  player's sprint speed at the slider's hang time. Savant itself pairs the
  empirical plays with a formula ring; our v1 bullseye is this exact feature.
- Sliders: **Hang Time** (caption e.g. "Hang Time <= 6.5 Seconds"), **Catch Rate
  GT / LT** (band filter, e.g. ">= 5% and <= 100%"), Stroke/Fill opacity;
  Show Hits / Show Outs / Show Hulls toggles; Save Chart button.
- Filter semantics: dragging Hang Time down to 5.8s + Catch Rate <= 65% leaves
  only the hard-play subset; hulls recompute live on the filtered subset.

### Chart B — Hang Time x Distance catch-difficulty scatter
- X = **Distance From Ball Landing** (0–140 ft; distance fielder had to travel),
  Y = **Hang Time** (1–8 s). One dot per responsible play.
- Diagonal teal **"League Wide Catch Difficulty Scale"** bands sweep the
  lower-right (short time + long distance = hard): 5 shaded star bands, darkest =
  5★. Bands are league constants, NOT per-player — the player's dots are read
  against a fixed league difficulty surface.
- Legend/encoding: filled red = **Out**, gray = **Hit**, green ring = **Wall**
  play, blue ring = **Back** (going-back) play. Clicking legend filters (e.g.
  Wall-only view in screenshot 134333).
- Tooltip per dot: `Catch Probability: 5% | Opportunity Time: 5.2 seconds |
  Distance Needed: 104ft.` Dropdowns: year + FIELDER PERSPECTIVE.

## Source 2 — MLB Glossary: Catch Probability

URL: https://www.mlb.com/glossary/statcast/catch-probability (WebFetch, clean)
- Inputs: (1) **Distance needed** — start position to catch point, optimal
  route; (2) **Opportunity time** — clocked from PITCHER'S HAND RELEASE, not
  contact; (3) **Direction** — going-back adjustment since May 2017; (4) **Wall
  proximity** adjustment since 2018.
- Star buckets: 5★ = 0–25% catch prob, 4★ = 26–50%, 3★ = 51–75%, 2★ = 76–90%,
  1★ = 91–95%; >95% = unrated/routine.

## Source 3 — MLB Glossary: Outs Above Average + Tango attribution rule

URLs: https://www.mlb.com/glossary/statcast/outs-above-average (WebFetch) +
https://tangotiger.com/index.php/site/comments/statcast-lab-catch-probability-outs-above-average
(via WebSearch excerpt; Tango is the Statcast author)
- OAA = season sum of per-play credits: catch a 75% ball → +0.25; miss it → −0.75.
- **Responsible-fielder attribution (the answer to Zac's question):** every
  batted ball gets exactly ONE responsible fielder. If an outfielder makes the
  putout (or error), it's his. If it falls for a HIT, responsibility goes to the
  fielder **closest to the eventual landing spot, measured from his starting
  position at pitch release**. So yes — a player IS responsible for balls he
  never touched, and a missed catchable ball still counts against him. There is
  no "he missed it so he wasn't responsible" escape: responsibility is assigned
  pre-outcome by geometry, outcome only decides out vs hit coloring.

## Takeaways for us (v2 spec deltas vs our shipped v1)

1. **Our Tier-3 gate already matches Savant's concept.** `first_defender='Y' AND
   out_prob NOT NULL` (GC2's first-defender flag) ≈ Savant's
   closest-to-landing-spot rule. Terminology now defensible as "Responsible
   plays." Difference to verify on work laptop: whether GC2 flags first_defender
   on outs made by a NON-nearest fielder the same way Savant reassigns to the
   catcher-of-record.
2. **Chart A deltas we do NOT have:** opportunity BINNING with size-by-count +
   per-bin Exp vs Actual catch rate tooltip; outs HULL + hits HULL (deferred to
   v2 in review as "convex hulls" — now confirmed as a core Mazzo ask); catch-rate
   band slider (GT + LT pair — we shipped one-sided). We DO have: field view,
   per-play difficulty stars, Wall/Back rings, hang slider, reach ring.
3. **Our reach ring is legitimate** — it's Savant's own "Sprint Speed Range?"
   overlay. Zac's objection was to presentation ("Fixed defaults" caption reads
   like canned data). v2: anchor ring time to the play data (e.g. median hang of
   the window) or show ring + empirical outs hull TOGETHER like Savant does —
   the hull is the data-driven range, the ring is the model overlay.
4. **Chart B is a NEW surface for us:** hang-time × distance-needed scatter with
   league difficulty bands. We have out_prob per play (GC2 model) but the BANDS
   require a league-wide difficulty surface over (opportunity time, distance) —
   candidate: bucket league plays into prob bands from our own tracking data, or
   draw iso-probability bands from the GC2 out_prob model itself. MiLB caveat:
   HawkEye sparsity (~50% at non-HE venues) thins both dots and the league pool.
5. **PDF translation question (open):** Savant charts are slider-driven; a static
   PDF must freeze settings. v1 froze at defaults + captioned them. Options for
   v2 PDF: (a) small-multiples at 2–3 canonical slider settings, (b) drop the
   interactive-style view from the PDF and print Chart B (scatter is static by
   nature) + hulls-only field view, (c) keep PDF minimal until Mazzo's dash
   verdict. DECISION PENDING — Zac reviewing dash first; weekly-PDF inclusion
   still gated on Mazzo approval regardless.

## Local assets

- Screenshots: `C:\Users\Owner\OneDrive\Pictures\Screenshots\Screenshot 2026-07-09 133448.png`
  (Chart A + tooltip), `...134326.png` (Chart B full), `...134333.png` (Chart B
  Wall-filtered), `...134406.png` (Chart B tooltip + perspective dropdown).
- Video: `C:\Users\Owner\Downloads\OF DASH EXAMPLE.mp4` (111s; slider/hull/
  sprint-ring interactions; sampled frames in session scratchpad).

---

## BUILD STATUS + IF NEXT (updated 2026-07-21)

The OF Range & Difficulty dashboard is **DONE and deployed** (Intangibles app,
`feature/astros-intangibles`). The 2026-07-19→21 sessions rebuilt it from the v1
above to match Zac's reference video/mocks exactly. Zac's verdict 2026-07-21:
*"we are good here on the OF... we cooking here."*

### What OF actually shipped (the reference impl for IF)

- **Single page, two square charts, stacked** (Zac reverted a side-by-side
  experiment): Responsible Plays scatter on top, savant field below.
- **Scatter (Chart B):** square, Opportunity Time (y, 1–8s) × Distance From Ball
  Landing (x, 0–140ft), 5 diagonal league difficulty bands + a WHITE 0-star
  no-chance floor below Elite. Bands = the same 5 `DIFFICULTY_BUCKETS` the weekly
  OF/IF reports use (out_prob .90/.75/.50/.25); fallback speed fan 20/24/28/33
  ft/s until the empirical league fit runs on a live DB. Teal gridlines drawn as
  explicit traces (kaleido ignores `layer="above traces"` under band fills).
- **Field (Chart A):** square, cropped view box (`_FIELD_EXTENT_SQUARE` — the
  shared extent letterboxed the field into the top half), teal fair territory +
  grey outline + wall-distance labels read FROM the fence fn, square markers
  **sized by opportunity count** (not difficulty), convex hull **red=outs /
  grey=hits**, reach-ring bullseye drawn as filled traces (add_shape sat under
  the grass and read grey) toggled by **Sprint Speed Range** (OFF = zero rings).
- **Per-chart controls, NOT shared:** each chart owns its own filter row; the
  ONLY page-wide control is the sidebar (level/player/season/Position). Scatter
  row = `1★–5★ · 0% · Wall · Back · Out · Hit` as `st.pills`, every one an
  INDEPENDENT predicate (deselect 0% and every 0% play goes, wall ball or not).
- **Click-to-video on BOTH charts**, `video_url_index=7`.

### The hard constraints learned (so IF doesn't re-litigate them)

- **A plotly legend filters ONE dimension** — a marker lives in exactly one
  trace, so Out/Hit CANNOT be legend toggles beside the difficulty stars (a play
  can't be in both "3★" and "Out"). That's why the filter row is `st.pills`
  (independent predicates, brief rerun) rather than native legend dots. Asserted
  from plotly knowledge, not deep-researched; Zac accepted it. If ever revisited:
  the tell is that no Savant chart does dual-dimension legend toggling either.
- **0% means "displays as 0%"** = `out_prob < 0.005`, NOT `<= 0` — the hover
  rounds `v*100:.0f`, so a 0.004 play reads "0%". Testing `<=0` was a real bug.
- **Convex hull, NOT an angular/radial polygon.** An angular polygon was tried
  (read off video stills as "goes concave") and was wrong — jagged star. Reverted.
- **Sidebar widget-state trap:** Player selectbox needs an explicit `index`
  (else it snaps to top-of-list on state churn) and the Position radio key must
  be scoped per-gcid (options differ per player → shared key resets the widget).

### IF SAVANTIFICATION — parked, near-future (this is the /document ask)

Zac 2026-07-21: *"we may savantify some IF stuff in the near future... in the
near future we need to cook on some IF range and whatnot just like this."* He is
checking Savant for IF-specific presentation ideas and will come back with what
to build. **NOT started.**

Head start already in place: **IF shares the entire data path.** Both
`make_savant_range_figure` and `make_difficulty_scatter_figure` take
`domain="IF"`; `fielding_range_data._DOMAIN_CONFIGS["IF"]` carries the OPIDA
ball-time axis (`xtime_to_fielder`, reaction fallback), the IF field extent, the
1B/2B/3B/SS position map, and DSL `D`-angle video chains. So an IF port is
largely presentation decisions (Savant's IF page differs from OF — infield
difficulty is ball-time/reach, not hang-time/distance), not new plumbing.

Open IF questions to resolve when Zac returns: does the difficulty-band surface
(hang×distance for OF) become ball-time×reach for IF, and is there a league IF
band pool; how do the reach rings read on the infield zoom; whether the OPIDA
`lateral_distance_needed` should drive the scatter x-axis instead of
start→landing distance. The `_make_if_scatter_figure` builder already exists as
the seam.

### Reference pointers

- **Impl:** `intangibles/src/fielding_range_page.py` + `fielding_range_data.py`
  + `field_plot.py` (savant style + `show_distances`).
- **Durable spec + frames:** `intangibles/docs/mocks/of-dash-savant-reference/`
  (README behavior spec + video frames + the 4 mocks) — the file that stops the
  video context evaporating again.
- **Render harness (DB-free):** `intangibles/scripts/render_range_smoke.py` →
  `output/_range_smoke/` (40 PNGs, OF+IF).
- Video-angle fix shipped same session: MLB main chain `M→B→X→V` (V demoted
  below B/X — away games opened the CF/personal-device angle when M was absent);
  DSL `D` angle added to the range query. Audit query for the broader MLB
  home/away question: `sql-queries/mlb-home-vs-away-angle-audit.sql`.

Related: [[fielding-advance-spray-grid]], [[prp-player-review-process]],
[[rules/intangibles]].
