---
type: reference
created: '2026-06-26'
updated: '2026-10-13'
tags:
  - reference
  - context-library
  - ai
  - data-science
---
# 📚 Context Library

Running index of **external context Zac feeds Claude** — AI/agent technique,
prompting, data science, baseball — each with real content (not just a URL) and a
one-line *why*. Captured via **`/document`**; consumed by the [[advisory-council]].
Artifacts (data/models) → [[artifacts-register]].

## How to add
- **`/document <url|file|paste>`** — files it here (links) or in [[artifacts-register]] (files), categorized + dated. Never dropped.
- **`/ingest <url>`** — deeper: turns a source into full interlinked concept notes.

---

## AI agents, workflows & orchestration

- **@akshay_pachaar "3 RAG architectures"** (X, Jul 2 2026; captured Jul 3 via fxtwitter) —
  Standard vs Graph vs Agentic RAG chosen by query pattern, not tiers; companion "IdeaBlocks"
  post (atomic Q-A beats chunks: −40× corpus, +2.3× relevance) validates our atomic-note vault.
  Full takeaways: [[rag-architectures]]. Now council curriculum ([[council-knowledge-base]] §7).
  <https://x.com/akshay_pachaar/status/2072767459908796782>
- **@0xkozue "PyTorch training pipeline cheat sheet"** (X article, Jul 2 2026; captured Jul 3) —
  tensors→autograd→backprop→optimizer loop one-pager; bench depth vs our LightGBM tabular stack,
  nearest live use = Command CV YOLO fine-tune. Full note: [[pytorch-training-pipeline]].
  Cheat-sheet image needs manual view. <https://x.com/0xkozue/status/2072607035624247732>
