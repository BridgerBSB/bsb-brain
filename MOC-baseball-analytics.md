---
type: MOC
topic: baseball-analytics
created: '2026-06-15'
---
# 🗺️ Baseball Analytics — Map of Content

The hub. Domains × methods × projects × people, all cross-linked. Start here;
follow the links out. This weaves the personal/portfolio work
([[private-archive/README|private archive]]) into the live Astros canon
([[bsb-resources-inventory]], the `rules/` + `memory/` snapshots).

## Domains
- **Hitting** → [[xwoba]] · [[swing-path-bat-tracking]] · [[strike-zone-kde]] — projects: [[og-pena]], [[swing-path]]
- **Pitching** → [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] — projects: [[pitch-design-colby]], [[dudz-batter-pitcher]]
- **Baserunning** → [[send-hold-decisions]] · [[re24-run-expectancy]] — project: [[send-from-2b]] · Astros tie-in: [[org-attribution-per-pa]]
- **Defense** → (Astros: fielding tracking — see `rules/fielding`)

## Methods / modeling (the connective tissue)
- [[statcast-pipeline]] — the shared data spine under almost every project
- [[statcast-bulk-fetch]] — the pybaseball bulk-pull + retry/chunking pattern feeding it
- [[advanced-modeling-setup]] — vendoring public pitch-model repos (4S / Stuff+) for AI context
- [[lightgbm-baseball-modeling]] — gradient-boosted decision models → [[send-from-2b]], Astros [[promotion-models-status]]
- [[dsproj-data-science-examples]] — force-plate → velo/bat-speed prediction corpus: [[velo-prediction-rf]] · [[support-vector-regression-baseball]] · [[decision-trees-baseball]] · [[radar-chart-viz]] · [[percentile-rank-scoring]] · [[hp-cross-db-pipeline]]
- [[xwoba]] · [[re24-run-expectancy]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[swing-path-bat-tracking]]
- Viz: [[strike-zone-kde]], 3D Plotly swing arcs ([[swing-path-bat-tracking]])

## AI tools / content automation
- [[podcast-transcription-pipeline]] — Whisper + pyannote + GPT-4 audio→threads pipeline
- [[2024-4th-place-ai-comp]] — the Driveline AI Impact Challenge entry (4th place) it was built for

## People / sources
- [[colby-morris]] (pitch design) · [[robbie-dudzinski]] (matchup reports)
- [[johnny-nienstedt]] (4S Pitching) · [[jack-kelly]] (public Stuff+) · [[driveline]] (research)

## Projects (personal archive)
[[dudz-batter-pitcher]] · [[og-pena]] · [[pitch-design-colby]] · [[swing-path]] · [[personal-bsbres]] · [[send-from-2b]] · [[youth-hp-analytics]]

## Youth / dev-tracking (Driveline-era)
- [[youth-hp-analytics]] — youth HP force-plate + velo tracking (R + SQL + Shiny)
- Methods: [[hp-trios]] (CMJ/SJ/IMTP strength snapshot) · [[gainers-analysis]] (rank biggest improvers)
- [[dsproj-data-science-examples]] — the ML side of the same HP force-plate data (RF/SVR/DT velo + bat-speed prediction, SHAP, radar comps, Blue Jays scoring)

## Live Astros surfaces these inform
- BR send/hold + advancement → ties to the [[2h-1to3-run-attribution-status|run-attribution work]]
- Pitch design → Arm Farm (`rules/arm-farm`)
- xwOBA → [[xwoba-canonical]]
- Modeling → [[promotion-models-status]]
- Org rollups / parity → [[multi-level-rollup]], [[three-surface-parity]]

> Growing: add a node whenever a new method/person/dataset shows up; link it both
> ways. The graph IS the value — orphans mean a missing link, not a dead end.
