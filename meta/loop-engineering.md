---
type: meta
topic: loop-engineering
status: captured
created: '2026-06-12'
---
# Loop Engineering — Context Preservation Workflow

How this vault fights **context rot** (the slow degradation of an agent's working
context across long sessions / many /clears) and the source material driving the
design. Durable home for the methodology — see [[README-dual-run]] and
[[mcp-setup]] for the system mechanics.

## What "context rot" is (and how the loop fights it)

Long agent sessions degrade: early facts fall out of the window, summaries lose
detail, decisions get re-litigated, and after a `/clear` the next session starts
blind. The vault counters this by moving context **out of the chat window and
into durable, retrievable notes**, then pulling only what each task needs.

| Rot symptom | Counter | Command / mechanism |
|---|---|---|
| Session starts blind after /clear | situation report from durable notes | `/context` |
| Day's work evaporates | structured capture before context is lost | `/log` → `05-daily/` |
| Lost the thread of the week | weekly rollup seeds next week | `/sunday` → `personal/reviews/` |
| Quietly working on the wrong thing | adversarial re-grounding | `/drift` |
| Bulk-loading 70 rules burns the window | one note per question, on demand | MCP retrieval (see [[mcp-setup]]) |

Loop: **`/log` (capture in) → `/context` + `/today` (context out) → `/sunday`
(close + seed next week)**. Writes only touch write-zones; `rules/` + `memory/`
stay read-only snapshots (facts are *proposed*, never written here).

## Daily run cadence

Run Claude Code **from `cd C:\Users\Owner\bsb-brain`** to get these commands.

- **Morning** → `/today` — top 3, the one thing, first 3 steps, what's slipping.
- **Session start (esp. after /clear)** → `/context` — where you left off.
- **Evening** → `/log` — dump the day; structures it + proposes memory facts.
- **Sunday** → `/sunday` — one win / one friction / one change, writes the weekly.
- **Scattered** → `/drift` — still on the locked plan?

---

## Source material — loop / context engineering (X threads, captured 2026-06-12)

> Captured via fxtwitter API (x.com blocks bot fetches with 402). Summaries +
> linked article titles below; underlying t.co article links not yet expanded.

### Loop engineering

- **@vibemarketer_** — "WTF is a loop visualized." → article *"WTF Is a Loop?
  Peter Steinberger vs. Boris Cherny"* (Matt Van Horn). Thesis: **a loop is
  "cron plus a decision-maker"** — the model autonomously decides next steps
  instead of hardcoded branches. *"The loop is only as good as its feedback;
  continuous review + validation gates are what make a loop trustworthy."*
  Evolution ReAct (2022) → orchestration (2026).
  https://x.com/vibemarketer_/status/2063989241089012050

- **@cyrilxbt** — Anthropic engineer: *"You're not supposed to prompt Claude.
  You're supposed to build a system that prompts itself."* Points: ~14% of
  context lost before you type; a **caching setup that hits 95% makes long
  sessions almost free**; the chat window is the slowest interface you have.
  → article *"How to Use Claude Skills to Automate Any Workflow (Full Course)."*
  https://x.com/cyrilxbt/status/2064189224442560563

- **@sairahul1** — Boris Cherny (Claude Code creator): *"I don't prompt Claude
  anymore. I write loops — and the loops do the work. My job is to write loops."*
  Peter Steinberger: *"You should be designing loops that prompt your agents."*
  → article *"Loops: What Every AI Engineer Needs to Know in 2026."*
  https://x.com/sairahul1/status/2064279904989147577

### Obsidian → agent brain (the write-back loop — most relevant to us)

- **@undefinedki** — ⭐ THE BLUEPRINT FOR THIS VAULT. *"Connect AI agents to your
  Obsidian and build a brain that learns on its own."* 5 steps:
  1. **Point an agent at the vault** — `npx obsidian-mcp /path/to/your/vault`
     (no plugins/keys), add to Claude Code config, restart.
  2. **Confirm it sees the brain** — "list the notes in my vault and summarize."
  3. **Give each agent one job + a write-back rule** — "research this, then save
     what you found as a new note in /brain with links to related notes." One
     researches, one summarizes, one plans — each writes output back.
  4. **Close the loop** — one line in every agent's instructions: *"read /brain
     before starting, write your result back when done."* Each task leaves the
     vault richer; the next run reads that first. **Compounds instead of
     resetting.**
  5. **You only steer** — review output, point at the next thing.
  > "The edge isn't better notes. It's a brain that feeds itself, so the work
  > gets sharper every cycle instead of starting over."
  https://x.com/undefinedki/status/2063637596148756702

- **@undefinedKi** — Affaan Mustafa won the Anthropic x Forum Ventures hackathon,
  open-sourced **"Everything Claude Code" (repo: `affaan-m/ecc`)** — a library of
  skills + specialized subagents + commands. Notably: **a subagent that optimizes
  memory so Claude stops forgetting earlier decisions around hour three**, and one
  that learns from past sessions so the setup gets smarter with use. MIT, runs in
  Claude Code / Cursor / Codex / OpenCode.
  https://x.com/undefinedKi/status/2063615286301839698

- **@eng_khairallah1** — article *"30 Obsidian Workflows, Plugins, and Setups That
  Most Users Don't Know"* (Obsidian + Claude; essential plugins / must-know
  workflows / advanced setups).
  https://x.com/eng_khairallah1/status/2061012675824644161

- **@DamiDefi** — quotes the same "30 Obsidian Workflows" article (12,900+ GitHub
  stars in <3 months). *"The ones who connect plugins, workflows, and Claude will
  turn their vault into working memory."*
  https://x.com/damidefi/status/2062092730436874360

