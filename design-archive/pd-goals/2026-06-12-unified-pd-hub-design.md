# Unified PD Hub — "Baseball Savant for Astros PD" — Design & Plan

**Date:** 2026-06-12
**Branch:** `feature/pd-goals` (hub lives in the existing PD Engine app)
**Status:** DESIGN — for review. No code written yet.
**Author:** Zac Bridger (PD analyst) + Claude

---

## 0. One-paragraph summary

Consolidate the four Streamlit apps (PD Goals / PD Engine, Arm Farm,
Barrelsville, Intangibles) into **one front door**: a Baseball-Savant-style
hub that lives in the existing **PD Engine** app (`pd-goals/`, app GUID
`79f52369-…`). The hub is **player-search-first**: type a player → land on a
cross-domain Player Card → drill into any domain. The hub itself renders
from the **pre-aggregated Connect pins** (refreshed every 6h, sub-second cold
load), so it's fast. The heavy, live-SQL report/tracker pages stay in their
own deployments and are reached by **deep-link with the player/level
pre-filled**. This is faster on Posit and lower-risk than physically merging
40+ pages and four `src/` trees into one deployment — and roughly 60% of it
is already built (`pages/8_Player_Card.py` already synthesizes all four apps'
pins).

---

## 1. Goal & success criteria

