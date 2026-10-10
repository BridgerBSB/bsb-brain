# Auto-decide: a model trained on Zac's grades (2026-10-10)

**Goal:** the knowledge base approves and rejects notes the way Zac would, learning
from his grades, so the review queue only holds the notes it is unsure about.

## What the data said before building

142 graded notes (100 approved, 42 rejected). The writer's own rating already
matches Zac at the ends: high 73/78 approved, low 0/17. Med is a coin flip, 27/48.

Low notes never reach the model (they auto-file), so the honest test population is
high + med, n = 126. Repeated 5-fold cross-validation, 20 repeats:

| | AUC | Agreement | Med notes |
|---|---|---|---|
| Writer rating (high > med) | 0.769 | 0.794 (approve all) | no signal |
| **Text classifier** (bge-small embedding of title + TL;DR, logistic regression C=1, balanced) | **0.818** | 0.810 at p=0.5 | AUC 0.735 |

About 18 configurations were tried; this one was picked as the simplest, not the
best scorer (the best read 0.873 agreement, inflated by picking it from 18).

Cutoffs from out-of-fold probabilities, budget **approve 1 in 20 wrong, reject 1
in 50 wrong** (asymmetric: a wrong reject hides a good note, a wrong approve sits
in the library). Stable across 20 repeats: approve p >= 0.55-0.61, reject p <=
0.35-0.41. On history: auto-approve 64 (Zac rejected 3), auto-reject 4 (Zac
rejected all 4), 58 to Zac. On the 40 pending at build time: 28 approve, 0
reject, 12 to Zac.

## How it works (nightly, `kb.py run`)

1. **Overturn sweep** (before promote). Zac overturns by editing `status:` on
   the note itself:
   - auto-approved note -> `rejected`: unwired from cues/drills/concepts/MOCs,
     moved to `_rejected/`, becomes his grade + a lesson for the writer.
   - auto-approved note -> `approved`/`edited`: confirmed, becomes his grade.
   - auto-rejected note -> `approved`/`edited`: moved back to `_review/` and
     promoted normally that same run (corrections recorded as usual).
   - auto-rejected note -> `rejected`: confirmed, becomes his grade + a lesson.
2. **Promote** (unchanged) files what Zac graded in `_review/`. NEW: a plain
   reject of a note the writer rated high/med is saved as a **lesson** the writer
   reads ("you rated this high, Zac rejected it"). Before this, a plain reject
   taught nothing.
3. **Train**: on Zac's grades ONLY (state `promoted`/`rejected`, note
   `confidence: zac`, proposed value high/med). Model decisions never enter the
   training set, or the model would grade its own homework and could only look
   better (blocking rule #19).
4. **Decide** on every `pending` note in `_review/`: approve, reject, or leave it
   for Zac. Runs again after summarize so tonight's new notes are decided too.
   Each auto-decided note carries `model_p` and `model_like` (the 3 graded notes
   it most resembles and how Zac graded them), and is listed in
   `_review/auto-decided.md` with the model report.

## Statuses added

- note: `auto-approved` (filed into `sources/<src>/`, wired like an approve),
  `auto-rejected` (in `sources/<src>/_rejected/`). `confidence: model`.
- state: `auto-promoted`, `auto-rejected`.

## Not built (on purpose)

- No forced spot-check share. Overturns from the skim list are the feedback.
- No minimum-sample gate. The model trains whenever 5-fold CV can run (5+ of each
  class); a zone with no cutoff meeting the budget simply stays off.
- Writer lessons are capped at the newest 10 rejections per source in the prompt,
  beside the newest 15 corrections, so rejections never crowd corrections out.
