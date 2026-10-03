# Last session state - 2026-10-02 (Pitch Similarity comp-pool pin)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen` - branch `feature/bullpen-reports` (+ bsb-resources `feature/pd-goals` for the pin map)
- **What we were doing:** Making Arm Farm Pitch Similarity fast. Every search re-scanned Pitches_View 2018->now and every new pitch-type combo / filter was a fresh scan.
- **Shipped this session:** per-season comp-pool pin `zbridger/arm_farm_similarity_pool_{year}` + `zbridger/arm_farm_similarity_career_war`; page reads pin-first with live fallback; ranking vectorized (~28x); DSL no longer labelled FCL; season widgets follow the clock (`8f968417`, empty-new-season fix `24c729fb`, schedule text `4c0d9625`). DB parity VERIFIED (6 combos, live 4-101s vs pin 0.02s). History 2018-2026 pinned 10/10 (1,164s). New Connect job `arm-farm-similarity-pool-pin` (GUID d9d2884a-1c9f-450b-953f-9135226c9273), daily 8:30 AM Central, Vars set. App redeployed; Camden confirmed it is fast. Pin map + rollover plan updated (`0b34f033`, `0e6c2613`).
- **EXACT next step:** CHECK the first scheduled 8:30 AM run of `arm-farm-similarity-pool-pin` in Connect Logs: `DB creds set = True`, `pinned : 2/2`, `Exit code: 0`. Put the server run time into `docs/pin-system-map-observed.md` (Run size row). Then smoke Pitch Similarity once more. Verification backlog row #25.
- **Blockers / waiting on:** the first scheduled run (deploy-time render skipped because Vars were not set yet, so no server run has been seen). Zac moving to a new computer.
- **Uncommitted work:** none of this session's (bsb-wt-bullpen rules edits belong to another session).

---