**Goal (user's words):** "make our dashboards all into one — all our apps in
intangibles, pd goals, arm farm, barrelsville into one all-encompassing dash
like baseball savant that will live in either main or pd goals."

**Decided constraints (from brainstorming):**
- Core shape = **unified shell + nav (integrate)**, keep existing app code.
- Deciding criterion = **"whatever loads quickest on Posit and is usable."**
- Home = **PD Goals / PD Engine** (it is already the front door).

**Success criteria:**
1. A coach/coordinator opens ONE URL and can reach every domain (hitting,
   pitching, defense, baserunning, goals, org board) without knowing which
   "app" it lives in.
2. Player-search-first: type a name → one cross-domain summary page.
3. Hub landing + Player Card cold-load in **< 2 s** (pin-backed, no live SQL
   on the synthesis layer).
4. No regression: every existing report/tracker/PDF keeps working unchanged.
5. No new dependency-conflict risk; no re-pin/redeploy churn beyond pd-goals.

---

## 2. What already exists (ground truth — read before building)

### 2.1 PD Engine is already the umbrella app
`pd-goals/PD_Engine.py` is a card-nav landing (retro arcade aesthetic) with
links to PD Goals / Transitions / WPA Plays / Org Board / Defense Matrix.
13 pages already live under `pd-goals/pages/`:

| Page | Purpose | Data source |
|---|---|---|
| `1_PD_Goals.py` | 6-week goal tracking + compliance | live SQL + pins |
| `2_Transition.py` / `3_Transitions_View.py` | transition reports | parquet pins |
| `4_WPA_Plays.py` | daily WP swings + video | live SQL |
| `5_Org_Board.py` / `6_Team_View.py` | EBIS kanban / team view | PP_MASTER + TR_HISTORY |
| `7_Defense_Matrix.py` | versatility matrix | dedicated pin |
| **`8_Player_Card.py`** | **Savant-style cross-domain player page** | **all 4 apps' tracker pins** |
| `9_Pitch_Arsenal.py` | pitch arsenal view | (verify) |
| `10_Hitter_Approach.py` | hitter approach view | (verify) |
| `11_Cohort_Explorer.py` | cohort/peer explorer | (verify) |
| `12_Compare.py` | player comparison | (verify) |
| `13_Org_Pulse.py` | org-level pulse | (verify) |

### 2.2 The cross-app pin-synthesis layer already works
`8_Player_Card.py` reads **every** app's tracker pin off the shared board:

```
HITTER_PIN_FMT   = "zbridger/barrelsville_tracker_{year}"      # Barrelsville
PITCHER_PIN_FMT  = "zbridger/arm_farm_tracker_{year}"          # Arm Farm
OF_PIN_FMT       = "zbridger/intangibles_of_tracker_{year}"    # Intangibles
IF_PIN_FMT       = "zbridger/intangibles_if_tracker_{year}"
BR_PIN_FMT       = "zbridger/intangibles_br_tracker_{year}"
CATCHER_PIN_FMT  = "zbridger/intangibles_catcher_tracker_{year}"
```

It already: auto-selects metrics per position family, computes percentile vs
the level pool, renders radar + percentile-bar grid + cohort table, and falls
back gracefully on a pin miss. **This is the architectural proof that "one
hub fed by pins" is viable today.** The pins are refreshed every 6h on Connect
(per `tracker-parquet-pins.md` §12), so the synthesis is daily-fresh with
zero new infrastructure.

### 2.3 Dependencies are already harmonized (no merge-conflict risk)
All four `requirements.txt` deliberately pin to the same window
(`streamlit>=1.49,<1.50`, `pandas<3`, `numpy<2`, `plotly`, `matplotlib`,
`plottable`, `pins>=0.8`, `scipy`, `streamlit-aggrid`). Only Intangibles adds
`duckdb` + `pyarrow`. There is **no version conflict** that would block code
living together — they were all pinned in lockstep precisely because of the
shared-rules discipline (`streamlit-tracker-column-pinning.md` §12.2).

---

## 3. Architecture decision — three options, with recommendation

### Option A — Pin-synthesis hub + deep-links (RECOMMENDED)
PD Engine becomes the hub. The **synthesis surfaces** (landing, player search,
Player Card, compare, cohort, org pulse) render from pins and live in pd-goals.
The **heavy report/tracker pages** stay in their own deployments (Barrelsville,
Arm Farm, Intangibles) and are reached by deep-link with `?player=<gc_id>` /
`?level=<code>` pre-filled (the prefill pattern already exists in PD Goals and
Org Board).

```
ONE URL — Astros PD Hub (pd-goals deploy)
  [ 🔍 search player ]            ← player-search-first
  ┌──────────────── landing ────────────────┐
  │ Player Card (pins)   Compare (pins)      │
  │ Cohort (pins)        Org Pulse (pins)    │  ← instant, pin-backed
  │ Goals/Compliance     Org Board           │
  └──────────────────────────────────────────┘
        │ "open full hitting report ↗"
        ▼ deep-link, player pre-filled
  Barrelsville / Arm Farm / Intangibles deploy (live SQL, unchanged)
```

- **Loads fastest:** the front door + every synthesis page are pins → < 2 s.
  Heavy SQL only runs when a user explicitly opens a full report, and only
  that app cold-starts (already perf-tuned + pin-backed per app).
- **Usable as "one":** single URL, single nav, single search, Astros chrome.
  Deep-links feel like sections; coaches never see "four apps."
- **Lowest risk:** zero changes to the other three apps' code/deps/deploys.
  No 40-page sidebar, no four-`src/`-tree dedupe, no requirements reconcile.
- **Cost:** the experience is "one front door + handoffs," not literally one
  process. A deep-link to another deployment cold-starts that app on first
  jump (then warm). Mitigated by keeping all apps on the 6h pin refresh so
  their cold-load is already sub-second at default filters.

### Option B — Mega-app merge (one deployment, all 40+ pages)
Physically merge all `pages/` + `src/` into the pd-goals deployment.

- **Pro:** literally one process, in-app nav never cold-starts a sibling.
- **Con (perf):** the entry process must import a much larger `src/` graph;
  Connect cold-start of the merged app is *heavier*, not lighter. Streamlit
  does lazy-load page scripts, but shared-module imports + a 40-item sidebar
  hurt first paint. This works *against* "loads quickest."
- **Con (risk):** dedupe four `database.py` / `pins_config.py` / `roster.py`;
  reconcile one `requirements.txt` (feasible — already aligned — but adds
  `duckdb`/`pyarrow` to everyone); rename colliding page numbers; re-audit
  every `connect_pins*/deploy.ps1` import graph; one redeploy now risks all
  four apps at once. High effort, real regression surface.
- **Verdict:** only worth it if a single-process in-app experience becomes a
  hard requirement. Not justified by "loads quickest + usable."

### Option C — Iframe-embed hub
Hub embeds each app deployment in an iframe.

- **Con:** Connect auth/session inside iframes is fragile; Streamlit iframe
  sizing/scroll quirks; slower (cold-start + iframe overhead); the
  `st.components.v1.html` parent-frame tricks we already fight (Org Board
  lazy-render) get worse. Middle ground that inherits the downsides of both.
- **Verdict:** no.

**RECOMMENDATION: Option A.** It is the fastest on Posit, the most usable as
"one dashboard," the lowest risk, and it builds directly on what already
exists. Option B stays on the table as a *future* step **only if** a coach
explicitly needs zero cross-deploy cold-starts — and even then we'd revisit
whether it actually loads faster.

---

## 4. Information architecture (the Savant model)

### 4.1 Landing = search-first + domain tiles
- Big **player search box** up top (autocomplete over the active roster; the
  roster query already exists in `src/roster.py`).
- Below it, **domain tiles**: Hitting · Pitching · Defense · Baserunning ·
  Goals/Compliance · Org Board. Each tile is either an in-app pin page or a
  deep-link to the owning app.
- A "browse by level" rail (MLB → DSL) for coaches who start from a club.

### 4.2 Player page = the Savant profile (already built, to be elevated)
`8_Player_Card.py` is the spine. Elevate it to the **primary destination of
search**:
- Hero (photo, vitals, level, position, B/T, age).
- Role-aware panels (hitter / pitcher / OF / IF / catcher / BR) auto-shown by
  `position_family()`.
- Percentile bars + radar vs the player's level pool (already implemented).
- Cohort table (top-5 peers, already implemented).
- **NEW: a "drill-in" action bar** per panel → deep-links to the full report
  in the owning app, player pre-filled:
  - Hitting → Barrelsville Postgame / KPI / Advance
  - Pitching → Arm Farm Postgame / KPI / Advance
  - Defense/BR → Intangibles OF/IF/Catcher/Baserunning
  - Goals → PD Goals page (same app, in-process)

### 4.3 Cross-cutting hub pages (already scaffolded, to be confirmed/finished)
- **Compare** (`12_Compare.py`) — N players side-by-side from pins.
- **Cohort Explorer** (`11_Cohort_Explorer.py`) — pool/leaderboard from pins.
- **Org Pulse** (`13_Org_Pulse.py`) — org-level rollup from pins.
- **Pitch Arsenal** (`9`) / **Hitter Approach** (`10`) — domain deep-dives.

> ACTION: read pages 9–13 to confirm what's real vs stub before scoping
> Phase 2 (they were created recently and may be partial).

---

## 4.5 FUTURE navigation model (user direction, 2026-06-12) — NOT a now-build

> Explicit user direction: this is the **future** target, not what we ship
> first. We are *not* shipping right now. Captured here so the Phase-1 hub is
> built in a direction that grows into this without rework.

### The model: top tabs → sub-tabs, global sidebar retired

- **Top-level = tabs, one per domain** (Hitting / Pitching / Defense /
  Baserunning / Goals / Org) — replacing Streamlit's left-sidebar page list as
  the primary navigation. The viewer reads navigation **horizontally across
  the top**, not down a sidebar.
- **Each tab has sub-tabs = that domain's features.** e.g. Hitting →
  Postgame / Tracker / KPI / Advance; Defense → OF / IF / Catcher / Matrix.
- **The global sidebar is no longer the nav.** Only deep subpages keep a
  sidebar, and only for **their own** filters — and even that is up for a UX
  rethink (below).

### The filter rethink — two tiers, viewer-first (the crux)

The recurring failure mode of a tabbed hub is **filters**. If each subpage
re-asks for player/level/season, switching domain tabs forces the viewer to
re-pick the same player — the opposite of "one dashboard." Split filters:

| Tier | What | Where it lives | Why |
|---|---|---|---|
| **Shared context** | player, level/team, season | **Persistent top context bar**, selected ONCE, inherited by every tab + sub-tab | The hub is always "looking at a player/team"; tabs just change the lens. Pick once, never re-pick. |
| **Local filters** | date range, pitch type, handedness/HA split, count state, sub-view toggles | **Inline filter strip at the top of the subpage content** (preferred over a sidebar) | View-specific; meaningless to other tabs. An inline strip stops competing with the tab bar for "where do I navigate?" attention. |

**Why hoist shared filters:** this is the same pattern already proven in the
codebase — the tracker "hoist Mode + multiselects ABOVE the WoW/MoM/YoY
sub-tab strip" fix (`tracker-trends-perf-plan.md`). Apply it one level up:
hoist the **shared** filters above the **domain tabs**; demote per-page
sidebars to **local-only** filters.

**Why prefer an inline strip over a sidebar for local filters:** a left
sidebar visually reads as "navigation." With navigation already living in the
top tab bar, a second nav-shaped region (the sidebar) splits the viewer's
attention. An inline filter row, directly above the content it filters, reads
as "controls for THIS view" — clearer mental model.

### Viewer-first principles to carry into every tab
- **One subject at a time, many lenses.** The top context bar names the
  subject (player/team); tabs are lenses on it. Never make the viewer
  re-establish the subject when changing lens.
- **Navigation up top, controls near content, data fills the page.** Three
  bands: tab bar (where am I) → context + local filters (what am I looking at)
  → content (the answer). No competing nav regions.
- **Progressive disclosure.** Land on a summary (pin-backed, instant); the
  full live-SQL report is one explicit click deeper, never on the critical
  path.
- **Consistency across domains.** Same tab grammar, same context bar, same
  filter-strip placement in every domain, so a coach learns the hub once.

### Implementation implication for this model
Streamlit's native top-tabs (`st.tabs`) re-run on every switch and don't deep-
link cleanly, so the production form of this is most likely either (a) the
mega-merge (Option B) with a custom top-tab bar + a shared context-bar module,
or (b) a hub shell that renders the top-tab bar and routes via query params.
**This is exactly why the Phase-1 hub (Option A) should externalize the
"shared context bar" as a reusable module from day one** — so the eventual
top-tab shell can wrap the same context bar without a rewrite. Decide A-vs-B
for the *production* nav at that later phase; build Phase 1 so either works.

---

## 5. Load-speed strategy (the "loads quickest on Posit" requirement)

1. **Pin-first on every synthesis surface.** Landing, Player Card, Compare,
   Cohort, Org Pulse must read pins only — never live SQL on cold load. This
   is already the Player Card's design (`@st.cache_data(ttl=3600)` on pin
   reads). Pins refresh every 6h on Connect (no user wait).
