---
type: meta
topic: agent-harness-research
status: captured
created: '2026-10-13'
tags:
  - agents
  - claude-code
  - advisor
  - harness
  - loop-engineering
  - graph-engineering
  - research
---
# Agent + Claude Code research batch (Oct 13 2026)

Zac fed 15 links on Oct 13 2026 ("read, view, listen or watch all of these, store,
take heavy notes, give use cases and action steps"). This note holds the 13
AI / agent / Claude Code sources. The rest of the batch:

- Baseball: [[defensive-positioning-hofmeister-2026-10]] (LinkedIn positioning model) ·
  [[bat-path-kozak-volpe-2026-10]] (2 hitting threads)
- Courses: [[astro-world-course-prompts-2026-10]] (7 learning prompts)
- The visuals Zac liked, plus the Command Center / idea library proposal:
  [[agent-session-visuals-2026-10-13]]

**How it was read.** Every X post via `api.fxtwitter.com/<user>/status/<id>` (full X
Article bodies, including the code blocks embedded in them) plus `/2/thread/<id>` for
multi-post threads. All 9 attached videos downloaded: the 26.6-min workshop was
transcribed locally (faster-whisper `small`, 881 lines), the 8 short clips have no
speech and were frame-sampled (12 frames each) and read. Official docs pulled as
markdown (`code.claude.com/docs/en/<page>.md`), which made it possible to fact-check
the posts' "official tip" claims line by line.

---

## TL;DR: what actually matters for us

1. **`claude agents` (agent view) is the built-in answer to "I had 6 sessions open, the
   computer died, what was I doing?"** One screen of every background session grouped
   Needs input / Working / Completed, Haiku-written row summaries, and
   `claude agents --json --all` for scripts. Research preview, already in our installed
   v2.1.299. Catch: an interactive session only shows up after you background it (`←` or
   `/background`), and shutdown still stops running sessions. See section 2.
2. **The advisor tool is real and fits how we already work.** `/advisor`, the
   `advisorModel` setting, or `claude --advisor <model>`. Our main model is Opus 5.5, so
   the only valid advisors are **Opus 5+ or Fable** (an advisor must rank at or above the
   main model). Claude decides when to call it (before a plan, on a repeating error, before
   "done"); there is no setting to force calls, only instructions. The cost catch for us:
   **each advisor call re-reads the full transcript uncached**, and our sessions run to
   hundreds of thousands of tokens. See section 1.
3. **The Anthropic token-efficiency webinar is the most useful single source in the batch**
   and it is directly about our habits: long resumed sessions, mid-session effort/model
   switches, noisy command output. See section 7.
4. **We already run most of "harness / loop / graph engineering."** Our rule files = guides,
   our guards (`test_rule_routing.py`, layout-collision guard, pin audits) = sensors,
   `/goal` + `/loop` + Workflow = loops and graphs. The new ideas worth stealing are
   small: a "spine" file for loops, critics that try to destroy a finding, and evals built
   from real failures (we have the failures, in the rule bug histories).
5. **About half the batch is sponsored or invents CLI flags.** Fact-check table below.
   Nothing from those posts gets pasted into our settings without checking the doc.

---

## Fact-check table (claims vs the official docs)

| Claim | Where | Verdict |
|---|---|---|
| `claude --advisor opus`, `/advisor`, `advisorModel` setting | mirku21, Bober | **TRUE** (doc). `--advisor` is not listed in `claude --help`. |
| Sonnet 5.5 main + Opus advisor; Opus 5.5 main + Fable advisor | mirku21 x2 | **TRUE**, both are accepted pairings |
| `claude --subagents haiku` | mirku21 Oct 7 | **NOT DOCUMENTED.** Subagent model is set per agent definition or `CLAUDE_CODE_SUBAGENT_MODEL` |
| "subagent parallel dispatcher pool (3x workers)" setting | mirku21 Oct 7 | **NOT A REAL SETTING** |
| "automatically summon advisor when a test fails twice" as config | mirku21 Oct 7 | **FALSE as config.** Doc: "no setting to cap or force advisor calls"; you can only ask in instructions |
| `DISABLE_TELEMETRY` / `CLAUDE_CODE_DISABLE_ADVISOR_TOOL` turn the advisor off | mirku21 Sep 29 | **TRUE** (feature-flag fetching). We have neither set. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enables agent teams | Bober | **TRUE** |
| `claude --teammates ux,backend,adversary`, `~/.claude/teams` roles | Bober | **NOT DOCUMENTED.** Teammates are requested in plain language ("Spawn 4 teammates...") |
| "Jev resolves 1,500+ routing branches in 16ms", "200x faster, 400x cheaper" | mirku21, Miles/aiedge | **MARKETING** (TypeSafe/Jev promo). Independent numbers below say otherwise |
| "Netflix engineers posted 20 GitHub repos" | N01ennn | **FALSE framing.** Repos are by individuals + HeyGen, Remotion, GreenSock, LottieFiles, Airbnb. None from Netflix |
| "Anthropic engineer: 99% use Claude Code like Google... 100+ agents, Boss Agent, PM agents" | ZoriaHartson | **FALSE framing.** The video is a token-efficiency webinar. No swarm, no Boss Agent |
| The animated "agent tree" terminals | mirku21, Bober | **Mockups.** Numbers in them (fork counts, tok/s) are illustrative, not a real session |

---

## 1. Claude Code advisor tool (official doc)

<https://code.claude.com/docs/en/advisor> (fetched as `.md`). Experimental; Anthropic API
only (not Bedrock / Vertex / Foundry).

- Claude consults a second, usually stronger model "before committing to an approach, when
  stuck on a recurring error, or before declaring a task complete." The advisor receives the
  FULL conversation including every tool call and result, runs server-side, returns
  guidance; Claude follows it but surfaces a conflict when its own evidence contradicts it.
- Enable: `/advisor opus` (saved to `advisorModel`), `"advisorModel": "opus"` in settings,
  or `claude --advisor opus` for one session. `/advisor off` to stop.
  `CLAUDE_CODE_DISABLE_ADVISOR_TOOL=1` disables entirely.
- **Pairing rule: advisor must rank at or above the main model.** Opus 5 / 5.5 main accepts
  only Fable or Opus 5+. Fable 5.1 main accepts only Fable 5.1. Subagents inherit the
  advisor and apply the same check against their own model.
- Fable as advisor may need the one-time usage-credits consent (`/model fable` first).
- UI: an `Advising` line; then Reviewed (Ctrl+O to read) / Declined / Unavailable.
- **Cost:** advisor tokens at the advisor's rates on every call; **the advisor's read is not
  cached and re-processes the full transcript each call.** Toggling `/advisor` does NOT
  break the main model's prompt cache.
- Requires feature-flag fetching (any var that disables it, like `DISABLE_TELEMETRY`,
  keeps the advisor off).
- Compare: `opusplan` (stronger model in plan mode only), subagents with `model` set
  (whole subtask), `/model` (switch from next request).

**For us.** Our setup (checked Oct 13): `model: opus[1m]`, `effortLevel: high`, env
`CLAUDE_EFFORT=xhigh`, no `advisorModel`, no `DISABLE_TELEMETRY`. So the advisor would
work; the choice is Opus-advises-Opus (independent second read, the doc's "high-stakes"
pairing) or Fable. Best fit: the work where we have been burned by confident-but-wrong
"done" (EOY decks, promotion-model verdicts, metric parity), not routine edits. Because
our transcripts are huge, try it on a bounded task and read `/usage` before leaving it on.

## 2. Agent view: `claude agents` (official doc)

<https://code.claude.com/docs/en/agent-view> (found from the docs index while checking the
advisor claims). Research preview.

