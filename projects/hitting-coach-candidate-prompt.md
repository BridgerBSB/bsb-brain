---
type: project
domain: player-development
status: building
created: 2026-06-17
updated: 2026-06-17
feeds: astro-world
---

# Hitting Coach Candidate Prompt — Interview Deck Spec

Astros hitting-coach interview presentation. Mirrors the **arc** of the existing Pitching
Coach Candidate Prompt deck but is hitting-specific and structured differently. Built on
the [[pd-onboarding-curriculum]] spine (Modules 3/5/6/8/9 = the question arc).

**Voice rule (BLOCKING):** Astros principles only. **Never mention Driveline / HTKCH / any
source.** All vocabulary used (attack angle, hip-shoulder separation, blocked/random,
constraints-led, top-8th EV, smash factor) is industry-general and presented as ours.

**Anonymous hitter:** **Ethan Frey** — used WITHOUT revealing his name. Slides say "a hitter
in our system." His real swing video (multi-angle) + batted-ball data get dropped into the
placeholders. Until then, placeholders.

---

## What the example pitching deck does (the pattern we mirror)
1. **Title / framing scenario** — logo + a "you're hired, here's our weakness, what's your
   plan to fix it by 2026" hook + dashed separator.
2. **Delivery Audit** (text-only question) — "identify the 3–5 inefficiencies; plan to
   address; how you work with S&C/ATC/biomech; how you communicate to build buy-in."
3. **Multi-angle video grid** (2×2: 2 color game angles + 2 B&W mocap/side) with play
   buttons — the anonymous pitcher; pairs with the audit.
4. **Arsenal Optimization** — a data table (Pitch Type · Velo · Zone% · Stuff+ · Exec+ ·
   xwOBAcon) + a multiple-choice next-step question (a/b/c/d) + "explain why."
5. **2024 vs 2025** — two videos + two break charts + "what changed / get the slider back /
   what missing info helps your process."
6. **Scaling / Staff Development** — scale a principle across affiliates with skeptical
   coaches; framework, alignment, accountability, cross-functional comms, success indicators.

---

## Layout conventions (match the screenshots)
- **Astros star logo top-left** (`pd-goals/assets/astros_logo.png`), ~0.9" square.
- **Slide title** centered at top, dark text.
- **Thin gray border box** framing the content area.
- **Dashed line** separator under a scenario paragraph.
- **Video tiles:** 2×2 grid, each a poster frame with a centered circular play button;
  label each tile with the angle (Side / CF-Behind / Overhead / Game).
- **Data tables:** navy header (`#002D62`) white text, alternating light-fill rows,
  orange (`#EB6E1F`) accents for highlights/percentile coloring.
- **Multiple-choice** answers bolded **a) b) c) d)**.
- White background; clean, lots of negative space (interview-room legibility).
- **Video format:** embedded MP4, click-to-play (PPTX native). Web/Astro World version
  later = same slides as HTML/reveal with `<video>` tags.

---

## Slide-by-slide structure (our arc)

### 1 — Title / Framing Scenario
- "**Hitting Coach Candidate Prompt**" + Astros logo + candidate name/date line.
- Scenario hook (pick one, data TBD): *"Last year our MiLB hitters ranked [X/30] in
  chase% and [Y/30] in damage on pitches in the heart. You're hired for this role next
  week — what is your plan and process to move us into the top tier in 2026?"*
- Dashed separator. (Parallels the pitching title slide.)

### 2 — Core Beliefs (general, no player)
- **"What would you rank as your 4 core hitting tenets, and in what order would you place
  their importance? Why?"**
- Follow-ups: *How do those tenets translate into a hitter's daily plan? Which is most
  trainable, and does that change where you start?*
- *(We listen for a coherent hierarchy + the trainability inversion — see Module 3.)*

### 3 — The Hitter (introduce Ethan Frey, anonymous) — VIDEO + DATA
- "Here is a hitter in our system. Multiple angles and his recent data."
- **2×2 video grid:** Side · CF/Behind · Overhead · Game. (Ethan Frey clips — placeholder.)
- A compact **data card** (our snapshot): Top-8th EV, Avg EV, Avg/HHB LA, Avg/HHB POC,
  Pull/Mid/Oppo, attack angle, spray mini-chart, pitch-location heatmap. **No name shown.**

### 4 — Swing Audit (the diagnostic) — pairs with Slide 3
- **"Identify the 3–5 most significant inefficiencies in this swing. Tie each to a phase
  of the swing (load / stride-launch / swing-impact)."**
