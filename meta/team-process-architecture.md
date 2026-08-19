---
type: meta
created: '2026-06-29'
tags:
  - meta
  - teams
  - process
  - ways-of-working
  - advisory-council
---
# 🛠️ Team & Process Architecture — operating doc

How the agent **teams** and **loops** actually run. Born from the Jun 27 ecosystem map
([[ecosystem-map-and-process-architecture-2026-06-27]]): coverage is huge, the friction is
in verification / parity / productization / foundations. This doc is the org chart + the
playbook. Sits next to [[advisory-council]] (the critique team) and [[loop-engineering]]
(the methodology). Train the teams via [[team-training-loop]].

---

## The 3 standing TEAMS (by process, not topic)

### T1 — Critique Council  *(LIVE)*
The 4 lenses — `council-scout` · `council-data-scientist` · `council-ml-engineer` ·
`council-skeptic`. **Job:** "is this good / what's wrong with it." **Invoke:** spawn the 4
in parallel on any consequential model/metric/architecture call. **Gate:** nothing ships
that the Council hasn't argued against. (Born from the R²=0.41 over-claim miss.)

### T2 — Build Squad  *(NEW — the missing execution loop)*
The Council critiques but doesn't *build*. T2 is the **maker → checker → verify** loop that
actually ships a tool:
1. **Maker** — a build agent (or the voltagent ML/data agents) implements against a spec.
2. **Checker** — the Council critiques the implementation (not just the idea) BEFORE merge.
3. **Verify** — `verification-before-completion` + (for visuals) `render-and-look` +
   (for DB code) the L1 verification loop. Evidence before "done."
**Invoke:** drive maker→checker→verify in sequence; first job = **ACWR** ([[acwr-workload-monitor]]).

### T3 — Research / Tooling Analyst  *(DEFINED, not yet stood up)*
Vets external resources ([[context-library]]) + new ideas against the ecosystem; flags
new-vs-already-built (what the doc-fork did by hand for the 9 links). Stand up when L3's
cadence needs a dedicated triager.

---

## The 3 standing LOOPS (recurring cadences)

### L1 — Parity & Verification  *(closes the biggest gap: untested-on-live-DB + 3-surface drift)*
Two halves:
- **(a) Change-triggered:** any metric/surface edit → run `metric-audit` across the 3 surfaces
  (tracker / KPI weekly / org) + dual-query + app↔report → emit a parity diff.
- **(b) Work-laptop post-pull sweep:** smoke-test everything on the **verification backlog**
  (`bsb-resources/docs/verification-backlog.md`) + scan for the silent-failure signatures
  (hidden `logger.warning`, Logic-App-200, unset `CONNECT_API_KEY`, phase-exit-0-while-Slack-fails).
This turns the split-laptop tax into a checklist an agent runs. **First output shipped:** the
verification backlog registry.

### L2 — One-off → Product mining
Periodically mine the 123 SQL one-offs + diagnostic sprawl, cluster what recurs (velo-jumps,
player-lookup/ID-bridge, parity-audits, draft/amateur, leaderboards, IP/workload), promote
≥N-recurrence clusters to parameterized tools/pages. Stops re-writing the same query.

### L3 — Backlog governance
Council reviews the 17-tool backlog ([[council-new-tools-ideation-2026-06-26]]) + logged ideas
on a cadence (ride `/sunday`), assigns owners, promotes the next 1–2 to a T2 build /goal.

---

## The 2 build-now WORKSTREAMS
- **W1 — Tier-0 Analytics Foundations:** reliability/empirical-Bayes shrinkage + level/park/age
  adjustment. Highest leverage; hardens every existing surface.
- **W2 — Infra hardening:** finish the Connect→DB offload; a **stable model-artifact archive**
  (out of `Downloads\`); a shared org-code canon helper; cut the cross-worktree sync tax.

---

## How a tool flows (the pipeline)
```
L3 backlog  →  T2 Build Squad (maker → T1 council checker → verify)  →  ship  →  L1 guards it
                                   ↑ misses + wins feed → team-training-loop
```

## What NOT to do
- Don't ship a DB-touching surface without an L1 entry + a work-laptop verify.
- Don't add a metric to one surface only (3-surface + app/CLI parity).
- Don't let backlog ideas accrue without an L3 owner.
- Don't conflate T1 (critique) with T2 (build) — they're different processes.


---

## Roster update — Jun 29 2026 (members built)

The teams above now have real members (all invokable agent types, trained on [[council-knowledge-base]]):
- **T1 Critique Council** = `council-data-scientist` · `council-ml-engineer` · `council-scout` · `council-skeptic` (upgraded) **+ domain depth** `council-pitching` · `council-hitting` · `council-fielding`.
- **T2 Build Squad** — `verifier` owns the verify gate (L1); makers = the domain specialists + voltagent agents; checker = the Council.
- **T3 Research / Tooling Analyst** = `research-analyst` (built).
- **Writing persona** (new category, feeds reports/questionnaires) = `player-evaluator` + its KB `projects/player-evaluator/`.
- **L1 loop** is owned by `verifier`. Full roster in [[advisory-council]].
