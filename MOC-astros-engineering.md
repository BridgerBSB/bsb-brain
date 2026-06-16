---
type: MOC
topic: astros-engineering
---
# MOC — Astros Engineering

Map of Content for the ~70 engineering rules governing the Houston Astros PD analytics codebase (live source: `bsb-resources/.claude/rules`). These encode the hard-won conventions, BLOCKING invariants, and bug-class fixes that keep the four apps (PD Engine, Arm Farm, Intangibles, Barrelsville) in sync.

**Connects to:** [[MOC-baseball-analytics]] — the engineering canon implements the analytics web. A few load-bearing links:

- [[xwoba-canonical]] ↔ [[xwoba]] — every surface must match GC2's per-PA xwOBA within ±0.001; IBB counts as a walk (opposite of wOBA).
- [[woba-rules]] ↔ [[woba]] — wOBA weights from `Guts.woba_lwts`, league-resolved per PA.
- [[fielding]] ↔ [[paa-eo]] / [[oaa]] — the 3-tier gate and arm floors behind every defensive metric.
- [[multi-level-rollup]] ↔ [[percentile-pooling]] — pool raw obs at the individual tier, weighted-mean at the org tier.
- [[gc2-metrics]] ↔ [[gcoba]] / [[pbarrel]] / [[whiff-pct]] — canonical hitting metric formulas.

---

## Canonical metrics
The single-source-of-truth definitions every app must match. Drift here = a coordinator catches us off by .003.

- [[xwoba-canonical]]
- [[woba-rules]]
- [[gcera-canonical]]
- [[gc2-metrics]]
- [[bat-speed-canonical]]
- [[damage-pct-cross-app-divergences]]
- [[ip-calculation]]
- [[data-cleaning]]
- [[never-round-until-display]]

## Fielding
- [[fielding]]
- [[pd-goals-defense]]
- [[tracking-schema]]
- [[pooled-percentile-pattern]]

## Tracker pins & deploy
The parquet-pin caching layer, its refresh cadence, and the Connect deploy bundles.

- [[tracker-parquet-pins]]
- [[tracker-pin-connect-deploy]]
- [[tracker-pin-daily-refresh]]
- [[tracker-pin-sparse-recovery]]
- [[tracker-new-metric-checklist]]
- [[pin-only-raw-not-derived]]
- [[streamlit-tracker-column-pinning]]
- [[tracker-save-screen]]
- [[tracker-stat-rank-display]]
- [[tracker-aggrid-stat-rank]]
- [[database-tcp-retry]]

## KPI weekly
- [[kpi-weekly-charts]]
- [[kpi-roster-filter]]
- [[kpi-parallelization]]
- [[combined-kpi-stapler]]

## Delivery & cascade
- [[delivery]]
- [[cascade-orchestrators]]
- [[slack-channels-sync]]
- [[in-app-submission]]
- [[external-resource-capture]]

## PD-Goals / PD Engine
- [[pd-goals]]
- [[pd-goals-defense]]
- [[pd-goals-flag-tracker]]
- [[pd-goals-rolling-chart]]
- [[pd-goals-transition]]
- [[pd-goals-unmeasurable]]
- [[pd-goals-wpa-plays]]
- [[org-board]]

## App-specific
- [[arm-farm]]
- [[barrelsville]]
- [[intangibles]]

## DB & SQL
Schema references, join keys, query patterns, and the SQL Server gotchas.

- [[db-columns]]
- [[db-connection]]
- [[db-joins]]
- [[event-vs-pitch-anchored]]
- [[level-codes]]
- [[sched-types]]
- [[pitch-codes]]
- [[draft-tables]]
- [[draft-projects]]
- [[advance-levels]]
- [[advance-non-ebiz-pitchers]]
- [[query-performance]]
- [[dual-query-path]]
- [[pitfalls]]
- [[reference-impl-index]]

## Visualization & PDF
- [[visual-standards]]
- [[coordinates]]
- [[sz-planning-prompts]]
- [[pdf-patterns]]
- [[pdf-last-in-script]]
- [[video-angles]]

## Org-codes & parity
Cross-source canonicalization and the invariants that keep the same number from appearing on every surface.

- [[org-codes]]
- [[org-attribution-per-pa]]
- [[three-surface-parity]]
- [[multi-level-rollup]]
- [[merge-union-not-primary]]

## Process / behavioral
The non-negotiable BLOCKING list and the behavioral corrections.

- [[blocking-rules]]
- [[dual-track-operate-vs-assemble]]
- [[never-defer-to-tomorrow]]
- [[graduation-log]]
- [[graduation-log-archive-2026-04-thru-05-10]]
