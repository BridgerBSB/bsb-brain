---
name: opt-in CLI flags, never implicit smart behavior
description: User wants explicit control over CLI behavior — auto-features that fire based on absence of other flags are too magical
type: feedback
originSessionId: 0506d4f2-0a41-4377-8757-ea1a547d55b5
---
When adding a non-default behavior to a CLI script (auto-split, auto-fallback, auto-anything), make it an **explicit opt-in flag**. Never trigger it implicitly based on the absence of another flag.

**Why:** I shipped pitcher-analysis auto-split that fired whenever `--deliver` was set without `--levels`. User pushed back: they want explicit control. Implicit behavior was confusing — they expected the default delivery to remain a single PDF (which would fail HTTP 413), and `--split` to be a separate opt-in. Magic that fires "when needed" robs the user of predictability.

**How to apply:**
- Default behavior = simplest, predictable thing
- New non-default behavior = its own flag (`--split`, `--early-mode`, `--strict-only`, etc.)
- Failure modes that signal "you need the flag" (HTTP 413 in this case) are fine — let the user re-run with the flag rather than auto-flipping
- Never use "absence of flag X" as a trigger for "do feature Y"

The first split shipped (level-grouped) was also wrong shape — split by level filters each group's pitches by level, which breaks the picture for multi-level pitchers. Final design: 50/50 list-halving, full data per pitcher, opt-in `--split` flag.

Pattern: when in doubt about whether to auto-fire, default to "user must opt in".