2. **Live SQL only behind an explicit click.** Goals compliance, WPA, full
   reports run SQL — keep them off the landing's critical path (the
   `pdf-last-in-script.md` discipline already enforces "data first").
3. **Deep-link, don't embed.** A handoff to another app cold-starts only that
   app, and only its default (pin-backed) view — already sub-second.
4. **Shared pin board, single auth.** All pins on `zbridger/*`,
   `CONNECT_API_KEY` already set on pd-goals. No new infra.
5. **Search index from roster pin.** Autocomplete reads the cached roster, not
   a live PP_MASTER hit per keystroke.

---

## 6. Deep-link contract (the glue)

Each owning app must accept URL params and pre-filter. Status:
- PD Goals: `?player=<gc_id>` prefill **exists** (Org Board → PD Goals).
- Org Board / Team View: `?drawer=<gc_id>`, `?team=<code>` **exist**.
- Barrelsville / Arm Farm / Intangibles: **need** a small, uniform
  `?player=<gc_id>` (and optionally `?level=`, `?date=`) prefill block at the
  top of each target page (mirror `pages/1_PD_Goals.py::_apply_query_param_prefill`).

**Canonical param set:** `player` (gc_id), `level` (MLBAM sport code),
`season` (year), `view` (optional sub-tab). Keep it identical across apps so
the hub can build one link shape.

