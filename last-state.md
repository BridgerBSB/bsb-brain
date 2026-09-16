# Last session state - 2026-09-16 (Candidate Rubrics: owners-only plumbing + the internal board field drag)

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main`
- **Recall checkpoint (SOURCE OF TRUTH):** session `aa73` - domain `hiring/main`
- **What we were doing:** two tracks in parallel, Zac's plan - build the rubric environment
  in the app while designing the five hitting rubrics. Plus two internal-board asks that
  came in mid-session.
- **Shipped:**
  - **Internal board Field view drag** (`0bdff29`). Role boxes drag between and within
    sections, people come along free. Drop meaning BRANCHES on viewMode - tree reparents,
    field only moves - or rearranging the field silently rewrites the org chart. Field
    order got its own number `ford`, fixing a live bug where "Move earlier" jumped boxes to
    the top of their section. All 9 sections always draw now (emptying one made it vanish
    with its drop target). `drive_internal.py` 105 pass / 0 fail.
  - **Leaving a board saves it** (`580f5a9`). No more "You have unsaved changes" on a board
    that was about to autosave. The "Main page" `<a href>` flushes first too.
  - **Rubrics: owners only + a definition per form** (`39cf2ad`). 798 pass / 7 skip.
  - **Migration 010 APPLIED TO PRODUCTION** and verified against the DB. Also confirmed
    **009 was already applied**, closing a question open since 2026-09-02.
  - `rubric/hitting/FORMAT.md` - Zac's own form pattern, captured. His shape won; my 1-5
    anchored instrument (`rubric/hitting/03-case-assessment.md`) is superseded.
- **EXACT next step:** **Build the Candidates view** - the rubric dashboard's landing tab -
  against `cage-sandbox/data/rubric_forms.json` so it renders with SYNTHETIC rows before any
  real CSV exists. Zac has asked twice for something to look at and the honest answer so far
  has been "nothing visible changed". Approved mock is on his Desktop as
  `rubric-dashboard-mock.png`: one row per candidate x position x round, **sorted by spread
  not score**, each grader a tick on a bar with the mean in orange, recommendation pips
  beside the mean, THIN flag on a single grader, and the agreement badge grey never green.
- **Blockers / waiting on:** the **CSV import cannot be built blind** - it needs one real
  export from any of the three live forms (even a single self-filled test response) to learn
  the exact column headers Microsoft produces. Asked for, not yet supplied.
- **Uncommitted work:** hiring 10 paths (harness-regenerated render PNGs + pre-existing
  `deck/`). bsb-resources 78 paths, all pre-existing, none from this session.
- **Three things flagged to Zac and deliberately NOT changed:** "Candidate Reviewed" is free
  text on his live forms and must become a Choice or the dashboard cannot group a candidate's
  graders; First/Last Name are typed questions that org auth should replace; and Sam's
  recommendation scale is 2 positive / 1 neutral / 1 negative with no "strongly do not
  advance", which drifts a pool upward.
- **The trap worth remembering:** a blanket `COORD -> OWNER` find-replace, run to move the
  FLOW tests onto an owner, also hit refusal tests written minutes earlier in the same file.
  One failed loudly and cost four rounds chasing an auth bug that never existed. Its sibling
  went **GREEN on the wrong actor**, which is worse - nobody re-reads a passing test.
- **Also:** the real finalized decks are `Desktop/Pitching_Case_Assessment.pptx` (14 slides)
  and `Downloads/Hitting_Case_Assessment.pptx` (12). The `deck/` copies in the repo are STALE
  and gitignored. Full pytest hangs on a used `data/cage.db` - move it aside first.

## ALSO OPEN - In-Game Strategy Assessment (separate thread, 2026-09-16)

- **Project / cwd:** `C:/Users/Owner/hiring-wt-deck` - branch `director-deck-philosophy`
  (SQL side: `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`)
- **Recall checkpoint:** session `a2dd` - domain `hiring/director-deck-philosophy` - id `b87255136e5b366a`
- **Shipped:** 10-slide deck (`8815d87`, `7cbdde3`, `fb6c264`, `fc68891`); item 1 done with its
  real clip (2026-08-06 Fayetteville, top 7, two outs, 3-2, bases loaded, sched 1298992 pitch
  245); 4 SQL queries (`3d7de637`, `02f08261`, `6935a143`, `b36df632`), three have run. A+
  runner-on-3B-1-out = 1.023 runs / 66.1% (n=3120). Two-out send break-even A+ 45.4%, MLB 39.7%.
- **EXACT next step:** Zac said **"all the text got messed up"** and did not say which file.
  ANSWER-KEY.md is intact. **ASK HIM WHICH ARTIFACT** (PPTX in PowerPoint? slides PDF? chat?)
  and fix that before anything else.
- **Blockers:** three Zac decisions - the Infield In? page off a real play or leave it designed;
  the Send or Hold clip; item 4's hitter, which needs the spray query run.
- **Two traps:** score columns are `tinyint` and tinyint arithmetic STAYS tinyint, so a negative
  lead raises "Arithmetic overflow ... tinyint". And the 3-2 query only read the runner on FIRST,
  so it called the chosen clip clean while the fault was at third.

## ALSO OPEN - Astro World (separate thread, 2026-09-15)

- **Project / cwd:** `C:/Users/Owner/astroworld` - branch `feat/aerollo-watch`
- **Recall checkpoint:** session `5937` - domain `astroworld/main` - id `d3c5ae53b86d5dc6`
- **Shipped:** #74 MERGED (every API route takes its page's gate; `GET /api/travel/hub` was
  leaking the staff directory and everyone's trips to any signed-in viewer). #75 MERGED (draft
  text survives closing a card, emoji picker, reactions). #76 OPEN (a reaction reaches your
  inbox). #77 OPEN, stacked on #76 (the bell + `/aerollo/notifications`).
- **EXACT next step:** merge **#76**, run migration **"Aerollo reaction notifications"** under
  Admin > Database, check the live app, then merge **#77** and run **"Aerollo watching"**.
- **Blockers:** Peter (admin consent + shared mailbox + Application Access Policy for email).
  No deploy-while-in-use plan yet.
- **Left running on that laptop:** embedded-postgres on 5434, `next start` on 3210 and 3211 as
  two signed-in users. Restart recipe: `Desktop/aerollo-screens/AEROLLO-RUNBOOK.md`.
