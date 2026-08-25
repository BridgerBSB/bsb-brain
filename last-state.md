# Last session state - 2026-08-25 15:20 (EOY note line breaks + the S&C weight load)

- **Project / cwd:** `C:/Users/Owner/bsb-resources/pd-goals` - branch `feature/pd-goals` (Arm Farm half on `bsb-wt-bullpen` / `feature/bullpen-reports`).
- **Recall checkpoint (SOURCE OF TRUTH):** session `279b` - domain `bsb-resources/feature/pd-goals` - id `167afc64c676860d`.
- **What we were doing:** A coordinator typed an off-season goal as two lines and the delivered deck drew it as one. Fixed the renderer, then bulk-loaded 186 players' off-season bodyweights into Goal #1 on page 2 of both EOY decks so nobody had to type them.
- **SHIPPED AND LIVE.** App redeployed, 154 notes written and verified by re-read, Zac confirmed "it all went thru". EOY is wrapped at his call until more updates come in.
- **The defect:** `textwrap.wrap` defaults `replace_whitespace=True`, so every newline and tab became a space. The pin and the app text box were correct the whole time - the ONLY surface that showed it was the deck already sent to a player. `aeaf0fcc`.
- **Shipped:** `src/eoy_text_block.py` is now the single path every note box takes (stdlib-only, so it imports identically in the pd-goals and Arm Farm bundles); it superseded four independent wrap idioms, one of which was already right. Arm Farm half `cd76354f`, port `--check` in sync. Plus `scripts/load_offseason_weights.py` + the committed extract `data/offseason_weights_2026.csv`. Rule `.claude/rules/bulk-load-into-a-pin.md` (`1ca335f6`) synced to all 4 worktrees; LINEAGE `37aee219`.
- **Deliberately NOT converted:** the pitcher deck's `_draw_commentary_box` took the paragraph half only. Those boxes hold ~2 lines at 9pt, so fitting to the box turned a visible overflow into a SILENT one-line truncation - the render showed it. Overflowing loudly beats disappearing quietly.

- **EXACT next step:** Nothing queued - Zac wrapped EOY. When it resumes: Camden hand-enters the 10 held rows (8 have no 2027 goal weight, Loperfido has no 2026 end, Lambert has neither) and confirms whether the 8 names with no EOY pool row (Aparicio, Burleson, Delgado, MacRae, McPherson, Ramos, Rodriguez L.A., Walter) are legitimately absent or a roster gap.

- **Blockers / waiting on:**
  - **`rsconnect.exe` needs a STANDING IT approval**, not a per-invocation response code. Application whitelisting refuses to launch it; cancelling that dialog prints `No process is associated with this object`, which reads like a broken install and is not. Every Connect deploy is gated behind it. Logged in `docs/verification-backlog.md`.
  - **The Connect API key was pasted in plaintext** in terminal output and is legible in a screenshot. Flagged twice; rotation not confirmed.
  - If S&C fills the missing 2027 goals, re-run with `--xlsx` **and** `--save-csv`, or the committed CSV silently falls behind the workbook.
- **Uncommitted work:** 1 file - `pd-goals/docs/plans/2026-08-20-scheduled-workload-inventory-for-it.pdf`, pre-existing, not mine.

---

## ALSO OPEN - Neyens Left-on-Left (another session, 2026-08-24)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` - branch `feature/barrelsville` (also `bsb-resources` / `feature/pd-goals`).
- **Recall checkpoints (SOURCE OF TRUTH):** session `97c6` - `bsb-wt-hitting/feature/barrelsville` id `11016fc5f4c5f122`, and `bsb-resources/feature/pd-goals` id `5fb2b46515b6bcc7`.
- **What we were doing:** Building the Left-on-Left case materials for the Director of Hitting deck - Xavier Neyens (gc 244959) vs LHP. Scoped `hitter_analysis.py` to a single handedness faced, wrote the splits/log SQL, and built two-angle swing reels from clips Zac pulled on the work laptop.
- **Shipped this session:** 8 commits on `feature/barrelsville` (`07397c57`..`4f8a56da`) + 4 on `feature/pd-goals` (`9d20463f`, `788baf5b`, `8a8401ce`, `a49ff57c`). `--hand L|R` scopes the whole hitter report to handedness faced; the Swing Path page's filter bypass fixed; `build_swing_reel.py` built with `--batter` / `--download-only` / `--ev-min` / local-path modes; reels delivered (`neyens_lhp_cf.mp4` 29 clips, `neyens_lhp_side.mp4` 28 clips, + manifest) to `C:/Users/Owner/Downloads`. Two documented facts corrected: video angle `'H'` is the OPEN SIDE VIEW (db-columns.md said "high home", which sent a query to the wrong angle), and a fourth standing IT constraint - unapproved executables are blocked by application whitelisting, **bundled pip binaries included**.
- **The finding:** vs LHP he is .365 xwOBA / .303 xSLG on 93 PA vs .422 / .447 on 328 vs RHP. The story is the breaking ball: **51.4% whiff on 37 swings**, he offers at only 21.1% of them, and lefties throw it 42% of the time.

