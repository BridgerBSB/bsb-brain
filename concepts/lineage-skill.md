---
type: concept
domain: engineering/ai-workflow
source: designed + built 2026-07-12 (brainstorm + deep-research)
---
# /lineage — per-project chronological lineage skill

A Claude Code command (`C:\Users\Owner\.claude\commands\lineage.md`) that maintains
a **read-first `LINEAGE.md` at each repo root** — the chronological record of what a
project is now, what superseded what, and what's deprecated (⚠️ STILL-WIRED vs
✅ REMOVED, with `file:line`) and WHY. Built to stop complex multi-model work (the
promo/release regressions) from re-confusing the agent every session.

## Design (locked 2026-07-12)
- **Artifact:** living `LINEAGE.md` (newest on top) + `docs/plans/archive/` for dead
  snapshot docs, each stamped with a `⛔ SUPERSEDED` banner on line 1.
- **Location:** repo root, per project (like CLAUDE.md). Not the vault — the agent
  reads it right next to the code. A SHORT CLAUDE.md pointer ("read LINEAGE.md first").
- **Two entry points:** `/lineage` standalone (log the moment something changes) +
  **Step 1 of `/wrap`** (end-of-session sweep, multi-repo aware — one entry per repo
  that actually changed structurally; silent on repos merely poked).
- **Anti-misconstrue guards (the whole point):** `Active truth now` line = the only
  current truth · `WHY ABANDONED / Do NOT reintroduce` tombstones on dead ideas ·
  archive banners so a dead doc self-identifies on line 1.
- **Verified deprecation:** the skill greps the repo for remaining references and
  classifies each as STILL-WIRED (loose end) vs REMOVED — not trusted to memory.
- **Git pairing:** nudges a `lineage: <title>` commit (log + git history together).

## Why (research-backed)
See [[agent-modeling-workflow-patterns]]: Anthropic's own long-running-agent pattern
is a progress-log + git commits; NO ML tool (MLflow/W&B) encodes
"superseded/deprecated/why" — this fills that gap. The `/wrap` integration is the
documented **end-of-session summarize-and-refine loop**.

## Sibling ideas (not built)
- `model-tournament` — parallel subagents build candidate models, judged multi-criteria.
- Scheduled eval loop — headless/cron nightly-or-weekly retrain/eval/drift (match data cadence).

## Links
[[agent-modeling-workflow-patterns]] · [[promotion-models-STATUS]] · [[promotion-release-models]] · [[astro-world]] · [[MOC-astros-engineering]]
