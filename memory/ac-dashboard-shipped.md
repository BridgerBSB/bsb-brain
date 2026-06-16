---
name: AC Dashboard shipped
description: Astros Catching internal KDB-port dashboard — 6 tabs LIVE on feature/astros-intangibles as of May 9, 2026
type: project
originSessionId: 1a6368db-2db3-4ba6-843f-a01258601ce9
---
# AC Dashboard ("Catcher Dash") — LIVE

KDB (kickdirtbaseball.com) visual port for HOU's catching team, scoped
to internal data. Lives at `?view=dashboard` on `intangibles/pages/4_Catching.py`.

## Status (May 9-13, 2026)

**LIVE on `feature/astros-intangibles`.** User confirmed UI "looks very
solid" after CommonMark trap fix.

**May 13 — pending user audit.** All three goals from the May 12
autonomous sprint shipped (GOAL 1 `96242cb`, GOAL 2 `a05559d`, GOAL 3
`17c66ea`) before user's machine restarted. User has not yet tested
end-to-end on work laptop. Open decisions list below is still the
correct punchlist — DO NOT assume any of those are resolved until user
confirms after their audit pass.

**May 13 (afternoon) — 5 bug classes shipped** in `a74e3c7`. User
flagged Pitch Calling / Pitchers / Stats throws / Scoreboard /
Catcher Cards extras all returning empty or wrong data, and Gameday
had no date toggle. Root causes:

1. **`pv.pitch_type_lk` phantom column** — canonical everywhere is
   `pv.pitch_type` (no `_lk` suffix). 5 sites in pitch_calling.py,
   pitchers.py, gameday.py. → broke Pitch Calling, Pitchers, Gameday
   zone plot completely.
2. **`cdt.runner_out` phantom column** — canonical
   `compute_throwing_summary` derives CS from `ev.event_result LIKE
   '%caught_stealing%'`. stats.py was the only place using
   `cdt.runner_out`. Rewrote stats throws CTE to JOIN PV + EV on
   `cur_event_id` (SBA events are PA-ending, matches canonical
   `_THROWS_QUERY`).
3. **Stats blocks missing 3 canonical filters** — `dirtball_flag=1`,
   `event_result NOT IN ('walk','hit_by_pitch')`,
   `pitch_result NOT IN ('hit_into_play','hit_into_play_no_out')`.
   Without them every non-null pp_prob row counted → "blocks crazy".
   Now mirrors `_SEASON_BLOCKING_QUERY` exactly.
4. **Scoreboard slate** — `sv.sched_date = :target_date` is fragile if
   sched_date is DATETIME; switched to `CAST(sv.sched_date AS DATE)`.
   INNER JOIN to MLBAM.Teams dropped affiliate games where opponent
   isn't in MLBAM (DSL/FCL pairings). Switched to LEFT JOIN + ISNULL
   org_abbrev. Same fix on `get_latest_hou_game_date`.
5. **cards_extras** — `SELECT TOP :n` swapped to `{top_n}` .format()
   placeholder. Pop-time hand split was using `ab_event_id` for
   Events_View JOIN — that's the AB-ending event, NOT the SBA event.
   CS detection silently failed. Switched to `cur_event_id`. Block
   sub-query in recent_games CTE was missing same 3 canonical filters
   as stats blocks → over-counted opps.
6. **Gameday tab — no date toggle.** Added 3-column chrome: From/To
   date_input pickers (in-memory filter on existing games list) plus
   "🎯 Latest Game (mm-dd) →" orange button that jumps straight to
   the most recent sched_id. Card hrefs now include `catcher_id` so
   URL share works without session_state.

**Out of scope for May 13 fix (still TBD, awaiting user input — see
"Open user decisions" section below):**
- Defensive grade composite weights
- 7-bucket framing detail (KDB-only construct)
- Hitting stats panel spec
- 5×6 approach matrix per-pitcher
- Umpire schema probe (column + lookup table)
- Live/final game scores in Scoreboard (Schedule_View score column probe)
- Same-day data lag (real-world tracker pipeline delay, not a code bug —
  the "Latest Game" quick-jump mitigates the UX impact)

Future agents touching AC dashboard SQL: **mirror the canonical
catcher_data.py + catching_tracker_data.py patterns verbatim.** The 5
bug classes above were all preventable via canonical-first authoring.

---

## Where we left off (May 14)

