---
type: meta
created: '2026-07-01'
tags:
  - meta
  - ai
  - claude-code
  - hooks
  - teams
  - build-spec
---
# Build Spec — The Self-Feeding Brain (two hooks)

> [!abstract] What this is
> Spec for the two loop-closing hooks. Grounded in [[repo-eval-tddguard-subconscious-wshobson]]
> (patterns to lift) + [[team-training-loop]] (the capture step we're automating).
> Zac is intrigued by this — it's the piece that makes "the vault remembers" automatic.

> [!done] STATUS — updated Jul 1 2026 (read this FIRST)
> Reading the live `~/.claude/hooks/` BEFORE building revealed most of Gap 1 was already done:
> - **Gap 1 write-back — lossless tier ALREADY BUILT:** `~/.claude/hooks/autocapture-session.js`
>   (SessionEnd) copies every transcript into `00-inbox/transcripts/` + drops a dated pointer in
>   `_autocapture-<date>.md`. Curate later with `/log`. Nothing to rebuild.
> - **Gap 2 hooks-as-law — BUILT THIS SESSION (advisory):** `~/.claude/hooks/bsb-law-gate.js`,
>   wired into global `settings.json` PreToolUse (`Write|Edit|MultiEdit`). Self-scopes to
>   bsb-resources + `bsb-wt-*` `.py` files; injects the render-and-look (#18) reminder on visual
>   edits + the metric-audit/three-surface reminder on metric edits; SILENT elsewhere. Advisory
>   (never blocks). Tested on 4 scenarios (visual✓ metric✓ vault-silent✓ util-silent✓).
> - **Existing PreToolUse guard** = GSD's `gsd-prompt-guard.js` (prompt-injection scan of
>   `.planning/` only) — was the template copied for the law-gate.
>
> - **Gap 1 write-back — SMART tier BUILT THIS SESSION:** `autocapture-session.js` now ALSO writes
>   `00-inbox/session-digest-<date>_<sid>.md` per session — files touched, bash count, a conversation
>   skeleton, and AUTO-FLAGGED teaching moments (user-correction turns → golden-set candidates via
>   the `CORRECTION` regex). Pure local heuristics, no LLM. Tested on a real 50-turn transcript: it
>   correctly caught both of Zac's corrections. Lossless jsonl copy still runs alongside.
>
> **Remaining (ranked):** (1) escalate `bsb-law-gate.js` to a real BLOCK (exit 2) once proven
> low-false-positive. (2) install wshobson **security** plugin only. (3) optional: an on-demand
> command that LLM-summarizes a digest into a curated golden-set entry (the human-curation step).

## The two gaps → two hooks

| Gap | Hook | What it does | Risk |
|---|---|---|---|
| **1 — write-back** | `Stop` (or `SessionEnd`) summarizer | On session end, a LOCAL script drafts learnings/golden-set cases + a handoff INTO the vault. No cloud. | Low — it only writes notes. **Build this first.** |
| **2 — hooks-as-law** | `PreToolUse` gate | Before a `Write\|Edit\|MultiEdit`, block/warn if a metric file or visual-draw file is edited without its check (`metric-audit` / `render-and-look`). | Higher — can block real edits. Ship as WARN first, escalate to BLOCK. |

## Design decisions to make FIRST (don't skip)
1. **Where do the hooks live?**
   - PreToolUse gate → the **coding** repos: `bsb-resources/.claude/settings.json` + `.claude/hooks/` (and it must be synced to the 3 worktrees, same as rules — use `sync-rules`). It fires where code is edited, NOT in the vault.
   - Write-back Stop-hook → decide **global** (`~/.claude/settings.json`, fires everywhere → always captures) vs **per-repo** (only bsb-resources). Recommend global with a cheap early-exit if the session did nothing worth writing.
2. **Honesty limit of the PreToolUse gate:** a hook CANNOT verify a human "looked" at a PNG. It can only enforce a *procedural* gate — block the edit and emit the checklist, or require a fresh render artifact exists. Don't oversell it as true verification. TDD Guard uses a validation LLM; we can start dumber (path-match + reminder) and add rigor later.
3. **Use the `update-config` skill** to edit settings.json — hooks are harness config, not something a prompt/memory can set.

## MVP build order (execute in a coding session, in bsb-resources)
1. **Write-back Stop-hook (do this first — highest leverage, lowest risk):**
   - `bsb-resources/.claude/hooks/session_writeback.py` — reads the Stop-hook JSON from stdin; if the session touched anything notable, append a dated stub to `bsb-brain/05-daily/<date>-auto.md` proposing: golden-set cases, new scars, an open-loops list. It PROPOSES (draft), doesn't overwrite curated notes.
   - Wire via `update-config`: `Stop` hook → `python .claude/hooks/session_writeback.py`.
   - This automates the capture step in [[team-training-loop]] that `/log` does by hand.
2. **PreToolUse gate (WARN mode):**
   - `bsb-resources/.claude/hooks/law_gate.py` — reads tool-call JSON from stdin. If `file_path` matches a metric/report/visual-draw path (e.g. `*_report.py`, `*_data.py`, files that draw figures), emit the `metric-audit` / `render-and-look` checklist to stderr. Exit 0 (warn) at first; flip to exit 2 (block) once trusted.
   - Wire via `update-config`: `PreToolUse` matcher `Write|Edit|MultiEdit` → the script.
   - Sync to 3 worktrees (`sync-rules`), same discipline as `.claude/rules/`.
3. **Then:** install ONLY wshobson's **security** plugin via `/plugin`; audit vs Connect deploy / DB-cred / env-var footguns.

## What to SKIP (already decided in the eval)
- TDD Guard the tool (enforces test-first, not our law; no pytest suite anyway) — lift the pattern only.
- Claude Subconscious (ships transcripts w/ player names + GC2 schema to Letta CLOUD) — run the Stop-summarizer idea LOCALLY instead.
- Bulk wshobson agents (194 → roster bloat breaks subagent spawning). Security plugin only.

## Reference implementations to copy
- `PreToolUse` shape: TDD Guard's settings.json (stdin JSON → non-zero exit blocks). See eval note.
- Existing blocking rule this makes "law": `render-and-look.md` (#18) + `metric-audit` skill in bsb-resources `.claude/`.

Related: [[repo-eval-tddguard-subconscious-wshobson]] · [[team-training-loop]] · [[Command-Center]] · [[loop-engineering]]
