# Last session state - 2026-09-16 (In-Game Strategy Assessment: the deck, the queries, the first clip)

- **Project / cwd:** `C:/Users/Owner/hiring-wt-deck` - branch `director-deck-philosophy`
  (SQL side: `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`)
- **Recall checkpoint (SOURCE OF TRUTH):** session `a2dd` - domain `hiring/director-deck-philosophy` - id `b87255136e5b366a`
- **What we were doing:** turning Zac + Sam's manager / dev-coach brainstorm into a real
  assessment - 7 questions, questionnaire format, delivered as a walked-through deck built
  the same way as the director case assessments.
- **Shipped:**
  - **10-slide deck** (`8815d87`, `7cbdde3`, `fb6c264`, `fc68891`). `content/ingame.json` ->
    `gen.js`. Two new page kinds: `situation` (setup card + drawn base-out diamond + clip /
    chart / table + questions) and `table` (roster). Both throw on overflow.
  - **Item 1 DONE with its real clip** - 2026-08-06 Fayetteville, top 7, two outs, 3-2,
    **bases loaded**, Cauro batting (sched 1298992 pitch 245). Zac's read of the fault: the
    runner on **third** never broke toward home; the runner from first did go (63.3 ft
    secondary). It is a HBP, so the run walks in and the scoreboard hides the miss.
  - **4 SQL queries** (`3d7de637`, `02f08261`, `6935a143`, `b36df632`). Three have RUN.
    A+ runner-on-3B-1-out = **1.023 runs / 66.1%** (n=3120). Two-out send break-even
    **A+ 45.4%, MLB 39.7%** - higher in the minors. 113 real infield-in situations, SS
    depth 88-153 ft.
  - Answer key + README + runbook under `assessments/in-game-strategy/`.
- **EXACT next step:** Zac said **"all the text got messed up"** and did not say which file.
  ANSWER-KEY.md was checked and is intact. **ASK HIM WHICH ARTIFACT** (PPTX in PowerPoint?
  the slides PDF? the chat?) and fix that before anything else.
- **Blockers / waiting on:** three Zac decisions - (1) rebuild the Infield In? page off a REAL
  play (Jul 22 Asheville SS at 88 ft drawn in / Jul 25 SS at 153 ft back, both gave up the run)
  or leave it designed; (2) Send or Hold clip - Nowak thrown out at home vs Flores held at
  third on a ball he should have scored on; (3) item 4 hitter, needs the spray query run.
- **Uncommitted work:** hiring-wt-deck 2 paths (gitignored build scratch). bsb-resources 78
  paths, all pre-existing, none from this session.
- **Two traps worth remembering:** score columns are `tinyint` and tinyint arithmetic STAYS
  tinyint, so a negative lead raises "Arithmetic overflow ... tinyint" and kills the batch.
  And the 3-2 query only read the runner on FIRST, so it called the chosen clip clean while
  the fault was at third - it now reads all three bases.

## ALSO OPEN - Astro World (separate thread, 2026-09-15)

- **Project / cwd:** `C:/Users/Owner/astroworld` - branch `feat/aerollo-watch`
- **Recall checkpoint:** session `5937` - domain `astroworld/main` - id `d3c5ae53b86d5dc6`
- **Shipped:** #74 MERGED (every API route takes its page's gate; `GET /api/travel/hub` was
  leaking the staff directory and everyone's trips to any signed-in viewer). #75 MERGED
  (draft text survives closing a card, emoji picker, reactions). #76 OPEN (a reaction reaches
  your inbox). #77 OPEN, stacked on #76 (the bell + `/aerollo/notifications`).
- **EXACT next step:** merge **#76**, run migration **"Aerollo reaction notifications"** under
  Admin > Database, check the live app, then merge **#77** and run **"Aerollo watching"**.
- **Blockers:** Peter (admin consent + shared mailbox + Application Access Policy for email).
  No deploy-while-in-use plan yet - that is the open design question.
- **Left running on that laptop:** embedded-postgres on 5434, `next start` on 3210 and 3211 as
  two signed-in users. Restart recipe: `Desktop/aerollo-screens/AEROLLO-RUNBOOK.md`.
