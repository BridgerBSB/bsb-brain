# Last session state - 2026-08-05 15:44 (BR 1-3 wash: onto the Connect rhythm, verified end to end)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` - branch `feature/astros-intangibles`
- **Recall checkpoint:** session `4946`, domain `bsb-wt-intangibles/feature/astros-intangibles`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Resumed after a machine crash. Goal was to get the 1-3 / 2-H 3rd-out-wash correction onto a self-maintaining Connect rhythm. The rhythm was ALREADY coded (`15a8f387`, Jul 30 - the wash refresh rides inside `pin_br_tracker_seasons.py`, which the `connect_pins_br` 12h job already runs). What was broken was everything around it.

- **Shipped (all pushed):** `a9ee56ae` notebook said 6h + named only 1 of its 2 pins - `8bf52445` **pyarrow** - `b07104a0` org canon on the fact side - `cb198bf9` **NaN-set duplicate row, 3 trackers** - `c342b950` `check_wash_org_coverage.py` - `312c89af` rules + precautionary catching dedupe - `4c923522` rules onto `feature/pd-goals`.

- **FOUR DEFECTS, ALL SILENT, ALL DOWNSTREAM OF A CORRECT DETECTOR.** The detector found all 104 on its first scheduled run four days ago; nothing wrong was ever in the baseball. (1) **No pyarrow** - tracker pin is joblib, fact pin is parquet; the job printed its 104 then `pin write failed: ImportError` and **exited 0**. Tracker self-healed via live fallback, but PD-Goals reads that pin and has no detector, so two worktrees silently disagreed. THIRD occurrence (defense May 19, range Jul 30, BR Aug 3). (2) **DSL split REFUSED on all 9 combos** - the row universe is a Python `set`, which does NOT dedupe NaN (boxed `np.float64` nan vs the `np.nan` singleton; `nan != nan`, different hashes, so the set keeps both while pandas calls them one). Reproduced standalone: 3 set entries, 1 pandas duplicate. Same builder copy-pasted into catching + fielding, which have no guard and just rendered the phantom row. (3) **Org canon missing on the fact side** - verified NOT biting (`mlbam.teams` emits ATH for 2026, ATH is in the pin), so insurance not a recovered bug. (4) A one-liner PowerShell could not parse - scripted instead.

- **VERIFIED WITH REAL NUMBERS, not inferred:** clean run, fact pin `20260804T030312Z-3283b`, **no `pin write failed`**, facts at 03:03Z before tracker at 04:07Z, exit 0 in 3889.6s. DSL split now `+18` on all 9 combos and `orgs_dsl_split` **233 -> 232 rows** (exactly the one phantom). MLB restores **+11 not +14**, so sched_type scoping held. pd-goals diff: **29 of 30 orgs moved**, MIA absent. **HOU 213/370 -> 217/372** - and the accounting proves itself: +4 successes, +2 opportunities, because exactly 2 of the 4 HOU washes were LF-fielded (Correa LF, Whitaker LF, Hernandez CF, Moss RF) and the rule is "success +1 always, opp +1 only for LF". All four match per-player on EOY P21 too. **The pin later read 105** - the 12h schedule fired on its own and picked up a new game's wash, which is the first evidence the rhythm is self-maintaining rather than merely configured.

- **Documented into EXISTING rules, no new files** (both classes already had a home, and one had actively WRONG guidance): `tracker-parquet-pins.md` 5.17 - deleted the false "tracker bundles don't include pyarrow" line, since the dependency is a property of the WRITE not the bundle - `merge-union-not-primary.md` - new section on a key member that can legitimately be NaN - `br-advance-3rd-out-wash.md` - bug history + corrected its rollout table, which claimed the DSL split was LIVE. Synced byte-identical to all 4 worktrees, verified with `diff`.
- **Audit closed:** 11 set-union sites across the 3 trackers - 8 `dropna` both keys (safe), 3 were NaN-exposed (fixed), 1 more found in the sweep. **Unguarded sites remaining: 0.**

