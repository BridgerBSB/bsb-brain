# Last session state - 2026-08-07 18:47 (EOY: amateur pool fix + Development Goals page)

- **Project / cwd:** `C:/Users/Owner/bsb-resources/pd-goals` - branch `feature/pd-goals`
- **Recall checkpoint:** session `1a4f`, domain `bsb-resources/feature/pd-goals`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Fixed my own amateur-pool regression that blanked the P13 Arm/Exch %MLB table and the P14-P17 %MLB donut halves, then built the Development Goals page as the deck's second page.
- **Shipped this session:** 4 commits, all pushed.
  - `eff568ff` pool LEVEL is `{level_filter}`'s job; `{junk}` stays an EXCLUSION. `_level_scope_pool_sql` added. Two pools ask for `mlb` on every source, so a positive pin emptied them. Affiliate/unofficial byte-identical. **Zac reran: "WE RERAN AND IT ALL LOOKS FANTASTIC HERE"** - DB-verified.
  - `f6ea685c` Development Goals page. Renders 2nd, **no renumber** (page_num None, existing keys untouched). Affiliate-only, no-goals-no-page, unreadable-pin renders "unavailable" rather than vanishing.
  - `70c6f46b` full-season + dedupe - **REVERTED, do not resurrect.**
  - `ea4525fb` the revert (per-phase windows, repeats stay as two cards) + removes four of Zac's WIP files that my `git add -u` swept onto the branch. Content restored on disk, still uncommitted.
- **EXACT next step:** Ask Zac what page 2 looked like on his dinner run: `python scripts\generate_eoy_position.py --gcid 244959 --season 2026` (Xavier Neyens, single-level A).
- **Blockers / waiting on:** Zac's eyeball on the rendered goals page. The page is UNRUN vs DB - guards cover shape + gating only.
- **Uncommitted work:** 86 paths, essentially all pre-existing untracked clutter plus the 4 restored WIP files. Nothing of mine.
- **Known + accepted:** stolen-bases goals read low (phase window, not season) - Zac's call, deferred.


## ALSO OPEN - Postgame V2 panel audit (bsb-wt-bullpen, session 13f1)
- **Project / cwd:** `C:/Users/Owner/bsb-wt-bullpen/bullpen-report` - branch `feature/bullpen-reports`
- **Recall checkpoint:** session `13f1`, domain `bsb-resources/feature/bullpen-reports`. **That is the source of truth**; this file renders the newest wrap only.
- **What we were doing:** Audited every panel of the Postgame V2 pitcher card with Zac, panel by panel, fixing what the audit surfaced. Contact Quality, Count Battle, Attack Zones, StuffRelVel Distribution, vs-LHH/RHH + Times Through Order, Velo Fatigue, gcPerf Trend. He ran real reports at every level between rounds.
- **Shipped this session:** ~18 commits `f47adcda` -> `e6e16c2a` (plus `83e8c1d2`, `90ebba4e`, `8b1e69b8` earlier in the arc), all pushed, all four guard suites green. Headlines:
  - **Contact Quality** value and pool disagreed on the BIP denominator on two axes (pool counted bunts, card kept EV misreads). Both now match `tracker_data`.
  - **Attack Zones**: hitter height NEVER reached the classifier in production - `batter_height_ft` existed only in a function signature and a test fixture, so every hitter was scored against a 6.0212ft zone. Heart band top moves 6.4in across 5'6"-6'7". Zone diagram was ~24% oversized and never set an aspect; redrawn in real inches with geometry IMPORTED from the classifier.
  - **Velo Fatigue** rebuilt twice - see `bsb-resources/LINEAGE.md` 2026-08-07. Final: y = loss from own fresh velo, season-scoped, SE ribbon, plus a NEW league fade curve (`_VELO_FADE_QUERY`) that ran clean on live data at every level.
  - **TTO redefined**: batters faced, nine to a turn, IBB counted including zero-pitch automatics (via the PA frame). Any TTO figure from before today used the old per-batter definition and is not comparable.
  - **Card now prints `percentiles: YYYY LEVEL`** (orange on fallback). It had been serving prior-year percentiles silently.
- **EXACT next step:** **Talk before typing.** Zac's words: *"we will talk about furthering the report, its purpose etc next session - doing some dash stuff."* Open the session by asking what the card is FOR, who receives it, and whether it replaces V1. Do NOT start editing panels.
  If code is wanted, the entry point is the two undecided thresholds in `bullpen-report/src/postgame_percentiles.py`: `has_data` (~line 1129) uses `any(...)` so one metric crossing 10 qualifiers drags every pool live; and `_MIN_POOL_N = 5` (line 75) is too low. **V1 and V2 SHARE that constant** - any change moves both plus the Arm Farm app page. Zac said "dynamic!!! want this to match v1". Do not pick the number for him.
- **Blockers / waiting on:** Zac's decision on those two thresholds. Nothing on this card is deployed - CLI only, not in `manifest.json`, never delivered to Slack.
- **Uncommitted work:** 11 files in `bsb-wt-bullpen` (`.claude/rules/*.md` + `.claude/scripts/scaffold_pin_deploy.py`) - **pre-existing, not from this session**, left untouched deliberately.

## Standing rule earned this session

I invented **four** sample floors without asking (25/50 on x-stat pools, 30 on a distribution row, 5 on gcPerf dots, 5 pitch types on the TTO usage bar). Every one hid data Zac wanted to see. Rule: **communicate sample size, never gate on it** - thresholds are his call, default to none, print the `n`. Written to `memory/feedback_never_invent_sample_floors.md` and indexed in MEMORY.md.
