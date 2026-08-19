---
created: 2026-07-06
type: reference
topic: claude-code workflow
source: chat session 2026-07-05 — Claude explained each skill, Zac asked to
  /document it
---
# Claude Session Skill Sequence — Cheatsheet

One-line-each reference for the core slash-command skills and the order they
run in a working session. Captured 2026-07-05.

**The canonical loop:**
`/brief` → (research / ingest as needed) → `/spec` → `/plan` → `/implement` → `/reviewloop` → `/wrap`
— with `/orchestrate` as the "run the whole middle autonomously" shortcut.

## Session lifecycle

- **/brief** — Loads the BSB Brain vault state (`last-state.md`, where you left off) at the start of a session so work resumes with context instead of from zero.
- **/wrap** — Closes a session cleanly: writes last-state, logs the day, syncs the vault snapshot, refreshes the dashboard, and then it's safe to `/clear`.

## Knowledge / research

- **/explain** — Explains anything simply in chat with a visual and an analogy, or re-explains the previous answer in plainer terms.
- **/research** — Researches links or topics on the web AND captures the findings into the BSB Brain vault; the turn isn't considered done until the vault write is verified.
- **/document** — Saves anything Zac feeds (link, file, CSV, model output, paste, idea) into the BSB Brain — categorized, dated, never dropped — so the council agents can use it later.
- **/ingest** — Feeds a whole source (URL, repo, doc, long paste) into the BSB Brain as multiple interlinked notes, rather than one capture note.
- **/deep-research** — A heavier research harness: fans out web searches, fetches sources, adversarially verifies claims, and synthesizes a cited report. (Unlike /research, its output is the report itself, not primarily a vault capture.)

## Build pipeline (GSD flow)

- **/orchestrate** — Alias for autonomous multi-phase/multi-agent execution (`gsd:autonomous` or a Workflow): runs discuss → plan → execute across all remaining phases without driving each step manually.
- **/spec** — Alias for the GSD spec step: defines WHAT we're building — requirements and scope — before any code exists.
- **/plan** — Alias for `gsd:plan-phase`: turns the spec into an executable phase plan (PLAN.md) with task breakdown and verification.
- **/implement** — Alias for `gsd:execute-phase`: executes the current phase plan with atomic commits and state tracking.
- **/reviewloop** — Alias for a review cycle: runs `/code-review` on the diff, fixes the findings, verifies, and repeats until the review comes back clean.

## Related

- [[loop-engineering]] — the context-rot methodology these skills implement
- [[claude-code-toolkit-raycfu]] — external toolkit eval (superpowers skills)
- [[skill-dev-principles]] — how new skills get built
- [[vault-map]] — where /brief and /wrap read/write in the vault
- [[README-dual-run]] — the dual-run operating contract the lifecycle skills serve

## Deep-analysis & guided-questions skills (GSD) — added 2026-07-06

The "analyze the repo / ask us questions" family, surfaced while hunting for a
project-documentation auditor:

- **/gsd:map-codebase** — the deep-analyzer. Fans out parallel mapper agents over the repo (tech, architecture, quality, concerns) and writes structured analysis docs to `.planning/codebase/`. General mapper — does NOT grade code against `.claude/rules/`.
- **/gsd:discuss-phase** — the "guides through and asks us" one. Adaptive questioning to pin down context and gray areas before planning a phase.
- **/gsd:list-phase-assumptions** — the flip side: surfaces what Claude is ASSUMING about a phase approach so Zac can correct it before planning.
- **/gsd:new-project** — deep context gathering with questions up front; produces PROJECT.md and stands up the GSD planning structure for something new.

**Open idea (Zac, 2026-07-06):** these `gsd:*` names are unintuitive — consider renaming/aliasing them the way /spec /plan /implement already alias GSD steps (e.g. `/map`, `/discuss`, `/assumptions`).

## Rules-compliance audit — no single skill, assembled from parts

There is NO off-the-shelf "read the whole project and audit it against `.claude/rules/`" skill. The pieces:

- **verifier agent** — runs the L1 parity/verification loop (3-surface parity, dual-query sync, app↔report parity).
- **/metric-audit** — checks any single metric for cross-app consistency.
- **/drift** — checks whether current work still aligns with locked decisions.
- **/code-review** — correctness bugs, but only on the current diff, not the whole project.

The gap-filler is a custom fan-out audit: one agent per rule domain (SQL/columns, rounding, org-codes, parity, PDF patterns, delivery, …) against a target project directory → follows/violates/fix-priority report. Recommended combo: `/gsd:map-codebase` scoped to the project for structure, then the custom rules audit layered on top.

**UPDATE 2026-07-06 — rename idea SHIPPED.** Four new thin aliases live in `~/.claude/commands/` (same pattern as /spec /plan /implement):

| New command | Aliases | What it does |
|---|---|---|
| `/map` | `gsd:map-codebase` | deep repo analysis via parallel mapper agents |
| `/discuss` | `gsd:discuss-phase` | adaptive Q&A before planning |
| `/assumptions` | `gsd:list-phase-assumptions` | surfaces Claude's assumptions to correct |
| `/kickoff` | `gsd:new-project` | question-driven project setup → PROJECT.md |

Full loop now: `/kickoff` → `/spec` → `/plan` → `/implement` → `/reviewloop`, with `/map` `/discuss` `/assumptions` as analysis helpers anywhere in between.
