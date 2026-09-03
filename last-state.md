# Last session state — 2026-09-03 14:11
- **Project / cwd:** `C:/Users/Owner/astroworld` · branch `feat/travel-hub` (shell cwd was `bsb-resources`; only memory files changed there)
- **Recall checkpoint:** `568d99b9b174e1c9` (session `a3f1`, domain `astroworld/feat-travel-hub`); full build state in `ae34725ae8549e7d`.
- **What we were doing:** Aerollo labels/backgrounds shipped (#62-#64 merged, live), then ported the colleague's Travel Hub HTML into CoordinatorHUB as PR #65 (open): 7 views, real users from Manage access, admin-only Coverage/Admin, owner-or-admin trips, 5 new tables via Admin > Database.
- **Shipped this session:** astroworld `c4cf3a1` `b0a5b1c` (#62) · `a0119f0` (#63) · `b168a80` (#64) · `1867030` (#65). Spec `docs/plans/2026-09-03-travel-hub-spec.md`; renders `docs/plans/mocks/travel-hub-{source,port}/`.
- **EXACT next step:** Zac's six items on #65, verbatim: "1. make sure that the season is the current year - keep histories of former seasons 2. you did not include the images of the logos of each of the affiliates 3. i dont see the actual games populating from the database in master schedule 4. when adding a trip remove functional area, travel in and travel out time 4b. leave the affiliate blank until they fill it in 5. we dont need the add seasons / seasons button in admin - you know the day, we are in CDT 6. all past seasons get kept". Start with (1+5+6): drop the seasons setting + Admin Seasons pane, season = Central year, header picker lists seasons that have data. Then (4/4b) in `src/components/travel/TripModal.tsx`. Then (2): extract the 5 base64 logos from `docs/plans/mocks/travel-hub-source/source-2026-08-24-0820.html` lines 34-40. Then (3) = the feed PR (gc2 | statsapi, Test connection).
- **Blockers / waiting on:** Zac to merge #65 + run Admin > Database "Travel Hub". Azure->GCSQL02 reachability unknown. No local DB this session - trip/profile writes are test+build verified only.
- **Uncommitted work:** astroworld clean (LINEAGE.md + docs/ are gitignored there, entry written locally). bsb-resources: only memory files.

## ALSO OPEN - hiring/main (session fc32, 2026-09-03 12:32) — 2026-09-03 12:32

- **Project / cwd:** `C:\Users\Owner\hiring` · branch `main`
  (shell cwd was `bsb-resources`, but **zero edits there** — HEAD still `da67f978`)
- **Supersedes** the 2026-09-02 17:42 last-state (session `578f`) — same repo,
  same branch, continued thread. Recall checkpoint this session:
  `79ee50caf718c189`, session id `fc32`, domain `hiring/main`.

- **What we were doing:** closed the four code-review findings deferred on
  2026-09-02, then took Zac's and Sam's live feedback on the pitching tool —
  depth-chart controls, UTIL/DEV boxes on the field, naming tags on every
  placed object, palette and form wording.

- **Shipped this session:** ten commits, ending `fb44d2d` (lineage).
  `079e787` pitching equipment uncapped + briefs reworded ·
  `f940100` the four review findings (scenario-list disclosure, cross-area
  session leak, unrationed `/sample/open`, evaluator drew no mound) ·
  `07feb34` lineage · `31fa204` evaluator PDF fits the page ·
  `a864950` **the Sandbox never applied `unlimited_items` on either track** —
  it posts an inline scenario and the id is forced to `custom`, which names no
  file; an operator may name the preset they are previewing now ·
  `de1ccd8` calendar Location 4th, UTIL onto the grass, dev list, buckets
  pitchers-first · `09f88f9` arrows were being eaten by a dragstart ·
  `4be2aa4` DEV under 3B mirroring UTIL under 1B ·
  `8dd53b5` the drop point decides the rank ·
  `81c3f67` Misc Equipment off the pitching day, "Candidate name" ·
  `e7769e3` every object on the floor says what it is (45 items had no name).
  704 passed / 7 skipped · `node tools/test_depth_order.js` 40 passed ·
  `node tools/render_placements.js` checks 138 item×rotation combos.

- **EXACT next step:** get a REAL BROWSER onto the deployed app
  (`hirehou.up.railway.app`) and confirm the four things no test here can
  prove: (1) UTIL under 1B and DEV under 3B with magnets in them, (2) drag a
  man to the TOP of a stack — he should land top, (3) click a depth arrow and
  check it is no longer swallowed, (4) the name tags on a real bullpen.

- **Blockers / waiting on:** the playwright harness is DOWN — admin sign-in
  401s after repeated driver runs; survived a server restart and two
  `dev_seed.py` re-seeds, root cause not found (stopped after three attempts).
  Everything visual this session was verified by extracting functions and
  running them in node, which is blind to a live session. **Nothing from
  2026-09-03 has been seen in a real browser** and Zac was told so each time.

- **Uncommitted work:** `hiring` clean apart from pre-existing untracked
  `deck/`. `bsb-resources` has 86 untracked paths, all pre-existing clutter
  from other threads — nothing from this session.

