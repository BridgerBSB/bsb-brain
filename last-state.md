# Last session state - 2026-10-01 11:34 (Fielding pin rebuild + pin year rollover)
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

