---
title: LLM Explainer Video - Source Research
date: 2026-09-30
status: active
tags: [llm-explainer, ai-literacy, research]
---

# LLM Explainer Video - Source Research

Research pass for [[llm-explainer-video]], a narrated motion-graphics explainer (about 6-8 min) teaching AI and large language models to total beginners. Primary audience is professional baseball coaches, with other staff levels too. Sits alongside [[llm-curriculum-project]].

Each source below lists what it is, the substance, and how it maps onto a video for coaches. Sources that could not be fetched directly are marked "capture caveat" with what search excerpts said. The synthesis at the bottom is the part to build from.

---

## 1. 3Blue1Brown - "Large Language Models explained briefly"

**What it is:** Grant Sanderson (3Blue1Brown), short video lesson made for an exhibit at the Computer History Museum. Published Nov 20, 2024. URL: https://www.3blue1brown.com/lessons/mini-llm/ (video also on YouTube, id LPZh9BOjkQs).

**Substance:**
- Defines an LLM as a mathematical function that predicts what word comes next, assigning a probability to every possible next word rather than picking one with certainty.
- Opens with a concrete hook: a movie script where the AI assistant's reply has been "torn off," and the model has to fill it in. That is how a chatbot works: lay out a script of a user talking to an assistant, append what the user typed, then repeatedly predict what the assistant would say next.
- Word-by-word generation is shown as repeated prediction steps, which makes the process tangible.
- Scale comparisons: a person reading the GPT-3 training text nonstop, 24-7, would need over 2,600 years. Training compute is framed as 100+ million years at a billion operations per second.
- Parameters are "dials on a really big machine," tuned by comparing predictions to real text over trillions of examples.
- Ordering: definition, then chatbot application, then mechanism, then scale, then transformers and attention (the "riverbank" example of context changing meaning).
- Key humility line: specific behavior is "an emergent phenomenon" of how the parameters were tuned, so it is hard to say why a given answer came out.

**Takeaways for us:**
- Steal the "torn-off script" hook almost directly. For coaches: a lineup card or a scouting report with the last line torn off, and the model filling it in.
- The dial-tuning image animates well in motion graphics (a wall of dials settling).
- Its order (what it is, then what it does for you, then a peek under the hood, then scale) is the right pacing for a short video. Skip the attention math; keep one example of context changing meaning.

---

## 2. Andrej Karpathy - three general-audience videos

**What it is:** Andrej Karpathy (OpenAI co-founder, former Tesla AI lead). Three YouTube videos aimed at non-specialists:
- "[1hr Talk] Intro to Large Language Models," Nov 2023: https://www.youtube.com/watch?v=zjkBMFhNj_g
- "Deep Dive into LLMs like ChatGPT," 3h31m, Feb 2025: https://www.youtube.com/watch?v=7xTGNNLPyMI
- "How I use LLMs," 2h11m, Feb 2025: https://www.youtube.com/watch?v=EWvNQjAaOHw

**Substance:**
- Intro talk: an LLM is "two files," a big parameters file (the learned weights) and a small program that runs it. That is the whole thing on disk, which demystifies it. Second half proposes the "LLM OS" framing: think of the model as the kernel of a new kind of operating system, not just a chatbot.
- Deep Dive: walks the full training stack. Pretraining on internet text produces a "base model" that only continues text; post-training on conversation examples turns it into an assistant; reinforcement learning is "practice problems." Dedicated segments on hallucination and how tools (search, code) reduce it.
- How I use LLMs: the context window is working memory (like RAM), while knowledge in the parameters is a "vague recollection, like something you read a month ago." A new chat starts with an empty token stream. Advice: keep context relevant and start a fresh chat when old material is no longer helping. Covers thinking models, search, file uploads, voice, and comparing ChatGPT, Claude, and Gemini.

**Takeaways for us:**
- "Vague recollection vs what is on the table in front of it" is the single most useful distinction for coaches. Training = what a veteran scout half-remembers from years of games. Context = the report you just handed him.
- "Two files" is a great 10-second demystifier for skeptics who imagine something mystical.
- "Start a fresh chat" is practical, beginner-level, and counterintuitive. Worth one line.

---

## 3. Anthropic - AI Fluency: Framework and Foundations (the 4Ds)

