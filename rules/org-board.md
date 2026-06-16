# Org Dash + Transition Reports — Architecture (BLOCKING)

LIVE on `feature/pd-goals` since May 6 2026. Two new pages on PD Engine
that surface the entire HOU org roster as a kanban board with player
drill-downs and per-team views. EBIS / PP_MASTER is the source of truth;
TR_HISTORY decorates with historical context.

Pairs with `pd-goals.md` (PD Engine app family), `kpi-roster-filter.md`
(canonical PP_MASTER filter), `in-app-submission.md` (Transition Report
pattern that this hands off to).

---

## Files (BLOCKING — keep in sync as a unit)

| Role | File |
|---|---|
| Org Board page | `pd-goals/pages/5_Org_Board.py` (~1300 lines) |
| Team View page | `pd-goals/pages/6_Team_View.py` (~1200 lines) |
| Transactions data layer | `pd-goals/src/transactions_data.py` (~360 lines) |
| Landing nav card | `pd-goals/PD_Engine.py` (4th card "ORG BOARD") |
| Manifest | `pd-goals/manifest.json` registers both pages + transactions_data |
| Design doc | `docs/plans/2026-05-06-org-dash-design.md` |
| Research doc | `docs/plans/2026-05-06-org-dash-design-research.md` |
| Discovery SQL | `sql-queries/tr-history-discovery.sql` |

When changing ANY metric / data path / layout invariant, update ALL
affected files in one commit. The two pages duplicate the drawer
chrome (intentional — see "Why duplicate the drawer" below).

---

## Layout (locked May 7 2026 v2)

### Top row (6 columns, ascending toward MLB)
```
┌──────┬──────┬──────┬──────┬──────┬──────┐
│ FCL  │  A   │  A+  │  AA  │  AAA │ MLB  │   ← TOP_ROW_LEVELS
│  r   │  1f  │  1a  │  2a  │  3a  │  ml  │     ["r","1f","1a","2a","3a","ml"]
└──────┴──────┴──────┴──────┴──────┴──────┘
```

### Bottom row (3+3 split, aligned with top via `repeat(6, 1fr)` grid)
```
┌──────────────────────────┬────────────────────────┐
│  DSL  (BOTTOM_LEVEL "ds")│  IL / DFA              │
│  3-cards-per-row grid    │  3-cards-per-row grid  │
└──────────────────────────┴────────────────────────┘
```

### Above the grid (May 7 2026)
- **Recent Moves horizontal timeline** — 7-day window, dots positioned
  by date, color-coded by 5-bucket category, hover for custom CSS
  tooltip card, click → drawer. Day-of-week ticks below.

### Right rail (always visible >1280px)
- Total Roster · Showing · On IL/DFA · By Level breakdown · footer
- **Recent Moves was REMOVED from the rail May 7 2026** — moved to
  horizontal timeline above the grid

---

## Roster sources — TWO queries, EBIS is canonical

| Need | Source | Notes |
|---|---|---|
| Active HOU players | `src.roster.get_roster()` (Alvaro pattern) | Returns 230+ ACT/OPT/OUTRT players. EXCLUDES IL statuses. |
| IL/DFA players | `_load_il_sus_roster()` (local SQL in 5_Org_Board.py) | Mirrors get_roster shape but INCLUDES IL/REHAB/DFA statuses. |

**BLOCKING — IL DEDUPE INVARIANT:**
After loading both, build `il_gc_ids = set(il_roster_full["groundcontrol_id"])`
and EXCLUDE those gc_ids from `roster_full`. IL players appear ONLY in
the IL column, never duplicated in their nominal level column. Bug
shipped May 6, fixed same day. Don't reintroduce.

**BLOCKING — DRAWER LOOKUP MUST CHECK BOTH ROSTERS:**
When `?drawer=GC_ID` is set, lookup MUST fall through both rosters:
```python
match = roster_full[roster_full["groundcontrol_id"] == drawer_gc_id]
if match.empty and not il_roster_full.empty:
    match = il_roster_full[il_roster_full["groundcontrol_id"] == drawer_gc_id]
```
The Phase-2 dedupe excluded IL gc_ids from roster_full → if drawer
only checks roster_full, every IL/REHAB/DFA card opens an empty
drawer. Bug shipped May 7, fixed same day.

