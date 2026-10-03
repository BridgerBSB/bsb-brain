---
title: LLM Explainer Video (AI Basics for Coaches)
date: 2026-09-30
status: active
tags: [llm-explainer, ai-literacy, project]
---

# LLM Explainer Video - AI Basics for Coaches

A narrated motion-graphics explainer (~5.5 min) on what LLMs are and how to use them. Primary audience: coaches who are total beginners, with other staff levels watching too. **Video first, then the same scenes as an interactive explainer page to present from.**

- Repo: `C:\Users\Owner\11labs-llm` (github.com/BridgerBSB/11labs-llm). Remotion (React -> MP4) + ElevenLabs voice. Runs on the personal laptop only.
- Research: [[llm-explainer-video-research]]
- Content roots: [[llm-curriculum-project]] (11-lesson series, `C:\Users\Owner\llm-lesson-1\`)

## Inspiration (captured 2026-09-30)

Claude's Opus 5.5 showcase thread: https://x.com/claudeai/status/2103515655760982273 (fxtwitter: https://api.fxtwitter.com/claudeai/status/2103515655760982273). Zac fed it as 8 phone screenshots. What he saw in them:
- @shneural: a 15-second "motion reel" showreel with an orange and white particle spiral and corner HUD telemetry (timecode, FPS, resolution). **Used for the cold open, the outro and the dark scenes.**
- @RyanSael: an interactive "Plane of Focus" lens lab (https://lens.lab.sael.net), built in one shot in 1h26m for $25.66. Teaches by letting you move one control and watch the effect.
- Three.js scenes: a clear stream (water and light on a riverbed), and Osaka Castle built in the browser and then in Blender.
- @techartist_: "Architect's Model", which stages a build as sketch -> massing -> detail -> built reality with a bottom scrubber. **Used for the Build scene and the chapter scrubber.**
- @victormustar: a pixel-art galloping horse, one HTML file, Canvas 2D, no images.
- @redp314: a 3D dental CBCT viewer built with Claude Code from 800 DICOM files.
- @scheemunai: a room planner to see whether a new bed fits.

The common thread is that everything is drawn in code, one idea gets animated at a time, and builds happen in stages.

## Structure (7 chapters, 9 scenes)

1. The Basics: it reads (spring training), then predicts the next word. A scouting-report line with the end torn off, with odds bars for the next pitch.
2. The Big Three: Claude / ChatGPT / Gemini are three clubs playing the same game. Pick one.
3. Ways to Use It: chat -> voice -> inside your tools -> agents (Claude Code). You keep the final say on send, spend and delete.
4. Context: a scouting report (generic vs specific answer), then a whiteboard with limited room where the oldest notes get erased. A new chat starts mostly blank.
5. Feedback: coach it like a player. A vague rep, one clear cue, then a specific rep.
6. Build Something: describe -> sketch -> build -> test + fix (architect-model homage).
7. Check Its Work: the infield fly rule, stated confidently and wrongly, then flipped to the real rule. You're the coach.

## Status

- 2026-09-30: v0 built. All 9 scenes render. Draft voice is Windows TTS. The full MP4 renders to `out/explainer.mp4`.
- NEXT: Zac reviews the draft, then either ElevenLabs Instant Voice Clone (needs an API key + voice ID) or Zac records his own takes. After that, the interactive page version.

- 2026-09-30: Slide deck "AI 101 for Coaches" built (16 slides, same look, narration in the speaker notes): https://claude.ai/artifact/FamN15Wy7bij6uMAWPg2Uj
- **The loop:** Zac marks up the deck -> the deck gets revised -> Zac records himself presenting it -> the video is revised to match the final deck (narrated in his ElevenLabs voice) -> the two are paired into the AI 101 class.

- 2026-10-01: The deck is a solid base (Zac's words) after 3 rounds: 17 slides. Cover > agenda > What is an LLM > Common LLMs (logos) > Domain Specialties x2 > Functionality > Use Cases > Prompting 101 + scenarios > Prompt Context + Prompt Inputs > Environments + Terminal > Environment Context + File Types > Summary. OPEN: Zac's real example after File Types; whether the dark "Prompt Context" slide stays; end-to-end project examples on Functionality; an advanced section (terminal setup, GitHub, files); then re-cut the video to match the deck.

## Decisions

- Audience = total beginners (coaches). Baseball analogies over the lesson series' kitchen/coffee ones.
- Brand-neutral on the big three: names and makers only, no rankings on screen.
- Voice: Zac wants his own voice. Plan is an ElevenLabs clone if it doesn't sound bad, otherwise he records the takes himself.
