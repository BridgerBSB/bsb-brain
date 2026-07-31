# Last session state - 2026-07-31 06:38 (Onboarding report -> player-facing, 2026 draft class)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Took Camden's onboarding-meeting report (merged from `origin/cq/onboarding-report`) and finished it for the 2026 draft class. Real headshots out of the recruiting deck, page 1 filled from the department Slack threads, page 2 filled from the PD Handoff deck.
- **The pivotal fact:** Zac + Sam confirmed the report is **ATHLETE-FACING**. The source material is staff notes written ABOUT the player, so this was never a transcription job. Every note is second person, and staff-evaluation language was reframed or pulled (Galloway's "concerning/disordered eating habits", Nowak's "poor understanding of body awareness", buy-in skepticism, "extreme loner", agent criticism, a body-fat position-viability judgement, third-party family medical detail).
- **Shipped this session:** `9f9f2add` merge - `b54f2aa3` headshots + rectangular frame (border OUTSIDE the image, per Zac) - `3492cd7d` `extract_headshots_from_deck.py` - `9cf90d3c` staff-to-box map - `f8d0a529` page 1 for 19 players, player-facing - `27ae8256` page 2 for 22 of 23 + page 1 forced to ONE page - `cd31016d` Durnin rewrite + OUTSTANDING banner - lineage entry + `parse_pd_handoff_deck.py`. All pushed, HEAD == origin.
- **Also fixed along the way:** `_wrap_note_lines` preserves pasted Slack line breaks (the shared `_wrap_lines` was reflowing every note into one run-on paragraph); page 1 shrinks type to a 7pt floor instead of spilling a lone box; `_hard_break` stops an unbroken token running off the box; long names shrink to fit.
- **Verified:** 23 reports, 0 failed, **every one exactly 2 pages**. Voice audit returns zero third-person references to the player.
- **EXACT next step:** On the **work laptop**, pull `gc_id` / bats / throws / age / school for **John Carver, Carson Estridge and Drew Wyers** from `MLB_eBis.PP_MASTER` + `Astros.Players` **by name** - do NOT wait on `build_onboarding_scaffold.py`, the two UDFAs have no `R4_Draft_Query` row so it will never build them. Type them into the TODO markers in `pd-goals/data/onboarding_notes.yaml`, re-run `scripts/extract_headshots_from_deck.py`, then `generate_onboarding_report.py --all`.
- **Blockers / waiting on:** **Sam's review is the gate** - he said "I will need to make some edits to make sure it is all kosher." Nothing reaches a player before that. Also waiting on Butler's page-1 notes (he was absent from the Slack threads) and on Wyers, who has nothing: no headshot, no page 2, no bio.
- **Open decisions for Zac/Sam:** does Galloway's brother-with-autism detail go back in? Where do Sam Niedorf's own notes belong (currently in DEFENSE with Mazzo's)? Should notes carry the staff member's name?
- **Uncommitted work:** ~85 paths, but all pre-existing untracked clutter from earlier sessions (`.agents/`, `.codex/`, `awesome-claude-skills/`, `design-system/`, `gcpy/`, `pd-goals/output/`, loose `sql-queries/*.sql`). **Nothing from this session is uncommitted.**

---

## ALSO OPEN - PD Goals cockpit (2026-07-30, DONE + PARKED)
> Kept from the previous wrap. Same repo/branch, different thread. Its one
> loose end is the Connect **redeploy** - the live app still serves the old
> build, so the deleted Goal Compliance tab is still visible until it ships.

- **Project / cwd:** `C:/Users/Owner/bsb-resources` · branch `feature/pd-goals`
- **What we were doing:** Putting a bow on the PD Goals org cockpit. Zac had already set + staggered the 12h pin schedules on both Connect pin contents, which made the "↻ Recompute current phase (live)" button redundant — so the whole **Goal Compliance view got deleted** rather than ported. Its one genuinely unique bit (the goal window) moved onto the cockpit.
- **Shipped this session:** `fb73f639` — deleted the `if _view == _V_COMPLIANCE:` block (292 lines) + its `_V_COMPLIANCE` constant + its view-radio entry + the imports/helper only it used; added **Start / End** columns immediately after Phase on the cockpit player table (guarded for old pins). `7cbdea7b` — LINEAGE entry, corrected the two live runbooks that pointed at the deleted button (`rules/pd-goals.md`, `rules/prp-correction-resend.md`), banner-stamped the Jul 8 compliance spec **PARTIALLY SUPERSEDED** (UI dead, data model still canonical), flipped the Jul 29 cockpit spec off "Not yet built". 37 tests pass, py_compile clean, render verified via Playwright → `docs/plans/mocks/pd-goals-cockpit/phase5-start-end-columns.png`. Rules synced to all 4 worktrees. HEAD == origin.
- **Correction to my own earlier handoff:** the previous wrap said the cockpit's player table was "one row per PLAYER, so goal-level detail vanishes entirely." That was **wrong** — it was already goal-level. The only real loss was the goal window, hence Start/End. The Level × Pitcher/PositionPlayer matrix is covered by the cockpit's header **Type** filter.
- **Status: DONE and PARKED.** Zac: *"looks absolutely fantastsic … looks great and functions great … for now untill we have more goals to add!!!!"* This thread resumes only when new goals get added. Do not invent follow-up work on it.
- **EXACT next step:** Nothing on this thread. The one loose end is a **redeploy** — the live app still serves the old build, so the deleted tab is still visible on Connect until someone runs, on the work laptop:
  `cd C:\Users\zbridger\bsb-resources ; git pull ; cd pd-goals ; rsconnect deploy manifest --server https://connect2.astros.com --api-key "$env:CONNECT_API_KEY" --app-id 79f52369-8244-46da-a4d6-95df956bacad --title "PD Goals" .\manifest.json`
  (display-only change — **no re-pin**).
- **Blockers / waiting on:** None. Both pin jobs are scheduled every 12h and staggered (Zac did this between sessions — it is what killed the Recompute button).
- **Honest caveat, do NOT claim otherwise:** the acceptance check carried through the last two wraps — cockpit matrix Total vs Goal Compliance Total for the same Year+Phase — was **never run, and now cannot be**. I flagged before deleting that Compliance was the only cross-check surface; Zac chose to delete anyway. Defensible (same pin, same `aggregate_by_domain` / `goal_status`, and a test asserts `_snapshot_counts` agrees with `aggregate_by_domain`) but the two surfaces were never numerically diffed.
- **Known, not blocking:** at ~50% a domain bar draws nearly invisible (white midpoint on a `#eef2f6` track — Outfield at 50% reads as an empty bar); contrast fix offered twice, no answer. `docs/ARCHIVED_REFERENCES.md:354` still has the Connect API key in PLAINTEXT and is git-tracked.
- **Uncommitted work:** bsb-resources 106 files — all pre-existing/unrelated (slide-deck scripts, eoy-catching png, untracked `.claude/` scaffolding, sql-queries). Nothing of this session's is uncommitted.
- **Not mine, same branch:** `dbe05d31` `9f00b23d` `064e5be0` `b90708ad` (br-advance-3rd-out-wash rule syncs) and `d436705d` `71e98cad` (onboarding notes + gitignore) belong to a concurrent thread.

---

## ALSO OPEN — Range & Difficulty (`bsb-wt-intangibles` / `feature/astros-intangibles`)

From the 2026-07-30 15:38 wrap. **Zac closed it out fully** — both pins live on Connect (`intangibles_range_plays_of_2026` 38,555 × 75 / `_if_2026` 55,436 × 77), Vars + 12h schedule set on `intangibles-pin-range-plays-2026` (GUID `eb324534-ebb9-409f-a027-a716f591688b`), OF and IF both fast. Kept only for its loose ends.

- **Known, not blocking:** OF 400k-row league band read still untouched (`_fetch_league_band_plays`, `_BAND_LEVEL_FILTER` hardcoded to all 7 levels — violates `scope-percentile-pools-to-run.md`); `pd.concat` FutureWarning at `fielding_range_data.py:1074` (cosmetic now, hard error on a future pandas); any pin bundle scaffolded between the parser regression and `ac171cc6` may have a broken notebook (tell: the title line sits in a code cell — `connect_pins_fielding` and `connect_pins_br` verified good).
- **If a play ever looks wrong:** `scripts/diff_range_pin.py` is the tool (`--mode batch` for the IN-list change, `--mode pin` for the parquet round-trip; exit 0 clean / 1 real differences / 3 wrong domain for that player / 4 inconclusive).

---

## ALSO OPEN — BR 1→3 canonical rollout (`bsb-resources` / `feature/pd-goals`)

Concurrent thread on the same branch. Commits `06fcfa58` `5ee45396` `aa006003` `ff3e3bf5` belong to it (BR true 1→3 on EOY P21 + Org KPI, diff harness) — do not attribute them to the cockpit or range work. As of this wrap it has also produced `dbe05d31` `9f00b23d` `064e5be0` `b90708ad` (br-advance-3rd-out-wash rule syncs).

**Correction carried forward:** an earlier wrap listed `ac171cc6` under this thread. It is not — `ac171cc6` is the scaffold-pin-deploy notebook-parser fix from the 2026-07-30 evening range session, made while scaffolding `connect_pins_range`.
