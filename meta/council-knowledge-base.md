---
type: meta
created: '2026-06-29'
tags:
  - meta
  - teams
  - council
  - knowledge-base
  - curriculum
---
# 🎓 Council Knowledge Base — the curriculum every member is trained on

The shared knowledge the council members (`council-scout` · `council-data-scientist` ·
`council-ml-engineer` · `council-skeptic`) are grounded in. "Trained on knowledge" =
grounded in these canonical sources + scarred by these past failures. **Members READ the
source of truth before advising — never reconstruct a column or metric from memory.**

Companion to [[team-process-architecture]] (the roster + loops) and [[team-training-loop]]
(how the team improves). Situational map: [[ecosystem-map-and-process-architecture-2026-06-27]].

---

## 1. Situational awareness (the ecosystem)
4 live apps — **Barrelsville** (hitting) · **Arm Farm** (pitching) · **Intangibles**
(fielding) · **PD Engine** (hub) — + a 14-model modeling layer + daily/Monday delivery
cascades + tracker parquet-pins + the BSB Brain vault. *Coverage is huge; the friction is
in verification / parity / productization / analytics-foundations.* Full map in the
ecosystem note above.

## 2. Canonical truth — READ before advising (never guess a column or metric)
- `.claude/rules/reference-impl-index.md` — where every metric's canonical impl lives. **Open it before judging ANY metric.**
- `.claude/rules/db-columns.md` — column names, Astros vs MLBAM, IDs, PA semantics, the wOBA-vs-xwOBA denom split.
- `.claude/rules/db-joins.md` + `event-vs-pitch-anchored.md` — `cur_event_id` vs `ab_event_id`, the PA-inflation trap.
- `.claude/rules/blocking-rules.md` — the 18 non-negotiables.
- `.claude/rules/org-codes.md` — the 4-org canon (CHI/LA/NY + OAK→ATH) on every cross-source JOIN.
- `.claude/rules/level-codes.md` — `gc2_level_code` DSL/FCL split, junk levels.

## 3. Metric-canon cheat sheet (the must-knows)
- **T-SQL, not Postgres** — `ISNULL`/`TOP`, no `FILTER`, `CAST(bit AS int)` before `SUM`.
- **wOBA denom** = `AB+BB−IBB+HBP+SF` (IBB subtracted). **xwOBA denom** = `AB+BB+HBP+SF`, IBB **counted** as a walk (opposite). May 19 2026.
- **DSL/FCL via `gc2_level_code`**, never `sv.league`.
- **`is_whiff` gated by `did_swing`**, or Ctct%+Whf% > 100%.
- **Never round until display** (percentage-space, once).
- **Reliability ≠ a hard count gate** — n≥3 / ≥30 is volume, not stability; each metric stabilizes at a different `n` per level. (Tier-0 gap.)
- **No level/park/age adjustment exists org-wide** — raw cross-level deltas are contaminated. (Tier-0 gap.)

