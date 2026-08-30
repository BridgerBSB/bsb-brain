# Last session state - 2026-08-30 12:00
- **Project / cwd:** `C:/Users/Owner/bsb-resources` branch `feature/pd-goals`, and `C:/Users/Owner/bsb-wt-bullpen` branch `feature/bullpen-reports`
- **What we were doing:** Closed out the Aug 29 EOY notes deletion. Recovered what could be recovered, then made the deletion mechanism structurally impossible and shipped it to both apps.
- **Shipped this session:**
  - `40c77bf1` **the merge fix** - a save no longer reverts work that landed after its own read. `_pin_write_notes` was re-reading the pin for its anti-shrink guard and then throwing that fresh copy away; it now rebases, applying only the cells this save changed. Guard: `pd-goals/scripts/test_eoy_note_concurrent_merge.py`, whose section 5 disables the merge and asserts the OLD path still loses the row.
  - `0313f6fc` blank guard ported to Arm Farm's `eoy_notes.py` (its own pin, `zbridger/eoy_pitcher_notes`, still had the Aug 29 bug).
  - `57f4192a` the pitcher nightly job pins **payloads**, not just pools - the position side has done both since August. NEVER `--level` on the payloads step: pools MERGE, payloads REPLACE the whole bundle.
  - `ce5fbefd` the pin bundle ships `pyarrow`. Without it `_attach_goals` would have pinned ~200 payloads with **empty goals**, silently, inside a try/except.
  - `a9a40af1` verification backlog. `677d81bc` LINEAGE.
  - **All deployed**: PD Engine bundle 60821, Arm Farm 60822, pin bundle after an rsconnect fight.
  - **Recovery final:** 242 boxes / 184 players live. 168 of 186 Goal 1 weights restored from the committed CSV. Neyens + Curry from saved PDFs. Schiavone unrecoverable, confirmed.
- **EXACT next step:** Read the next scheduled run of `arm-farm-pin-eoy-pitcher-pools-2026` in the Connect log for the line `[notebook] STEP 2 -- payloads (full run, all levels, ~40 min)` AND for the ABSENCE of `[EV-P95] pin miss ... ImportError`. Those two prove the new bundle is active and that pyarrow landed. The 04:14 UTC run predated the deploy and had neither.
- **Blockers / waiting on:**
  - **rsconnect is broken on the work laptop and will recur.** `connect_pins_eoy/deploy.ps1` probes `py -3.11 -m rsconnect`, which can never work (it is a package with no `__main__`), falls through to `Get-Command`, and gets a NON-whitelisted exe that dies with `Program 'rsconnect.exe' failed to run: No process is associated with this object`. Workaround every time, and it must be a REAL PATH because the var is `Test-Path`-ed and a command string both fails and skips the remaining fallbacks:
    `$env:RSCONNECT_EXE = "C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe"`
  - Zac to run: two-browser check of the merge fix (one window CANNOT detect it), the 4 weights by hand (Alvarez / Amador / Borquez / Mancini), IT about pin versions before ~08:00 Aug 29, copy `~/Desktop/eoy_backups/*.txt` off the laptop.
  - **He told the group everything was lost except the Completion tab, and that it will never happen again.** Both overstate it - 242 boxes ARE in the app and coordinators should look before retyping. Flagged to him; may need walking back.
- **Uncommitted work:** bsb-resources 77 paths, bsb-wt-bullpen 11 - all pre-existing untracked dirs from before this session.

---

# Last session state - 2026-08-30 12:00
- **Project / cwd:** `C:/Users/Owner/hiring` (cage-sandbox/, BridgerBSB/hiring) - branch `main`
- **What we were doing:** Designed and shipped **COMPARE mode** on the Astros Multipurpose **magnet board** - your projection beside other people's, and beside your own past. Then fixed retention + roles, and made sharing send an email. Zac ended the session testing a real share to Sam on the live app.
- **Shipped this session:** eleven commits, all pushed to `main`.
  - `42af2ba` **compare built into the real page**, driven in a real browser (19 checks, `tools/drive_compare.py`, 236 seeded players + 3 boards via `tools/dev_seed_compare.py`).
  - Design + rendered mocks first: `4afe0a9` `1980d01` `60cd682` `920412d` `3a7eab9` `5391f0e`. Renders in `cage-sandbox/docs/renders/magnets-09..14-*.png`.
  - `c19eb18` **history is INFINITE** (`db.MAGNET_HISTORY` 40 -> 0; the old value PRUNED ON EVERY WRITE in both DB paths, so a debounced afternoon of dragging deleted the morning). `BOARD_HISTORY`/`CALENDAR_HISTORY` untouched.
  - `c19eb18` also: **coordinators were never blocked** from being shared with - my flaws review said they were, on the strength of a docstring written before the role existed. Prose fixed + regression test.
  - `2e678e1` **sharing now emails the person.** Fires on the DIFFERENCE in `unlocked_to` across a write, never on "list is non-empty" (the debounce would spam). Revoking silent on purpose.
  - Security: a historical version read is gated by the **HEAD's** unlock list, never the old document's own. Proven by injection.
  - **526 pytest passed / 7 skipped.** Flaws review written BEFORE the build: `cage-sandbox/docs/magnet-board-compare-flaws.md`.
- **EXACT next step:** The **retention conversation Zac deferred** ("we will chat more about history after you do so"). Nothing trims `magnet_doc` now and a board is tens of KB per save. Get ONE number first - how many times a board actually saves in a working day (saves are debounced during dragging) - then choose between (a) keep every save but collapse days older than N to their last, (b) keep everything and move cold rows out, (c) keep everything and watch the size.
- **Blockers / waiting on:**
  - Zac was mid-test sharing to Sam on the live app. Nothing blocked pending it; if it failed the useful detail is **which** of the three failed - the email, Sam's picker, or the compare table.
  - **The Postgres path has never run.** Every test and screenshot was local SQLite and the tests explicitly unset `DATABASE_URL`, so the `store.py` halves of BOTH history changes have literally never executed. Highest-risk untested code.
  - Compare shows nothing in production until two people have saved project boards and one unlocks to the other.
  - App moved: **`https://multi-purpose-ston.up.railway.app`** (IT blocked `hirehou`). `DEPLOY.md` repointed, 8 refs.
- **Uncommitted work:** `hiring` clean except untracked `deck/` (not from this session). Local rig left RUNNING: uvicorn on `127.0.0.1:8799` against the cage-sandbox sqlite.
