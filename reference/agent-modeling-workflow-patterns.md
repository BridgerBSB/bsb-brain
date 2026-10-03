---
type: reference
domain: engineering/ai-workflow
source: deep-research 2026-07-12 — 22 sources, 24/25 claims adversarially confirmed
tags:
  - claude-code
  - modeling
  - lineage
  - workflow
---
# Agent-Driven Modeling: Workflow Patterns (research synthesis)

Cited playbook for using Claude Code in iterative statistical/ML model work, to optimize how we build the promo/release models. From a fan-out deep-research pass (22 sources, 24/25 claims confirmed 3-0). **Primary sources only where marked.**

## 1. Lineage / versioning — validates our `[[lineage-skill]]`
- Anthropic's own long-running-agent pattern = a **persistent progress-log file** (`claude-progress.txt`) **+ descriptive git commits**, so a fresh-context agent reconstructs "what superseded what" from the log + git history. Our repo-root `LINEAGE.md` **is** that progress-log. *(anthropic.com/engineering/effective-harnesses-for-long-running-agents)*
- Dedicated ML tools formalize versioning — MLflow Model Registry auto-increments versions + links each to its run; W&B draws lineage graphs + audit history — **but NONE natively encode "superseded-by / deprecated / WHY."** That semantic gap is exactly what `/lineage` fills; don't expect a tool to give it to us. *(mlflow.org, docs.wandb.ai — primary)*

## 2. Multi-model comparison → parallel subagent tournament
- Final model choice is a **human, multi-criteria decision over many candidates** — not a single-metric auto-pick. Judge on error types, feature-importance stability, per-instance behavior, not just RMSE/AUC. *(Model LineUpper, ACM IUI 2021 — peer-reviewed)*
- **Subagents** (isolated context, parallelizable) are the native way to build/eval candidate models simultaneously without polluting the main thread → a future `[[model-tournament-skill]]`. *(Anthropic Agent SDK — primary)*

## 3. Cross-session continuity ("read-this-first" spine)
- Documented defenses: git-checked **CLAUDE.md** read-first artifact (keep it SHORT — procedure goes in skills); **spec-to-file + fresh named session** for handoffs; the API **Memory tool** / subagent `memory` field; end-of-session **summarize-and-refine** loop. *(code.claude.com/best-practices, sub-agents — primary)*
- Mechanism: **"context rot"** — recall degrades as tokens grow → externalize state, don't cram context. *(Anthropic cookbook; 2-1 vote — treat as argument FOR external lineage, not literal cause of fresh-session amnesia.)*
- ⚠️ **REFUTED (0-3):** "separate Claude instances preserve full context across days." They do not — reset happens; rely on artifacts, not instances.

## 4. Loop automation — YES, a real use case (answers the original question)
- **Headless mode** (`claude -p` + JSON) + **cron/routines** drive scheduled/fan-out batches: **nightly retrain-eval, drift checks, leaderboard refresh**. Maps to the canonical loop "gather → act → verify → repeat." *(best-practices, Agent SDK — primary)*
- **Flag (adopt-and-validate):** the *mechanism* is vendor-documented; the specific ML applications are our inference. Continuous-eval sources suggest **weekly/biweekly** batch eval, not daily — match cadence to how often player-dev data actually updates.

## ⚠️ Hallucination caveat
MLR-Bench (NeurIPS 2025) found coding agents produced **fabricated/invalidated experimental results in ~80% of open-ended ML tasks**. → Never trust an agent-run model result without an independent verify step. Ties to [[council-skeptic]] / [[verifier]]. *(Extracted but not in the verified-25 — flagged, not confirmed.)*

## Open questions (for us to decide)
1. Exact `/lineage` schema for explicit supersession (model_id, supersedes, superseded_by, deprecated_on, reason, metric-deltas) — frontmatter vs progress-log vs subagent memory?
2. Which multi-criteria dimensions fit promo/release models (calibration by level, feature-importance stability, per-player rationale, subgroup fairness)?
3. Is a scheduled loop worth it for our data cadence, or is on-demand enough?
4. Reconcile TWO persistence layers — Claude Code native `memory` vs the Obsidian `[[astro-world]]`-style vault — which is authoritative?

## Links
[[lineage-skill]] · [[promotion-models-STATUS]] · [[promotion-release-models]] · [[pd-onboarding-curriculum]] · [[MOC-astros-engineering]]
