---
type: project
created: '2026-06-27'
tags:
  - ecosystem-map
  - process-design
  - teams
  - strategy
  - guiding-light
  - advisory-council
---
# 🗺️ PD Analytics Ecosystem Map + Process Architecture (Jun 27 2026)

The **guiding light**: a full inventory of everything we run + everything logged,
synthesized so the **gaps design the teams/loops we stand up next.** Built from a
6-agent parallel sweep (4 apps + cross-cutting infra + the vault). Per-domain detail
lives in the agent runs; this is the synthesis.

Related: [[council-new-tools-ideation-2026-06-26]] (the 17-tool backlog) ·
[[acwr-workload-monitor]] · [[advisory-council]] · [[loop-engineering]] ·
[[connect-offload-migration]] · [[MOC-baseball-analytics]]

---

## 1. What we have (the snapshot)

**4 live apps + a modeling layer + a hub, all on Posit Connect:**

| Domain | App | LIVE surfaces (sample) |
|---|---|---|
| Hitting | **Barrelsville** | Postgame (+Visuals, Contact Map, Swing Path 3D), Affiliate Tracker, Advance, Blast Motion, KPI weekly, ~15 one-off CLIs |
| Pitching | **Arm Farm** | Side Reports, Postgame (+0-0/0-1, daily tracker), Affiliate Tracker (+pitch-efficiency), Advance (+Matchup Optimizer), KPI, **Pitch Similarity Finder** |
| Fielding | **Intangibles** | OF/IF/BR/Catcher trackers, 4 postgames, 4 KPI weeklies, Fielding Advance, OF Positioning, cPAA/EO review, AC Dashboard |
| Hub | **PD Engine** | PD Goals, Goal Compliance, PRP, Transition, WPA Plays, Org Board, Team View, Defense Matrix, Player Card, Pitch Arsenal, Hitter Approach, Cohort Explorer, Compare, Org Pulse, Injury Tracker |
| Models | **modeling/** | 14 LightGBM (promote/release/stickiness) — code-complete; v2 wRC+ **PARKED** (R² mirage) |

**Automation already running:** `run_daily.ps1` (11-phase game-day cascade) + `run_monday.ps1`
(weekly, stapler barrier) · tracker parquet-pins (6h Connect refresh) · in-app-submission
(form→pin→PDF→Slack) · drift/flag tracker · cross-worktree rule sync.

**Standing tooling:** the 4-lens **council** (now real subagents) · GSD + superpowers skill
suites · repo skills (baseball-sql, metric-audit, tracker-new-metric, new-report, new-visual,
document/ingest, memory-cleanup) · the **BSB Brain** vault as the durable knowledge layer.

> [!important] The honest one-line verdict
> Measurement and delivery coverage is enormous; almost all the friction is in
> **verification, parity, productization, and analytics foundations**, not in building
> more surfaces.

---

## 2. The cross-cutting gaps (these design the teams)

Clustered from gaps that recurred across **multiple** domain maps:

**G1 — Split verification loop (work-laptop-only DB).** All DB-touching code is written
blind on the personal laptop, pulled, tested later. Dozens of surfaces sit "UNTESTED on
live DB" (Pitch Similarity, Trend Leaderboards, pitch-efficiency, contact-quality, swing-
decision grader, zero-count phase 2…). *No in-session verification.* **Biggest structural tax.**

**G2 — Parity sprawl.** Every metric lives in 3+ places (tracker / KPI weekly / org) AND
often an app+CLI pair. A single-surface edit silently drifts values; held together only by
discipline + the metric-audit/three-surface-parity rules.

**G3 — Silent failure modes.** `logger.warning` hidden on Connect, Logic App 200s on
malformed payloads, `CONNECT_API_KEY` per-session, phase exits 0 while Slack sends fail.
Many BLOCKING rules exist *only* to catch these.

**G4 — One-off & diagnostic sprawl.** 123 ad-hoc SQL files (no index) + 15–40 `debug_/
diagnose_/explore_` scripts per worktree. Institutional knowledge living in throwaway
scripts. Recurring clusters (velo-jumps, player-lookup/ID-bridge, parity-audits, draft/
amateur, leaderboards, IP/workload) get **rewritten per request**.

**G5 — Analytics foundations missing (council Tier-0).** No reliability/shrinkage layer,
no level/park/age adjustment. Flagged "poisons everything if absent." **Highest-leverage
unbuilt work** — and it would harden every surface already shipped.

**G6 — Backlog has no owners.** 17 council tools + a long logged-idea list; only ACWR is
green-lit. Ideas accumulate faster than they're assigned.

**G7 — Infra strain & durability.** Connect CPU/RAM saturation (offload migration active);
model artifacts live only in `Downloads\` (no stable archive); org-code canon hand-coded
across many JOIN sites; rules + `slack_channels.csv` byte-identical across 4–5 worktrees
(manual sync tax); context rot on a 73KB MEMORY.md.

**G8 — Model production-readiness uncertain.** v1 STATUS says LIVE but memory says deploy
pending; v2 parked after the R²=0.41→0.09 mirage; promotion-velocity has 3 unfixed QA bugs.
Calibration/"is it actually live & honest" discipline is ad-hoc.

---

## 3. Proposed process architecture (3 teams · 3 loops · 2 build-now)

Designed so each piece closes named gaps. Informed by the captured resources
([[loop-engineering]] maker/checker + gated loops; the Claude agent-teams feature).

### Standing TEAMS (by process-type, not topic)
- **T1 — Critique Council** *(exists, keep).* The 4 lenses for "is this good?" Convene on
  consequential model/metric/architecture calls.
- **T2 — Build Squad** *(new).* A maker→checker→verify loop for actually shipping a chosen
  tool: TDD + verification-before-completion + a council critique gate before merge. Uses
  the voltagent ML/data agents for execution. This is the missing **execution** process
  (council is critique, not build). First job: ship **ACWR**.
- **T3 — Research/Tooling Analyst** *(deferred per Zac — home identified).* Vets external
  resources ([[context-library]]) + new ideas against the ecosystem; flags new-vs-already-
  built (what the doc-fork did by hand). Stand up when the backlog cadence needs a triager.

### Standing LOOPS (recurring cadences)
- **L1 — Parity & Verification loop** *(closes G1, G2, G3, G8).* The biggest friction-killer.
  Two halves: (a) on any metric/surface change, auto-run metric-audit across all 3 surfaces +
  dual-query + app↔report and emit a parity diff; (b) a **work-laptop post-pull sweep** that
  smoke-tests everything flagged "UNTESTED on live DB" and scans for the silent-failure
  signatures. Turns the split-laptop tax into a checklist an agent runs.
- **L2 — One-off → Product mining loop** *(closes G4).* Periodically mine the SQL/diagnostic
  corpus, cluster what recurs ≥N times, and promote it to a parameterized tool/page (velo-jump
  → standing board; player-lookup → generic ID-bridge utility; parity-audits → the metric-audit
  skill). Stops re-writing the same query.
- **L3 — Backlog governance loop** *(closes G6).* Council reviews the 17-tool + logged-idea
  backlog on a cadence (ride `/sunday`), assigns owners, promotes the next 1–2 to a Build-Squad
  /goal. Keeps ideas from rotting.

### Build-now WORKSTREAMS (funded builds, not standing)
- **W1 — Tier-0 Analytics Foundations** *(closes G5).* Reliability/empirical-Bayes shrinkage +
  level/park/age adjustment. Highest analytics leverage; hardens every existing surface.
- **W2 — Infra hardening** *(closes G7).* Finish the Connect→DB offload; stand up a **stable
  binary archive** (model artifacts out of Downloads); a shared org-code canon helper; reduce
  the cross-worktree sync tax.

---

## 4. Recommended first moves (sequenced)

1. **Stand up T2 (Build Squad) and run ACWR through it** — proves the maker/checker loop on
   the one already-green-lit tool.
2. **Build L1 (Parity & Verification loop)** — the single biggest friction-killer; pays back
   on every future change and clears the "UNTESTED on live DB" backlog.
3. **Fund W1 (Tier-0 Foundations)** — highest analytics leverage; everything downstream
   (including the parked v2 model) gets better.
4. Then L2/L3 as cadences; T3 + W2 as the backlog and infra pressure dictate.

Everything else (the 17-tool backlog) flows through L3 → T2 once these rails exist.
