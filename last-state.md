# Last session state - 2026-09-17 09:41 (Candidate Rubrics board + Internal Board notes)

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main`
- **Recall checkpoint (SOURCE OF TRUTH):** session `30b3` - domain `hiring/main`
  - id `14b654bdadd96fae` (supersedes `a12e6a5ec2672e22` - the 165 fix landed after the wrap)
- **What we were doing:** shipped the Candidate Rubrics board and its CSV import,
  then built magnet-board-style notes with a timeline on the Internal Board.
  Zac tested the notes and likes them ("looks phenomenal", confirmed they carry over).
- **Shipped this session (9 commits, all pushed, Railway auto-deploys, NO migrations):**
  - `6880348` Candidate Rubrics board - Candidates / Instrument / Import, owners only,
    at `hirehou.up.railway.app/admin/rubrics`. **NO single "mean" column**: each form
    declares its own headline question and the board is GROUPED BY FORM, so a 4-of-5
    and a 4-of-10 can never share an axis. Sorted by DISAGREEMENT, not score.
  - `e2d58b7` CSV import - preview writes nothing; reports every column it could NOT
    match and every question NO column answered, and refuses to commit while either
    list has an entry.
  - `ff583f1` / `be3bf4f` rubrics 4 and 5 drafted (Claude's wording, marked `draft`).
  - `047d557` all three live forms name a candidate; forms doc rewritten as Zac's own.
  - `dbca1db` + `e00357d` **Internal Board notes drawer** - By day / All notes, 3-day
    strip, who+when stamp, compose box, opt-in Share. Notes stay YOURS, one doc per
    owner, and follow the PERSON across Current and every project board.
  - `a3aba4d` + `aa9d25d` lineage entries.
- **EXACT next step:** nothing is in flight - Zac is clearing and will feed the next
  task in. The fastest win when he returns: he sends ONE real Microsoft Forms CSV
  export, paste it into the Import tab, copy the printed snippet into
  `cage-sandbox/data/rubric_forms.json` to pin the column headers. ~10 minutes.
- **Blockers / waiting on Zac (all on the Forms side, none in code):** one real CSV
  export; make "Candidate Reviewed" a **Choice** not free text on all three forms;
  his pass on the rubric 4 and 5 draft wording; a split threshold per scale (the
  board deliberately colours nothing as "a split" and says so).
- **ANSWERED BY THIS FILE:** Zac's "we have to establish teh pitchind decision unless
  its exactly laid out teh way sam was" - I could not parse it and asked twice. It is
  the **In-Game deck's Pitching Decision item**, the ALSO OPEN thread below, NOT the
  rubrics. Pick it up there.
- **Two of my errors this session, both corrected in the artifacts:** addressed the
  forms doc to Camden, who is not involved (Zac heads the search himself) - the name
  came from a stale prior-session checkpoint, and the lesson is now
  `feedback_verify_people_against_this_session`; and reported "two forms cannot name
  a candidate" when Zac had already added it and only our JSON was behind.
- **The deliberate divergence not to undo:** the magnet board's `notesOn()` hides
  notes on Current. This board shows them on Current AND every project, because a
  note follows the PERSON. `drive_internal.py` goes red if the gate is reintroduced.
- **Verified:** full suite 899 pass / 7 skip (was 798 at session start).
  `drive_internal.py` 121 pass / 0 fail (was 105). ~20 defect injections proven RED,
  including four of my OWN guards that came back green and were fixed, not loosened.
- **Landed AFTER the wrap (`60aef6e`): the dev list now counts toward the MiLB 165.**
  Zac: "i meant and dev list ... add dev list to this rule". The Aug 28 rule was
  recorded as "only active and 7Day IL" and dev was left out because that wording
  never named it. Board goes 145/165 -> 149/165. The tooltip had listed only the IL
  exclusions and never mentioned dev, which is why it read as a bug rather than a rule.
  **The full rule now:** counts at FCL/A/A+/AA/AAA when status is active, injured
  (day-to-day, hand-set only, ~0 in production), 7-day IL, or dev. Out: 60-day IL,
  full-season IL, DSL, MLB. `COUNTS_TOWARD_LIMIT` is a separate rule and still
  excludes dev on purpose.
- **OPEN, FLAGGED TWICE, UNANSWERED: do Suspended and Leave count toward the 165?**
  They are out by silence right now - the same way the dev list was out for three
  weeks. 6 of the board's 8 statuses are decided; those 2 are not, and the guard
  passes either way. My read is both should count, but that is reading shorthand
  again, which is what got dev wrong, so it is deliberately NOT encoded.
- **The guard lesson, hit twice in one day:** `test_the_milb_165_counts_the_right_people`
  passed the whole three weeks dev was missing, because it asserted `il7` IN and
  `il60`/`ilfs` OUT and said nothing either way about `dev`. A guard that enumerates
  only some of the options silently blesses the ones it skips. It now names every
  status in or out and cross-checks against `STATUSES`.
- **Uncommitted work:** hiring ~10 magnet-board render PNGs (`demo-field`, `notes-*`)
  pre-existing from other threads. bsb-resources 78 paths, all pre-existing, ZERO
  from this session.

## ALSO OPEN - In-Game deck: Pitching Decision on real data (separate thread, 2026-09-17)

- **Project / cwd:** `C:/Users/Owner/hiring-wt-deck` - branch `director-deck-philosophy`
  (SQL side: `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`)
- **Recall checkpoint (SOURCE OF TRUTH):** session `fecf` - domain
  `hiring-wt-deck/director-deck-philosophy` - id `ef1633101182eb4d`
- **What we were doing:** replaced the invented Pitching Decision item with three slides
  built from a real game, anonymized the deck, SENT IT TO SAM (he liked it), then spent the
  back half hunting the real base-out state behind Situation 1.
- **Shipped:**
  - **Pitching Decision = 3 real slides** (`0b97afa`). Aug 2 vs the Greenville Drive: their
    actual nine, and the 8 A+ arms who started under a third of their own appearances.
    GENERATED by `deck/tools/build_pitching_decision.py` from `deck/data/pitchdec_*.csv` -
    re-run the script, never hand-edit the pages.
  - **Anonymized + AvgOutLen fixed to thirds** (`1fdf909`). Club, date and affiliate are
    out; AvgOutLen was a decimal average (2.40) and is now 2.1 = two and one third.
  - **Situation 1 setup now leads its clip; Situation 2 question 3 rewritten** (`289bd53`).
    `videoAfter` is opt-in per page - only Situation 1 has it.
  - **`M` IS HIGH HOME** (Zac) - the same camera `db-columns.md` calls "Main CF". In the
    rules and synced to all four worktrees (`3e8aa3f1`, `632e3fd3`, + intangibles).
  - **7 SQL files** on bsb-resources `feature/pd-goals`, ending `29ae255e`.
  - **LINEAGE entry** on the deck repo.
- **THE FINDING:** afx 2026, 3-2, two outs, man on first -> **68 qualifying pitches, 28
  STAYED (41%)**. With ONLY a man on first: 30 qualifying, **12 stayed**, all 12 have both
  high-home and sporty clips. Situation 1's real game is **sched 1298992, Aug 6 vs the Salem
  RidgeYaks** (the YAKS logo on the grass in the clip), pitches 244 and 245 - and **Waner
  Luciano 176301 is the runner on THIRD**, who never goes on either.
- **EXACT next step:** **pick one of the 12 one-runner-on-first candidates** - recommendation
  is **2026-06-19 vs Kannapolis, bottom 7, down one, strikeout** (the inning ends, so nothing
  visibly bad happens - the same property that made the original clip good) - then rebuild
  Situation 1's card off that real state and re-cut the clip. **Camden has the final cut;
  confirm with him before redoing it.**
- **BUILD COMMAND - the wrong build is SILENT:** from `deck/`, set `DECK_VIDEO_DIR` to the
  repo's `deck\media` folder, then `node gen.js ingame`. **15 slides = clips embedded. 13 =
  no clips.** A 13-slide build was handed over for sending once.
- **Blockers / waiting on:** Zac owes the per-arm IP / pitch limits (two columns reserved).
  Unconfirmed whether the all-right-handed pen is real or a gate artifact. Unconfirmed
  whether a 3B runner should count as "should have gone" - his message said it both ways,
  and `r3_going` is on every row so it is a verdict flip, not a re-query.
- **Uncommitted work:** hiring-wt-deck 2 paths (`deck/media-small`, `deck/render_check` -
  both gitignored build scratch). bsb-resources 78, siblings 17/46/18 - all pre-existing.
- **THE VAULT REPO IS MID-REBASE** - `git -C C:/Users/Owner/bsb-brain status` says "all
  conflicts fixed: run git rebase --continue". Left alone deliberately this wrap; this file
  was written but NOT committed. Finish or abort that rebase before trusting vault git.
- **What actually cracked the search, after too many rounds:** a **funnel** counting pitches
  surviving each gate one at a time. It ruled Hickory out in a single run - 733 pitches, 6
  games, 7 full-count-two-out, **zero** with a runner on. **Gating on the thing you are
  searching for is what hides it** - the play is by definition just outside whichever filter
  last came back wrong. Every such query should ship its own denominator.
- **Three misses, all caught by Zac:** `MLBAM.Teams.team_name` written from memory (it is
  `name_display_full`); the no-video build handed over for sending; and gating on 3-2 / two
  outs without SELECTING the count and outs, so he could not verify the filter. **A filter
  you cannot see on the row is a claim, not evidence.**
- **The variable trap:** a `DECLARE` came back *"Incorrect syntax near 'INT'"* plus *"Must
  declare the scalar variable '@Waner Luciano'"* - the player's NAME had been substituted
  into the variable name somewhere between the file and his query window. All seven queries
  use inline ids and no variables.
- **Camden executed the final cut faster by hand.** The slow half was the search, not the deck.

## ALSO OPEN - Candidate Rubrics / internal board (separate thread, 2026-09-16)

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
