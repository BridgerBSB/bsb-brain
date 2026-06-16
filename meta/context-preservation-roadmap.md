---
type: meta
topic: context-preservation
status: approved
created: '2026-06-13'
---
# Context-Preservation Roadmap — fighting rapid context rot

User endorsed (2026-06-13): *"all of these sound great… we need to best utilize
Obsidian to preserve memory/context rot which has been happening very rapidly."*
Three approved improvements, ordered by how directly each fights rot. Source
threads + mechanics in [[loop-engineering]]; fetch/capture convention now a live
rule (`.claude/rules/external-resource-capture.md`, synced to all 4 worktrees).

## 1. Write-back rule — HIGHEST LEVERAGE (do first)

**What:** add one line to the bsb-resources CODE agents' instructions —
*"read the brain before starting, write your result/learnings back when done."*
Today only `/log` (run manually from the vault) deposits context; code work in
`bsb-resources` does NOT feed the brain. This closes that gap so every code
session leaves the vault richer and the next session starts from it instead of
from zero. Source: @undefinedki (the 5-step self-feeding-brain blueprint).

**Why it fights rot most:** rot is worst *during* long code sessions and across
`/clear`s. A write-back rule makes the code agent itself the capturer, so context
survives without the user remembering to `/log`.

**Open design Qs:** where the code agent writes (a `projects/<app>/` note vs a
dated log); how it reconciles with the live `.claude/` memory writer (one-writer
discipline — propose-to-memory vs write-to-vault-write-zone).

## 2. Memory-optimizer subagent — STUDY (`affaan-m/ecc`)

**What:** Affaan Mustafa's open-source "Everything Claude Code" repo (`affaan-m/ecc`,
MIT) includes a subagent purpose-built to **stop Claude forgetting earlier
decisions around hour three** + one that learns from past sessions. Study it
against our existing `/log` + `memory-cleanup` skill; lift the
memory-compaction pattern if it beats ours. Source: @undefinedKi.

**Why:** directly targets the "forgets around hour three" failure the user is
hitting. Evaluate before building our own.

## 3. Prompt-cache discipline — ENABLER (pairs with MCP cutover)

**What:** structure sessions so the prompt cache hits high (~95%), making long
sessions almost free — so we can AFFORD to keep more durable context loaded /
retrieved. Source: @cyrilxbt (Anthropic-engineer framing: build a system that
prompts itself; the chat window is the slowest interface). Pairs with the MCP
retrieval cutover in [[mcp-setup]] (slim auto-load to `blocking-rules.md`, pull
the rest on demand).

**Why:** doesn't fight rot directly, but removes the cost objection to keeping
rich context — the economic enabler for #1 and the MCP layer.

## Sequence
1. Wire the **MCP retrieval layer** ([[mcp-setup]] Config B → live `.claude/rules`)
   + measure token before/after. *(Already the standing next step.)*
2. Add the **write-back rule** to bsb-resources code agents (#1 above).
3. Study **`affaan-m/ecc`** memory-optimizer (#2); adopt or skip with a reason.
4. Lock in **prompt-cache discipline** (#3) once the MCP cutover lands.

## Standing convention (now enforced by rule)
Every external link/resource the user feeds → fetched (fxtwitter for X, jina for
general) → captured to this vault with summary + source link, in EVERY branch.
See `.claude/rules/external-resource-capture.md`.
