---
type: meta
created: 2026-08-17
tags:
  - meta
  - agents
  - context-engineering
  - claude-code
  - tooling
---
# Agent Engineering Layers + the Retrieval Decision Tree

Written 2026-08-17 after a live context burn in `bsb-resources`, cross-checked
against the Aug 2026 link batch Zac fed (five-layer stack, 6 agent patterns,
second-brain skill repos). Companion to [[loop-engineering]] (the daily cadence)
and [[team-process-architecture]] (how teams/loops run). This note is the
**retrieval half**: which tool to reach for, and what a tool call actually costs.

---

## 0. The incident that produced this

Task: confirm the PD Goals Monday no-play gate is 7 days.

1. `Grep -n "played-within|get_last_game_dates"` on `generate_goals_batch.py`
   returned lines 22, 25, 123, 302-323. **The answer was in that output**: the
   flag, `default=7`, and the gate block.
2. I then called `Read` on the same file for exact cutoff arithmetic.
3. The harness matched the path against every `paths:` glob in `.claude/rules/`
   and injected **40 rule files, roughly 140K tokens**, before I saw one line.

The three extra sentences of precision cost 140K. `Grep -C 20` would have cost
about 1K.

## 1. The cost model nobody sees

> **The cost of opening a file is a property of its PATH, not its size.**

`pd-goals/scripts/generate_goals_batch.py` is a few hundred lines. Opening it
costs ~140K because of where it sits:

| glob | rules pulled |
|---|---|
| `**/*.py` | db-columns (26K), level-codes (32K), tracking-schema (18K), gc2-metrics, pitfalls, db-joins, woba-rules, fielding, ip-calculation ... |
| `**/scripts/*.py` | xwoba-canonical, xslg-canonical ... |
| `pd-goals/**/*` | pd-goals.md (40K) + its 6 satellites |

Three overlapping registrations, one path. A tool call has **two** costs: the
result, and what the harness does *because of* the call. Only the first is
visible when you decide to make it.

**This is a feature, not a bug.** Those globs are why nobody in this repo
guesses a DB column or ships a wOBA denominator with SH in it. The tax buys a
real guard. It is just charged at a flat rate whether or not you need the goods.

## 2. Which LAYER does a fix belong to

