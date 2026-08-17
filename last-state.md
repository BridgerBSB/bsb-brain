# Last session state - 2026-08-17 08:46 (Care page: ForceDeck resolved, Tina's feedback built, waiting on her)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `cb64` - domain `bsb-resources/feature/pd-goals` - id `fb608b06390368d3`. Ring buffer 9/10, so older checkpoints are close to eviction.
- **What we were doing:** closing out the ForceDeck/CMJ database dependencies for the EOY Player Care page, then turning Tina's 2026-08-17 feedback into a real two-page layout and a doc she can act on.

- **Shipped:** `d1526da6` all 13 discovery results + evidence CSVs - `b4972d7c` `render_care_page_real.py` (renders the page from the real export) - `ee629020` pin-vs-DB spec - `60a31fef` first PCMP one-pager, pin count corrected 8->7 - `3bc31e67` Tina's six wording changes + `render_care_page_v2.py` two-page layout + `test_care_page_layout.py` guard - `b7182939` no Spanish under the page title, page 1 filled, artifact refreshed.
- **Resolved:** five S&C metrics confirmed by exact `definition_name`, all on the same trials; step 9b returned `5, 272` so every HOU player has all five. P2:P1 is DB, not a pin. Brodie's flat table is out, EAV chain is in.
- **Two measured findings:** single-test TREND points the wrong way on 21-32% of players (use a windowed mean); MAX is biased by test count (+6.02 at k=3 vs +14.33 at k=30, and HOU counts run 1 to 53), so use mean-of-best-k with k fixed.

- **EXACT next step:** nothing to build until Tina replies - Zac is holding here deliberately. The one thing that can move without her is the work-laptop query confirming NordBord + ForceFrame live in `SportsMed.Metrics`: dump `LK_Metric_Sources.metric_source_name` and `LK_Metric_Types.metric_name/metric_unit`, then distinct `side`/`muscle`/`test` and per-player counts for HOU since 2025. That turns the 10 placeholder rows on page 2 into real ones. When Tina does reply, ASK FOR THE TEMPLATE FIRST - her hierarchy note cannot be acted on without it.