- One terminal screen of all background sessions across all projects, grouped Pinned /
  Ready for review / Needs input / Working / Completed. Each row: name (tinted by `/color`),
  a Haiku-written one-line summary (what it is doing, the question it is asking, or what it
  produced), age, and a PR link label (`#1234`) when the session opened a PR.
- Icons: animated = working, yellow = needs input, dim = idle, green = completed, red =
  failed, grey = stopped; `∙` = process exited (reply or attach restarts it from the saved
  conversation); `✢` = a `/loop` sleeping, with run count + countdown.
- Peek and reply without attaching; attach to enter the full conversation; dispatch new
  sessions from the view or with `claude --bg`; background a live session with `←` or
  `/background`; `/fork` copies one.
- Shell: `claude agents --json [--all] [--cwd <path>]`, `claude attach|logs|stop|respawn|rm <id>`,
  `claude daemon status|logs`. JSON fields: `cwd`, `kind`, `startedAt`, `id`, `state`
  (working / blocked / done / failed / stopped), `status`, `waitingFor` (permission prompt,
  input needed, ...), `sessionId`, `name`. The doc says read `--json`, never the files
  under `~/.claude/jobs/` (not a stable interface).
- A supervisor process hosts background sessions, so closing the terminal does not stop
  them. Sleep is survived; **shutdown is not** (sessions show as failed after shutdown).
