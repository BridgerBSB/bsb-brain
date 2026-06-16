---
type: concept
domain: pitching
source: personal-bsbres
created: '2026-06-15'
---
# Stuff+ Deep Learning (Pitch Design)

Two sources sit behind this note: an educational **"Pitch Design: What is Stuff+?"** deck, and the foundational **Driveline blog article of the same name** by Chris Langin (Pitching Trainer), *"Pitch Design: What is Stuff+? Quantifying Pitches with Pitch Models"* (Dec 13, 2021) — the canonical public explainer of Stuff+.

## What Stuff+ is
A **pitch model** scoring a pitch's intrinsic nasty-ness from physical traits alone, **location-agnostic** (command is measured in a separate metric). It quantifies the secondary skills beyond "command / velocity / manipulate-the-ball": the ability to **generate unique movement**. As of the 2021 article, Driveline's Stuff+ was on its **4th iteration**.

## Inputs / features
Primarily **ballflight metrics**: Pitch Velocity, Vertical Break, Horizontal Break, **Release Extension** — plus, in design contexts, release height, spin, tilt, spin efficiency, and **fastball-relative deltas** (a secondary graded against its own arsenal's fastball). The first three (velo, V-break, H-break) are the main drivers; the model accounts for **interactions** between them (more velo on a breaking ball often trades off with glove-side action; a sinker drops in effectiveness with too much V-break; a slider gains with H-break). Reclassifying four-seamers by their relative action (cutting vs riding) matters — a "FF" with cut competes in a different bucket than a true riding FF.

## Method
Mapped shape → grade. The deck's filename frames a **neural-net "deep learning"** approach, contrasted against the tree-based public analogs ([[tjstuff-plus]] is LightGBM; FanGraphs Stuff+ is tree-based). Either way the model is location-stripped and pitch-type aware.

## Scaling / units
**Scaled to 100 = league average, like IQ.** 75 = 25% below league avg; 130 = 30% above; a fastball of 75 is 25% below the FF bucket, a curveball of 130 is 30% above all breaking balls. Pitch types are **"popularized" / grouped into buckets** that compete *within* their grouping: **Fastballs** (Four-Seam, Sinker), **Breaking Balls** (Cutter, Slider, Curveball), **Offspeed** (Changeup, Splitter). **Buckets are not equivalent across groups** — breaking balls lower run values more than fastballs, so a FF Stuff+ 150 ≠ a slider Stuff+ 150 in "raw stuff."

**Run value per 100 pitches by raw pitch type (2021):** SL −0.98, CT −0.59, CB −0.58, CH/SP −0.42, FF −0.19, SI −0.14 (more negative = better). 2021 four-seam averages: RHP ~94.1 mph velo, 7.5" HB, 14" VB, 5.9' release height, 6.4' extension; LHP ~92.8, 7.8", 16.6", 6.0', 6.3'.

## Worked examples (from the article)
- **Aroldis Chapman** — highest-graded FF of 2021: 102.4 mph (99th pct), 18.7" VB (80th), −2.2" HB (10th) → **Stuff+ 350.** Velocity is the chief driver; he threw the 8 best FBs of the season.
- **Daniel Bard vs Mike Fiers** — same FF "label," wildly different grades: Bard 98.6 (98th), 13.5" VB (15th), 10" HB (67th) → **Stuff+ 90**; Fiers 89.4 (9th), 20.4" VB (92nd), 11.5" HB (80th) → **Stuff+ 80**. Bard rides league-leading velo/spin; Fiers compensates with big total movement to reach ~league average in the low 90s.

## Why it matters — pitch design payoff
The deck renders Stuff+ as **hexbin heatmaps over the break plane** (current movement vs hypothetical movement) → "add X inches of sweep, Stuff+ goes 110 → 121." Companion **FF release-height expectation tables** give per-slot shape benchmarks. The article's caution: Stuff+ is **location-agnostic** — maximize it *contextualized* to the pitcher's arsenal, not blindly (don't push a guy toward a sinker if his strength is a four-seamer; don't add a cutter that overlaps an existing pitch). Stuff+'s strengths: converges fast (small sample), reliable, percentile rankings, immediate offseason feedback.

## Links
[[MOC-baseball-analytics]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[lightgbm-baseball-modeling]] · [[driveline]] · [[tjstuff-plus]] · [[mix-plus-sync]] · [[driveline-hitting-models]] · [[independent-stuff-value]]
