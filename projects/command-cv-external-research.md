---
type: project
domain: computer-vision
created: 2026-08-17
updated: 2026-09-01
status: SUPERSEDED IN PART - re-read at v1.2.0 on 2026-09-01. Method sections below describe v1.0.0. Current analysis lives in bsb-resources/command-cv/docs/2026-09-01-opencommand-v12-and-cross-camera-accuracy.md
tags:
  - project
  - command-cv
  - computer-vision
  - external-research
  - pitching
---
# Command CV - External Research

External work on pitcher-command-from-video, captured against our own build
([[command-cv-status]], `bsb-resources/command-cv/` on `feature/pd-goals`).
Captured per the external-resource-capture rule (X -> `api.fxtwitter.com`, then
GitHub raw + tree API for the source).

---

## READ THIS FIRST - 2026-09-01 re-read at v1.2.0

Everything below was captured against **v1.0.0**. They have shipped v1.1.0
(Aug 21) and v1.2.0 (Aug 27) since, and two changes matter:

1. **The naive per-pitcher offset is gone**, replaced by a two-level
   hierarchical empirical-Bayes model with DerSimonian-Laird shrinkage, plus
   fitted glove-dependence slopes. The old method survives in their validation
   table as `fixed offset`, alongside the diagnostics that expose its
   small-sample artifact (bias -2.02 in at n=10, flatness 8.08 vs 10.14 full).
   **This retires the "their inferred target is a fitting artifact" critique in
   takeaway list item form below** - they found it and fixed it, and the gain now
   survives a 50/50 holdout (train 12.89, test 13.20).
2. **They added the 2024 season**, which gives a second independent broadcast
   year. Geometry accuracy is identical across the two (X 0.34/0.35, Z 0.40/0.39
   over 1.27M pitches). That is cross-camera evidence they never label as such.

**New analysis we ran that they do not publish:** `park` is stamped on every pose
row and never used in a validation. Broken out over 635,925 clips and 30 parks,
the geometry holds to about half an inch everywhere, only ~30% of the residual is
park-level (the rest is game to game), and accuracy is **flat with respect to how
far off-axis the camera is aimed** - which is precisely where our affine cannot
be. Full write-up and the reproducible script:

- `bsb-resources/command-cv/docs/2026-09-01-opencommand-v12-and-cross-camera-accuracy.md`
- `bsb-resources/command-cv/scripts/analyze_opencommand_poses.py`

---

## OpenCommand (DT K / @tomdoyo) - open-sourced Aug 11 2026

**What it is.** A complete, public, MLB-wide implementation of exactly the thing we
are building: pitcher command measured as the distance from a pitch's actual plate
location to the catcher's glove target, recovered from broadcast video. Announced
Aug 11 2026; code and data both public.

- Announcement thread: <https://x.com/tomdoyo/status/2087272169852088752>
- Repo: <https://github.com/tomdoyo/open-command>
- Data 2025 + 2026: <https://huggingface.co/datasets/tomdoyo/open-command>
- Supporting thread, "true fastball miss is 7-10in, not the commonly cited 10-13in":
  <https://x.com/tomdoyo/status/2082066794404294671> (Jul 28 2026)
- License: **CC BY-NC-SA 4.0, NON-COMMERCIAL**, attribution required (CITATION.cff)

### Models

**YOLO11** detectors over broadcast clips for three classes: **glove**, **ball**,
**strikezone box**. Postprocessing by detection confidence.

**The weights are NOT released.** The repo ships the pipeline (5 python files) and
the *detection outputs*; no trained detector is in the tree (verified against the
GitHub tree API: `src/`, `artifacts/`, `data/.gitkeep`, and nothing else). So the CV
half is a description. The geometry half is fully open and is the valuable half.

### The pipeline (4 stages, `src/`)

| Stage | Script | What it does |
|---|---|---|
| 1 | `solve_camera_pose.py` | Solve the CF broadcast camera pose per game + per clip. HEAVY, hours per season. JAX `vmap`/`jacfwd` + a hand-rolled batched Levenberg-Marquardt. |
| 2 | `solve_glove_locations.py` | Unproject glove pixels to world (x, z) on a fixed depth plane |
| 3 | `target_inference.py` | Peak-glove target, then a per-pitcher offset |
| 4 | `opencommand.py` | miss = distance(actual, target); median per pitcher x pitch type |
| - | `poselib.py` | pinhole model, `project` / `unproject`, Statcast 9-param trajectory |

