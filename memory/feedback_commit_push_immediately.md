---
name: feedback-commit-push-immediately
description: "After writing ANY new file or making code changes on a worktree, commit AND push immediately — never leave new files uncommitted, even briefly, even for \"diagnostic\" or \"scratch\" work"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3ab21951-afd2-48a7-9e6b-354b31f57d5c
---

After writing ANY new file or modifying code on a worktree, **commit AND push in the same response** as the write. No exceptions for "diagnostic scripts," "scratch work," "let me see if this works first," or "I'll commit later."

**Why:** The user runs every script on the work laptop, which only sees what's pushed to the feature branch. Telling the user to "run this script" without committing it first means they `git pull` and the script doesn't exist — wasted iteration, wasted user time, broken trust. This rule pairs with the existing "Auto-push to worktrees" preference but adds the dimension that the COMMIT step also has to be immediate, not delayed.

**How to apply:**
- After every `Write` of a new file in a worktree → next tool call is `git add` + `git commit` + `git push`. Same response.
- After every `Edit` to existing code in a worktree → same. Don't batch edits across responses hoping to commit "at the end."
- If you wrote a file and forgot to commit, the next thing you do is commit it, BEFORE telling the user how to run it.
- Diagnostic scripts, throwaway one-offs, exploration tools — all of these get committed too. The user needs to be able to pull them.
- The user's CLAUDE.md says "blanket permissions granted" — push without asking.
- If you're unsure which branch the worktree is on, run `git branch --show-current` once, not every time. Personal laptop has worktrees on the right feature branches by default.

**Failure pattern that triggered this rule (May 18 2026):** wrote `barrelsville/scripts/diagnose_gcoba_pool.py` to disk, told user to run it on work laptop. User did `git pull` — only got unrelated rules updates — then `python scripts/diagnose_gcoba_pool.py` failed with "No such file or directory." Wasted a round trip because the file existed locally but never made it to the remote.

**See also:**
- [[user-preferences]] (the existing "Auto-push to worktrees: Always push after committing" rule — this expands it)
- [[feedback-assume-redeployed]] (same family: don't ask about deploys / pulls, assume them done after you push)
