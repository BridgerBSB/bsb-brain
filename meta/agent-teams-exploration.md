---
type: meta
topic: agent-teams
status: exploration
created: '2026-06-17'
---
# Agent Teams — Exploration (NOT integration yet)

Learning how multiple agents coordinate. Explicitly exploratory — we are *not*
building this into the live workflow yet, just mapping the patterns. Pairs with
[[loop-engineering]] and [[maker-checker-split]].

## What an "agent team" is

`anthropics/knowledge-work-plugins` — a free open-source marketplace of
**role-based plugins** for Claude Cowork (also runs in Claude Code). Each plugin
turns Claude into one narrow specialist (Sales, Marketing, Finance, Legal, Data,
Product, Support, Productivity, Enterprise Search). Each contains 3 parts:

- **Skills** — domain knowledge, auto-pulled when relevant (you don't invoke).
- **Commands** — slash workflows (`/sales:call-prep`, `/data:write-query`).
- **Connections** — the tools that role plugs into via MCP (CRM, warehouse, Slack).

Install: `claude plugin marketplace add anthropics/knowledge-work-plugins` then
`claude plugin install <role>@knowledge-work-plugins`. Multiple installed roles
work together in one session (data pulls numbers → finance reconciles →
marketing reports). Plugins are just markdown → fork/edit freely. This is the
base layer Anthropic built Claude for Legal / Financial Services on.

## How agents coordinate (the patterns)

| Pattern | What | Our primitive |
|---|---|---|
| **Maker–checker / evaluator–optimizer** | one generates, a *second* (different instructions/model) critiques, repeat. The maker is "too nice grading its own homework." (Anthropic's Dec-2024 pattern, renamed in 2026.) | two `Agent` calls; or the Workflow `pipeline` review stage. See [[maker-checker-split]] |
| **Orchestrator–worker** | a lead delegates to specialists, folds results back | main session + subagents; the Workflow tool |
| **Isolation** | each agent in its own context window → no cross-pollution | every `Agent` call is isolated by default |
| **Worktrees** | parallel agents each get a fresh git checkout → edits can't collide | `isolation: worktree` |
| **Shared state / handoff** | agents pass work via a state file or handoff store | `recall` MCP (`checkpoint`/`handoff`/`session_close`); a shared `STATE.md` |

Typical split: **explorer (fast/read-only) → implementer → verifier (strong
model, high effort).** The verifier is the *reason you can walk away* during a
loop. Subagents cost more tokens (each runs its own model + tools) — spend them
where a second opinion is worth paying for.

## Speculative — a PD-analytics agent team (FUTURE, not a build order)

If we ever wire this for the baseball work, a plausible team:

- **SQL-verifier** — every query checked against schema before it runs (we
  already have the `baseball-sql` skill; this would be the agent form).
- **Metric-parity checker** — the `metric-audit` skill as a standing verifier
  across the 3 surfaces (tracker / KPI / PD-Goals).
- **Report-builder** — implements the PDF/app change.
- **Skeptical reviewer** — clean-context critic on the diff before commit.
- Shape: explorer → implementer → parity-checker → reviewer, gated.

## Honest caveats

- **Cost** — a 4-agent team multiplies token spend per task. Justified only for
  repetitive, machine-checkable work (see [[loop-4-condition-test]]).
- **The bloat blocker (live, 2026-06-17)** — subagents spawned from
  `bsb-resources` currently **die** ("prompt too long") because the ~310k
  auto-loaded rules exceed a subagent's window. **Any agent-team experiment is
  blocked until the rules-bloat is fixed.** That's the prerequisite, not the
  team itself.
