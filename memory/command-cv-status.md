---
name: command-cv-status
description: "Command CV miss-distance tracker — CV glove vs Trackman actual, PoC built+pushed Jun 29 2026"
metadata: 
  node_type: memory
  type: project
  originSessionId: aa82e339-d969-4b13-ab31-7e74181fce55
---

**Command CV — computer-vision miss-distance / command tracker.** Recreating
Lucas Baquero's LinkedIn tool: quantify pitcher command = how far a pitch missed
the catcher's intended target. Lives at `command-cv/` on `feature/pd-goals`
(commit `5f15d5f8`, pushed Jun 29 2026). Standalone offline Python pipeline (NOT
Posit — Connect can't decode video).

**The core insight (decided, matches the source):** we do NOT track the ball in
video. CV finds ONLY the catcher's **glove** (intended target) on one frame.
**Actual** pitch location = **Trackman/Hawk-Eye plate_x/plate_z** (data, not CV).
Miss = vector between them, in inches + arm/glove + up/down. The LinkedIn text
confirms: "compared to a Trackman's tagged location."

**Built + tested PoC (stages 3-6 = the value engine):**
- `src/geometry.py` miss vector (inches, labels), `src/calibration.py` pure-NumPy
  DLT homography pixel→Trackman plate plane (round-trip tested to <0.25in),
  `src/report.py` Strike-Zone View (matplotlib, Astros navy/orange,
  render-and-look verified), `src/profile.py` per-pitcher command CSV,
  `src/pipeline.py` orchestrator, `src/detect.py` interface (ManualDetections
  backend + YoloDetector stub).
- **`src/ingest/statsapi.py` — LIVE-VERIFIED.** MLB/MiLB Stats API (no key):
  `statsapi.mlb.com/api/v1.1/game/{gamePk}/feed/live` → 261 tracked pitches for
  game 814841 (Colton Gordon) with pX/pZ, strikeZoneTop/Bottom, pitcher
  hand/name, pitch type, AND a `playId` GUID per pitch for video.
- 7 pytest passing. Design doc `command-cv/docs/2026-06-29-command-cv-miss-distance-design.md`.
- Demos: `scripts/render_synthetic_report.py`, `scripts/demo_statsapi_report.py 814841 0`,
  `scripts/synth_frame.py`. Outputs → `command-cv/output/` (gitignored).

**Provided-video path BUILT + tested end-to-end (Option 1 start):** `src/video.py`
(cv2 frame extract by idx/time), `scripts/clip_to_report.py` (clip+frame+coords+
Trackman → Strike-Zone View + reticle overlay + profile row; Trackman from Stats
API by game/playId OR manual), `scripts/annotate_clip.py` (click-to-annotate the
flash frame = also the labeling tool), `scripts/make_test_clip.py` (synthetic mp4
smoke). Verified: frame 20 → 20.3in arm-side/down. opencv-python-headless 4.13
installed/required. Commits through `5706a6f3`.

**API video boundary CONFIRMED (evidence):** free GUMBO `feed/live` (+`/timestamps`)
= no key, gives pX/pZ + playId. But `/api/v1/game/{gp}/guids`, `/{guid}/analytics`,
batTracking, skeletal all return **401 Unauthorized**; MiLB `/content` has no free
clip URL. So the playId→clip auto-fetch NEEDS the MLB key Brodie's API references
(`statsapi.mlb.com/api/v1/jobs/umpires`, `research.mlb.com`). Parallel track.

**Adam Brodie's video endpoint (Jul 1 2026, for reference):**
`statsapi.mlb.com/api/v1/game/{gamePK}/{guid}/analytics?hydrate=analytics(video)`
(example: game 824821, guid c4958213-a3d3-3ed2-96ef-d9fe6fcc798b). **PROBED Jul 1
→ HTTP 401, returns an Okta login page.** The `hydrate=analytics(video)` param does
NOT make it public — it's the same guid→analytics endpoint gated behind MLB internal
Okta SSO. This IS the canonical playId(guid)→video path; unlocking it = get the
authenticated session / key from Adam (his example works because he's SSO'd), not a
code trick. Confirms the boundary note above.

**Video automation scaffold BUILT (Jul 1 2026) — `src/ingest/video.py`.** Given a
game_pk it uses the public `fetch_game_pitches` (feed/live → every playId GUID) then
hits Brodie's `/analytics?hydrate=analytics(video)` per playId, extracts the .mp4 URL,
downloads to `data/clips/<pitcher>_<type>_<n>.mp4` (annotator-ready naming). Blocked on
ONE thing: **auth.** Re-probed all paths Jul 1 — Brodie's analytics endpoint = 401 Okta
even with browser UA; the ONLY public video is `game/{pk}/content` = ~40 curated
highlights (HR/condensed), NOT every pitch → can't replace the endpoint. So automation
needs Brodie's auth carried in: `MLB_STATS_COOKIE` or `MLB_STATS_BEARER` env (or
--cookie/--bearer). ASK BRODIE for a service token/API key (best) or an authenticated
statsapi cookie. `video.py --probe <guid>` dumps the raw JSON to pin the real video
schema (`extract_video_urls` currently walks the tree for any .mp4, schema-defensive)
once auth works. Compiles; fails loud with the exact ask when creds absent.