User is running the catcher tracker pin refresh today
(`connect_pins_catcher/deploy.ps1` from the intangibles app root).
After it finishes + Connect redeploy, they'll audit the dashboard
end-to-end with the May 13 `a74e3c7` fixes in place.

**Sequenced for the next session:**
1. User confirms after pin run + redeploy whether each May 13 fix
   actually populated as intended (Pitch Calling, Pitchers, Stats
   throws+blocks, Scoreboard slate, Cards recent games + pop hand
   split, Gameday date picker + Latest Game button).
2. User answers the 6-question punchlist (defensive grade weights,
   7-bucket framing canon, hitting stats panel spec, 5×6 approach
   matrix per-pitcher decision, Schedule_View score-column probe,
   Umpire schema probe).
3. Any remaining bugs from the audit get fixed in a follow-up commit
   on `feature/astros-intangibles`.

**Do NOT assume** any May 13 fix has been validated against live data
yet. Pin re-run timing matters because the catching tracker pin
backs `get_catcher_leaderboard` (used by Cards) — old pin data could
mask the SQL fixes until refresh completes.

### Umpire schema probe — ANSWERED May 14 by Brodie

Brodie confirmed via Slack (May 14, 3:04 PM CT):
> **Source table:** `MLBAM.pbp_pregame`
> **Names caveat:** Not all umpires are in `Astros.Players`.
> **Name fallback:** He's been getting umpire names from the MLB Stats
> API: `https://statsapi.mlb.com/api/v1/jobs/umpire`

Closes one of the 6 TBDs (umpire schema probe). Implementation path is
now hybrid:
- **IDs** → `MLBAM.pbp_pregame` (schema probe SQL still needed to
  confirm exact column names — query that table on the work laptop
  before wiring up `data/umpire.py`)
- **Names** → JOIN `Astros.Players` first, fall back to MLB Stats API
  for the missing rows. Either pre-cache via a Connect-scheduled pin
  job (preferred — avoids per-page HTTP) or in-process with caching
  if the volume is low.

**Not yet wired up.** User wants to think about this alongside the
broader MLB Stats API exploration (see
[[mlb-stats-api-exploration]]) before implementing. Don't write code
until they fire /goal on it.

**v1 review opened May 10.** User flagged: empty data on Pitchers / Pitch
Calling / Scoreboard for known catchers (Collin Price, Carlos Perez 2026
AAA), no Umpire tab (KDB has it as a top-level page — we missed it at
design time), and asked for the canonical KDB source as reference.

### May 10 fixes shipped (autonomous session)

**Empty-data root cause** (`9d64a50`): All 6 AC data modules INNER JOIN'd
`Astros.Events_View` on `pv.cur_event_id` — NULL on ~75% of pitches
(PA-ending only). Switched all 11 joins to `pv.ab_event_id` (every pitch).
Same bug class as bat-speed Bug 1 in `rules/bat-speed-canonical.md`. Pena
+ Price 2026 AAA empty results were the symptom; AAX HOU + DSL likely
also affected.

**Visual format refactor** (`68b388a`, `87e868c`): Catcher Cards is now
the visual reference family across all 6 tabs. Two new shared
components in `components.py`:
- `render_player_hero(name, headshot_url, sub_text, is_hou, title_size)`
  — extracted from Cards' inline pattern. Used by Cards / Pitchers /
  Pitch Calling / Stats. One helper, future tweaks touch one place.
- `render_tbd_placeholder(label, reason, badge)` — visible
  "AWAITING SOURCE" block per the original "use OUR canon, mark blanks
  don't fake them" design directive.

5 catcher-context tabs now wrap content in `render_card("default")`
with the shared hero + section dividers + KPI tiles + TBD placeholders
where data is missing. Scoreboard kept its per-game card pattern (slate
view is intentionally a different visual family from player profiles)
but now also has a TBD for live game scores.

### TBD placeholders + status

