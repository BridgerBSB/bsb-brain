---
type: concept
topic: loop-engineering
created: '2026-06-17'
---
# The State File — "the agent forgets, the repo does not"

The piece that sounds too dumb to matter and is actually the spine of every
working [[loop-engineering|loop]]. Agents have short memory by default — what
they learn this session is gone tomorrow **unless you write it down outside the
conversation.**

A markdown `STATE.md` (or a Linear board / GitHub Issues) holds:
- **Last run** — timestamp + what happened
- **In progress** / **Completed** / **Escalated to humans**
- **Lessons learned** (write here, NOT in chat — e.g. "this Windows runner needs bash, not PowerShell")
- **Stop conditions met since last review**

A loop without persistent state restarts every run; a loop with state **resumes**.

## State vs spec
Pair the state file with a standing high-level spec (`VISION.md` / `AGENTS.md` /
`CLAUDE.md`) the agent rereads each run. **State tells it where it is; the spec
tells it where to go.** The reread is the mitigation for goal drift over long
sessions (see [[loop-failure-modes]]).

## Our equivalent
This vault *is* the state file. `05-daily/` (what happened), `memory/` (durable
facts), and now the **SessionEnd auto-capture hook** ([[hooks-setup]]) which
drops every session into `00-inbox/` automatically — so multi-agent days resume
instead of restart. CLAUDE.md is the standing spec.

See [[minimum-viable-loop]].