- **EXACT next step:** **Nothing on baserunning - 1-3 is done.** The only work left is COSMETIC and unrelated (the phantom DSL row). Two deploys, each its own command. First: `cd C:/Users/zbridger/bsb-wt-intangibles ; git pull` (**pull is mandatory - `312c89af` landed after Zac's last pull**), then `cd intangibles`, set `$env:CONNECT_API_KEY`, then `.\connect_pins_catcher\deploy.ps1` (short). Second: `cd C:/Users/zbridger/bsb-wt-intangibles/intangibles` then `.\connect_pins_fielding\deploy.ps1` (~2 hrs, combo precompute). **GOTCHA:** `deploy.ps1` does `Set-Location $here` and never restores it, so `cd` back explicitly between them. Expect `orgs_dsl_split` to drop one row in each.
- **Blockers / waiting on:** none. Schedule on `intangibles-pin-tracker-2026-br` confirmed set and unchanged by Zac.
- **Uncommitted work:** clean in the intangibles worktree apart from pre-existing untracked clutter.
- **Not observed this session** (wired, same pin, same helper, low risk): BR season percentile pools, KPI weekly table + chart line, snapshot. The KPI ones surface on the next Monday cascade. Postgame is the best-tested (live narrative detection, video-verified July).
- **SECURITY, raised once, not actioned:** Zac pasted the Connect API key in plaintext, and `docs/ARCHIVED_REFERENCES.md:354` already carries it committed to git. Worth rotating.

---

## ALSO OPEN - 2026-08-05 14:48 (Swing shape: coachability answered)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint:** session `110b`, domain `bsb-resources/feature/pd-goals`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Zac ran `--shift` (the loft-coachability test) and asked what it means plus "the dirty stuff". Interpreted it, fixed the 3 known dirty spots, then ran a 47-agent code review and fixed 9 of its 10 confirmed findings.

- **Shipped (all pushed, unpushed=0):** `378ca725` retire the window metric + land --shift - `0ce8e8ee` shift-estimator honesty - `74500206` UNTAPPED + chase through BH - plus a `LINEAGE.md` entry.

- **THE ANSWER:** within-hitter loft lever = **+1.00 pts top-zone whiff per +1 deg** (SE 0.29, CI +0.43 to +1.58, n=373), **+0.97** on the 325 who never changed level. Cross-hitter tiers recomputed from the frame: **MLB/AAA +1.35, AA/A+/A +1.19, FCL/DSL +1.00** - monotone selection gradient, and the within-hitter number lands on the least-selected tier. Hitters move ~1.4 deg a season, so the ceiling on a loft cue is ~1.4 pts of whiff and it costs hard contact. **Verdict: still no degree targets, ships as a screen.**
- **I shipped a wrong number and caught it:** said "HALF the 2.0 cross-hitter curve". That `+2.0` was a hardcoded literal orphaned when the survivorship pass was deleted in `8fba831d`. Real inflation is **35%**. Fixed in all four places.
- **Two metrics retired/rebuilt by MEASURING RELIABILITY first:** contact-depth **window width** split-half **-0.08** (vs +0.99 loft / +0.98 tilt in the same test) because a 5-pt threshold sits at 0.4 of a bin's 12.6-pt SE - **deleted**, replaced by peak contact depth (SB +0.61). **UNTAPPED** was firing by construction; now in-zone + 25 BIP + exact binomial vs his other bands + BH -> **3 of 145 survive** (Pena deck p10, Ferreras p28, Huezo p55).
- **Four hardcoded copies became one computation:** `shift_analysis` gained `quiet=True` and stashes results on `r.attrs`; the deck formats page-1 findings 4+5 from it.

- **EXACT next step:** Ask Zac his verdict on **page 1 and page 10 (Jeremy Pena)** of the deck he just opened - he wrapped without saying. If he says go, **build the shift page** (~1h; numbers already on `shift_analysis(...).attrs`, exposed in `build_deck` as `_SH`/`_cross`). Rebuild locally, NO DB: `cd pd-goals` then `python scripts/swing_shape_lab.py --parquet "C:/Users/Owner/Downloads/swings_2026 (1).parquet" --deck`
- **Blockers / waiting on:** Zac's verdict on the deck; his call on whether the shift page goes in before Gavin sees it.
- **Uncommitted work:** 86 files in bsb-resources, all **pre-existing untracked dirs**, none mine.
- **Process note:** `--extract` needs the work laptop (DB). Everything downstream runs **locally** off the parquet in Downloads - I wrongly sent Zac to the work laptop and he called it out.

---

## ALSO OPEN - 2026-08-05 14:05 (Postgame V2: spec + card prototype)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen` - branch `feature/bullpen-reports`
- **Recall checkpoint:** session `4089`, domain `bsb-wt-bullpen/feature/bullpen-reports`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Zac sent a Pitch Profiler card screenshot and asked to shift the Arm Farm postgame pitcher report to that shape for 2027 and expand past it. Spec'd it, built the layout prototype, rendered it, and closed every open decision.

- **Shipped (all pushed, all 4 worktrees `unpushed=0`):**
  - `61a47420` **spec** - `bullpen-report/docs/plans/2026-08-05-postgame-v2-pitcher-card-spec.md`. PDF only in v1 (Zac: *"the sole focus is on the PDF report at the moment - as a postgamev2 concept"*); Streamlit page is a phased follow-up with a deliberate app-report parity gap recorded.
  - `8c4b48f3` **layout prototype** - `src/postgame_v2_layout.py` + `scripts/render_postgame_v2_mock.py`. SYNTHETIC ONLY, DB-free, **not in manifest, nothing deploys.** 3 renders + 3-page PDF committed at `docs/plans/mocks/postgame-v2/`.
  - `0fc1c1f3` RV finding + PDF output · `350dde73` gcPerf + 300 gate + LK_Schedule_Types · `563cc273` spec close-out.
  - Rules: `c8f193a0`/`6496d002` **sched-types.md**, `3676e078`/`3bda605d` **percentile-golden-gates.md** - both synced md5-identical to all 4 worktrees.
  - `eaa9f7e0` captured GC2 tooltip SQL -> `bsb-resources/sql-queries/gc2-pitch-grades-tooltip-reference.sql`.
  - Phone-viewable review artifact: https://claude.ai/code/artifact/d48d79a8-6f82-4a37-83af-b889ae150525

- **THE HEADLINE: RV and gcPerf are the same number.** `gcPerf = 50 - 1500*AVG(rv)`, so `RV/100 = (50-gcPerf)/15`. The card was going to ship both as if they were independent evidence. Zac: *"use gcperf in the RV case!!"* - gcPerf everywhere, RV/100 nowhere.
- **Rendering the prototype earned its keep immediately** - 4 defects `py_compile` is blind to: percentile colors **inverted** (gcERA at the 97th and xwOBA .198 at the 91st both painted RED - the data layer orients low-is-better to goodness and the renderer inverted it *again*); `Overall` printed `10.0` not `100.0` (stripping the leading zero with `.replace("0.",".")` eats the zero *inside* 100.0); label/value collisions; legend over its own title.
- **Two questions I should NEVER have asked Zac** (he pushed back, correctly): **weight** is `MLBAM.Players.weight` ord 20, two rows below the height columns we already join - it was in a **committed schema snapshot the whole time**. And **Loc was never ambiguous** - the card uses our shipped `loc_grade`; the tooltip's `ProjLoc` is Proj-minus-Stuff, a different quantity that merely has "Loc" in the name.
- **`sched-types.md` had TWO WRONG entries for months.** `V` is **Live BP** (not "Veloz/bullpen sessions" - `B` is the bullpen type); `I` is **Intersquad** (not "Instrumented"). **15 types exist; the rule listed 5.** That file auto-loads on every `.py`/`.sql` edit. The correct table was committed in the repo the whole time. So the "LiveBP" domain Zac asked about = `sched_type 'V'`, and `_report_title` already handles it - nothing to build.
- **NEW durable pointer:** memory `gc2-schema-snapshot-location` - full GC2 `columns.csv` + LK lookups are committed at `sql-queries/schema/GroundControl2/` **on branch `cq/pd-goals`** (`467af12e`), NOT on `feature/pd-goals`, so invisible to `find`/`ls`. `git show` it **before** asking for an INFORMATION_SCHEMA run.

- **DECISIONS - all made, nothing blocks the build:** percentiles always full-season + always regular season (a single game can never produce one) · sched_type domain picks the GAMES never the pool · game value left / season bar + percentile circle right · **pitcher percentile gate = 300 IN THE FOCUS** (pitch type, group, hand, count, TTO) · palette stays HOUSE red-bad/green-good, not the mock's Savant red-is-good · renderer never inverts a percentile · **delivery + audience/voice DEFERRED** (Zac: *"delivery is the last of our worries ... we are just focused on report creation"*).

- **EXACT next step:** Zac will `/clear` then `/recall` and asks **which approach one-shots the build**. Answer is in the recall checkpoint's `open_questions` - short version: **do NOT orchestrate the implementation** (all 17 metrics land in ONE new `src/postgame_v2_data.py` and share the same canonical references - parallel writers collide and duplicate reading); a Workflow is only worth it as a **research fan-out** (one agent per canonical reference returning formula + `file:line`). `/goal` fits **Phase 1 only** and MUST end at "code + tests + pushed + runbook", never "verified vs GC2" (work-laptop -> `goal-hook-hygiene.md` Stop-hook loop). Plainest good answer: **`/plan` the metric layer, then execute Phase 1 in one pass.** **Before writing anything, ask Zac about the two-column game-vs-season treatment** - the only part I designed rather than derived, cheap to change now.
- **Blockers / open:**
  - **Flip `postgame_percentiles.py:219` `_PITCH_TYPE_QUERY HAVING 30 -> 300`.** Pools WILL shrink; a 4th pitch type at DSL/FCL may drop under the 5-member floor and go uncolored - that is **correct** (honest blank beats a percentile off 4 players). Count them; do not soften the gate.
  - `_compute_rv` (`postgame_percentiles.py:456`) must be **diffed** against the tooltip's `rv_case` before reuse - written independently, may not match.
  - **13 players have NO `channel_id` at all** (delivery goes nowhere): Aparicio, Walter, Boettcher, Vogel, J.Jimenez, Geraldo, Pratt, K.Herrera, R.Hernandez, R.Smith, Dagnino, plus **Gantes 247291 / Rivero 282250 who have no channel NAME either**. Separate from the 78 missing `z_channel_id`. Slack-admin, not code.
  - No DB on the personal laptop - every metric verification is work-laptop work.
- **Camden:** nothing outstanding; Zac had already pushed the `hq` ones. PR #19 (ToolBox) merged into `feature/bullpen-reports` mid-session and was rebased onto.
- **Uncommitted work:** `bsb-wt-bullpen` carries a **pre-existing** rules-sync WIP from an earlier session (7 modified `.claude/rules` + untracked skills). **Not mine** - deliberately left alone, stashed/restored around the rebase.

---

## ALSO OPEN - 2026-08-05 11:35 (Decision Outcomes: the dead-comparison sweep)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-modeling` - branch `feature/promotion-models`
- **Recall checkpoint:** session `97a3`, domain `bsb-wt-modeling/feature/promotion-models`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Zac asked why Lucas Spence's journey strip showed a phantom "AA" between AAA and MLB. One question turned into four instances of the same structurally-dead comparison, plus an anchor replacement, a repair path, two pin guards, and a dry run that was writing.

- **THE HEADLINE:** `next_level >= level_to` **could never come out False**, in FOUR places. `decision_outcomes_resolve` filters promote candidates to `level_to` FIRST (`at_to = mine[mine["level_code"] == to_level]`) then sets `next_level = judged level`, so it compared a value against itself. `next_level` does NOT mean "where he is now" - it means "the stop we JUDGED".
- **The worst instance was NOT the visible one.** `_promote_bucket` fed the *Sent back down* tile and was DOUBLY dead, so that tile was driven only by an explicitly detected demote - which needs >=10 PA/BF at the lower level. **A player optioned down who then got hurt or took 6 PA was counted as having HELD his promotion.** Tile went 7 -> 8 live after the fix.

- **Shipped (12 commits, all pushed):** `073e3ab7` level_from = previous STINT not trailing-90d modal (+ `repair_decisions`, because `decision_id` does NOT contain `level_from` so a re-run could never reach frozen rows) - `0790a400` `_pin_exists` reads `fs.info`'s exception class, never `board.pin_exists` (fsspec's bare `except: return False` turned a timeout into "definitively absent" and reopened the bootstrap-over-live-data path) - `c1e0afa8` every scatter dot names WHICH move it is - `d93e0c68` + `756df0b9` the four dead comparisons, `_held_level`/`_level_known` DELETED - `7d6c1919` **my bug: `--dry-run --repair` was APPENDING FOR REAL** - `03d31039` a send-down is a red CHIP either way (`DOWN 7/17/26` detected vs `DOWN to AAA` board-only) - `5c70dd27`/`2076811a`/`3aed7e8a`/`ae23d29b`/`b397200f` the diag + `--audit-anchor` - `f8ee2f06` LINEAGE.
- **Documented:** blocking rule **#19** + new `.claude/rules/tautological-display.md`, and `prp-pin-wipe-recovery.md` **§4b** (4 pin guards). Both byte-identical in **all 5 worktrees** incl. `bsb-wt-modeling`, which the document-pattern skill's list predates.
- **VERIFIED LIVE by Zac:** app deployed, Connect **Min processes 0 -> 1** (that was the intermittent "could not reach Connect"). `--audit-anchor`: **108 of 109** promote/demote rows carry `prev_stint`. MLB is not in `LV_ALL` so an MLB player **cannot** have a promote grade - Spence's 5 is his real AAA grade; he had been **optioned back**, and the board was the only current thing on the page.

