---
type: concept
domain: engineering/ai-workflow
source: session 2026-07-15 — parked idea
status: parked
---
# Selective rule-loading (parked idea)

**Problem (observed twice, 2026-07-15):** `load-rules` is **all-or-nothing** — it loads
all ~35 `.claude/rules/*.md` regardless of task, eating **~50% of context** on rules that
are usually irrelevant. E.g. a pd-goals goal-number edit (`prp_tab.py`) loaded
`bat-speed-canonical`, `fielding`, `xwoba-canonical`, `pitch-codes` — none applicable.

**Proposed fix (not yet built):**
- **Selective load** — an always-on cheap INDEX (rule names + one-liners, ~30 lines);
  the agent pulls only the 2–3 rules the task's files/topic actually touch (use
  `reference-impl-index` as the map).
- **Path-scope** rules via `paths:` frontmatter (documented Claude Code feature; see
  [[claude-code-optimization]] §8) → a rule loads only when matching files are touched.
- Keep a **`--all` / subagent-fork mode** for the rare full-canon case (metric-parity
  PR review), where isolation ([[agent-modeling-workflow-patterns]]) keeps the 35 rules
  out of the main window.

**Next step when un-parked:** read the `load-rules` skill, confirm *why* it loads all,
then convert to selective. Diagnose before changing (skill lives in bsb-resources).

## Links
[[claude-code-optimization]] · [[agent-modeling-workflow-patterns]] · [[lineage-skill]]