- **Blockers / waiting on:** TINA (the template; is a real reporting bodyweight recorded anywhere; where "what these mean" goes; should the P2:P1 trend sit on the coach's writing screen) - ALVARO (is `Contraction Time` really "Time to Takeoff", it is an inference on a player-facing label) - ZAC (Positional Norm grouping, since 8 of 14 `POSITION_LK` values have under 15 players; plus max-vs-windowed).
- **Worth remembering:** 21 players carry an impossible Eccentric Braking Impulse or P2:P1 that survives Alvaro's WHERE - four of the five care metrics have no physiological gate anywhere, not even in the org's own exclusions view. Needs a per-metric clamp that NaNs the VALUE and keeps the ROW when this is wired for real.
- **Uncommitted work:** clean (untracked scratch only). Artifact: https://claude.ai/code/artifact/fb02be00-9c5f-4ceb-8af4-fe14f19240fa

---

## ALSO OPEN - 2026-08-16 15:18 (EOY goals correctness + two pins nobody read)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen/bullpen-report` (branch `feature/bullpen-reports`) + `C:/Users/Owner/bsb-resources/pd-goals` (branch `feature/pd-goals`).
- **Recall checkpoint (SOURCE OF TRUTH):** session `610b` - domain `bsb-wt-bullpen/feature/bullpen-reports` - id `318843573cb34420`.
- **What we were doing:** fixing the EOY goal bugs Zac found (SB/IP carryover, NetK sign, range direction, Perez shorthand), then chasing why pitcher decks load slower than position ones.

- **Shipped:** `f4c27677`+`4aa2fcaa` range goals say "Above Target" when the miss is high and measure from the edge actually missed - `8e220bf7`+`994e135e` both EOY pitcher pages now READ the payload pin (written and never opened since the day it was built) - `5a9d0f0c` `_EOY_LEVELS` derived from `eoy_roster_select.LEVELS` after drifting 3x - `5bef550d` ship `eoy_roster_select.py` in the pin bundle - lineage entry in `bsb-resources/LINEAGE.md`.
- **Zac confirmed:** goal corrections look right on BOTH pitcher and position decks.

- **EXACT next step:** on the work laptop, from `bullpen-report` (NOT from inside `connect_pins_eoy`): `git pull` then `.\connect_pins_eoy\deploy.ps1`. The last attempt died with `ModuleNotFoundError: src.eoy_roster_select`; `5bef550d` fixes it. Then restart the Connect content, open an MLB pitcher, and confirm the log reads `[POOLS] leaguerow_mlb_rhp_2026_0 from PIN` and `leagueexec_mlb_rhp_2026_0 from PIN` rather than "built live".

- **Blockers / waiting on:** Zac's call on the range progress bar (still reads "58% of target" off the LOW bound under "Above Target") and on the shorthand-direction table (IVB ceiling by pitch type, HB by sign of target, render the RESOLVED text as the card subtitle). Pin scan for other shorthand goals not run. Position-side goals page unchecked.
- **Biggest structural lesson:** `connect_pins_*` bundles are SEPARATE deploy targets from the apps and ship their own copies of `compliance.py`/`goal_parser.py`. Miss them and the scheduled job reverts your fix on a timer. FOUR targets, not two.
- **Uncommitted work:** 78 files in bsb-resources, 15 in bsb-wt-bullpen - mostly pre-existing untracked scratch, not this session's.

---

## RESOLVED 2026-08-17 (was ALSO OPEN 08-15) - EOY ForceDeck sources
> Superseded by the block at the top of this file. All 13 discovery queries ran;
> the S&C dependencies are resolved. Kept for the goals-page-batch half only.

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`.
- **Recall checkpoint (SOURCE OF TRUTH):** session `ba04` - domain `bsb-resources/feature/pd-goals` - id `c95d6bfec48e872e`. This file renders the newest wrap only and **supersedes nothing**; the three threads below are still live.
- **What we were doing:** while the Player Care page waits on Tina, two things - resolving where the card's six force-plate fill-ins actually live in `SportsMed`, and building a batch that renders EVERY player's Development Goals page (both decks) so they can be flipped through and checked.

- **Shipped:** `29e473b2` guard + batch driver + ForceDeck discovery SQL - `41a799cd` ForceDeck findings resolved from Zac's 5 CSV dumps - `fe652391` fixed my own `no_current` key bug.

- **THE BATCH RAN (work laptop): 114 pages, 0 dropped goals, 0 build failures.** Phase census max = **2 phases** on both sides (pitcher 23x1 + 31x2, position 25x1 + 35x2). That confirms Zac's push-back: the page renders complete at <=2 phases, so the second-goals-page work stays **PARKED** and the guard's tripwire is correctly quiet. `test_eoy_goals_page.py` passed 13/13 on his machine.

- **My bug, corrected same session:** the first run reported 160 pitcher goals with no current value - 54 of 54 players at exactly 100%. That was the SCRIPT, not the decks (`g.get("actual")`; the real key is `current`). Aguilar's page renders FF Velo 89.0 vs 91.0 "Close". The tell was sitting in the CSV - `no_current` equalled `n_gradeable` on every pitcher row, which is blocking rule #19's own shape inside analysis code. Both sides now raise on a missing key instead of fabricating.

- **The one real finding - Drew Brutcher (130666, 2a):** Phase 2 (set 07-07) renders all three goals as "No data" while Phase 1 resolves the SAME metrics. Not a parser miss - no measurable activity in that window. **Open question for Zac:** the page reads "0 of 6 goals met" / "0/3 met" while three of six could not be evaluated. The cards are honest; the denominator is not.

- **ForceDeck resolved:** use the EAV chain (`_Player_Test` -> `_Trial` -> `_Result`, 400 metric names). Brodie's flat table and `ForceDeck_View` both carry only ONE of the card's six. Time to Takeoff = **`Contraction Time`** (283,154) - **inferred, confirm with Alvaro before it ships.** Match EXACT strings; every slot has a `Takeoff `-prefixed sibling at n=75-297. Two of my earlier flags were wrong and are corrected in the file header.

- **EXACT next step:** open with the **Brutcher tally question** - should "0 of 6 goals met" exclude the three goals that had no data ("0 of 3 measured"), keep 6 and add "3 awaiting data", or stay as-is? That is the first of the goals loose ends Zac wants to work through. Then take the 13 query outputs he is bringing.

- **Blockers / waiting on:** Tina on the Player Care page (unregistered, not wired, do not send). Alvaro to confirm `Contraction Time`. Zac's call on the Brutcher tally.

- **Standing constraint:** Zac flagged twice that bulk rules-loading is eating context. Pull only what a specific decision needs.

- **Uncommitted work:** 80 paths, all pre-existing clutter; the one tracked modification (`pd-goals/scripts/sync_eoy_pitcher_port.py`) is NOT mine - do not commit it. Nothing of mine is uncommitted.

## ALSO OPEN - 2026-08-14 14:15 (Chuck/Caufield MLB Monday: weekly label overlap + a layout guard)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`; the CODE work was in `C:/Users/Owner/bsb-wt-hitting` - branch `feature/barrelsville`.
- **Recall checkpoints (SOURCE OF TRUTH):** session `8a8d` - `bsb-resources/feature/barrelsville` id `18dd2e574266245c` (the code) and `bsb-resources/feature/pd-goals` id `b3ea165ac8624fc0` (the Monday cascade + close-out). This file renders the newest wrap only. **Supersedes nothing** - the 08-13 EOY thread below is STILL LIVE and was deliberately kept.
- **What we were doing:** started as a `/recall` on where the Caufield ("Cau") week-over-week MLB hitter work stood, became a real fix - the weekly date window was rendering underneath the PA value - and then the sweep for every other page that still said the year.

- **CHUCK'S MONDAY IS SETTLED** - channel `C0BHJ9CM2EQ` (ex-#velo-threshold) gets THREE single multi-page PDFs, each gated on the ML roster AS OF THE RUN (`PP_MASTER LEVELOFPLAY_LK='ml'`), not season MLB activity:
  - phase `velo-thresh` / step `velo-ceiling` -> `Velo_Ceiling_mlb_<seasons>_<date>.pdf`
  - phase `hit-mlb` / step `hitter-mlb` -> `Hitter_Analysis_2026_<date>_MLB_P1-2.pdf` (year-over-year)
  - phase `hit-mlb` / step `hitter-mlb-wk` -> `Hitter_Analysis_2026_<date>_MLB_WK<date>_P1-2.pdf` (week-over-week)
  The `_WK<date>` suffix is what stops the two hitter sends overwriting each other.

- **THE FIND WORTH REMEMBERING:** **neither matplotlib's `ax.table` nor plottable CLIPS an overflowing cell.** No wrap, no shrink, no ellipsis - it draws straight through the divider and over whatever is next door. So a column width is not a layout preference, it is an **unenforced assumption about the longest string that will ever land in it**, and the only symptom is pixels. The KPI row-label column was `0.04` against `0.06` for a data column - narrower than PA - fine for `"2026"`, not for `"Aug 04 - Aug 10"`. Corollary that matters more: **`bbox_inches="tight"` GROWS the canvas around a runaway label**, so the out-of-figure case looks clean in a saved PNG while the fixed-size PDF page is what clips. Looking at a render is *structurally unable* to catch it - you have to measure against `fig.bbox`.

- **Shipped this session:** all pushed, all 4 worktrees in sync with origin (nothing ahead/behind).
  - `387f895f` (barrelsville) the overlap. `row_label_w = _WEEK_COL_W if _PERIOD_LABELS else 0.04`, `_WEEK_COL_W = 0.12`. Weekly only; year-over-year byte-identical. 0.12 chosen by rendering 0.04/0.08/0.12/0.16 + the yr/yr baseline and looking at all five. Kept the verbose `"Aug 04 - Aug 10"` rather than compacting to `"8/04-8/10"`, because the same string is the page title and that is the part Zac said reads well.
  - `dc5590d1` (barrelsville) the label sweep - SIX display strings on pages 3+ still hardcoded the season, and **one was on page 1** (the four zone-chart titles), inside `--first-pages 2`, so it was **already shipping wrong to Chuck every Monday**. Pages A/B/C needed more than a swap: their player data is the week but their colouring pool is always the full season, so new `_data_period_label` names both - `"Aug 04 - Aug 10  (colored vs 2026 league)"`. Byte-identical in yr/yr.
  - `dc5590d1` **the guard** - `barrelsville/scripts/test_weekly_layout.py`, 21 checks, DB-free, ~3s. (a) source regex: no display f-string may hardcode `{season}` where a period label belongs. (b) geometry: render the REAL draw fns at the WORST-CASE label **derived from argparse** (`--baseline last-30` appends `" (30d)"`, so `"Jul 06 - Aug 03 (30d)"`) and assert no two `Text` artists overlap (intersection over the SMALLER box, threshold 0.15) and none leaves `fig.bbox`. Run in weekly-worst AND yr/yr, so it also proves yr/yr did not move.
  - **Proven RED before shipping** - `_WEEK_COL_W=0.04` -> `'Jul 06 - Aug 03 (30d)' over '25' (100%)`; the two pre-fix f-strings -> names lines 4404 and 4852; an over-wide title -> `off the figure by 50px`.
  - New rule `.claude/rules/layout-collision-guard.md`, md5-identical `89287eff1c` in all 4 worktrees and committed on each branch; cross-referenced from `render-and-look.md` (`3b99beffd7`) and indexed in CLAUDE.md. Heads: bsb-resources `5372fc9b`, bsb-wt-hitting `5e757f78`, bsb-wt-bullpen `5b8d6fba`, astros-intangibles `7ccca5ab`.

- **EXACT next step:** **Nothing is queued - Zac closed the thread** (*"our work should be done here"*). Do NOT start anything on this unprompted. If he returns to it, the first move is the zero-DB regression check: `cd C:\Users\Owner\bsb-wt-hitting\barrelsville ; python scripts\test_weekly_layout.py` -> expect `21/21 checks passed`.

- **Blockers / waiting on:** **UNRUN vs DB - no weekly PDF has ever been built from real data.** Personal laptop has no DB access; every render this session was synthetic. His work-laptop verification is TWO pulls in TWO worktrees (`hitter_analysis.py` is in bsb-wt-hitting, `run_monday.ps1` is in bsb-resources - pulling one gets a stale half): `git pull` both, then `python scripts\hitter_analysis.py --season 2026 --mlb --weekly --week-ending 2026-08-10 --first-pages 2` and the same without `--weekly` (no `--deliver`; both land in `barrelsville\reports\`), then `.\pd-goals\scripts\run_monday.ps1 -Date 2026-08-17 -DryRun`.

- **Two decisions I made that are HIS to revisit once he sees real output:** `--baseline` is never passed by the Monday step so it defaults to **prior-week** (`std` and `last-30` are built and untested in production) - he was never asked which one Caufield wants. And a 7-day sample colours against the **full-season pool** with **no sample floor** (`feedback_never_invent_sample_floors` - print the `n`, do not hide the row); he has not seen that on a real card.

- **Guard coverage is PARTIAL, stated honestly:** only 4 surfaces are geometry-checked (KPI tables, metric zone page, swing-path metric table at 1+2 panels, page-1 zone titles). Anything needing a real `pitch_df` - the EV/Whiff zone pages, the contact-point page, the Pages A/B/C table BODIES - is covered by the source check only.

- **Housekeeping en route:** bsb-resources and bsb-wt-bullpen were behind origin; rebased with `--autostash` and the unrelated unstaged files came back intact. That push also carried **9 pre-existing unpushed local commits on bullpen** (the 02-09/02-10 Postgame V2 native-chart work from a prior session). None of it mine; it is now on origin.

- **Uncommitted work:** pre-existing clutter only, nothing of mine - bsb-resources 81, bsb-wt-hitting 41, bsb-wt-bullpen 16, astros-intangibles 18.

---

## ALSO OPEN - EOY app: per-department saves, season picker, athlete-channel delivery (2026-08-13 13:35)

- **Project / cwd:** `C:/Users/Owner/bsb-resources` - branch `feature/pd-goals`
- **Recall checkpoint:** session `b9a1` - `bsb-resources/feature/pd-goals` id `a32b6f165f07ae5f`. **That is the source of truth**; this file renders the newest wrap only. (Supersedes the 08-13 11:45 pd-goals block - same repo+branch, newer.)
- **What we were doing:** Zac's EOY app round - six per-department saves on the off-season plan, season-aware notes, signed-target goal cards, delivery routing - then a stream of things he caught while testing the deployed app live.

- **THE FIND WORTH REMEMBERING:** commit `d1dc7c80` shipped as **DEAD CODE**. `_render_odp_section` in `pages/14_EOY_Reports.py` is a **bespoke renderer** that never goes through `_notes()` - it reads `note_sections_for()` for the box list and had its own hardcoded single Save button. So adding six groups to `_NOTE_SAVE_GROUPS` changed **nothing on screen** while compiling, importing, and passing its own coverage assertion. Zac found it in the app: *"i dont see the ATC button and S and C focus button theyre still just one"*. I edited the config I assumed owned the behaviour instead of grepping its CONSUMERS (`definition-parity-audit.md` s5). **A second renderer of the same widgets is where a config change goes to die quietly.** Guarded: `test_eoy_pool_gates.py` s14.

- **Shipped this session:** all pushed.
  - `d1dc7c80` six ODP save groups (config) + **signed-target goal cards**: a target of 0 or negative renders no bar by design (a ratio of two negatives is positive and GROWS as the player gets worse), which left a dead band - now prints the distance, "3.1 to go" / "Target cleared". No invented bar length; nothing in the goals payload carries a spread to scale one against.
  - `7ecc1e61` **season picker**. The notes pin was ALWAYS per-season (`zbridger/eoy_notes_<season>`), so PRP-style retention + blank-boxes-on-new-year already worked; only `SEASON = 2026` hardcoded broke it. Preset = current calendar year (Zac's call), deliberately NOT auto-roll - EOY work runs Oct-Feb and Jan 1 would blank every box mid-cycle. `season` is now an explicit arg on the 3 cached loaders: **`st.cache_data` keys on ARGS, not globals**, so leaving them reading the global would have served 2026 data under a 2027 selection with no error. Other 6 cached fns audited clean.
  - `f5e86264` the **real** ODP fix - a Save under each of the six boxes, labels pulled FROM `note_save_groups_for` so the grouping has one home.
  - `e0320d34` four things Zac hit testing: **Send back above the deck** (not mine - `33251f51` regressed `522c414f` by drawing both tandem decks in columns ABOVE the button); **real sends now go to the player's `z_` ATHLETE channel** not `zzz_` coach, chain `z_ -> zzz_ -> overflow`; **test safety** renamed + captioned in place; **React at 3 decimals** (`.570` printed `0.6` beside a current of `0.6`, so a met goal and a missed one were the same two characters). Also removed the **P18 hexbin debug probe**.
  - LINEAGE entry appended + pushed.
  - Guards s14 + s15, both proven RED at exit 1. Had to move that file's summary/exit block to EOF **twice** - I appended sections after it, so a failure printed and still exited 0.

- **CRITICAL adjacent defect found while moving delivery:** `OVERFLOW_CHANNEL` **IS** `PD_AUTOMATION_TEST_CHANNEL` (both `C0ABHSF6SCA`). A player with no channel on file came back `status="delivered"` with a green tick having reached nobody - one target, one success. `overflow` is now its own status rendering as a warning. **73 of 360 players have no `z_`**, 13 have no `zzz_`. Any other surface that falls back to `OVERFLOW_CHANNEL` and derives status from "did every channel succeed" has the same shape.

- **EXACT next step:** Zac wrapped to *"discuss some things next turn"* - **ASK what he wants to discuss, do NOT start building.** Three items are queued and unanswered: **(1) goal-card title overflow** - root cause is the TITLE not the sentence wrap; `ax.text(0.055, 0.93, g.get("metric"), fontsize=10.5)` has no wrap and no clip, and for unmeasurable goals the parser's raw-phrase fallback puts the whole sentence in `metric`, so title and body print the same string twice. Proposed ellipsize + suppress-the-duplicate; awaiting his pick. **(2) all-goals PDF** he asked for - one page per player, CHEAP because `build_goals_page()` reads only the compliance pin; awaiting his answers on scope/order and whether a 3-phase player spills to page 2. **(3) pitcher-pools pin**, unchanged - confirm the PIN OWNER first (`cquick/` vs `zbridger/` scar at `pin_eoy_pitcher_pools.py:309`) then the pd-goals adapter + import-graph audit.

- **HIGHEST-VALUE UNFIXED BUG:** **Send does NOT persist notes to the pin.** `save_eoy_notes` is called only from the two Save handlers; neither send block calls it. Type, skip Save, hit Send -> the PDF is right but the pin never gets the text, so the box is blank next time while the delivered report has it. **Worse now: six ODP buttons = six chances to forget.** Zac told twice, no direction yet.

- **My git error:** used `git add -u` on `e0320d34` and swept **12 of Zac's uncommitted WIP files** in (mock PNGs, the deleted slide-deck plan, `generate_amateur_vs_pro_slide_deck*.py`, `probe_clip_stitch.py`). Force-push is **blocked by branch protection** so it could not be rewritten. Nothing lost, nothing changed on disk. Offered a forward-only follow-up commit to back those paths out - **he has not answered.**

- **Blockers / waiting on:** **Everything this session is code-verified ONLY.** Personal laptop cannot reach Connect (DNS), so the season picker has never rendered in Streamlit (sidebar order of two `with st.sidebar:` blocks was reasoned, not observed), the `z_` delivery has never actually sent, and blank-boxes-on-new-season exercised the right path but cannot tell an absent pin from an unreachable board. Zac said *"im testing this"* - expect findings. Work laptop: `git pull` then `rsconnect deploy manifest . --app-id 79f52369-8244-46da-a4d6-95df956bacad` from `pd-goals/`. **No re-pin.** Eyeball: six ODP buttons, Season dropdown at sidebar top, Send above the deck on a **two-deck pitcher**, React showing `.570`, the safety caption. Still unconfirmed on Connect from the prior session: `CONNECT_API_KEY` in Vars, and Min processes = 1.

- **Concurrent session on this branch:** `bab5d74d` (clip-room probe), `85d68d3b`, `da3d203a`, `bca9fdcf` are **not mine**.

- **Answered, no action:** per-phase goal CURRENT values differ **by design** - `compliance.py:346` evaluates each row over its own start/end window. Correct for rates; the 9 `CUMULATIVE_METRICS` (stolen_bases, net_strikes, oaa, paa, fram_raa, block_raa, surpp, innings_pitched) read low in later phases - documented deferral from Zac 2026-08-07, must be fixed in the engine or the deck would disagree with the Cockpit.

- **STILL-WIRED:** `_renderer_stamp()` is the surviving sibling of the P18 probe I removed, still printed by `_render_pdf_inline` on every deck. Left because Zac did not name it.

- **Zac's standing instruction, still in force:** *"you loading all thr rules railed us here"* - resume **fresh**, do NOT bulk-load rules, use `/load-rules` on demand (`rule-loading-architecture.md`).

- **Uncommitted work:** pre-existing untracked clutter only (`.agents/`, `.codex/`, `awesome-claude-skills/`, `design-system/`, `gcpy/`, `pd-goals/output/`). Nothing of mine.

---

## ALSO OPEN - AstroWorld content authoring, access levels, HUBs (2026-08-10 20:00)

