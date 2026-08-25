# Last session state - 2026-08-25 16:45 (the case assessments become a generated deck)

- **Project / cwd:** `C:/Users/Owner/hiring` - work split across `director-deck-philosophy` (the decks) and `main` (the app).
- **Recall checkpoint (SOURCE OF TRUTH):** session `afa8` - domain `hiring/director-deck-philosophy` - id `0f8b2d09f7227279`.
- **What we were doing:** Turned the Director of Hitting and Director of Pitching case assessments into a generated deck, page by page with Zac dictating the wording. Fixed three things in the cage-sandbox app on the way through.

- **Shipped:** 11 commits `ab0e474`..`e3300fa` on `director-deck-philosophy`, 4 commits `8fe07a7`..`lineage` on `main`. 301 tests / 7 skipped, up from 280. LINEAGE entry written.
  - **`hiring/deck/` is new.** `gen.js` (pptxgenjs) reads `content/<role>.json` and emits **Hitting, 14 slides** and **Pitching, 9 slides**. Nobody edits a PPTX. Twelve page kinds. Three guards each proven red, and the house-rule check (em dash / en dash / non-ASCII) failed the very first build on a character I had written myself.
  - **Everything derivable is derived.** The "1 OF 4" eyebrows, "Section 2 of 3", and each divider's list of its own pages were typed strings; adding a fourth philosophy page would have left a stale count somewhere, silently.
  - **A clip is a named file now.** `videoBlock` built `${base}_angle${i+1}`, which worked with one player's video and broke when a second arrived as `neyens_lhp_ev100_cf.mp4`. A naming convention had become the thing deciding what a page could show.
  - **`8fe07a7`** a signed-out browser was shown `{"error":"Not signed in.","status":401}` **as the page**. Fixed by changing how the refusal RENDERS for a browser navigation, never by adding a gate - `require_admin` still decides. `/login` gained `next`, and `safe_next` with it, because a `next` with no guard is an open redirect.
  - **`51c1eb4` Add Position was never missing.** Settings > Hiring Roles has had a working "+ Add Hiring Role" since release. Sam could not find it because you look for "add another one of these" beside the ones you can already see. Added a dashboard tile calling the same `roleForm(null, null)`.
  - Read all six HTKCH PDFs (185pp). Hitting Biomechanics is the movement document by far; Swing Flaws is the most operational; Big 3 holds the trainability table. Substance goes in the never-send evaluator kit, never on a slide.

- **EXACT next step:** Build the PD Calendar per `cage-sandbox/docs/calendar-build-spec.md`. **Open with the one question the spec leaves for Zac: admin, or owner only?** Then `app/private/calendar/index.html` + `app/calendar_api.py` with the guard on the ROUTER + migration 005 `calendar_doc`, and write its save as a **conditional insert** rather than copying `board_save`.

- **Blockers / waiting on:**
  - **DO NOT COPY `board_save`.** `app/board_api.py:170` read-merge-writes with no transaction and no compare-and-set, so two saves ~50ms apart drop one. Still the last known data-loss hole.
  - **Two assessments now exist.** `assessments/_shared/01-philosophy.md` (4 prompts) and `02-scaling.md` (8 prompts) are unchanged and overlap **nothing** in the deck, and `04-evaluator-scoring.md`'s prompt keys still point at the markdown. Whichever wins, the other goes, and the pitching twin moves with it. Unruled.
  - **The video deck is 92MB** - 8MB from GitHub's hard limit and too big to email. Measured fix: 854-wide CRF30 halves each clip in ~27s. The better answer is probably to stop embedding and use Drive links; the plumbing already exists (each `videos` entry takes a `link`). **Zac is uploading the 7 clips; the PDFs carry zero links today, verified rather than assumed.**
  - **The centre-field poster frame shows a scoreboard** - "WIL 0, FAY 1, 5th" - naming the affiliate, opponent, score and inning on a slide whose whole premise is an anonymous hitter. Fixable by picking a frame between pitches.
  - **Verify "28 of 30 in MiLB average fastball velocity"** on pitching Environment Q5. It is the only externally checkable fact in either deck.
  - Hitting calls the mind map page "Applying the Standard"; pitching calls it "Scaling Tenets". Same question, two names.
  - Pitching Breakdowns is absent entirely (3-4 pages, later). Neyens page 13 still needs its data.
  - **Zac, in Railway:** Watch Paths -> `cage-sandbox/**`. Any commit on `main` redeploys the live app.
  - The staff-password email fix is still **unverified in production** (Cristian Perez / Camden).

- **Uncommitted work:** `hiring` clean apart from `?? deck/` on `main` (deck/ lives on the branch). `bsb-resources` untouched this session.

---

## ALSO OPEN - EOY note line breaks + the S&C weight load (another session, earlier today)

Session `279b` - domain `bsb-resources/feature/pd-goals` - recall id `167afc64c676860d`. **Shipped and live**, Zac confirmed "it all went thru"; EOY wrapped at his call until more updates arrive.

`textwrap.wrap` defaults `replace_whitespace=True`, so every newline became a space and a two-line coordinator note drew as one - on the deck already sent to a player, while the pin and the app text box were correct the whole time (`aeaf0fcc`). `src/eoy_text_block.py` is now the single path every note box takes, superseding four wrap idioms. Arm Farm half `cd76354f`. Plus `scripts/load_offseason_weights.py` + `data/offseason_weights_2026.csv` (186 players, 154 notes written and verified by re-read). Rule `bulk-load-into-a-pin.md` (`1ca335f6`) synced to all 4 worktrees; LINEAGE `37aee219`.

Deliberately not converted: the pitcher deck's `_draw_commentary_box` took the paragraph half only, because those boxes hold ~2 lines at 9pt and fitting to the box turned a visible overflow into a silent truncation.

When it resumes: Camden hand-enters the 10 held rows, and confirms whether the 8 names with no EOY pool row (Aparicio, Burleson, Delgado, MacRae, McPherson, Ramos, Rodriguez L.A., Walter) are legitimately absent or a roster gap. **The Connect API key was pasted in plaintext and is legible in a screenshot - flagged twice, rotation not confirmed.** If S&C fills the missing 2027 goals, re-run with `--xlsx` **and** `--save-csv` or the committed CSV silently falls behind.
