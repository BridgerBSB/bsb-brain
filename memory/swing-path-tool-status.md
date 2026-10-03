---
name: swing-path-tool-status
description: "Swing-path 3D visual (hitter postgame) — status, data findings, reconstruction approach, open questions"
metadata: 
  node_type: memory
  type: project
  originSessionId: 317a8b14-8cf0-4464-8314-be20e62aeb50
---

**Swing Path 3D — hitter postgame Visuals tab.** Goal (locked Jun 16 2026):
map the bat swing **arc through contact in 3D, in the app** (PDFs later). Savant-
style swing-path look. On `feature/barrelsville` (`bsb-wt-hitting/barrelsville`).

**⭐ LATEST — Jun 19 2026: BLOCKER RESOLVED. Zac supplied GC2's official "Swing
Factors Explainer" (now authoritative in data-ref §L + figures `assets/swing-factors/`;
commit on `feature/barrelsville`).** It proves the shipped `build_arc` is **wrong at
the root** and gives the real recipe:
- **The `Km30…K45` stations are HBA (Horizontal Bat Angle) degrees; window = HBA
  [−30°,+45°]. `K0` = HBA 0° = "pitcher face" (bat ∥ plate front), NOT contact.**
  Contact happens at **`HBA_con`** *inside* the window, varies per swing. Our code
  anchored station 0 ↔ contact = wrong.
- **The swing plane is GIVEN by `loft` (angle vs ground seen by pitcher) + `tilt`
  (seen by hitter).** Our SVD-fit-to-dots plane + "bend toward hands"/"concave-up"
  sign heuristics reinvented data GC2 hands us → that's what caused every sign-flip
  churn. Drop them; use loft/tilt. `plane_p0/1/2` (Q2) no longer needed.
- **Curve = sweet-spot trajectory** (sweet spot = 6″ below head); **Rc = 1/Km** at
  each HBA station — GC2's Rc table is identical in form to ours (radii were right;
  *placement* was wrong).
- **Corrected recipe (data-ref §L8):** param by HBA −30→+45 → integrate Rc=1/Km →
  orient plane by loft+tilt → anchor contact at `HBA_con`. `batv_con` = tangent AT
  `HBA_con` (validation, not station-0 anchor). Savant tilt/AA/swing-length = now
  *validation*, not the decode.
- **CURVATURE TRUE-ARC = FUTURE ADD (deferred, Zac 2026-06-19). NOT building it now.**
  When we do: rewrite `build_arc` per §L8. `HBA_con` is **COMPUTED from e1con**
  (`DEGREES(ATN2(e1y,e1x))` RHB / flip e1x LHB), NOT a stored column — already in
  `swing_path_data.py` + `tracker_data._HBA_QUERY` (my earlier "confirm the column"
  ask was wrong). Q1 ✅ RESOLVED / Q2 ✅ MOOT / Q5 definitions ✅ (data-ref §G).
- **The 3D arc / its PNGs are UNCHANGED** — GC2 doc is captured + documented, NOT
  wired into the visual. Shipped arc stays known-wrong until the future curvature pass.
- **SHIPPED 2026-06-19 (separate from the arc): `hba_con` (HBA at contact) as a METRIC**
  next to `vba_con` across the Barrelsville affiliate tracker (LEADERBOARD_COLS,
  tooltip, `_HBA_QUERY`, pool.submit, merge, stale-pin shim, pitch_weighted rollup,
  monthly/weekly SCV + agg loops), page (`_PITCH_WEIGHTED_KEYS` + org enrich),
  `postgame_data.py` 3 SQL sites + coerce list, and a `1_Postgame.py` HBA heatmap
  option (range to tune). Handedness-flipped (LHB) — unlike vba_con. **Re-pin needed
  on work laptop for live tracker; KPI-weekly left out (only carries aa_con).**
- **FUTURE TODO (Zac flagged 2026-06-19): Visuals page formatting + display cleanup**
  (layout/formatting fixups, scope later) + the curvature true-arc + cherries + PDF.