- **EXACT next step:** nothing queued - Zac: *"this has hogged a bunch of time we should be using elsewhere."* When he returns for research, the one item needing HIS decision is **chart-per-decision vs table-per-player** (a two-move player is two dots and one row, which is what cost an hour of "why do the percentiles disagree"). Options: table goes per-decision, expandable row for multi-move players, or leave it and rely on the dot labels shipped this session. **No default - do not pick one for him.** Full ordered backlog is in `pd-goals/modeling/LINEAGE.md` under "Next".
- **Blockers / open:**
  - **`--repair` HAS NOT BEEN RUN and may not need to be** - 108/109 already carry `prev_stint`. The 1 holdout is **Reylin Perez 176305, 2026-07-09 demote afa->afx, UNGRADED** (demote detection shipped a day before the stamp existed). No grade, percentile, verdict or rate depends on it.
  - **DO NOT "fix" `decision_outcomes_page.py:1213`.** `_reached_higher` compares `next_level` on a RELEASE, where the resolver's `at_to` forcing does not apply, so it is a genuine free variable. A blind grep for `next_level` WILL flag it. Recorded in LINEAGE as STILL-WIRED-but-not-dead.
  - Two-level jumps plot a ONE-level probability against a two-level outcome. Zac reviewed and **ACCEPTED** this 2026-08-05; do not re-open unprompted.
