---
name: claude-code-optimization
description: Claude Code optimization research — remote control, skills, multi-agent, GSD, auto-research patterns
type: reference
---

## Claude Code Optimization — Research & Setup Guide (Mar 24, 2026)

### 1. Remote Control (MESSAGE CLAUDE FROM YOUR PHONE)

**Status:** Available now. Requires CC v2.1.51+.

**Setup:**
```bash
# Start remote control server on personal laptop:
claude remote-control

# Or with a custom name:
claude remote-control --name "BSB Resources"

# Or add to an existing session:
/remote-control
```

Displays a QR code → scan with Claude mobile app → steer your local session from phone.

**Key flags:**
- `--name "Project Name"` — custom session title
- `--spawn worktree` — each remote session gets its own git worktree
- `--capacity N` — max concurrent sessions (default 32)
- `claude --rc "BSB Resources"` — interactive session + remote in one command

**How it works:**
- Claude runs LOCAL on your machine (filesystem, DB tools, everything stays local)
- Phone/browser is just a window into the local session
- No ports opened — outbound HTTPS only
- Auto-reconnects on network drops
- Terminal must stay open (laptop stays running)

**Enable by default:** `/config` → toggle "Enable Remote Control for all sessions"

**Use case for Zach:** Leave CC running on personal laptop with `remote-control`. Steer from phone at the stadium, in meetings, on the road. Work laptop can't run CC but phone can control it.

---

### 2. Custom Skills (ONE-COMMAND WORKFLOWS)

**Location:** `.claude/skills/<skill-name>/SKILL.md`
**Invoke:** `/skill-name` in CC

**Skills to create:**
- `/spring-report` — full spring training postgame batch
- `/postgame-deliver` — generate + deliver daily postgame
- `/advance-batch` — batch advance scouting for upcoming series
- `/run-kpi` — weekly KPI report generation + delivery
- `/ev-diagnostic` — run EV misread diagnostic

**SKILL.md format:**
```yaml
---
name: skill-name
description: What it does (Claude sees this to decide when to auto-invoke)
argument-hint: "[optional args]"
---

# Instructions in markdown
Steps Claude should follow when this skill is invoked.
```

**Advanced patterns:**
- `context: fork` — run skill in isolated subagent (fresh context)
- `agent: Explore` — use Explore agent type (read-only, fast)
- `!`backtick commands`` — inject dynamic context (e.g., `!`git status``)
- `$ARGUMENTS` — pass args to the skill

---

### 3. Self-Growing Skills

**Pattern:** Skill that accumulates knowledge over time.

**Example: baseball-sql skill**
- Starts with basic column reference
- Hook on `PostToolUse` for Bash (SQL queries)
- When a query fails or user corrects a column name, Claude appends the correction to the skill
- Over time: living SQL reference specific to our DB

**Implementation:**
1. Create skill with initial knowledge
2. Add a hook that triggers on SQL-related events
3. Hook prompt: "If this query failed due to a wrong column name, append the correction to the skill file"
4. Skill grows organically from real usage

---

### 4. GSD (Get Shit Done)

**Repo:** github.com/gsd-build/get-shit-done
**What it solves:** Context rot in long conversations

**How it works:**
1. Writes a spec/plan FIRST
2. Decomposes into atomic tasks
3. Spawns FRESH subagent context per task (clean 200K window each)
4. Atomic git commits per task
5. No drift — each task starts fresh with full context

**When to use:** Big features, multi-file changes, anything that would normally degrade in a long session.

**Install:** Clone repo, copy skills to `.claude/skills/gsd-*/`

---

### 5. Multi-Agent Patterns

**Current pattern:** One CC session, dispatch agents to worktrees manually.

**Level-up options:**

| Pattern | Command | Use Case |
|---------|---------|----------|
| `/batch` | `/batch apply X to all 3 projects` | Auto-decompose + parallel worktree agents |
| Agent teams | `claude --team` | True parallel workers, independent contexts |
| Background agents | `run_in_background: true` | Keep working while agents run |
| Subagent chains | Agent A → results → Agent B | Sequential coordination |

**Cross-worktree coordination:** Agents don't talk directly. Main thread orchestrates: Agent A finishes → passes results → Agent B starts.

---

### 6. Karpathy AutoResearch Pattern

**Pattern:** constraint + measurable metric + autonomous iteration = compounding gains

**Flow:**
1. Give Claude a metric to optimize
2. Loop: modify code → run eval → check if improved → keep or discard → repeat
3. Runs overnight autonomously

**Baseball application ideas:**
- Optimize zone heatmap smoothing parameters against known good outputs
- Tune percentile color gradients for readability
- Auto-experiment with PDF layout parameters

**Repo:** github.com/karpathy/autoresearch (original), github.com/uditgoenka/autoresearch (CC port)

---

### 7. Hooks (Deterministic Automation)

**What:** Shell commands that fire at lifecycle events (28 event types).

**Key events:**
- `PreToolUse` — before any tool call (can block)
- `PostToolUse` — after tool succeeds
- `SessionStart` — session begins/resumes/compacts
- `Stop` — Claude finishes responding
- `Notification` — Claude needs attention

**Useful hooks for our workflow:**
- Auto-format Python after edits
- Block edits to production data files
- Re-inject critical context after compaction
- Desktop notification when Claude needs attention
- Audit all git operations

**Location:** `~/.claude/settings.json` or `.claude/settings.json`

---

### 8. CLAUDE.md Best Practices

**Current state:** Our CLAUDE.md is comprehensive (~500+ lines). This is above the recommended 200 line target.

**Optimization options:**
- Split into `.claude/rules/` files with path-scoped rules
- Use `@` imports to reference detailed docs
- Keep main CLAUDE.md as overview, move details to rules

**Rule file example:**
```markdown
---
paths:
  - "barrelsville/**/*.py"
---
# Barrelsville-specific rules
- Always use gc2_level_code for DSL/FCL
- EV filter: > 0 AND < 125 on Hits JOIN
```

---

### 9. QMD (Tobi Lutke's Local Search)

**Repo:** github.com/tobi/qmd
**What:** Mini CLI search engine — BM25 + vector search + LLM re-ranking, all local.
**Use case:** Replace grep/glob for Claude Code's file search with semantic understanding.
**Tobi quote:** "I shipped more code in the last 3 weeks than the decade before."

---

### Priority Order

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | Remote Control setup | 5 min | Huge — work from phone |
| 2 | Create 4-5 custom skills | 30 min | Daily time savings |
| 3 | Install GSD | 15 min | Better long sessions |
| 4 | Self-growing SQL skill | 1 hr | Compound knowledge |
| 5 | Split CLAUDE.md into rules | 1 hr | Cleaner context |
| 6 | AutoResearch experiment | 2 hr | R&D exploration |
