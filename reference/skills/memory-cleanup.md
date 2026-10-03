---
name: memory-cleanup
description: Clean up stale memory files, app-dir design docs, and completed plans when knowledge has graduated to .claude/rules/. Triggers on explicit keywords (done/complete/shipped/live/finished), commit patterns (docs(rules): sync, chore: delete dead), or periodic sweeps. Runs pre-flight staleness scan before any deletion. Also syncs rules across worktrees and appends to a graduation log.
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Edit, Write
---

# Memory Cleanup — Completed Feature Graduation

When a feature is marked complete and its knowledge is captured in `.claude/rules/<app>.md`, memory files and old design/plan docs in app directories are dead weight. This skill handles the full graduation process with a pre-flight scan, 3 cleanup phases, and an append-only graduation log.

## Triggers

**Strong (always sweep):**
- User says a feature is "done", "complete", "shipped", "live", or "finished" AND a rules file was recently updated
- User explicitly asks for cleanup ("memory cleanup", "clean these up", "sync rules", "graduate these")
- Commit pattern in recent history: `docs(rules): sync`, `docs(rules): lift`, `chore: delete dead`, `chore: remove dead`
- End of a multi-commit parity / refactor push (≥10 commits on a single theme)

**Soft (scan + flag, don't auto-delete):**
- Session start if `.claude/rules/.graduation-log.md` last entry is > 14 days ago
- Any large CLAUDE.md or rules/ edit

## Scope Variants

Pass one of these as argument to narrow the sweep:
- `memory` — Phase 1 only (memory files)
- `docs` — Phase 2 only (app-dir design/plan docs)
- `sync` — Phase 3 only (rules parity across worktrees)
- `all` (default) — all three phases
- `<worktree-path>` — scope Phase 2 to a specific worktree only

If the user's scope is narrow ("clean up intangibles docs"), run only the relevant phase on that scope.

## Pre-Flight Staleness Scan (run first, for any phase)

Generates a candidate list with evidence BEFORE deletion. Never deletes at this stage.

### Step 1: Find stale files

```bash
# App-dir candidates: .md files > 30 days old, not in .claude/ or .git/
for wt in bsb-resources bsb-wt-bullpen bsb-wt-hitting "bsb-wt-intangibles/astros-intangibles"; do
  find "/c/Users/Owner/$wt" -name "*.md" \
    -not -path "*/.claude/*" -not -path "*/.git/*" \
    -not -path "*/node_modules/*" -not -path "*/__pycache__/*" \
    -mtime +30 2>/dev/null
done

# Memory candidates: > 30 days old, excluding feedback + reference
find "/c/Users/Owner/.claude/projects/C--Users-Owner-bsb-resources/memory/" \
  -name "*.md" -mtime +30 \
  ! -name "feedback_*" ! -name "*reference*" ! -name "MEMORY.md"
```

### Step 2: Cross-reference with rules

For each candidate, extract its main subjects (first `##` heading + filename tokens) and grep them in `.claude/rules/`:

```bash
# Example: does AFFILIATE_TRACKERS_DESIGN.md's content live in rules?
grep -rn "affiliate tracker\|fielding_tracker\|tracker_page" .claude/rules/
```

Interpretation:
- **≥5 hits on core terms** → content graduated → DEAD / COMPLETED PLAN
- **0-2 hits + unique technical content** → REFERENCE → KEEP
- **Has open items ("TODO", "TBD", "PENDING", "NEXT")** → KEEP

### Step 3: Present candidate list

Output a markdown table (NEVER a bulleted narrative):

```markdown
## Pre-Flight Candidates — YYYY-MM-DD

| File | Age | Rules overlap | Verdict | Reason |
|------|-----|---------------|---------|--------|
| intangibles/FOO.md | 45d | 8 hits in intangibles.md | DEAD | all features LIVE |
| barrelsville/BAR.md | 60d | 0 hits | KEEP | unique schema ref |
| memory/baz-notes.md | 35d | 4 hits in barrelsville.md | DEAD | shipped Apr 7 |
```

## Phase 1: Memory File Cleanup

### Step 1: Identify Candidates

Read `MEMORY.md` and identify memory files matching ALL:
- Feature status is COMPLETE / LIVE / SHIPPED / CODE COMPLETE
- Knowledge is already in `.claude/rules/<app>.md` (verify via grep, not assumption)
- File contains NO active TODO / TBD / PENDING / NEXT items
- File is ≥ 14 days old (or ≥ 3 days with explicit "feature is live" signal)

**Do NOT delete if:**
- Contains active open items or unresolved decisions
- Has knowledge NOT yet in rules (add to rules first, OR keep)
- Filename starts with `feedback_` (permanent behavioral corrections)
- Filename contains `reference` or is a DB/schema/external-system pointer
- Updated in last 3 days AND actively developed

### Step 2: Verify Before Deleting

For each candidate:
1. Read the memory file completely
2. Grep the corresponding rules file for the memory's key terms
3. Confirm overlap. If memory has unique info: add to rules first, then delete.

### Step 3: Delete + Update Index

1. `rm <file>`
2. Remove the file's entry from `MEMORY.md`
3. Append a 1-line migration note to MEMORY.md under a dated "Graduated YYYY-MM-DD" section

## Phase 2: Dead Doc Cleanup (App Directories)

### Step 1: Scan

```bash
find <worktree>/<app-dir> -name "*.md" \
  -not -path "*/.claude/*" -not -path "*/.git/*" \
  -not -path "*/node_modules/*" -mtime +30
```

### Step 2: Classify

| Classification | Action | Criteria |
|---------------|--------|----------|
| **DEAD** | Delete | Content fully superseded by `.claude/rules/<app>.md` |
| **COMPLETED PLAN** | Delete | Plan files where git log confirms all tasks done |
| **STALE PRD** | Archive or update | PRD where "Next Steps" are all done |
| **REFERENCE** | Keep | Schema docs, research with unique findings not in rules |
| **WRONG BRANCH** | Flag | Files that belong to a different project |
| **CLAUDE.md REF** | Keep | Any file explicitly referenced by CLAUDE.md or MEMORY.md |

### Step 3: Execute

1. `git rm <file>` for tracked, `rm <file>` for untracked
2. Commit with explanatory message listing deleted files + reasons
3. Push to the worktree's feature branch (per CLAUDE.md auto-push rule)

## Phase 3: Rules Sync + CLAUDE.md Parity

### Step 1: Diff rules files across worktrees

```bash
for f in /c/Users/Owner/bsb-resources/.claude/rules/*.md; do
  base=$(basename "$f")
  for wt in bsb-wt-bullpen bsb-wt-hitting "bsb-wt-intangibles/astros-intangibles"; do
    diff -q "$f" "/c/Users/Owner/$wt/.claude/rules/$base" 2>/dev/null
  done
done
```

### Step 2: Sync stale copies

Identify authoritative version (latest edits, matches latest commits). Copy to all worktrees.

### Step 3: Check CLAUDE.md parity

```bash
diff /c/Users/Owner/bsb-resources/CLAUDE.md /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/CLAUDE.md
# ...and for other worktrees
```

Blocking rules + project table must match.

## Graduation Log — MANDATORY after any delete

After ANY delete operation in Phase 1 or Phase 2, append to `.claude/rules/.graduation-log.md`:

```markdown
## YYYY-MM-DD — cleanup-sweep ({scope})

### Deleted memory files (N)
- `memory-file.md` — reason
- `other.md` — reason

### Deleted app-dir docs (N)
- `path/to/file.md` — reason (e.g. "content in rules/intangibles.md — 13 hits")

### Kept but flagged
- `path/to/borderline.md` — reason

### Commit(s)
- `<sha>` on `<branch>`
```

This is the audit trail. Without it, you can't tell if the skill ran at each claimed moment or whether something was wrongly deleted. Bootstrap the log on first run if it doesn't exist.

## Staleness Heuristics (summary)

| Signal | Interpretation |
|--------|---------------|
| File > 30 days old | Likely stale candidate |
| File > 30 days + ≥5 rules hits on its subject | Likely DEAD |
| File named `feedback_*` | KEEP always |
| File named `*reference*` | KEEP unless rules fully cover |
| File contains "TODO"/"TBD"/"PENDING"/"NEXT" | KEEP (has open items) |
| File in `docs/plans/` + git log shows all tasks done | COMPLETED PLAN → delete |
| File referenced by CLAUDE.md or MEMORY.md | KEEP (explicit index ref) |
| File modified in last 3 days | KEEP (active) |

## Report Template

```markdown
## Cleanup Report — {Scope} — {YYYY-MM-DD}

### Pre-flight
- Candidates found: {N}
- Verdicts: {N dead} / {N completed plans} / {N kept}

### Phase 1 (memory)
- Deleted: {list}
- Kept (reason): {list}

### Phase 2 (app docs)
- Deleted: {list}
- Flagged for review: {list}

### Phase 3 (rules sync)
- Files synced: {N}
- Divergences: {list or "none"}

### Graduation log updated
- Entry: {YYYY-MM-DD line}
- Commit(s): {list}
```