### The core method (the part that matters to us)

**They calibrate on the BALL and the drawn strike-zone box. Never on the glove.**

- World frame: feet, plate-centered, origin at the plate's back tip, x = catcher's
  right, y = toward the pitcher, z = up.
- **Phase 1, per GAME.** For every clip with a plausible ball run, fit a
  **7-parameter** pose `(Cx, Cz, pan, tilt, roll, f, t0)` against **12+ observations**
  (8+ ball pixels plus the 4 strike-zone box corners). Ball world positions come free
  from the Statcast 9-param trajectory `(x0,y0,z0, vx0,vy0,vz0, ax,ay,az)`. `t0`, the
  clock offset, is a fitted nuisance parameter and is discarded. Robust loss soft_l1,
  `f_scale = 2.0`. A clip only **votes** if its ball reprojects within **3 px RMSE**;
  the game's camera position `C` is the **median of the votes**, minimum 2 votes.
- **Phase 2, per CLIP.** Freeze `C`, refit only `(pan, tilt, roll, f)` from the
  **4 box corners alone**, on that clip's own peak-glove frame. The ball is
  deliberately excluded here "because camera often moves mid-ball flight."
- **`Cy` (camera depth) is PINNED at 400 ft and never solved.** It is degenerate
  against focal length (move the camera back and zoom in, get the same pixels). They
  validated the pin on a 140-clip harness: a free `Cy` rails at its bounds while the
  targets move **0.06 in**. Documented as a deliberate non-identifiability, not a
  shortcut.
- Glove depth is pinned the same way: **`SETUP_DEPTH_FT = -1.75`** (median catch
  depth, 1.75 ft behind the plate tip). Glove pixels unproject onto that plane.
- Strike-zone box world geometry: 17 in wide (`+/- 17/24 ft`), `sz_top`..`sz_bot`
  tall, at the zone depth plane, which is **17/12 ft through 2025 and 8.5/12 ft from
  2026 under ABS** (the broadcast moved the drawn box; `plate_x/z` did not).
  They fit against a **reference** `sz_top_ref`/`sz_bot_ref`, never the pitch's own
  sz, because Statcast re-measures sz on takes and leaves the batter default on
  swings, so the raw value would fit the camera pose against the pitch's own outcome.

### Target definition

- **Naive target** = the **highest** glove `z` in the window
  **`[release - 2.0 s, release - 0.3 s]`**, subject to a stability check: the
  `+/- 0.05 s` neighborhood spread must be `<= 4 in`, otherwise skip to the next
  candidate. The value is the **median** of that neighborhood. The `-0.3 s` end is
  explicitly "catch-lock-safe", i.e. it stops the window grabbing the receive.
- **Inferred target** = naive + **mean(actual - naive) per (pitcher x pitch type x
  season)**. Rationale: pitchers "start the pitch from the glove and let the ball
  break away from it." Explicitly assumes every pitcher is perfectly calibrated at
  the pitch-type level.
- **Plausibility screen:** drop `|x| > 20 in`; drop `z` outside a pitch-type
  floor/cap (`z > 10 in` for FF/SI/FC else `> 6`; `z < 50` for FF else `< 44`).
- **Teleport cleaning** (`clean_teleports`): a detection is kept only if physically
  reachable from the **last accepted** detection, radius `min(150 in/s * dt, 20 in)`.
  Their comment: "a catcher's glove tops out near 180 in/s; **misfires jump 15-40
  in**." It keeps the largest mutually-consistent set and re-seeds until every
  detection is covered, so a clip that OPENS on misfires still finds the real glove.

### Results and validation (`artifacts/validations_2025.txt`)

**Geometry accuracy, the number to beat:** reprojecting the Statcast trajectory
through the SHIPPED pose gives **ball-at-plate error of median 0.35 in in X and
0.39 in in Z** (n = 635,018 = 99.9% of posed clips). Pixel reprojection median 2.28
px, 76.5% under 5 px. The shipped phase-2 pose is fit on box corners only, so the
ball is close to a genuine holdout.

**Coverage funnel, 2025: 90.09% of all 724,005 pitches survive end to end.** Losses:
no strikezone drawn -4.21%, no ball release -1.62%, late CF camera cut -2.89%, low
detection quality -0.81%, implausible target -0.28%.

**MLB command distribution, 2025 (per-pitcher MEDIAN miss, inches):**