- Interactive sessions in other terminals are NOT listed until backgrounded; subagents and
  teammates are not separate rows.

**For us.** This is exactly the Oct 9 crash problem (5-6 sessions, "what was I working
on"). Two moves: (a) run long work as background sessions (`claude --bg` / `←`) so it shows
up in `claude agents`, named per project; (b) the Command Center can read
`claude agents --json --all` for a live sessions panel. For interactive sessions that were
never backgrounded, the fallback is what we did on Oct 9: scan
`~/.claude/projects/*/*.jsonl` for the last user message per session.

## 3. Agent teams (official doc)

<https://code.claude.com/docs/en/agent-teams>. Experimental, off by default
(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). One lead session coordinates teammates that
each have their own context, share a task list, claim work, and message each other (vs
subagents, which only report back). Teammate model = the one named in the spawn prompt,
else the subagent definition's `model`, else `CLAUDE_CODE_SUBAGENT_MODEL`, else the lead's.
"Significantly more tokens than a single session"; best for research/review, competing
debugging hypotheses, separate modules; bad for sequential or same-file work.
Prior note: [[agent-teams-exploration]] (Jun 17).

## 4. @mirku21 "advisor opus + subagents haiku" (Oct 7 2026)

<https://x.com/mirku21/status/2107939129736700335> · 747k views, 15k bookmarks.
Pattern: Sonnet 5.5 drives (high effort), Haiku 5.5 subagents swarm file discovery and
docs, Opus 5.5 "on call" as advisor at three moments: before a plan locks (missed
invariants / schema contracts?), when a test breaks twice (root cause or rabbit hole?),
before done (hidden regressions?). "Plan on high. Delegate on medium. Keep Opus on call."
Includes a paste-in prompt that pins models + effort and writes advisor checkpoints into
CLAUDE.md ("show every config diff first"). Video = animated agent-tree terminal mockup.
Quoted article: "Harness Engineering: How to Build AI Workflows That Never Fall Apart"
(Sep 12): harness = everything outside the weights; Karpathy "model = CPU, context window
= RAM"; 3 layers (harness / loop / graph); 5 jobs of a personal harness (bounded contract
with non-goals + acceptance criteria; a map not an encyclopedia; externalize memory to
files; build sensors before autonomy; **dual-encoding: state the rule in text AND put a
mechanical gate behind it**); a `HARNESS.md` template (operating boundaries, project map,
verification protocol, "if a test fails twice on the same error: stop, print the log,
propose, wait"); two-pass prompting (execution pass, then adversarial review pass).
Verdict: pattern sound, two flags invented (see table).

## 5. @mirku21 "advisor fable" (Sep 29 2026)

<https://x.com/mirku21/status/2105040007127761242>. Same pattern one tier up: Opus 5.5 main
on high, explorer / worker / researcher subagents on Sonnet 5.5 medium, Fable 5.1 advisor.
Its prompt is the useful one because it is accurate: check `~/.claude/agents` and
`.claude/agents` for subagents that already fit before drafting new ones; set `effortLevel`
and `advisorModel`; **report anything that keeps the advisor off (`CLAUDE_CODE_DISABLE_ADVISOR_TOOL`,
`DISABLE_TELEMETRY`, flag-fetching vars) and `CLAUDE_CODE_EFFORT_LEVEL`, which overrides
subagent effort; change nothing**; one CLAUDE.md rule to consult the advisor before a large
plan, on a repeated error, and before calling a long task done.
**For us:** this is the closest to our setup (Opus main). Note we set `CLAUDE_EFFORT=xhigh`
in env; check whether that var behaves like `CLAUDE_CODE_EFFORT_LEVEL` for subagents.

## 6. @Bober_smart agent teams + "second brain" (Oct 3 2026)

<https://x.com/Bober_smart/status/2106444298849796475>. Architect (Opus 5.5 high, plans +
merges) / developers (Sonnet 5.5 medium in separate git worktrees) / adversary (Fable 5.1 at
contract boundaries, repeat failures, pre-PR) / script layer (Jev). Rule: adversary review
before any PR. Video = a richer agent-tree mockup (phase stepper plan > fork > delegate >
work > merge > review > ship, swimlane timeline, "who sees what" panel).
Quoted article "Claude Second Brain & Folder Workflow" (Jul 19, 8.2M views): flat markdown,
`notes/ people/ projects/` + `MEMORY.md`, `LEARNINGS.md`, `decisions.md`, a root CLAUDE.md
map, one topic per file, `@MEMORY.md` imports used sparingly; argues AGAINST Obsidian.
**For us:** we already run this (bsb-brain + MEMORY.md index); the "one topic per file" and
"decisions.md audit log" ideas match our memory system. The anti-Obsidian take is about
proprietary formats; our vault is plain markdown, so it does not apply.

