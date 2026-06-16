---
name: feedback-stay-on-branch
description: NEVER touch other worktree branches unless explicitly told to — stay on the current branch/worktree
type: feedback
---

NEVER edit files on other worktree branches unless the user explicitly says to.

**Why:** User has separate Claude sessions running on each worktree (Barrelsville, Arm Farm, etc.). Editing files on another branch causes conflicts with the agent already working there and wastes time with reverts.

**How to apply:** If the user says "do what Barrelsville does" or "copy that pattern" — apply the change to the CURRENT worktree/branch only. Never go touch the source branch. Read the pattern from the other worktree if needed, but only WRITE to the current one.