- **@agentic.james "one-big-feature method"** (IG reel, captured Jul 3 2026 from
  Zac's screen recording) — 5 custom slash commands: `/orchestrate /plan /spec
  /implement /reviewloop`. **ADOPTED same-day as thin aliases in
  `~/.claude/commands/`** routing to our GSD suite (spec→discuss/new-project,
  plan→plan-phase, implement→execute-phase, reviewloop→code-review+verify cycle,
  orchestrate→gsd:autonomous/Workflow) — ours persists state to `.planning/`
  across /clear, which the bare-command version can't. Video audio unreviewed
  (frames only); recording in Downloads `ScreenRecording_07-03-2026 12-05-55_1.MP4`.
  Pairs with [[fable5-use-cases]] + the /explain command born the same session.
- **chase.h.ai "5 Fable 5 use cases"** (IG carousel Jul 2026; captured Jul 2 2026) —
  clone-paid-apps-locally via `/goal` · **audit your Claude Code sessions with
  sub-agents** · **visual agentic OS dashboard wired to Obsidian** · bug hunts w/
  parallel adversarial reviewers · ship-from-a-single-PRD. Full breakdown + mapping
  to our stack (GSD / Workflow tool / BSB Brain) in [[fable5-use-cases]]. Testing
  use cases 02+03 on Jul 2. Source: 5 screenshots (IMG_8319–23), video slides unreviewed.
- **@undefinedKi "Claude Code agent teams"** (Jun 15 2026) — Anthropic shipped
  *agent teams*: a team lead spawns **peer** agents that share a task list and
  **message each other** (not subagents reporting up). Demo: a QA agent caught 3
  bugs, sent work back to FE/BE devs, shipped in one pass.
  **Enable:** Claude Code ≥ v2.1.32, add to `settings.json`:
  `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }`, restart.
  **Rules:** each agent owns its files; define exact outputs; name who messages who;
  3–5 agents; complex parallel work only (costs 3–4× tokens).
  → **This is the real feature behind our [[advisory-council]].** 989s video unreviewed,
  but the caption is the full how-to. <https://x.com/undefinedKi/status/2066504594755031343>
- **@h100envy "Loop Engineering"** (Jun 24 2026) — Anthropic senior-dev 11-pager.
  5-step loop: **Discovery** (agent finds its own tasks) · **Handoff** (isolated git
  worktrees) · **Verification** (separate agent reviews assuming it's broken — "an
  agent grading its own work gives itself an A") · **Persistence** (*results save to
  disk so they don't vanish when context clears* ← our exact pain, see
  [[artifacts-register]]) · **Scheduling** (timer auto-wakes the loop).
  <https://x.com/h100envy/status/2069864261203988901>
- **@Blum_OG "9-step engineering loop"** (Jun 15 2026) — explore-subagent → plan mode
  → CLAUDE.md standards → hooks → small diffs → tests → review-subagent → fix &
  re-check → `/ship`. Mantra: *"explore > plan > test > another agent reviews the diff
  > first agent fixes what the second found."* <https://x.com/blum_og/status/2066641308559474891>
- **Claude Skills for Product Managers** (pmclub / Medium; captured Jun 27 2026) —
  Skills = `SKILL.md` workflow files that turn Claude from a generic tool into a
  "trained specialist": encode your PRD templates, competitive-analysis formats, and
  product context ONCE so outputs come back correctly formatted on the first try
  instead of re-explaining each request. **Why it matters:** the PM-process framing is
  a template for *expanding our own process library* — same mechanic as our `/document`,
  `/brief`, `/log` skills, applied to product/PM workflows we don't yet encode. Pairs
  with [[skill-dev-principles]]. <https://medium.com/@pmclub/claude-skills-for-product-managers-0b3f8a186fcf>
- **OpenAI Codex plugin for Claude** (claudepluginhub; captured Jun 27 2026) —
  **[UNFETCHED-SPECIFICS — needs manual review]** page 403/401'd through WebFetch +
  jina; title/listing only. A Claude plugin wrapping OpenAI Codex, flagged by Zac as a
  *future code-audit / second-opinion reviewer* over our 4 apps + worktrees (cross-model
  review, the "separate agent assumes it's broken" pattern from Loop Engineering above).
  We already have a local `codex` skill; assess overlap before adopting. Revisit the
  page content manually. <https://www.claudepluginhub.com/plugins/openai-codex-plugins-codex>

- **@agentic.james "god tier Claude code stack"** (IG reel; **fully transcribed**
  Jul 16 2026 — yt-dlp + Whisper) — `/ultraplan` → `/goal` → `/agents` →
  `/ultrareview`, a cloud maker→checker loop. **CONFIRMS our stack** (`/ultrareview`
  = our `/code-review ultra`; `/goal` = ours; `/agents` = Agent/Workflow), one gap:
  no cloud-fanout *planner* (`/ultraplan`). Keep his cost tip: run cloud commands
  **locally** to save billed credits. Full transcript + verdict table →
  [[ig-cc-command-stack-obsidian-command-center]]. Pairs [[loop-engineering]].
  <https://www.instagram.com/reel/Da1rowXkniP/>
- **chase.h.ai "Obsidian command center"** (IG reel; **fully transcribed + dashboard
  read from frames** Jul 16 2026) — turn Obsidian into a **visual command center**:
  metric cards + a **button grid firing Claude Code skills** (Morning Brief, Weekly
  Review, Vault Cleanup, Pull Metrics…) + an **activity/cascade feed** + embedded
  terminal + graph view. **ADOPT** — this is the [[fable5-use-cases]] use-case-03
  dashboard we flagged; build via kepano **obsidian-bases** ([[obsidian-skills-kepano-eval]])
  wired to our `/today /brief /monday /sunday` skills. Full layout + BSB build spec →
  [[ig-cc-command-stack-obsidian-command-center]].
  <https://www.instagram.com/reel/DazC8iapXvQ/>
- **@sairahul1 "Prompt, context, harness, loop & graph engineering"** (X, Jul 19 2026;
  captured Aug 17 via fxtwitter) — the five layers of an AI application, each building on
  the last. **The most useful frame in this batch**: it tells you WHICH LAYER a fix belongs
  to. Our 140K rule-injection burn is a *harness* bug (`paths:` globs), not a prompt bug, so
  "be careful" can never fix it. Quotes Peter Steinberger (OpenAI) + Boris Cherny (Anthropic)
  on the shift from prompts to autonomous loops. Full note: [[agent-engineering-layers]].
  <https://x.com/sairahul1/status/2078781824160166070>
- **@hanakoxbt "6 agent patterns"** (X, Jul 19 2026; captured Aug 17 via fxtwitter) —
  Anthropic's own taxonomy: ① prompt chaining ② routing ③ parallelization ④ orchestrator-workers
  ⑤ evaluator-optimizer ⑥ autonomous agent. First five are *workflows* (you wrote the path);
  only the last writes its own. "Most production systems people call agents are pattern 1, 2,
  or 5 with good error handling" — true of ours (Monday cascade = 1, fetch ladder = 2, council
  reviews = 5, Workflow = 3/4). Vocabulary for naming what we build. [[agent-engineering-layers]]
  <https://x.com/hanakoxbt/status/2078979637804187793>
- **@sairahul1 "Claude as an entire company — 42 skills"** (X, Jul 16 2026; captured Aug 17
  via fxtwitter) — 42 Claude Skills organised as an org chart (Developers, Designers,
  Marketing, Social, Finance, Small Business, Legal). Zac flagged this one as most
  interesting. The packaging end of the same idea our `.claude/skills/` already runs;
  worth mining for department-shaped skills we lack (Legal/Finance = none today).
  <https://x.com/sairahul1/status/2077733367358079309>
- **@suraj_sharma14 "12 Agentic AI projects"** (X, Jul 18 2026; captured Aug 17 via
  fxtwitter) — portfolio/curriculum list from Structured Output Agents through OSS
  framework contributions; companion to his 6-month Agentic AI Engineer roadmap.
  Reference only — we ship these patterns in production already; useful as a gap checklist.
  <https://x.com/suraj_sharma14/status/2078449718414180393>
- **"How to create 1,000 Agents from One Prompt in Claude Code"** (Google Doc, newsletter
  link; **BODY NOT CAPTURED** Aug 17 — Docs sign-in wall, jina 401). Title + framing only.
  WebSearch recovered the surrounding public state of the art: Claude Code ships built-in
  subagent types, nested subagents (depth cap 5), and Dynamic Workflows that fan out tens
  to hundreds of parallel subagents with a Performance Outcomes grader looping each result
  against a rubric; for large N the `Workflow` tool moves orchestration OUT of the
  conversation context. **Re-feed as pasted text if the body matters.**
  <https://docs.google.com/document/d/1RVyNHGngk2rnidAPt1CvVfZX2r0u8QENunbI047fKqc/edit>

### Oct 13 2026 batch (13 AI / agent sources; full notes [[agent-harness-research-2026-10-13]])
- **Claude Code advisor tool** (official doc) - a stronger model Claude consults before a plan,
  on a repeating error, and before "done"; reads the FULL transcript (uncached) each call. With
  our Opus 5.5 main model the only valid advisors are Opus 5+ or Fable.
  <https://code.claude.com/docs/en/advisor>
- **Agent view `claude agents`** (official doc, research preview) - one screen of all background
  sessions (needs input / working / completed) + `--json` for scripts. The fix for "6 sessions
  open, the computer died, what was I doing." <https://code.claude.com/docs/en/agent-view>
- **@mirku21 "advisor opus, subagents haiku"** (Oct 7) - plan on high, delegate on medium, keep
  Opus on call; `--subagents` flag and "3x dispatcher pool" are NOT real. Quotes the
  "Harness Engineering" article (dual-encoding: rule in text AND a mechanical gate).
  <https://x.com/mirku21/status/2107939129736700335>
- **@mirku21 "advisor fable"** (Sep 29) - Opus main + Fable advisor; its prompt correctly checks
  `DISABLE_TELEMETRY` / `CLAUDE_CODE_DISABLE_ADVISOR_TOOL`. <https://x.com/mirku21/status/2105040007127761242>
- **@Bober_smart agent teams + second brain** (Oct 3) - architect / developers in worktrees /
  adversary before PR; `--teammates` flag NOT documented; "flat md + CLAUDE.md map" second brain
  (we already run it). <https://x.com/Bober_smart/status/2106444298849796475>
- **Anthropic webinar: how Claude Code spends tokens** (via @ZoriaHartson, Oct 3; tweet framing
  "100+ agent swarm" is false) - cache is the biggest lever; model/effort switches, /compact and
  /clear break it; ~1h cache TTL on plans, 5 min subagents; compact BEFORE stepping away; noisy
  command output rides along all session. <https://x.com/ZoriaHartson/status/2106460701661253927>
- **@N01ennn 20 motion repos + "Opus 5.5 studio" guide** (Oct 8; "Netflix engineers" is false)
  - frame = pure function of its number; a smoke test whose six counters must read zero (= our
  layout-collision guard); guides vs sensors (Bockeler); arXiv 2609.00006 study of 11 coding
  agents (no vector RAG over code, skills in 9/11). <https://x.com/N01ennn/status/2108182955671580771>
- **@undefinedKi Karpathy autoresearch + 5 levels of agents** (Oct 4) - one file, one number,
  fixed 5-min runs, keep or git reset, simplicity rule; honest Jev numbers (logreg 98.9 vs Jev
  98.6; phishing Jev 62.6 vs Haiku 81.3); 93% of permission prompts get approved.
  <https://x.com/undefinedKi/status/2106775535787323649> · <https://github.com/karpathy/autoresearch>
- **@Promixyz evidence-loop repos + Graph Engineering 14 steps** (Oct 3) - nodes think, edges
  transform; the diamond; critics that try to destroy a finding; remember rejected findings.
  <https://x.com/Promixyz/status/2106462125874987099>
- **@santtiagom_ on Uber's MCP Gateway** (Oct 3) - 800+ servers / 5,000+ tools; discovery does not
  imply exposure; progressive discovery; Code Mode writes tool output to files to grep.
  <https://x.com/santtiagom_/status/2106483024129147108>
- **@thegreatest_sv awesome-ai-agents (300+)** (Oct 3) - category map + JSON/YAML data; lookup
  list, nothing to install. <https://x.com/thegreatest_sv/status/2106403149162455349> ·
  <https://github.com/slavakurilyak/awesome-ai-agents>
- **@milesdeutscher "Opus 5.5 + Jev"** (Oct 7, SPONSORED by TypeSafe) - cheap judge before the
  big model, atomic questions, route by confidence; keep the pattern, skip the vendor (no Astros
  data to a third-party API). <https://x.com/milesdeutscher/status/2107908322368360477>
- Visuals Zac liked from this batch + Command Center v2 / idea-library proposal:
  [[agent-session-visuals-2026-10-13]].

## Prompting & "senior-AI" usage

- **@rubenhassid** (Jun 25 2026) — stop writing 700-word prompts; use **Claude Skills**
  (embed voice/rules/structure, invoke with a slash command). Validates our
  `/document` + skill approach. <https://x.com/rubenhassid/status/2070099690935218547>
- **@Voxyz_ai** (Jun 17 2026) — "don't use a senior AI like a junior intern," 8 prompt
  templates: ① goal-until-the-bar-not-just-runs ② parallel + e2e goal ③ production-grade
  ④ inherit-unfamiliar-repo refactor ⑤ senior debugger ⑥ perf optimization ⑦ prod UI
  ⑧ publishable APIs. <https://x.com/Voxyz_ai>
- **@AlexFinn "Reverse Prompting"** (X, Jul 31 2026; captured Aug 17 via fxtwitter) —
  have the agent prompt YOU. Two-step exercise: brain-dump your goals, then ask *"what more
  information can I give you to help me achieve my goals faster"*, then *"what tasks can you
  do for me right now"*. "You don't prompt. You give information, then allow your agent to
  guide you somewhere interesting." Directly relevant to how Zac runs sessions; the sibling
  of our `feedback_eoy_ask_disambiguation_questions` rule (agent asks the structural question
  BEFORE building). <https://x.com/alexfinn/status/2082982462012227648>
- **@jjacky "the 'i have adhd' skill"** (X, Jul 19 2026; captured Aug 17 via fxtwitter;
  33K likes / 2.0M views) — a Claude Skill that changes *reply style*, not capability, and
  the author reports it "made my claude replies so good". Evidence that response-shape skills
  are as high-leverage as task skills. We have zero style-layer skills; our style rules live
  as memory feedback entries instead (no em dashes, plain-language-first, player-facing
  second person). Candidate: promote those into one loadable style skill.
  <https://x.com/jjacky/status/2078689662118314318>
- **"How to Clone Yourself with AI: The 4 Step System"** (Google Doc, newsletter link;
  **BODY NOT CAPTURED** Aug 17 — Docs sign-in wall, jina 401). Title + framing only.
  Topic overlaps our voice work ([[player-evaluator]] agent writes in Zac's voice).
  **Re-feed as pasted text if the body matters.**
  <https://docs.google.com/document/d/1j85DIP2paoBdZX6vH3flH2CG7ts4YMkHe9bBH_W1Gi8/edit>

- **@Rixhabh__ 7 learning prompts** (Oct 3 2026; captured Oct 13) - foundation builder,
  curriculum architect, concept-by-concept, tutor, mental models, common mistakes, examiner.
  Mapped onto AstrosEDU course parts in [[astro-world-course-prompts-2026-10]].
  <https://x.com/Rixhabh__/status/2106415023354708293>

## Second brain / Obsidian / knowledge management

> We already RUN a Claude+Obsidian second brain (this vault). These are captured as
> reference/benchmark — flagged where they overlap what we already do. See
> [[claude-code-obsidian]] · [[obsidian-optimization]] · [[mcp-setup]] · [[vault-map]].

- **"How to Build an AI Second Brain with Claude and Obsidian"** (ai-snapshots / Medium;
  captured Jun 27 2026) — **[ALREADY-IMPLEMENTED]** core thesis = point Claude straight
  at your Obsidian vault so it reads your notes/context with no copy-paste. That is
  *exactly* this vault via the `obsidian` MCP ([[mcp-setup]]) + the dual-run setup
  ([[README-dual-run]]). Gap assessment: nothing new vs what we do; article body cut off
  before implementation detail, so no new technique to mine. Filed as confirmation, not a
  to-do. <https://medium.com/ai-snapshots/how-to-build-an-ai-second-brain-with-claude-and-obsidian-5ac78f4021e0>
- **Roan Monteiro "Master Obsidian — definitive second-brain guide"** (Medium; captured
  Jun 27 2026) — **[PARTIAL-OVERLAP — we already do MOCs + linking + local-markdown]**
  long-form guide to Obsidian as a second brain (nine "dimensions," core features,
  commands; PARA/MOC methodology). We already run MOCs ([[MOC-baseball-analytics]] etc.),
  wikilink graph, local-markdown-no-telemetry. Worth a skim for plugin/command tactics we
  may NOT have (the methodology sections were behind the fetch cutoff). Cross-ref
  [[obsidian-optimization]]. <https://medium.com/@roanmonteiro/master-obsidian-the-complete-and-definitive-guide-to-turning-your-notes-into-a-second-brain-43f9f147f31a>
- **@eng_khairallah1 → "30 Obsidian Workflows, Plugins, and Setups Most Users Don't Know"**
  (X, links article pub. May 31 2026; captured Jun 27 2026) — **[PARTIAL-OVERLAP — audit
  vs our setup]** tweet is just the link; article catalogs 30 lesser-known Obsidian
  workflows/plugins/setups (2,700+ community plugins, 100+ AI-related). Notable hook: the
  **Obsidian CEO published official Claude Skills for the platform — 12,900+ GitHub stars
  in under three months** (worth chasing for our [[skill-dev-principles]]). Action: mine
  the 30-list against [[obsidian-optimization]] for setups we haven't adopted. Tweet text
  was only a `t.co` link. <https://x.com/eng_khairallah1/status/2061012675824644161>
- **kepano/obsidian-skills** (the CEO's official Skills repo above; cloned + vetted
  Jun 30 2026) — **[PARTIAL-OVERLAP — 1 ADOPT, 2 ADAPT, 2 SKIP]** 5 Agent Skills:
  `obsidian-bases` (**ADOPT** = native Dataview successor, closes the projects/context
  dashboard gap we already named), `obsidian-markdown` (ADAPT = we already write OFM; lift
  the callout convention, we use 0 callouts vault-wide), `json-canvas` (file-for-later),
  `obsidian-cli` (SKIP = needs Obsidian app running, our MCP is headless), `defuddle`
  (SKIP = our fxtwitter/jina fetch ladder already covers the real pain). MIT. Install
  Bases-only into vault `.claude/skills/`; Skills don't conflict with our slash commands.
  Full eval → [[obsidian-skills-kepano-eval]]. <https://github.com/kepano/obsidian-skills>
- **@cyrilXBT "Hermes + Obsidian + NotebookLM"** (X, Jul 30 2026; captured Aug 17 via
  fxtwitter) — second brain that "writes its own skills, maps its own knowledge, remembers
  everything you taught it", runs locally, 140K GitHub stars in three months. Linked article:
  *"How to Build an Opus 5 + Obsidian Research System That Replaces Hours of Manual Reading"*,
  whose thesis is ours verbatim: *"Most research work is not thinking. It is reading,
  extracting, and cross-referencing, done manually, one source at a time."* **[LARGELY
  ALREADY-IMPLEMENTED]** — that is `/research` + `/ingest` + the obsidian MCP. The one genuinely
  new bit is *self-authored skills*; we hand-write every skill today.
  <https://x.com/cyrilXBT/status/2082716319565386132>
- **@kirillk_web3 "The CEO of Obsidian dropped his own Claude Skills"** (X, Aug 9 2026;
  captured Aug 17 via fxtwitter) — kepano/obsidian-skills, now **44.5K stars / 3K forks**
  (was ~13K when we vetted it Jun 30). Respects the real formats: Markdown, Bases, JSON
  Canvas, wikilinks. **[ALREADY VETTED]** — verdict stands at [[obsidian-skills-kepano-eval]]:
  1 ADOPT (Bases), 2 ADAPT (Markdown conventions, Canvas), 2 SKIP (CLI, Defuddle). The star
  growth is the only new information; it does not change the verdict.
  <https://x.com/kirillk_web3/status/2086495974986223898>

## Data science / ML methods
- **SHAP** — feature attribution; Zac leans on it heavily. Pairs with [[lightgbm-baseball-modeling]]. (Next use: v1 hitter age-share study.)
- **Model-eval rigor** — adjusted R², baseline-lift, calibration, overfit gap, inflated-by-easy-rows. Enforced by the [[advisory-council]] Data Scientist.
- **"7 Python Libraries That Replace Entire Data Pipelines"** (python.plainenglish.io;
  captured Jun 27 2026) — **[UNFETCHED-SPECIFICS — needs manual review]** Medium redirect +
  jina 401 blocked the body; title/topic only. Roundup of 7 libs that collapse multi-stage
  ETL into one tool. Zac flagged as **Driveline / data-pipeline relevant** — candidate
  upgrades for our statcast bulk-fetch + feature-ETL spine ([[statcast-pipeline]],
  [[advanced-modeling-setup]]). Re-fetch manually to capture the 7 names (likely
  Polars / DuckDB / Dask / Ibis / Arrow class). <https://python.plainenglish.io/7-python-libraries-that-replace-entire-data-pipelines-31c17cf05ae8>
- **"How to Generate 3D Models from Images with Python"** (data-science-collective / Medium;
  captured Jun 27 2026) — uses **DepthAnything v3** (foundation depth model) to predict depth
  from a single image → voxels / point clouds / 3D Gaussian splatting / meshes. **Why filed:**
  Zac — "in case we ever need 3D models in Python." Potential fit: reconstructing 3D from our
  swing-path / bat-tracking or single-cam video where we lack HawkEye pose blobs (see
  [[swing-path-bat-tracking]]). Reference only, no current project.
  <https://medium.com/data-science-collective/how-to-generate-3d-models-from-images-with-python-b92b7d549801>
- **Rami Krispin on skforecast-ai** (LinkedIn, Aug 2026; captured Aug 17 direct) — new OSS
  forecasting agent from the skforecast authors (Amat Rodrigo / Escobar Ortiz). Architecture
  worth stealing regardless of the domain: a **deterministic core that runs offline** plus an
  **optional LLM reasoning layer** for explanations and plan refinement. Backtesting on
  MAE/MSE/MASE; auto forecaster/estimator/lag/feature selection; recursive, direct,
  multi-series, statistical and foundation models. `pip install skforecast-ai`.
  **Takeaway for us:** this is the split our promotion models should hold — the number must be
  backtestable and interrogable on its own, with the LLM only ever *explaining* it. Getting a
  coordinator to trust a number they cannot interrogate is the actual constraint.
  Docs <https://ai.skforecast.org> ·
  <https://www.linkedin.com/posts/rami-krispin_ai-datascience-forecasting-share-7483514432355176449-w0bj/>

## Baseball analytics sources
- **FanGraphs "A Visual Primer on Horizontal Approach Angle (HAA)"** (captured Jun 27 2026)
  — **[ALREADY-IMPLEMENTED]** HAA = the horizontal angle at which a pitch crosses the plate
  (from release point, final location, velo/accel vectors); sharp arm-side approach buys
  called strikes on the outer edge + weak contact inside, but is far more location-dependent
  than VAA. We already compute this: **`horz_appr_angle` in `Astros.Pitches_View`** (one of
  the 10 match metrics in the Pitch Similarity Finder; documented in `.claude/rules/db-columns.md`).
  Filed as the canonical conceptual primer behind the column. Pairs with
  [[stuff-plus-4s-pitching]] · [[MOC-baseball-analytics]].
  <https://blogs.fangraphs.com/a-visual-primer-on-horizontal-approach-angle-haa/>
- **Berkeley Sports Analytics "Beyond Whiffs"** (captured Jun 27 2026) — proposes **BBQ+
  (Batted Ball Quality Plus)**: grades a pitch on *physical characteristics* (velo, movement,
  release point) rather than outcomes, to predict contact suppression — a Stuff+-family,
  contact-quality-targeted model. Key finding: traditionally undervalued **sinkers + splitters**
  excel at limiting hard contact via vertical deception + unique arm angles, challenging the
  K-only emphasis. **Why filed:** Zac — "good food for thought as we conceptualize similar
  projects." Direct analog to the council's proposed **Stuff+/Location+ pitch-quality** idea
  (see [[council-new-tools-ideation-2026-06-26]]). <https://sportsanalytics.studentorg.berkeley.edu/articles/beyond-whiffs.html>
- **OpenCommand (@tomdoyo)** (captured Aug 17 2026) — **[DIRECT COMPETITOR / DIRECT UPGRADE
  PATH for [[command-cv-status]]]** open-sourced Aug 11 2026: full MLB-wide
  command-from-broadcast-video pipeline (YOLO11 glove/ball/strikezone detections + geometry),
  CC BY-NC-SA **non-commercial**, weights NOT released. The lesson: they solve a **physical
  pinhole camera pose** off the **Statcast ball trajectory + the drawn K-zone box**, and their
  geometry error is **0.35-0.39 in** at the plate; our per-game affine fit on catch-glove
  pixels is **3.9 in**. Calibrate on the ball, not the glove. Also free wins: a physical
  reachability filter that kills the elbow-grab with no retraining, a target rule
  (highest stable glove in [release-2.0s, release-0.3s]), an MLB yardstick (naive median
  miss 11.06 in all / 10.07 FF), and a BB% validity anchor (Spearman +0.547). Full read
  incl. license caution + the "inferred target is bias removal not improvement" caveat:
  [[command-cv-external-research]]. <https://github.com/tomdoyo/open-command> ·
  <https://x.com/tomdoyo/status/2087272169852088752>
- **Colin Hofmeister "Modeling Defensive Positioning"** (LinkedIn + Medium + Shiny app, Oct 13
  2026) - Statcast-only optimizer for all 7 fielders per PA: XGBoost batted-ball mix, park BIP
  reweighting, out model AUC .93, physical coverage race, traced walls (11.8 ft reach),
  rule-constrained L-BFGS-B; held-out gain = 56% of in-sample. Leakage rule: never use where a
  ball was fielded. We have the starting positions he lacks. Feeds Mazzo item 1:
  [[defensive-positioning-hofmeister-2026-10]].
  <https://www.linkedin.com/posts/colinhofmeister_using-mlb-statcast-data-in-r-i-built-a-model-share-7515836650363482112-Zprh/> ·
  <https://medium.com/@colinhofmeister/where-should-the-defense-stand-4ea568dda964> ·
  <https://colinhofmeister.shinyapps.io/DefensivePositioning/>
- **Eric Kozak (@kozy_shack) Volpe bat-path threads** (Sep 2025 + Sep 2026; captured Oct 13) -
  read attack angle conditional on contact depth (13.1 overall, 17.5 at pulled contact = pulled
  grounders); Pull AIR% not Pull%; 3-view baseline vs optimized path visual.
  [[bat-path-kozak-volpe-2026-10]]. <https://x.com/kozy_shack/status/2105427183787184368> ·
  <https://x.com/kozy_shack/status/1966275872870269306>
- *(grow: tjStats, Stuff+, FanGraphs FV/KATOH, Baseball Savant — see [[MOC-baseball-analytics]])*

## Internal past-project corpora (local)
- `bsb-resources/swing-path/examples/data-science-projects` · `/advanced-modeling` · `/external-docs`
- `bsb-resources/swing-path` · `bsb-resources/tjstats-pitching`
- Vault: [[dsproj-data-science-examples]] · [[advanced-modeling-setup]] · [[lightgbm-baseball-modeling]]

---

Related: [[advisory-council]] · [[artifacts-register]] · [[MOC-baseball-analytics]] · [[promotion-release-models]] · [[council-new-tools-ideation-2026-06-26]]


## Claude Code tooling & repos
- **@raycfu "10 Claude Code Repos that actually matter"** (IG carousel; captured Jun 29 2026) → full catalog in [[claude-code-toolkit-raycfu]]. 10 repos; 6 are team-relevant. Two land on our [[loop-engineering]] gaps off-the-shelf: **TDD Guard** (hooks-as-law = gap 2) and **Claude Subconscious** (self-building write-back memory = gap 1). Also: Karpathy Skills, Repomix, ecc, wshobson/agents, Claude Squad, Playwright MCP, awesome-claude-code. Screenshots in `Downloads/IMG_8298–8307.png` (archive when ready).
- **@AlexFinn "the vibe-coding stack"** (X, Aug 4 2026; captured Aug 17 via fxtwitter) —
  NextJS · Vercel · Convex · Clerk · Stripe · Tailwind · Resend, AI split by job (light logic
  / heavy logic / cheap tasks), built with the Codex desktop app + voice. Relevant to
  [[astroworld-status]] (Next.js) as a comparison stack; nothing to change in the baseball
  repos. <https://x.com/alexfinn/status/2084752809476456820>
- **3 Instagram reels on agent technique** (fed Aug 17; **NOT CAPTURED** — Instagram is fully
  walled to direct fetch AND to the jina proxy, which now 401s). Zac's framing is the only
  content we have, preserved verbatim as the index:
  - "transcribe and research when needed with your skills like this" —
    <https://www.instagram.com/reels/DXx6KhJshmv/>
  - "like this search" — <https://www.instagram.com/reels/DbWtIbkJraI/>
  - "turning videos into skills" — <https://www.instagram.com/reels/DbOcjY7RAz7/>
  The third is the interesting one for us (video to skill is the self-authoring gap flagged
  in the cyrilXBT entry). **To capture: paste a transcript or the caption text.** Precedent
  for a recovered IG capture: [[ig-cc-command-stack-obsidian-command-center]].

- **Oct 13 2026: `claude agents` (agent view) + advisor + agent teams docs** - read from the
  official markdown docs (`code.claude.com/docs/en/<page>.md`), which is also how to fact-check
  "official tip" posts. Agent teams: <https://code.claude.com/docs/en/agent-teams>.
  Detail: [[agent-harness-research-2026-10-13]].