**What it is:** Free course from Anthropic, built with professors Rick Dakan (Ringling College of Art and Design) and Joseph Feller (University College Cork), who developed the AI Fluency Framework in 2023-2024. 14 lessons, about 4 hours, quiz and badge. URL: https://academy.claude.com/courses/ai-fluency-framework-foundations (also on Coursera and Anthropic Skilljar; framework site https://aifluencyframework.org/).

**Substance:**
- Four competencies:
  - **Delegation** - deciding what work to hand to AI vs do yourself, based on knowing the problem, the tool, and the task.
  - **Description** - communicating clearly: what the output should be, how to approach it, how it should behave.
  - **Discernment** - critically evaluating what comes back, in a loop with Description.
  - **Diligence** - owning the result: quality, transparency about AI use, responsible deployment.
- Three modes of interaction: Automation (AI does a defined task), Augmentation (you and AI collaborate), Agency (AI acts more independently on your behalf). Course page names these; detailed definitions were not on the fetched page.
- Core philosophy: using AI well is a learnable skill, and prompting is only one of four skills.

**Takeaways for us:**
- The 4Ds map cleanly onto a coaching cycle: Delegation = who gets the rep, Description = the cue, Discernment = watching the rep, Diligence = your name is on the evaluation. A good closing-chapter framework.
- The "learnable skill, not a talent" message lowers the intimidation bar for veteran staff.
- Description <-> Discernment loop is literally the feedback loop coaches already run.

---

## 4. Financial Times - "Generative AI exists because of the transformer"

**What it is:** Madhumita Murgia (FT AI editor) and the FT Visual Storytelling Team, Sept 12, 2023, open access. Reviewed for accuracy by researchers including Slav Petrov, Aidan Gomez, Jakob Uszkoreit, and Ashish Vaswani. URL: https://ig.ft.com/generative-ai/

