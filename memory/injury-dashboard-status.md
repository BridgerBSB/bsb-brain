---
name: injury-dashboard-status
description: "Injury Tracker — standalone Connect app FEATURE-COMPLETE v2 (TR_HISTORY + DL_Stints body part/diagnosis); only optional full source-swap + body-map remain"
metadata: 
  node_type: memory
  type: project
  originSessionId: ed24512b-9f5f-4275-95d4-04a85c356a41
---

**Injury Dashboard** — new feature on `feature/pd-goals`. Lives as a SECOND tab on
Org Board (`pages/5_Org_Board.py`), reached via a new top "title board" tab strip.
Org Board = default/auto-selected; Injury Dashboard = second tab. Position-selector
bubble STAYS (crucial for grabbing player profiles) and moves BELOW the "Astros
Organization Board" H1. Part 2 = cross-app tabs (Arm Farm / Barrelsville / Intangibles
external links) in the same title strip.

**Status (Jun 10 2026): RESEARCH DONE, no code yet.** Full deep-research + design brief at
`pd-goals/docs/plans/2026-06-10-injury-dashboard-research.md` (metrics, ACWR caveats, UX
patterns, Python/body-map/Gantt impl, real-world data models, phased plan, sources).

**Load-speed answer (user's main worry):** do NOT use `st.tabs` (it runs every tab body
each rerun → injury queries fire on the Org Board path). Use a **query-param view switch**
`?view=org` (default) / `?view=injury` styled as the title board — only the active view's
data layer runs. Default Org Board path keeps its current cost.

**v1 ships with ZERO new data** — reuse `src/roster.py::load_il_sus_roster` +
`_classify_il_status` (IL/IL-60/REHAB/DFA) and `src/transactions_data.py` TR_HISTORY
("Injury - IL Placement" / "IL Transfer" categories): availability status board + IL Gantt
(placement→reinstatement) + IL-count/availability% trend.

**DATA ANSWER (locked Jun 10):** NO dedicated medical/diagnosis table in GC2 (checked
DATABASE_REFERENCE.md, SCHEMA_OVERVIEW.md, whole sql-queries tree, transactions_data.py).
ONLY injury signal = `MLB_eBis.TR_HISTORY` + `TR_NAME_LKUP` + PP_MASTER — the league-wide
eBis txn log (PRE/POST_ORG_LK = all 30 orgs). Gives: IL placements (who/when/org), **injury
"type" = IL LENGTH** (7/10/15/60-day/full-season/concussion — NOT body part), days-missed
(DERIVED via stint = placement→next reinstatement REINS/RHBRT/RSTIL/RENES/REACT/RCACT/ACPAC),
org rankings. **CANNOT do body region/diagnosis → body-map DROPPED** unless an `SVE_*` col
carries a note (probed in discovery §3) or an external medical CSV appears.

**DECISIONS (Jun 11):** (1) Standalone + private NOW, **fold into PD Engine LATER** — reason:
Posit Connect access is PER-APP not per-page, so a private injury page can't live in the
coach-visible PD Engine; built portable (injury_data.py + 2 pages drop into pd-goals/pages/
with ~zero rework) for the future move. (2) The feature/pd-goals push-rejection was
UNINTENTIONAL — user is removing the branch protection; once off, push commit `81ac9691`
straight to feature/pd-goals (local feature/pd-goals is already 1 ahead of origin) and delete
the temp `feature/injury-tracker` branch. Normal push-to-feature workflow resumes.

