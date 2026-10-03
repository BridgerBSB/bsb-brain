---
date: 2026-09-24
tags:
  - claude-code
  - context
  - rules
  - meta
source: bsb-resources a4a04835
---
# Rule loading guard - Sep 24 2026

**What happened:** Claude Code warned at session start: *"19 instruction files add up to 151.3k chars, over the 150.0k-char total limit."* Always-on rules had crept from 11 (after the Aug 20 cleanup, see [[context-bloat-fix-plan]]) back to 17.

**Why:** a rule file written without `paths:` frontmatter loads on EVERY turn by default. Six rules were written that way:
- `pitch-grade-variants` (Arm Farm)
- `weights-sum-to-100` (promo-engine)
- `index-and-time-origins`, `long-jobs-on-this-laptop`, `metric-must-separate-failure-modes`, `probe-capability-before-accepting-a-blocker` (command-cv)

The routing guard (`.claude/scripts/test_rule_routing.py`) already had an always-on census that would have caught it. **It was red and nobody knew, because nothing ran it automatically.**

![[assets/rule_loading_map_2026-09-24.png]]

## The fix (3 layers)

1. **Route, don't delete.** The six got `paths:` globs, so they load only when a matching file is opened. ~39k chars off every turn (151k -> ~112k).
2. **Index.** `blocking-rules.md` (always-on) has a "Domain BLOCKING rules loaded by path" section with one pointer line per rule, so every session knows they exist.
3. **Automatic guard.** `sync-rules.sh` (the PostToolUse Write|Edit hook) now runs the guard on every `.claude/rules/` edit. Silent on pass, fails loudly on a paths-less rule. Zero context cost. Proven red on an injected fake rule.

## Rule for new rules
Every new rule = `paths:` frontmatter + a pointer line in `blocking-rules.md`. Always-on only by a deliberate entry in `ALWAYS_ON_INVENTORY` (costs every turn, forever). Also written into the `document-pattern` skill.

## Caveats
- The hook fires on the Write/Edit tools only. A rule written via a Bash heredoc skips it - run `python .claude/scripts/test_rule_routing.py` by hand.
- Sibling worktrees got the files copied (working copy, not committed there) and pass the guard. `bsb-wt-modeling` has its own `blocking-rules.md`; the pointer section was appended, not overwritten.

## What NOT to do
- Don't delete rules to save context - route them.
- Don't trim `blocking-rules.md` to pointers - it is the index that makes everything findable.
- Don't rely on memory to carry this - it is per-machine.

Source: `bsb-resources` commit `a4a04835` on `feature/pd-goals`; full write-up in `.claude/rules/rule-loading-architecture.md`.