- **Tests:** 5 new DB-free files (12 + 15 + 36 + 47 + 24 checks). All 10 files in `modeling/tests` green.
- **Uncommitted work:** 16 tracked + 58 untracked, ALL pre-existing clutter. **None of this session's** - verified by grep against my own filenames.
- **Honest note:** I was wrong twice this session and stated both confidently - "the board has not caught up with the callup" (he had been optioned DOWN) and "the stale row is probably a phantom promotion" (it is an ungraded demote). Both were the same mistake: explaining what numbers MEANT before checking which ROWS they came from. That is now blocking rule #19's corollary. Zac caught that `diag_current_grade.py` still shipped both disproved theories; fixed in `b397200f`.

---

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **What we were doing:** Short session. Added athlete (`z_`) channels for 5 players, then fixed the `slack-channels-csv` skill which still claimed 5 CSV copies after the 5th was deleted Aug 3. Zac: *"ok good to /wrap here."*
- **Shipped (all pushed, all 4 worktrees current with origin):**
  - **5 athlete channels**, set on each player's **existing `zzz_` row** (7th column) - never a standalone `z_` row: 106480 Loperfido `C028Q57E0TF` · 264917 Mendez `C0A9SADTMSR` · 1299133 Rivas `C09L39EJFS5` · 1299134 Colina `C09KNDNFQ9F` · 1329926 Arias `C0A9ZB47GMS`. All five already had a `zzz_` row with an empty `z_channel_id`, so coach routing untouched; 360 lines before and after. **Since Aug 3 the weekly fielding+hitting reports are athlete-only, so these 5 had been landing in coach channels every Monday.** No-athlete-channel count **80 -> 75**.
  - `610b19b1` **skill corrected 5 -> 4 copies.** It pointed at a file deleted Aug 3 (`2eaaa183`) and demanded a 5-way md5 that could never pass. Kept a historical note on WHY it was deleted so nobody re-creates it "as a fallback." Skill exists **only in bsb-resources** - no sibling copies - and `.claude/skills/` is **not** in `sync-rules.sh`'s copy set (`rules/` + `scripts/` only).
  - New `windows-toolchain.md` entry, synced md5-identical to all 4 worktrees.
