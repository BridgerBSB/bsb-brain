# Catcher Dashboard — KDB-Style Internal Tool (Plan)

**Date:** 2026-05-05
**Status:** Brainstorm / pre-design
**Branch (target):** `feature/astros-intangibles`
**Likely home:** New page in Intangibles, e.g. `intangibles/pages/4_Catcher_Dashboard.py`,
or expansion of the existing Catcher section.
**Audience:** HOU Player Development coaches + coordinators (internal only).

---

## Goal

Big dashboard added to the Catching section of Intangibles — feature parity with select
KDB ("Kick Dirt Baseball") tool capabilities. Internal HOU tool, not public.

Reference: <https://kdbbeta85v2.netlify.app/> — single-page JS canvas app pulling from
MLB Stats API + Baseball Savant CSVs.

---

## Metric overlap with existing Intangibles

We already have most of the metric math. The KDB tool is mostly a UX layer on top of
metrics we've already canonicalized.

| KDB Concept | Intangibles Equivalent | Status |
|---|---|---|
| Framing Runs (Tango 0.125/strike) | FramRAA | HAVE — three-surface parity |
| Blocking Runs / BAA | BlockRAA, BlockRAA650 | HAVE |
| Pop Time 2B / 3B | Pop2B, Pop3B, AugPop | HAVE |
| Arm Strength | Arm (P99) | HAVE |
| Exchange | Exch (P10) | HAVE |
| R2K% | R2K% | HAVE |
| Shadow zone framing breakdown | Framing buckets (E Stl/Stl/Mid/Loss/B Loss) | HAVE |
| CSProb model (Bayesian, 1.88M pitches) | We use empirical CS rate | DIFFERENT approach, similar output |
| xBlock model (logistic, 71k pitches) | TDM/DCBP gates + tier 1 | DIFFERENT approach, similar output |

**Key insight:** Don't rebuild the metric pipeline. Use existing FramRAA / BlockRAA / Pop /
Arm / Exch / R2K%. The value-add is presentation, not new metrics.

---

## Genuinely net-new vs current Intangibles

These are the things KDB has that we don't:

1. **Savant catcher stance data** (knee_code splits)
   - Source: `https://baseballsavant.mlb.com/leaderboard/catcher-stance?...&csv=true`
   - 4 variants: Both Up (Traditional), Both Down, L-Down R-Up, R-Down L-Up
   - Per-stance framing/blocking/throwing run values, usage %, ext-leg %
   - **Real data gap** — no current Intangibles surface tracks stance.

2. **Interactive per-game zone plot with click-to-video**
   - Plot every called pitch with extra/lost markers
   - Click pitch → MLB Film Room mp4 (KDB uses `fastball-gateway.mlb.com` GraphQL)
   - We have video URL columns in `Astros.Video` / `Astros.Video_Network` already
     (see `rules/video-angles.md`) — could plug in directly.

3. **Shareable catcher card images** (vs current PDFs)
   - 1200×960 PNG layouts with team colors, scouting card style
   - Current postgame PDFs cover the substance; this is a shareable / Slack-friendly format.

4. **Lower priority / nice-to-haves:**
   - ABS challenge analysis (challenge-risk model, recoverable strikes)
   - Umpire heatmaps (HP umpire accuracy by game)
   - Multi-catcher pitch explorer (heavy build, mostly duplicates tracker)

---

## Phased build plan (proposed)

### Phase 1 — Stance data ingestion (~2-3 days)
- Add Savant catcher-stance CSV fetch to `intangibles/src/database.py`
  (cache by season, refresh nightly via Connect-scheduled job — same pattern as
  `rules/tracker-parquet-pins.md` §12 daily refresh).
- New tab in Catcher tracker page: **"Stances"** with usage % by knee_code.
- Pair with existing FramRAA/BlockRAA/R2K% per stance variant where Savant exposes them.
- **Lift level: LOW.** Public data, plugs into existing pin pattern.