> This is the only change required *outside* pd-goals, and it's additive +
> low-risk (a silent no-op when the param is absent).

---

## 7. Phased rollout

**Phase 0 — Confirm & decide (this doc).**
- Read pages 9–13 to inventory real vs stub.
- Lock Option A. Lock the deep-link param contract.

**Phase 1 — Hub front door (pd-goals only, ~days).**
- Elevate `PD_Engine.py` landing: add player search + domain tiles; make
  Player Card the search destination.
- Add the per-panel "drill-in" action bar to `8_Player_Card.py` (deep-links).
- Ship behind the existing pd-goals deploy. No other app touched yet → if a
  deep-link target lacks prefill, it still opens (just unfiltered).

**Phase 2 — Finish the cross-cutting pin pages.**
- Confirm/complete Compare, Cohort Explorer, Org Pulse, Pitch Arsenal,
  Hitter Approach. All pin-backed.

**Phase 3 — Uniform deep-link prefill in the 3 sibling apps.**
- Add the `?player=`/`?level=` prefill block to the key target pages in
  Barrelsville / Arm Farm / Intangibles (one small block per page, additive).
  Cross-worktree, one commit per worktree.

**Phase 4 — Polish & wayfinding.**
- Consistent Astros chrome/header across hub + sibling apps (shared CSS
  snippet) so handoffs feel seamless.