**⭐ hitter_analysis.py PDF — Swing Path page (Jun 21 2026, `feature/barrelsville`,
UNTESTED on work laptop).** New **3D Swing Path page = P6** (avg bat path season-1
orange vs season navy, reconstructed via `swing_path_data`, + the app metric table:
Bat Speed/Swing Len/Path Tilt/AACon/VBACon/HBACon as prev-vs-cur cols). **Ball-Flight
(contact-point) page → P7 (now last).** Switch hitters: Swing Path page **doubled vs
RHP/vs LHP** (split by `pitcher_throws`), and **P2 drops xwOBAcon** (AA+LA only).
New funcs in hitter_analysis.py: `_render_metric_table`, `_draw_swing_path_panel`,
`_draw_swing_path_page`; wired before the contact-point block; `total_pages` +1 (7
dual / 6 single). Added `pitcher_throws` to `swing_path_data._SWINGS_SQL`. **Renderer
VERIFIED on synthetic data (single + switch PNGs render clean).** Runs on work laptop
(adds per-hitter `get_swings_for_season(gc_id,[season-1,season])` fetch).
**#5 DONE Jun 21 2026 (switch-hitter hand-split, `/goal` execute). Riley Unroe = gc
4773, MLBAM 373316, SS/INF AAA, BATS S (switch) — the test target.** Switch hitters
(bats=='S') now hand-split (vs RHP/vs LHP); ONE-SIDED hitters BYTE-IDENTICAL
(xwOBAcon STAYS on their P2 — `_draw_metric_zone_page` 3-col width math unchanged):
- **P2 AA/LA:** 2 rows (vs RHP/vs LHP) × 4 cols (AA, LA each × 2 seasons), NO xwOBAcon.
- **P3 EV/Whiff:** same 2×4 hand grid.
- **Swing/Contact:** dual = 4 pages ({Swing,Contact}×{vsRHP,vsLHP}); single = 2 (per hand).
- **Swing Path** page (3D arc + metric table) + **Ball-Flight LAST**, reformatted for
  switch = 2 rows (PoC/Spray) × 4 cols (vs RHP/LHP × season).
- **Page count dynamic** (switch dual = **9 pages**); `_entry_page_count` helper.
- Metric table: **Bat Speed now AT CONTACT** (|batv_con|, was peak); "Attack Angle @
  Contact/Downswing" → "AA @ …". Added `pitcher_throws` to `_SWINGS_SQL`.
- Helpers: `_hand_df`/`_hand_grid_rows`/`_hand_grid_cols` (loop closures),
  `_draw_swing_path_page`/`_draw_swing_path_panel`/`_render_metric_table`,
  `_draw_contact_point_page_switch`. Adaptive `col_w` for 4-col grids.