### Phase 2 — Per-game framing dashboard (~1 week)
- New section on catcher postgame page (or new `5_Catcher_Game.py`).
- Interactive zone plot: every called pitch, extra/lost markers, click-to-video.
- **Recommend Plotly** (click events work, hover details, zoom/pan).
  Less polished than KDB's canvas but maintainable in Streamlit.
- Pulls from existing postgame data layer — no new SQL required.
- Video: hook into `Astros.Video` URL fallback chain (per `rules/video-angles.md`).

### Phase 3 — Shareable card image generator (~3-5 days)
- Replicate the KDB MLB-card layout in matplotlib (it's matplotlib-shaped, not canvas-only).
- Reuse panels from `intangibles/src/catcher_postgame_pdf.py` where possible.
- Output: 1200×960 PNG, downloadable button on catcher page.
- Optional: integrate with in-app submission pattern (`rules/in-app-submission.md`)
  for Slack delivery.

### Phase 4 — Optional / lower priority
- ABS challenge risk model — depends on ABS-tagged pitches in our DB; check schema.
- Umpire heatmaps — needs HP umpire ID per game (likely available via MLB Stats API
  hydration, not currently in our DB).
- Multi-catcher pitch explorer — mostly duplicates existing tracker scope.

---

## Tradeoffs

### Streamlit vs JS canvas
KDB's interactivity is canvas-based. In Streamlit our options are:
- **Plotly** — click events + hover + zoom; less polished feel; **maintainable**. RECOMMEND.
- `st.components.v1.html` with custom React — full control; major maintenance burden.
- matplotlib + selectbox — simplest, click-to-video via session state; rough UX.

### Internal-only constraints
- Posit Connect environment, FreeTDS connection, parquet pins for cache (existing pattern).
- Savant CSV pulls already used in some scripts — pattern is fine for stance data.
- MLB Film Room GraphQL works from Connect (we already use it).

### Three-surface parity
- KPI weekly + tracker + PD Goals must stay in sync (per `rules/three-surface-parity.md`).
- This dashboard is effectively a **4th surface**. It does NOT need to match the three —
  different scope (per-game/per-pitch vs season/L2W rollup).
- **BUT:** any metric refinement (new framing constant, new gate) MUST propagate
  to all four. Don't add a "dashboard-only" version of any existing metric.

---

## What NOT to build

- **Don't** rebuild the metric pipeline. FramRAA/BlockRAA/Pop/Arm already work.
- **Don't** import KDB's CSProb v8 or xBlock v8 models — we have our own (vetted internally).
- **Don't** build for public consumption. Strict internal HOU tool.
- **Don't** clone the entire KDB UI 1:1. Focus on what coaches need (stance, per-game
  framing+video, shareable card) — skip the flashy stuff that doesn't add coach value.
- **Don't** add a new metric surface that diverges from the three canonical ones.
  If we need a new variant, it goes through three-surface-parity update first.

---

## Open questions for next session

1. **Stance data:** daily refresh acceptable, or only on-demand pull when user opens page?
2. **Video click-through:** do we want to use `Astros.Video` direct URLs, or hit MLB Film
   Room GraphQL like KDB does (sporty-clips.mlb.com — IT-approved for player phones)?
3. **Card image:** coach-facing only, or also Slack-deliverable (in-app-submission pattern)?
4. **Page placement:** new page (`5_Catcher_Dashboard.py`) or expand existing `4_Catcher.py`?
5. **MVP scope:** do all three phases, or ship Phase 1 (stance) first as proof of value?

---

## References
- KDB tool: <https://kdbbeta85v2.netlify.app/>
- Existing catcher modules: `intangibles/src/catching_tracker_data.py`, `intangibles/pages/4_Catcher.py`, `intangibles/src/catcher_postgame_pdf.py`
- `.claude/rules/three-surface-parity.md` — parity invariants
- `.claude/rules/in-app-submission.md` — Slack delivery via Posit
- `.claude/rules/tracker-parquet-pins.md` — pin + Connect-scheduled refresh pattern
- `.claude/rules/video-angles.md` — video URL fallback chain