| Pitch type | naive median | inferred median |
|---|---:|---:|
| All | 11.06 | 9.97 |
| FF four-seam | 10.07 | 9.39 |
| SI sinker | 9.92 | 9.11 |
| FC cutter | 9.82 | 9.37 |
| SL slider | 11.53 | 10.39 |
| ST sweeper | 11.95 | 10.66 |
| CU+KC curve | 13.07 | 11.40 |
| CH change | 12.78 | 10.56 |
| FS split | 13.70 | 10.99 |

The fastball family commands about 1 in better than breaking/offspeed. Inferring the
target shaves about 1 in off naive. Best 2025 inferred: Turnbull 7.37, Hoby Milner
7.67 (n=885), Eovaldi 7.81 (n=1619), Nola 8.11 (n=1526).

**External validity, 339 pitchers, min 50 IP (Spearman):** BB% **+0.547**
[+0.465, +0.626] inferred, +0.456 naive · Stuff+ +0.251 · xERA -0.069 (ns) ·
xERA given Stuff+ +0.137. Walk rate is the anchor.

**Their own stated limits.** No ground truth exists ("unless we ask hey where did you
aim every pitch"). Season-level "good chance of <1 inch"; **pitch-level "certainly
not."** Median over mean because a single 100-in spike takes 100 pitches to undo.
Three failure archetypes: see-glove-hit-glove pitchers are represented best; pitchers
who make the CATCHER move to match their miss pattern invert the premise entirely;
pitchers who **never look at the glove** (they name Misiorowski) are heavily
misrepresented.

---

## Takeaways for us

Ordered by value. Where we are today: a per-game **affine** pixel-to-feet fit on
catch-glove-pixel to Trackman `plate_x/z` pairs, RANSAC-robustified, **LOO median
3.9 in**; Ogando 2026 A+ season board median miss 14.2 in on 110 of 149 pitches.

1. **Replace the affine with a physical pinhole camera solve. This is the finding.**
   Their geometry contributes about 0.4 in of error. Ours contributes about 3.9 in.
   Same problem, roughly 10x. Our affine is a 6-DOF planar approximation of a
   projective camera, and it is fit on the noisiest object in the pipeline. A 7-param
   pose with `Cy` pinned is barely more code (`project` / `unproject` are ~20 lines
   each) and it is physically identifiable.
2. **Calibrate on the BALL, not the glove.** The conceptual unlock. Today our ruler
   is built from catch-glove detections, so calibration error and glove-detection
   error are literally the same error, and the receive-plane vs plate-plane offset is
   silently absorbed into the fit. The ball's 3D position is known exactly at every
   instant from the 9-param trajectory, and it is a small high-contrast object. **We
   have that trajectory** (`trajectoryData` on the authed analytics payload; also
   `groundcontroltracking.Tracking.Pitch_Hit_Trajectories` /
   `Hawkeye_Pitch_Hit_Trajectories`). This also removes our "needs ~30 pitches per
   game to self-calibrate" limitation, which is the thing that makes short relief
   outings unusable today.
3. **`clean_teleports` is a free fix for our elbow-grab, today, with no retraining.**
   Reachability filter of `min(150 in/s * dt, 20 in)` from the last accepted
   detection, and their own comment says misfires jump 15-40 in, which is exactly the
   elbow/forearm offset from the mitt. Our current plan is to annotate the 69
   RANSAC-rejected hard cases and retrain. Do the filter FIRST; it may eat most of the
   problem in about 30 lines. The "largest mutually-consistent set, try every seed"
   detail matters - a clip that opens on the elbow still recovers.
4. **The strike-zone box is their anchor and we probably do not have one.** MiLB A+
   broadcast (behind-pitcher, our only Asheville angle) likely draws no K-zone box, so
   phase 2 as written does not port. Two outs, both fine: (a) our camera is a fixed
   mount, so a per-GAME pose from ball runs alone may be sufficient (8+ ball points =
   16 residuals against 7 params, no box needed); (b) **we have anchors they can never
   have** - HawkEye gives us real-world 3D positions of the catcher, umpire, and every
   fielder per frame (`Play_Event_Positions`, `Player_Tracking_ByPos`,
   `Play_Starting_Positions`). Those are calibration correspondences on demand. This
   is a real edge over the public-data version.
5. **Pin the depth planes explicitly and name them.** `SETUP_DEPTH_FT = -1.75` and
   `Cy = 400` as documented, validated constants beats our current "the affine absorbs
   the offset." Our own two-planes doc already says the offset is physics and not a
   bug; this is how to make that statement operational. Their 140-clip degeneracy
   harness (free `Cy` moves targets 0.06 in) is the model for how to justify a pin.
6. **Steal the target-selection criterion and A/B it against ours.** Ours: longest
   low-motion glove run. Theirs: **highest** glove z in `[release-2.0s, release-0.3s]`
   with a `+/-0.05 s` spread `<= 4 in` stability gate, median of that neighborhood,
   falling through to the next candidate when jittery. Genuinely different definitions
   of "the target." Cheap to test both against our 49 hand-labeled clips.
7. **Get an external validity check. We have none.** Their strongest credibility claim
   is the BB% correlation (+0.547), not the pipeline. Correlating our per-pitcher
   median miss against affiliate BB% is cheap and is the first thing
   council-data-scientist will ask for. Their numbers also give us a yardstick: MLB
   naive median 11.06 / FF 10.07 against our A+ 14.2 / FF 15.4. Worse command at A+ is
   expected, and part of our gap is our own ~4 in of calibration noise, which is one
   more argument for item 1.
8. **Publish a coverage funnel.** They lose 10% and itemize every reason. We lose 39
   of 149 Ogando pitches and have never named why. Same discipline, and it is the kind
   of thing a coach asks about immediately.
9. **Adopt their known-limitation catalogue verbatim as caveats.** Pitchers who make
   the catcher move to match their miss pattern, and pitchers who never look at the
   glove, break any glove-target method including ours. That belongs on any
   coach-facing page we ship.
10. **YOLOv8n to YOLO11n is a free upgrade, and the SMALLEST win here.** YOLO11n is
    about 39.5 COCO mAP against YOLOv8n's 37.3, at fewer parameters and roughly 56 ms
    vs 80 ms per image on CPU, so more accurate AND about 30% faster, which matters on
    our CPU-only box. One-line change in the training call, reusing the existing 98
    crops plus the 69 hard cases. But our detector is already mAP50 0.85 / P 0.93.
    **The bottleneck is calibration, not detection.** (YOLO26, NMS-free end-to-end, is
    the current bleeding edge if we ever want it.) Source for the head-to-head numbers:
    <https://docs.ultralytics.com/compare/yolo11-vs-yolov8> and
    <https://docs.ultralytics.com/models/yolo11>.

### Where they are weaker than us, and one caution

- **The "inferred target" is bias removal, not a command improvement.** Adding
  `mean(actual - naive)` per pitcher x pitch type forces that pitcher's mean residual
  to zero by construction, so inferred miss measures **dispersion only** and discards
  accuracy. It mechanically improves the headline by about 1 inch. If we adopt it,
  report BOTH and never report inferred alone. This is exactly the class
  `prescriptive-claims-from-observational-data.md` #1 exists to catch: a shipped
  magnitude produced by a fitting artifact. It also needs shrinkage at our sample
  sizes; a per-pitch-type offset on ~20 A+ sliders is noise.
- **Their "actual" is Statcast `plate_x/z` too**, so they inherit the same
  plate-front vs receive-plane mixing we documented. They handle it by pinning the
  glove plane and letting the pose absorb the remainder. Nobody has solved it. We
  should stop treating it as an open problem unique to us.
- **We have HawkEye; they have broadcast only.** Fielder and catcher 3D truth, real
  `plate_x/z` at every affiliate, and the ability to work where no K-zone is drawn.
  Our Model B (standalone CV, no data backup) remains the differentiated goal: their
  pipeline is 100% Statcast-dependent and cannot run anywhere Statcast is dark, which
  is precisely the amateur / back-field / non-HawkEye case we care about.

### LICENSE CAUTION (read before any code moves)

**CC BY-NC-SA 4.0, non-commercial.** A club using this for player development is
plausibly commercial use. Do **not** vendor `poselib.py` or any OpenCommand file into
`bsb-resources`, and do not ship their dataset inside a club product, without a legal
read. The *method* (pinhole camera, Levenberg-Marquardt pose estimation, robust
soft_l1 loss) is textbook computer vision and is not theirs, so reading the repo and
independently implementing the geometry is fine. Attribution is the right move
regardless. Share-alike would also try to reach into anything derived from their
code, which is the second reason to reimplement rather than copy.

---

Related: [[command-cv-status]] · [[pytorch-training-pipeline]] ·
[[context-library]] · [[MOC-baseball-analytics]] · [[council-knowledge-base]]
