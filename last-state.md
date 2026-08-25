# Last session state - 2026-08-24 21:52 (Neyens Left-on-Left: --hand flag + swing reels)

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
