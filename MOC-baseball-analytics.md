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
- **Independent leagues** → project: [[indyball-tracker]] (4 MLB-partner indy leagues, season hitting+pitching)

## Methods / modeling (the connective tissue)
- [[statcast-pipeline]] — the shared data spine under almost every project
- [[statcast-bulk-fetch]] — the pybaseball bulk-pull + retry/chunking pattern feeding it
- [[advanced-modeling-setup]] — vendoring public pitch-model repos (4S / Stuff+) for AI context
- [[lightgbm-baseball-modeling]] — gradient-boosted decision models → [[send-from-2b]], Astros [[promotion-models-status]]
- [[dsproj-data-science-examples]] — force-plate → velo/bat-speed prediction corpus: [[velo-prediction-rf]] · [[support-vector-regression-baseball]] · [[decision-trees-baseball]] · [[radar-chart-viz]] · [[percentile-rank-scoring]] · [[hp-cross-db-pipeline]]
- [[xwoba]] · [[re24-run-expectancy]] · [[stuff-plus-4s-pitching]] · [[pitch-design-logic]] · [[swing-path-bat-tracking]]
- Viz: [[strike-zone-kde]], 3D Plotly swing arcs ([[swing-path-bat-tracking]])

## Infra / scraping
- [[datacenter-ip-waf-block]] — why some external scrapers fail on Connect (datacenter-IP WAF) and the residential-IP→pin fix

## AI tools / content automation
- [[podcast-transcription-pipeline]] — Whisper + pyannote + GPT-4 audio→threads pipeline
- [[2024-4th-place-ai-comp]] — the Driveline AI Impact Challenge entry (4th place) it was built for

## People / sources
- [[colby-morris]] (pitch design) · [[robbie-dudzinski]] (matchup reports)
- [[johnny-nienstedt]] (4S Pitching) · [[jack-kelly]] (public Stuff+) · [[driveline]] (research)

## Projects (personal archive)
[[dudz-batter-pitcher]] · [[og-pena]] · [[pitch-design-colby]] · [[swing-path]] · [[personal-bsbres]] · [[send-from-2b]] · [[youth-hp-analytics]] · [[indyball-tracker]]

## Youth / dev-tracking (Driveline-era)
- [[youth-hp-analytics]] — youth HP force-plate + velo tracking (R + SQL + Shiny)
- Methods: [[hp-trios]] (CMJ/SJ/IMTP strength snapshot) · [[gainers-analysis]] (rank biggest improvers)
- [[dsproj-data-science-examples]] — the ML side of the same HP force-plate data (RF/SVR/DT velo + bat-speed prediction, SHAP, radar comps, Blue Jays scoring)

## Live Astros surfaces these inform
- BR send/hold + advancement → ties to the [[2h-1to3-run-attribution-status|run-attribution work]]
- Pitch design → Arm Farm (`rules/arm-farm`)
- xwOBA → [[xwoba-canonical]]
- Modeling → [[promotion-release-models]] (concept + map) · [[promotion-models-status]] (status pointer)
- Org rollups / parity → [[multi-level-rollup]], [[three-surface-parity]]

> Growing: add a node whenever a new method/person/dataset shows up; link it both
> ways. The graph IS the value — orphans mean a missing link, not a dead end.


## Ways of working (AI / process)
- [[context-library]] — running index of AI / DS / baseball reference links + sources we feed Claude
- [[advisory-council]] — standing persona "voices" (Data Scientist, ML Engineer, Scout, Skeptic) invoked on hard calls
- [[promotion-release-models]] — the v1/v2 promotion+projection project (concept + deep dive)

## Ideation / backlog
- [[council-new-tools-ideation-2026-06-26]] — first full council convening (4 subagent lenses) → 32 new-tool ideas synthesized into a ranked backlog. Top shared gaps: workload/injury risk + level/park/age adjustment + reliability shrinkage.

## Ecosystem map / process architecture
- [[ecosystem-map-and-process-architecture-2026-06-27]] — full inventory of all 4 apps + modeling + automation + vault, synthesized into a gap-driven process architecture (3 teams · 3 loops · 2 build-now workstreams). The guiding-light map.

- [[milb-mlb-promotion-calendar]] — when promotions actually happen (MiLB season-end by level, MLB Sep-1 expansion, rookie/PPI dates); drives label-maturity logic for [[promotion-release-models]]

## Home dashboard
- [[Command-Center]] — the vault home: live Bases boards for the idea backlog + projects/process, plus links to every MOC. Start here.