## 7. Anthropic webinar: how Claude Code spends tokens (via @ZoriaHartson, Oct 3)

<https://x.com/ZoriaHartson/status/2106460701661253927> (26:35 video; full transcript
saved at `00-inbox/transcripts/anthropic-token-efficiency-webinar-2026-10.txt`, which is
gitignored, so it lives on this laptop only). The tweet's framing is wrong;
the content is an Anthropic staffer's webinar. Key points, in order:

- Every request = system prompt + tool definitions + environment + CLAUDE.md + skill/MCP
  names and descriptions + the conversation. "It's never just the prompt."
- Three token kinds: input (processed in one pass, cheap per token), output (one full pass
  per token, most expensive), **cached** (the identical prefix, a fraction of input price).
  "Cache is your biggest lever"; check the prompt-cache line in `/usage`, it should be high.
- **Pick the model per task.** Sonnet = generalist, Opus = expert, Fable = specialist,
  Haiku = quick assistant. The model multiplies everything else.
- Give context up front: `@file` in the prompt skips a Read round trip. Run `/context` in a
  fresh session to see what loads.
- CLAUDE.md = only what applies to EVERY task; move situational instructions to skills
  (only name + description load until used). An Anthropic skill audits CLAUDE.md + skills
  for instructions newer models no longer need (named on the call as a "Claude API prompt
  audit" skill; exact name unverified).
- Idle MCP servers are cheap but not free; switch off unused ones; prefer CLIs.
- **Command output stays in context for the rest of the session.** A test runner printing
  400 passing lines is under the auto-file threshold and rides along on every later request.
  Put the 2-3 daily commands in CLAUDE.md written with quiet reporters; send noisy runs to
  a subagent.
- **Effort heuristic: "did it not know enough (model) or not try hard enough (effort)?"**
  Medium effort on big models is excellent; higher effort = more output = more input later.
- Context only grows. `/clear` between tasks (a long session cost 2x in their demo).
  `/rename` then `/clear` keeps the old one resumable. `/compact` takes hints.
- **Cache breaks on:** `/compact`, `/clear`, a model switch, an effort change (except
  Fable 5.1). CLAUDE.md is read once at start; mid-session edits apply next session.
- **Cache TTL: about 1 hour on a plan, 5 min on API; subagents 5 min everywhere**
  (configurable). Compact BEFORE stepping away while the cache is warm, not when you come
  back (a cold compact re-reads everything at full price). Resuming an old session = one
  full uncached read.
- Subagents keep the main context small; total cost for that job can be a bit higher, but
  every later main turn is cheaper. Subagents can run a smaller model and their own effort.
- Admin: managed settings (default model, default effort, cache TTL, allowed MCPs,
  org-wide CLAUDE.md), OpenTelemetry for cache-read share per user, spend limits, "auto
  continue at usage limit."
- Three things to remember: set model / effort / MCPs at session start and leave them;
  be deliberate about what enters the conversation; keep sessions focused.

**For us (direct hits).** (a) Our long sessions resumed after a break or crash pay one full
uncached read; compact or `/wrap` before stepping away. (b) We switch effort mid-session
sometimes; that breaks cache. (c) Our guards and test scripts print a lot; quiet modes help
every later turn. (d) The 150k instruction-limit fight in `rule-loading-architecture.md` is
the same lesson as "CLAUDE.md only for every task, the rest in skills." (e) `CLAUDE_EFFORT=xhigh`
as a standing default is the "tempting but not always necessary" case.

## 8. @N01ennn "20 repos" + "Opus 5.5 studio" guide (Oct 8 2026)

<https://x.com/N01ennn/status/2108182955671580771>. List of 20 motion-design repos (skills:
claude-motion, claude-motion-design, motion-graphics-skills, claude-remotion-skill,
klik-anim-skill-creation, hyperframes-motion-reel-skill, product-launch-motion, animate,
motion-design-skills, hyperframes-student-kit; engines: heygen-com/hyperframes (HTML to
MP4), remotion (React video), remotion-dev/skills, GSAP; taste: LottieFiles
motion-design-skill, awesome-motion-design-agent-skills, Barty-Bart/motion-graphics,
motion-dev-animations-skill, motion, lottie-web). "Check each repo before you install."
The quoted article is the substance ("How to Turn Opus 5.5 Into a Studio", Oct 7):

