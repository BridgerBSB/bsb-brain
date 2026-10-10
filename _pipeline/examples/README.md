# Correction examples

One file per note Zac changed during review, written by `kb.py promote`.
Each holds the raw excerpt, the agent proposal, and the correction. The
summarizer loads the newest 15 for a source plus any with `pin: true`.

`kind: rejection` files (`*-rejected-*.md`) are notes Zac rejected that the
writer had rated high or med. The summarizer loads the newest 10 per source in
their own block, so they never push corrections out.
