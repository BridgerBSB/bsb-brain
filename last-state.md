# Last session state - 2026-10-01 12:05 (Pin freshness + hung jobs)
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

