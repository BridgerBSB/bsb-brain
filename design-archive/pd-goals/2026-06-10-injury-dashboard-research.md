# Injury / Health Analytics Dashboard — Deep Research + Design Brief

**Date:** 2026-06-10
**Branch:** `feature/pd-goals`
**Status:** RESEARCH (no code yet — awaiting injury data source confirmation from user)
**Goal:** Build an **Injury Dashboard** that lives as a second tab on the PD Engine
**Org Board** (`pages/5_Org_Board.py`), reached via a new top "title board" tab bar.
Org Board stays the default/auto-selected view; Injury Dashboard is the second tab.
The position-selector "bubble" stays (it's how player profiles get grabbed) and moves
*below* the "Astros Organization Board" title. The top title board also (Part 2) gets
cross-app tabs to Arm Farm / Barrelsville / Intangibles.

This doc is the synthesis of (a) sports-medicine injury-surveillance literature, (b)
workload-monitoring methods (ACWR + baseball caveats), (c) dashboard UX patterns, (d)
Python/Streamlit implementation specifics, and (e) what we already have in-repo.

---

## 0. TL;DR — what to build first

1. **Reuse what's already wired.** Org Board already pulls a live IL/DFA feed
   (`src/roster.py::load_il_sus_roster` → `_classify_il_status` → IL / IL-60 / REHAB /
   DFA / OTHER) and a full transaction history (`src/transactions_data.py` off
   `MLB_eBis.TR_HISTORY`, which includes **"Injury - IL Placement"** and **"Injury - IL
   Transfer"** categories). That is enough to ship a **v1 Injury Dashboard with ZERO new
   data sources** — it's a re-presentation of data we already query.
2. **v1 deliverables (no new data):**
   - **Current IL/DFA roster status board** — who's out right now, by level, by IL
     category, with days-on-IL (computed from the IL-placement transaction date).
   - **IL Gantt / availability timeline** — one horizontal bar per stint, derived from
     TR_HISTORY IL-placement → reinstatement/activation pairs.
   - **Org availability % + IL-count trend** — rolling count of players on IL over the
     season; "team availability %" headline number.
   - **Body-region breakdown** — *only if* the TR_HISTORY description text carries a body
     part (often it doesn't; see Open Questions). If not, defer the anatomical body-map to v2.
3. **Load-speed answer (the user's main worry):** do **NOT** use `st.tabs` for the
   Org-Board/Injury split. `st.tabs` eagerly runs the body of *every* tab on every rerun,
   so the injury queries would fire even while the user is on Org Board. Instead use a
   **query-param-driven view switch** (`?view=org` default / `?view=injury`) rendered as a
   styled HTML "title board" tab strip. Only the active view's data layer runs. Each view's
   data is independently `@st.cache_data(ttl=6h)` and (eventually) pinned — same pattern the
   rest of PD Engine uses. Net effect: opening Org Board costs exactly what it costs today;
   the injury queries only run when the user clicks the Injury tab.

---

## 1. Canonical injury-surveillance metrics (the KPI set)

These are the IOC 2020 consensus-statement definitions — the industry standard for
recording/reporting sports injury data. Use this exact vocabulary so the dashboard speaks
the same language as the medical/performance staff.

| Metric | Definition | Formula | Denominator |
|---|---|---|---|
| **Injury incidence** | rate of *new* injuries over time at risk | `new injuries ÷ exposure` | per 1000 athlete-**hours** (cross-sport gold standard) **or** per 1000 athlete-**days** / per player-season (more practical for us — we don't have clean exposure-hours) |
| **Injury prevalence** | share of squad currently affected | point: `existing cases ÷ squad` at a moment; period: `players affected anytime in window ÷ squad` | — |
| **Injury burden** | frequency × consequence (THE headline metric) | `days lost ÷ exposure` **or** `incidence × mean severity(days lost)` | per 1000 athlete-days |
| **Severity** | time-loss per injury, bucketed | days from day-after-onset → day-before-fully-available | buckets: **0 / 1–7 / 8–28 / >28 days** |
| **Time-loss injury** | the standard inclusion rule | any injury causing **≥1 day** absent from training/competition | (vs "medical-attention" definition which includes 0-day) |
| **Recurrence** | same site/tissue injury **after** full recovery | count ÷ total injuries at that site | (vs **exacerbation** = same site **before** full recovery) |
| **Availability %** | the number coaches actually care about | `(player-match-opportunities − absences due to injury/illness) ÷ opportunities`, avg % | — |

**Design implications:**
- **Lead with injury burden + availability %**, not raw injury count. Incidence alone
  measures *likelihood* but ignores *consequence*; the consensus literature is explicit
  that you must report incidence **and** days-lost **and** their cross-product (burden).
- **Body-region and mechanism breakdowns** are standard surveillance cuts (e.g. shoulder /
  elbow / hamstring / oblique; contact vs non-contact). For a pitching org the
  **shoulder + elbow (UCL)** story dominates — that's the marquee body-map.
- **Recurrence rate** is a developmental-quality signal (are we returning guys to play too
  early?). Worth a dedicated tile once we have clean injury+RTP records.
- Reference: `injurytools` (an R package) implements exactly these epi measures — a useful
  spec to mirror in Python even though we won't use R.

---

## 2. Workload monitoring (ACWR) — use it, but know the baseball caveats

**ACWR (Acute:Chronic Workload Ratio)** = short-term load (acute, ~7-day rolling) ÷
long-term load (chronic, ~28-day rolling). Two computation models:
- **RA (rolling-average), coupled** — acute is included inside chronic (the classic Gabbett
  form). Criticised for mathematical coupling artifacts.
- **EWMA (exponentially-weighted moving average)** — weights recent days more; multiple
  studies find it tracks injury-risk signal better than the plain RA ratio. **If we build
  ACWR, build the EWMA variant** (and optionally show the uncoupled RA for comparison).
- The frequently-cited "sweet spot" is **ACWR ≈ 0.8–1.3**, danger zone >1.5. Use as a
  traffic-light band, **not** as gospel.

**Baseball-specific caveats (BLOCKING context — do not oversell ACWR):**
- The 7-day/28-day windows **don't transfer cleanly to a 5-day pitching rotation** — two
  rest days fall out of the arithmetic. ArmCare's piece notes this "stumped Gabbett"
  himself. So a naïve soccer-style ACWR on pitch counts is shaky for SP.
- ACWR is an **external-load-only** measure (what the arm *did*), not how the arm
  *responded*. Players inside the sweet spot still get hurt.
- The broader literature is openly skeptical ("Is there scientific evidence?" editorials;
  systematic reviews finding spikes *dissociated* from injury). Treat ACWR as **one
  descriptive panel, clearly caveated**, not a prediction engine.

**What's actually defensible for OUR pitchers (and we already compute most inputs):**
- **Throwing-load time series** from our own data: pitch counts / innings (we have IP via
  `MLBAM.Gamelog_Pitching.outs` per `ip-calculation.md`), appearances, **AOL (avg outing
  length)**, days-rest between outings, back-to-back flags. These are concrete and trusted.
- **Rolling pitch-count / IP load** with a simple acute-vs-chronic visual is fine as a
  *descriptive* workload panel — just label it honestly.
- ArmCare's recommended direction is **functional testing** (arm strength, shoulder ER/IR
  balance, strength-velocity, pre/post-session recovery, ROM). We almost certainly **don't
  have that data in GC2** — flag as a future integration if the org captures it elsewhere.

**Recommendation:** ship the **descriptive throwing-load timeline** (pitch counts / IP /
days-rest) in an early version; gate "ACWR risk band" behind a clear "descriptive, not
predictive" caveat; do **not** build an injury-prediction model in v1.

---

## 3. Dashboard UX patterns for injury/availability data

The well-trodden patterns from pro-sports medical dashboards (soccer Premier-League-style
availability boards, NBA load management, AI injury-risk monitors):

1. **Roster availability status board** — the squad as a grid of cards/rows, color-coded
   Available / IL / Rehab / DFA / Day-to-day. This is *exactly* the Org Board kanban shape
   — the Injury Dashboard is its medical-lens twin. We already split IL/DFA out
   (`load_il_sus_roster`); the injury tab just makes that the headline.
2. **Availability heatmap** — players (rows) × dates (cols), cell colored by status
   (green available → red out). Great for "who was out when, all season, at a glance."
3. **Anatomical body-map (body heatmap)** — front/back human silhouette with body regions
   shaded by injury frequency or days-lost. The signature injury-dashboard visual. For a
   pitching org, the shoulder/elbow heat is the story.
4. **Gantt / availability timeline** — one horizontal bar per IL stint over a season
   timeline (start = IL placement, end = reinstatement). The canonical "who's been out and
   for how long" view. Plotly has first-class Gantt support.
5. **Traffic-light risk indicators** — red/amber/green chips for ACWR band, days-rest,
   workload spike, IL-recurrence flag. At-a-glance triage.
6. **Trend lines** — IL-count-over-time, team availability %, injury burden by month — the
   same grey-org-lines + HOU-navy-bold pattern our KPI charts already use
   (`visual-standards.md`).

**Org Board already gives us #1 and a transaction timeline strip** — so the injury tab is
mostly recombination + 2–3 new visuals (heatmap, body-map, Gantt).

---

## 4. Python / Streamlit implementation specifics

### Tab bar / view switch (load-speed-critical)
- **Avoid `st.tabs`** for the Org-Board ↔ Injury split — it runs all tab bodies each rerun.
- **Use a query-param view switch** styled as the "title board." Pattern:
  ```python
  view = st.query_params.get("view", "org")   # 'org' default → auto-selected
  # render HTML title-board nav with pills linking ?view=org / ?view=injury
  if view == "org":
      _render_org_board()       # existing code path — unchanged cost
  elif view == "injury":
      _render_injury_dashboard()  # only runs when this tab is active
  ```
  The nav pills are `<a href="?view=injury" target="_self">` styled like the existing level
  pills (`LEVEL_PILL_COLOR`). The Arm Farm / Barrelsville / Intangibles "tabs" (Part 2) are
  just `<a href="https://connect2.astros.com/...">` external links in the same strip.
- Alternative if we want true separate Streamlit pages: keep Injury as its own
  `pages/N_Injury_Dashboard.py` and use `st.page_link` in the title board. Either works;
  the query-param switch keeps everything in one file and one CSS block (and the position
  selector lives above both views). **Recommend the query-param switch** so the position
  bubble + title board are shared chrome and we don't duplicate the kanban CSS.

### Gantt / timeline
- `plotly.express.timeline` (a.k.a. Gantt) — `px.timeline(df, x_start=, x_end=, y=player,
  color=il_category)`. One row per IL stint. Native, fast, click-friendly.

### Anatomical body-map
- No turnkey baseball body-map package exists. Options, simplest → richest:
  1. **SVG silhouette with region paths** — hand-authored front/back human SVG where each
     body region is a `<path id="shoulder_R">`; fill each region by injury metric. Render
     via `st.components.v1.html` (we already use this pattern in Org Board for the lazy
     history JS). Most control, ~one-time SVG authoring cost. **Recommended.**
  2. **`etal/bodymap`** (GitHub) — draws anatomical maps; closest off-the-shelf, but generic
     and not injury-tuned. Evaluate, likely outgrow.
  3. **Plotly scatter over a body PNG** — overlay colored markers on body regions using
     `layout.images` background + scatter; quick but crude.
  - The soccer viz packages (`mplsoccer`, `matplotsoccer`, `socplot`) are **pitch** maps,
    NOT body maps — not directly usable, but confirm the "shade-regions-by-value" idiom.
- **For a pitching org, start with a focused upper-body / arm diagram** (shoulder, elbow,
  forearm, lat, oblique) rather than a full-body anatomical render. Higher signal, less SVG.

### Performance / caching (must match PD Engine conventions)
- `@st.cache_data(ttl=6h)` on every injury data fetch (mirrors Org Board's
  `CACHE_TTL_SECONDS = 6*60*60`).
- If the injury queries get heavy, **pin them** the same way the rest of PD Engine pins
  (`rules/tracker-parquet-pins.md` — joblib/parquet bundle, Connect-scheduled refresh,
  pin-first read with live-DB fallback). v1 almost certainly doesn't need a pin — the
  IL/transaction queries are PP_MASTER/TR_HISTORY (small, already 6h-cached).
- **PDF block (if any) goes LAST** per `rules/pdf-last-in-script.md`.

---

## 5. Real-world examples + data model

- **Soccer availability dashboards** (Premier-League-style, Sky Sports injury tables,
  Aspetar surveillance programme, AI injury-risk monitors): squad availability board +
  per-player risk chips + load trends. Data model = **per-player injury records**
  (onset date, body region, mechanism, severity/days-lost, RTP date) joined to **exposure**
  (training/match minutes, GPS load) + **roster**.
- **NBA load management**: minutes/back-to-backs/availability — same external-load + status
  shape.
- **Common data model** (what a mature injury dashboard sits on):
  ```
  injury_event(player_id, onset_date, body_region, side, tissue, mechanism,
               severity_days, status, rtp_date, recurrence_of_id)
  exposure(player_id, date, minutes/IP/pitches, session_type)
  roster(player_id, level, position, availability_status)   ← we have this
  ```
- **We already have the roster + an IL/transaction proxy for `injury_event`.** What we lack
  is a clean medical `injury_event` table (body region, mechanism, true RTP) and an
  `exposure` feed beyond pitch/IP. That gap defines the v1↔v2 boundary.

---

## 6. Recommended architecture for the Injury Dashboard tab

### What we already have (reuse, don't rebuild)
| Asset | File | Gives us |
|---|---|---|
| Active roster (PP_MASTER, 6h cache) | `src/roster.py::get_roster` | squad universe, level, position |
| **IL/DFA roster** + categorizer | `src/roster.py::load_il_sus_roster` + `_classify_il_status` | current-out list → **IL / IL-60 / REHAB / DFA / OTHER** (status codes 7DL/60D/FSIL/DL/10D/15D/7RH/15R/60R/DFA) |
| Transaction history (TR_HISTORY) | `src/transactions_data.py` | per-player IL-placement / reinstatement events incl. **"Injury - IL Placement"** + **"Injury - IL Transfer"** categories, dates, `load_player_transactions`, `load_recent_transactions`, category/bucket colors |
| Kanban + drawer + CSS chrome | `pages/5_Org_Board.py` | the status-board UI to clone for the availability board |
| Position selector bubble | `pages/5_Org_Board.py:1954` (`st.selectbox`) | the crucial player-profile filter — **keep, move below title** |

### Layout (the user's spec, made concrete)
```
┌──────────────────────────────────────────────────────────────────────┐
│  TITLE BOARD  (new top strip)                                          │
│  [ Org Board ]  [ Injury Dashboard ]   |   Arm Farm · Barrelsville ·   │  ← Part 2 = external links
│   ^default/auto    ^new tab                Intangibles                  │
├──────────────────────────────────────────────────────────────────────┤
│  Astros Organization Board            (existing H1 title)              │
│  [ Position ▾ ]   (selector bubble — moved to here, below the title)   │
├──────────────────────────────────────────────────────────────────────┤
│  <active view renders here>                                            │
│   view=org    → existing kanban (unchanged)                            │
│   view=injury → availability board + IL Gantt + trend + body-map(v2)   │
└──────────────────────────────────────────────────────────────────────┘
```
- Title board = HTML strip rendered once (shared chrome), pills styled like level pills.
- `?view=org` (default) renders the existing board verbatim → **zero added cost** on the
  default path.
- Position selector stays a real Streamlit `st.selectbox` (it drives both views) and is the
  one widget that renders above the view switch — moved to sit just under the H1.

### Phased build
- **v1 (no new data — ship-able now):** availability status board (clone kanban, color by
  IL category) + days-on-IL (from IL-placement txn date) + IL Gantt (placement→reinstatement
  pairs from TR_HISTORY) + IL-count/availability-% season trend. All off existing
  PP_MASTER + TR_HISTORY queries.
- **v2 (needs a body-region source):** anatomical arm/upper-body body-map shaded by
  injury frequency / days-lost; mechanism + recurrence breakdowns.
- **v3 (needs medical + functional data):** ACWR/throwing-load panel (descriptive,
  caveated), RTP tracking, ArmCare-style functional readiness if that data exists anywhere.

---

## 7. Open questions for the user (data availability gates v2/v3)

1. **Is there a real medical injury table** anywhere we can reach (body region, side,
   tissue, mechanism, severity-days, RTP date, recurrence link)? Or is **TR_HISTORY IL
   transactions** the only injury signal we have? (This is the single biggest fork — it
   decides whether the body-map is v1 or v2.)
2. Does TR_HISTORY's transaction **description text carry a body part** (e.g. "right
   shoulder")? If yes, we can parse a crude body-region cut in v1.
3. Do we have **any functional / readiness data** (ArmCare arm-strength, shoulder ER/IR,
   force-plate, ROM) in a queryable store? Determines whether v3's functional panel is real.
4. **Scope confirm:** Injury Dashboard MiLB-only (matches Org Board), or include MLB?
5. **Cross-app tabs (Part 2):** confirm the Arm Farm / Barrelsville / Intangibles Connect
   URLs (app GUIDs are in `CLAUDE.md`) for the external-link pills.

---

---

# PART B — Scope update + DATA ANSWER (Jun 10 2026, user direction)

The user confirmed scope: a **league-wide (all 30 MLB orgs) injury timeline dashboard**,
with **injury type, days missed, IL placements (who + when)**, **per-org pages**, and
**multi-org sortable / ranked pages** (pies, timelines, bar charts, org rankings by days
missed). Reached from the Org Board top title strip. This is bigger than the original
"HOU IL tab" framing — it's a standalone league injury analytics surface inside PD Engine.

## THE DATA ANSWER (definitive)

**There is NO dedicated medical / diagnosis / injury table in GroundControl2.**
Verified against `sql-queries/DATABASE_REFERENCE.md`, `SCHEMA_OVERVIEW.md`, the whole
`sql-queries/` tree, and the live `transactions_data.py` plumbing. **Our ONLY injury signal
is `MLB_eBis.TR_HISTORY` + `TR_NAME_LKUP` (the league-wide eBis transaction log) + PP_MASTER
roster statuses.** TR_HISTORY columns are confirmed (see `tr-history-discovery.sql §1`):
`PLAYER_ID, TRANSACTIONNAME_LK, PRE/POST_ORG_LK, PRE/POST_CLUB_LK, PRE/POST_*ROSTERSTATUS_LK,
TRANSACTION_DTSTMP, SVE_*` (service flags, mostly NULL).

### What that gives us (all 30 orgs — TR_HISTORY is the league feed via `*_ORG_LK`)

| Field the user asked for | Available? | How |
|---|---|---|
| **IL placements — who + when** | ✅ YES | `category = 'Injury - IL Placement'`, `PLAYER_ID` = who, `TRANSACTION_DTSTMP` = when, `POST_ORG_LK` = org |
| **Days missed** | ✅ DERIVED (not stored) | **stint** = placement → next reinstatement (`REINS/RHBRT/RSTIL/RENES/REACT/RCACT/ACPAC`); `days = DATEDIFF(placed, returned or today)`. See `injury-dashboard-discovery.sql §4–5` |
| **Injury "type" = IL length** | ✅ YES | from placement code: 7-day / 7-day concussion / 10-day / 15-day / 60-day / Full-Season IL / IL(ML) / IL(MiL) |
| **All 30 orgs + rankings** | ✅ YES | group/rank on `POST_ORG_LK`; `injury-dashboard-discovery.sql §5` proves the leaderboard |
| **Currently-on-IL snapshot** | ✅ YES | PP_MASTER status (already used by `load_il_sus_roster`) |
| **Injury TYPE = body region / diagnosis** | ❌ NO (almost certainly) | TR_HISTORY says "Placed on 15-day IL," never the body part. **One hope:** an `SVE_*` column carrying a note — probed in `injury-dashboard-discovery.sql §3`. Don't count on it. |
| **Anatomical body-map (Part A §4)** | ❌ BLOCKED | needs body-region data we don't have → **drop unless §3 surprises us** |
| **True RTP / functional readiness** | ❌ NO | no medical/ArmCare table in GC2 |

**Bottom line:** everything the user asked for — IL placements, days-missed charts, org
rankings, per-org timelines, pies of IL-length type, multi-org sortable views — is
**fully buildable from TR_HISTORY today.** The ONE thing we can't do is anatomical
injury-type / body-region breakdowns (and therefore the body-map), unless `SVE_*` (§3)
secretly carries it OR the org provides an external medical CSV. So "type of injury" in v1
means **IL length**, not body part. This must be set as the user's expectation up front.

## The core data model — the "IL stint"

Everything hinges on collapsing the transaction log into **stints** (one row per
continuous out-period per player):
```
il_stint(player_id, org, level, position_group,
         il_type,            -- 7/10/15/60-day / full-season / concussion (from placement code)
         placed_on, returned_on,   -- returned_on NULL = still out (open stint)
         days_missed,        -- DATEDIFF(placed, returned or today)
         is_open)
```
Derivation lives in a new `pd-goals/src/injury_data.py` (mirrors `transactions_data.py`):
1. Pull all `Injury - IL Placement` + reinstatement rows league-wide for the season(s).
2. Pair each placement with the earliest reinstatement after it (per player).
3. **Collapse transfers:** a 7-day→60-day transfer (`Injury - IL Transfer`) is the SAME
   stint with a longer length — keep the FIRST placement of a contiguous out-period, take
   the LONGEST/last IL type, end at the final reinstatement. (Validate in discovery §4.)
4. Attribute org by `POST_ORG_LK` at placement; level via CLUB_LK → level (reuse Org Board's
   `LEVEL_CLUB_MAP` + `load_global_club_map` GBL_CLUB_LKUP fallback); position via PP_MASTER.

## Metric set (off the stint model)

- **Per org:** total days missed, # IL stints, # players injured, avg stint length, open
  (currently-out) count, IL-length-type mix, by-level + by-position breakdown, timeline.
- **League:** org ranking by total days missed (+ by stints, by avg length), HOU's rank,
  league-wide IL-length-type pie, monthly placement trend.

## Page architecture (the user's "page per org + multi-org" ask)

Reached from the Org Board **title board** strip (`?view=injury` query-param switch — NOT
`st.tabs`, per Part A §4). Inside the injury view, an **org selector** (All 30 / single org):

- **League view (default, "multiple orgs"):**
  - 30-org **ranking table** — sortable by days missed / stints / avg length / open count
    (`st.dataframe` sortable, HOU row bold; or AgGrid per `tracker-aggrid-stat-rank.md` if
    we want a "value (rank)" combined cell).
  - **Bar chart** — orgs ranked by total days missed (HOU navy, others grey — our KPI chart
    idiom from `visual-standards.md`).
  - **League IL-length-type pie** + **monthly placement trend line**.
- **Per-org page** (`?view=injury&org=HOU`):
  - Org headline tiles (total days missed + league rank, # stints, # currently out, avg).
  - **IL Gantt timeline** — one bar per stint over the season (`px.timeline`), colored by
    IL-length type, click → player.
  - **Pie** of IL-length-type mix + **by-position / by-level** bars.
  - Stint table (player, type, placed, returned, days missed, open?) — sortable.

## Build phases (revised for 30-org scope)

- **Phase 0 (you, work laptop):** run `sql-queries/injury-dashboard-discovery.sql` — §3 is
  the decider (any body-part field?), §1 volume (pin vs live), §4–5 validate stints +
  league ranking. Report results inline.
- **Phase 1:** `src/injury_data.py` (stint derivation + per-org + league rollups, 6h cache)
  + the `?view=injury` title-board switch on Org Board + League ranking view (table + bar +
  pie + trend).
- **Phase 2:** Per-org page (Gantt timeline + org tiles + breakdowns + stint table) +
  org selector + sortable charts.
- **Phase 3:** pin the season stints if volume warrants (Connect-scheduled, per
  `tracker-parquet-pins.md`); historical multi-season backfill; HOU deep-link from Org Board
  cards. Body-map ONLY if §3 found body-region data.

## Load-speed

`injury_data.py` 6h-cached; pin only if discovery §1 shows high volume. The league
ranking is one league-wide stint query → one Python rollup; cheap. (The earlier
`?view=` Org-Board-tab plan is SUPERSEDED — see Part C: this is now a standalone app.)

---

# PART C — STANDALONE PRIVATE APP (Jun 11 2026, user direction)

**Decision:** the Injury Dashboard is NOT a tab on PD Engine. It is its **own standalone
Streamlit app**, deployed as **separate Posit Connect content**, with **viewer access
restricted to Zac + Sam only**. Rationale: IL/medical-adjacent data should not inherit PD
Engine's broader audience; a separate content item gives independent access control,
independent deploy, and its own Vars/pin namespace.

The earlier "tab on Org Board / `?view=` switch" framing (Parts A–B) is retained only for
the *data + viz* content; the *delivery vehicle* is now a private app, not a tab.

## Access control — the privacy mechanism (Posit Connect)

Privacy is enforced by **Connect content access settings, NOT by code**:
- New Connect content → **Access** panel → set sharing to **"Specific users or groups"**
  (NOT "Anyone — no login", NOT "All users"). Add **Zac (owner) + Sam** as the only viewers.
- Result: only authenticated Zac/Sam see it; it won't appear in anyone else's content list.
- This is the same Connect instance (connect2.astros.com) as the other apps — just a
  separate, locked content item.

## Repo structure — TWO options (user picks; Option 1 recommended)

**Option 1 — co-located standalone app on `feature/pd-goals` (RECOMMENDED).**
A self-contained app folder (e.g. `pd-goals/injury_dash/` or top-level `injury-dash/`) that
**imports the existing `pd-goals/src/` DB layer** (`database.py`, `roster.py`,
`transactions_data.py`, `pins_config.py`) — same worktree, so NO cross-worktree-import
violation (`feedback_no_cross_worktree_imports.md`) and NO duplication of the TR_HISTORY /
roster code (single source of truth). New code = `src/injury_data.py` (stint layer) + the
app entrypoint + `pages/`. Deployed as **separate Connect content** with its **own
`manifest.json`** that lists the entrypoint + the `pd-goals/src/*` modules it imports (the
deploy bundle copies them in, exactly like the `connect_pins*/deploy.ps1` pattern).
- Pro: zero duplication; reuses confirmed TR_HISTORY/roster/DB code; one branch.
- Con: deploy manifest must enumerate the shared `src` modules (mechanical, well-trodden).

**Option 2 — fully separate worktree + branch** (e.g. `feature/injury-dash`, new worktree),
mirroring how barrelsville/bullpen/intangibles are each isolated apps with their own `src/`.
- Pro: total isolation (own everything), cleanest "private app" boundary.
- Con: must COPY `database.py` + `roster.py` + `transactions_data.py` into it (duplication +
  drift risk; cross-worktree import is banned so it can't reuse pd-goals/src).

## Deploy + Vars (either option)

- Standalone entrypoint (`Injury_Dashboard.py`) + `pages/` (League / per-org).
- Own `manifest.json` + `requirements.txt`; deploy via `rsconnect` (Connect-scheduled pin
  optional later — Part B Phase 3).
- **Vars tab on the new content:** `DB_USER`, `DB_PASS` (FreeTDS, copy from an existing
  app's Vars), `CONNECT_API_KEY` (only if it reads/writes pins). Linux container can't do
  Windows Auth — FreeTDS creds required (per `tracker-parquet-pins.md` §12.3.7).
- **Access:** restrict to Zac + Sam (above) — do this in the Connect UI after first deploy.

## Build phases (revised — standalone app)

- **Phase 0 (you, work laptop):** run `sql-queries/injury-dashboard-discovery.sql` (§3 body-
  part decider, §1 volume, §4–5 stint + ranking validation). Report inline.
- **Phase 1:** scaffold the standalone app (entrypoint + manifest + requirements) +
  `src/injury_data.py` stint layer + League ranking page (sortable 30-org table + bar + IL-
  type pie + monthly trend). Deploy to Connect, lock access to Zac + Sam.
- **Phase 2:** per-org page (Gantt timeline + tiles + by-pos/level bars + stint table) + org
  selector. Sortable charts throughout.
- **Phase 3:** pin season stints if volume warrants; historical backfill. Body-map ONLY if
  discovery §3 surfaced body-region data.

---

---

# PART D — POST-DEPLOY ITERATION (Jun 12 2026) — READ FIRST ON RESUME

## Deploy state (DONE except the final command)
App built + pushed on `feature/pd-goals` at `pd-goals/injury_tracker/` (self-contained:
`Injury_Tracker.py` League + `pages/1_Org_Detail.py` + `src/injury_data.py` +
`src/database.py` dual-mode + `requirements.txt` + `manifest.json` + `.python-version`).

**Deploy gotcha (resolved):** rsconnect runs under Python **3.14** → `deploy streamlit`
stamps the bundle 3.14.6 → Connect only has **3.11** → `build-failed-error: no
compatible environment`. FIX committed: `manifest.json` pinned to **python 3.11.0**
(appmode `python-streamlit`, entrypoint `Injury_Tracker.py`, empty checksums; mirrors
`pd-goals/manifest.json`). **MUST deploy with `deploy manifest`, NOT `deploy streamlit`**
— streamlit mode prints "the existing manifest.json will not be used or considered" and
re-stamps the local 3.14. Canonical command, run **from `pd-goals/injury_tracker/`**:
```
rsconnect.exe deploy manifest . --server https://connect2.astros.com --api-key <KEY> --title "Injury Tracker" --new
```
After build OK: delete any dud failed "Injury Tracker" items in the Connect UI; set
**Vars** `DB_USER`/`DB_PASS` (FreeTDS); lock **Access** → "Specific users or groups" =
**Zac + Sam only**.

## FIXED this session
- **TR60N** added to transfer codes (fired 103x, was dropped).
- **Bulk roster-parking toggle** (`is_spring_bulk`, default EXCLUDE) — round-4 proved
  the 2026-03-17 cluster of 216 dominates the ranking (NY #3→#8, HOU #7→#10).
- **Released-player "still out" bug (Karniel Pratt / Yajure):** released/FA/retired
  players' IL stints never closed → ran to today, inflating days. Added
  `IL_REMOVAL_CODES` (RELES/URREL/UNCRL/FAOTH/ELFA/FAXAC/RETIR — `org-board.md`
  'Roster Removal'); a removal **while on IL** ends the stint at the removal date
  (`ended_reason='released'`, `is_open=False`, days bounded). Org-Detail table shows
  OUT / Returned / **Released**. Verified via synthetic `get_stints` test.

## OPEN DECISION — converge on ONE definition aligned with Eno Sarris (NEEDS USER)
Inspiration: **Eno Sarris, The Athletic, 2026-06-04** — "baseball injuries by
organization" (Mets/Yankees/Orioles). https://www.nytimes.com/athletic/7330754/2026/06/04/baseball-injuries-organizations-mets-yankees-orioles/
User wants ONE coherent view, not the toggle ("all this should be on one tbh… confused
why there is a button"). Questions to settle next session:

1. **Drop the spring-bulk toggle for a single definition?** User leaning yes.
2. **Season-start clamping (the "count from when" point — the big one):** a player
   injured to start the year — count from his **placement date** (often Feb/spring) or
   from his **level's Opening Day**? You can't miss games in the offseason. Proposal:
   `days_missed = end_date − max(placed_on, level_season_open)`. This likely **dissolves
   the spring-bulk problem** (a Feb 60-day parking counts only from ~April when MiLB
   starts; a genuinely season-long guy still counts as real burden) → may remove the
   need for the toggle entirely. Needs a per-level 2026 opening date =
   `MIN(sched_date)` per level (or per org×level) from `Schedule_View`.
3. **MLB-only vs all-levels:** Sarris is MLB-focused; our dashboard is all 30 orgs ×
   ALL levels (MLB+MiLB), which is WHY the MiLB parking dominates. Decide: keep
   all-levels (with clamping) or add a level filter / MLB-default.
4. **Released players:** DONE (stint ends at release). Confirm it matches intent — user
   said released guys "should count, but their stint should end as soon as they're
   released," which is exactly the fix.

**Likely path:** implement season-start clamping (Q2) → that probably lets us delete the
bulk toggle (Q1) and gives a single Sarris-aligned "player-days lost in-season" number;
optionally add a level filter (Q3). Then re-deploy via `deploy manifest`.

---

# PART E — v2 DELIVERED (Jun 12 2026) — FEATURE-COMPLETE

User sign-off: "done product besides one-off requests." Latest commit `ce168085`
on `feature/pd-goals`. App = `pd-goals/injury_tracker/` (standalone Connect content,
Access = Zac + Sam).

**Gold source found (intern):** `SportsMed.DL_Stints` — league-wide, current, with
body part + side + diagnosis (e.g. "Left Hamstring – Strain"). Supersedes the
body-map "dropped" call in PART A/D. Reference query: `sql-queries/dl-stints-recent-injuries.sql`.

**Shipped:**
- Single-page, top-bar controls (no sidebar): Season · Dashboard (League/Org Detail)
  · **Level MLB|MiLB** (unselected = all) · **Rank by (Days Missed | IL Stints)** · Org
  (All + 30; League scopes to one team) · **Include days after release** · **Exclude
  preseason** (IL'd before **Apr 5** — one solid cutoff, NOT per-level; eBis levels
  fluctuate early). All reactive, scope both sources.
- **Rank by** is a global lens (Days Missed default) applied to BOTH dashboards. Days
  missed = severity/volume; IL stints = frequency/incidence — flip to see whether the
  org order shifts (Sam ask). `league_org_summary` exposes both `rank` and `stint_rank`;
  the toggle re-points the League bar/rank-tile/table and the Org Detail health-rank tile.
- Two sources: TR_HISTORY (stints/days/open-closed/IL-length) + DL_Stints (body part
  + diagnosis).
- League: KPI tiles (#1 = healthiest) · org bar · IL-length pie · **body-part PIE +
  diagnosis bar** · always-on Trend·severity·level·recurrence · org-table expander.
- Org Detail: tiles (Health-rank tile follows the Rank-by toggle) · IL Gantt · pie ·
  injury-type section · stint table (with an **Injury Type** column after Level, before
  IL Type).
- Body part = side-stripped specific; blank/`'Other'` pools to its group; pie shows
  all parts (no rollup "Other").
- Deploy = `rsconnect deploy manifest .` (NOT streamlit), py3.11 pin, from app dir.

**Only remaining (optional):** run `sql-queries/dl-stints-discovery.sql` §1-§5, then
full source-swap (days-missed + open/closed off DL_Stints) + a body-map view. Not
needed for the current product.

---

## Sources
- IOC 2020 Consensus Statement (injury/illness surveillance methods + definitions): https://pmc.ncbi.nlm.nih.gov/articles/PMC7029549/
- Injury & illness surveillance framework for team sports: https://pmc.ncbi.nlm.nih.gov/articles/PMC11163858/
- `injurytools` epi-measures spec (incidence/burden/prevalence): https://cran.r-project.org/web/packages/injurytools/vignettes/estimate-epi-measures.html
- Aspetar 8-season football injury-burden surveillance: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11694202/
- ACWR overview (Science for Sport): https://www.scienceforsport.com/acutechronic-workload-ratio/
- "Rethinking Acute:Chronic Workload for Pitchers" (ArmCare — baseball 5-day-rotation caveat + functional alternative): https://blog.armcare.com/rethinking-acute-to-chronic-workload-for-pitchers/
- ACWR "Is there scientific evidence?" editorial: https://www.frontiersin.org/journals/physiology/articles/10.3389/fphys.2021.669687/full
- ACWR systematic review (injury-risk relationship): https://pmc.ncbi.nlm.nih.gov/articles/PMC7047972/
- ACWR spikes dissociated from injury (soccer): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7739681/
- Plotly Gantt/timeline: https://plotly.com/python/gantt/
- `etal/bodymap` (anatomical maps in Python): https://github.com/etal/bodymap
- `mplsoccer` (region-shading idiom; pitch not body): https://pypi.org/project/mplsoccer/
- Multiverse Player Injury Risk Monitor (commercial dashboard shape): https://multiversecomputing.com/player-injury-risk-monitor
- SoccerGuard ML injury-risk (data-model reference): https://arxiv.org/pdf/2411.08901
