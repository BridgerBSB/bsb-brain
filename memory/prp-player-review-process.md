---
name: prp-player-review-process
description: PRP (Player Review Process) — NEW PD Engine app tab where each dept fills a player's section, green-check gates, auto-sends PDF to zzz_ when all complete
metadata: 
  node_type: memory
  type: project
  originSessionId: 7953a7e9-8dd6-4405-82d8-ded79eefea0a
---

## ✅ BUILT Jun 19 2026 — PRP Report tab SHIPPED to `feature/pd-goals` (commit `294e6208`), UNTESTED on live pin/Slack

The app-driven workflow below is now built. **It lives as the 4th TAB on the PD Goals page (`pages/1_PD_Goals.py` → "📋 PRP Report", next to Goals / Goal Compliance / Upload)** — Zac wanted it inside the PD Goals experience, NOT a separate hub page (refactor commit `a7d903b7`; standalone `8_PRP_Report.py` + landing card removed). Files:
- `pd-goals/src/prp_tab.py` — `render()` for the tab. Player picker (completion badge), **per-domain Superpower + Opportunities boxes** + Goals 3×(What/Why/How) grid, **`💾 Save section`** (write edits + mark ✅) and **`✓ (No Changes)`** (keep baseline content as-is + mark ✅ — the carry-forward button Zac explicitly asked for), Reopen, progress gating, all-green **`📤 Send PRP to coach channel`** (explicit one-click + 🧪 test mode), PDF preview LAST. **NO individual-name attribution** — sections show ✅ + date only (Zac: "we don't need the name of the individual who said so").
- `pd-goals/src/prp_workflow_pins.py` — pin `zbridger/prp_records_<season>`, ONE row/player; content cols (mirror prp_store.csv) + per-section `status_/done_by_/done_at_` + `sent_*`. Seeds from `prp_store.csv` (86 baselines). `save_section/reopen_section/mark_sent/sections_for/all_sections_complete/completion_counts`.
- `pd-goals/src/prp_channels.py` — `resolve_prp_channels(gcid, test_mode)` → zzz_ coach channel (reuses `transition_channels.lookup_zzz_channel`), overflow/test fallback. Delivery reuses `transition_slack`.
- `pd-goals/scripts/pin_prp_records.py` (seed/refresh; `--merge` preserves state) + `clean_prp_records.py` (`--list/--delete/--reopen-all/--clear-all`).
- `PD_Engine.py` PRP REPORT card + `manifest.json` registers all new files incl. `prp_pdf.py`/`prp_store.py`/`prp_store.csv`.

**ROSTER = EBIS (Jun 19 2026, Zac):** PRP player universe = `get_roster()` (PP_MASTER active HOU, **AAA→DSL**, same as the PD Goals sidebar). `pin_prp_records.py` was rewritten to SYNC the pin to that roster: in-org players show even with NO prior PRP (acquired e.g. **Bryce Collins 80773** → empty sheet to fill); **released players (not in EBIS) drop off**; content + every dept sign-off carry forward for players who stay; baseline content seeds a sheet only the FIRST time a player enters the pin. `--reset-content` = destructive re-seed; default preserves edits. `prp_store.csv` is now just the **content lookup by gcid**, grown 86→**112** (added FCL 20 + DSL 6 from `Downloads/FCL.zip`+`DSL.zip` via `scripts/add_fcl_dsl_to_store.py`, gcid via slack_channels, 112/112 matched). DB-dependent → run sync on work laptop. **PRP is now the 2nd tab** (Goals · PRP · Goal Compliance · Upload). Goal Compliance: the Individual All/P/H toggle now also drives the Org matrix (P→Pitching col only, H→Position Player only) + retitles "Org Compliance (Pitching/Position Player)". Commits `c12eb20e` (header scope + 1-row picker), `16732cc3` (send-date freeze + reset), `20de9ca0` (EBIS roster + FCL/DSL + tab + compliance toggle).

**⭐ THE CONNECTED CYCLE — BUILT Jun 19 2026 (commit `e8665bc0`), UNTESTED on live pin/Slack.** A delivered PRP send now: (1) delivers PDF, (2) closes the player's open goals.csv row(s) (`end_date=send_date`), (3) appends a new cycle row (`start_date=send_date`, blank end, `goal_1/2/3` = PRP goal What lines; identity carried from last goal row else EBIS roster), (4) clears PRP green checks (keeps content + sent record) → next cycle fresh. Fires ONLY on FULL delivery (partial/failed = no goal write, no reset). `goals_loader.apply_prp_goals` + `prp_workflow_pins.clear_section_status` + prp_tab Send handler. Goal Compliance/Goals tab pick up the new cycle instantly (same goals pin, date-aware selection). Also Jun 19: Goals PDF download moved to sidebar bottom + "Connected to GC2" button removed (`309e4920`). **DEFERRED:** season-end auto-close of still-open goals (Zac unsure — "maybe 9/30?"). Decided defaults: goal text = PRP "What"; partial send = no-op.

