# Last session state — 2026-09-03 12:32

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