---

## IL/DFA detection (BLOCKING)

PP_MASTER `MNROSTERSTATUS_LK` / `MJROSTERSTATUS_LK` codes empirically
identified May 6 2026 from HOU distinct-status query:

| Bucket | Codes | Label rendered |
|---|---|---|
| Injury — short-term | `7DL`, `DL`, `10D`, `15D` | `IL` (yellow) |
| Injury — long-term | `60D`, `FSIL` | `IL-60` (red) |
| Rehab | `7RH`, `15R`, `60R` | `REHAB` (navy) |
| Designated for assignment | `DFA` | `DFA` (orange) |

**Excluded:** `RES` (paternity/bereavement — too noisy), `VOL` (historical
voluntary-retired bloat — already excluded by get_roster), `DIS`
(suspended — user direction May 6 2026 — show suspended players nowhere).

`_classify_il_status(mn, mj)` uses pd.isna-safe `_safe_str` helper
because `pd.NA` is truthy in `or` chains and `(NaN or "").strip()`
crashes (pitfalls.md trap).

---

## CLUB_LK → level_code mapping (BLOCKING)

TR_HISTORY's `*_CLUB_LK` columns are NUMERIC IDs, not level codes.
Resolution requires lookup.

### LEVEL_CLUB_MAP (HOU canonical — empirically identified May 6 2026)

```python
LEVEL_CLUB_MAP = {
    1297:     "ml",   # MLB Houston
    68593:    "3a",   # AAA Sugar Land Space Cowboys
    598:      "2a",   # AA Corpus Christi Hooks
    649:      "1a",   # A+ Asheville Tourists
    620:      "1f",   # A — historical Salem (BOS A+ now), some HOU acquisitions still tagged here
    729:      "1f",   # A Fayetteville Woodpeckers
    836:      "r",    # FCL Astros
    599:      "ds",   # DSL Astros Blue (primary)
    10000055: "ds",   # DSL Astros Orange (secondary)
}
```

### Global lookup — `MLB_eBis.GBL_CLUB_LKUP` (May 7 2026 fix)

LEVEL_CLUB_MAP only covers HOU's 9 clubs. Trades / waiver claims /
amateur signings reference clubs from other orgs (e.g. SF Giants AAA
= 235). Without a fallback those resolve to "—" in level history.

`load_global_club_map()` queries `MLB_eBis.GBL_CLUB_LKUP WHERE
ACTIVE_FLG = 1` and returns `{club_id: level_code}` for ALL active
clubs across ALL orgs. Resolution order in level history:
```python
pre_lvl = LEVEL_CLUB_MAP.get(pid) or global_map.get(pid)
```

LEVEL_CLUB_MAP wins (faster, HOU-canonical). Global map fills the
gaps for cross-org transactions. The `<a href>` then uses this
resolved level for the From → To pill display.

---

## TR_HISTORY data path (BLOCKING)

Source: `MLB_eBis.TR_HISTORY` joined to `MLB_eBis.TR_NAME_LKUP` for
human-readable transaction name + category.

### Schema (verified May 6 2026)

| Column | Format | Notes |
|---|---|---|
| `PLAYER_ID` | 8-digit int | Joins to `Astros.Players.ebis_id` (NOT groundcontrol_id directly) |
| `TRANSACTIONNAME_LK` | varchar(5) | Joins to `TR_NAME_LKUP.transactionname_lk` |
| `*_CLUB_LK` | int | Numeric club ID — see CLUB_LK mapping above |
| `*_ORG_LK` | varchar(3) | UPPERCASE 'HOU', 'SF', etc. |
| `*_MN/MJROSTERSTATUS_LK` | varchar | Status before/after — drives IL/active inference |
| `TRANSACTION_DTSTMP` | datetime | The display date |

### TR_NAME_LKUP categories (drives badge color)

