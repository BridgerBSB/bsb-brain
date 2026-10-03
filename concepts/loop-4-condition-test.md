---
type: concept
topic: loop-engineering
created: '2026-06-17'
---
# The 4-Condition Test (build a loop only if ALL hold)

Before turning a task into an automated [[loop-engineering|loop]], it must pass
**all four** — miss one and the loop costs more than it returns.

1. **The task repeats** (≥ weekly). A loop amortizes its setup across runs. One-off → a good prompt is faster.
2. **Verification is automated** — a test, type-check, linter, or build can *fail* the work without you in the room. No automated gate = you're back in the chair reading every diff (the job the loop was meant to remove).
3. **Token budget can absorb the waste** — loops re-read, retry, explore. Obvious to people with free tokens; reckless on a metered $20 plan.
4. **The agent has senior-engineer tools** — logs, a repro environment, the ability to run its own code and see what breaks. Without these it iterates blind.

## The 30-second tactical checklist (per specific task)
Adds two more gates on top: a **hard stop** (token/iteration/time cap) and a
**human review gate** before anything irreversible (merge, deploy, dep change).

**Good first loops:** CI-failure triage, dependency-bump PRs, lint-and-fix passes,
flaky-test reproduction, issue→PR drafts on a codebase with strong tests.
**Bad first loops:** architecture rewrites, auth/payments, production deploys,
vague product work — anything where "done" is a judgment call. There, one
well-aimed prompt still wins.

> Honest version: loop engineering is real, and most developers don't need it yet.

See [[minimum-viable-loop]] · [[loop-failure-modes]].
