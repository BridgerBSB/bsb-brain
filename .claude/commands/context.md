---
description: Load vault state — where you left off — before starting work
argument-hint: [optional: a project or topic to focus the report on]
---

You are booting a work session in the BSB Brain vault. Produce a **situation
report** so we start grounded. **READ ONLY — do not edit any note.**

You've already read `CLAUDE.md` (it auto-loads). Now gather state — use search /
glob / read on the *specific* notes below, never bulk-read `rules/` or `memory/`:

1. Read the most recent daily note in `05-daily/` (highest `YYYY-MM-DD.md`). If
   none exists yet, say so.
2. Read the most recent weekly review in `personal/reviews/` if one exists.
3. List active projects: each subfolder in `projects/`; read its newest note for
   one-line status.
4. Skim `00-inbox/` for unprocessed captures (filename + 1 line each).
5. From `memory/MEMORY.md`, surface only the "most recent session" pointers — do
   NOT read every memory note.

Then output, in **≤12 bullets**:
- **Where I left off** — from the latest daily + weekly
- **Active projects** — one-line status each
- **Open loops / unprocessed inbox**
- **Suggested first move today** — one line

If `$ARGUMENTS` is given, focus the whole report on that project/topic.
