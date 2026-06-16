---
name: Grep before asking user to run discovery queries
description: NEVER ask user to run discovery queries when the answer exists in the codebase — grep existing scripts first
type: feedback
originSessionId: 02135e2a-2e8a-4613-9ed2-1063cd790e2d
---
NEVER ask the user to run a discovery query on the work laptop when the answer is already in the codebase. Grep existing scripts, sql-queries/, and .claude/rules/ FIRST.

**Why:** Asked user to run `SELECT DISTINCT draft_org` when `ss_draft_analysis.py` and `alvaro_roster_queries.sql` already showed `draft_org = 'hou'` (lowercase). Wasted user's time and violated rule #1 ("Never guess — grep the codebase first"). The grep results were literally in the same conversation.

**How to apply:** Before ever suggesting a discovery query, exhaust all local sources: existing scripts in ALL worktrees, sql-queries/, .claude/rules/db-columns.md. If the pattern exists anywhere in the codebase, use it. Also — if you learn something from grepping, document it in the relevant rules file immediately so it's findable next time.