**Capture caveat:** direct fetch of ig.ft.com is blocked from this tool. Content below is from search excerpts and secondary write-ups (journalismAI.com, Downes.ca, the designer's portfolio).

**Substance (per excerpts):**
- Scroll-driven, step-by-step visual build of what happens inside an LLM: text becomes tokens, tokens become numbers (embeddings), attention lets each word look at the others.
- Key point: transformers process a whole sequence at once rather than word by word in isolation, which is why they handle context.
- Also covers where models go wrong and why they are powerful.

**Takeaways for us:**
- The scroll-reveal, one-step-per-beat build is the pacing model for our "peek under the hood" chapter. One idea per animated beat, never two.
- A single sentence that follows us through every stage (theirs is a running example sentence) is a strong device. Ours could be a baseball sentence, e.g. "The runner on first takes a big lead," tracked from words, to numbers, to a prediction.

---

## 5. Ethan Mollick - "An opinionated guide to which AI to use"

**What it is:** Ethan Mollick (Wharton professor, author of "Co-Intelligence," 2024), newsletter One Useful Thing. The fetched page is dated July 23, 2026 (a search excerpt referred to a "Summer 2026 Edition" and an Aug 31 date; treat the exact date as July-Aug 2026). URL: https://www.oneusefulthing.org/p/an-opinionated-guide-to-which-ai-b22 . Companion: "Using AI Right Now: A Quick Guide," https://www.oneusefulthing.org/p/using-ai-right-now-a-quick-guide

**Substance (as stated by the author, his opinion):**
- For advanced agent work, he names Claude and ChatGPT as the two serious choices for most people, both at about $20/month, with comparable power.
- He says Google Gemini has fallen behind on frontier models and agentic ability, while noting Google is strong in specific tools (for example its notebook-style research tool).
- Modes of use he lays out: plain chat for low-stakes questions; "Work/Cowork" style agents that run on the company's servers and return finished deliverables; "Codex/Code" style agents that run on your own computer where you can watch the work; and voice modes.
- Beginner advice: start with low-stakes tasks; use the stronger models with more "thinking" for high-stakes questions (medical, legal); "pick Claude or ChatGPT, pay the $20, and give an agent a real task."
- Working with agents is "more like managing than it is chatting." When results come back, "ask for changes, just as you would ask a real person," rather than just accepting or rejecting.
- Keep approval toggles on for anything that sends, spends, or deletes.
- On product naming: "The names do not map onto each other in any way that will help you remember them."

**Takeaways for us:**
- "More like managing than chatting" is the adult framing coaches will respect. They manage people for a living.
- "Ask for changes like you would a real person" is our feedback chapter in one line.
- For the Claude vs ChatGPT vs Gemini segment, attribute the ranking to Mollick as opinion. Our own on-screen claim should stay at: several good assistants exist, they are more alike than different for a beginner, pick one and practice.

---

## 6. Zhicheng Lin - "Six misconceptions about large language models" (PNAS Nexus)

**What it is:** Zhicheng Lin, Department of Psychology, Yonsei University. Peer-reviewed paper, PNAS Nexus, published July 8, 2026. URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC13378163/ (journal: https://academic.oup.com/pnasnexus/article/5/7/pgag236/8728241)

**Substance:**
- The six misconceptions:
  1. LLMs are just autocomplete or "stochastic parrots."
  2. LLMs regress to the mean, the average of the internet.
  3. LLMs merely regurgitate training data.
  4. LLMs either remember everything or nothing about users.
  5. Fine-tuning / safety training is a removable filter on top.
  6. LLMs either think like humans or have no understanding.
- Popular slogans ("glorified autocomplete," "stochastic parrot," "blurry JPEG of the web") are folk theories: each has a kernel of truth (next-word training, compression of data) but misleads when treated as the whole story.
- Two failure directions: deflationary (it is trivial, ignore it) and anthropomorphic (it is a mind like ours). Both lead to practical mistakes.
- Proposed framing: LLMs as "simulators of discourse and task performance."

**Takeaways for us:**
- This is our authority for handling analogies honestly. Use "next-word prediction" as the starting mechanism, then explicitly say "but 'just autocomplete' undersells it."
- Misconception 4 (memory) is directly relevant to 2026 products, which now have optional memory features. The accurate line: by default the model does not learn from your chat, but many apps now save notes about you that you can view and delete.
- Coaches will split into the two camps Lin describes (dismissive veterans and over-trusting enthusiasts). Address both on screen.

---

## 7. OpenAI - "Why language models hallucinate"

**What it is:** OpenAI research paper by Adam Tauman Kalai, Ofir Nachum, Santosh S. Vempala, and Edwin Zhang, Sept 2025. Paper: https://arxiv.org/abs/2509.04664 . Blog: https://openai.com/index/why-language-models-hallucinate/

**Capture caveat:** the openai.com blog returned 403 to direct fetch. Substance below is from the arXiv listing and search excerpts.

**Substance:**
- Models hallucinate partly because training and evaluation reward guessing over admitting uncertainty.
- The analogy: a student on a multiple-choice exam who guesses on hard questions because a blank scores zero and a guess sometimes scores.
- Proposed fix: penalize confident errors more than "I don't know," and give partial credit for appropriate uncertainty.

**Takeaways for us:**
- The exam analogy is great for beginners and translates to baseball: a young player who would rather give the coach any answer than say "I didn't see it." Confident is not the same as correct.
- Gives a non-mystical reason for hallucination, which beats "it lies" or "it glitches."
- Practical corollary for the video: tell it that "I don't know" is an acceptable answer, and ask it to show where a fact came from.

---

## 8. Anthropic prompting docs, OpenAI Help Center, Google's Gemini prompting guide

**What it is:** The three vendors' own beginner-facing prompting advice.
- Anthropic, "Prompting best practices," Claude Platform Docs (fetched Sept 2026): https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- OpenAI Help Center, "Prompt engineering best practices for ChatGPT": https://help.openai.com/en/articles/10032626-prompt-engineering-best-practices-for-chatgpt (capture caveat: search excerpt only, not fetched)
- Google, "Gemini for Google Workspace: Prompting Guide 101" (PDF): https://services.google.com/fh/files/misc/workspace_with_gemini_prompting_guide.pdf (capture caveat: search excerpt only, not fetched)

**Substance:**
- Anthropic (verbatim): "Think of Claude as a brilliant but new employee who lacks context on your norms and workflows. The more precisely you explain what you want, the better the result." Golden rule: "Show your prompt to a colleague with minimal context on the task and ask them to follow it. If they'd be confused, Claude will be too." Also: explaining why an instruction matters helps it deliver more targeted responses.
- OpenAI (per excerpt): prompting is iterative; start, review, refine. Identify the task clearly, give needed context, set tone. Break complex jobs into follow-up steps; treat it as a conversation.
- Google (per excerpt): the PTCF formula, Persona, Task, Context, Format. You do not need all four every time. The task verb is the most important part. Context = why you need it and where it will be used.

**Takeaways for us:**
- All three vendors converge on the same three moves: say what you want, give the background and the why, then iterate. That convergence is itself a teaching point (this is not one company's trick).
- "Brilliant but new employee" + "colleague test" is the coach-friendly version: would a new staff member who has never seen our org follow this?
- PTCF is a simple on-screen card. Baseball version: who they are (role), what you want (task), the situation (context), what it should look like (format).

---

## 9. Anthropic Help Center - Claude memory and chat search

**What it is:** Official help article, "Use Claude's chat search and memory to build on previous context," updated about mid-Sept 2026. URL: https://support.claude.com/en/articles/11817273-use-claude-s-chat-search-and-memory-to-build-on-previous-context

**Substance:**
- Chat search: Claude can pull relevant context from past conversations when asked.
- Memory: Claude saves short topics from your chats (role, projects, preferences) and carries them into new chats. On by default for Free, Pro, and Max on web, desktop, and mobile; off by default on Team and Enterprise (admins can turn it on).
- Each Project has its own separate memory and summary, walled off from other projects and non-project chats.
- Users can view, edit, delete, pause, or reset memory, and use incognito chats.
- Press coverage (TechCrunch, Aug 25, 2026) reports memory now spans chat and the Cowork agent.

**Takeaways for us:**
- Correct the old "it has no memory between chats" line. Accurate 2026 version: the model itself does not learn from you; the app may keep notes about you, which you can see and control. Settings vary by plan and by what your org turned on.
- Projects = a binder per topic (one for the pitching staff, one for advance reports), which coaches will get instantly.
- Important for staff: know what your org's plan does with memory before pasting sensitive player info.

---

## 10. Claude's Opus 5.5 showcase thread and the interactive lens lab

**What it is:** Post by @claudeai, Sept 25, 2026: "Claude Opus 5.5 has been out for a few days. Some of our favorite things people have explored and discovered with it so far:" quoting Ryan Sael (@RyanSael, Sept 23, 2026). Fetched via https://api.fxtwitter.com/claudeai/status/2103515655760982273 . Original: https://x.com/claudeai/status/2103515655760982273 . Quoted post: https://x.com/RyanSael/status/2102591147927654847 . Demo: https://lens.lab.sael.net (redirects to https://sael.net/plane-of-focus/ ).

**Capture caveat:** the fxtwitter JSON returned only the top post and the quoted lens-lab post. Other items the brief mentions in the thread (code-drawn motion graphics, Three.js scenes, staged sketch to massing to detail to finished builds) were not in the returned payload and are not verified here.

**Substance:**
- Sael: "I asked Opus 5.5 to explain camera focus by building an interactive lens lab." Built in one shot over 1 hour 26 minutes at $25.66 API cost. "Move the focus ring and you can see the glass elements shift the sharp plane through the scene."
- The page (fetched): a 3D scene teaching the plane of focus. Core idea stated plainly first: a lens "can only bring one distance to a perfect point." Shows light rays converging (sharp) or missing the sensor ("circles of confusion" = blur).
- Isolates two variables only: focus ring and aperture (f/2 to f/16).
- Direct manipulation: drag the focus ring, keys 1/2/3 snap to foreground, middle, background; toggle assembled vs exploded lens view; orbit and zoom.
- Progressive disclosure: a simple console of current values up front, expandable "why" explanations ("Why the rest goes soft"), advanced controls hidden behind a key.

**Takeaways for us (why these visuals teach well):**
- One sentence of principle first, then the visual proves it. We should state each chapter's idea in one line before animating.
- Only two knobs. Our visuals should vary one thing at a time (e.g. more context in, better answer out).
- Cause and effect you can see: move a control, watch the consequence. In a narrated video we cannot hand over the knob, but we can show the knob turning and the outcome changing, ideally the same prompt with thin vs rich context.
- Exploded view = show the parts, then snap them back together. Good model for "what is inside a chatbot app" (model + context + tools + memory).
- Drawn in code means cheap iteration and exact reproducibility; it is also a meta-demo that these tools can build teaching material. A companion interactive page for coaches (built the same way) could extend the video.
- The staged-build pattern the brief describes (sketch, massing, detail, finished) is a strong structure for our chapter visuals even though it is not verified in this thread: reveal each diagram in stages rather than all at once.

---

## Synthesis for the video

### Recommended analogies (baseball-flavored where natural)

| Concept | Analogy | Source basis |
|---|---|---|
| What an LLM does | Fills in the torn-off last line of a script, one word at a time, choosing the most likely next word. Baseball: finishing a play-by-play call. | 3Blue1Brown |
| Training | A scout who has watched millions of games and remembers patterns, not every box score. Vague recollection, not a record book. | Karpathy |
| Context window | The scouting report you hand over before the game. What is on the table right now beats what it half-remembers. | Karpathy, Anthropic docs |
| Starting fresh | New series, new report. Clear the board when the old notes are getting in the way. | Karpathy |
| How to ask | A brilliant new staff member on day one. Smart, but does not know our org, our terms, or why this matters. Colleague test: would a new hire follow this? | Anthropic docs |
| Iterating | Coaching cues. One rep, watch it, adjust the cue. Ask for changes like you would with a person. | Mollick, OpenAI help, 4Ds |
| Hallucination | A young player who would rather give any answer than say "I didn't see it." Confident is not correct. | OpenAI paper |
| Agents | Delegating a task to a staffer vs asking a question. More like managing than chatting. Keep sign-off on anything that sends, spends, or deletes. | Mollick |
| Projects / memory | A binder per topic that the assistant can see; notes it keeps about you that you can open and erase. | Anthropic Help Center |
| Using it well overall | The 4Ds as a coaching cycle: who gets the rep, the cue, watching the rep, owning the evaluation. | Anthropic AI Fluency |

**Analogies to avoid or correct on screen:**
- "It looks things up in a database" - wrong by default. It generates from patterns unless a search tool is turned on. (3Blue1Brown, Karpathy)
- "It thinks like a person" / "it knows you" - anthropomorphic overreach. (Lin)
- "It's just autocomplete" - true mechanism, misleading conclusion. Say it, then say why "just" undersells it. (Lin)
- "It never remembers anything" - outdated for 2026 apps with optional memory. (Anthropic Help Center, Lin misconception 4)

### Misconceptions to address
1. It is a search engine or database. (Mostly no; it predicts text, and search is an optional add-on tool.)
2. If it sounds confident, it is right. (Hallucination; ask for sources, allow "I don't know.")
3. It knows today's news. (Knowledge cutoff from training; current info only if it searches.)
4. It remembers or doesn't remember everything. (Model does not learn from your chat; apps may keep visible, editable notes.)
5. Better AI = better magic words. (It is mostly context and iteration, not tricks; all three vendors agree.)
6. One brand is the only good one. (Several strong options; pick one and practice. Any ranking is opinion and changes quickly.)
7. Either it is useless or it replaces judgment. (Diligence: your name stays on the evaluation.)

### Recommended 7-chapter structure (about 6-8 min)

1. **Cold open: the torn-off line (0:00-0:45).** A scouting report with the last line missing; the machine fills it in word by word. "That is the whole trick. What is surprising is how far it goes."
2. **What it actually is (0:45-1:45).** Next-word prediction, trained on more text than a person could read in thousands of years. Dials settling on a giant machine. "Two files." Not a database, not a person.
3. **Where its knowledge comes from, and where it stops (1:45-2:45).** Veteran scout memory vs the report in hand. Knowledge cutoff. Confident guessing (exam analogy). Confident is not correct.
4. **Context is the scouting report (2:45-3:45).** Same question, thin vs rich context, side-by-side results changing (one variable at a time, lens-lab style). Brilliant new staffer. Colleague test. PTCF card.
5. **Feedback is coaching (3:45-4:45).** First answer is a first rep. Adjust the cue, ask for changes, start fresh when the thread gets muddy. Description <-> Discernment loop.
6. **Where you will meet it (4:45-5:50).** Chat apps, voice, inside tools you already use, projects and memory (binders you control), agents that do tasks on a computer (Claude Code, Codex, Cowork style). The brands: Claude, ChatGPT, Gemini, more alike than different for a beginner; pick one.
7. **Using it well: the 4Ds (5:50-7:00).** Delegation, Description, Discernment, Diligence as a coaching cycle. Guardrails: check facts that matter, know your org's data rules before pasting player info, keep approval on for send/spend/delete. Close: "It's a learnable skill. Take one real task from your week and give it the scouting report."

### Visual approach notes
- One idea per beat; state it in a line, then animate it (FT scroll build, lens lab principle-first).
- Vary one thing at a time; show cause and effect.
- Reveal diagrams in stages (sketch, structure, detail, finished) rather than all at once.
- Exploded-view moment for "what is inside the app": model + context + tools + memory, then snap back together.
- A running baseball sentence that threads through chapters 1-4 ties the mechanism together.

Related: [[llm-curriculum-project]] · [[llm-explainer-video]]
