---
type: concept
topic: loop-engineering
created: '2026-06-17'
---
# Loop Failure Modes

How [[loop-engineering|loops]] fail — quietly and expensively. Know these before
you build.

## The Ralph Wiggum loop (the canonical failure)
Named by Geoffrey Huntley. An agent meant to emit a "done" token only when
finished emits it **early**, and the loop exits on a half-done job — then keeps
spending. Happens when there's: no real verifier (just a second agent asked to
"review" with no objective signal = two optimists agreeing), soft completion
conditions (the agent's judgment, not a test), or no hard stop. **Fix = an
objective [[minimum-viable-loop|gate]]**: a test that passes/fails, a build that
compiles or doesn't. Not a verifier with an opinion.

## Other measured failure modes
- **Goal drift** — each summarization step is lossy; "don't do X" disappears by turn 47. Mitigate with a standing spec reread each run ([[loop-state-file]]).
- **Self-preferential bias** — the maker grades its own homework A+. Mitigate with a separate verifier ([[maker-checker-split]]).
- **Agentic laziness** — declares "done enough" at partial completion. Mitigate with `/goal` + an objective stop condition checked by a fresh model.

## The slow-burn risks (get worse as the loop gets BETTER)
- **Comprehension debt** — the loop ships code faster than you understand it; the bill is the day you debug a system no one read. *Read the diffs.*
- **Cognitive surrender** — accepting whatever the loop returns without forming an opinion.

## The security tax (an unattended loop is an unattended attack surface)
Unreviewed PRs merging; **skills as prompt-injection vectors** (audit sources
before installing — measured: 520 of ~17k skills leak credentials); credentials
scattered in debug logs; permission scope creep (re-audit every 30 days).

See [[loop-4-condition-test]].