**DELIVERY (user Jun 11): STANDALONE PRIVATE APP, not a PD Engine tab.** Own Streamlit app,
SEPARATE Posit Connect content, viewer access LOCKED to Zac + Sam only (Connect "Specific
users or groups" access setting — privacy is a Connect UI setting, NOT code). The earlier
`?view=` Org-Board-tab plan is SUPERSEDED for delivery (data/viz content unchanged).
Repo: **Option 1 (recommended)** = co-located app folder on `feature/pd-goals` importing
existing `pd-goals/src` (database/roster/transactions_data/pins_config — same worktree, no
cross-worktree-import violation, no dup) + new `src/injury_data.py`, deployed as own Connect
content w/ own manifest (bundle the shared src modules like connect_pins deploy.ps1). Option 2
= fully separate worktree/branch (must COPY the 3 DB modules). Vars: DB_USER/DB_PASS (FreeTDS),
CONNECT_API_KEY only if pinning. **AWAITING user pick: Option 1 vs 2.**

**SCOPE (user Jun 10):** league-wide 30-org injury dashboard — injury type, days missed, IL
placements, **page per org** (Gantt timeline + pies + by-pos/level bars + stint table) +
**multi-org sortable/ranked pages** (30-org ranking table sortable by days missed/stints/avg,
bar chart, league IL-type pie, monthly trend). Core model = **IL stint** (new
`src/injury_data.py`, mirrors transactions_data.py). Reuse Org Board CLUB_LK→level map +
GBL_CLUB_LKUP fallback.

**BRANCH NOTE (corrected Jun 11):** pushes to `feature/pd-goals` WORK NORMALLY — the
"Changes must be made through a pull request" line is a NON-BLOCKING advisory hook, not a
block. The repo protection only blocks branch DELETION (GH006). Everything (Phase 1 + Phase 2)
is on **`feature/pd-goals` @ `5c5253df`**. A redundant `feature/injury-tracker` ref exists
(same commit, can't delete due to no-deletion protection — harmless; delete via GitHub UI if
wanted). Normal push-to-feature workflow is intact; no protection change needed.

**PHASE 2 ADDED (Jun 11):** severity buckets (IOC 1-7/8-28/>28 days) + by-level days-missed
bar + recurrence (repeat-IL) KPI/table — all off existing stint data, commit `5c5253df`.
Remaining researched items: availability% + by-position (small new query, build next if asked),
body-map (GATED on discovery §3), ACWR/throwing-load (separate Phase 3, optional, diff data src).

**PHASE 1 BUILT + PUSHED (Jun 11):** standalone app `pd-goals/injury_tracker/` (own
Connect content from feature/pd-goals). Files: `src/injury_data.py` (IL-stint derivation
`get_stints(season)` + `league_org_summary`/`il_type_breakdown`/`monthly_placements`/
`org_stints`; reinstatement code set TUNABLE — validate via discovery §2/§4), `src/database.py`
(self-contained copy + pool_pre_ping), `Injury_Tracker.py` (League: KPI tiles, HOU rank, days-
missed bar HOU-highlighted, IL-type pie, monthly trend, sortable 30-org table), `pages/1_Org_Detail.py`
(per-org Gantt timeline + tiles + pie + sortable stint table). All 4 ast.parse clean.
Commit `81ac9691`. **⚠️ feature/pd-goals now REJECTS direct push (branch protection — "must use a
PR"); the documented push-to-feature workflow is broken.** Worked around: pushed to NEW branch
**`feature/injury-tracker`**. Work laptop: `git fetch && git checkout feature/injury-tracker`.
Deploy: `rsconnect deploy streamlit pd-goals/injury_tracker/ --title "Injury Tracker"` → set
Vars DB_USER/DB_PASS → lock Connect access to Zac+Sam. Then PR feature/injury-tracker→feature/pd-goals.

**DISCOVERY COMPLETE + APP FINISHED (Jun 12 2026, commit `bbe6254f` on `feature/pd-goals`).**
Ran discovery rounds 1-4 on work laptop. Findings:
- **Round 1:** TR_HISTORY validated. 2026 = 2433 placements / 30 orgs (live 6h cache fine, no
  pin). Reinstatement codes REINS/RHBRT/RSTIL/RENES/ACPAC all fire (REACT/RCACT unused, harmless).
  **Bug found+fixed: `TR60N` (103x in 2026) was missing from IL_TRANSFER_CODES + _IL_TYPE.**
  HOU = #7 / 3300 days / 87 stints.
- **Round 2-3 (medical tables):** §3c surfaced real medical tables. `SportsMed.Injury_Data_BPro`
  = full BP injury ledger (body_part/side/injury/severity/days/games/surgery/reaggravation) BUT
  **FROZEN AT 2014** (round-3 §1 returned only 2011-2014; 2024+ empty). `MLBAM.PBP_Injury` =
  coarse during-game events (injury_type only, no days/RTP). `SportsMed.Sports_Medicine` = HOU-only
  physical screening (FMS/ROM/body-comp), future v3 readiness panel. **VERDICT: no current-season
  body-part source → body-map stays OFF for live view; TR_HISTORY (IL-length type) stays PRIMARY.**
  BPro is gold for a future HISTORICAL (1974-2014) retro only.
- **Round 4 (spring-bulk):** end-of-spring roster-parking DOMINATES the ranking. 2026-03-17 =
  216 placements all 60-day/full-season; removing it moves NY #3→#8, NYY #6→#16, HOU #7→#10.
  Smaller 2026-05-22 (48 severe) cluster too. **Built `is_spring_bulk` detection (any day with
  ≥20 60-day/full-season placements) + a League + Org-Detail TOGGLE; default = EXCLUDE.**

**APP STATE: fully built + smoke-tested + pushed, awaiting work-laptop DEPLOY.** Files in
`pd-goals/injury_tracker/` (self-contained: `Injury_Tracker.py` League + `pages/1_Org_Detail.py`
+ `src/injury_data.py` + `src/database.py` dual-mode FreeTDS/WinAuth + requirements.txt). Added
`deploy.ps1` + `DEPLOY.md`. Rollups + bulk flag verified on synthetic data (no DB needed).
**DEPLOY (work laptop):** `cd ~/bsb-resources && git pull && $env:CONNECT_API_KEY=... &&
.\pd-goals\injury_tracker\deploy.ps1` → Connect UI: set Vars DB_USER/DB_PASS (FreeTDS) → lock
Access to "Specific users or groups" = Zac + Sam ONLY. Then verify the spring-bulk toggle live.
Discovery SQL rounds 2-4 saved as `sql-queries/injury-dashboard-discovery-{2-medical,3-bpro-coverage,4-springbulk}.sql`.
Org Board context in `.claude/rules/org-board.md`.

**🔑 GOLD SOURCE FOUND — `SportsMed.DL_Stints` (Jun 12 2026, intern). CHANGES THE WHOLE BUILD.**
League-wide + all levels (MLB→DSL) + **CURRENT** (2026) + **body part + side + diagnosis** + real
dates/`total_days`/`dl_stint_num` + est RTP (`EARLIESTREINSTATEMENT_DTE`). Keys: `groundcontrol_id`
+ `PLAYER_ID`(ebis); org via `POST_ORG_LK`/`POST_CLUB_LK`→`GBL_CLUB_LKUP`. Cols (from intern's query,
not exhaustive): txn_date, POST/PRE_ORG_LK, POST/PRE_CLUB_LK, first/last_name, groundcontrol_id,
PLAYER_ID, transactionname, TRANSACTIONNAME_LK, bodypart, bodypartdetail, BODYSIDE_LK(R/L),
diagnosis, INJURY_DTE, LASTGAME_DTE, EARLIESTREINSTATEMENT_DTE, total_days, dl_stint_num.
**SUPERSEDES the TR_HISTORY-derived `injury_data.py`** — gives real diagnosis (not just IL-length) →
**body-map is BACK ON**, plus body-region/diagnosis/side breakdowns + RTP. Earlier discovery MISSED
this (checked Injury_Data_BPro[frozen 2014] + PBP_Injury[coarse]). Intern's query saved:
`sql-queries/dl-stints-recent-injuries.sql`. PBP_Injury decision query now MOOT.
**INJURY TRACKER — FEATURE-COMPLETE v2 (Jun 12 2026, latest `ce168085` on `feature/pd-goals`).
User: "done product besides one-off requests."** Standalone Connect app `pd-goals/injury_tracker/`.
FINAL shape:
- **Single page, TOP-BAR controls (no sidebar):** Season · Dashboard segmented (League / Org Detail)
  · Level segmented (**MLB | MiLB**, unselected = all levels) · **Rank by segmented (Days Missed | IL
  Stints)** · Org selectbox (All orgs + 30 — League can scope to ONE team) · toggle **Include days
  after release** · toggle **Exclude preseason**
  (drops anyone IL'd before **Apr 5** of season — SOLID fixed cutoff, NOT level-based; user explicitly
  rejected per-level Opening Day b/c eBis levels fluctuate early). Every control is reactive + scopes
  BOTH data sources.
- **TWO data sources:** TR_HISTORY (stints / days-missed / open-closed / IL-length) + **SportsMed.DL_Stints**
  (specific body part + side + diagnosis — the gold source).
- **League:** 5 KPI tiles (rank #1 = HEALTHIEST / fewest days) · org-ranking bar (HOU orange) · IL-length
  pie · **Injury type section = body-part PIE + diagnosis bar** (DL_Stints) · always-visible
  Trend·severity·level·recurrence · org-ranking-table expander.
- **Org Detail:** tiles · IL Gantt timeline · IL pie · injury-type section (org-scoped) · stint table.
- **Stint table** has an **Injury Type** col (after Level, before IL Type), matched gc_id + closest
  placement date ("—" on no match).
- **Body part** = side-stripped specific (Left+Right Hamstring → Hamstring); detail blank/`'Other'`
  pools into its group (`s.bodypart`); pie shows ALL parts (no top-N rollup "Other").
- **Deploy:** `rsconnect deploy manifest .` (NOT streamlit — py3.11 pin) from `pd-goals/injury_tracker/`;
  Vars DB_USER/DB_PASS; Connect Access = Zac + Sam only.
- **Commit trail:** 82809550(top-bar+1-team+compact) 36e7d234(injury-type) 70125f2a(MLB|MiLB+side-strip)
  c9087a75(body pie) 46a9cc4a(Other→group + trend always visible) 9f265094(Injury Type col)
  4344baee(drop pie "Other" rollup) b59815ac→16f2fa23→ce168085(preseason → Apr 5 final).
- **SQL saved:** `dl-stints-recent-injuries.sql` (intern's gold query), `dl-stints-discovery.sql`,
  `dl-stints-other-breakdown.sql`, `dl-stints-hou-other.sql`. PBP_Injury MOOT.
**"RANK BY" TOGGLE ADDED + WORKING (Jun 12 2026, commits `e6fe6495` + `c534d352` on
`feature/pd-goals`). Sam ask: "adding IL stints in addition to days missed... curious if that
shifts anything."** Days missed = severity/volume (one season-ender = big days/1 stint); IL stints
= frequency/incidence (many short trips = many stints/modest days). They diverge, so ranking orgs
by each lens can reorder them. Implementation:
- `league_org_summary` now also computes `stint_rank` (#1 = fewest IL stints), co-equal to the
  existing days-missed `rank`. Both ascending (#1 = healthiest).
- **Global "Rank by" segmented control in the top bar** (Days Missed default), resolved ONCE to
  `metric_col`/`rank_col`/`metric_label` and passed into BOTH `render_league` and
  `render_org_detail` (user explicitly wanted it toggleable for both dash pages, sitting right of
  Dashboard + Level).
- League: drives headline bar chart (y + caption, `categoryorder=total descending` auto-reorders
  on flip), the #X/30 health-rank tile, and the org-table sort + Rank column.
- Org Detail: the "Health rank" tile follows the toggle; c1/c3 tile tooltips still show both static
  per-lens ranks (days-missed rank + stint-frequency rank).
- Pure display change — no SQL/derivation touched (`n_stints` was already computed). No re-pin
  (app is live-DB, no pins). USER CONFIRMED WORKING.
- Possible future polish if asked (deliberately NOT built): rank-Δ column (Days Rk vs Stint Rk +
  delta) and a days-vs-stints scatter (catastrophic vs nagging quadrants).

**ONLY REMAINING (optional, not needed for current product) — awaits user work-laptop run of
`sql-queries/dl-stints-discovery.sql` §1-§5:** full source-swap so days-missed + open/closed come off
DL_Stints too, + a body-map view. `get_level_opening_dates()` left UNUSED in injury_data.py (harmless). Decisions pending results: (1) retire TR_HISTORY derivation = single
source (rec: yes); (2) days-missed = `total_days` vs computed. Season-start-clamp/release toggle
threads likely simplify once DL_Stints' return handling is understood.

**POST-DEPLOY (Jun 12 2026, commit `4378700a` + release-fix commit). READ `docs/plans/2026-06-10-injury-dashboard-research.md`
PART D first on resume.**
- **DEPLOY GOTCHA RESOLVED:** rsconnect runs under Python **3.14** → `deploy streamlit`
  stamps 3.14.6 → Connect has only **3.11** → build-failed. FIX: committed `manifest.json`
  (python 3.11.0, mirrors pd-goals/manifest.json) + `.python-version`. **DEPLOY WITH
  `deploy manifest` NOT `deploy streamlit`** (streamlit mode ignores the manifest +
  re-stamps local 3.14). Run FROM `pd-goals/injury_tracker/`:
  `rsconnect deploy manifest . --server https://connect2.astros.com --api-key <KEY> --title "Injury Tracker" --new`.
  Then UI: delete dud failed items, set Vars DB_USER/DB_PASS, lock Access to Zac+Sam.
- **RELEASED-PLAYER BUG FIXED:** released/FA/retired players' IL stints ran "still out"
  to today (Karniel Pratt, Yajure). Added `IL_REMOVAL_CODES` (RELES/URREL/UNCRL/FAOTH/
  ELFA/FAXAC/RETIR) as stint-enders → stint ends at release date, `ended_reason='released'`,
  is_open=False, days bounded. Org-Detail shows OUT/Returned/Released. Smoke-tested.
- **POST-DEPLOY ITERATION (Jun 12, pushed to `origin/feature/pd-goals`, latest `82809550`).**
  Several UI changes shipped, ALL still **awaiting work-laptop `deploy manifest` to go live:**
  - **Bulk toggle REMOVED** (`a244a4d3`) — always counts all IL (Sarris "all IL time").
  - **(Released) label + "Include days after release" toggle** (`9e1d75ff`, default OFF =
    days stop at release; ON = count through today).
  - **Rankings flipped: #1 = FEWEST days missed (healthiest)** (`8095764c`); table sorts
    healthiest-first. HOU now reads ~#24/30 "health rank".
  - **UI RESTRUCTURE (`82809550`):** sidebar multipage → **single page + top
    `st.segmented_control` (League / Org Detail)**. Shared **Org selector** — League can be
    narrowed to ONE team ("All orgs (League)" default + 30). Compact fit-on-screen League
    (KPI tiles + org bar + IL-type pie above the fold; trend/severity/level/recurrence +
    tables in expanders; CSS tightens spacing; sidebar collapsed). **DELETED
    `pages/1_Org_Detail.py`** (folded into `render_org_detail`); dropped from manifest.
    Parse-clean; NOT visually tested (no DB on personal laptop) — verify on redeploy.
  - **BRANCH FIX:** local `feature/pd-goals` upstream was mis-set to
    `origin/feature/injury-tracker` (plain `git push` rejected, name-mismatch). Reset to
    track `origin/feature/pd-goals` via `git push -u`. All session commits ARE on
    `origin/feature/pd-goals`. Future `git push` works normally now.
- **OPEN DECISION (needs user) — season-start clamping.** Eno Sarris, The Athletic
  2026-06-04 (Mets/Yankees/Orioles injury burden). KEY next build = count days from
  `max(placed_on, level_season_open)` not raw placement (can't miss offseason games) —
  likely dissolves remaining spring-parking inflation. Needs per-level 2026 opening date =
  `MIN(sched_date)` per level. Also decide MLB-only vs all-levels (Sarris is MLB-focused;
  our all-levels scope is why MiLB parking dominates). Full spec in PART D.