| Category | Codes (sample) | Bucket |
|---|---|---|
| `Injury - IL Placement` | DL07J, DL10J, DL15J, DL60J, PILMJ, PILMN, PFSMN, PL15L | IL (yellow) |
| `Injury - IL Transfer` | TR07N, TR10J, TR15J, TR60J, TFSMN, TILMJ, TILMN | IL (yellow) |
| `Injury` | REINS, RECRT, REHAB, RHBRT | Other (navy) |
| `Roster Removal` | URREL, UNCRL, RELES, FAOTH, ELFA, FAXAC, RETIR | Demote (grey) |
| NULL category | RECOP, OPTAS, MJSEL, SGNFA, SGNMN, TRANS, RESTR, ... | Bucketed by code |

### `show_by_default = 1` filter

ALL TR_HISTORY queries filter `ISNULL(lk.show_by_default, 1) = 1` to
skip noise (ASGEE/MXFRM/R5SEL/OFFSA etc.). Don't remove this filter
unless you want signing-housekeeping in the timeline.

---

## Cached helpers (TTL 6h matches roster cache)

| Helper | Purpose |
|---|---|
| `load_last_txn_dates()` | Per-HOU-player MAX(txn_date) — drives card "moved 4d ago" |
| `load_recent_transactions(days=7)` | Last-N-day HOU transactions (filtered by show_by_default=1) — drives the horizontal timeline strip |
| `load_player_transactions(gc_id)` | Full chronological history for one player — drives drawer Level History section |
| `load_team_transactions(level_code, year)` | All transactions touching the given affiliate level (resolved via CLUB_IDS_BY_LEVEL) — drives Team View timeline |
| `load_global_club_map()` | `{club_id: level_code}` for all active clubs across all orgs — fixes cross-org level resolution |

`@st.cache_data(ttl=21600)` on every query. EBIS doesn't shift hourly.

---

## Headshots — modern mlbstatic CDN (locally overridden)

Alvaro's `roster.py::get_player_photo_url` returns the legacy
`securea.mlb.com/.../head_shot/{id}.jpg` for MLB + non-ACT players.
That CDN doesn't host Spring Training shots and 404s for many
recent players (Wagner reported May 7 2026).

**Local override** (`_modern_photo_url` in BOTH `5_Org_Board.py` and
`6_Team_View.py`) — always uses mlbstatic CDN:

```python
if level_code == "ml":
    # Silo path with Cloudinary placeholder fallback baked in
    return f"https://img.mlbstatic.com/mlb-photos/image/upload/d_people:generic:headshot:silo:current.png/w_180,q_auto:best/v1/people/{mid}/headshot/silo/current"
return f"https://img.mlbstatic.com/mlb-photos/image/upload/c_fill,g_auto/w_180/v1/people/{mid}/headshot/milb/current"
```

The `d_people:` prefix is Cloudinary syntax — if the player's photo
doesn't exist, returns the silo silhouette placeholder (still color,
looks decent). Card's `onerror="this.style.display='none'"` is the
secondary fallback if even that 404s.

Does NOT modify `src/roster.py` — keeps PD Goals / Postgame /
Transitions on Alvaro's original logic. Override is local-page-only.

---

## CommonMark code-block trap (BLOCKING — `_compact_html`)

`st.markdown(html, unsafe_allow_html=True)` runs input through
CommonMark FIRST. **Any line starting with 4+ leading spaces is
interpreted as an indented code block** and the entire layout
renders as raw `<pre>` text instead of HTML.

Our nicely-indented f-string templates trigger this. Fix:
```python
def _compact_html(s: str) -> str:
    return "\n".join(line.lstrip() for line in s.split("\n"))
```

EVERY `st.markdown(html, unsafe_allow_html=True)` call wraps the
HTML in `_compact_html()`. CSS blocks don't need it (the `<style>`
tag content isn't markdown-processed). Bug shipped May 6, caught
within an hour by the user testing. Don't reintroduce.

---

## NaN safety (per pitfalls.md)

`pd.NA` / `NaN` are TRUTHY in `or` chains because any non-zero float
is truthy. So `(mn or "").strip()` calls `.strip()` on a float and
crashes. Same for `int(NaN)` raising ValueError.

