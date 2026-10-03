---
type: concept
topic: loop-engineering
created: '2026-06-17'
---
# The Minimum Viable Loop

If a task passes the [[loop-4-condition-test]], build the **smallest** loop that
works before anything fancy. Four parts, no swarm:

1. **One automation** — a scheduled run that fires on a cadence and stops on a clear condition. `/loop` (re-run on cadence) or `/goal` (run until an independent checker says a condition is true). In Claude Code: `/loop`, `ScheduleWakeup`, `CronCreate`, Routines.
2. **One skill** — a single `SKILL.md` holding the project context the agent would otherwise re-derive from zero every run.
3. **One state file** — see [[loop-state-file]]. Tomorrow's run resumes instead of restarting.
4. **One gate** — the test / type-check / build that fails bad work automatically. This is the part that decides whether the loop helps or just spends.

## Build order matters (don't skip ahead)
Get **one manual run reliable** → turn it into a **skill** → wrap it in a **loop**
→ then **schedule** it. Skipping ahead is how loops fail in production.

## The metric
**Cost per accepted change** — not tokens spent, not tasks attempted. If your
accepted-change rate is below 50%, you're doing the review work the loop was
supposed to save, and the loop is losing.

See [[maker-checker-split]] (the gate is often a checker agent) · [[loop-failure-modes]].
