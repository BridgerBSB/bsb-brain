---
name: ALWAYS surface PowerShell execution-policy bypass in deploy walkthroughs
description: Every Connect deploy walkthrough I give MUST start with the Set-ExecutionPolicy bypass command, copy-pasteable with hyphens visible, BEFORE the deploy.ps1 invocation. Don't bury it under "you may need." Show it upfront, every time.
type: feedback
originSessionId: 5de55ffe-8c6f-460b-a14d-68a74c52a701
---
When walking the user through ANY Connect deploy that uses
`connect_pins/deploy.ps1` (or any local .ps1 script), the FIRST line of
the walkthrough MUST be the execution-policy bypass:

```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Note the hyphens before `Scope` and `ExecutionPolicy` — they are
non-negotiable. PowerShell reads `-Scope Process` as a named-parameter
flag; without the hyphen it sees `Scope` as a positional argument and
errors with "A positional parameter cannot be found that accepts
argument 'Scope'."

**Why:** May 3 2026, deploy walkthrough for Barrelsville + Arm Farm
pin-tracker contents. I mentioned the bypass but only after the user
asked, then the command I gave got line-wrapped in their narrow
PowerShell window so the hyphens looked easy to miss. User typed it
without dashes and burned ~10 min troubleshooting twice. Already
documented in `.claude/rules/tracker-parquet-pins.md` §12.4 as a known
issue, but I failed to surface it proactively in the walkthrough.

**How to apply:**
- Every walkthrough that says "run `.\deploy.ps1`" MUST also say
  "run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
  first" — show it as the first command, not a footnote.
- Format it as a code block on its own line, with the hyphens clearly
  visible. Don't run-on with other text.
- Note it's per-session — closes when the PowerShell window closes,
  must be re-run for each new shell.
- This applies to ALL `connect_pins/deploy.ps1` invocations across all
  4 trackers (Barrelsville, Arm Farm, BR, Catcher) — every one of them
  is unsigned and triggers the same block.

**Pattern for deploy walkthroughs:**

```powershell
# Step 1 — bypass policy for this session (per-session only, safe)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Step 2 — deploy
.\deploy.ps1
```

Always two steps. Always Step 1 first. Always with hyphens visible.

**Tripwire:** if my walkthrough mentions `.ps1` and doesn't mention
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` as a
preceding step, I missed it.
