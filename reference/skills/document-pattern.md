---
name: document-pattern
description: Document reusable engineering patterns to .claude/rules/ and propagate to all worktrees. Use when completing ANY cross-app fix, optimization, or architectural pattern that other agents/worktrees need to follow. Trigger words - "document this", "write this up", "make sure other agents know", "propagate", "apply to other apps".
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Document Pattern — Cross-App Rules Propagation

When a reusable pattern, fix, or optimization is completed, document it in `.claude/rules/` and propagate to all worktrees so every agent picks it up automatically.

## Step 1: Identify What to Document

Only document things that are:
- **Cross-app** — applies to 2+ projects (Barrelsville, Arm Farm, Intangibles, PD Goals)
- **Non-obvious** — can't be derived by reading the code alone
- **Prescriptive** — tells agents what TO DO, not just what was done

Do NOT document:
- App-specific logic (belongs in that app's rules file)
- One-time fixes (the commit message covers it)
- Things already in existing rules files (update instead of duplicate)

## Step 2: Check for Existing Rules

Before writing a new file:

```
grep -rl "KEYWORD" .claude/rules/
```

If a related rule exists, UPDATE it instead of creating a new file.

## Step 3: Write the Rules File

Location: `.claude/rules/<pattern-name>.md`

Structure:
1. **Title** — what the pattern is
2. **Problem** — what goes wrong without it
3. **Fix/Pattern** — the actual implementation with code snippets
4. **App-Specific Differences** — table of how each app varies
5. **What NOT to Do** — common mistakes

Keep code snippets minimal — show the PATTERN, not the full implementation. Agents will read the actual codebase for details.

## Step 4: Propagate to All Worktrees

Copy to every worktree. Always use this exact set:

```bash
# All 4 worktrees
cp .claude/rules/FILENAME.md "C:/Users/Owner/bsb-wt-hitting/.claude/rules/FILENAME.md"
cp .claude/rules/FILENAME.md "C:/Users/Owner/bsb-wt-bullpen/.claude/rules/FILENAME.md"
cp .claude/rules/FILENAME.md "C:/Users/Owner/bsb-wt-intangibles/.claude/rules/FILENAME.md"
# Main repo (bsb-resources) already has it
```

If a worktree's `.claude/rules/` dir doesn't exist, create it:
```bash
mkdir -p "C:/Users/Owner/bsb-wt-WORKTREE/.claude/rules"
```

## Step 5: Verify Propagation

```bash
for wt in "C:/Users/Owner/bsb-resources" "C:/Users/Owner/bsb-wt-hitting" "C:/Users/Owner/bsb-wt-bullpen" "C:/Users/Owner/bsb-wt-intangibles"; do
    test -f "$wt/.claude/rules/FILENAME.md" && echo "OK: $wt" || echo "MISSING: $wt"
done
```

## Step 6: Update CLAUDE.md if Needed

If the new rule is a universal blocking rule or introduces a new domain section, add a pointer in CLAUDE.md under the appropriate section:
- Blocking rules go in `## Blocking Rules`
- Domain patterns go in `## Reference Guide — .claude/rules/`

## Worktree Reference

| Path | Branch | Project |
|------|--------|---------|
| `C:\Users\Owner\bsb-resources` | `feature/pd-goals` | PD Engine (main repo) |
| `C:\Users\Owner\bsb-wt-hitting` | `feature/barrelsville` | Barrelsville |
| `C:\Users\Owner\bsb-wt-bullpen` | `feature/bullpen-reports` | Arm Farm |
| `C:\Users\Owner\bsb-wt-intangibles` | `feature/astros-intangibles` | Intangibles |
