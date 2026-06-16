---
name: feedback-srv-meaning
description: "SRV abbreviation expansion — never invent it; just call it 'SRV' in user-facing surfaces"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 86a79174-14a1-443b-b8cf-f8f80de50a37
---

**SRV = stuff-grade relative to velocity** (a differential metric).
**NOT "Stuff Release Velocity".** I invented that expansion May 16 2026
in the org SRV × FB Velo scatter PDF (xlabel + docstring). User
correctly called it out — the column is `stuffrelvel_grade_2080` in
`Pitches_View` and the abbreviation stands for "stuff relative to
velocity," not "stuff release velocity."

**Why:** Stuff models grade pitches on their movement / shape /
release; velocity is a separate axis. SRV measures how much the
stuff grade differs from what would be expected given the velocity —
i.e., a 95 mph fastball with a 60 SRV is "better stuff than a typical
95," while a 95 with a 40 SRV is "less stuff than a typical 95."
"Stuff Release Velocity" reads like a velocity metric, which is the
opposite of what it is.

**How to apply:**
- In user-facing surfaces (PDF labels, app columns, glossary text),
  **just say "SRV"** — don't try to spell it out. If a tooltip /
  glossary is needed, write it as **"stuff grade vs. velocity
  (differential)"** or reference the column name
  `stuffrelvel_grade_2080` directly.
- Never invent the long form of an abbreviation from the column name
  alone. Grep `gc2-metrics.md` / `db-columns.md` / `pd-goals.md` /
  the live PDFs (postgame report, KPI weekly) for how the abbreviation
  is actually displayed. If no live label exists, ASK the user before
  shipping a new long form.
- Same caution applies to any other compound abbreviation: SwDec,
  R2K%, FPinZ%, EW%, AOL — verify the expansion in canonical rules
  files or live UI labels, never reverse-engineer from the SQL column
  name.

**Pairs with:** `feedback_no_guessing_columns_scripts.md` (don't
guess column names; same principle for column meanings).