- **EXACT next step:** Zac is re-collecting with a wider contact cut on the work laptop - `python scripts/build_swing_reel.py --batter 244959 --out neyens_lhp_ev100 --ev-min 100 --download-only` - and will send back `clips/` + `neyens_lhp_ev100_local.csv`. Unzip into a scratch dir and run the same script WITHOUT `--download-only`, with `--clips-dir` pointed at it, then send the two MP4s.

- **Blockers / waiting on:** Zac's re-collected clips. Also unanswered: whether he wants a single hstacked side-by-side video, because the two reels are index-aligned but NOT time-aligned (277s vs 247s) and will drift if played beside each other on a slide.
- **Uncommitted work:** 41 files in `bsb-wt-hitting`, 77 in `bsb-resources` - none of them mine.

---

## ALSO OPEN - hiring board (different thread, do not delete)

- **Project / cwd:** `C:/Users/Owner/hiring` - branch `main`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `2b36` - domain `hiring/main` - id `f1bca9513dc5e3c5`.
- **What we were doing:** Recovered a session that died to a machine crash mid-morning, then took the Astros Hiring Board from one-browser-only to a live shared backend, built the owner-only User Management page, restructured the admin surface to three areas, turned two labels into real mechanisms, and acted on a code review of the whole day.
- **Shipped this session:** 16 commits `56f7a18`..`2ff7372`, all pushed to `BridgerBSB/hiring`. 280 tests / 7 skipped (was 210 at session start). **Migration 004 applied to production Supabase** - `board_doc` + `board_blob` created, board confirmed saving live at v6+. Postgres round-trip proven by hand before handing it over. Shipped: shareable URLs + real browser Back; the `renumber` bug that was rewriting every `CAND-000xx` on first save; acting-as leaking one person's identity to everyone; the accounts becoming the single list of people (adding an account now makes somebody an evaluator); `/admin/access` with a mailed first password and a forced change; three areas (Hiring Board / Cage Assessment / User Management); the blind evaluation hold-out made real; private notes made per-person and withheld by the server. Full decision record in `LINEAGE.md` (`2ff7372`).

- **EXACT next step:** Make `board_save` atomic. `app/board_api.py:170` reads head, merges and writes with no transaction and no compare-and-set on `version`, so two saves ~50ms apart both merge against the same head and the second silently drops the first. Fix = conditional insert in `db.board_write` (INSERT only where the current head version still equals the base the caller merged against), returning None on conflict, and `board_save` re-merging once against the new head before giving up. This is the last known data-loss hole and it bites exactly when Zac and Sam are both on the board.

- **Blockers / waiting on:**
  - **Zac, in the Railway dashboard:** set **Watch Paths** to `cage-sandbox/**`. Root Directory scopes the BUILD only, so a markdown-only commit on `main` likely redeploys the live app. Until then, assessment work belongs on a branch. Region is also still US East vs Supabase us-west-2.
  - **Never done with two humans:** two browsers editing the live board at once (the merge is heavily unit-tested and has never met a second person), and the User Management password email actually landing in an `@astros.com` inbox - check junk, Defender ate their magic links before.
  - Smaller, all recorded in LINEAGE OPEN: N+1 queries per access-page render; `navDepth` decrements on Forward as well as Back; `list_accounts` orders a NULL role differently on sqlite vs postgres; two UI strings describing a toggle that was deleted and an export that no longer carries other people's notes.

- **Uncommitted work:** clean.

---

## ALSO OPEN - Director of Hitting technical assessment (another session)

Planning, not built. Philosophy 25 / Scaling 45 / Mechanical 30, markdown canonical with the deck as a build artifact, built off the June 2026 entry-level Hitting Coach deck in `hiring/reference/hitting-coach-2026/`. First proposed step: audit the three hitting pillar files against the ~144 KB of hitting notes in the vault, because nothing has yet checked that the assessment tests what the org actually believes. Blocked on two real players (~22, on the 2027 clock), video clips, and four of Zac's calls (take-home vs timed, live vs sent-then-discussed, does the walkthrough shrink the 9.5 hours, is it recorded).