## 4. The scars (golden set — failure modes the team MUST catch)
- **R²=0.41 called "strong"** → really 0.09 once circular rows stripped. *(The council's origin.)*
- **v2 wRC+ 0.41→0.09** MiLB-only mirage → parked.
- **FB% read as fastball-usage** instead of flyball% — disambiguate a metric's MEANING before coding it.
- **Org-code drop: 29 of 30 orgs** — a "29-org leaderboard" is a bug (missing OAK/ATH + CHI/LA/NY remap), not a finding.
- **Stray "P" under the logo** — a visual shipped without render-and-look.
- **DSL/FCL opponent leak** — shared `SPORT='rok'`; discriminate on `MLBAM.Teams.league`.
- **Damage% rounding drift** — decimal-space vs percentage-space.
- **Swallowed SQL error** — `reaction_time` alias-not-column; `logger.warning` hidden on Connect (use `print`).
- **Org-attribution by majority-org** — Moss flickered between orgs; attribution must be per-PA.

## 5. The methodology
[[team-process-architecture]] (3 teams · 3 loops) · [[team-training-loop]] (capture→diagnose→update→eval + this golden set as regression tests) · [[advisory-council]] · [[loop-engineering]].

## 6. How a member grounds itself (the standing instruction)
Before any claim touching SQL / metrics / a column name → Read the relevant §2 source.
Before calling anything "good/strong" → run the §3 + §4 checks. Given data → **compute,
don't eyeball.** Cite `file:line`. When you catch a NEW failure mode → flag "add to the
golden set" so it becomes a permanent regression test.

## 7. Continuing education — vetted external methodology (grows via /research)
Captured + summarized external sources every member inherits. Each note carries
"Takeaways for us" mapping the idea onto OUR stack — read the note, not just the link.
- [[promote-release-external-research]] — Mould prospect model (leaky-label AUC lesson) · KATOH per-level probits (per-level feature validity) · KILA peer-group wRC+ (r=.423 = honest ceiling on continuous targets). Core curriculum for council-data-scientist judging OUR 0.79–0.80 AUC honestly.
- [[rag-architectures]] — Standard/Graph/Agentic RAG chosen by QUERY PATTERN, not as tiers; IdeaBlocks (atomic Q-A > chunks, −40× corpus / +2.3× relevance) validates the vault's atomic-note design. For council-ml-engineer + any retrieval build.
- [[pytorch-training-pipeline]] — the DL training-loop one-pager; bench depth for when a problem is representation-learning-shaped (Command CV YOLO is nearest candidate), NOT tabular promote/release.
- [[loop-engineering]] — discovery/handoff/verification/persistence/scheduling agent-loop patterns (the verification-agent-assumes-broken principle §4 already encodes).
- [[command-cv-external-research]] — OpenCommand (public, Aug 2026): command = |actual plate loc − catcher glove target| from video. Methodology to inherit: **calibrate the camera on a KNOWN 3D object (the ball's Statcast trajectory), never on the object you are measuring** (their geometry error 0.35 in vs our glove-fit affine's 3.9 in) · pin non-identifiable parameters and PROVE the degeneracy (free camera depth rails at bounds, moves targets 0.06 in) · physical-reachability filtering beats retraining for detector misfires · publish a coverage funnel · anchor a new metric to an external correlate (BB% Spearman +0.547). Plus the trap: their "inferred target" subtracts each pitcher's own mean residual, so it measures **dispersion only** and improves the headline ~1 in by construction — the `prescriptive-claims` #1 class. For council-ml-engineer + council-pitching + anyone building a CV metric.
- [[savant-fielding-visuals-research]] — Savant's OF "Responsible Plays" mechanics: one responsible fielder per batted ball (out/error = who made it; hit = closest to landing spot from start pos at pitch release — responsibility is pre-outcome), catch-prob inputs (opp time from RELEASE, distance needed, back/wall adjustments), star buckets (5★ 0–25% … 1★ 91–95%), and the dash grammar (opportunity bins w/ exp-vs-actual catch rate, outs/hits hulls, sprint-speed rings, league difficulty bands). Curriculum for council-fielding on any range/OAA build.
- [[agent-engineering-layers]] - the five-layer stack (prompt / context / harness / loop / graph) + the Anthropic 6-pattern agent taxonomy + a retrieval decision tree. Two ideas every agent should carry: **a repeated context failure is a HARNESS bug** (what the tooling auto-injects), not a prompt bug, so telling the model to be careful can never fix it; and **the cost of opening a file is a property of its PATH, not its size** (one 350-line read pulled 40 rule files / ~140K via glob-matched injection). Also the corrected fetch ladder (jina r.jina.ai now 401s). For any agent, tooling, or retrieval build.
- [[context-library]] skforecast-ai (Rami Krispin, Aug 2026) - forecasting agent whose architecture is the one to copy: a **deterministic core that runs offline and backtests on MAE/MSE/MASE**, with the LLM confined to an **optional explanation / plan-refinement layer**. Direct read-across to the promotion models: the number must be interrogable on its own, because getting a coordinator to trust a number they cannot interrogate is the real constraint, not model sophistication. For council-data-scientist + council-ml-engineer.

**Feeding this section:** `/research <links>` captures + summarizes into the vault; if
the source is methodology the council should inherit, the capture ALSO adds a line here.
That's the "training pipeline" for the team: capture → takeaways-for-us → this curriculum
→ every member reads it at grounding time.

- **Linear weights are environment-specific — borrowing them across levels biases the number, not the rank** (2026-08-05). NCAA D1 league wOBA is ~47 pts HIGHER than MLB (.363 vs .316) while every D1 event weight is LOWER relative to an out (HR 1.74 vs 2.045), because cheap runs make each event worth less. So MLB weights applied to a college line inflate twice over. But when the comparison pool is also college and also MLB-weighted, the bias is common-mode and the percentile survives. Rule of thumb for any borrowed-weight metric: **ship the rank, not the absolute, and never reuse the canonical metric's name.** Full research + FanGraphs/NCAA constants: [[college-eoy-xwoba-weights]].
