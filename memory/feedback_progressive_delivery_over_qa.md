---
name: feedback-progressive-delivery-over-qa
description: "When the user is happy with quality on Lesson 1 / Part 1 of a multi-part deliverable, keep building forward instead of over-QA'ing the early parts"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1d9bcdb0-fdf5-4bf4-a54a-da5f5a8226d1
---

When user gives positive signal on the FIRST deliverable of a multi-part series ("looks amazing", "love this"), pivot to building the NEXT part immediately. Don't burn time on additional QA passes of the part they already liked.

**Why:** May 26 2026 — user asked for an 11-lesson LLM curriculum. After shipping Lesson 1 (deck + PDF manual), I started dispatching multiple visual-QA subagents on what I'd already shipped instead of building Lesson 2. User interrupted with "the pdf actually looks amazing - i thought you were going to build section 2 and beyond?" — they wanted progressive delivery through all 11 lessons, not over-engineered QA on lesson 1.

**How to apply:**
- For multi-part educational series, build content first, ship progressively, do QA inline (spot-check 1-2 slides/pages per part, not full agent passes).
- When the user says "this looks great" / "love it" — that IS the QA signal. Move forward.
- Reserve full visual-QA subagent passes for the FIRST item to establish the template works, then trust the template on subsequent items.
- If the build pattern is "shared template + content swap," a single per-lesson spot-check of one content slide and one PDF page is sufficient — the template was already proven.
- Use SendUserFile with status="proactive" to ship each part as soon as it's built. Don't batch up at the end.

**See also:** the LLM curriculum project lived in `C:\Users\Owner\llm-lesson-1\` — used a `lessons/lesson_NN.json` content file + parameterized `build_deck.js` and `build_pdf_manual.py` builders. Pattern is reusable for future multi-part deliverables.
