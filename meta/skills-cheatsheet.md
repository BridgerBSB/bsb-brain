# Skills Cheat-Sheet — reach for these instead of typing the ritual

The point: most recurring things you ask Claude to do already have a **skill**
that does them the same, correct way every time. Type `/<name>`. When in doubt,
skim this. Built 2026-07-08. Cross-ref: [[claude-session-skill-sequence]],
[[claude-usage-audit-2026-07-02]].

> **How to build the habit:** at the START of a session run `/brief`; at the END
> run `/wrap`. In between, before you hand-do a recurring task, ask "is there a
> skill for this?" — the answer is usually yes.

---

## 🔁 Ops rituals (the cascades)
| Skill | Reach for it when |
|---|---|
| `/monday` | Run the full Monday cascade across all 4 worktrees |
| `/dry-monday` | Rehearse Monday — generates PDFs, **NO** Slack delivery |
| `/repin-goals` | You edited `goals.csv`, need it live on Connect |
| `/scaffold-pin-deploy` | Standing up a NEW tracker pin/deploy bundle |
| `/audit-deploys` | Verify every `connect_pins*/deploy.ps1` matches its import graph |

## 🏗️ Building things — HIGHEST VALUE, use every time
| Skill | Reach for it when |
|---|---|
| `/new-report` | Building ANY new report — forces reading reference impls first + matching SQL/PDF/delivery |
| `/new-visual` | ANY new chart / zone grid / spray / heatmap / table — enforces visual standards + render-and-look |
| `/metric-audit` | Add / change / remove ANY metric — checks parity across every app that has it |
| `/tracker-new-metric` | Add/modify a metric in any affiliate tracker — forces disambiguation Qs BEFORE code |

## 🔗 Cross-worktree hygiene
| Skill | Reach for it when |
|---|---|
| `/add-slack-channels` | New channel name+ID → syncs all 5 `slack_channels.csv` + checksum-verifies |
| `/document-pattern` | A fix/pattern other worktrees need → writes the `.claude/rules/` file + propagates |
| `/sync-rules` | Byte-copy `.claude/rules/` + `.claude/scripts/` to the 3 sibling worktrees |
| `/memory-cleanup` | Stale memory files / graduated knowledge piling up |

## 🧠 BSB Brain vault (Obsidian) — the durable layer
| Skill | Reach for it when |
|---|---|
| `/brief` | **START of session** — reloads exactly where you left off (reads `last-state.md`) |
| `/wrap` | **END of session** — writes last-state + logs + syncs → safe to `/clear` |
| `/today` | Morning briefing — top 3 + the one thing + how to start |
| `/sunday` | Weekly review — one win / one friction / one change |
| `/log` | Turn a brain-dump into a structured daily note (+ propose memory facts) |
| `/ingest` | Feed a URL / repo / doc / paste into the vault as linked notes |
| `/research` | Research a topic AND capture findings into the vault (verified write) |
| `/document` | Save anything (link, file, CSV, idea) into the Brain, categorized + dated |
| `/drift` | "Is what I'm doing still aligned with the locked plan?" |
| `/tidy` | Audit the vault for empties / strays / misfiles |
| `/sync` | Refresh the vault's read-only snapshot of rules + memory |
| `/explain` | Explain anything simply, in chat, with a visual + analogy |
| `/deep-research` | Deep multi-source, fact-checked research report |

## 🧭 The build pipeline (GSD) — for anything bigger than a one-off
Use the friendly ALIASES (not the `gsd:` names) — they're a pipeline:
`/kickoff` → `/spec` → `/plan` → `/implement` → `/reviewloop`
(or `/orchestrate` to run all phases autonomously).

| Alias | Does |
|---|---|
| `/kickoff` | New project — deep context gather → `PROJECT.md` |
| `/spec` | Define WHAT you're building BEFORE any code (requirements) |
| `/plan` | Spec → executable phase plan (tasks, deps, verification loop) |
| `/implement` | Execute current phase — atomic commits + state tracking |
| `/orchestrate` | Run ALL remaining phases autonomously / multi-agent fan-out |
| `/reviewloop` | code-review → fix → verify → repeat until clean |

Navigation: `/gsd:progress` (where am I?) · `/gsd:next` (auto-advance) ·
`/gsd:discuss-phase` (Q&A before planning) · `/gsd:debug` (persistent-state debugging).
**When:** new app, model productionization, big refactor — want phases + atomic
commits + verification, not one-shot. `/spec` first = the anti-scope-creep move.

## 🔍 Code quality
| Alias | When |
|---|---|
| `/code-review` | Review the current diff for correctness bugs + cleanups |
| `/verify` | Exercise a change END-TO-END before claiming it's done |
| `/simplify` | Cleanup pass (reuse/simplify/efficiency), then apply |
| `/run` | Launch + drive the app to SEE a change working |
| `/loop` | Run a prompt/command on a recurring interval |
| `/schedule` | Scheduled cloud agents (cron) |

## ⚙️ Process discipline (superpowers — Claude uses these, you can invoke too)
`/superpowers:brainstorming` (before any creative build) · `systematic-debugging`
(any bug) · `test-driven-development` · `verification-before-completion` (before
claiming done). These make Claude follow a rigorous method instead of winging it.

---

## When NOT to use a skill
- A genuinely one-off, tiny task with no recurring shape (just ask directly).
- If you're mid-cascade and just need a diagnosis, not a ritual.

## The 3 that change your day the most
1. **`/brief`** to open + **`/wrap`** to close — never lose context across `/clear`.
2. **`/new-report` / `/new-visual` / `/metric-audit`** — stop shipping reports that drift from the reference impl or break parity.
3. **`/document-pattern`** — the moment you fix something cross-app, this makes every future agent inherit it (like today's weekly no-activity gate).