Three NaN-safe helpers in 5_Org_Board.py:
- `_safe_gc_id(row)` — returns None on NaN gc_id, callers skip-and-continue
- `_classify_il_status(mn, mj)` — uses explicit `pd.isna()` check
- `_safe_str(v)` (inside _classify_il_status) — returns "" on NaN

---

## Card expansion — current architecture (May 8 2026)

Cards in both Org Board and Team View are native HTML
`<details>`/`<summary>` elements. Click summary → expands inline below
the card. No URL change, no Streamlit rerun, no white flash.

**Body content (both pages):**
1. 7-row vitals grid (position group, roster status, B/T, age, MLBAM
   ID, eBis ID, GC ID) — rendered server-side, instant on expand.
2. Level History — lazy-loaded via JS from a JSON blob (Option B,
   below). Up to 10 most-recent transactions with colored category dot,
   short label, full date, italic full name, From → To pill.
3. Three CTAs: **File Transition** (primary, navy/orange) / **PD
   Goals** (secondary) / **More ↗** (links to drawer for Recent
   Transition Reports).

**Option B — JSON blob + JS lazy-render (current shipped path):**

1. main() runs `load_all_player_transactions(gc_ids)` — single batched
   SQL query keyed on every roster gc_id. Cached 6h via
   `@st.cache_data`.
2. `build_history_html_map(all_txns, level_display, max_rows=10,
   css_prefix=...)` in `transactions_data.py` pre-renders each player's
   history as an HTML string. Returns `{gc_id_str: html_string}`.
   Server-side rendering happens ONCE per player into a string instead
   of 250 hidden DOM trees.
3. Each card body contains an empty placeholder:
   `<div class="..._lh-list" data-lazy-history="{gc_id}">
   <div class="..._pending">Loading…</div></div>`
4. At page bottom, the full map ships as a JSON blob inside a
   `<script>` tag plus a capture-phase `toggle` event listener that
   targets `window.parent.document`. When a `<details>` opens, the
   listener finds the matching placeholder via `data-lazy-history`
   and replaces innerHTML with the corresponding HTML string.
5. **BLOCKING — script injection MUST use `st.components.v1.html`,
   NEVER `st.markdown(unsafe_allow_html=True)`.** Streamlit's
   `st.markdown` strips `<script>` tags as a security default; the
   listener never reaches the DOM and every card opens to "Loading…"
   forever. `st.components.v1.html(html, height=0)` is designed to
   execute JS — it runs in an iframe, so reach the parent-frame DOM
   via `window.parent.document` for the listener and stash the data
   blob on `window.parent.__OB_HIST` / `__TV_HIST` for cross-rerun
   persistence. Fixed May 8 2026 commit `12e6194`.
6. **Capture-phase listener is required** because `<details>` `toggle`
   event does NOT bubble. `parentDoc.addEventListener('toggle', fn,
   true)` (third arg = `true`).
7. **XSS guards:** transaction names, level codes, dates are
   `html.escape()`'d before being baked into the HTML strings. JSON
   blob escapes `</` → `<\/` to prevent `</script>` tag breakout.
8. **Dedupe on Streamlit rerun:** `window.parent.__OB_HIST_HANDLER_ATTACHED`
   / `__TV_HIST_HANDLER_ATTACHED` flags prevent re-binding the listener
   on every rerun. Data blob refreshes each rerun. Flags live on the
   PARENT window so they survive even though each rerun creates a new
   iframe instance.

CSS prefix differs per page — `ob-card-lh` (Org Board), `tv-cardbody`
(Team View) — so each page can style independently. Same JS pattern,
different `window.__*_HIST` namespaces.

**Drawer (overlay sidebar) still exists** at `?drawer=GC_ID` URL param.
Accessible via:
- "More ↗" CTA on each card (Org Board + Team View)
- Direct URL navigation

Drawer hosts the **Recent Transition Reports** section (per-player pin
read from `transition_reports`) that isn't in the inline body. Click
to drawer = one-time white flash, accepted because it's a rare action.