**VERIFIED via synthetic renders:** swing-path page (single+switch), 2×4 zone grid,
2×4 ball-flight — all clean, row labels show, non-switch math unchanged. **Zone-cell
CONTENT with real hand-filtered data + the whole 9-page PDF need a work-laptop run on
Riley 4773 (DB).** Commits on `feature/barrelsville` this session.
**Jun 21 FINAL — PDF swing-path CAMERA settled = "D": `view_init(elev=26, azim=-6)`
+ X box-aspect widened ~2.2x (`_wide[0]*=2.2`), FAN REMOVED (avg lines only).**
Iteration history (so we don't relitigate): catcher-cam(elev14/az-80) read edge-on;
side-view(az±90) was wrong; app-cam+fan matched 643 but Zac didn't want the fan.
Final = opposite side of plate, slightly elevated, wide -> swing reads as a bowl/U
opening up, plate flat front-bottom. Tune point = the `view_init`/`_wide[0]` lines in
`_draw_swing_path_panel`. Preview saved `Downloads/swingpath_D_final.png`.

**Jun 21 (cont.) — APP doubled by side + PDF camera + plate.** (1) **APP** Postgame
Visuals Swing Path now DOUBLES by side for switch hitters: the selected view
(A Individual / B Selected-vs-Season / C Year-avgs) renders once per side (vs RHP /
vs LHP, `st.columns(2)`), each with its OWN avg + season baseline + year avgs +
metric table (`build_showings` on `pitcher_throws`-filtered swings). Switch detected
by `_sw["bat_side"]` having both L+R. One-sided unchanged. (2) **PDF panel now app-like:**
home plate pentagon (z=0) + strike zone added; **equal DATA aspect** (`set_box_aspect`)
so the bat is the same proportion as the app; bat uses app 28in/6in constants.
(3) **PDF camera** = opposite-box aerial SIDE view (azim ±90 flipped by swing's X
side, elev 18) so the arc curve/angles read (was edge-on catcher's-eye). Metric-table
label column widened so "Bat Speed (mph)"/"AA @ Contact (deg)" don't clip. Bat speed
now AT CONTACT. All render-verified synthetically; **real eyeball on Riley 4773 next.**
**STILL OPEN (Zac deferred, "talk more in a bit"): swing-path page SPACING/visual
fine-tuning.** Plus future curvature true-arc (§L8).

**SHIPPED (untested on work laptop):** in-app first slice — `src/swing_path_data.py`
(fetch + reconstruction + 3D Plotly figure + metric table) wired into
`pages/1_Postgame.py` Visuals tab below the PoC section, reactive to sidebar,
Average / Average+individual toggle + contact bat. Registered in `manifest.json`.
Commit `25498a85`. **Needs: work-laptop redeploy + Zac's in-app eyeball on arc shape.**

**Reconstruction (tune in `build_arc`):** contact-anchored swing-ZONE arc. Anchor =
measured contact point (`batx/y/z_con`); leaves along measured contact velocity
`batv_con` (= attack angle + horizontal sweep); swing plane = `batv_con × e1_con`;
curvature from contact-station `K0` (radius 1/K0); drawn ~3.5 ft back + 0.5 ft
follow-through. Display-choice bits (NOT measured): the ~4 ft extent + constant
curvature. It's the swing-ZONE arc, NOT full load→contact (snapshots can't give
the early swing).

**KEY DATA FINDINGS (discovery `sql-queries/swing-path-discovery.sql`, results
in Zac's b*.tsv; full catalog in `barrelsville/docs/plans/2026-06-15-swing-path-data-reference.md`):**
- Frame = plate-origin FEET, +Y to pitcher, +Z up; vel ft/s; mph = v×0.681818.
- `Astros.Bat_Tracking_Metrics` (~90-99% MLB→A): 4 phase snapshots
  (activation/pitcher_face/true_peak/peak) — but they **straddle contact within
  ~10 ms** (NOT the downswing), so they map only the contact zone. Each has
  x/y/z, v, yaw, roll, distance (=swing length proxy ~7.8 ft), + adj_aa/adj_vba_pitcher_face.
- `tracking.Swing_Contact_Values` (~50-80%): contact frame — bat{x,y,z}_con,
  batv*_con, e1*_con (bat long-axis unit vec), head_con (2nd pt), ball_con.
  GC2-canonical contact angles: AA=asin(batvz/|batv|); VBA=90-acos(e1z); HBA=atan2(e1y,e1x) (flip x for LHB).
- `tracking.Swing_Shapes` (~50-80%): EXACTLY 14 cols = Km30/Km15/K0/K15/K30/K45
  (curvature 1/ft; radius=1/Kx), x0/y0/z0, plane_p0/1/2, loft, tilt. The whole
  arc-shape descriptor. **NO per-frame bat table exists.** Hands: measured at
  contact (sweet + e1 → 28/6 split); per-phase orientation only; no continuous track.
- Coverage affiliate-wide (MLB→A solid, FCL usable, DSL/amateur sparse).

**3 showings SHIPPED** (A selected / B selected-avg-vs-season / C per-year, big box
+ A/B/C selector, catcher's-eye cam). Bat now drawn from MEASURED points only
(head_con→bat_con at avg PoC, no derived 28in knob) — commit `adc68369`.

**KEY FINDING Jun 16 2026 (reframes the decode):** read the captured GC2 prod
queries (`sql-queries/Player Hitting Tracking - Top Table.sql` +
`Daily Swing Tracking.sql`). **GC2 NEVER 3D-reconstructs the swing path** — it uses
`Km30…K45` only as scalar per-station radii (`SwingRadius{X}deg = 1/Kx`), `loft`/
`tilt` as scalar plane angles; NO station→3D mapping, NO `plane_p0/1/2` use, NO
`x0/y0/z0` anchor logic. So Q1–Q3 are not a recipe to look up — "decode the whole
path" = BUILD a curvature-integration model (Km* through loft/tilt plane, anchored
x0/y0/z0) + validate near-contact vs measured points. Per-station sanity bands +
EV/Barrel/Damage sources now in data-ref §G2. Commit `2103b9e2`.

**BLOCKER: decode needs a work-laptop data pull — nothing local substitutes.** All
b1–b9 TSVs in Downloads are schema/coverage dumps (zero real swing rows); prototype
numeric output never returned here. Statcast CSV
(`swing-path/catcher-interference-app/data/bat-tracking-swing-path (2).csv`) is a
season AGGREGATE (per-MLB-hitter bat speed/tilt/attack angle) — good for a Q5/Q6
metric cross-check, NOT path coords.

**Jun 16 2026 — biomech/skeleton data characterized (Zac: "there are skeletons for
GC2"). Full in-depth doc: `barrelsville/docs/plans/2026-06-16-biomech-measurements-schema-reference.md`;
swing-path data-ref §I (corrected §I4). Schema rule: `tracking-schema.md` §5b.**
Two EAV stores in `groundcontroltracking.Tracking.*`:
- `Biomechanics_Tracking` (`sched_id,pitch_id,metric_id,groundcontrol_id,value`),
  joins Pitches_View on (sched_id,pitch_id), 2 rows/metric → filter gc_id=batter_id;
  564 metrics via `LK_Biomechanics_Metrics_Types` (`4q.tsv`).
- `Measurements` (per-play EAV, `measurement_id`→`LK_Measurement_Types` 996 rows;
  target_id 0=play,1=P,2=C,3-9=fielders,10=batter,11+=runners).

**REALITY CHECK (§7 pivot, Justin Thomas 170147 = MiLB): the exciting `wrist`/`elbow`
3D joints + `pc1/2/3` swing-plane are NULL for prospects — POSE-tracked = MLB-ONLY.**
So for MiLB: hands STAY derived (head→bat dir + length); plane STAYS modeled;
`bat_ss`/`bat_head`/`bat_velo_unit` just duplicate Swing_Contact_Values (no new geom).
No raw per-frame skeleton exposed anywhere (only derived metrics + completeness %).
**Real new win = `Measurements` cherries (target_id=10): EV=11, Attack Angle=942,
Bat Speed=943, Swing Length=974, Percent Squared Up=984, Dist-from-Sweet-Spot=963,
Barreled=108, Hit Trajectory JSON=109** → build cherries after the arc (verify level
coverage first). `LK_Joint_Types`=29-joint pose model (positions feed Biomech, MLB-only).

**DUMP DECODED Jun 16 2026 (`swing_dump_170147.tsv`, 5 swings + 3 PNGs; data-ref §J):**
(1) `head_con` = ball-IMPACT point NOT barrel tip (||head−bat||=con_loc_axis); (2)
**(+e1_con)=barrel CONFIRMED** → hands=bat_con−28in·e1, barrel=+6in·e1 — bat reverted
to e1 axis (commit fix; my head→bat change was wrong). Hands now correct, match PNGs.
(3) snapshots = ±20ms window around contact (load/downswing NOT measured); (4)
Swing_Shapes radii sane but station→frame map unvalidatable from these points →
**full backswing arc is inherently a MODEL; no DB pull fixes it.** Through-contact
arc + correct hands = the defensible visual (what Zac liked). Dump archived at
`barrelsville/scripts/exploration/output/swing_dump_170147.tsv`.
**POSE HUNT DEFINITIVE Jun 16 2026 (qu1/qu2/qu2b/qu31/qu4/qu5; data-ref §K):
the full per-frame batter skeleton EXISTS but is a Hawkeye BLOB, NOT queryable SQL.**
`Blob_Upload_Log` (qu31) = proof: uploads typed ball/bat/player/**biomech**
(`body29`=29-joint skeleton) → raw pose in blob files, GC2 renders from them. No
pose table/column/measurement in SQL (only "Batter Biomechanics" bool + "Pose
Completeness %"); only per-frame JSON for batter = ball Hit Trajectory (id 109).
Summary wrist exists for a few plays but NULL for CJ + non-plate frame (y≈54) =
unusable. **So SQL ceiling = through-contact bat arc + derived hands + ball path
(all real). Full skeleton needs a BLOB/object-store access track (IT/Hawkeye) — a
separate project, not a query.** Decision: (a) ship SQL-ceiling visual, or (b) open
blob-access track.
**BREAKTHROUGH Jun 16-17 2026 — TRUE ARC from the curvature profile, VALIDATED.**
Zac (correctly) pushed: the current app arc was a lazy K0-only PARABOLA that ignored
Km30/Km15/K15/K30/K45 + plane + the dots. New offline reconstruction
`scripts/exploration/swing_path_true_arc.py` (runs on local dump, NO DB): integrate
measured curvature across stations -30..+45deg → arc; orient with measured swing
plane (SVD-fit to the dots, fallback batv×e1); anchor station-0 at measured contact
+ contact tangent; pick orientation (4 sign combos) that best matches the measured
snapshot dots. **RESULT: clean swings land 0.03-0.30 ft from the dots (arc THREADS
activation→contact→peak); junk foul-tip 184 = 0.82 ft (correctly worst).** PNGs in
Downloads `true_arc_*.png` + repo output/. THIS is the real swing arc.
**STATE Jun 17 2026 (app `swing_path_data.py` + `1_Postgame.py`, feature/barrelsville;
Zac redeploys to verify):** TRUE arc IS in app `build_arc` (replaced K0 parabola):
integrate measured curvature Km30..K45 (swing_shapes / batrotation endpoint), ANCHORED
at measured contact with tangent=batv_con (can't flip), bend toward the HANDS (center
of curvature ~= hands, radius 1/Kx ~= bat+arms; AA-independent -- AA is tangent slope,
separate from curvature). Junk swings (foul-tip, |e1|!=1, fit-miss>0.5ft, no curvature)
-> None -> dropped. AVG arc = built from AVERAGED inputs (df.mean) = full-size (NOT
averaging output arcs). Bat = STRAIGHT hands->sweet->head on e1, anchored at head_con
(Brodie ~27.5in from head), snapped onto arc (kink 0, gap 0). Showing A = EVERY selected
swing (uncapped); B = sel-avg vs season; C = per-year avg. View = st.tabs (radio
reverted per Zac; keep-subpage rule deleted). Both biomechs (Moore, Brodie) confirmed
swing_shapes(+swing_contact_values) canonical; e1=unit bat-orientation; head_con=head@contact;
"contact"=contact OR nearest-pass on whiff. (data-ref Q4/G2/I-K.)

**OPEN / NEXT:** (1) **SUPERSEDED by the Jun 19 LATEST block** — the "skeptical /
eyeball / suspect plane-normal sign" item was the symptom; root cause now known
(anchored 0°↔contact + guessed plane). Real next step = the §L8 `build_arc` rewrite
(HBA param + loft/tilt plane + `HBA_con` anchor). (2) REVAMP the whole Visuals page (Zac wants it -- scope
next session). (3) Cherries (Measurements target_id=10: squared-up%=984/swing-len=974/
bat-speed=943/attack-angle=942/EV=11 + damage_window via Swing_Damage_Windows). (4) PDF
(matplotlib matching app). Discovery SQLs READY for work laptop: `damage-window-discovery.sql`,
`swing-shapes-contact-peek.sql`. Synced to Obsidian brain Jun 17.

(superseded) earlier unblock — Zac runs on work laptop & sends back: (a) skeleton-discovery
**§7** (`skel7.tsv`) = batter-filtered pivot of measured wrist/bat_head/bat_ss/
bat_velo_unit/pc1-3/contact-angles for ~8 swings → I verify units+orientation vs
plate frame, then wire `swing_path_data.py` to draw REAL hands (`wrist`) + REAL plane
(`pc1/2/3`) — DON'T wire the EAV pivot blind; (b) skeleton-discovery **§6**
(`skel6_*.tsv`) = `Measurements` per-frame check (if it's per-timestamp joint/bat XYZ
→ draw the real full path, no arc model needed); (c) `swing_path_decode_prototype.py
--batter-id 170147 --n 5` → `output/swing_dump_170147.tsv` (Swing_Shapes Km* for
curvature). With §7 + swing_dump I fit the geometry and upgrade `build_arc` from the
constant-K0 curl to measured plane + curvature. THEN: Savant cross-check (pull our agg
bat-speed/tilt/AA for MLB hitters in the Statcast CSV → Q5/Q6), then PDF, then
cherries (squared-up %, ideal-AA %, smash factor; EV = `pitch_hit_trajectories.hit_launch_speed`).
Design: `docs/plans/2026-06-15-swing-path-postgame-design.md`;
data-ref: `…-data-reference.md` §G2/§H. Build per [[feedback_run_locally_when_data_is_local]] (DB on work laptop only).
