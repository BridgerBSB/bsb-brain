---
type: concept
topic: loop-engineering
created: '2026-06-17'
---
# Maker–Checker Split

The single most useful structural move inside a [[loop-engineering|loop]]: keep
the agent that **writes** separate from the agent that **checks**.

The model that wrote the code is *"way too nice grading its own homework"*
(Addy Osmani). A second agent — different instructions, ideally a different
model — catches what the first talked itself into. This is exactly Anthropic's
**evaluator-optimizer** pattern from their Dec-2024 engineering post: one model
generates, another critiques, repeat. The 2026 vocabulary is 18 months old.

## Why it matters specifically in a loop
A loop runs while you're not watching. **A verifier you actually trust is the
only reason you can walk away.** Self-preferential bias (the maker rating its own
work A+) is a named [[loop-failure-modes|failure mode]] — the checker is the cure.

## Maps to our primitives
- Two separate `Agent` calls (the checker gets a clean context window + a critic mandate).
- Custom subagents in `.claude/agents/` (e.g. an explorer on a fast/read-only model + a verifier on a strong model, high effort).
- The Workflow tool's `pipeline` review stage — adversarially verify each finding before it ships.

Cost note: a second agent doubles token spend per item. Spend it where a second
opinion is worth paying for — not on trivial edits.

See [[loop-engineering]] · [[agent-teams-exploration]].