- Per the article (Anthropic launch post, Sep 22 2026): Opus 5.5 ~Fable 5.1 level, ~40%
  cheaper than Opus 5; $4 / $20 per M in/out, cache reads $0.20 (60% less than Opus 5);
  1M context, 128K output; adaptive thinking always on, default effort medium.
- Motion pipeline: **a frame is a pure function of its number** (no clocks, no unseeded
  random); stage / renderer / encoder (ffmpeg, set pixel aspect) / checks. House rules:
  pure function of frame, the loop closes, color has a job, real data only, nothing ships
  unchecked. Brief: describe the mechanism, name every state, give real material, show a
  reference and say what NOT to take, ask for the plan before code.
- **Checks: a headless smoke test whose six counters must all read zero** (runtime errors,
  error banners, invalid colors, text off stage, text out of its panel, text overlaps); a
  seam check (frame 0 == frame one loop later, pixel-identical); a look (render stills,
  crop dense parts at 100%, read them; Opus reads images).
- Harness = guides (feedforward: CLAUDE.md, skills, docs) + sensors (feedback: tests,
  linters, review agents), per Birgitta Böckeler (Thoughtworks, martinfowler.com, Apr 2026).
  Sensors work best when their messages are written for an LLM. "When the same issue shows
  up twice, fix the harness, not the output." Keep quality left (fast checks pre-commit,
  expensive ones in the pipeline, drift detection continuously).
