# Last session state - 2026-08-26 19:40 (the case deck becomes two, and the reels get their metrics)

- **Project / cwd:** `C:/Users/Owner/hiring-wt-deck` - branch `director-deck-philosophy` (NEW worktree; the app session lives on `main` in `C:/Users/Owner/hiring`).
- **Recall checkpoints (SOURCE OF TRUTH):** session `3be9` - `hiring/director-deck-philosophy` id `7ea283a11bfed301`, and `bsb-resources/feature/pd-goals` id `ee33aad66c9add93`.
- **What we were doing:** Built the Neyens and Cassedy case video, then split each Director deck into a Case Assessment and a Questionnaire Resources pack per Sam. Both decks are with Sam; waiting on his feedback. Finished with his 30/30 query.

- **Shipped this session:**
  - **hiring** (`director-deck-philosophy`, 11 commits ending `9169982`): four decks off one generator - `Hitting_Case_Assessment` (12 sl), `Pitching_Case_Assessment` (12 sl / 41.5 MB), and a `Questionnaire_Resources` pack per role. New page kinds `compare` and a `bare` casevideo; casevideo wraps to a grid past two clips. Full structural record in `hiring-wt-deck/LINEAGE.md` 2026-08-26.
  - **bsb-wt-hitting** (`feature/barrelsville`, `2bc853e8`): `--speed` on `build_swing_reel.py`. 4 Neyens reels delivered.
  - **bsb-wt-bullpen** (`feature/bullpen-reports`, 7 commits ending `b2935616`): NEW `scripts/build_pitcher_reel.py`. 10 Cassedy reels with velo/spin/IVB/HB/RelZ/VAA burned in.
  - **bsb-resources** (`feature/pd-goals`, `d5e7c5d6`): `sql-queries/milb-30-hr-30-sb-seasons.sql`.

- **EXACT next step:** Nothing is mine until Sam replies. The one runnable item is on the WORK laptop - `cd C:/Users/zbridger/bsb-resources ; git pull`, then run `sql-queries/milb-30-hr-30-sb-seasons.sql` in SSMS; it has never touched a database. If it returns empty, send back `SELECT DISTINCT level FROM MLBAM.YTD_Player_Batting_Stats` and the level whitelist gets fixed.

- **Blockers / waiting on:** Sam's feedback on both Director decks (sent 2026-08-26). The 30/30 query is unrun.

- **Uncommitted work:** hiring-wt-deck 2 (derived, gitignored) - bsb-resources 77 - bsb-wt-bullpen 14 - bsb-wt-hitting 43. All pre-existing clutter from other threads; nothing from this session is uncommitted.

- **Two things that bit, both worth remembering:** a **pptx is a build artifact** - `node gen.js` overwrites Zac's PowerPoint edits, so diff his saved file before regenerating and never read a screenshot as a save. And **a clamp is not a layout** - `Math.min(y, 6.32)` drew a closing question on top of the list instead of preventing the overflow.

---

## ALSO OPEN - PD Calendar + hiring board (session `c8ee`, `hiring/main`)

Different branch, still live. Preserved verbatim from the previous wrap:

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `c8ee` - domain `hiring/main` - id `265375719cfe5418`.
- **What we were doing:** Shipped the PD Calendar into the hiring app as its second area, then kept answering Sam's and Zac's requests against it. Also split the Defensive Coach search into Infield / Outfield / Catching by writing to production directly.

- **Shipped this session:** 16 commits `9f1e5ce`..`63557b1` on `main`, all pushed. **397 tests, 7 skipped** (from 301).
  - **PD Calendar is live** - `/admin/calendar`, `/api/calendar`, migration 005. Second tile, before Cage Assessment. Off localStorage and onto a merged shared document, with a compare-and-set the board still does not have.
  - **Programs editor** - rename, colour, short label, group, region, reorder, add, hide. Delete refused while events point at it. A rename also relabels the events that were only echoing the old name.
  - **Seasons** - 2026 through `thisYear + 1`, derived from the clock. A season is a field on the event, so the merge is untouched.
  - **Export CSV** - month grid + DETAIL table, BOM and formula-injection quoting. Free-text `location` on events.
  - **Production board write** - `board_doc` v126 to v127. Defensive Coach renamed to Infield (`ROLE-00003`, id kept so nothing detached), Outfield `ROLE-00007` and Catching `ROLE-00008` created with cloned templates, `CAND-00014` repointed.
  - **Bugs found:** a deleted event came back on every load and was written back for everyone; `004` never enabled RLS so the whole board and every resume were reachable with the anon key; the save chip drew over the wordmark at 1024px; Aug 31 was dropped from the exported grid.
  - Three browser tools (`drive_calendar`, `drive_programs`, `drive_seasons`, 66 checks) + `tools/dev_seed.py`.

- **EXACT next step:** In `app/private/calendar/index.html`, rewrite `renderSeasons()` to emit a single `<select>` instead of the chip row, and delete the `" (current)"` / `" (next)"` suffixes. THEN ask Zac what "the full season" means before touching `monthsFor()` / `scopeStart()` / `scopeEnd()` - they are Sep-Dec today and everything (grid, export, date-picker clamp) derives from those three. `tests/test_calendar_route.py::test_a_season_switch_moves_everything_it_has_to` and `tools/drive_seasons.py` will both go red and need updating.

- **Blockers / waiting on:** Zac to say what the full-season window is. Four older offers never answered: rename the eval template with its role, a one-command `tools/migrate.py`, the Railway URL so the live deploy can be checked, and `board_save`'s missing CAS.

- **Uncommitted work:** clean (excluding untracked `deck/`, which belongs to the other thread below).

---

## ALSO OPEN - the case-assessment decks (`director-deck-philosophy`)

Still live, different branch, not touched this session. Previous wrap follows.


- **Project / cwd:** `C:/Users/Owner/hiring` - work split across `director-deck-philosophy` (the decks) and `main` (the app).
- **Recall checkpoint (SOURCE OF TRUTH):** session `afa8` - domain `hiring/director-deck-philosophy` - id `0f8b2d09f7227279`.
- **What we were doing:** Turned the Director of Hitting and Director of Pitching case assessments into a generated deck, page by page with Zac dictating the wording. Fixed three things in the cage-sandbox app on the way through.

- **Shipped:** 11 commits `ab0e474`..`e3300fa` on `director-deck-philosophy`, 4 commits `8fe07a7`..`lineage` on `main`. 301 tests / 7 skipped, up from 280. LINEAGE entry written.
  - **`hiring/deck/` is new.** `gen.js` (pptxgenjs) reads `content/<role>.json` and emits **Hitting, 14 slides** and **Pitching, 9 slides**. Nobody edits a PPTX. Twelve page kinds. Three guards each proven red, and the house-rule check (em dash / en dash / non-ASCII) failed the very first build on a character I had written myself.
  - **Everything derivable is derived.** The "1 OF 4" eyebrows, "Section 2 of 3", and each divider's list of its own pages were typed strings; adding a fourth philosophy page would have left a stale count somewhere, silently.
  - **A clip is a named file now.** `videoBlock` built `${base}_angle${i+1}`, which worked with one player's video and broke when a second arrived as `neyens_lhp_ev100_cf.mp4`. A