**LATEST (Jun 19 2026, all on `feature/pd-goals`, deployed live):**
- **Sidebar-driven (`fc51d3aa`):** PRP tab has NO own picker — it renders the SIDEBAR-selected player (`selected_gcid` passed to `prp_tab.render`). Header (headshot/name) scoped to Goals tab only so PRP isn't a 2-player view.
- **Auto-materialize / NO repin (`8ed8da09`):** if the sidebar player isn't in the pin (new acquisition / injured pickup — Apker, Dashwood), the tab auto-builds an empty PRP from `roster_df` meta (content seeded from baseline if they have one); persists on first Save via `save_section` UPSERT (`build_record_row`). Running `pin_prp_records.py` is OPTIONAL cleanup, never required.
- **Goal Glossary DONE (`5a7b7c36`):** Upload Goals tab → **📖 Goal Glossary** = read-only `goals.csv` table, newest rows on top + download. Upload UI removed (Zac edits goals on back end). Tab order: Goals · PRP Report · Goal Compliance · Goal Glossary.
- **Send-date freeze (`16732cc3`):** delivered send freezes send date onto the PRP `date`; preview shows today until sent.
- **GOTCHA — goals pin pollution:** Glossary/Goals read the goals **pin** (`zbridger/pd_goals`), NOT local csv. Junk in the pin (blank-goal rows w/ end_dates, dup period buttons) ≠ my code (the cycle write only fires on a real send). FIX: re-pin clean csv `python scripts/pin_goals.py` (work laptop, `CONNECT_API_KEY` set — it's per-session; "board unavailable" = key unset). Local `goals.csv` (117, no end_dates) is source of truth.

**TRIAL RUN IN PROGRESS (Jun 19 2026):** team manually entering AA/A+/A dept SP/Opp+goals from Excel (Bridger/Camden/Sam&Cristian SharePoint) into the app. zzz_ (coach) send = REAL commit (writes goals) — Zac confirmed (corrected my "QA = no write" assumption). Coaches QA in zzz, then forward to athlete Z channel manually. AWAITING Zac's trial feedback. Docs synced: Obsidian `projects/prp-player-review-process.md` updated to current state.

**(historical decision record) THE CONNECTED CYCLE (decided Jun 19 2026):** the all-encompassing wiring Zac has chased "forever." A goal's **`end_date` is NOT set until the NEXT PRP report is fully submitted** — so a goal survives the entire cycle until a new fully-completed PRP supersedes it. This entwines PRP ↔ Goals ↔ Goal Compliance ↔ Upload Goals into one cycle; PRP submission will drive Upload Goals (mechanism Zac will specify) and rewire the sidebar button. OPEN discussion items: (1) snapshot/history of each sent PRP (look-back), (2) reset section behavior (date blank-on-reset; per-player in-app vs all-players CLI), (3) how PRP-complete writes goals + sets prior goal end_date, (4) released-player handling in Goal Compliance.

**Sections = depts + Goals:** pitcher 7 (Pitching/Analytics/PerfSci/S&C/ATC/Nutrition + Goals), hitter 8 (Hitting/Defense-Baserunning/+5 depts + Goals). Slugs via `prp_store._slug`.

**Decisions made (FLAGGED for Zac):** (a) dept identity = honor-system "Your name" field (no auth infra) — could move to role/login later; (b) Send is explicit one-click confirm + test mode, NOT silent auto-send (Slack send is outward-facing/irreversible) — Zac said "auto-send"; change to fully-automatic-on-last-section if he wants.

**Verified locally:** 86 rows seed, gating correct, PDFs render clean (pitcher+hitter) from pin-seeded path, writes fail-soft w/o CONNECT_API_KEY. **NEXT (work laptop):** `git pull`; set `CONNECT_API_KEY`; `python pd-goals/scripts/pin_prp_records.py --season 2026` to create the pin; redeploy PD Engine (GUID 79f52369…); set `LOGIC_APP_URL` Var; test Save / (No Changes) / all-green Send in test mode → real coach channel. Open: DSL channel still None in `transition_channels.AFFILIATE_CHANNELS` (PRP only uses zzz_ coach channel so unaffected). Optional: historical/closed-cycle view; per-section edit-lock by dept.

## ⭐ ARCHITECTURE PIVOT (Zac, Jun 18 2026 — THIS SUPERSEDES the local-AI-merge approach below)

PRP becomes an **app-driven, department-by-department workflow in PD Engine** — modeled on the **Transition Report** (`in-app-submission.md` pattern: Streamlit form → parquet pin → reportlab PDF → Logic App → Slack). NOT a local Claude AI-merge. **This OVERRULES the earlier "LOCAL ONLY, no Posit/pin" decision** — that was because the *merge* needed AI; the new model is *humans fill their own section in the app*, so no AI merge, and it CAN live on Connect.

**The workflow:**
- New PD Engine **page/tab ("PRP Report")**. Per player, the PRP sheet's sections map to **departments/groups** (Pitching/Hitting, Defense-BR, Analytics, Performance Science, S&C, ATC, Nutrition). Each group logs in and fills out **only their section** (Superpower / Opportunities, + goals).
- Each section shows a **green check ✅ to the right when that group has filled it** (per-section completion state). The filled content **stays/persists** (pin-backed) and groups can come back and **update their section** throughout the year.
- **When ALL sections are green-checked for a player → the PDF auto-sends to that player's `zzz_` (triple-z) coach Slack channel** (same per-player routing as postgame/transition, `slack_channels.csv` zzz_ column). Once every player is sent → done for that cycle.
- Pins store in-progress + completed PRPs (like `transition_reports` + `transition_drafts`). The existing renderer `prp_pdf.py` makes the PDF; the baseline store (`prp_store.csv`, 86 players already extracted) **seeds the initial pin content** so depts edit FROM the Spring baseline, not blank.
- This is the GOALS analog of the Transition Report: replaces the CSV-merge cycle entirely. Departments self-serve; no Claude-in-the-loop merging.

**Next (post-/clear, will be set as a /goal):** design + build the PRP Report tab. Reference impl to mirror = Transition Report (`pd-goals/pages/2_Transition.py` + `3_Transitions_View.py` + `src/transition_*.py`). Open Qs: per-section auth/identity (how a group "claims" their section), the completion/checkmark state model in the pin, the "all green → send" trigger, whether goals are a 8th section or set by a lead. Lives in `pd-goals/` (bsb-resources OPERATE track — live feature).

---

## (HISTORICAL) Local AI-merge approach — BUILT Jun 18 2026, now SUPERSEDED by the app pivot above

The renderer (`prp_pdf.py`) + extractor (`prp_extract.py`) + store (`prp_store.py`) are STILL USED by the app (PDF gen + baseline seed). The merge/adjustment/build scripts (`prp_merge.py`, `prp_adjustments.py`, `build_prp_updates.py`, `generate_prp.py`, `seed_prp_store.py`) were the local-CSV-merge path — kept for reference but the app replaces them.

**PRP (Player Review Process)** — NEW PD Goals subsystem, started Jun 18 2026 on `feature/pd-goals`. Zac assigned to own/automate it.

**What a PRP is:** one-page navy "Player Review Process" sheet, one per player. Header (title / date / `Last, First` / gcid) → department table (each dept = Superpower + Opportunities rows) → 3-goal grid (What/Why/How). Pitcher depts: Pitching/Analytics/Performance Science/S&C/ATC/Nutrition. Hitter depts: Hitting/Defense-Baserunning/Analytics/Perf Sci/S&C/ATC/Nutrition. Originally hand-built in an Excel template (`PRP Example.xlsx`, tabs: Pitcher/Position Player Template, Pitcher S&O Entry, Pitcher Goal Entry, rosters) and exported to PDF.

**The workflow being automated:**
1. Spring training — all depts converge on each player's superpowers/opportunities + 3 goals → seeds goals.csv AND the PRP PDFs.
2. In-season — affiliates send **adjustment CSVs** (e.g. `Fayetteville PRP 7-Week Adjustments(Pitchers).csv`): one row/player, one col/department, each cell free-text prefixed by contributor initials (DJ/SB/JW=pitching, ZB/CP=analytics, ABB/BM=perf sci, MQ/BZ=ATC, AM/ZR=S&C, CR/TB=nutrition). Zac feeds these to Claude → Claude proposes the per-section tweaks → applies → regenerates PDFs.
3. Should live IN PD Goals (host the master PRP records + CSVs back/front-end), as a sibling to Transition Report (the in-app-submission.md pattern).

**Current PDFs (86) live in the 4 OneDrive zips** → extracted to `C:\Users\Owner\Downloads\prp_current\<level>\<Pitchers|Position Players>\<Last, F>.pdf`. 3 levels (A Fayetteville / A+ Asheville / AA Corpus), each 15+15 / 15+15 / 13+13. Baseline content (dated 4/1/2026) lives ONLY in the PDFs — the per-level xlsx workbooks hold ONLY the adjustment tabs. Many sections legitimately blank (Zac: "some are blank, we may have to dig deep/discover"); adjustments sometimes give multiple remedies → pick best.

**BUILT + render-verified Jun 18 2026 (runs LOCALLY, pure CSV/PDF↔PDF, no DB). FULL LOOP WORKS:**
- `pd-goals/src/prp_pdf.py` — `PRPRecord` + `build_prp_pdf()`. reportlab, mirrors `transition_pdf.py`. Navy #002D62/orange #EB6E1F. ESCAPE `&` via `_esc` (S&C→"S&C;" bug).
- `pd-goals/scripts/generate_prp.py` — parses per-player Spring template tab → PDF. Verified vs originals (Weber 250211, Rives 260505).
- `pd-goals/src/prp_extract.py` — `extract_prp(pdf, type)` reconstructs baseline PRPRecord from a PDF. Geometry-robust (dynamic row heights): nearest-section-label + nearest SP/OPP-label assignment; goal cols by left-boundary; goal header detected as "Goal"+digit (NOT the word "goal" in a value). **Validated across ALL 86 PDFs: 0 section failures, 0 name failures.** Beck (269548) round-trips byte-faithful.
- `pd-goals/scripts/seed_prp_store.py` — extracts all 86 → `pd-goals/data/prp_store.csv` (wide, 86 rows × 31 cols, gcid via roster/adjustment name maps; **86/86 gcid-matched**). cp1252 fallback for smart-quote CSVs.
- `pd-goals/src/prp_store.py` — `load_store` / `record_from_row` / `row_from_record` / `find_player`. The hosted source of truth (swap CSV→pin later).
- `pd-goals/src/prp_adjustments.py` — `load_adjustments()` routes the in-season delta CSV notes to PRP sections, strips initials-only lines.
- **End-to-end demo:** Beck baseline (store) + Fayetteville 7-wk adjustment → proposed tweaks (FF velo 91.5✓→92.5+, S&C ConImp>320 / CMP/BM>36, +BB vs LHH<10%, +nutrition note) → `UPDATED_Beck.pdf` regenerated dated 6/18/2026. Sent to Zac.

**DECISIONS (Zac, Jun 18 2026):** (a) **LOCAL ONLY — NOT Posit/pin.** The whole PRP pipeline runs on the personal laptop because it requires AI (Claude in the loop). CSV store (`data/prp_store.csv`) is the source of truth; do NOT build a Connect app/pin for it. (b) **Blanks carry forward unchanged** ("stay same as last time"); a **first-time** section/goal with nothing → standard **"Connect with <dept>"** placeholder. (c) Run **full proposed tweaks for ALL players**.

**BULK RUN DONE Jun 18 2026 (first cut, all 88 players):**
- `pd-goals/src/prp_merge.py` — `merge(baseline, adj)` + `new_record(...)` (first-time). Parses "Super Power: X - Opportunities: Y" cells cleanly; APPENDS free-text dept notes to baseline Opportunities (preserves Spring context); skips no-ops (`_NOOP`: "Keep X Goal"/"Maintain"/"--"); first-time PRP fills from adjustments + "Connect with <dept>" placeholders.
- `pd-goals/scripts/build_prp_updates.py` — runs all 6 adjustment CSVs vs store → `output/prp_updates/`: 88 regenerated PDFs (`<level>/<grp>/Name.pdf`), `changes.md` (per-player was→now log), `review_queue.csv` (84 cells for AI polish), `prp_store_updated.csv`.
- Result: **88 players (63 updated + 25 first-time), 368 changes, 84 need AI review, 25 first-time PRPs.** Delivered to Zac: `PRP_7Week_Updated_PDFs.zip` + changes.md + review_queue.csv + updated store. Beck + Cassedy(first-time) render-verified.

**The 25 first-time players** = had a 7-week adjustment but NO Spring baseline PDF in the zips (roster churn / new). e.g. Cassedy, Fraide, MacRae, Mathiesen, Shoemaker, Varela (Fay P); Carr, Collins, Cuevas, Steinbaugh, Moss (Ash); Leach, J.Rodriguez, A.Santos, Torres, Tredwell, True, Biggers, Williams (Cor); Cauro, Luciano, Lytle, Newman (Fay H). Built from adjustments + placeholders.

**OPEN / next:** (1) **AI-polish the 84 review_queue cells** — mostly first-time PRPs (turn raw dept notes into clean SP/OPP, decide goals). (2) **First-time GOALS** currently left BLANK — decide if they should get "Check in with ___" placeholders too (Zac's rule hints yes). (3) some appends are verbose (Beck Pitching opp now long) — may want curation per cell. (4) "Keep FF Goal" embedded mid-note still appends (only leading no-ops skipped). (5) AAA Sugar Land + FCL/DSL not in this batch. (6) where do final PDFs go — Zac delivers to coaches, or add Slack delivery. Source: `Downloads\prp_current\` (baseline PDFs), `Downloads\*PRP 7-Week Adjustments*.csv` (6), `pd-goals/data/prp_store.csv` (seed), `pd-goals/output/prp_updates/` (build). Relates to [[unified-pd-hub-vision]], [[player-development-dual-track]].
