---
name: No DB column assertions in design docs without grep
description: When writing design docs / agent prompts that reference DB columns, GREP FIRST. Never assert "column X is on table Y" without a grep result backing it. Don't tell agents to "skip the audit" — the audit IS the safeguard.
type: feedback
originSessionId: 5de55ffe-8c6f-460b-a14d-68a74c52a701
---
When I write design docs or agent prompts that name specific DB columns,
I MUST grep the existing codebase to verify the column exists BEFORE
typing the column name. Confidence-from-pattern-matching is not a
substitute for grep — DB column names vary by schema (b_side vs bat_side
vs stand vs batter_side) and what's "obvious" from MLBAM/Statcast doesn't
guarantee what's on Astros.Pitches_View.

**Why:** May 3 2026, handedness rollout to 4 affiliate trackers. I asserted
`pv.b_side` in the design doc as if it were verified — it wasn't, I just
picked the most-common-looking variant. Then I baked the same wrong column
straight into the dispatched agent's implementation checklist AND told the
agent: *"Arm Farm queries don't need this audit since `b_side` is on `pv`
directly."* I explicitly told the safeguard to stand down. Agent followed
my instructions, shipped 12 queries with a column that doesn't exist.
Caught at re-pin time when SQL Server raised `Invalid column name 'b_side'`.
Actual column is `pv.bat_side`. Cost: one wasted re-pin attempt + a
follow-up commit. Trivial-to-grep before-the-fact verification would have
caught it instantly.

**How to apply:**
- Whenever I'm about to type a column name in a design doc, agent prompt,
  or planning artifact: STOP. Run grep first. Confirm the column exists
  via a real codebase reference. Cite the file:line in the design.
- Never tell an agent to "skip" or "not bother with" column verification.
  If a column reference appears in the agent's prompt, the agent MUST
  grep to verify before using it. The orchestrator's confidence is
  irrelevant to the agent — the agent's grep is the safeguard.
- For SQL-touching agents: the prompt should include "grep to verify
  every column reference exists in the target schema before committing"
  as a non-negotiable step.
- This rule is layered on top of CLAUDE.md Blocking Rule #1 ("NEVER guess
  DB column names") and existing memory `feedback_no_guessing_columns_scripts.md`
  — same principle, applied specifically to design-doc / agent-prompt
  authoring rather than just direct SQL writing.

**Tripwire:** if I find myself typing "pv.X" or "table.column" in any
artifact and I haven't grepped X in the last 60 seconds, that's the
signal to stop and grep.
