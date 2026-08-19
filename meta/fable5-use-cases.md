# Fable 5 Use Cases — chase.h.ai carousel (Jul 2026)

**Source:** 5 Instagram screenshots Zac fed on 2026-07-02 (`IMG_8319–8323.PNG`,
Downloads). chase.h.ai 8-slide carousel, caption *"Comment 'Jarvis' to get my
exact Fable 5 OS setup."* Captured same week Zac switched this repo's Claude
Code sessions to **Claude Fable 5** (Mythos-class tier above Opus).

Five use cases, verbatim substance + how they map to OUR stack:

## 01 — Clone paid apps locally
> "Point Fable at an app like Whisper Flow, let it research the architecture,
> then run `/goal` — it rebuilds a private, local version that runs entirely on
> your machine."

- `/goal` is chase's own skill, NOT stock. Our equivalents: **GSD suite**
  (`/gsd:new-project` → roadmap → `/gsd:autonomous`) or brainstorm → plan → build.
- Precedent in our world: the [[indy-ball-scraper]] and Astro World builds —
  research-then-rebuild is already our pattern.

## 02 — Audit how you use Claude ⭐ (testing 2026-07-02)
> "Point Fable at your Claude Code history and it does a full teardown with
> sub-agents — clustering where you keep hitting friction, then turning it into
> new skills, automations, and CLAUDE.md upgrades."

Prompt from the slide: *"Audit my recent Claude Code sessions with sub-agents.
Cluster where I keep hitting friction, then propose new skills, automations,
and CLAUDE.md fixes."*

- Our transcripts: `C:\Users\Owner\.claude\projects\<per-worktree dirs>\*.jsonl`.
- Output should feed `.claude/rules/` + the skill library, same graduation
  pipeline as [[skill-dev-principles]].

## 03 — Build a visual agentic OS ⭐ (testing 2026-07-02)
> "Wrap Claude Code in a clickable dashboard — codify daily work into one-click
> skills, with metrics the terminal can't show. Here's mine, wired to Obsidian."

Slide shows his "V.A.U.L.T." dashboard: follower/output metrics, directives
list, command deck of one-click skills (metrics pull / inbox brief / trend scan
/ plan today / review / vault clean), schedule, audio I/O, AI wire feed.

- We already have the substrate: BSB Brain vault + `/brief` `/today` `/log`
  `/sunday` `/drift` skills + Command-Center.md. The dashboard is a thin
  clickable layer over what exists. See [[Command-Center]], [[advisory-council]].

## 04 — The best model for bug hunts
> "Bug-finding is where Fable 5 pulls ahead — the highest recall and precision
> of any Claude model. It surfaces real bugs, not nitpicks, catches
> intermittent flakes, and holds a whole large codebase in its 1M-token context."

Prompt from the slide: *"Hunt this codebase for real bugs. Fan out parallel
reviewers, adversarially verify each finding, then rank by severity with a fix
plan."*

- Maps 1:1 to Claude Code's **Workflow** tool (parallel finders → adversarial
  verify votes → severity ranking). Candidate targets: `pd-goals/`, Arm Farm,
  Barrelsville before redeploys. Same shape as the "verification agent assumes
  it's broken" pattern in [[loop-engineering]].

## 05 — Ship from a single PRD
> "Hand Fable a detailed PRD and let it run long. One open-source build: a 3D
> browser game in three.js, generated autonomously from a single spec."

- Ours: `/gsd:autonomous` or a long Workflow run. Requires the PRD up front —
  pairs with the PRD-template idea in the PM-skills capture in [[context-library]].

## Status
- **2026-07-02:** testing 02 (session audit) + 03 (visual dashboard) live in the
  bsb-resources Fable session. 01/04/05 parked for future runs.
- Video slides (1–2, 8) unreviewed — only the 5 use-case slides were captured.

Related: [[context-library]] · [[loop-engineering]] · [[advisory-council]] ·
[[skill-dev-principles]] · [[claude-code-obsidian]]
