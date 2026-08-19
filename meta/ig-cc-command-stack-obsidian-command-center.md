---
type: meta
domain: ai-workflow
status: captured
created: 2026-07-16
source: IG reels (chase.h.ai DazC8iapXvQ + agentic.james Da1rowXkniP)
---
# IG Reels — Claude Code Slash-Command Stack + Obsidian Command Center

Two IG reels Zac fed Jul 16 2026, fully transcribed (Whisper base on the audio +
on-screen frame read, not caption-only). Both creators already in [[context-library]].
Verdicts mapped to OUR stack. Pairs [[loop-engineering]] · [[fable5-use-cases]] ·
[[claude-code-obsidian]] · [[obsidian-optimization]] · [[obsidian-skills-kepano-eval]].

---

## Reel B — @agentic.james "god tier Claude Code stack" (70s)
<https://www.instagram.com/reel/Da1rowXkniP/>

**Full transcript (audio):** "Claude Code `/ultraplan` → `/goal` → `/agents` →
`/ultrareview`. Probably the ultimate native Claude Code slash-command stack of the
new features they added recently. What each does + how to string them:
- **`/ultraplan`** deploys a bunch of subagents **in the cloud on Anthropic servers**
  to create a crazy ultra plan. If you're smart, you recreate ultraplan **locally**
  and run it yourself.
- Once you have the plan, **`/goal`** has Claude Code **loop over that plan until it
  achieves the actual goal**. You can literally loop for days on end.
- **`/agents`** lets you zoom out on that session and **run it in the background** —
  so `/goal` keeps looping while you start a whole **new parallel session**.
- Once a session hits its goal, zoom back in and **`/ultrareview`** — same as
  ultraplan except it deploys cloud subagents to **review all the code** the
  `/goal` loop produced. If you're really smart, do this one **locally too** so you
  don't burn your ultrareview **credits**.
Learn more (long-running agentic loops + orchestration + local slash commands) →
his paid Skool community, link in bio."

**Verdict — mostly CONFIRMS our stack; one genuinely-new candidate.** This is
maker→checker loop-engineering ([[loop-engineering]]) under marketing names:
| His command | Our equivalent | Have it? |
|---|---|---|
| `/ultrareview` (cloud subagent code review) | `/code-review ultra` (multi-agent cloud review of the branch) | **YES, exact** |
| `/goal` (loop until goal met) | `/goal` + `goal-hook-hygiene` rule (Stop-hook loop) | **YES** |
| `/agents` (background + parallel sessions) | Agent tool, `isolation:'remote'`, Workflow tool, [[advisory-council]] | **YES** |
| `/ultraplan` (cloud subagent fan-out to build a plan) | GSD `/plan-phase` + plan mode (LOCAL, single-context) | **PARTIAL — no cloud-fanout planner** |

- **His actual tip worth keeping:** cloud commands burn billed credits — run the
  **local** equivalent when you can (for us: `/code-review high|max` in-session vs
  billed `/code-review ultra`; local plan vs a remote fan-out). Cost discipline, not
  a new capability.
- **The one gap:** we have no "spawn N cloud/remote agents to *draft a plan*" command
  — our planning is local + single-context. Candidate: a Workflow-tool judge-panel
  planning step (N approaches → score → synthesize), optionally `isolation:'remote'`.
  Low priority; GSD plan-phase already covers 90%.

---

## Reel A — chase.h.ai "Obsidian command center" (47s)
<https://www.instagram.com/reel/DazC8iapXvQ/>

**Full transcript (audio):** "You can do more with Obsidian + Claude Code than just
create knowledge graphs. **Turn Obsidian into a command center for your Claude Code
automations and skills.** All my metrics get pulled in across my social channels.
**These buttons are tied to my most-used automations/skills**, and the reports they
generate are visible right here. Click **Morning Brief** → it pops up in the
**activity feed** and I see the entire report. Advantage over **always sitting in the
terminal**: visualizations + metrics you wouldn't get there. And inside Obsidian you
can set the **terminal to live inside the same dashboard** — best of both worlds."

**On-screen dashboard (read from frames) — the actual layout:**
- **Metric cards** top row: YouTube subs 149K / views 12.7M, IG 220K, TikTok 133.3K
  (his are social; a **PULL METRICS** button refreshes them).
- **Command-button grid** (each fires a Claude Code automation/skill): PLAN TOMORROW ·
  MORNING BRIEF · INBOX BRIEF · DEEP RESEARCH · YT PIPELINE · WEEKLY REVIEW · VAULT
  CLEANUP · DAILY CLEANUP · CONTENT CHANNEL · NEXT RESEARCH.
- **Activity/cascade feed** — dated log lines of what the agents did ("blog live,
  LinkedIn scheduled 9AM, three long-forms ~102K views…").
- **"YouTube — What's Trending"** research panel (titles/creators/views).
- **Embedded terminal** pane + the **Obsidian graph view**.

**Verdict — ADOPT (we've flagged this before, this reel is the finished picture).**
This is the "visual agentic OS dashboard wired to Obsidian" already logged as
[[fable5-use-cases]] use-case 03. We run the vault as text+MCP but have **no visual
dashboard with clickable command buttons + activity feed**. Concrete BSB build:
- **One dashboard note** via kepano **obsidian-bases** (already ADOPT in
  [[obsidian-skills-kepano-eval]]) + button plugin.
- **Metric cards** (ours ≠ social): pin freshness, tracker/deploy status, delivery
  counts, open `verification-backlog` count.
- **Button grid** → our existing skills: `/today` `/brief` `/monday` `/sunday`
  `/log` `/drift` `/wrap` `/sync` `/dry-monday`.
- **Activity feed** = `05-daily/` notes + cascade logs surfaced inline.
- Optional embedded terminal pane.

## Links
[[context-library]] · [[loop-engineering]] · [[fable5-use-cases]] ·
[[claude-code-obsidian]] · [[obsidian-optimization]] · [[obsidian-skills-kepano-eval]] ·
[[advisory-council]] · [[vault-map]] · [[MOC-baseball-analytics]]
