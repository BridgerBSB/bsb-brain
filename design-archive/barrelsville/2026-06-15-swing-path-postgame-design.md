# Swing Path Visual — Hitter Postgame Visuals Tab (Design)

Status: **EXPLORATION (2026-06-17).** First in-app slice shipped; true-arc
reconstruction validated offline. Still iterating on the arc + visual before
it's locked.

> **Are we making up the swing path? NO.** We reconstruct it from Hawkeye's own
> MEASURED data: the curvature profile `Km30…K45` (the bat-path turn-radius at six
> bat-rotation stations −30°→+45°), the measured swing plane, and the measured
> contact point/tangent — then we validate it against the measured snapshot dots
> (activation/pitcher_face/true_peak/peak/contact). On clean swings the
> reconstruction lands **0.03–0.30 ft** from those dots, i.e. the arc threads the
> real measured points. The *shape is measured*, not invented.
>
> **Honest limit (current):** Hawkeye stores the per-frame *body skeleton* only as
> blob files we can't query (see data-ref §K), and the curvature span covers the
> swing-zone, not the deepest load. So the deep wind-up beyond the measured span is
> the measured curve continued, not per-frame truth.
>
> **FAR-FUTURE only (not now):** for contexts with NO swing tracking at all
> (lower levels / missing data), we *may* later train a model to predict a swing
> path from whatever signal exists. That is well down the road — today we draw
> only measured swings and simply omit swings without data.

Owner: Zac. Worktree: `feature/barrelsville` (`bsb-wt-hitting/barrelsville`).
Discovery SQL: `sql-queries/swing-path-discovery.sql` (run + results captured
2026-06-15).

---

## 1. Purpose & placement

A reactive Savant-style **bat swing-path** visual for the hitter postgame
**Visuals tab** (`barrelsville/pages/1_Postgame.py`), placed **below the spray
chart**. It reconstructs the bat's path through the swing from our internal
HawkEye tracking and reacts to the page's existing scope (selected dates,
level/sched_type, pitch/result filters).

Reference look = the Savant 3-view swing-path screenshots (front/catcher, side,
overhead + home plate) plus a metric table. Our internal data is **richer than
Savant public**, so this should exceed the public version where data exists.

---

## 2. Layout & scopes (VALIDATED)

Three **showings**, side by side (3 columns). Each showing = **3 stacked
projected views** (front/catcher = XZ, side = YZ, overhead = XY) with home plate
drawn, + its **own metric table** beneath.

| Showing | What it draws |
|---|---|
| **A — All selected swings** | Every qualifying selected swing overlaid as faint spaghetti (the raw sample). |
| **B — Selected avg vs season baseline** | Bold = pooled average path over the *selected* swings. Overlaid lighter line(s) = the **full-season average** path for each year the selected dates touch (3 dates in 2025 → selected-avg + full-2025-avg; 2 in 2025 + 1 in 2026 → selected-avg + full-2025-avg + full-2026-avg). "My sample vs the season." |
| **C — Per-year avg of the selected swings** | One average line per year, over *only the selected swings* in that year (multiple colored lines when multiple years selected; single line when one year). |

**Metric tables** — one per showing: Bat Speed, Swing Length, Path Tilt, and
HAA + VAA at Downswing / Contact / Follow-Through. Showing-C table has one
column per year when multiple years selected.

**Handedness**: draw in the postgame catcher's-view convention (see
`.claude/rules/coordinates.md`); L vs R render correctly without flipping the
metric values.

---

## 3. Data sources (discovery-confirmed 2026-06-15)