- arXiv 2609.00006 (Jul 2026) read the source of 11 coding agents: 7 subsystems around one
  loop; Mini-SWE-Agent covers all 7 in ~100 lines; loop sophistication predicts production
  readiness, not benchmark score; **none use LangChain-style frameworks or vector RAG over
  code (ripgrep, glob, tree-sitter, markdown context files)**; skills in 9 of 11, MCP in 8.
  18 recommendations incl.: start with a while loop and a bash tool; load tools on demand
  past ~15; compact at a fixed buffer, keep a verbatim recent tail; stay single-agent until
  you can point to real breadth-first work (multi-agent ~15x tokens).
- Loops (Claude Code team, "Loop engineering: getting started with loops", Jun 30 2026):
  agentic loop (you are the loop), `/goal` (evaluator checks your condition each time Claude
  tries to stop), `/loop` (interval, local, 7-day expiry, session-scoped), routines
  (`/schedule`, cloud). Addy Osmani: delegate the task, never the taste; the agent that did
  the work must not judge it; "the same command tried a third time with no change = stop."
  IBM's four debts when humans step out: unverified code, comprehension debt, intent debt,
  cognitive surrender.
- Example goals: `/goal ... Lighthouse >= 92 and LCP < 1.8s ... abort after two turns with no
  improvement. Stop after 10 turns.`; `/goal The smoke test reads zero on all six counters
  and frame 0 matches frame 720 pixel for pixel. Fix the worst failure each round. Abort if
  a round fixes nothing. Stop after 5 rounds.`

**For us.** The six-counter smoke test IS our `layout-collision-guard.md` (pairwise text
overlap + out-of-figure, measured not eyeballed) plus `render-and-look.md`. That makes a
concrete loop: `/goal` "render the real draw function at the worst-case label until the
collision counters read zero, abort if a round fixes nothing." The motion stack is a fit for
the parked [[llm-explainer-video]] / AstrosEDU video content, **on the personal laptop only**
(ffmpeg/Node binaries are blocked on the work laptop, see CLAUDE.md IT constraints).

## 9. @undefinedKi: Karpathy autoresearch + "5 levels of AI agents" (Oct 4 2026)

<https://x.com/undefinedKi/status/2106775535787323649>. **autoresearch**
(<https://github.com/karpathy/autoresearch>, ~92k stars, MIT, one NVIDIA GPU, forks for
Mac/Windows/AMD): the agent edits one file (`train.py`), commits, trains exactly 5 min,
keeps the change if the score improved else `git reset`, logs, repeats forever. The human
only edits `program.md` ("the code of your research org"). Simplicity rule: a tiny gain that
adds 20 hacky lines is thrown out; equal score with less code is kept. Instructions forbid
"should I keep going?" because the human may be asleep.
Quoted article (sponsored by Viktor, an AI-employee product; the method is still sound):
context / loop / Jev / harness / evals as five layers. Useful specifics:
- Context: middle-of-window documents get ~50-57% accuracy (Stanford), worse than none;
  stable content first for caching; tools: 58 definitions ate ~55k tokens; tool search took
  Opus 4 from 49% to 74%; under ~20 tools keep loaded, over that search.
- Loop: 4 parts or it is not a loop: a done condition, an EXTERNAL checker (self-correction
  only works with real feedback), a stop rule (pass / turn limit / last two outputs equal),
  a budget. Agent ~4x tokens of one call, multi-agent ~15x. Atlan hybrid: deterministic
  filter first (only ~14% of alerts reach the agent), max 3 cycles, under 50% confidence
  falls back to a fixed workflow. "Filter first, loop briefly, fall back."