From [@sairahul1's five-layer stack](https://x.com/sairahul1/status/2078781824160166070)
(prompt to context to harness to loop to graph). Naming the layer tells you
where a fix goes, and stops you patching the wrong one:

| Layer | What it is | Our instance | Fix for the 140K burn? |
|---|---|---|---|
| **Prompt** | the words in the turn | the ask | No. "Be careful with Read" does not survive a context reset |
| **Context** | what is in the window and why | Grep-vs-Read choice | **Yes, partly** - the discipline in section 3 |
| **Harness** | tools, injection, permissions | `paths:` globs in `.claude/rules/` | **Yes, mostly** - lever #1, tighten the globs |
| **Loop** | when the agent re-enters | `/brief` `/wrap` `/monday` | No |
| **Graph** | multi-agent coordination | Workflow / subagents | Sometimes - a subagent eats the injection in ITS window |

The lesson: **a repeated context failure is almost always a harness bug wearing
a prompt-layer costume.** Telling the model to behave is the weakest available
fix; changing what the harness injects is the strongest.

## 3. THE DECISION TREE (retrieval)

Run top to bottom. First match wins.

```
Do I already have the answer in context?
  YES -> STOP. Answer. (<- today's failure lived here)
  NO  v

Is it EXTERNAL (web/X/docs)?
  YES -> fetch ladder, external-resource-capture.md
         X -> api.fxtwitter.com | general -> WebSearch excerpts
         (jina r.jina.ai now returns 401, Aug 17 2026 - see section 6)
  NO  v

Do I need to EDIT this file?
  YES -> Read it. Injection is CORRECT here; it is the guard you want
         before touching a query. Pay it deliberately.
  NO  v

Do I need ONE fact? (a flag, default, column, line number, does-X-exist)
  YES -> Grep with -n and -C 15. NEVER Read.
         Grep does not trigger path injection.
  NO  v

Do I need to know WHICH file, out of many?
  YES -> Grep output_mode=files_with_matches first.
         Then Read only the winner, if the EDIT branch says you must.
  NO  v

Is the answer a CONCLUSION over many files whose text I do not need?
  YES -> subagent (only if the operator has opted in - Zac's config
         forbids unrequested Agent calls). The subagent eats the
         injection in its own window and returns the conclusion.
  NO  v

-> Read, and accept the injection knowingly.
```

**The one-line version:** *cheapest tool that can produce the answer, and check
whether you already have it first.*

## 4. The pattern vocabulary (for naming what we build)

[@hanakoxbt's 6 agent patterns](https://x.com/hanakoxbt/status/2078979637804187793),
which is Anthropic's own "building effective agents" taxonomy. Useful because it
separates **workflows** (you wrote the path) from **agents** (it writes its own):

1. **prompt chaining** - fixed steps, each checking the last
2. **routing** - classify the input, send it to the tool built for it
3. **parallelization** - fan out, then merge or vote
4. **orchestrator-workers** - lead decides the subtasks at runtime
5. **evaluator-optimizer** - one writes, one grades, loop until it passes
6. **autonomous agent** - no fixed path

"Most production systems people call agents are pattern 1, 2, or 5 with good
error handling." That is true of ours: the Monday cascade is **1**, `/research`
is **1**, the fetch ladder is **2**, the council reviews are **5**, and the
`Workflow` tool is **3/4**. Section 3's decision tree is a **routing** table,
pattern 2 applied to retrieval instead of to user input.

## 5. What to actually change in our setup

| # | Change | Layer | Status |
|---|---|---|---|
| 1 | Tighten `paths:` globs so a `.py` read pulls ~6 relevant rules, not 42 | harness | **PENDING** (lever #1, `rule-loading-architecture.md`) |
| 2 | Collapse `settings.local.json` 392 permission entries to wildcards (~25K) | harness | **PENDING** (lever #3) |
| 3 | Prefer `Grep -C` over `Read` for one-fact lookups | context | **adopt now**, section 3 |
| 4 | Never move a BLOCKING rule out of always-on to save tokens | harness | standing NO (lever #4, rejected) |

Levers #1 and #3 are config-only with zero knowledge-loss risk and are the
whole fix. #4 stays rejected: a missed BLOCKING rule is a shipped bug, which is
the exact failure the rules system exists to prevent.

## 6. Fetch-ladder correction (Aug 17 2026)

**`r.jina.ai` now returns HTTP 401 on every URL tested** (2 Google Docs, 3
Instagram reels). It previously worked as the general-purpose reader proxy and
is documented as rung 2 in `external-resource-capture.md`. It appears to require
an API key now. Revised ladder:

1. X/Twitter to `api.fxtwitter.com` (still works, 9/9 this session)
2. General to direct `WebFetch` (recovers Google Docs **titles** but not bodies
   behind a sign-in wall)
3. ~~jina~~ **dead without a key**; go straight to `WebSearch` excerpts
4. Still blocked, capture the gap explicitly with the user's framing

Instagram is fully walled to both direct and proxy fetch. For reels the durable
answer is the user's own framing plus a transcript if they can supply one,
which is itself one of the techniques in the reels Zac sent.

## 7. Sources

- [@sairahul1 - prompt/context/harness/loop/graph engineering](https://x.com/sairahul1/status/2078781824160166070) (Jul 19 2026) - the five layers; section 2 is built on it
- [@hanakoxbt - 6 agent patterns](https://x.com/hanakoxbt/status/2078979637804187793) (Jul 19 2026) - Anthropic's taxonomy; section 4
- [@sairahul1 - 42 Claude skills as an org chart](https://x.com/sairahul1/status/2077733367358079309) (Jul 16 2026) - skills-as-departments; the packaging end of the same idea
- [@cyrilXBT - Hermes + Obsidian + NotebookLM](https://x.com/cyrilXBT/status/2082716319565386132) (Jul 30 2026) - "writes its own skills, maps its own knowledge"
- [@kirillk_web3 - kepano's Obsidian skills](https://x.com/kirillk_web3/status/2086495974986223898) (Aug 9 2026) - already vetted here: [[obsidian-skills-kepano-eval]]
- [@AlexFinn - reverse prompting](https://x.com/alexfinn/status/2082982462012227648) (Jul 31 2026) - have the agent prompt YOU
- Related in-vault: [[loop-engineering]] - [[context-preservation-roadmap]] - [[team-process-architecture]] - [[context-library]]
