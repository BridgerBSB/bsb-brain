---
name: unified-pd-hub-vision
description: "Future vision + plan to merge all 4 PD apps into one Baseball-Savant-style hub; nav model, architecture decision, and what's already built."
metadata: 
  node_type: memory
  type: project
  originSessionId: cdcf4026-70bc-429c-bb18-bcb9b7478efd
---

**FUTURE project (NOT shipping now — user explicit 2026-06-12).** Merge the 4
Streamlit apps (PD Goals/PD Engine, Arm Farm, Barrelsville, Intangibles) into
ONE "Baseball Savant for Astros PD" hub that lives in **pd-goals / PD Engine**
(app GUID `79f52369-…`, `feature/pd-goals`).

**Formal plan:** `pd-goals/docs/plans/2026-06-12-unified-pd-hub-design.md`.

## Key facts discovered (ground truth)
- **~60% already built.** `pd-goals/pages/8_Player_Card.py` is a working
  Savant-style cross-domain player page that reads ALL 4 apps' tracker pins
  off the shared `zbridger/*` Connect board (hero, radar, percentile bars,
  cohort). Pages 9–13 (`Pitch_Arsenal`, `Hitter_Approach`, `Cohort_Explorer`,
  `Compare`, `Org_Pulse`) also scaffolded — NOT YET inventoried (real vs stub).
- **No dependency conflict.** All 4 `requirements.txt` already pinned to the
  same window (streamlit<1.50, pandas<3, numpy<2, plotly/matplotlib/plottable/
  pins/scipy/aggrid). Only Intangibles adds duckdb+pyarrow. So a code merge is
  NOT blocked by deps (the "merge is risky" worry is weak).
- Pins refresh every 6h on Connect → pin-backed synthesis pages cold-load <2s.

## Architecture decision — SINGLE APP, everything in-app (user FIRM Jun 13)
User direction (verbatim intent): "we need the apps and data to all be in this
app... so the sub-tabs can be selected at any time to shift to whatever app we
are looking for." → **Option B (single-shell) IS the target, NOT deep-links.**
- ONE Streamlit deploy = Astros PD Engine. ALL 4 apps' render code lives in it;
  ALL pins read in-process. Clicking a tab/sub-tab swaps the view IN-PLACE (no
  jumping to a separate deploy, no reload). The mockup already demonstrates this
  (tabs switch in-place, zero deep-links).
- Feasible because: (1) all 4 `requirements.txt` already share one dep window
  (streamlit<1.50/pandas<3/numpy<2/plotly/plottable/pins/scipy/aggrid; only
  Intangibles adds duckdb+pyarrow) → no merge conflict; (2) all 4 already read
  the same `zbridger/*` Connect pin board → "all data in the app" = the one app
  reads all pins (pin FILES stay on Connect, NOT committed to git).
- Architecture: ONE entrypoint + a custom TOP-tab + sub-tab router (st.tabs or
  CSS bar + session_state), NOT Streamlit's sidebar `pages/`. Router dispatches
  to each domain's existing render fn; shared context bar feeds them player/
  level/season. Visuals reused unchanged — hub is a nav shell.
- Structural implication: the 4 domains CONVERGE into ONE Connect content
  (apps/pd-engine grows into the whole app); arm-farm/barrelsville/intangibles
  folders become libraries pd-engine imports from (or consolidate under it).
  Teammates' OTHER apps can still deploy independently — monorepo supports both.
- Deep-link (`?player=`/Option A) was a stepping-stone idea; SUPERSEDED. Migrate
  app-by-app still, but the destination is one app. Keep the shared context bar
  a reusable module so the tab shell wraps it without a rewrite.

## NAME = **Astros PD Engine** (NOT "PD Hub" — user correction 2026-06-13)
The encompassing app extends the existing PD Engine. apps/pd-engine grows INTO
the full hub (it already holds the Org section). All repo/mockup refs renamed.

## EXACT nav spec (user direction 2026-06-13) — supersedes the generic list below
**Landing page = Org Board.** Top-bar tabs, each with sub-tabs/dropdowns:
- **Org** (default tab on load): **Org Board** (default sub-tab) · Goals · Transitions · Win Prob
- **Barrelsville** (hitting): Affiliate Tracker · Advance · Postgame *(→ future "Player Dash")* · Blast Motion *(standalone for now; maybe folds into Player Dash later)* · KPI Report
- **Arm Farm** (pitching): Affiliate Tracker · Advance · Postgame *(→ future Player Dash)* · Side Reports *(maybe folds into Player Dash later)* · KPI
- **Baserunning**: Affiliate Tracker · Gamelog · KPI
- **Infield**: Affiliate Tracker · Advance · Individual · Gamelog · KPI · PAA Review Log
- **Outfield**: Affiliate Tracker · Advance · Individual · Gamelog · KPI *(no PAA Review Log)*
- **Catching**: Affiliate Tracker · Gamelog *(→ future Player Dash)* · KPI · **Catcher Dash BETA** *(unfinished — jumping the gun; ~7-8 open design questions parked for a future date)*