## Known issues / Future work (May 8 2026)

Stopping here because the app is in a usable "chill" state. These are
polish items for a future session, not blockers. Each is independent
and can be done in any order.

| # | Issue | Symptom | Likely cause | Fix path |
|---|---|---|---|---|
| 1 | White flash on drawer "More ↗" | Click "More ↗" CTA → page goes white briefly → drawer slides in from right | `<a href="?drawer=GC_ID">` causes Streamlit rerun = full DOM rebuild = browser white flash. Same root cause as the original drawer-click flash that Option A/B was meant to solve, just relocated to a less-frequent button. User explicitly de-prioritized May 8 2026 ("isn't really a big deal"). | Move Recent Transition Reports section into the inline-expand body as a 4th block (eliminates the drawer entirely). Requires another batched pin read on cold load. Alternative: investigate `st.dialog()` for modal-style transition reports view. |

**RESOLVED** — Lazy-render history not firing on click. Was issue #1
in the original list. Root cause: Streamlit's
`st.markdown(unsafe_allow_html=True)` strips `<script>` tags. Fixed
May 8 2026 commit `12e6194` by switching to
`st.components.v1.html(height=0)` + parent-frame DOM access.

**RESOLVED** — PD Goals CTA generic. Was issue #3 in the original
list. Fixed May 8 2026 commit `03d19ea` by adding
`_apply_query_param_prefill(roster_df)` at the top of
`pages/1_PD_Goals.py`. Reads `?player=<gc_id>`, looks up the player
in `roster_df`, sets `level_select` + `player_select` session_state
BEFORE the sidebar widgets render (Streamlit forbids mutating
widget-key state after widget instantiation). Mirrors the
`_apply_query_param_prefill` deferred-load pattern in
`pages/2_Transition.py`. Silent no-op if param malformed or player
not in active roster (IL / released).

---

## Why duplicate the drawer between 5_Org_Board.py and 6_Team_View.py

Both pages render a player drawer. The HTML/CSS chrome is duplicated
(~300 lines of CSS) instead of extracted to a shared module.

**Reason:** drawer state is page-specific — Org Board's close link is
`?` (clears all params), Team View's close link is `?team=X` (preserves
the team param). Cross-page sharing forced awkward parameterization.
~300 lines of CSS duplication is the price of clean independent pages.

If a third surface ever needs the drawer, refactor to `src/org_drawer.py`
at that point.

---

## What NOT to do (BLOCKING)

- Don't write to PP_MASTER. EBIS owns that. We read only.
- Don't add new players based on TR_HISTORY transactions. PP_MASTER is
  the source of truth for who is HOU. TR_HISTORY only decorates.
- Don't include `RES`, `VOL`, or `DIS` in the IL/DFA column. User
  explicit direction May 6 2026.
- Don't drop the `IL DEDUPE INVARIANT` from main(). Pena/Zeglin
  duplicating bug returns immediately.
- Don't drop the `DRAWER LOOKUP DUAL CHECK`. Every IL card silently
  opens empty drawer.
- Don't write inline f-string HTML without `_compact_html()` wrap.
  Layout renders as code block. Caught within an hour but burns user
  trust.
- Don't add the SUS column back without explicit user direction.
- Don't push to `main` for testing. CLAUDE.md blocking rule #10.
- Don't change `src/roster.py` to fix Org Board headshots. That helper
  is shared with PD Goals / Postgame / Transitions / Transitions_View.
  Override locally with `_modern_photo_url`.
- Don't change `MILB_LEVEL_ORDER` — it's renamed to `TOP_ROW_LEVELS`
  (May 7 2026 layout v2). Old name was removed; lingering references
  would NameError.
- Don't put MLB on top of the grid. User direction May 7 2026: MLB
  rightmost on top row (destination), DSL bottom-left, IL bottom-right.