- **"What does the ball-flight pattern tell you, and does it corroborate what you see on
  video?"**
- **"What is your plan to address them — drills, cues, training implements — and how do you
  sequence it (what first, what later)?"**
- **"How do you communicate these changes to the player to build buy-in? What language,
  cues, and progressions ensure he understands the *why* and owns the process?"**
- *(Filters: do they phase-anchor the flaw? external vs internal cues? do they pair
  ball-flight with what the body is doing? — Modules 5 & 6.)*

### 5 — Ball-Flight / Data Read (optimization decision)
- Show Ethan Frey's batted-ball detail (spray, EV×LA, POC, attack-angle, heatmap).
- **Multiple choice — "Which do you prioritize FIRST, and why?"**
  - **a)** change bat path / attack angle
  - **b)** raise bat speed / swing intent
  - **c)** shift swing decisions / approach
  - **d)** postural / sequencing change (separation, posture, GRF)
- **"What would you measure to know it's working, and over what window?"**
- *(Parallels Arsenal Optimization. Tests training economy + a measurable success gate.)*

### 6 — Read the Tape: Early vs Late (or 2024 vs 2025) — VIDEO + CHARTS
- Two videos side by side + two charts (attack-angle / POC / spray over time).
- **"What changed between these two windows? If the earlier version was better, what is
  your directive and how do you get it back? If later is better, how do you build on it?"**
- **"What missing information would help your process here?"**
- *(Parallels the 2024/2025 slider slide. Tests change-detection + humility about data.)*

### 7 — Approach / Game Plan
- Give an opposing pitcher's **arsenal · usage · location** (heatmaps).
- **"Build this hitter's plan against this pitcher. Which approach type fits him — zone,
  target, or guess — and why? What exactly do you show him, and how do you avoid
  information overload?"**
- *(Module 8. Tests distill-don't-dump + matching the visual to the hitter.)*

### 8 — Rapid-Fire Principles (the filter round) — optional, high-signal
Short questions that reveal whether they know the mechanics without us prompting:
- **"A hitter's measured attack angle jumps from ~2° to ~12° over two weeks, but you see no
  change on video. What's the most likely explanation before you credit a path change?"**
  *(contact-point/timing artifact — a strong filter.)*
- **"When do you reach for a heavier vs a lighter training bat — and is there a limit?"**
  *(the ~20% over/under transfer rule.)*
- **"A hitter can't pull the ball in the air. Walk me through your diagnostic tree."**
  *(horizontal bat angle / staying through / offset-closed drill.)*
- **"Internal vs external cues — when do you use each?"**
- **"How do you know a cage gain will actually transfer to the game?"** *(transfer/
  specificity, perception-action coupling.)*

### 9 — Scaling / Staff Development
- **"Imagine you identify a hitting principle that will materially improve results for the
  hitters in our system. After validating it with analysts and the biomechanics group, you
  believe it should become a system-wide teaching point. Your affiliates have hitting
  coaches of different backgrounds, levels of experience, and styles — some skeptical and
  slow to change. Walk me through how you would:"**
  - turn it into a clear, scalable, **teachable framework** any coach can apply consistently;
  - roll it out across affiliates, ensuring **alignment without micromanaging**;
  - create **accountability + feedback loops** to see whether it's being applied well;
  - **communicate progress + barriers** back to leadership and cross-functional groups
    (S&C, ATC, analytics).
- **"At the end of the season, what specific indicators tell you it was successfully scaled?"**
- *(Direct hitting-parallel of the pitching Scaling slide.)*

### 10 — Wrap / Reverse
- "What would you want from our analytics group to do this job well? What's the first thing
  you'd want to measure on a new hitter?"

---

## Build plan
- **Format:** PPTX (matches the example; native click-to-play video; portable for the room).
  Web/Astro World HTML version is a later mirror, same structure.
- **Assets needed from Zac:** Ethan Frey multi-angle MP4s + his batted-ball/swing data (work
  laptop / DB). Until then, build with labeled placeholder boxes.
- **Generator:** `pptx` skill; Astros logo from `pd-goals/assets/astros_logo.png`; navy
  `#002D62` / orange `#EB6E1F`.

## Related
- [[pd-onboarding-curriculum]] — the spine this is built on.
- Source notes (our reference only, never cited externally): [[big-3-hitting]] ·
  [[hitting-biomechanics]] · [[swing-flaws-programming]] · [[training-implements]] ·
  [[meta/skill-dev-principles]] · [[meta/org-training-process]]
