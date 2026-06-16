---
name: feedback-srv-not-stuff-plus
description: "Never call the pitcher stuff grade \"Stuff+\" in any user-facing surface. Always \"SRV\" (short) or \"Stuff RelVel\" (long form). Org-wide naming convention."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c9176d2d-f153-4427-b10d-8e38b232ab31
---

# Never call it "Stuff+" — it's SRV / Stuff RelVel

User direction May 25 2026: "Never call shit Stuff+. Call it Stuff
RelVel SRV. We use it in a different app, so I don't know why you
fucked up here."

**Why:** The metric is `stuffrelvel_grade_2080` from `Pitches_View`
(see `rules/db-columns.md`). The org-wide canonical name for the
metric is "Stuff RelVel" with short form "SRV". Other Astros apps
already use "SRV" — the amateur-vs-pro slide deck was the outlier.

## How to apply

- **Slide titles / card labels / column headers**: use `SRV`
- **Body text / takeaway sentences**: use `SRV` (the audience knows it; "Stuff RelVel" full form is OK on first introduction in a lingo-reference slide if needed)
- **Code identifiers**: leave alone (`stuff_plus`, `amat_stuff_plus`, `pro_stuff_plus` are CSV column names + metric_key strings — internal identifiers, not labels)
- **Variable names, comments, docstrings**: prefer SRV but not load-bearing

## Where this rule applies (org-wide)

ANY user-facing surface in the BSB resources codebase. Includes:
- Amateur-vs-pro slide deck (fixed v5.17 May 25 2026)
- Arm Farm postgame + advance + tracker (verify next session)
- Pitcher KPI weekly
- PD Goals pitcher metric displays
- Any future deck / report / app page that surfaces the pitcher stuff grade

When adding the metric to a new surface, never use "Stuff+" in
rendered text. Default to "SRV".

## Bug history

- **May 25 2026**: amateur-vs-pro slide deck v5.16 shipped with "Stuff+" as the rendered label on slides 7, 10, 11, 12, 13 + dead code. User caught it. Fix v5.17: bulk replace `Stuff+` → `SRV` everywhere in `pd-goals/scripts/generate_amateur_vs_pro_slide_deck.py`. CSV column names + metric_key string `stuff_plus` left untouched.

## Cross-reference

- `rules/db-columns.md` Pitches_View section: `stuffrelvel_grade_2080` is the column
- Other apps where SRV is already used (verify when relevant): Arm Farm tracker, Pitcher KPI weekly