- Jev, honestly: two weeks old; on email classification logistic regression 98.9% vs Jev
  98.6%; on phishing Jev 62.6% vs Claude Haiku 4.5 81.3%; "zero hallucinations" = schema-valid
  only; confidence is a ranking, not a probability. **Baseline first: label ~200 examples,
  train a basic classifier, make the vendor beat it.**
- Harness: Anthropic moved a benchmark 6 pts by changing only container resources;
  LangChain moved one 13.7 pts changing only the harness. **People approve 93% of agent
  permission prompts**, so real protection is actions that are not available. Hooks enforce
  ("never push to main" as a hook, not a prompt line). Re-read the harness every few months
  and delete what the model has outgrown.
- Evals: start from real failures; one behavioral check per case, run on the TRACE (e.g.
  "trace has get_order before send_reply"); check the judge against hand grades (Airbnb
  found ~3/4 of model-generated reference answers changed across runs); sample production;
  watch individual checks, not the overall pass rate.

**For us.** autoresearch fits anywhere we have one number, one file, a fixed run time: a
promotion-model feature search scored on a frozen held-out harness, or command-cv when it
un-shelves. Guardrails from our side: the metric must be leakage-proof first
(council-data-scientist), and the simplicity rule is exactly our "less code at equal score."
The evals advice maps onto our golden set: every rule's bug history is a failure case
waiting to become a behavioral check.

## 10. @Promixyz evidence loop + "Graph Engineering, 14 steps" (Oct 3 2026)

<https://x.com/Promixyz/status/2106462125874987099>. 10 repos for agents that prove what
they write: OpenScholar, PaperQA2 (find + cite), Docling (PDFs/tables to structured data),
Crawl4AI (web to clean evidence), RAGFlow (retrieval from complex docs), GraphRAG, LightRAG
(connect claims), Open Deep Research, DeepEval, Ragas (cross-check + evaluate). The loop:
question > split > search > extract > link facts > compare sources > check claims > cite >
report ("47 sources can become 30 claims, 30 claims 26 citations"). Video = "Evidence Weave"
18-task research board (see visuals note).
Quoted article "Graph Engineering with Claude: 14 steps": ask of every "then" whether data
crosses it; one job + one contract (schema) per node; **nodes think, edges transform**
(dedupe / sort / filter / reshape in code); fan out independent work to distribute context;
merge only when the data requires it; **the diamond (split > parallel work > reduce >
synthesize)**; route by a classified risk; **make findings survive an attack** (independent
critics for correctness, reproduction, security, contradicting evidence); failure is a local
event; loops need a convergence rule ("several consecutive rounds find nothing new") and
memory of REJECTED findings; tier models by node; pipelines beat global barriers; finally let
Claude design the graph. Six graphs worth building first include a deep research engine and
unknown-size bug discovery.
**For us.** Our Workflow tool is this; the "remember rejected findings" point is a gap in our
review loops. Docling is the candidate for ingesting PDFs (GC2 glossaries, external decks)
into the vault. Ragas/DeepEval fit [[coordinator-notes-rag]] if it moves forward.

## 11. @santtiagom_ on Uber's MCP Gateway (Oct 3 2026)

