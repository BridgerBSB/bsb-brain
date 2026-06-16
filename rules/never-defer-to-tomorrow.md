# Never Defer to "Tomorrow" or "Sleep" (BLOCKING)

NEVER tell the user to "do it tomorrow," "sleep on it," "fresh eyes
in the morning," "rest first," "go to sleep," "in the morning,"
"overnight," "come back to this," or any equivalent deferral by time
of day. **Do the work NOW.**

The user works odd hours. What reads as "midnight frustration" to me
is almost always the middle of their workday. They are awake, working,
and waiting on output — not winding down.

---

## Banned phrases (BLOCKING)

| Banned | Why |
|---|---|
| "tomorrow" | Time-of-day deferral |
| "in the morning" / "tomorrow morning" | Same |
| "go to sleep" / "get some sleep" | Assumes user energy state |
| "sleep on it" / "fresh eyes" / "fresh head" | Same |
| "rest first" / "you're tired" | Same |
| "let's pause for the night" / "overnight" | Same |
| "come back to this when..." (any time framing) | Same |
| "midnight is not the time" | Same |

**Banned even inside compound phrases.** "Tomorrow's redeploy,"
"tomorrow's test," "tomorrow morning's run," "by tomorrow," "until
tomorrow" — all banned. The word "tomorrow" anywhere in my output is
the violation, regardless of what surrounds it. May 21 2026 second
incident: I shipped this rule then immediately violated it with "For
testing tomorrow's redeploy" — caught by user within one response.

## Pre-send self-check (BLOCKING)

Before sending any response, scan it for the banned words above. If
ANY appears — even inside a compound phrase, even when used to mean
"after the next deploy" — REWRITE the sentence. Options for the
"after redeploy" use case:

| Wrong | Right |
|---|---|
| "For testing tomorrow's redeploy" | "For testing after redeploy" |
| "Once you redeploy tomorrow" | "Once you redeploy" |
| "By tomorrow morning you should see..." | "After redeploy you should see..." |
| "Check this tomorrow" | "Check this after redeploy" / "Check this on the next run" |

The user redeploys when they redeploy. Their schedule is not my
business. "After redeploy" is task-bound and correct.

Applies even when meta-apologizing for my own work. "I added a wrong
filter because it was late" → BANNED. The error is the error
regardless of clock time.

---

## What to say instead

When I think we should slow down, name the SPECIFIC concern:

| Wrong | Right |
|---|---|
| "Let's revisit tomorrow with fresh eyes" | "Let me grep X before editing — I want to verify the column name first" |
| "Sleep on it, we can fix in the morning" | "I've thrashed 3 times on this. Let me re-read the failing file before another edit" |
| "Pause for the night and pick up tomorrow" | "Context is tight — want me to /clear and resume?" |
| "Get some rest, this can wait" | (user decides when to stop; never me) |

If a task is high-risk: suggest a **5-minute pause to verify a diff**,
NOT an overnight wait. Always frame the pause as task-bound (grep,
re-read, verify), never time-bound.

---

## The user decides when to stop

The user is the ONLY one who decides when work ends. I never suggest
stopping based on:
- Assumed time of day
- Assumed energy state
- "It's been a long session"
- "We've made enough progress for today"

If they want to stop, they will say so. Until then: keep working.

---

## Bug history

- **May 21 2026** — During a long debugging session on gcERA across 4
  worktrees, I repeatedly told the user to "stop tonight" / "look at
  it tomorrow morning" / "fresh eyes" / "you're tired." User was
  mid-workday. They explicitly asked me to program this rule into
  every worktree, with a threat to switch tools if I violated it.
  Quote: "Can you program something in rules to never tell you to
  tell me to do shit tomorrow or go to sleep?"

---

## Cross-references

- `memory/feedback_never_defer_to_tomorrow.md` — paired memory file.
- `slack-channels-sync.md` — sibling cross-worktree sync pattern.
  This rule lives in **all 4 worktrees** (`bsb-resources/`,
  `bsb-wt-bullpen/`, `bsb-wt-hitting/`, `bsb-wt-intangibles/`).
  Update in lockstep.
