---
type: meta
created: '2026-06-29'
tags:
  - meta
  - ai
  - claude-code
  - tooling
  - teams
  - context-library
source: instagram @raycfu carousel
---
# 🧰 Claude Code Toolkit — 10 repos worth knowing (@raycfu)

Captured from a 10-slide Instagram carousel by **@raycfu** ("10 Claude Code Repos that
actually matter," ~Jun 28 2026). Screenshots: `C:\Users\Owner\Downloads\IMG_8298–8307.png`
(Downloads is not durable — content captured here; archive or delete the PNGs when ready).

Several of these **directly assist with the agent teams** we just built — and two are
near-exact solutions to the loop-engineering gaps we flagged ([[loop-engineering]]:
gap 1 = the write-back rule, gap 2 = hooks-as-law). Tagged below.

---

## The 10

| # | Repo | ★ | What it is | What WE'd use it for |
|---|---|---|---|---|
| 1 | **Superpowers** | 148K | Full dev workflow for Claude: brainstorm → spec → plan → TDD → review → merge, with subagent orchestration. | ✅ **Already have it** — the `superpowers:*` skills are installed. Reference for the maker→checker loop. |
| 2 | **Karpathy Skills** (`forrestchang/andrej-karpathy-skills`) | 44K | One CLAUDE.md, four principles: stop overcomplicating, don't touch unrequested files, ask instead of guess, don't skip your own checks. | 🟡 **Adopt candidate** — bottles the discipline we enforce by hand. Install: `/plugin marketplace add forrestchang/andrej-karpathy-skills`. |
| 3 | **Repomix** | 21K | Packs an entire codebase into one AI-readable file (XML/Markdown/plain). | 🟡 **Adopt candidate** — feed a whole worktree to an agent in one shot (the ecosystem inventory we did manually; the org-wide parity audits). |
| 4 | **everything-claude-code** (`affaan-m/ecc`) | — (hackathon winner) | The most complete setup: 20 agents, 156 skills, 1,101 commands, 10 months of real use. | 📚 **Study** — already on our radar in [[loop-engineering]] for its **memory-optimizer subagent** (fights "forgets around hour 3"). |
| 5 | **wshobson/agents** | 25K | A team of production specialist subagents (strategy, dev, **security**, design, data, research). | 👥 **TEAM** — direct analog to our council + voltagent roster. The **security agents** are worth it for our Connect deploys. Compare vs our specialists. |
| 6 | **Claude Squad** | 5.6K | Terminal multiplexer running Claude/Aider/Codex in parallel — one builds a feature, one writes tests, one refactors, no interference (worktrees). | 👥 **TEAM** — an orchestration UI for the parallel-agent work we do via forks/Workflow. Alternative to managing crews by hand. |
| 7 | **Playwright MCP** (Microsoft official) | — | Browser automation: navigate, fill forms, click, scrape dynamic content on sites with **no API**. | 🟡 **Adopt candidate** — directly useful for the **indy-ball scraper** (Pioneer 405s / no-API league sites) and any web data we can't get via API. |
| 8 | **TDD Guard** | 1.7K | A **hook** that blocks a commit if Claude wrote code without tests first. Doesn't write tests for you — prevents skipping them. | 🔴 **TEAM / closes gap 2 (hooks-as-law)** — this is exactly the "non-negotiables go in hooks, not CLAUDE.md" move. Pattern to adopt for `metric-audit` + `render-and-look`. |
| 9 | **Claude Subconscious** | 2.4K | A background agent that watches the session, reads files, and **accumulates knowledge over time** — Claude remembers things you never told it. | 🔴 **TEAM / closes gap 1 (write-back loop)** — the self-feeding memory the undefinedki blueprint + our [[team-training-loop]] describe. Study before we hand-roll a write-back rule. |
| 10 | **awesome-claude-code** | 28.5K | The directory of everything worth knowing: skills, hooks, commands, plugins. Curated (only Claude can add → quality stays high). | 📑 **Bookmark** — we already have `awesome-claude-skills/` checked into the repo; this is the broader index. |

---

## What this means for US (the synthesis)

The carousel isn't random — **6 of the 10 are about running agent teams**, and the two
highest-leverage ones land squarely on the gaps we just named:

- **TDD Guard (#8) = our gap 2.** It's the reference implementation of *hooks-as-law*. We
  copy the pattern to make the `verifier`'s checks (metric-audit on a metric change,
  render-and-look on a visual) fire **deterministically**, not "if the agent remembers."
- **Claude Subconscious (#9) + ecc memory-optimizer (#4) = our gap 1.** Self-building,
  write-back memory — exactly what would automate our [[team-training-loop]] capture step
  instead of relying on the skeptic to manually flag "add to the golden set."
- **wshobson/agents (#5) + Claude Squad (#6)** are external versions of the roster +
  parallel-crew orchestration we just stood up — worth mining for patterns (especially the
  security agents for Connect deploys).
- **Karpathy Skills (#2), Repomix (#3), Playwright MCP (#7)** are adopt-candidates for
  discipline, whole-repo context, and no-API scraping respectively.

**Next move if we want it:** before hand-rolling the write-back rule + hooks layer, evaluate
TDD Guard (#8) and Claude Subconscious (#9) — they may give us gaps 1 & 2 off the shelf.

Related: [[loop-engineering]] · [[team-process-architecture]] · [[team-training-loop]] ·
[[council-knowledge-base]] · [[context-library]]
