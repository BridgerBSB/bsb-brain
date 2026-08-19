---
type: meta
created: '2026-06-29'
tags:
  - meta
  - teams
  - training
  - evals
  - ways-of-working
---
# 🎓 Team Training Loop — how the agents get better over time

The teams in [[team-process-architecture]] are only as good as their prompts, their context,
and what they've learned from past misses. This is the loop that **trains them** — turning
every defect and every catch into a permanent improvement. It's the maker/checker idea from
[[loop-engineering]] pointed back at the agents themselves.

The Council already proves the principle: it was **born from a single miss** (Claude called
R²=0.41 "strong" with no domain context → the Data-Scientist lens now always asks for
baseline-lift + adjusted R²). That reflex should be systematic, not accidental.

---

## The loop: Capture → Diagnose → Update → Eval

### 1. Capture (misses AND wins)
Every time an agent/council is wrong, OR a verify/L1 catches a defect, OR a call turns out
great — log a one-line **training case**: what was asked, what the agent did, what was right.
Sources already generating these: code-review findings, L1 parity diffs, council vetoes,
the bug-history sections in `.claude/rules/`.

### 2. Diagnose (why)
Was it a **prompt** gap (the lens didn't know to ask X), a **context** gap (it lacked the
fact / had stale memory), a **skill/rule** gap (no enforced check), or a **team-shape** gap
(needed a domain voice the 4 generalists don't have)?

### 3. Update (the fix lands somewhere durable)
| Diagnosis | Fix lands in |
|---|---|
| Prompt gap | the agent's definition (sharpen the lens's signature questions) |
| Context gap | a `.claude/rule`, a memory file, or leaner retrieval (curate the 73KB MEMORY) |
| Enforced-check gap | a skill or a BLOCKING rule (e.g. `render-and-look` was born this way) |
| Team-shape gap | add a domain voice (pitching-dev / draft) when generalists underperform |

### 4. Eval (regression test the team)
Build a **golden set** of past incidents and re-run the current agents against them: *would
they catch it now?* Seed cases (all real):
- R²=0.41 "strong" → does `council-data-scientist` demand baseline-lift + out-of-fold? ✅
- v2 wRC+ 0.41→0.09 MiLB-only mirage → does the Council flag inflated-by-easy-rows?
- FB%-as-fastball-usage misread → does `tracker-new-metric` force disambiguation first?
- org-code drop (29 of 30) → does a reviewer catch a cross-source JOIN without the CASE remap?
- stray-"P"-under-the-logo → does `render-and-look` gate the visual?
A miss on a golden case = the team regressed; fix before shipping new agent changes.

---

## Cadence + ownership
- **Continuous:** capture is automatic (it's the byproduct of L1 + code-review + council vetoes).
- **Weekly:** ride `/sunday` — review the week's training cases, run the golden set, land 1–2 updates.
- **Owner:** T3 (Research/Tooling Analyst) is the natural home once stood up; until then, the
  main loop does it during the backlog-governance pass (L3).

## What "better-trained" looks like (the goal)
Leaner context (curated memory + sharper rules, not more), agents that catch our *known*
failure modes by reflex, domain voices added only where generalists demonstrably miss, and a
golden set that grows every time we get burned — so we never get burned the same way twice.

Related: [[team-process-architecture]] · [[advisory-council]] · [[loop-engineering]] ·
[[ecosystem-map-and-process-architecture-2026-06-27]]