- **Don't inject `<script>` via `st.markdown(unsafe_allow_html=True)`.**
  Streamlit strips `<script>` tags as a security default — the script
  is silently removed and never executes. Use
  `st.components.v1.html(html, height=0)` for any JS payload, then
  reach the parent-frame DOM via `window.parent.document` because the
  component runs in a sandboxed iframe. Stash any state that must
  survive Streamlit reruns on `window.parent` (e.g.
  `window.parent.__OB_HIST`), since each rerun creates a fresh iframe
  but the parent window persists. May 8 2026 lazy-render fix.
- **Don't render the Team View level header before `team_roster` is
  finalized.** The header includes avg age (`Age: __._`) computed from
  `team_roster["age"].mean()`, truncated to one decimal (per
  `feedback_age_formatting.md` — never round up). If the header
  renders before the roster loads, age is unavailable. Trade-off: the
  empty-roster early-return paths render their error message without
  a level header — acceptable, the error is self-explanatory.

---

## Bug history

- **May 6 2026** — Initial Phase 1 ship (`2dc3e0b`). Tiered kanban,
  static read-only, EBIS-driven.
- **May 6 2026** — Phase 2 drawer (`107625e`). Slide-in via query param.
- **May 6 2026** — Phase 3 (`47d81a8`). Transition CTA pre-fills.
  Added `_apply_query_param_prefill` to `2_Transition.py`.
- **May 6 2026** — Phase 4 (`da78c0d`). Team View page + transactions
  timeline stub.
- **May 6 2026** — CRITICAL bug: HTML rendering as code block (`7f57251`).
  Added `_compact_html`. Plus NaN-safe gc_id + classify_il + txn date.
- **May 6 2026** — Phase 5 (`15ac5e9`). Full TR_HISTORY wiring across
  4 surfaces.
- **May 6 2026** — User feedback batch (`3edaba8`). Drop SUS, dedupe IL
  players, 3+3 bottom split, remove Refresh button, fix Back to PD
  Engine, first-initial naming.
- **May 6 2026** — IL section grid 3-wide (`144dc94`).
- **May 7 2026** — Modern mlbstatic headshots (`1eac7d3`).
- **May 7 2026** — Layout v2: MLB top-right, DSL+IL bottom, horizontal
  timeline strip (`56fa08d`). Plus stale-reference NameError fix
  (`bc4af67`).
- **May 7 2026** — DSL grid + MLB silo headshots + 30d→7d timeline
  with same-day stacking + custom CSS tooltip (`f7ff4f8`, `e6bd4d2`).
- **May 7 2026** — Timeline first-initial in tooltip + TOP 25→300 in
  recent transactions query (`3f5078f`).
- **May 7 2026** — IL drawer dual-roster lookup fix (`b387451`).
- **May 7 2026** — Level History dashes fix via global club map
  (`load_global_club_map()` from GBL_CLUB_LKUP).
- **May 8 2026** — Timeline today-at-right-edge + 4-high stack with
  column overflow (`3c20fc0`). Window anchored to midnight boundaries
  (was `now - 7d`). 7 ticks evenly spaced, today at pct=100%. Same-day
  moves now overflow into columns of 4 instead of stacking invisibly.
- **May 8 2026** — Option A step 1: convert grid cards to
  `<details>`/`<summary>` inline expand (`e99b43b`). Body included
  vitals + level history + CTAs.
- **May 8 2026** — Option A step 2 (Team View) + drop bottom timeline
  (`9a39b6f`). Same `<details>` pattern; `_timeline_real_html` no
  longer called from main() but function definition kept for revert.
- **May 8 2026** — Cold-load slowness reported (~5s vs. previous
  ~1s). Root cause: 250 cards each pre-rendering ~2.5KB body HTML at
  page generation time = ~600KB Python rendering + DOM cost.
- **May 8 2026** — TOP-8 cap on batched txns query (`9a39b6f`)
  reverted (`aa8cbe2`). User-confirmed: query was not the bottleneck;
  Python body rendering was.
- **May 8 2026** — Option A trial: slim inline body to vitals + CTAs,
  level history moved behind "View History" CTA → drawer (`2d55025`).
  Cold load fast; user disliked needing extra click for history.