**CONTACT handling (decided Jul 1 2026):** On a pitch the batter makes CONTACT with
(BIP / foul / HBP) the catcher never cleanly receives it → **Method B (glove-at-catch
video) has NO valid catch frame → don't annotate catch on contact pitches.** Method A
(Trackman `plate_x/plate_z` actual vs glove-setup target) is UNAFFECTED — every pitch
has a tracked plate crossing point regardless of contact — so contact pitches get their
"actual" from DATA, not video. This is a core reason Method A is the production spine.
Command = intended(target) vs actual(location), independent of outcome, so a
well-located pitch that gets hit STILL counts as good command. Video annotation (Method
B) is limited to TAKES + WHIFFS + caught foul-tips (catcher receives the ball).

**"Mark Contact" button SHIPPED (Jul 1 2026)** — Zac's ask. annotate.html now has
"Lock CATCH (received)" + "Lock CONTACT (hit)"; both fill the actual-endpoint slot, tag
`endpoint_kind` = catch|contact. On a contact pitch Zac boxes the BALL where the bat
meets it (he can do this; Claude can't reliably) = where the ball ended up ≈ what a
catch would be. Miss math identical (setup→endpoint). Carried through ingest + methodb
(new `via` column, `endpoint_kind` in CSV, defaults "catch"). Use case Zac wants: a
"nuke" (crushed pitch) → annotate contact → see the command miss → "did that HR come off
a MISSED target or a good pitch he just hit?" = command-vs-damage, the money data. So we
DO annotate contact clips. `video.py --calls` filter added (default = pull everything).
Zac HAS credentials for the video endpoint now (provide as MLB_STATS_COOKIE/BEARER).

**DESIGN DECIDED (Jul 1 2026, after web research):** ONE metric = miss from target in
inches (arm/glove-side + up/down), measured two ways that agree where they overlap.
Intended target = **observed catcher glove at setup** (NOT modeled — this is our edge vs
the literature). Actual = **Trackman/Hawk-Eye plate crossing PRIMARY + training label**;
**CV fallback where no Trackman** (glove-at-catch for takes/whiffs, contact-point for
hits). Kill the "two sources is rough" worry by **calibrating the CV miss against
Trackman on pitches with both** → CV becomes the Trackman number reproduced from video,
extended to where Trackman is dark; show both when both exist (agreement = validation).
**Plane honesty (Zac's "multiple planes"):** Trackman=plate-front plane, glove-catch=
receive plane (behind plate), contact=in front — the ball breaks between them, so label
distinctly, don't silently mix. For command the target lives in the RECEIVE plane so
setup→catch is the purest self-consistent measure; glove-size depth-correction = v2 bridge.

**RESEARCH (Jul 1 2026):** (1) **BaseballCV** (open-source, github.com/BaseballCV/
BaseballCV) ships PRE-TRAINED `glove_tracking.pt` (YOLO) + `rfdetr_glove_tracking`
(RF-DETR, better) detecting catcher glove + ball + home plate + rubber, + a
`glove_framing_tracking.ipynb` that transposes glove coords to 2D. **Could kill the
train-a-glove-detector-from-scratch work — TEST IT on one clip first.** Caveat: trained on
BROADCAST/CF feeds; Ogando clips are side-cam → test transfer (and CF angle maps to the
plate plane cleaner anyway). (2) SOTA command metrics **Command+** and **xCTRL** (arXiv
2508.19184, "distance between actual and estimated intended location") both MODEL intent
probabilistically + use Trackman for actual. Our niche = OBSERVED glove target + a
CV path that works WITHOUT Trackman — a real gap nobody fills. (3) **Lokator** = physical
target training system (not CV). NEXT LEVER: test BaseballCV glove model on a clip.

**Ogando clips (Jun 29) → Method B added.** User supplied 12 GC2 clips
(`Downloads/CV Miss Distance Tracking.zip`: ogando cu/fc/ff/sl, 1280x720 30fps
~6s). They're a **down-the-line SIDE camera**, NOT center field → the Trackman/
plate-plane homography is weak on the horizontal axis. So built **Method B**
(`src/miss_methodb.py` + `src/glove_track.py` + `scripts/methodb_pitch.py`):
intended = mitt at SETUP frame, actual = mitt at CATCH frame, miss = displacement
scaled by mitt's real ~12" size (the user's "size of the glove" idea) — self-
contained, no Trackman, immune to oblique angle. Verified real: **Ogando FF#1 =
7.2in arm-side/up** off a low target (setup f88→catch f112). 11 tests pass.
Classical color+motion detector is NOISY (busy orange bg: fans/wall/Astros gear;
it locks onto the orange MASK CAGE not the mitt) → **trained YOLO mitt detector
is the next real step**; annotating the 12 clips gives real numbers + the label set.

**JUL 1 WORK COMMITTED + PUSHED (`7244e0d4`, Jul 2 2026):** browser annotator
(`tools/annotate.html` w/ Mark Contact), `scripts/ingest_annotation.py`,
`src/ingest/video.py`, methodb_batch endpoint_kind carry — all previously
uncommitted, now safe. All 12 Ogando clips extracted from
`Downloads/CV Miss Distance Tracking.zip` → `command-cv/data/clips/*.mp4`
(gitignored). Stale `data/annotations/ogando_ff.json` (pre-fix stem,
double-counted ff_1) DELETED → clean slate, annotating all 12 fresh.

**ANNOTATION TOOL SWITCHED to a browser annotator (Jul 1 2026).** The matplotlib
TkAgg `annotate_tool.py` GUI kept crashing / mis-clicking (the saved ogando_ff_1
box `cx850,cy510` was a TYPED guess, not a real click — Claude missed the mitt).
Root cause = the live GUI event loop, NOT the model (Fable 5 wouldn't fix it). New
path: **`command-cv/tools/annotate.html`** (open in Chrome, no install; loads the
mp4 via file-picker, scrub slider + ←/→ arrows, drag a box on the mitt, lock
Setup/Catch, Download JSON — same schema annotate_tool wrote) + **headless
`scripts/ingest_annotation.py <downloaded.json> --clip <mp4>`** (extracts the two
tagged frames via cv2, writes `data/annotations/<stem>.json` + YOLO samples — the
non-GUI half of annotate_tool.write, so nothing can crash). Drop-in: methodb_batch.py
+ train_yolo.py unchanged. annotate_tool.py kept but deprecated in favor of the browser.
Compile + imports (cv2 4.13, src.dataset) verified. Zac still does the actual clicking.
**FIRST REAL HUMAN ANNOTATION DONE (Jul 1 2026):** Zac browser-annotated ogando_ff_1
(setup f40 (852,497) 50×53 → catch f95 (896,555) 38×43, real drag-box coords) →
ingest → methodb_batch = **19.0in arm-side/down (11.5in arm-side, 15.1in down)**. The
old typed-guess ogando_ff_1 label (f88/f112, missed the mitt) was deleted from
data/annotations + YOLO. Naming-collision bug fixed: HTML now keeps the FULL clip stem
(ogando_ff_1, not ogando_ff) so the other 4 FF clips won't overwrite. NOTE: the one
existing annotation is stem "ogando_ff" (pre-fix); re-annotating gives "ogando_ff_1" —
delete the ogando_ff one if you want it clean. 11 clips left to annotate → train YOLO.

**Annotate→train→apply loop BUILT (Jun 29, through `59f97f60`):**
`scripts/annotate_tool.py` (interactive TkAgg: scrub a/d, click mitt center+edge,
`s`=setup `c`=catch `t`=Trackman entry `w`=write → pitch JSON + YOLO samples for
both frames), `src/dataset.py` (YOLO Box/save_sample/data.yaml), `scripts/
methodb_batch.py` (all annotations → `output/command_profile_b.csv` + per-pitch
table + per-pitcher rollup), `scripts/train_yolo.py` (Ultralytics scaffold, auto
val split), `scripts/contact_sheet.py` (pick setup/catch frames). Loop verified on
ogando_ff_1. `data/` is gitignored (local clip annotations + derived training imgs).
**Decided (industry standard, user agreed): Trackman/Hawk-Eye = actual (Method A
is the production spine); CV nails the SETTLED GLOVE target; Method B (video catch)
= no-DB fallback.** User will click-annotate the 12 clips → batch numbers → train YOLO.
Workflow cmds in `command-cv/README.md`. Ogando hand assumed R — confirm.

**OPEN / next:**
1. **Train the glove/plate/zone detector** (the "train our model" ask) — Ultralytics
   YOLO backend in `detect.py`; needs labeled MiLB frames scraped via the playId clips.
2. **playId → downloadable clip** — Film Room/MLB.tv entitlement is the uncertain
   feeder piece; statsapi gives the GUID, not the video file. May need an MLB key.
3. **VERIFY plate_x sign + arm-side/glove-side label** against ONE known DB pitch
   on the work laptop (flagged `# VERIFY` in geometry.py `_ARM_SIDE_X_SIGN`).
   Magnitude is exact; only the L/R word depends on it.
4. Glove parallax (~1.5-3ft behind plate) → reports labeled "approximate" (same
   limitation as the reference); optional v2 depth-correct via glove size.
5. Later: surface results in an Arm Farm tab (output CSV designed to be readable).

Goal was set via `/goal` Jun 29 2026 with the two LinkedIn screenshots
(`IMG_8281/8282.PNG`) + report mockups (`cv image.jpg`, `cv image creation.jpg`).
