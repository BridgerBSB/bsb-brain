# Fielding Advance — Interactive App Surface (Design / Plan)

**Date:** 2026-06-08
**Worktree:** `bsb-wt-intangibles/astros-intangibles` — `feature/astros-intangibles`
**Status:** ✅ SHIPPED + verified on Barrelsville-adjacent flow (Jun 8–10 2026). Below is the original design; final shipped state + gotchas at top.

## SHIPPED — final state (Jun 10 2026)

**UX (matches Arm Farm pitching advance, not the simpler original design):**
- 5th **"FIELDING ADVANCE"** card on BOTH Infield + Outfield → one shared
  `src/fielding_advance_page.py::render()` (route `?view=advance`).
- **Sidebar:** Level → Series → Hitter selectors + combined-team PDF /
  Upcoming-ZIP download buttons (mirrors `4_Pitching_Advance.py`).
- **Two tabs:** *Series Scouting* (every opposing hitter as an
  `st.expander`; expand → that hitter's IF/OF density **heatmaps** + wedge
  render inline via `st.pyplot` of `_draw_hitter_page`, + per-hitter PDF) and
  *Hitter Lookup* (new `search_hitters_by_name` → inline render + PDF).
- 100% reuse of `hitter_advance_data` + `hitter_advance_report` → App↔Report
  parity automatic; combined PDF unchanged from the weekly batch.

**Three real bugs fixed during build (all app-only; PDF/batch untouched):**
1. **Heatmap missing in app = scipy not installed on Connect.** `_draw_field_density`
   draws the KDE `contourf` only `if gaussian_kde is not None`; Connect lacked
   scipy → scatter-only ("black balls"). Fix: `scipy>=1.10,<1.14` added to
   `intangibles/requirements.txt` (+ env-rebuild trigger). **Redeploy required.**
2. **Headshot + Astros logo covered the heatmap in-app.** Both are `fig.figimage`
   at pixel coords calibrated for the 150-dpi PDF; `st.pyplot` renders at a
   different dpi → they land on the panels. Fix: `show_images` flag on
   `_draw_hitter_page`/`_draw_hitter_header`; app passes `show_images=False`
   (PDF keeps default `True` → byte-identical).
3. **`fielding_advance_page.py` must be in `manifest.json`** (Connect allow-list).

**DSL/FCL opponent leak (separate, cross-app):** all 3 advance schedule
queries pulled FCL/ACL teams into DSL series (org-level `gbl_club_lkup` join;
DSL+FCL+ACL share MLBAM `SPORT='rok'`). Fixed via `MLBAM.Teams.league`
team-level discriminator (`want_dsl`) + `SELECT DISTINCT team_id` in
`barrelsville/src/advance_data.py`, `bullpen-report/src/advance_pitching_data.py`,
`intangibles/src/hitter_advance_data.py`. **Documented in
`.claude/rules/level-codes.md` → "MLBAM.Schedule opponent schedules".**

**Monday cascade:** new `advance-fld` phase runs `generate_hitter_advance.py
--level dsl` → `dsl_intangibles` channel (DSL only; other levels manual).
See `pd-goals/scripts/run_monday.ps1` header.

**Work-laptop to finish:** `git pull` all advance worktrees → **redeploy
Intangibles** (picks up scipy + image-skip) → DSL series shows DSL-only
opponents with clean heatmaps.

---


## Goal

Give fielding coaches an **on-demand, interactive** way to pull a defensive
advance scouting report on any opposing hitter — the fielding equivalent of
Barrelsville's `pages/3_Advance.py` (which does the same for opposing
pitchers). Today the fielding/hitter advance only exists as a **batch CLI**
(`scripts/generate_hitter_advance.py`) that auto-detects upcoming series and
delivers PDFs to Slack. This adds the interactive surface; the batch CLI +
Slack delivery stay exactly as-is.

## Placement decision (Option A — Intangibles, now)

Lives in the **Intangibles app**, not PD Engine. Rationale:
- The data + report code (`hitter_advance_data.py`, `hitter_advance_report.py`)
  already live in this worktree. PD Engine (`pd-goals`) **cannot** import them
  (BLOCKING: no cross-worktree imports). Putting it here = thin wrapper, zero
  duplication.
- Fielding coaches already live in the Intangibles app.
- **Option B** (migrate everything to PD Engine as the unified org dashboard)
  is a separate, later plan. Nothing here blocks it — the new page module is
  self-contained and could be ported / pin-fed later.

## Navigation wiring ("two cards, one app")

The new **"FIELDING ADVANCE"** card is the **5th** sub-card under BOTH the
Infield and Outfield sub-landings, and both route to the **same** page module.

Each section page (`pages/2_Outfield.py`, `pages/3_Infield.py`) is
query-param routed (`?view=postgame|tracker|kpi|weekly`) and draws its cards
via the shared `render_domain_landing(...)` helper in `src/tracker_page.py`.