- Optional: a persistent "← back to Hub" link on sibling pages.

**Phase 5 (OPTIONAL, only if needed) — evaluate mega-merge.**
- Revisit Option B *only* if zero cross-deploy cold-start becomes a hard ask.

---

## 8. Risks & mitigations
- **Cross-deploy cold-start on first jump.** Mitigated: every app is already
  pin-backed + 6h-refreshed → sub-second default view. Acceptable for a
  click-through.
- **Pin schema drift across apps.** Player Card already handles legacy-key
  fallback (`_extract_df`). Keep that defensive pattern.
- **Deep-link prefill missing in a target page.** Fails safe — page opens
  unfiltered. Phase 3 closes the gap.
- **Two visual languages** (PD Engine arcade vs Player Card Savant). Pick the
  Savant card aesthetic as the hub standard; the arcade landing becomes the
  search-first hub (restyle in Phase 1/4).

---

## 9. Open decisions (need user input)
1. **Search-first vs search + tiles equal billing** on the landing? (Plan
   assumes search-first with tiles below.)
2. **Hub visual language:** keep the retro arcade landing, or restyle to the
   clean Savant card look used by Player Card? (Plan recommends Savant look
   for the hub, retire arcade on the landing.)
3. **Which sibling-app pages get deep-link prefill first** (Phase 3 ordering)?
   Suggest: Postgame + KPI + Tracker + Advance per app (the high-traffic four).
4. **Scope of Compare/Cohort/Org Pulse** — finish as-is, or redesign? (Pending
   the pages 9–13 inventory.)

---

## 10. What NOT to do
- Don't physically merge all four `src/` trees + 40 pages into one deployment
  as step one — it loads *slower* on cold start and risks all four apps in one
  redeploy. (Option B is a deliberate later choice, not the default.)
- Don't put live SQL on the hub landing or Player Card critical path — pins
  only. (Per §5.)
- Don't iframe-embed sibling apps (auth/session/scroll fragility — Option C).
- Don't duplicate the cross-app pin formats — Player Card already owns them;
  reuse `8_Player_Card.py`'s loaders.
- Don't break the `pdf-last-in-script.md` discipline on any hub page.
- Don't add new pin infra — the 6h-refreshed `zbridger/*` board already feeds
  everything.

---

## 11. Cross-references
- `rules/pd-goals.md` — PD Engine app family.
- `rules/tracker-parquet-pins.md` — pin pattern + 6h Connect refresh (§12).
- `rules/three-surface-parity.md` — values must match across surfaces.
- `rules/org-board.md` — query-param prefill + deep-link precedent.
- `pd-goals/pages/8_Player_Card.py` — the cross-app synthesis spine.
- `pd-goals/PD_Engine.py` — current landing/front door.
