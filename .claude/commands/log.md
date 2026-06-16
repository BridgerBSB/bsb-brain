---
description: Turn today's brain-dump into a structured daily note (+ propose memory facts)
argument-hint: [paste the day's notes / voice-memo transcript, or leave blank to be prompted]
---

Capture today into a structured daily note.

**WRITE-ZONE ONLY.** Never edit `rules/` or `memory/` — those are read-only
snapshots. Durable facts get *proposed*, not written here (see step 6).

Input: `$ARGUMENTS` — the day's dump / transcript. If empty, ask me to paste it,
then continue.

Steps:
1. Use **today's date** (from the environment) as `YYYY-MM-DD`.
2. Create or append `05-daily/YYYY-MM-DD.md` from `templates/daily.md`. Sort what
   I dumped into the headings (Top 3 / Shipped / Wins / Friction / Notes & ideas /
   Reflection). **Don't invent** — only what I actually said. Fill the "For future
   Claude" line with a one-sentence summary of the day.
3. Add `[[wikilinks]]` to any project, person, or decision I mention.
4. If something belongs in another zone (a SQL snippet → `sql/`, a project update
   → `projects/<name>/`), file a copy there and link it from the daily note.
5. Sweep `00-inbox/` — if there are loose captures, **offer** to file them (ask
   before moving anything).
6. **Propose** any durable facts/decisions worth locking ("should this become a
   memory fact?"). List them for me to confirm — do NOT write to `memory/`; that
   goes through the live `.claude/` workflow so there's exactly one writer.

End with a 2-line recap: what you wrote and where.