- **TWO PROCESS LESSONS, both now written down:**
  - **`grep -c $'\r'` does NOT detect CRLF in Git Bash.** It reported CRLF for all 4 CSV copies while `xxd` showed plain LF. That sent two string-replace passes matching the wrong line ending, each silently finding **zero** matches. Check bytes: `python -c "b=open(f,'rb').read(); print(b.count(b'\r\n'))"`.
  - **The 4 copies are NOT uniform** - `bsb-wt-bullpen` is CRLF, the other three LF (that clone's autocrlf). Raw `md5sum` legitimately differs while content is identical (`tr -d '\r' | md5sum` = `947a7cf00010` everywhere). The skill's old "md5sum all 5 -> must match" step could never have passed and would have read as real drift. Robust pattern: `splitlines(keepends=True)`, re-attach each line's OWN eol, idempotent (re-run reported `already=5` on the already-edited copy).
- **Also:** `bsb-wt-bullpen` was **33 commits behind** (someone pushed a whole `toolbox/` module) - pulled + pushed. That round also cleared the barrelsville commit stranded by the Aug 3 SSH aborts. **All four worktrees are now current.**
- **EXACT next step:** nothing queued. The live item is **next Monday's goals log** - look for `Collapsed N phase row(s) -> M player(s)`; **N-M is exactly how many duplicate posts went out the prior Monday.** If that line is absent, every player is single-phase (also fine) - then check Alvarez 213722's post count directly.
- **Blockers / open:**
  - **75 players still have NO z_ athlete channel** (was 80). Their weekly fielding/hitting reports fall back to the COACH channel every Monday and the player never sees them. **Slack-admin task, not code:** create the channel, then set its id in the `z_channel_id` **column** of that player's existing `zzz_` row - never a standalone row - then sync 4 copies. Offered the list twice; Zac has not taken it up.
  - Dunford 198153 + Diaz 67182 are standalone `z_` rows with **no `zzz_` row at all**, so coach-targeted sends for them land in their athlete channel. Harmless under athlete-only weekly routing, mildly wrong for the goals coach pass. Not raised with Zac.
  - **DEFERRED by Zac, do not start unasked:** hitter BB% missing its percentile.
- **Nothing today touched a DB or the live pin** - CSV edits + a doc fix, all verified locally. No work-laptop step pending from this session.
- **Uncommitted work:** pre-existing clutter only, none of this session's.

---

## ALSO OPEN - EOY position report (bsb-resources / feature/pd-goals, session `90dd`)

### (previous wrap) 2026-08-04 15:03 (EOY report: inline render + payload pin measured)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint:** session `90dd`, domain `bsb-resources/feature/pd-goals`. **That is the source of truth**; this file is a rendering of the newest wrap only.
- **What we were doing:** Made the EOY position report actually visible in the app (it was a build-a-PDF button + download link, so you could not see the deck without leaving), then tried to make it fast by pinning the season data. The pinning attempt is what produced the real finding.
- **Shipped (all pushed):** `c0aff2a0` inline PDF viewer (pymupdf -> `st.image`) - `49cfc0af` auto-render on player select, preview button deleted, build split at the notes seam - `522c414f` affiliate logos into `manifest.json` + Send above the deck - `5508911d` DSL uses the Astros star like FCL - `89776d56` reverted by `d572a0ac` at Zac's request - `a78cfbdb` the payload pin (`src/eoy_payload_pin.py`, `scripts/pin_eoy_position.py`) + `pins_config` `allow_pickle_read` fix - `d7c31754` first-run message - lineage entry.
- **The seam worth remembering:** ONLY page 1 reads the coordinator notes, so the ~43 season queries cache on the PLAYER alone. Typing notes never re-queries; layout changes never invalidate; only adding/removing a page does.
- **MEASURED (Zac ran it, killed at 10/135):** **152s per player, 5.7 HOURS for 135, ~45 MB, ~5,800 queries.** Size is fine. Runtime is the problem.
- **Root cause:** `eoy_fielding_data.py` 20 `run_query` / ZERO caching, `eoy_catching_data.py` 9/zero, `eoy_br_data.py` 2/zero. Those are league-wide POOL queries and several are hardcoded `_level_filter_sql("mlb")` - ONE pool re-executed 135 times. ~31 league scans per player that should run once.
- **THE FINDING (verified):** the intangibles fielding tracker pin already holds `raw_tdm` = **one row per TDM event**, Tier-1 gated, with every tracking metric + `pos_id/org/level/season/ha_split`. It has NO direction (`direction` appears ONCE in that module). Adding it is **one join to `Astros.Fielder_Direction` via `cur_event_id` and one column** - it does NOT multiply rows. That makes directional+positional metrics a Python groupby over a pinned frame everywhere, and retires EOY's directional scans.
- **EXACT next step:** Zac's words - *"we will have to /spec and plan this and then /wrap but i want to /discuss this as well when the context given is more optimal"*. So **next session = `/discuss` then `/spec` the directional architecture with fresh context**, decision being **one column on `raw_tdm` vs a separate directional pin**. Orthogonal quick win still UNDONE first: add `@lru_cache(maxsize=64) def _cached_pool(sql: str)` keyed on the fully-formatted SQL string (every site uses `.format()`, so params are baked in; return `.copy()`) to those three modules, then re-run `python scripts\pin_eoy_position.py --season 2026` **from the `pd-goals` dir** and re-measure the 152s.
- **Blockers / waiting on:** nothing about the pin has touched Connect - the run was killed at 10/135, so **the pin has NEVER been written**. The joblib write, the read round-trip, and whether the payload is even picklable are all unproven. Nothing is deployed either: `requirements.txt` changed (pymupdf + streamlit floor 1.37) so Connect MUST rebuild the env, and `manifest.json` changed so the affiliate logos only appear after the deploy runs.
- **Open, unanswered:** pin now vs after the EOY page set is frozen (he is still building pages - new pitch-type page, P2 sparkline - and adding a page invalidates the payload pin) - ~180 pitchers still stubbed, this pin is position-only (135) - college/BBC pools need their own pin, reusable by other projects.
- **Uncommitted work:** 86 paths, all pre-existing untracked clutter from earlier sessions. Nothing of this session's.
- **NOT MINE, same branch:** `74500206` `0ce8e8ee` `378ca725` (research estimator), `4d5760fe` `4c923522` `eeed253a` (rules syncs), `4e130235` `472c3875` `e70adea7` `095b6c3d` `9a747b96` `5222c615` (Monday cascade + goals delivery), and the Janek/catcher/org-SB SQL commits.

---

## ALSO OPEN - Decision Outcomes dashboard (`bsb-wt-modeling` / `feature/promotion-models`, preserved)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-modeling` - branch `feature/promotion-models`
- **Recall checkpoint:** session `183f`, domain `bsb-wt-modeling/feature/promotion-models`. **That is the source of truth**; this file is a rendering of the newest wrap only.
- **What we were doing:** Took the Decision Outcomes dashboard (promo-engine page 2) from "ledger pin has never been written" to live and correct. Every fix below came from Zac reading a real number on the deployed page and asking why it said that.

**Shipped (`90467ec0` -> `b75b8a8d`, all pushed):**

- **Promote verdict is now FOUR cells**, split on `grade_pctile` at `PROMOTE_READY=50`. New words `GRADED LOW` + `LOW SAMPLE`; `TOO EARLY` now means only "a release too recent for the silence to mean anything". A player graded BELOW the ready line who did not hold is no longer a MISS - the model called it.
- **`grade_pctile` was ranked against the wrong pool - my bug, same session.** The first version read the rank off the SCOPED as-of board, which scores ONLY the decided players, so it ranked them against each other (Marrero 27/rok and Saunier 34/afx both landed on exactly 50). Fixed with a separate UNSCOPED pool pass per (kind, season) + `_pctile_in`. **Caught by Zac asking "aren't these grades lower the higher the level tho?"**
- **Demote detection built.** `get_promotions` is now a wrapper on `_level_transitions(season, direction)`; `get_demotions` flips the rank test. 44 found in 2026, they ride in ungraded and never enter a rate. The page's `Sent back down` tile / `down` bucket / DOWN chip had sat unreachable since day one.
- **AUC tile DELETED** (it read 1.00 on 14 rows with one miss) and **"Advanced and held" replaced** by "Producing at the new level" 7 of 26 - it read 100% next to 14 MISSes because failing it required a demotion we did not detect.
- Same-day landing game no longer dropped (`<` promote, `<=` release) - indy name join hardened (the `b collins` Bryce/Brendan collision) - released scatter is two y-bands not four quadrants - scatter plots resolved rows only - `src/database.py` finally got the TCP retry this worktree never had - page error state split into transient / missing / config.

**LIVE STATE:** ledger 159 decisions (61 promote / 54 release / 44 demote), outcomes rebuilt, coverage 89% promote / 76% release. 12h schedule (`promo-models-decision-ledger`) carries it from here. `f7ed5571` + `b75b8a8d` are pushed but NOT yet deployed to the app - pick up on the next deploy, no rush.

- **EXACT next step:** **Wait for Zac** - he is reviewing the live dashboard and coming back with recommendations. Do nothing until he does. When he returns, check the two already-flagged items: (1) `GRADED LOW` came out **0** on the final run after the repair, where a handful was expected, so eyeball the `%Lvl` spread on the promote ledger; (2) release coverage is 76% (13 of 54 cuts ungraded in either season), so release rates run on a subset. Also verify Reylin Perez now shows a DOWN chip and reads FCL rather than A+.
- **Blockers / waiting on:** Zac's review. Nothing technical is blocked.
- **Uncommitted work:** 68 paths in `bsb-wt-modeling`, all pre-existing untracked artifacts (`modeling/output/`, research scripts). Nothing of this session's.
- **DO NOT re-run:** `backfill_grade_pctile.py --repair` is one-time and already done for 2026 (33 values corrected).
- **Carry forward:** `GRADE_ABS` / `RISK_ABS` are calibrated PROBABILITIES that fall with level (advance-and-hold base rates A .29 / A+ .28 / AA .21 / AAA .10), so **any fixed threshold on them is a threshold on LEVEL**. Memory file `grade-abs-is-a-probability-not-a-rank.md`.

---

## ALSO OPEN - PD Goals double-send fix (`bsb-resources` / `feature/pd-goals`)

From 2026-08-03, still live. Kevin Alvarez got the same PD Goals PDF twice from
one Monday run. Fixed with a `--played-within N` (default 7) **delivery** gate
anchored on `--end` (so re-running an old Monday reproduces it), plus a Monday
per-player routing split and deletion of the 5th `slack_channels.csv`. 6 commits
on `feature/pd-goals`, all pushed, head `095b6c3d`. **Waiting on next Monday's
cascade to confirm** - Zac: *"sounds great hoping this works next week - ill let
you know if any issues arise."* Detail in that branch's `git log`.

## ALSO OPEN - OF/IF Directional Progression (`bsb-wt-intangibles/astros-intangibles`)

From 2026-08-02, shipped but with one gate still open.

- **EXACT next step:** the **EOY P13 rose parity check** - take one player and
  compare his PAA/EO rose percentile on the directional report against his EOY
  P13 rose (same engine underneath, so they must agree). The diff harness proved
  the rewrite did not CHANGE the numbers; it did not prove they were right to
  begin with. Do this **before** it reaches `org_pd_reports` on a Monday.
- **Then:** `python scripts\generate_directional_progression_batch.py --family OF IF --test`
  (never live first). Confirm **ONE** `[pool] building` line per `(kind, scope)`
  for the whole run - that is the memoisation, and it is what stops a full roster
  re-spilling tempdb. Then swap `--test` for `--deliver`.
- **The incident worth carrying forward:** a league-wide TDM pool
  (`SELECT DISTINCT` over seven `PERCENTILE_CONT` windows, rebuilt once per
  player) **exhausted GCSQL02 tempdb on its first ever live run**. The tell was
  **"it worked once, then never again"** - that shape means WE ate a shared
  resource, not that the server broke. Called it server-side for three
  round-trips and was wrong; Zac pushed back and was right. The first fix
  memoised (16 execs -> 5) and could not possibly help: the cost is
  **per-execution** and it died on #1. Real fix `073b715a` - raw rows (months
  **1..12**, not the Apr-Sep list, or March/October silently drop) + pandas
  percentiles, proven output-neutral on real data.
- **Flagged, never written:** a rule for that incident class. Zac has not said go.
