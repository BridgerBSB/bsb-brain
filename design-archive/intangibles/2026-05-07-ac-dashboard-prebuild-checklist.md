# AC Dashboard — Pre-Build Checklist

**Date:** 2026-05-07
**Purpose:** Consolidate every open question across the 10 specs into one
prioritized prep list. Lock these BEFORE first code commit so the build
phase doesn't stall mid-stream.

**Read after:** [INDEX](./2026-05-07-ac-dashboard-INDEX.md)

---

## How to use

Walk through this with the user in one session. Mark each item as
**LOCKED** with the chosen value, **DEFERRED** with a sunset date,
or **DROPPED** with rationale. Skip nothing.

Once every BLOCKING item is locked, the build kickoff can begin.

---

## BLOCKING — must answer before any tab ships

### B1. Visual fidelity references

- [ ] **KDB Catcher Cards screenshot** — needed for hero card layout
  (currently inferred). Source: `https://kdbbeta85v2.netlify.app/` →
  click any catcher's card from a leaderboard/scoreboard.
- [ ] **KDB Live screenshot** — leaderboard layout, percentile chip
  styling, rank-context mini-panel. Influences Stats tab and Catcher
  Cards rank context.
- [ ] **KDB color palette browser-inspect dump** — exact hex values
  + spacing + border-radius tokens. Visual primitives doc has
  `[NEEDS-INSPECT]` flags throughout. Open Chrome DevTools on KDB,
  inspect a card, screenshot the computed-CSS panel.

### B2. Branding finals

- [ ] **AC accent color confirmed** — Astros orange `#EB6E1F` for
  positive/leader chips, Astros navy `#002D62` for emphasis text.
  Default in primitives doc; user can override.
- [ ] **Brand text** — landing hero shows "CATCHER DASH" /
  "Astros Catching · Internal Tool". Confirm copy.
- [ ] **Footer credit** — "Houston Astros Player Development" matches
  `feedback_player_development_name.md` rule. Already locked.

### B3. Scope locks

- [ ] **All 7 affiliates** confirmed in scope: mlb / aaa / aax / afa /
  afx / rok / dsl. Already locked per user direction.
- [ ] **HOU catchers only** — no league-wide comparison views in v1.
  Confirm.
- [ ] **Default sched_type = R** — advanced filter for S/E/V/I.
  Confirm.

### B4. Data layer integrity

- [ ] **Three-surface parity contract acknowledged** — AC reads, never
  recomputes. Per parity-test-plan.md.
- [ ] **Existing tracker pin reuse** — AC inherits `zbridger/intangibles_catcher_tracker_2026`
  pin via `catching_tracker_data.py` wrapped public functions. No
  new pin work for v1.
- [ ] **New SQL aggregators** approved for: pitch_calling, pitchers,
  scoreboard, leaders. Each is a NEW shape (no parity exposure).

### B5. Routing

- [ ] **`?view=dashboard` route** confirmed as the integration point in
  `4_Catching.py`. Two surgical edits described in master spec §2.
- [ ] **`render_domain_landing` extension** — adds optional
  `dashboard_desc/tag` kwargs. Backwards-compatible with BR/OF/IF.
  Confirm.
- [ ] **Catcher Dash card position** on the domain landing —
  before / after / inline-with the existing Postgame/Tracker/KPI
  cards? Default: 4th card (right of KPI).

### B6. Catcher Cards build-first rationale

- [ ] **Build order** — Catcher Cards first per master spec §8.
  Could ship as standalone MVP if budget tight. Confirm or override.
- [ ] **Defensive Grade composite formula** — z-score-mean across 8
  KPIs, mapped to 20-80 scale. Marked `[PROVISIONAL]` in UI. Lock
  formula now or accept provisional ship?
- [ ] **Recent games window on card** — last 5. KDB shows 5; matching.
  Confirm.

---

## NICE-TO-HAVE — can land at v1.5 or later

### N1. Stance data (originally Phase 1 of brainstorm)

- [ ] Savant catcher-stance CSV ingestion path (per
  `https://baseballsavant.mlb.com/leaderboard/catcher-stance?...&csv=true`)
- [ ] Connect-scheduled refresh per `tracker-parquet-pins.md` §12
- [ ] New "STANCES" panel on Catcher Cards or new tab
- [ ] Per-stance KPI splits (FramRAA / BlockRAA / R2K% by knee_code variant)

**Decision:** brainstorm doc had this as Phase 1, master spec defers
to v1.5. Confirm deferral.

### N2. PDF / PNG export of Catcher Cards

- [ ] Match on-screen card pixel-for-pixel (App ↔ Report parity)
- [ ] Slack delivery via in-app submission pattern
- [ ] Live in `ac_dashboard/pdf/` subpackage

**Decision:** v1.5. Confirm.

### N3. Hitting stats (Stats tab)

- [ ] Identify HOU data source for catcher hitting stats across
  affiliate levels
- [ ] PA + AVG + OBP + SLG + K% + BB% + wRC+ per (year, level)
- [ ] Career rollup per `multi-level-rollup.md`

**Decision:** Stats tab spec defers; defensive-only ships v1. Confirm.

### N4. League-wide comparisons

- [ ] AC currently shows HOU pool only. Tracker has all-30-orgs view.
- [ ] Future: leaderboard panel for "all 30 orgs catcher leaderboards"
  on the Stats tab — mirrors KDB Live.