### Changes

1. **`src/tracker_page.py` → `render_domain_landing(...)`**
   Add one optional card slot: `advance_desc` / `advance_tag` kwargs that
   render an `<a href="?view=advance">FIELDING ADVANCE</a>` card. Renders only
   when `advance_desc` is passed (mirrors the existing `kpi` / `weekly` /
   `dashboard` optional-slot pattern). Append `{advance_card}` after
   `{dashboard_card}` in the grid so it's the **last** card.

2. **`pages/3_Infield.py`** and **`pages/2_Outfield.py`** (identical edits):
   - Add to the `render_domain_landing(...)` call:
     `advance_desc="Defensive advance scouting on opposing hitters — spray/BIP tendencies for positioning"`,
     `advance_tag="[ NEW ]"`.
   - Add a route branch:
     ```python
     elif _view == "advance":
         render_back_link("Infield")   # "Outfield" in 2_Outfield.py
         from src import fielding_advance_page
         fielding_advance_page.render()
     ```
   - Import-on-use (matches how `kpi`/`weekly` are imported inside their
     branches) so the landing stays light.

3. **`src/fielding_advance_page.py`** (NEW) — the shared `render()`. Both IF
   and OF `?view=advance` routes call it → one app, two entry cards.

## The page module (`fielding_advance_page.render()`)

Mirrors Barrelsville `3_Advance.py` structure. Reuses existing data/report
functions — **no metric logic duplicated**, so App↔Report parity with the
batch CLI is automatic.

### Tabs

**Tab 1 — Series Scouting** (reuses 100% existing functions)
- Level select (`aaa/aax/afa/afx/rok/dsl` + `IL`) → upcoming series via
  `get_upcoming_series(...)` (fallback `get_season_series(...)`).
- Resolve opposing org → `get_opposing_hitters(org, level)`
  (+ `get_opposing_il_hitters` for the `IL` pseudo-level).
- "Generate combined advance PDF" → `generate_hitter_advance_batch(...)` →
  `st.download_button`. Same output the Slack batch produces.

**Tab 2 — Hitter Lookup** (the "for ALL opposing hitters" ask)
- Free search any hitter by name → single-hitter PDF via
  `generate_hitter_advance_report(...)`.
- **Gap:** no `search_hitters_by_name` exists yet. Add it to
  `hitter_advance_data.py`, mirroring Barrelsville
  `advance_data.search_pitchers_by_name` (name → gc_id/level/org candidates;
  then `get_hitter_bips(...)` → report).

### Deferred (YAGNI for v1)
- **Diagnostic tab** (Barrelsville's multi-gc-id / non-EBIZ stitching) — defer
  until a real multi-tracking-id opposing hitter forces it.
- **IF vs OF differentiation** — v1 serves the **same** combined report from
  both cards (the report already draws both `_draw_if_field` and
  `_draw_of_field`). A future `domain="IF"/"OF"` hint could emphasize the
  relevant field view; not now.
- **OF positioning sketches** (`generate_of_positioning.py`,
  `generate_field_sketch_pdf.py`) — possible later addition to the OF entry;
  out of scope for v1.

## Constraints / rules to honor

- **PDF-last-in-script (BLOCKING):** the `st.spinner("Generating PDF...")` +
  `generate_*` + `st.download_button` block must sit **after** all in-page
  `st.dataframe` / `st.plotly_chart` rendering in each tab. Ref
  `barrelsville/pages/3_Advance.py`.
- **No cross-worktree imports (BLOCKING):** everything stays in
  `intangibles/`.
- **App↔Report parity (BLOCKING):** the page calls the same
  `hitter_advance_data` + `hitter_advance_report` functions the CLI uses — no
  reimplemented queries.
- **Advance-levels exception:** advance reports may window on recency and
  include `bbc/ind/int/sum/win/min` per `.claude/rules/advance-levels.md` —
  inherit whatever scoping the existing `hitter_advance_data` functions
  already apply; do not re-gate.

## Task breakdown

1. `render_domain_landing` — add `advance_desc`/`advance_tag` slot + grid append.
2. `src/fielding_advance_page.py` — Tab 1 (Series Scouting) wired to existing functions.
3. `hitter_advance_data.search_hitters_by_name(...)` — new (mirror Barrelsville).
4. `fielding_advance_page` — Tab 2 (Hitter Lookup) using #3.
5. Wire `pages/3_Infield.py` + `pages/2_Outfield.py` (card desc + `?view=advance` route).
6. Verify PDF-last ordering; smoke-test both cards land on the same page.

## Out of scope
- Slack delivery / scheduling (batch CLI already owns it).
- PD Engine migration (Option B — separate later plan).
- New metrics or query changes to the underlying advance data.