Join chain (verified from GC2's production swing query — do not change):
```
Astros.Pitches_View (batter_id, sched_id, pitch_id)
  -> groundcontroltracking.tracking.plays   ON sched_id, astros_pitch_id = pitch_id
  -> *.swing_shapes / *.swing_contact_values ON sched_id, tracking_play_id
Astros.Bat_Tracking_Metrics                  ON sched_id, pitch_id
```

Three surfaces hold the bat path. **All share one coordinate frame**:
plate-origin, **feet**; velocities in **ft/s**; bat speed mph = `v * 0.681818`.
Confirmed by `x_peak`(0.05)/`y_peak`(1.43)/`z_peak`(2.19) ≈ SCV
`batx/y/z_con` ≈ Swing_Shapes `x0/y0/z0`.

### 3a. `Astros.Bat_Tracking_Metrics` — the swing skeleton (PRIMARY)
Real measured bat state at **4 kinematic timestamps**, each with full state
(`time_*`, `x/y/z_*`, `vx/vy/vz_*`, `v_*`, `yaw_*`, `roll_*`, `distance_*`):
`activation → pitcher_face → true_peak → peak`. Plus `time_at_swing_start`,
`adj_aa_pitcher_face`, `adj_vba_pitcher_face`, `adj_horz_activation`.
- `distance_*` = cumulative bat-head path length (≈7.8 ft) → **swing length**.
- `v_*` ft/s → bat speed (×0.681818 → mph).
- `yaw_*` / `roll_*` (deg) → HAA / VAA at that phase.

### 3b. `tracking.Swing_Contact_Values` — exact contact frame
`t_con`, `batx/y/z_con`, `batvx/y/z_con`, orientation `e1x/y/z_con`, bat head
`headx/y/z_con`, ball `ballx/y/z_con` + `ballv*_con`, `con_loc_axis/perp`.
The 5th (terminal) anchor point + the canonical contact-frame HAA/VAA/bat-speed.

### 3c. `tracking.Swing_Shapes` — curvature profile (SHAPE REFINEMENT)
`Km30, Km15, K0, K15, K30, K45` = **curvature (1/ft)** at bat-angle stations
−30…+45°; arc radius (ft) = `1 / Kx` (GC2: `SwingRadius{X}degAvg = 1/Kx`).
Plus plane (`loft`, `tilt`, `plane_p0/p1/p2`) and anchor `x0/y0/z0`.
`tilt` → **Path Tilt** metric.

### 3d. Bonus / not required
`tracking.Hitter_Kinematics` — body biomech at swing start (lead wrist/elbow
rot+tilt, torso flexion/rotation/tilt). Context only; not the bat path.

### 3e. No per-frame bat table
There is **no** frame-by-frame bat trajectory table (Ball_Tracking is the ball;
Player_Tracking_ByPos is fielders/runners). The 4 snapshots + contact (5 real
anchor points) are the richest bat data available.

---

## 4. Reconstruction approach (VALIDATED — conservative)

**Production = real measured data only.** A swing is drawn ONLY when it has the
required tracking rows. We never fabricate/extrapolate an arc where the data is
missing — a swing without data is simply omitted from the showing.

**CORRECTION (2026-06-15, from the decode of `b6b` times):** the four
`Bat_Tracking_Metrics` POSITION snapshots are all timestamped within ~10 ms of
contact (`time_activation/pitcher_face/true_peak/peak` ≈ 0.40–0.41 s; only
`time_at_swing_start` ≈ 0.19 s is early, and it has NO position columns). So the
measured positions cluster at the contact zone and **cannot carry the full arc**.

Honest source split:
- **Arc SHAPE ← `Swing_Shapes`** (curvature `1/Kx` across −30°→+45° + plane
  `loft`/`tilt`/`plane_p*`, anchored at contact / `x0/y0/z0`). ~50–80% coverage.
  This is the prod arc. A swing draws its arc only when it has Swing_Shapes.
- **Phase METRICS ← snapshots + SCV contact** (HAA/VAA at downswing/contact/
  follow-through, bat speed, swing length via `distance_*`). ~90–99% coverage.
  The metric table can populate even when the arc can't.
- **Experimental (NON-PROD, flag-gated): snapshot-spline.** Cubic-Hermite
  through the 5 anchor points (velocity tangents) only REFINES the contact zone
  — it cannot extend earlier (no early positions). Kept for eyeball trials;
  default OFF; never auto-promotes to prod.

The arc-geometry decode (exact frame for `Km*`/`plane_p*` → 3D arc) is the open
item the prototype (`scripts/exploration/swing_path_decode_prototype.py`)
exists to settle.

**UPDATE 2026-06-16 (first prototype run — 218498):** the measured points read
as a **coherent, real swing-zone path** in all 3 views (CU swing spanned ~1.4 ft
of forward travel; conventions correct, one consistent plate-frame). Revised
leading approach:
- **Prod arc candidate = Hermite spline THROUGH the 5 measured points** (real
  positions + measured velocity tangents — interpolation of measured data, not
  fabrication). Needs `Bat_Tracking_Metrics` + contact (~90%+ coverage), NOT
  `Swing_Shapes`. This covers the swing-*zone* arc — the segment that matters
  most for attack-angle / path-tilt reading.
- **`Swing_Shapes` curvature = the EXTENSION** to push the arc earlier (toward
  load) + smooth it, where present. The first-guess experimental curvature arc
  was geometrically wrong (right radii, wrong plane/anchor) — set aside until
  the measured-point arc is validated in 3D.
- Prototype now also writes an interactive **Plotly 3D HTML** (rotatable) so the
  arc shape can be judged directly. Awaiting Zac's 3D eyeball before locking the
  prod-arc method.

**UPDATE 2026-06-16 (2nd run — snapshot timing + angle-constrained arc):**
- The raw snapshot-spline wiggled — it ignored the angles. Decode of the FT swing
  showed **the 4 bat-tracking snapshots straddle contact within ~10 ms** (`activation`
  ~4 ms BEFORE contact; `pitcher_face`/`peak`/`true_peak` AFTER it). They sample a
  ~1 ft window around contact, NOT the downswing. So they cannot carry the arc shape.
- New working arc = **angle/plane/curvature-constrained** (`_constrained_arc`):
  anchor = measured contact point; contact tangent = measured `batv_con` direction
  (= attack angle + horizontal sweep); swing plane = `batv_con × e1_con` (the two
  measured vectors that span it); curvature near contact from `K0` (or fit to the
  contact-zone points); extended ~4 ft as the visible swing zone. Produces a
  believable swing-zone path (uses the angles Zac asked about). The raw spline is
  now behind `--spline`; the experimental Swing_Shapes curvature arc behind `--arc`.
- **Honest limits:** (a) the ~4 ft extent + follow-through length are a DISPLAY
  choice, not measured; (b) curvature is taken constant (from `K0`) — real bend
  varies `K0→K45`; (c) this is the contact-anchored swing-ZONE arc, NOT the full
  load→contact arc. Full fidelity needs decoding the `Swing_Shapes` station
  geometry (Q1–Q3) and/or a Savant cross-check to calibrate. Those are the next
  unblock, not more blind arc guesses.

**UPDATE 2026-06-17 (TRUE ARC — the curvature reconstruction, VALIDATED):**
The shipped app arc (`build_arc`) was a lazy **K0-only parabola** — it used only the
curvature *at contact* and a generic bend, throwing away `Km30/Km15/K15/K30/K45`,
the plane angles, the anchor, and the measured dots. That's why it floated *near*
the snapshots instead of *through* them.

The real reconstruction (`scripts/exploration/swing_path_true_arc.py`, runs offline
on the dump or live via `--batter-id`):
1. **Integrate the measured curvature** across stations −30°→+45°: tangent angle =
   station angle, local radius = `1/Kx` (interpolated). This traces the real
   ~75°-of-rotation arc shape — a real ~4–5 ft of bat travel, not a parabola.
2. **Orient with the measured swing plane** (SVD-fit a plane to the measured dots;
   fallback = `batv_con × e1_con`).
3. **Anchor station-0 at the measured contact point**, tangent = measured `batv_con`.
4. **Pick the orientation** (4 sign combos) that best matches the measured dots.

**Validation (Justin Thomas 5-swing dump):** avg miss of the arc to the measured
dots = `242` 0.03 ft · `232` 0.06 ft · `87` 0.21 ft · `324` 0.30 ft · junk foul-tip
`184` 0.82 ft. The clean arcs **thread activation→contact→peak**. PNGs:
`output/true_arc_*.png` (also copied to Downloads). **This is the production arc
direction — port it into `swing_path_data.build_arc` (replace the parabola).**

Per-view projection: project the reconstructed arc onto XZ (front), YZ (side),
XY (overhead); draw home plate per the `swing-path` project geometry (origin =
back tip of plate, front edge Y = 1.417 ft).

---

## 5. Metric table mapping

| Table row | Source |
|---|---|
| Bat Speed | `v` (ft/s ×0.681818). Savant-style = peak (`v_true_peak`); contact via SCV. (Pick one at build; default peak to match Savant.) |
| Swing Length | `Bat_Tracking_Metrics.distance_*` (≈ distance to peak/contact). |
| Path Tilt | `Swing_Shapes.tilt`. |
| HAA — Downswing | `yaw_pitcher_face` (or `adj_aa_pitcher_face`). |
| HAA — Contact | derived from SCV (`e1*_con` / `batv*_con`). |
| HAA — Follow-Through | `yaw_peak`. |
| VAA — Downswing | `adj_vba_pitcher_face` / `roll_pitcher_face`. |
| VAA — Contact | SCV (`e1z_con` → `90 - acos(e1z_con)` per GC2). |
| VAA — Follow-Through | `roll_peak` / `asin(vz_peak/v_peak)`. |

Averages computed per showing (selected pool / season pool / per-year pool),
full precision until display (`.claude/rules/never-round-until-display.md`).

---

## 6. Coverage & level gating (discovery 2026-06-15)

`has_swing_shapes` / `has_bat_tracking` per level, 2026:

| Level | swings | swing_shapes | bat_tracking |
|---|--:|--:|--:|
| MLB | 214k | 81% | 99% |
| AAA | 141k | 53% | 93% |
| AA (aax) | 124k | 76% | 81% |
| A+ (afa) | 124k | 72% | 76% |
| A (afx) | 121k | 53% | 73% |
| FCL (rok) | 67k | 26% | 36% |
| DSL | 29k | 10% | 12% |
| College (bbc) | 1.2M | 1% | 2% |

→ **Affiliate-wide** (MLB→A solid, FCL usable, DSL/amateur sparse — show what
exists, omit the rest). `bat_tracking` coverage >> `swing_shapes`, which is why
prod leans on the snapshots and treats Swing_Shapes as refinement.

---

## 7. Cherry metrics (LATER — not in v1)

Add after the swing-path ships, per Zac:
- **Squared-up %** — FanGraphs/Statcast. EV achieved vs max possible given bat
  speed + pitch speed.
- **Ideal Attack Angle %** — % of swings with attack angle in a good band
  (Blast ~6–14°; confirm Savant/ours band at build).
- **Smash Factor** — EV / bat speed (Driveline article for exact calc).

EV sourcing open item: Pitches_View here exposes pitch speed
(`plate_speed`, `release_speed`, `pitch_speed_50ft`) but **not** `hit_exit_speed`
on this connection. Likely source EV from
`tracking.Hawkeye_Pitch_Hit_Trajectories.hit_launch_speed` (+ `hit_launch_angle`)
or `Astros.Hits` — confirm canonical EV column when building cherries.

---

## 8. Open items / risks

1. **Snapshot frame/orientation conventions** — confirm `x/y/z_*` and
   `yaw/roll` axis conventions match SCV + the plate frame on a real swing
   before trusting the spline (build a single-swing decode/plot first).
2. **Prod render threshold** — exact minimum columns required to draw (contact
   only? contact + ≥2 snapshots?). Decide via the prototype.
3. **Spline never auto-promotes to prod** — flag-gated until Zac signs off.
4. **Performance** — 3 showings × 3 views, potentially hundreds of overlaid
   swings (Showing A). Matplotlib static (per spray-chart pattern) likely
   fine; cache the reconstructed-arc dataframe per scope.
5. **PDF last** — per `.claude/rules/pdf-last-in-script.md`, any PDF block goes
   after all chart rendering.

---

## 9. Reference implementations

- `sql-queries/swing-path-discovery.sql` — the discovery script + results.
- `swing-path/catcher-interference-app/` (personal project) — plate geometry,
  3-view projection, bat-ladder rendering, cubic-Hermite arc heuristic. Port the
  **rendering** layer; replace its public-Statcast heuristic with our measured
  reconstruction.
- GC2 production swing query (captured in brainstorm) — canonical contact-frame
  HAA/VAA/AA/bat-speed formulas + `SwingRadius = 1/Kx` decode.
- `barrelsville/src/bat_speed_clean.py` — canonical bat-speed cleaning (57 mph
  floor etc.) for the bat-speed metric.
- `.claude/rules/coordinates.md` — plate_x conventions / handedness.
- `barrelsville/pages/1_Postgame.py` Visuals tab — host page + spray chart it
  sits below.

---

## 10. Build sequencing

**CLARIFICATION 2026-06-21 (are we "chill"? — YES, with 2 deferred refinements).**
The MEASURED CONTACT POINT is correct and IS drawn: the arc passes through `bat_con`
and the orange bat sits there. NOT a missing-join issue (we already pull
`swing_shapes` incl. loft/tilt + `swing_contact_values`). The per-swing different
planes are real (we already fit a plane per swing — plane-aware). Two SECOND-ORDER
refinements remain, both DEFERRED polish, NOT blockers:
  1. **Plane = per-swing SVD / `batv×e1` GUESS** (Brodie's "too straight"); should be
     canonical loft/tilt.
  2. **Arc registration:** contact stamped at the 0° (pitcher-face) node; should be at
     the **HBA_con** node. HBA_con matters ONLY because it's the arc's PARAMETER axis
     (`Km*` sampled along HBA) — VBA_con and HBA_con are otherwise both just display
     metrics, and the contact POSITION is correct regardless.
Verdict: show-ready (Brodie: "positions reasonable for LHH"). Refinements = future.

**STATUS 2026-06-19 (⭐ BLOCKER RESOLVED — GC2 Swing Factors Explainer in hand):**
Zac supplied GC2's official Swing Factors doc (data-ref §L, source of truth). It
**resolves Q1/Q2** and shows the shipped `build_arc` is wrong at the root.

Honest map of the tool (what's true vs not):

| Part | Status |
|---|---|
| XYZ frame (plate origin, +Y pitcher, +Z up) | ✅ real (cross-checked) |
| Contact anchor (`bat_con`) | ✅ fine — hygiene, not the blocker |
| Curvature radii (`Km30…K45` = Rc per HBA) | ✅ measured, sane (matches GC2's Rc table) |
| Bat at contact + derived hands | ✅ defensible (Brodie 28″) |
| Swing plane orientation | ✅ **NOW KNOWN** — `loft` (pitcher view) + `tilt` (hitter view) GIVE it; stop SVD-fitting/guessing |
| Station↔contact mapping | ❌→✅ **FIXED IN UNDERSTANDING:** stations are **HBA**, `0°` = pitcher-face NOT contact; contact = `HBA_con` inside the window |
| Shipped `build_arc` | ❌ **wrong** — anchors `0°`↔contact + guesses the plane; needs the §L8 rewrite |
| Anything beyond HBA window | ❌ outside [−30°,+45°] is not described by Swing Shapes |

**Why the churn happened (now provable):** I anchored station 0 at contact (it's
pitcher-face) and SVD-guessed the plane + bend sign (GC2 gives it via loft/tilt).
Every sign-flip was tuning the wrong model.

**CURVATURE TRUE-ARC = FUTURE ADD (deferred, Zac direction 2026-06-19).** The
`build_arc` rewrite is NOT being built now — it's a planned future addition pulling
the curvature reconstruction from GC2. Do not treat it as this-week's work. The
shipped arc stays as-is (known-wrong) until the future curvature pass; nothing
about the 3D arc / its PNGs has changed — the GC2 doc is captured, not wired in.

**FUTURE recipe (§L8), when we build it:** (1) parameterize by HBA −30→+45,
(2) integrate Rc=1/Km, (3) orient the plane by loft+tilt, (4) anchor contact at
`HBA_con`. **`HBA_con` is NOT a stored column — it is COMPUTED from `e1con`**
(`DEGREES(ATN2(e1y,e1x))` RHB / flip e1x LHB), exactly like `vba_con`/`aa_con` we
already ship (corrects an earlier wrong "confirm the column exists" note). Savant
tilt/AA/swing-length = validation, not the decode. Build offline in
`swing_path_true_arc.py` + render-and-look before touching the app.

**SHIPPED 2026-06-19 (separate from the arc):** HBA at contact (`hba_con`) added as
a METRIC next to `vba_con` across the affiliate tracker (engine + page + pins-shim),
postgame data parity, and a postgame Visuals heatmap option. Re-pin needed for live.
This is a table/number rollout — it did NOT touch the 3D arc.

**OPEN / FUTURE:** curvature true-arc (above); **Visuals page formatting + display
cleanup** (Zac flagged 2026-06-19 — layout/formatting fixups coming, scope later);
revamp the Visuals page; cherries (Measurements + `Swing_Damage_Windows`); PDF version.

**STATUS 2026-06-17 (superseded by 06-19):** `build_arc` was the contact-anchored
curvature reconstruction (tangent=`batv_con`, bend-toward-hands). Avg arc from
averaged inputs; straight bat on `head_con` (28″); Showing A = every swing. This is
the model §L proved wrong (anchored 0°↔contact, guessed plane).

**STATUS 2026-06-16:** Goal confirmed = 3D swing arc *through contact*, in the
postgame app (PDFs later). First in-app slice SHIPPED for work-laptop testing:
`src/swing_path_data.py` (fetch + reconstruction + 3D Plotly figure + metric
table) wired into `pages/1_Postgame.py` Visuals tab (below the PoC section),
reactive to the sidebar scope, with an Average / Average+individual toggle.
Reconstruction = the contact-anchored `build_arc` (tune shape there). Remaining:
the 3-showings layout (B season-baseline / C per-year), arc-shape tuning from
Zac's in-app eyeball, then the PDF path. Original step list below.



1. **Data layer** (`barrelsville/src/swing_path_data.py`): per-swing fetch
   (snapshots + contact + swing_shapes) for a scope; reconstruct arc(s);
   per-scope averaging (A/B/C); metric-table builder.
2. **Single-swing decode prototype** (notebook/script) — plot one real swing's
   3 views from snapshots to confirm frame conventions BEFORE wiring scopes.
3. **Render layer** — 3-view projection + plate, ported from `swing-path`.
4. **Page wiring** — Visuals tab below spray chart; reactive to scope; 3
   showings + 3 tables.
5. **Experimental spline** behind a flag (non-prod).
6. **Cherries** (squared-up % / ideal-AA % / smash factor) — separate pass.
