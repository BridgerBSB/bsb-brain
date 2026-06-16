---
name: llm-curriculum-project
description: Pointer to the 11-lesson LLM Engineering Series staff curriculum (decks + PDFs) at C:\Users\Owner\llm-lesson-1\
metadata: 
  node_type: memory
  type: project
  originSessionId: 1d9bcdb0-fdf5-4bf4-a54a-da5f5a8226d1
---

The user built a full **11-lesson LLM Engineering Series** at
`C:\Users\Owner\llm-lesson-1\` on 2026-05-26. Each lesson ships as both a
PPTX deck (for live presentation) and a PDF manual (for staff self-study).

**When the user mentions "the LLM lessons" / "the curriculum" / "presenting on
AI to staff" / "Lesson N" — they mean this project.** Don't confuse with the
baseball codebase at `C:\Users\Owner\bsb-resources\`.

**Why:** They intend to come back later and present this material to staff.
Asked for a README documenting structure + rebuild commands.

**Audience profile** (locked 2026-05-26): **non-technical staff who've started
out "vibe coding"** — they've built things with Lovable / v0 / Cursor / Bolt /
ChatGPT / Claude / etc. but don't have a CS background. Calibration target is
"smart non-engineer who has shipped stuff with AI." Calibrate analogies and
examples to that audience — NOT to engineers, NOT to total newcomers.

**Roadmap for v2 (explicitly NOT for v1):** the user already flagged that v1
ships clean but should be simplified further for the most non-technical end
of the vibe-coder audience. Full roadmap is in the README's "Roadmap" section.
TL;DR of next-iteration improvements:
1. Drop one more layer of jargon (some terms still creep in — "autoregressive",
   "PagedAttention", "logits", etc.)
2. Possibly add a "Lesson 0" for true beginners (no prior AI use).
3. Add vibe-coder-specific examples to every topic (e.g. "this is why your
   Lovable build truncates your prompt — token limit").
4. More live demos in place of text-heavy slides (tokenizer page, embeddings
   plot, latency stopwatch, agent demo).
5. Ship a one-page AI Vocab Cheat Sheet handout.
6. User-test Lesson 1 with 2-3 real staff before rolling out wider — highest
   leverage step.

**Don't do roadmap work unless the user explicitly says it's time for v2.**
The phrasing was "we will adjust this in the future ... but that's a step we
will not attack this second."

**How to apply:**

- For any update to a lesson's content, edit `lessons/lesson_NN.json` then run
  `node build_deck.js NN && python build_pdf_manual.py NN`.
- Full structure, design tokens, and build history live in
  `C:\Users\Owner\llm-lesson-1\README.md` — read that first if asked anything
  about the project.
- The 11 lessons + topic counts: L1 Foundations (11), L2 Datasets & Training (10),
  L3 Fine-Tuning (8), L4 Inference & Optimization (9), L5 Local AI Ecosystem (9),
  L6 RAG & Memory (6), L7 Agents & Workflows (8), L8 Model Types (6),
  L9 Deployment (5), L10 Evaluation (5), L11 Real-World Skills (7).
- Visual style: Ocean Gradient palette (navy / blue / teal / gold). 16:9 widescreen
  decks. US Letter portrait PDFs. Standard layout: numbered badge + title + WHAT IT IS
  panel + 2-col body (Analogy + Key Points / Mental Model + Common Mistake).
  PDFs add an Exercise callout per topic that the deck doesn't include.
- Build stack: pptxgenjs (Node.js) for decks, reportlab (Python) for PDFs.
  Both read from `lessons/lesson_NN.json` as the single source of truth.

**Suggested presentation cadence** (also in the README):
6 sessions × ~75 min, pairing lessons L1+L2, L3+L4, L5+L6, L7+L8, L9+L10, L11.

**Known fixes already applied** (don't re-introduce):
- `pres.width` returns `undefined` in this pptxgenjs version → hardcode `W = 13.333, H = 7.5`.
- TOC uses a 2-column `Table` (not inline `&nbsp;`) so item 10/11/12 align with 1–9.
- `KeepTogether` wraps Mistakes + Exercise so the Exercise callout never orphans.
- Every body text box has `valign: "top"` + `margin: 0`.