- **May 8 2026** — **Option B shipped** (`81816e8`). JSON blob + JS
  lazy-render. Body includes empty placeholder for history; pre-
  rendered HTML strings ship as JSON; capture-phase `toggle` listener
  populates each placeholder on first expand. New helper
  `transactions_data.build_history_html_map()`. Cold load ~2-3s, no
  flash on card expand. KNOWN at ship: lazy-render JS may not fire on
  click in deployed Streamlit (suspected `<script>` stripping).
- **May 8 2026** — **Lazy-render fix shipped** (`12e6194`). Confirmed
  the suspected cause: `st.markdown(unsafe_allow_html=True)` strips
  `<script>` tags as a security default, so the JSON blob + capture-
  phase `toggle` listener were both silently removed before they
  reached the DOM. Every card opened to "Loading…" indefinitely
  because there was no handler to populate the placeholder. Fix:
  switched both `5_Org_Board.py` and `6_Team_View.py` to inject the
  script via `st.components.v1.html(height=0)`, which is designed
  to execute JS. The component runs in an iframe, so the listener
  attaches to `window.parent.document` (cards live in the parent
  frame) and the data blob lives on `window.parent.__OB_HIST` /
  `__TV_HIST` for cross-rerun persistence. History now populates
  within a frame of expand. Cold load unchanged.
- **May 8 2026** — **Avg age in Team View header** (`3966f4c`).
  `Age: __._` rendered inline-right of the affiliate name in
  `tv-header__title`. Computed from `team_roster["age"].mean()`,
  truncated to one decimal (`int(mean * 10) / 10.0` — never round up,
  per `feedback_age_formatting.md`). Header rendering moved past the
  roster load so `team_roster` is available. Empty-roster early
  returns now show the error message without the header — acceptable
  trade-off; the error is self-explanatory.
- **May 8 2026** — **Avg age in Org Board column headers** (`5dadb82`).
  Initial commit (above) put the age in Team View only — wrong place;
  user clarified they meant the Org Board level columns. New helper
  `_avg_age_suffix(df)` in `5_Org_Board.py` returns `" · Age: 22.3"`
  suffix, appended to the sub-line of all three column-header
  rendering paths: `_column_html` (FCL / A / A+ / AA / AAA top row +
  DSL bottom-left), `_il_column_html` (IL / DFA bottom-right), and
  `_mlb_row_html` (Houston row).
- **May 8 2026** — **PD Goals CTA prefill** (`03d19ea`). Closes the
  last open Known Issue from this list. New
  `_apply_query_param_prefill(roster_df)` in `pages/1_PD_Goals.py`
  reads `?player=<gc_id>` from the URL, looks the player up in
  `roster_df`, and sets `level_select` + `player_select` session_state
  BEFORE the sidebar widgets render. Mirrors the deferred-load
  pattern in `pages/2_Transition.py::_apply_query_param_prefill`.
  Marked-handled flag (`_pdg_query_prefill_handled`) prevents
  re-firing on reruns; param cleared after first hydrate. Silent
  no-op for malformed param or for IL / released players who aren't
  in the active roster — coordinator lands on default selection
  rather than crashing. Player search box is reset to empty so the
  prefilled label is guaranteed to be in `filtered_options`.

---

## Cross-references

- `pd-goals.md` — PD Engine app family. Org Dash is Card 4 on the landing.
- `kpi-roster-filter.md` — canonical PP_MASTER active-roster filter
  (Alvaro pattern). `_load_il_sus_roster` inverts that filter for IL.
- `in-app-submission.md` — Transition Report pattern. Drawer's "File
  Transition" CTA hands off to Transition page via query params.
- `pitfalls.md` — `int(NaN)` + `pd.NA truthy` gotchas the NaN-safe
  helpers protect against.
- `db-columns.md` — PP_MASTER column reference, level code mapping.
- `tracker-parquet-pins.md` — pin pattern (NOT used here; PP_MASTER
  query is fast enough at 6h cache).
- `docs/plans/2026-05-06-org-dash-design.md` — full validated design.
- `docs/plans/2026-05-06-org-dash-design-research.md` — inspiration scout.
- `sql-queries/tr-history-discovery.sql` — backend discovery template
  with results captured inline.