Notes: **Intangibles app EXPANDS into 4 separate top-bar tabs** (Baserunning, Infield, Outfield, Catching). "Player Dash" = future per-domain convergence of Postgame/Side Reports/Gamelog. Each sub-tab renders the SAME existing page/visual from today's apps — the hub is a nav shell, the charts are reused as-is.

## FUTURE nav model (the principles behind the spec above)
- Top-level = **tabs per domain** (per the exact spec above), replacing the
  Streamlit left-sidebar page nav.
- Each tab has **sub-tabs** = that domain's features.
- **Global sidebar retired** as nav. Only deep subpages keep a sidebar, and
  only for their own filters — and even that gets a UX rethink.
- **Two-tier filters (viewer-first):**
  - SHARED context (player, level/team, season) → persistent TOP context bar,
    picked ONCE, inherited by every tab. (Same hoist pattern as
    `tracker-trends-perf-plan.md`, one level up.)
  - LOCAL filters (date range, pitch type, HA/hand, count) → inline strip atop
    the subpage content (preferred over a sidebar, which competes with the tab
    bar for "where do I navigate" attention).
- Principle: one subject, many lenses. Nav up top, controls near content, data
  fills the page. Progressive disclosure (pin summary first, live-SQL report
  one click deeper).

## BUILD STATUS — encompassing shell + all apps copied in (Jun 13 2026)
SHIPPED to `Baseball-Operations/player-development` (`apps/pd-engine`):
- **`Astros_PD_Engine.py`** — ADDITIVE entrypoint (current `PD_Engine.py`
  untouched). Top-tab + sub-tab router (session_state, one active view/rerun).
  Exact spec wired. `_mount(rel_path)` runs each existing page UNCHANGED via
  `runpy.run_path`, neutralizes child `set_page_config`, and is DOMAIN-AWARE:
  inserts the page's domain root on sys.path + evicts `src*` from sys.modules
  so each app's `from src.X` resolves to ITS OWN src/ (root = page.parent.parent).
- **`domains/{arm_farm,barrelsville,intangibles}/`** = each app's runtime code
  (src/ pages/ assets/ requirements/ entrypoint) COPIED VERBATIM. Excluded
  docs/ scripts/ connect_pins/ (not runtime + leak surface). 185 files.
- Org tab → real pages (5_Org_Board/1_PD_Goals/3_Transitions_View/4_WPA_Plays).
- Barrelsville + Arm Farm: all 5 sub-tabs wired to real pages.
- Intangibles: ONE page per domain → mounted under each domain's FIRST sub-tab
  (Affiliate Tracker); finer sub-tabs (Gamelog/Individual/KPI/PAA Review) are
  placeholders — intangibles' sub-views are tabs INSIDE its domain page today,
  need splitting out later.
- `requirements.txt` unioned domain deps (scipy/seaborn/streamlit-aggrid/
  duckdb/pyarrow). Colleague names scrubbed from all copied code (11 files).
- Commits on `main`: shell, then domains+wiring. History clean (only Zac's email).

### ⚠️ UNTESTED — needs WORK LAPTOP (no Streamlit/DB on personal laptop)
`streamlit run apps/pd-engine/Astros_PD_Engine.py` on work laptop. Verify:
(1) top tabs + sub-tabs switch; (2) each domain's real page renders (the
src-evict/path-insert mount actually resolves each app's imports); (3) assets/
headshots load; (4) no double set_page_config error. RISK POINTS: the
sys.modules `src` eviction is the fragile part — if a domain caches state across
reruns or imports beyond `src`, may need per-domain namespacing (rename src →
<domain>_src + rewrite imports) as the robust fallback. Additive entrypoint =
nothing in production breaks while testing; switch Connect entrypoint only after
it's proven.

## Status / next when resumed
- No code yet. Phase 0 = read pages 9–13 to inventory real vs stub; lock the
  deep-link param contract (`player`/`level`/`season`/`view`).
- Open decisions still unanswered by user: search-first vs equal billing; hub
  visual language (clean Savant vs retro-arcade landing); phase-3 deep-link
  prefill ordering.