- **@humzaakhalid** — "Karpathy's Obsidian vault, the brain behind a million-dollar
  company." → guide *"How to Build Your Second Brain using Obsidian (FREE)"* —
  folder structures, plugins, templates, and **six Claude prompts** for a PKM.
  https://x.com/humzaakhalid/status/2062890023553576971

---

## What to lift from these into THIS vault

- **The write-back loop (undefinedki #5)** — our `/log` already proposes memory
  facts, but the "every agent reads /brain first, writes result back" rule is
  stronger. Candidate: add a write-back line to the bsb-resources agents so code
  work also deposits learnings into the vault, not just the daily note.
- **Memory/compaction subagent (ecc #6)** — directly targets the "forgets around
  hour three" rot. Worth studying `affaan-m/ecc` for a memory-optimizer pattern.
- **Caching for cheap long sessions (cyrilxbt #2)** — prompt-cache discipline so
  long sessions stay affordable; pairs with the MCP retrieval cutover in [[mcp-setup]].

## Open TODOs
- [ ] Expand the t.co article links above (the long-form guides behind each tweet).
- [ ] Evaluate `affaan-m/ecc` memory-optimizer subagent vs our `/log` + memory-cleanup.
- [ ] Wire the MCP retrieval layer (verify `mcpvault` pkg + Config B → live `.claude/rules`). See [[mcp-setup]].
- [ ] Measure before/after token burn, then decide the auto-load cutover.
- [ ] Re-snapshot cadence for `rules/` + `memory/` (currently manual `cp -r`).

---

## Loop Engineering Canon — the engineering layer (added 2026-06-17)

The notes above are the *vault* loop (context preservation). This section is the
*engineering* loop — the discipline from Addy Osmani / Anthropic for making an
agent run a senior-engineer pipeline on its own. Concept notes:
[[loop-4-condition-test]] · [[maker-checker-split]] · [[loop-state-file]] ·
[[minimum-viable-loop]] · [[loop-failure-modes]].

### The split that matters most — taste vs law

- **CLAUDE.md = taste** — advisory. Followed *most* of the time, not 100%.
  (conventions, "match local style", "ask before building".)
- **Hooks = law** — deterministic. Fire *every* time, no exceptions.
  (lint after edit, block broken commits, capture session on clear.)

Agents are great at following patterns and still perfectly capable of skipping
the one command you care about. Put non-negotiables in **hooks**, not CLAUDE.md.

### The 9-step senior loop (maps to Claude Code primitives)

1. **Explore** — read-only `Explore` subagent maps the area in its own context.
2. **Plan** — plan mode; approve the approach before any code exists to throw away.
3. **Standards** — CLAUDE.md loaded every session (taste).
4. **Build small** — one reviewable piece at a time, not a giant diff.
5. **Enforce** — hooks run lint/tests deterministically (law).
6. **Prove** — write + run tests; "done" = tests passed, not "looks plausible."
7. **Review** — a *second* subagent (clean context, critic mandate) reviews the diff.
8. **Fix + re-check** — close the loop; re-test + re-review until clean.
9. **Ship** — a `/ship` slash command wraps the whole pipeline into one trigger.

### The 14-step roadmap, distilled

**Loop engineering = replacing yourself as the prompter.** The leverage moved
from *typing prompts* to *designing the system that prompts*. Don't rush to build
one — see [[loop-4-condition-test]] (build only if task repeats weekly +
verification is automated + budget absorbs waste + agent has senior tools).

**The 5 building blocks** (and what we already have):

| Block | What | Our primitive |
|---|---|---|
| **Automations** (heartbeat) | schedule/event trigger; `/loop` (cadence) vs `/goal` (until a *checker* says true) | `/loop`, `ScheduleWakeup`, `CronCreate`, Routines, hooks |
| **Worktrees** | parallel agents, no file collision | `git worktree`, `isolation: worktree` on subagents |
| **Skills** | project knowledge written once, read every run | `.claude/skills/` (we have ~15) |
| **Connectors (MCP)** | loop touches real tools | obsidian + recall MCP; GitHub via `gh` |
| **Sub-agents** | keep the **maker** away from the **checker** | `Agent` tool, `.claude/agents/`, Workflow tool |

**The state file** is the spine: *the agent forgets, the repo does not.* A
markdown `STATE.md` (or our `05-daily/` + `memory/`) holds done/next/lessons
**outside** the conversation, so the next run resumes instead of restarting.
Pair with a standing spec (VISION/AGENTS/CLAUDE.md) reread each run: state =
where it is, spec = where to go. See [[loop-state-file]].

**Metric that matters:** *cost per accepted change* (>50% accept rate, or the
loop is losing). Not tokens, not tasks attempted.

**Don't loop:** architecture rewrites, auth/payments, vague product work,
anything where "done" is a judgment call. A single well-aimed prompt still wins.

### Where OUR setup already is (the honest audit)

We already hold nearly every loop primitive: skills (~15), hooks (now incl.
SessionEnd auto-capture — see [[hooks-setup]]), `/loop`, `ScheduleWakeup`,
`CronCreate`, recall + obsidian MCP, worktrees, subagents, the Workflow tool,
and a durable state layer (`05-daily/` + `memory/`). **The gap is not
primitives — it's (a) the rules-bloat that breaks subagent spawning from
bsb-resources, and (b) wiring these into actual gated loops.** See
[[loop-failure-modes]] for what to avoid when we do.
