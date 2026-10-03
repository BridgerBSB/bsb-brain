---
name: hitting-coach-interview-deck
description: "Hitting Coach Candidate Prompt interview deck + PD onboarding outline (Astro World), built Jun 17 2026"
metadata: 
  node_type: memory
  type: project
  originSessionId: 606ce92e-ca9c-4d17-9f03-2f93ddea7b10
---

**Hitting Coach Candidate Prompt** — Astros-branded interview presentation + the PD
onboarding outline it sits on. Brainstormed/built Jun 17 2026 to feed **Astro World**
(the internal PD learning platform — see [[astroworld-status]]).

**Voice rule (BLOCKING):** Astros principles only. The hitting substance is borrowed from
Driveline HTKCH (Big 3, biomechanics, swing flaws, training implements, motor learning)
but **Driveline is NEVER named** in any candidate/coach/player-facing artifact. The vault
concept notes carry source attribution for our reference only.

**Hitters:** Hitter 1 = Ethan Frey (174203), Hitter 2 = Drew Brutcher (130666). Names NEVER
shown on slides.

**VIDEOS DONE (Jun 18):** `build_videos.sh` (uses imageio ffmpeg v7.1 binary) splices the 20
clips/hitter from `~/Downloads/{frey_swings.zip, brutcher swings.zip}` into 2 angle MP4s each
(Angle 1 = non-`_side`, Angle 2 = `_side`). BOTH angles use ONE shared randomized swing order
so Angle1[k] == Angle2[k] swing (matched by swing number; build_hitter() in the script).
Normalized 960x540/30fps/no-audio/H264. Embedded as PLAYABLE media via pptxgenjs addMedia with
base64 poster `cover`. pptx ~53MB. NOTE the Brutcher zip also contains Frey clips → filter to
`brutcher*` only. NOTE: `cover` needs a `data:image/png;base64,` URI (file path errors).
DATA + VISUALS PLACED (Jun 18): Frey snapshot table = Avg EV 92.1 / 90th EV 108.7 / LA 10-30%
25.6% / Avg PoC -1.6 / AACon%(4-16) 70.0% (avg AA 7.5, 70/100 in band). PoC convention =
hit_initial_contact_point_y*12-17 (front-of-plate offset) per affiliate tracker tracker_data.py:943
(NOT _x, NOT from back tip). Query `frey_snapshot_query.sql` fixed + returns AA band counts.
Slide 3 also has Frey metrics strip (bottom row only: 92.1/8.3/74.1/7.4/68.8/78.5) bottom-center +
xwOBAcon zone bottom-left (label beside it). Slide 5 = Brutcher PoC+spray image
(assets/brutcher_ballflight.png, split+recombined to kill the middle gap) + larger w4.0 side-by-side
videos. Source screenshots cropped via PIL into assets/{frey_metrics_bottom,frey_xwobacon,
brutcher_ballflight}.png. STILL OPEN: Brutcher's table metrics (run his query 130666); enlarge
xwOBAcon if wanted; the other agent's hitter_analysis.py ball-flight page (handed off).
NOTE: user often has the .pptx open in PowerPoint -> EBUSY lock; build to OUT=_verify.pptx and
retry canonical (OUT env var supported in gen.js).

## What exists
- **Vault (`C:\Users\Owner\bsb-brain`):**
  - `projects/pd-onboarding-curriculum.md` — base-level outline spine (Modules 0–9:
    Orientation, LTAD ⚠GAP, Preparation, Key Tenets, Training Environments, Biomech
    Literacy, Compensations/Flaws & Drills, Metrics/Tech, Game Planning, Comms/Scaling).
    LTAD has NO backing note yet (`concepts/ltad.md` TODO) — the live gap-finder hit.
  - `projects/hitting-coach-candidate-prompt.md` — full deck spec (structure, layout
    conventions, the complete woven question set).
  - Source notes: `concepts/{big-3-hitting, hitting-biomechanics, swing-flaws-programming,
    training-implements}.md` + `meta/{skill-dev-principles, org-training-process}.md`.
- **Deck build (`C:\Users\Owner\hitting-coach-interview\`):**
  - `gen.js` (pptxgenjs generator) → `Hitting_Coach_Candidate_Prompt.pptx` (10 slides,
    LAYOUT_WIDE, navy #002D62 / orange #EB6E1F, logo from bsb-resources
    `pd-goals/assets/astros_logo.png`).
  - `export.ps1` — renders slides to `render/*.PNG` via PowerPoint COM (no LibreOffice on
    this machine; PowerShell tool unavailable — call `powershell.exe` full path from Bash:
    `/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe`).
  - All 10 slides render-QA'd clean (Jun 17).

## Deck arc — AS BUILT (9 slides, revised Jun 17; gen.js is source of truth)
1 Title/Framing · 2 Core Beliefs (4 tenets ranking) · 3 Hitter Snapshot "Hitter 1"
(Ethan Frey: 2 angles + table[Avg EV, 90th% EV, LA 10-30%, Avg PoC, AACon% 4-16] + PoC
heatmap) · 4 Ball Flight and Data (Hitter 1: prioritize a/b/c/d + measure) · 5 Hitter
Snapshot "Hitter 2" (Drew Brutcher: 2 angles + spray chart + "should this player adjust his
ball flight profile?") · 6 Building the Plan (build/communicate/work-with-S&C-ATC-sportssci-
analytics) · 7 Approach and Game Plan (Hitter 1 arsenal table) · 8 Principles (6 filter Qs) ·
9 Closing (logo + thank you).
APPROACH AND GAME PLAN slide SHELVED Jun 18 (liked, not needed for entry-level; concept kept in
gen.js comments for a future version) -> deck is now 8 slides: 1 Title, 2 Core Beliefs, 3 Frey
Snapshot, 4 Ball Flight and Data, 5 Brutcher Snapshot, 6 Building the Plan, 7 Principles, 8 Closing.
Sent to Sam for feedback Jun 18.
STYLE: NO em-dashes anywhere (user rule Jun 17). Scaling/Staff Development slide REMOVED
(shelved for a future non-entry-level version; content still in question-bank section G).
This is an ENTRY-LEVEL candidate questionnaire.

## OPEN / next
- Drop in Ethan Frey MP4s + data (work laptop); fill scenario numbers on slide 1 (chase/
  damage rank); fill the arsenal + snapshot tables.
- Optional web/HTML mirror for Astro World (same structure, `<video>` tags).
- Write `concepts/ltad.md` to close the curriculum gap.
- Loop layer (honest split): content = human-authored; looped = gap-finder, curation,
  lesson-draft maker-checker, Astro World export parity. See [[unified-pd-hub-vision]]?
  no — this is Astro World, distinct from the PD Engine hub.