**Decision:** v2 feature; not in initial scope.

### N5. Hotkeys

- [ ] KDB has H/G/R/S/C/E/M shortcuts. Port to AC tabs (D for
  Dashboard, etc.)?

**Decision:** Defer; nice polish, not critical.

### N6. Mobile responsive

- [ ] Coaches sometimes on phones; design currently desktop-first.

**Decision:** Defer; build desktop-first, add media queries in v1.5.

---

## BUILD-TIME DECISIONS (resolve during implementation, not before)

### Z1. Postgame panel extraction

`tab_gameday.py` reuses panels from `4_Catching.py::_render_postgame()`.
Two paths:
- (a) Extract to `ac_dashboard/postgame_panels.py`, refactor existing
  `_render_postgame` to call extracted helpers (clean, real refactor)
- (b) Duplicate panel functions into AC; document as known parity risk
  (faster, less risky to existing postgame view)

Decide at build time based on perceived refactor risk. Default: try
(a) first, fall back to (b) if extraction touches too much.

### Z2. Sequencing matrix granularity

Pitch Calling sequencing (prev type → next type) — at game level,
pitcher level, or session level? Tab spec defaults to pitcher level.
Decide on sample inspection.

### Z3. Pitch type universe

Pitch Calling + Pitchers tabs cap at top-N pitch types per catcher to
avoid sparse columns. Default: 5-7 by frequency, fold rest into
"Other". Confirm at build time on real data.

### Z4. Date navigator on Scoreboard

Calendar picker vs prev/next arrows vs both. Tab spec defaults to
both. Confirm UX during build.

### Z5. Empty-state copy

When catcher has no games / pool gate not met / no pitches caught for
selected pitcher. Each tab spec has an empty-state row in build
checklist. Lock copy at build time.

---

## RULE-COMPLIANCE CHECKLIST (auto-enforced via codebase rules)

These will be enforced by `.claude/rules/` files when code is being
written. Tracked here for visibility.

- [ ] `did_swing` gate on every Whiff% calculation (per `pitfalls.md`)
- [ ] `CAST(bit_col AS int)` before SUM on every BIT column (per `pitfalls.md`)
- [ ] `pv.pitch_id > 0` filter on every per-pitch query (per `pitfalls.md`)
- [ ] Age display = one decimal, never round up (per `feedback_age_formatting.md`)
- [ ] Player development naming = "Houston Astros Player Development" (per `feedback_player_development_name.md`)
- [ ] No `.dbo.` schema prefix on Pitches_View / Events_View / Schedule_View / Hits (per `feedback_no_dbo_prefix.md`)
- [ ] No EXISTS in SUM(CASE WHEN) — move to WHERE (per `feedback_no_sum_exists_tsql.md`)
- [ ] Per-metric n_obs weighting on multi-level rollups (per `multi-level-rollup.md`)
- [ ] 7-bucket framing palette LOCKED (per `intangibles.md`)
- [ ] Three-surface parity preserved (per `three-surface-parity.md`)
- [ ] Round only at display time (per `never-round-until-display.md`)
- [ ] `cur_event_id` vs `ab_event_id` JOIN choice deliberate (per `db-joins.md`)
- [ ] Video URL 3-tier fallback for click-to-video (per `video-angles.md`)
- [ ] Strike zone = ABS 17" Tango framework (per `sz-framework-savant-zones.md`)
- [ ] Tracker pin reuse — no parallel pin layer (per `tracker-parquet-pins.md`)

---

## VERIFICATION CHECKLIST (per `parity-test-plan.md`)

Before declaring any tab ship-ready:

- [ ] AC tab open in one browser window, source surface in another
- [ ] Same year + level + catcher selected on both
- [ ] Every numeric value compared cell-by-cell
- [ ] Mismatches traced to data assembler (NEVER fixed at display)
- [ ] Cross-tab navigation tested (deep links, session state persistence)
- [ ] Pool-gate hide-vs-show behavior tested
- [ ] Empty states tested

---

## BUDGET / TIMELINE CONFIRMATION

Per master spec §8:

- Foundation + routing + landing: 2.5 days
- Catcher Cards (Build First): 3-4 days
- Gameday: 2-3 days
- Pitch Calling: 2-3 days
- Pitchers: 2 days
- Stats: 1-2 days
- Scoreboard: 1-2 days
- Polish + parity: 1 day

**Total: 14-19 working days.**

- [ ] User confirms timeline acceptable
- [ ] User confirms single-developer scope (no parallel build streams)
- [ ] User confirms no compounding scope creep mid-build (lock specs)

---

## SIGN-OFF GATE

When all BLOCKING items above are LOCKED:

```
Build kickoff approved by: ____________ on ____________

Sequence start: Foundation phase →
                Routing phase →
                Landing tab →
                Catcher Cards tab (MVP value moment) →
                ... 
```

Until then, no `.py` files in `ac_dashboard/` get committed.

---

## References

- INDEX: `2026-05-07-ac-dashboard-INDEX.md`
- Open question sources: each tab spec's "Open questions" section
- Rule auto-load: `.claude/rules/intangibles.md` and friends
- Parity contract: `2026-05-07-ac-dashboard-parity-test-plan.md`
