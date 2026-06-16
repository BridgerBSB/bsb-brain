---
name: Never invent titles or roles for people
description: Don't guess job titles when they aren't documented; describe what someone DOES (with evidence) instead. Verify with user before publishing names with titles.
type: feedback
originSessionId: 7d997549-27b1-48e2-b481-d59230e40942
---
NEVER invent or guess a person's title, role, or organizational
position when documenting them. If the canon (CLAUDE.md, rules,
memory) doesn't explicitly state the title, do ONE of:

1. Describe what they DO that you have evidence for (e.g.
   "set the advance scouting page-1 layout May 2026" instead of
   "pitching coach"), OR
2. Mark it explicitly as needing verification ("ask Zac for
   current title"), OR
3. Leave the title field out entirely.

**Why:** May 8 2026 incident — published the PD Apprentice Handbook
(`docs/handbook/`) listing Sam Niedorf as "Front office." User
corrected: he's **Farm Director**. Other names in the same table
were also guessed (Cristian Perez "Pitching coordinator", Kyle
Brennan "Pitching coach", Mazzo "OF positioning project", Nick
Arrivo "Analytics counterpart"). I had evidence only for what each
person did, not their formal titles, and conflated "Cristian" and
"Perez" into one person when they appear separately in the canon.

**How to apply:**

- Whenever writing a "people / contacts" table, audit each row:
  is the title in `CLAUDE.md`, the rule files, or the memory
  index? If not, don't write it.
- For confirmed roles (e.g. Chris Josefy = Supervisor of Data,
  Adam Brodie = R&D, Sam Niedorf = Farm Director), write the
  title plainly.
- For everyone else, write what they did + a note to ask Zac.
- Before any new public-facing artifact (handbook, README, doc,
  Slack post) lists names with titles, verify each one with the
  user.
- Don't combine people whose names appear separately in the canon
  ("Cristian" and "Perez" are likely two different people, not
  "Cristian Perez").

Pairs with `feedback_no_design_doc_column_assertions.md` (don't
type DB columns from memory; verify) and
`feedback_no_made_up_effect_sizes.md` (don't fabricate magnitude
estimates). Same root cause: confidently asserting things I haven't
verified.
