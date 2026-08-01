# Last session state - 2026-08-01 10:45 (Non-roster pitcher: Jona Widmann one-off + the crash it exposed)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen` - branch `feature/bullpen-reports` (rule also on `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Zac asked why sessions tagged `INT R` show up in Arm Farm runs (they are DSL Live AB scrimmages, working as designed) and why a signed pitcher, gcid 252980, throws in our data but appears nowhere under HOU. Then ran a one-off postgame for him, which crashed.
- **The answer:** **Jona Widmann, LHP, DOB 2007-05-14, has NO eBIS record at all** - `ebis_id` AND `mlbam_id` both NULL on `Astros.Players`, so there is no key to join `MLB_eBis.PP_MASTER` on. Not a wrong-org or wrong-level filing; there is no row to evaluate. Roster surfaces INNER JOIN PP_MASTER, `Pitches_View` gates on nothing (`pitcher_id` IS `groundcontrol_id`), hence fully present in the data and invisible everywhere a human looks. 2026 sessions: 04-16 `V`, 07-25 `B`, 07-31 `int`+`R` Live AB, all `is_int_level=1`.
- **Shipped this session:** `937c32a5` reusable diagnostic `sql-queries/gcid-252980-roster-vs-pitchdata-diagnostic.sql` (set `@gcid`; Q2 tests each roster clause independently) - `f21c8a7b` fix the `'NoneType' has no attribute 'upper'` crash - `fd8f4b59` narrow that fix - `7340b555` + `b7bae15f` new rule `non-roster-player-reports.md`, synced + committed on all 4 worktree branches. All pushed, HEAD == origin everywhere.
- **The crash:** `roster.py::_get_player_direct` sets `level_code=None`, and `player.get('level_code','')` returns **None, not `''`** - a dict default fires only on a MISSING key, never on a present-but-None value. Two sites exposed: `_draw_percentile_key` `.upper()` (hit) and `_report_title` `.lower()` (latent, masked because `is_live_ab` returns early above it).
- **The narrowing, which matters:** my first fix forced `level_code='dsl'` for Live AB, but `level_code` feeds THREE renderers - title, percentile subtitle, and the pitch-log card header. That would have relabeled the card INT->DSL, asserting a level the game was not played at. Split into a separate `pool_level_code` local passed ONLY to the subtitle.
- **Parity bug found en route (real, now fixed):** `pages/2_Postgame.py` overrides `player['level_code']` with the game level, so the **app** printed "Percentiles based on 2026 INT" for Live AB games while pulling from the DSL pool (`p_pool_lc='dsl'`, `2_Postgame.py:2146`). The CLI printed DSL. App and CLI disagreed on the same game (blocking rule #11). **This is the ONLY change to any existing report's output** - Zac checked a pre-change report and confirmed it still renders fine.
- **EXACT next step:** WORK LAPTOP: `cd C:\Users\zbridger\bsb-wt-bullpen ; git pull ; cd bullpen-report ; python scripts\generate_postgame.py --date 2026-07-31 --pitcher 252980 --output reports\oneoff` then **hand-post the PDF - never pass `--deliver`**, he has no `slack_channels.csv` row. No re-pin (rendering only). Arm Farm app redeploy optional, only for the INT->DSL subtitle on Connect.
- **UNVERIFIED - do not claim otherwise:** the POST-fix CLI run has never touched a database. No DB access on the personal laptop. Zac ran the pre-fix build; the fixed one is unrun.
- **The real fix is not code:** Widmann needs an eBIS record under HOU (Josefy / eBIS side). Until then he is invisible to the daily cascade, trackers, KPI and every dropdown, and every report on him is a hand-run.
- **Flagged, not acted on:** only Arm Farm has the `_get_player_direct` fallback. Barrelsville, Intangibles and PD Goals `get_player_by_id` return `None`, so a non-roster player **silently skips** there ("not found in roster, skipping") rather than crashing - quieter and worse. Also: `postgame_report.py::generate_reports_for_date` (line 2733) is dead code (the live one is in `src/report.py`), and the bullpen worktree has no `LINEAGE.md` to record that in.
- **Skill bug worth fixing:** `document-pattern` Step 4 copies the intangibles rule to `bsb-wt-intangibles/.claude/rules`, which is OUTSIDE that git repo. Tracked path is `bsb-wt-intangibles/astros-intangibles/.claude/rules`. Both dirs exist, so it silently succeeds untracked. Corrected by hand this session, not in the skill.
- **Uncommitted work:** bullpen 14 paths, bsb-resources 85 paths - all pre-existing clutter from earlier sessions. Nothing of this session's.

---

## ALSO OPEN - Gyro SL + cutter starter screen (bsb-resources/feature/pd-goals, from 2026-07-31 16:45, preserved)


- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Built a one-off SQL screen for MLB starters who throw BOTH a gyro-shaped slider and a cutter that still carries. Zac gave the movement thresholds verbally, then added a 10+ GS starter gate, then asked what share of all 10+ GS starters that is.
- **Shipped this session:** NEW `sql-queries/gyro-sl-plus-cutter-mlb-2026.sql` - `a6f33bfc` base screen - `269f3db5` GS >= 10 gate - `79d7fc85` share-of-population result set. All pushed, HEAD == origin.
- **The spec, as implemented:** FC avg IVB >= 4.0 (min 30 thrown); SL avg |HB| <= 8.0 AND avg IVB >= -10.0 (min 30); >= 10 MLB GS. All six thresholds are `DECLARE`s at the top, so retuning is a one-line edit.
- **Three interpretation calls I made** (all stated to Zac, none corrected): (1) the HB gate is on the ABSOLUTE value so one threshold covers RHP and LHP - a signed threshold would pass every LHP sweeper; (2) SL minimum sample = 30, same as FC - Zac only ever specified 30 for the cutter, so this one is mine; (3) -10 SL IVB is a FLOOR not a ceiling (-6 passes, -14 fails), which is what makes it gyro rather than a downer.
- **Canon applied:** movement-cleaning (drop |IVB| or |HB| >= 30 glitch reads, keep NULLs); GS from the official box `mlbam.ytd_player_pitching_stats` and never pitch-derived, SUMmed across `team_id <> 0` rows so a traded pitcher's 6 + 5 starts totals 11 instead of failing twice; OAK -> ATH on display. Built off the near-twin `ff-cu-separation-26-30in-2026.sql`.
- **EXACT next step:** Zac runs the file WHOLE on the **work laptop** (`git pull` on `feature/pd-goals`; **no `GO`** between the first two statements or the share query loses the `@variables`) and pastes the two result sets back. Then: if `[matched]` is well under `[SP w/ 10+ GS]`, an mlbam_id mapping gap is eating the numerator and the % is understated - check that before quoting it. If `[% of all SP]` and `[% of FC+SL SP]` are far apart, the rarity is mostly "few starters throw a cutter at all", not the shape pair.
- **Blockers / waiting on:** Zac on standby - "waiting on standby here". Nothing to do until he runs it.
- **UNVERIFIED - do not claim otherwise:** this has never touched a database. No DB access on the personal laptop, so the SQL has not even been parsed by a server, let alone produced a number.
- **Worth asking when he's back:** what the screen is FOR (acquisition list? pitch-design comp set for one of ours? a Sam/DJ ask?) - it shapes whatever the output becomes.
- **Uncommitted work:** 85 paths, all pre-existing untracked clutter from earlier sessions (`.agents/`, `.codex/`, `awesome-claude-skills/`, `design-system/`, `gcpy/`, `pd-goals/output/`, loose `sql-queries/*.sql`). Nothing of this session's.
- **Not mine, same branch:** `b4c31051` `563366ec` `1bcbff51` (Addari pitching-box style rewrites + a revert) belong to a concurrent thread.

---


## ALSO OPEN - OF/IF Directional Progression Report (`bsb-wt-intangibles` / `feature/astros-intangibles`, from 2026-07-31 16:06, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles`
- **What we were doing:** Designed (mockups) then BUILT a new per-player OF/IF Directional Progression Report. P1 = 8 directional roses (dual level+MLB %ile) + overall trend strip + movement table; P2 = 8x8 monthly sparkline matrix.
- **Shipped:** `09e05b10` build (report+data+CLI+test+design); `33fd5bb6` SQL fix (PERCENTILE_CONT needs SELECT DISTINCT + COUNT OVER, err 8120); `73b20321` display (3-decimal React/PAA-EO/ReactRad/ReAccRad/UseReact, WoW removed, every sparkline point value-labeled); `b04e7529` backlog. Files: intangibles/src/directional_progression_{report,data}.py + scripts/generate_directional_progression.py + shape test.
- **EXACT next step:** WORK LAPTOP: cd to intangibles worktree, git pull, run `python scripts\generate_directional_progression.py --gcid 244959 283966 168757 212518 1263308 283424 1263410 1263300 --season 2026`, then compare a player PAA/EO rose %iles vs his EOY P13 rose (parity check, feedback #4).
- **Blockers / waiting on:** Data layer WORK-LAPTOP-UNVERIFIED vs GC2 (no DB here). First real render + EOY percentile parity are the open checks. Confirm 'Nic O' gcid (no Ortiz in CSV; Nico Zeglin 282253?).
- **Uncommitted work:** clean (1 unrelated untracked catcher doc only).

---

## ALSO OPEN - Onboarding report / 2026 draft class (bsb-resources/feature/pd-goals, from 2026-07-31 06:38, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Took Camden's onboarding-meeting report (merged from `origin/cq/onboarding-report`) and finished it for the 2026 draft class. Real headshots out of the recruiting deck, page 1 filled from the department Slack threads, page 2 filled from the PD Handoff deck.
- **The pivotal fact:** Zac + Sam confirmed the report is **ATHLETE-FACING**. The source material is staff notes written ABOUT the player, so this was never a transcription job. Every note is second person, and staff-evaluation language was reframed or pulled (Galloway's "concerning/disordered eating habits", Nowak's "poor understanding of body awareness", buy-in skepticism, "extreme loner", agent criticism, a body-fat position-viability judgement, third-party family medical detail).
- **Shipped:** `9f9f2add` merge - `b54f2aa3` headshots + rectangular frame (border OUTSIDE the image, per Zac) - `3492cd7d` `extract_headshots_from_deck.py` - `9cf90d3c` staff-to-box map - `f8d0a529` page 1 for 19 players, player-facing - `27ae8256` page 2 for 22 of 23 + page 1 forced to ONE page - `cd31016d` Durnin rewrite + OUTSTANDING banner - lineage entry + `parse_pd_handoff_deck.py`. All pushed.
- **Also fixed along the way:** `_wrap_note_lines` preserves pasted Slack line breaks (the shared `_wrap_lines` was reflowing every note into one run-on paragraph); page 1 shrinks type to a 7pt floor instead of spilling a lone box; `_hard_break` stops an unbroken token running off the box; long names shrink to fit.
- **Verified:** 23 reports, 0 failed, **every one exactly 2 pages**. Voice audit returns zero third-person references to the player.
- **EXACT next step:** On the **work laptop**, pull `gc_id` / bats / throws / age / school for **John Carver, Carson Estridge and Drew Wyers** from `MLB_eBis.PP_MASTER` + `Astros.Players` **by name** - do NOT wait on `build_onboarding_scaffold.py`, the two UDFAs have no `R4_Draft_Query` row so it will never build them. Type them into the TODO markers in `pd-goals/data/onboarding_notes.yaml`, re-run `scripts/extract_headshots_from_deck.py`, then `generate_onboarding_report.py --all`.
- **Blockers / waiting on:** **Sam's review is the gate** - he said "I will need to make some edits to make sure it is all kosher." Nothing reaches a player before that. Also waiting on Butler's page-1 notes (he was absent from the Slack threads) and on Wyers, who has nothing: no headshot, no page 2, no bio.
- **Open decisions for Zac/Sam:** does Galloway's brother-with-autism detail go back in? Where do Sam Niedorf's own notes belong (currently in DEFENSE with Mazzo's)? Should notes carry the staff member's name?

---

## ALSO OPEN - PD Goals cockpit (2026-07-30, DONE + PARKED)
> Same repo/branch, different thread. Its one loose end is the Connect
> **redeploy** - the live app still serves the old build, so the deleted Goal
> Compliance tab is still visible until it ships.

- **What we were doing:** Putting a bow on the PD Goals org cockpit. Zac had already set + staggered the 12h pin schedules on both Connect pin contents, which made the "Recompute current phase (live)" button redundant - so the whole **Goal Compliance view got deleted** rather than ported. Its one genuinely unique bit (the goal window) moved onto the cockpit.
- **Shipped:** `fb73f639` - deleted the `if _view == _V_COMPLIANCE:` block (292 lines) + its constant + view-radio entry + the imports/helper only it used; added **Start / End** columns immediately after Phase on the cockpit player table (guarded for old pins). `7cbdea7b` - LINEAGE entry, corrected the two live runbooks that pointed at the deleted button (`rules/pd-goals.md`, `rules/prp-correction-resend.md`), banner-stamped the Jul 8 compliance spec **PARTIALLY SUPERSEDED** (UI dead, data model still canonical). 37 tests pass, render verified. Rules synced to all 4 worktrees.
- **Status: DONE and PARKED.** Zac: *"looks great and functions great ... for now untill we have more goals to add!!!!"* Resumes only when new goals get added. Do not invent follow-up work on it.
- **EXACT next step:** Nothing on this thread. The one loose end is a **redeploy** on the work laptop:
  `cd C:\Users\zbridger\bsb-resources ; git pull ; cd pd-goals ; rsconnect deploy manifest --server https://connect2.astros.com --api-key "$env:CONNECT_API_KEY" --app-id 79f52369-8244-46da-a4d6-95df956bacad --title "PD Goals" .\manifest.json`
  (display-only change - **no re-pin**).
- **Honest caveat, do NOT claim otherwise:** the acceptance check carried through two wraps - cockpit matrix Total vs Goal Compliance Total - was **never run, and now cannot be**. I flagged before deleting that Compliance was the only cross-check surface; Zac chose to delete anyway.
- **Known, not blocking:** at ~50% a domain bar draws nearly invisible (white midpoint on a `#eef2f6` track); contrast fix offered twice, no answer. `docs/ARCHIVED_REFERENCES.md:354` still has the Connect API key in PLAINTEXT and is git-tracked.

---

## ALSO OPEN - Range & Difficulty (`bsb-wt-intangibles` / `feature/astros-intangibles`)

From the 2026-07-30 15:38 wrap. **Zac closed it out fully** - both pins live on Connect (`intangibles_range_plays_of_2026` 38,555 x 75 / `_if_2026` 55,436 x 77), Vars + 12h schedule set on `intangibles-pin-range-plays-2026` (GUID `eb324534-ebb9-409f-a027-a716f591688b`), OF and IF both fast. Kept only for its loose ends.

- **Known, not blocking:** OF 400k-row league band read still untouched (`_fetch_league_band_plays`, `_BAND_LEVEL_FILTER` hardcoded to all 7 levels - violates `scope-percentile-pools-to-run.md`); `pd.concat` FutureWarning at `fielding_range_data.py:1074` (cosmetic now, hard error on a future pandas); any pin bundle scaffolded between the parser regression and `ac171cc6` may have a broken notebook (tell: the title line sits in a code cell - `connect_pins_fielding` and `connect_pins_br` verified good).
- **If a play ever looks wrong:** `scripts/diff_range_pin.py` is the tool (`--mode batch` for the IN-list change, `--mode pin` for the parquet round-trip; exit 0 clean / 1 real differences / 3 wrong domain for that player / 4 inconclusive).

---

## ALSO OPEN - BR 1->3 canonical rollout (`bsb-resources` / `feature/pd-goals`)

Concurrent thread on the same branch. Commits `06fcfa58` `5ee45396` `aa006003` `ff3e3bf5` belong to it (BR true 1->3 on EOY P21 + Org KPI, diff harness) - do not attribute them to the cockpit or range work. Also produced `dbe05d31` `9f00b23d` `064e5be0` `b90708ad` (br-advance-3rd-out-wash rule syncs).

**Correction carried forward:** an earlier wrap listed `ac171cc6` under this thread. It is not - `ac171cc6` is the scaffold-pin-deploy notebook-parser fix from the 2026-07-30 evening range session.