| Tab | Section | Status May 12 |
|---|---|---|
| Cards | 7-bucket framing detail | TBD — KDB-only construct, no internal canon. Awaiting user direction (define internal 7-bucket or stay 5) |
| Cards | Pop-time hand split table | **SHIPPED `96242cb`** — 3-up grid vs RHH/LHH/SHH |
| Cards | Recent games last 5 | **SHIPPED `96242cb`** — click-through to Gameday |
| Cards | Defensive grade composite (20-80) | TBD — provisional formula, awaiting user weight lock |
| Pitchers | 5×6 approach matrix per-pitcher | TBD — Pitch Calling has aggregated; per-pitcher needs more agg |
| Stats | Hitting Stats Panel | TBD — defensive-only in v1; awaits user spec |
| Gameday detail | Receiving table by pitcher × CSC | **SHIPPED `96242cb`** — RHP + LHP sections, full bucket breakdown |
| Gameday detail | Throws panel — per-attempt | **SHIPPED `96242cb`** — per-SBA row, color-coded outcome, video link |
| Gameday detail | Blocks panel — per-pitch | **SHIPPED `96242cb`** — per-dirtball row, result category color tier |
| Gameday detail | FIP + PA outcomes summary | TBD — needs pitcher + hitter pool integration |
| Scoreboard | Live / Final game scores | TBD — Schedule_View score columns not yet probed |
| Umpire tab | Whole tab structure | **STRUCTURE SHIPPED `17c66ea`** — schema probe needed (see below) |

### May 12 2026 — 3-goal autonomous sprint shipped

Goal 1 (`96242cb`): wired 5 v1.5 sections into real implementations
reading canonical Astros helpers. New module
`src/ac_dashboard/data/cards_extras.py` for pop-hand-split + recent-games.
Gameday detail's Throws / Blocks / Receiving panels now use the
canonical postgame helpers (`get_throws_data`, `get_blocks_data`,
`compute_receiving_table`).

Goal 2: three-surface parity audit dispatched as background agent
(Salazar 2025 AAA reference). Writes report to
`intangibles/docs/plans/2026-05-12-ac-parity-audit.md`. Fix-on-AC-only,
report-elsewhere per user direction. Status: in progress at session end.

Goal 3 (`17c66ea`): 7th Umpire tab structure shipped. Full visual
chrome following Cards format. Data layer empty pending DB schema
probe — INFORMATION_SCHEMA probe SQL embedded in
`src/ac_dashboard/data/umpire.py` module docstring. Landing tile tagged
`[ STRUCTURE ]` (distinct from `[ LIVE ]`) so the gap is visible.

### Open user decisions / awaiting input

**Punchlist with full context lives at**
`intangibles/docs/plans/2026-05-14-ac-dashboard-open-questions.md`
on `feature/astros-intangibles` — structured per-question with
recommended defaults so user can answer in one pass.

Status snapshot:

1. **Defensive grade composite (Cards)** — ✅ SKIP per user May 14;
   placeholder removed
2. **Hitting stats panel (Stats)** — ✅ DEFER per user May 14;
   placeholder removed (AC stays defensive-only)
3. **5×6 approach matrix (Pitchers)** — ✅ BUILT May 14 (Phase 2C-ish);
   per-pitcher matrix on Pitchers tab via aggregate_count_matrix +
   _render_count_matrix_table reuse from tab_pitch_calling
4. **7-bucket framing (Cards)** — ✅ STAY 5-bucket per user May 14;
   placeholder removed
5. **Live/final game scores (Scoreboard)** — ✅ BUILT May 14 (Phase 2B);
   MLB Stats API /schedule?hydrate=linescore per sportId, merged onto
   ScoreboardGame.score_data, rendered in header strip with HOU-
   perspective win/loss color tint
6. **Umpire schema probe** — ✅ CLOSED May 14 via Brodie + work-laptop
   probe; Phase 2A LIVE on `fd7e041`

**ALL SIX TBDs RESOLVED.** Single follow-up commit on May 14 shipped
Phase 2B (Q5) + Phase 2C-ish (Q3) + Q1/Q2/Q4 cleanup. Pull + redeploy
intangibles Streamlit on work laptop to see the changes live.

## KDB SOURCE REFERENCE (saved May 10)

**Verbatim 983KB source** lives at:

`bsb-wt-intangibles/astros-intangibles/intangibles/docs/kdb_catching.html`

Committed `aa61fda` on `feature/astros-intangibles`. The earlier 8.6KB
stub at `docs/plans/2026-05-07-ac-kdb-source-reference.html` (which
held only a curl instruction because the full file couldn't be written
in that session) was deleted in the same commit.

To re-fetch the upstream live version: `https://kdbbeta85v2.netlify.app/`

Key gaps the source revealed (use as v2 punchlist):

- **Umpires page** (top-level tab in KDB — we never built it; user said
  "we'll worry about umpire later")
