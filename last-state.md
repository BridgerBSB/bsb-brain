# Last session state - 2026-08-30 (swing angles)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-hitting` branch `feature/barrelsville` (rules + SQL in `bsb-resources` / `feature/pd-goals`)
- **What we were doing:** Making HBA legible, then VBA and AA, then measuring them on Christian Walker + Xavier Neyens, then speccing the org-wide "optimal angles on damaged contact" study.
- **Shipped this session:**
  - Three DB-free geometry explainers, each drawn in the plane its angle is measured in: `hba_explainer.py` (overhead), `vba_explainer.py` (catcher's view), `aa_explainer.py` (side view, ONE panel - AA has no bat_side term so a mirrored second panel could only repeat the first). PNGs in `barrelsville/docs/plans/mocks/hba/`.
  - `hba_distribution.py` - 4-row per-player viewer (all swings / contact / whiffs / hard-hit EV 95+), reads the CSV, no DB.
  - `sql-queries/hba-walker-neyens-per-swing-2026.sql` - Zac ran it, 1,561 rows.
  - `.claude/rules/swing-characteristics-canon.md` - all eight characteristics; synced to all 4 worktrees.
  - `barrelsville/docs/plans/2026-08-30-optimal-swing-angles-spec.md` - the study spec.
- **What the data settled:**
  - **Whiffs DO have SCV frames** - 486 rows vs 497 BIP. `db-columns.md` said they did not; corrected.
  - **So do TAKES** - 24 rows with `did_swing = 0`, HBA junk from -80 to +63. `e1x_con IS NOT NULL` is not a swing filter.
  - HBA: Walker +12.9 / +11.8 contact / +18.7 whiffs; Neyens +7.3 / +8.0 / +9.4. Both POSITIVE-centred. **Whiff IQR is 2.2x contact IQR for both hitters.** Hard-hit HBA is NOT tighter than contact - that hypothesis was measured and died.
  - VBA never goes positive in practice (max seen -2.3 across 1,537 swings). AA barely differs contact vs all swings, unlike HBA.
  - **Damage is per-batted-ball already** (`pd-goals/src/metrics.py::calculate_damage_vectorized`); Damage% is just its mean. But Walker's median ball scores 0.0010 - it behaves like a top-third detector.
- **EXACT next step:** Spec section 6 - **run the CHECK before building anything.** Pull FCL + A hitters' per-BIP EV/LA for 2026, score damage per ball, and see whether the distribution separates at all at those levels. If it is degenerate, damage is out there and LA+top50EV becomes the candidate. Cheap query: driven from `Pitches_View` on indexed `batter_id`, one season, order 20-40k rows, seconds.
- **Blockers / waiting on:**
  - Four decisions for Zac in spec section 7 (joint objective with contact rate? show unresolved players? switch hitters? keep wOBAcon?).
  - **NOT fixed, needs Zac's call:** `tracker_data.py`'s `_HBA_QUERY` / `_VBA_QUERY` / `_AACON_QUERY` / `_BATSPEED_QUERY` have zero `did_swing` references, so shipped HBACon/VBACon/AACon/BatSpdCon include takes (1.5% here, extreme values). Four metrics x three surfaces - needs `metric-audit`.
- **Rules drift found and fixed:** blocking rule **18b** + `query-cost-before-handoff.md` existed in `bsb-wt-bullpen` ONLY. `sync-rules.sh` would have deleted them. Recovered into canonical, synced; all 114 rule files byte-identical across 4 worktrees, `test_rule_routing.py` PASS.
- **Uncommitted work:** all session work committed and pushed on 4 branches. Pre-existing untracked: bsb-resources 77, bsb-wt-hitting 41, bullpen 11, intangibles 14 - none from this session.

---

## ALSO OPEN - EOY notes incident (separate thread, do not delete)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` branch `feature/pd-goals` (also `bsb-wt-bullpen` / `feature/bullpen-reports`)
- **What we were doing:** Day 2 of the EOY notes incident. Everything from day 1 is deployed. Today was proving nothing is still being deleted, and building the report Zac hands colleagues who ask.
- **Shipped this session:**
  - `6de05226` **`audit_eoy_notes.py`** - one page: current boxes by department and level, every EMPTIED box by name with its old text, and an explicit "WHAT THIS CANNOT TELL YOU".
  - `5484f71e` prints people AND report rows. 167 vs 184 is one dataset at two grains (17 players hold both a coordinator report and an off-season plan); side by side without the reason it reads as 17 players vanishing.
  - `5d7bb861` `--since` filters **Central**, not UTC (blocking #20). It had reported 161 creates for "today" that were the weight load at 8-9pm CT the night before.
  - `ce20eaa3` prints a 5-sentence Slack reply with the numbers, so the answer and its evidence come out together.
  - Yesterday's work, all live: `40c77bf1` merge fix, `0313f6fc` Arm Farm blank guard, `57f4192a` nightly payloads, `ce5fbefd` pyarrow, `677d81bc` LINEAGE.
- **State of the data:** **CLEARED 0** on four runs through the afternoon while boxes climbed 242 -> 250. Coordinators saving cleanly (four history-then-notes pairs in the 3-4pm log, no errors). Loss landed on **Coordinator 16 / ATC 5 / Strength 8** vs Goals 179 and Nutrition 42 - the three thin ones are the departments whose text lived only in the pin.
- **EXACT next step:** Get the S&C coordinator's `s_c_offseason_recommendations` text out of the export, then RENDER the care page at production dpi and look. `[EOY care] S&C offseason recommendations overflows even at 6.0pt -- 4 item(s), budget 0.638` fired at 4:15pm; `eoy_care_page.py:853` sets `y_floor=0.035` (bottom of page) so the overflow runs OFF the page. The code is correct - it shrinks to 6pt then draws and warns rather than clipping silently. Do not guess at the layout (render-and-look.md).
- **Blockers / waiting on:**
  - **Slack delivery was never used for EOY decks** (Zac confirmed) - the "pull PDFs from player channels" recovery avenue is DEAD. What is left: someone's downloaded PDF, their own draft, or IT backups.
  - rsconnect on the work laptop still needs `$env:RSCONNECT_EXE = "C:\Users\zbridger\AppData\Roaming\Python\Python314\Scripts\rsconnect.exe"` or `connect_pins_eoy/deploy.ps1` grabs a non-whitelisted exe. Probe unfixed.
  - Next Arm Farm scheduled pin run unverified: look for `[notebook] STEP 2 -- payloads` and the ABSENCE of the pyarrow ImportError.
  - Zac told the group "overwrote old versions of the app with new versions" (not what happened) and offered to "enter the items that were overwritten" (he cannot - only coordinators know what they wrote). Flagged; his call whether to follow up.
- **Read the action labels carefully:** `create` fires only when a new player ROW appears. Filling an empty box on an existing row logs as `edit`. So "created 0, edited 9" still means real new content.
- **Uncommitted work:** bsb-resources 77 paths, bsb-wt-bullpen 11 - all pre-existing untracked dirs.
