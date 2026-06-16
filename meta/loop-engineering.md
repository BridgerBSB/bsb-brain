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