- **Models are far more sophisticated**: CSProb v8 Bayesian (1.88M
  pitches), separate Model A framing baseline that strips
  ump/park/sequence so catcher influence shows as residual, xBlock v8
  with 1001-point isotonic calibration, Swing/Whiff probability,
  RE-weighted blocking runs across 24 base-out states + dropped-3rd-
  strike, WOWY pitcher adjustment for leaderboard, ABS challenge-risk
  model for 2026
- **Pages we don't have**: Pitch Explorer (multi-catcher season-wide
  filtering), Card generator with PNG infographic export, Daily/Live
  date-range leaderboard with progress bar, Challenges page
- **Polish features**: per-pitch click-to-video via MLB Film Room
  GraphQL (mp4 with Savant iframe fallback), KDE heatmap overlays on
  Gameday, Savant stance leaderboard with knee_code grouping for
  per-stance Framing RV / Blocking RV / CSAA100, three-tier challenge
  attribution (catcher/pitcher/batter)
- **Suspected empty-data root cause**: KDB queries strictly with
  `sportId=11` for AAA. Our 2026 AAA catcher empty results probably a
  sportId / league-scope mismatch, not a real data gap. Verify before
  touching.

## 6 tabs (all built)

| Tab | Module | URL |
|---|---|---|
| Catcher Cards | `tab_catcher_cards.py` | `?view=dashboard&tab=cards` |
| Scoreboard | `tab_scoreboard.py` | `?view=dashboard&tab=scoreboard` |
| Gameday | `tab_gameday.py` | `?view=dashboard&tab=gameday` |
| Pitch Calling | `tab_pitch_calling.py` | `?view=dashboard&tab=pitch-calling` |
| Pitchers | `tab_pitchers.py` | `?view=dashboard&tab=pitchers` |
| Stats | `tab_stats.py` | `?view=dashboard&tab=stats` |

Each tab has a paired data module under `src/ac_dashboard/data/`.

## Architecture

- Foundation: `src/ac_dashboard/{styling,components,selectors,click_video,landing,__init__}.py`
- KDB visual port — Astros navy + orange overrides KDB blue + green
- Three-surface parity preserved: every metric flows through canonical
  paths (catcher_data, catching_tracker_data) — so values match
  ?view=tracker cell-for-cell
- 7-bucket framing palette LOCKED in styling.py (matches postgame, tracker, KPI)
- Design docs: `intangibles/docs/plans/2026-05-07-ac-tab-*.md` (one per tab)

## Key build commits (in order)

| Commit | What |
|---|---|
| `b8a6348` | Foundation + landing scaffold |
| `221ac51` | Catcher Cards tab (first live tab) |
| `3f8b3cc` | All 5 remaining tabs in one shot |
| `6813c3b` | CommonMark code-block trap fix (made everything actually render) |

## Known v1 deferrals (documented in tab files)

- **Gameday**: Receiving table by pitcher × bucket, full Throws/Blocks
  panels, FIP + PA outcomes (require postgame helper extraction from
  `4_Catching.py::_render_postgame()`)
- **Pitchers**: 5×6 approach matrix from KDB Screenshot 191124 (count
  state × pitch type) — partial via Pitch Calling's matrix
- **Scoreboard**: scores not displayed (Schedule_View score column
  names not in our rules — would need INFORMATION_SCHEMA probe)
- **Stats**: only defensive stats; hitting stats panel from KDB spec
  not implemented

## CommonMark code-block trap (BLOCKING — documented Why future sessions matter)

`ac_html()` helper in `components.py` strips leading whitespace from
every line of multi-line HTML blocks. Without it, Streamlit's
CommonMark parser sees 4+ space indents as code blocks and renders the
entire HTML as `<pre>` text. Same trap documented in
`.claude/rules/org-board.md` §"CommonMark code-block trap".

**Rule for future AC tab work:** every `st.markdown(f''' ... ''',
unsafe_allow_html=True)` with multi-line indented content MUST wrap the
HTML in `ac_html(...)`. Single-line strings and `<style>` content are
fine.

## Rendering quirks the user might still bring up

- "← BACK TO DASHBOARD" link sometimes renders as default underlined
  blue instead of orange — Streamlit stylesheet load order issue. Fix
  if asked: add `!important` to `.ac-back-link` rules in styling.py or
  scope more specifically.
- Page-level "← BACK" (huge orange, from `pages/4_Catching.py`) is
  separate from AC's own back link — that's intended.