<https://x.com/santtiagom_/status/2106483024129147108> (Spanish summary) quoting UberEng's
article "Designing MCP Gateway" (<https://x.com/UberEng/status/2106071967619322330>).
Registry (control plane) + proxy (data plane) translating MCP to HTTP / gRPC / TChannel;
800+ MCP servers, 5,000+ tools. AutoCrawler scans the IDL registry, parses schemas, has an
LLM write agent-friendly tool descriptions, registers tools **disabled by default; discovery
does not imply exposure**; owners review and enable; every description change is an
approvable diff. Tool-level auth + PII redaction. Scale fixes: **Omni MCP** progressive
discovery (`discover_server`, `discover_tools`, `get_tool_schema`, `invoke_tool`), **Response
Projection** (request only the fields you need), **Code Mode** (`aifx mcp list|search|call`
writes output to files that agents grep; now Uber's default).
**For us.** Same shape as our GC2 work at small scale: the committed schema snapshot is our
registry, query CSVs grepped from disk are our Code Mode. If we ever expose GC2 queries to
an agent, copy "disabled by default + owner-approved descriptions" and progressive
discovery over `sql-queries-index.md` instead of loading every query.

## 12. @thegreatest_sv: awesome-ai-agents, 300+ projects (Oct 3 2026)

<https://x.com/thegreatest_sv/status/2106403149162455349> → <https://github.com/slavakurilyak/awesome-ai-agents>
(MIT, ~25 categories, machine-readable `awesome-agents.json` / `.yaml`). Stack read as a menu:
model > framework > tools > sandbox > memory > evals > product. Picks: Ollama, LangChain,
Open Interpreter, AutoGen, Aider; crewAI, mem0, AgentOps, Flowise, E2B, DSPy, MetaGPT,
PrivateGPT. Advice: search by category, check last commit before trusting a star count.
Video = the "KIOSA" 3D wireframe HUD (see visuals note).
**For us.** A lookup list before building agent tooling, nothing to install. Note the arXiv
finding above: production coding agents do not use these frameworks.

## 13. @milesdeutscher / @aiedge_ "Opus 5.5 + Jev" (Oct 7 2026) - SPONSORED

<https://x.com/milesdeutscher/status/2107908322368360477> → aiedge_ article "Opus 5.5 + Jev:
The Complete Setup". Jev (TypeSafe) is a decision-only model (choice / 1-10 score /
true-false + confidence); "Jev judges > Opus thinks > code executes." Install =
`claude plugin marketplace add typesafe-ai/skills` + API key. Workflow advice that holds up
regardless of vendor: map each step as Action (code) / Judgment (cheap) / Thinking (big
model); write ATOMIC questions ("Choice: urgent / needs reply / FYI / ignore" not "is this
important?"); route by confidence (high > code acts, medium > big model, low > human); keep
every question + threshold in one config file and log each decision with its score; add an
"uncertain" option; use the cheap judge again as a final quality pass.
**For us.** Do not send Astros data to a third-party judge API. The pattern is reusable
in-house: a cheap first-pass ranker over a batch (like this link batch) with the expensive
read only on the top items, with a logistic baseline first (section 9).

---

## Action steps (ranked by value / effort)

1. **[S] Start running long work as background sessions** (`claude --bg "..."` or `←` in a
   session), named per project, so `claude agents` is the board after any crash. Zero build.
2. **[S] Habits from the webinar:** compact or `/wrap` before stepping away (not after);
   don't change effort/model mid-session; `/clear` between unrelated tasks; check the
   cache line in `/usage` once.
3. **[S] Try the advisor on one bounded high-stakes task** (`claude --advisor opus` for that
   session), then read `/usage` to see what it cost on our transcript sizes.
4. **[M] Command Center sessions panel** from `claude agents --json --all` + a transcript scan
   for interactive sessions. Spec in [[agent-session-visuals-2026-10-13]].
5. **[M] Quiet-mode pass on our guards** (`test_rule_routing.py`, layout guards): print the
   failures and one summary line, not every pass, since that output rides along all session.
6. **[M] A `/goal` recipe for visuals:** "worst-case render until the layout-collision
   counters read zero; abort when a round fixes nothing; stop after 5." Ties
   `render-and-look.md` to a loop.
7. **[L, later] autoresearch-style overnight search** on a frozen promotion-model harness,
   only after the eval is leakage-audited.

Related: [[loop-engineering]] · [[agent-engineering-layers]] · [[agent-teams-exploration]] ·
[[council-knowledge-base]] · [[context-library]] · [[Command-Center]]