## ALSO OPEN - 2026-10-02 08:42 (AFL advance report - Scorpions)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` - branch `feature/barrelsville` (+ bsb-resources `feature/pd-goals` for the Monday cascade)
- **What we were doing:** Building the AFL (Arizona Fall League - never "AZFL") condensed advance report for Kyle Brennan / the Scottsdale Scorpions: Advance tab + weekly Slack send, AA-pool colouring, then moving advance pitcher pools onto the existing pool pin.
- **Shipped this session:** AFL tab + `src/afl_report.py` + `src/afl_data.py` + `scripts/generate_afl_weekly.py` (--team, --deliver -> C0C5V1S3DS4). Colouring = ML advance report vs 2026 AA; VAA/HAA plain. Advance pools pinned as `advpit_*` in `barrelsville_postgame_pools_2026` (`6965db72`, seeded + --check ok). Deploy from `f399055a` (parent `4fa4ffe1` is a broken half-commit). Cascade step `advance-afl` (`6133f843`). Rule pin-deploy-runbook: a bundle deploy RUNS the job (`30300865`, all 4 worktrees). LINEAGE `9db08c55`. Recall checkpoint `0538cab70967b593`, session `eadb`.
- **EXACT next step:** Wait for Kyle Brennan's next AFL feedback. If not done yet on the work laptop: `cd C:/Users/zbridger/bsb-wt-hitting/barrelsville; git pull; rsconnect deploy manifest . --app-id bbb53548-a7c5-4a03-9146-44647e7c88c0`, then `cd C:/Users/zbridger/bsb-resources; git pull`.
- **Blockers / waiting on:** Kyle feedback. Unverified: AFL tab caption "Colours vs 2026 AA pitchers (N pools)" on Connect after redeploy; whether the barrelsville-pin-tracker-2026 bundle deploy finished (Zac's pasted log was the Defense Matrix job).
- **Uncommitted work:** bsb-wt-hitting / bsb-resources: only pre-existing untracked scratch; nothing of this session's. bsb-brain vault is MID-REBASE (pre-existing) - last-state not committed.

---

## ALSO OPEN - 2026-10-02 08:05 (Astro World: offboarding + A-Z)
- **Project / cwd:** `C:/Users/Owner/astroworld` - branch `main` (remote `prod` = Baseball-Operations/astroworld-dev; bare `git push`)
- **What we were doing:** Making "I removed them in Azure" actually remove somebody from Astro World - account, card assignments, watches and labels - then fixing a new card not filing itself alphabetically.
- **Shipped this session:** SEVEN PRs merged and deployed: #82 (deactivating clears AeroCardMember + AeroWatch), #83 (`src/lib/mail/` transport seam, inert), #85 (`AeroLabel.email` migration, RUN in prod by Zac), #86 (label<->person UI + offboard deletes linked labels), #88 (roster sync from the Entra group export), #89 (Access button affordance + "USER ASSIGNMENT"/"NA"), #90 (A-Z always on + `planBoardHeal`). LINEAGE entry written (file is gitignored in that repo, on disk only). Recall checkpoint `c277eacd254a2e28`, session `86e1`, domain `astroworld/main`.
- **THE FINDING:** Astro World has NO Graph integration at all. It learns a person exists only from the headers Azure injects AT SIGN-IN. Access is granted by the Entra group `sec_app_astroworld` (43 members; Zac is an OWNER, Peter Yee the other), so removing somebody there blocks their login and the app never finds out. Westlake was gone for weeks and still in every picker.
- **EXACT next step:** Waiting on Peter Yee for admin consent on Microsoft Graph `GroupMember.Read.All` for the `astroworld` app registration (client `9ff2dd7d-a0fa-4235-bea1-c0cf484bf0d8`, tenant `6bf5ba6c-1223-46fb-873b-9ab55c00bd24`). When it lands, build the Graph reconcile: the decision logic is already pure in `src/lib/roster-sync.ts` and cannot see its source, so it is swapping the file upload for a Graph call, about an hour. Ask Zac first whether he added `Mail.Send` to that same request - it is already requested and un-consented on the SAME registration, so one click unlocks mail too and may make Matt Mistric's SMTP work unnecessary.
- **Blockers / waiting on:** Peter Yee (one consent click gates everything automatic). Zac to confirm by eye that #90 re-ordered Fayetteville on load - if "Diaz, Camilo" is still at the bottom the heal is not firing. Zac to decide which events send mail (my recommendation: mentions yes, bell yes, reactions no) - nothing is wired to a call site until he says. Zac to link the labels that are people, leaving rehab/programmes on NA.
- **Uncommitted work:** astroworld 1 untracked (`migrations/content-export-2026-07-15.json`, pre-existing). bsb-resources NOT touched this session (81 pre-existing paths, none mine).

---

## ALSO OPEN - 2026-10-01 16:40 (Hiring app: assessment + rankings)
- **Project / cwd:** `C:/Users/Owner/hiring` (cage-sandbox) - branch `main` (Railway deploys main)
- **What we were doing:** Fixing what Zac found testing the hiring app live: the 3-prompt candidate assessment, the Sandbox practice runs for owners/Lim, a Lim sign-in bug, and the Post Panel Rankings.
- **Shipped this session:** b3a86ec, 670f6a9, 812372c, 263fbb9, 54a1d7e (assessment: 24h to open, clock at sign-in, lost-answer fix, loading screen, auto-close, cage picker), 6e1b118 (Sandbox practice runs), d2eec82 (emailed code lands on /dashboard; lockout message + reset clears it), 847e243 / 0557f1a / a2f2ef6 (rankings: owner preview, everyone in the process live, explicit "which rankings" picker), faea312 (panel members see the questionnaire; Lim once per candidate). LINEAGE (r) d441490, (s) bd01dd9. STATUS.md 7a61d0e.
- **EXACT next step:** Get Zac's answer: should Lim users be limited to ONE ranking? If yes, edit `cage-sandbox/app/panel_api.py` rankings_submit to 409 a second Lim submission and drop removed people from a locked ranking instead of asking to re-rank.
- **Blockers / waiting on:** Zac testing live after Railway redeploys; Zac deletes his test questionnaire on Candidate Rubrics (no live DB from this laptop).
- **Uncommitted work:** hiring 31 paths, pre-existing render PNGs/scratch (none from this session).

---

## ALSO OPEN - 2026-10-01 12:05 (Pin freshness + hung jobs)
- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals` (also committed to all 3 sibling branches)
- **What we were doing:** Started on making the daily cascade cheaper; it turned into pin health across all four apps. Found that ONE hung job was freezing the whole Connect scheduler.
- **Shipped this session:** BR percentile pool pin `930eaadb` (398.2s -> 3.6s, CONFIRMED `from PIN` in a cascade log). `diag_pin_schedule_audit.py` rebuilt into a job-health audit - OVERLAP/HUNG/FAILED/NO RUNS/ORPHANED, 24h SLA, copy-pasteable CANCEL per hung job (`26d982aff`, `6d9a7158c`, `2e6de73dc`, `382f0ce3b`) + guard `test_pin_audit.py` (21 checks, 5 injections red). Rule `.claude/rules/pin-freshness-and-hung-jobs.md`. `audit_app_manifest.py` on all 4 branches. `sync-rules.sh` now syncs `.claude/scripts/` too (`776e0b0a4`). manifest fix `48cf1e966` (Baserunning ImportError). LINEAGE `89708051a`. RETRACTED: BR per-game leads hoist `96c732585` -> reverted `c777dd772` (made MLB 10x slower; the parity harness caught it).
- **THE FINDING:** 50 of 66 in-scope 2026 pins were >24h stale. Cause was one job - `intangibles-pin-tracker-2026-fielding`, running 76h, previous completed run 76.6h against a 12h interval. It held scheduler slots so ~10 other jobs stopped firing on 09-28. Killed 09-30 12:59 -> backlog drained that evening, 20+ pins written 16:17-22:17. **Stale 50/66 -> 12/66 from one cancel.**
- **EXACT next step:** Zac feeds the latest `python pd-goals\scripts\diag_pin_schedule_audit.py` output back in, then attack the 4: (1) kill the 2 still-hung runs - barrelsville `$k='hz42dB7aXwK1I8Wj'` / catcher `$k='KpjQtPOkTf32W5Rh'`, re-run the audit first since keys rotate; (2) read the Connect log for `arm-farm-pin-tracker-2026` exit=1 on 09-30 12:59 (arm_farm_tracker 71h stale, a real failure not a hang); (3) grep the BR tracker job log for `[wash-facts]` - `intangibles_br_wash_facts_2026` is 168h stale despite exit 0, and PD-Goals EOY P21 + Org KPI read it with no detector of their own; (4) find why `mgr_card_pools` / `mgr_card_pin_preflight` (142h) have NO writer notebook in the content list.
- **Blockers / waiting on:** Zac to classify `decision_ledger` (129h, append-only, probably correct) and `indyball_winter_*` (535h, likely retired). THREE live CONNECT_API_KEYs pasted in plaintext this session - rotate. Offered-not-built: mutual-exclusion detection (fielding + fielding-combos both write the same pin and must never overlap).
- **Cross-session flag:** the other session plans to use the 09-28 of/if tracker pin as the fielding A/B "A" baseline. **Not valid** - written by the COMBOS job over base slices from a run spanning 09-22->09-27 while MLB was still playing. Parity needs a SQL run and a Python run back to back. Also recommended rebuild BEFORE rollover.
- **Uncommitted work:** bsb-resources 81 paths (pre-existing clutter + the other session's in-flight work); nothing of mine uncommitted.

---

## ALSO OPEN - 2026-10-01 11:34 (Fielding pin rebuild + pin year rollover)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-intangibles/astros-intangibles` · branch `feature/astros-intangibles` (rollover also touched bsb-resources/bullpen/barrelsville)
- **What we were doing:** Replacing the fielding nightly pin job (336 heavy SQL queries, DBA killed it 09-30) with one raw pull + Python, proven by A/B parity. Also made every pin job derive its season from the clock for Jan 1.
- **Shipped this session:** fielding_raw_rebuild.py + parity_fielding_raw_rebuild.py (978a32090..8d2ad260d); all 6 splits: tracking stats exact, positions only ties, PAA shift = calibration refit, old pin missing 3,170 MLB IF-away rows. Rollover: 5132bcc52, 74c0cfcc1, b9cf5756a, 79f19f4cc, 982d84ac0; runway in bsb-resources docs/plans/2026-09-30-pin-year-rollover.md. diag_pin_schedule_audit.py (5822f89b5+). Recall checkpoint baac.
- **EXACT next step:** Port the other 7 slices into `intangibles/src/fielding_raw_rebuild.py` (start with `fielders` season slice, then monthly - needs a month column added to `_RAW_*_QUERY`), extending `scripts/parity_fielding_raw_rebuild.py` per slice. Plan + step log: `intangibles/docs/plans/2026-09-30-fielding-pin-python-rebuild.md`.
- **Blockers / waiting on:** Zac: rollover deploy #1 (range plays) today; fielding schedule stays OFF; stuck Barrelsville/catcher runs owned by the other session.
- **Uncommitted work:** intangibles 6 modified (synced .claude/rules, not mine)

## ALSO OPEN - Hiring app
- **Project / cwd:** `C:/Users/Owner/hiring` (main, Railway hirehou.up.railway.app); session opened in bsb-resources (no edits there)
- **What we were doing:** Fixed the security findings Zac picked (calendar planted code, sign-in limits/lockout, sessions that don't end, browser headers, login timing), sped up Hiring Processes, then built the standard 3-prompt in-person assessment (hitting: Bat Speed, Swing Decisions, Blank; pitching: Velocity, Command, Throwing Program on a football field).
- **Shipped this session:** hiring 282c5b7, a47b875, 841d42e, c16a031, 97e5374, 5bf27c3, c441e55, 01beff8, 11bc4c7, lineage (p)(q) 22f9572. Migration 018 APPLIED by Zac. Recall checkpoint hiring/main.
- **EXACT next step:** Zac is testing live: send from https://hirehou.up.railway.app/admin/invites (or /admin/pitching/invites) with times 5/5/5 to a personal email, open in incognito, Start -> place -> I'm done, check Submissions (prompt lines, PDF, End current prompt). Fix whatever his screenshots show, then he runs Sam through it.
- **Blockers / waiting on:** Zac's live test feedback; confirm pitching brief goal wording; Railway region to US West (his setting).
- **Uncommitted work:** hiring clean apart from pre-existing render PNGs; all code pushed.

## ALSO OPEN - Command CV (2026-09-30 09:20, SHELVED for hardware)
- **Project / cwd:** `C:/Users/Owner/bsb-resources/command-cv` · branch `feature/pd-goals`
- **Shipped:** 11602a7d0, db3f5d877, 05404f392, 8b92df0e6, 2dae4cad3 + 3cd85f188, ced861212, lineage c5e8fe2ec. Vault: `projects/command-cv-hardware-research-2026-09-30.md`.
- **EXACT next step:** When the new machine arrives: ask DESKTOP vs LAPTOP, install NVIDIA driver + CUDA PyTorch, run `python -c "import torch;print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"`, copy command-cv/data over, then train on camera-projected labels (`scripts/project_labels.py`) at the solved parks.
- **Blockers:** new hardware (purchase this weekend; advised 32 GB+ RAM, 1 TB+ disk). track_px gate still Zac's call.

