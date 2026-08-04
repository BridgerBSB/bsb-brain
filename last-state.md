# Last session state - 2026-08-04 15:45 (Decision Outcomes: line at 50 + calibration fixed)

- **Project / cwd:** `C:/Users/Owner/bsb-wt-modeling` - branch `feature/promotion-models`
- **Recall checkpoint:** session `c0d3`, domain `bsb-wt-modeling/feature/promotion-models`. **That is the source of truth**; this file is a rendering of the newest wrap only.
- **What we were doing:** Reworked the Decision Outcomes promote quadrant at Zac's direction (x axis, verdict words, table columns, GC2 links), then spent the back half chasing a Board-page failure that turned out to be Connect infrastructure, not our code.
- **Shipped (all pushed, `860ffbb6` -> `d462144e`):** verdict axis moved to the ABSOLUTE grade and then FIXED at 50 - words renamed to OUTPERFORMING / CONFIRMED / UNDER EXPECTATIONS / CONFIRMED LOW - the promote calibration curve stopped measuring roster survival - Grade at Promote + Current Grade columns - Grade Now rename on release - GC2 player links - Side-wrap CSS - board perf (169KB PDF per rerun, history re-parse per click).
- **The finding worth remembering:** the promote "Were we right?" curve read **100% in every bucket** because it plotted roster survival. `train_promote_held.py` trains on `promote_held = (post_pct - pre_pct) >= -tol` and its docstring says the v2.0 SURVIVAL label was **abandoned** for running ~73% positive. The page had re-introduced that abandoned label at the display layer. **Zac caught it from the picture, not from the code.**
- **Deploy VERIFIED:** the 17:03 scheduled run printed `promote readiness reference -> 50.0 (FIXED...)` plus the `VERIFIED:` line - proof `connect_pins_decisions` was redeployed and is not reverting the pin.

- **EXACT next step:** Connect -> **Promotion Model** (GUID `fbbb2dd7-076c-46fc-9635-64e6adba55bd`, Content ID 970) -> **Settings -> Runtime** -> set **Min processes = 1, Max processes = 1**, raise **Idle timeout**. That is the fix for the red `Failed to fetch dynamically imported module` boxes AND the repeated "Loading v3 grades". If the fields are capped it is a server-level `Applications.*` setting - email Chris Josefy (cjosefy@astros.com).

- **DO NOT chase the Connect issue in code again.** Ruled out with evidence: `app.py` byte-identical since `c8608490` - Python renders fine (screenshot shows "236 players") - `st.cache_data` has a constant key with no eviction and no `.clear()`, so it cannot miss twice in a live process - Streamlit pinned `>=1.49.0,<1.50.0` since Jun 27, same cached env hash both deploys. The `_w_` token pair **differs on every occurrence** across three screenshots: Connect is reaping the worker.
- **Blockers / waiting on:** Zac to change the Connect runtime settings (he was going to /clear and take it fresh).
- **Uncommitted work:** 71 files in bsb-wt-modeling, **all pre-existing untracked artifacts** (projection-anatomy outputs, rules files, explain.html). None of this session's work is uncommitted.
- **Next real improvement (not started):** store a pre-move percentile on the ledger so the promote calibration curve can use the model's ACTUAL label instead of the `_producing` proxy. Schema + resolver work.

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
