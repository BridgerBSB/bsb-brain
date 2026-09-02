# Last state — 2026-09-02, hiring app

Resume point after `/clear`. Full detail: `C:\Users\Owner\hiring\LINEAGE.md`
(top entry) and recall checkpoint `38d2c3c09276878c` / session `7269`.

---

## What shipped

Nine commits on `BridgerBSB/hiring` main, `a029802` through `746c791`.
**650 tests pass, 7 skipped** (563 at session start).

**Candidate Rubrics** — `/admin/rubrics` (enter + your own submissions) and
`/admin/rubrics/results` (owner + admin only, invisible to a coordinator).
The three written sections score today; only Sam's questionnaire criteria are
still blocked. Tile is deliberately GREY, "Not set up yet", still clickable.

**Pitching Environment (the 8 pack)** — real brief, roster and geometry, its
own dashboard tile, sendable from the invite form's Scenario dropdown. Same
area, same permissions, same invite as the cage assessment.

---

## THE ONE THING TO PICK UP FIRST

Zac, at the end of the session: *"idk why teh fuck pitchign environment takes
us to cage assessment u fucked up but oh well theres too mcuh context and we
will address this next tiem here"*.

The Pitching Environment tile lands on `/admin/invites`, whose nav strip
highlights **Cage Assessment**, because one area serves both exercises. Correct
for access, reads as a mis-link. **Fix it without splitting the area** — a
lane-aware heading or subnav on the invites page when `?scenario` is set is
probably enough. He deferred it; do not re-litigate the one-area decision, the
security tests all rest on it.

---

## Waiting on Zac

1. **`migrations/009_candidate_rubrics.sql` — apply by hand in the Supabase SQL
   editor.** NOT confirmed applied. `migrations/CHECK_WHAT_IS_APPLIED.sql` (also
   on his Desktop) says what is on the database in one result set. Confirmed so
   far: 008 is applied (`admins_role_check` contains `coordinator`) and the
   policy query returns zero rows, which is what we want.
2. **Three numbers in the 8 pack are mine, not Sam's** — the 76 x 12 lane, the
   16 arms and their five groups, the 3 catchers. Listed at the bottom of
   `constraints/PITCHING-8PACK.md`. Each is one value in one JSON file.
3. **"Gadgets"** — named in Sam's inventory with no specification, no palette
   entry.

---

## Deliberately not done

- The hiring board's `role.category` → `role.domains` read-migration (section 1
  of the rubrics design). 26 sites in a 552 KB single-file page; the rubric owns
  the canonical eight tags and does not need it.
- `auth.dashboard()`'s `role_for(addr) or ROLE_ADMIN` — pre-existing sibling of
  a fail-open fixed elsewhere. Flagged, untouched: changing it alters what a
  role-less admin sees, which is a product call.
- `data/PALETTE.md` has drifted twice; ten rows describe items the palette no
  longer has. Named at the top of that file rather than reconciled row by row.

---

## Process lessons from this session

- **Run the test suite ALONE.** Two pytest processes against one
  `data/cage.db` produce 5 to 42 phantom `test_magnet_api` failures, a
  different count every run. I chased that before spotting it was mine.
- **A test that executes at module scope runs during COLLECTION**, before every
  other test file. Mine popped `ADMIN_EMAILS` and broke `test_auth`.
- **An HTML comment ships to the browser.** The rubrics template explained the
  invisibility rule by naming the area it hides.
- **The Supabase SQL editor renders only the LAST result set.** A multi-select
  check file looks like it answered when most of it was invisible.
- **The `/security-review` skill reads the SESSION cwd**, which is
  `bsb-resources`. It diffed 13 MB of the wrong repo. Point it at the right one.
- **Don't rewrite copy on a surface you were not asked to touch.** I changed the
  Cage Assessment blurb and had to put it back.
