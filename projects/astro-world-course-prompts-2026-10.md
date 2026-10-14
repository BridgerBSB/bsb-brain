---
type: research
status: captured
created: '2026-10-13'
project: Astro World / AstrosEDU courses
tags:
  - astroworld
  - astrosedu
  - courses
  - prompts
  - learning-design
---
# Learning prompts for building AstrosEDU courses (captured Oct 13 2026)

**What it is.** A 10-post X thread by @Rixhabh__ (Oct 3 2026, 166k views, 4.8k
bookmarks): "Claude can now teach you anything for free", 7 prompt patterns for
self-study. Posts 8-10 are a newsletter plug and a wrap; no substance there.
<https://x.com/Rixhabh__/status/2106415023354708293>. Post 1 has no prompts; they are in
the replies, recovered via `api.fxtwitter.com/2/thread/<id>`.

Zac's framing: "good prompts to keep down - we will have to create Astros courses for
Astro World, so taking this into account."

## The 7 prompts (verbatim)

1. **Zero-Level Foundation Builder.** "Act as a world-class teacher and subject-matter
   expert. Teach me the topic [insert topic] starting from absolute zero, assuming I have
   no background at all. Build my foundation step by step, define all terms clearly, use
   simple language, and ensure I fully understand the basics before moving forward."
2. **Complete Curriculum Architect.** "Design a complete learning curriculum for mastering
   [insert topic] from beginner to expert level. Break it into stages, explain what to
   learn at each stage, what skills I should gain, how to practice them, and how to know
   when I am ready to progress."
3. **Concept-by-Concept Deep Teaching.** "Teach me [insert topic] one core concept at a
   time. For each concept, explain it clearly, give real-world examples, show common
   mistakes, and ask me questions to confirm understanding before introducing the next
   concept."
4. **Personalized Tutor & Feedback.** "Act as my personal tutor for [insert topic]. Ask
   diagnostic questions to assess my understanding, adapt explanations based on my
   responses, correct my errors in detail, and continue teaching interactively until I
   demonstrate real competence."
5. **Mental Models & Expert Thinking.** "Teach me how experts think about [insert topic].
   Explain the mental models, frameworks, decision rules, and thought processes
   professionals use so I stop thinking like a beginner and start reasoning like an
   expert."
6. **Common Mistakes & Failure Prevention.** "Identify the most common mistakes people
   make when learning or applying [insert topic]. Explain why these mistakes happen, how
   they block progress, and exactly how I should avoid or correct them during my learning
   process."
7. **Examiner-Level Testing.** "Test my understanding of [insert topic] as a strict
   examiner would. Ask questions from basic to advanced level, evaluate my answers
   honestly, explain what I got wrong, and tell me precisely what to improve before moving
   forward."

## How they map onto an AstrosEDU course

The 7 are really the parts of one course, in build order:

| Course part | Prompt | AstrosEDU surface |
|---|---|---|
| Course outline + stage gates ("ready to progress when...") | 2 Curriculum Architect | the module list, like [[pd-onboarding-curriculum]] Modules 0-9 |
| Module 0 / glossary for a brand-new staffer | 1 Foundation Builder | orientation lesson; define every metric the way our canon defines it |
| One lesson per concept, each ending in check questions | 3 Concept-by-Concept | lesson pages + inline quiz items |
| "How our coordinators think" | 5 Mental Models | the decision rules: when we promote, what a red flag on a swing card is |
| "What people get wrong" | 6 Common Mistakes | maps 1:1 to our rule-file bug histories, which are real mistakes with real numbers |
| Module assessment | 7 Examiner | the quiz system already shipped ([[astro-world-astrosedu-media-and-quizzes-2026-08-03]]) |
| Interactive tutor | 4 Personalized Tutor | a later feature; needs grounding in our notes or it will invent baseball |

## Takeaways for us

1. **Ground every prompt in OUR canon.** A generic "teach me attack angle" answer will
   contradict `swing-characteristics-canon.md` or GC2's definitions. Course generation
   must read the canon note first and cite it; GC2's definition is the answer
   ([[feedback_gc2_definition_is_the_answer]] in memory).
2. **Prompt 6 is our moat.** Our `.claude/rules/` bug histories are a library of real,
   specific mistakes (e.g. "Pull% up but on the ground", "a rate that reads 100% in every
   bucket"). A "Common mistakes" lesson built from them is something no generic course has.
3. **Player-facing courses use second person** (you/your), per `player-facing-voice.md`.
4. **No names or internal laundry** in anything that leaves the building.

## Action steps

- [ ] Turn prompts 2 + 3 + 7 into one reusable "course builder" brief: topic -> outline ->
      lessons with checks -> quiz bank, reading the matching canon note first.
- [ ] Pilot it on one module that already has an outline (Hitting Module 7 "Metrics &
      Tech Literacy" in [[pd-onboarding-curriculum]]) and compare against
      [[hitting-quiz-bank]].
- [ ] Park prompt 4 (live tutor) until the course content exists; it is the expensive one.

Related: [[astro-world]] · [[llm-curriculum-project]] · [[pd-apprentice-handbook]] ·
[[agent-harness-research-2026-10-13]]
