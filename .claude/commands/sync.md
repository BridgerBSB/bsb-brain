---
description: Refresh the vault's read-only snapshot of rules + memory from the live .claude/ source
argument-hint:
  - optional - a source repo path to override the default
---

Refresh the vault's **read-only snapshot** of the engineering rules + agent
memory so the graph view and on-demand retrieval aren't stale.

**DIRECTION IS ONE-WAY:** live `.claude/` → vault. NEVER the reverse. The live
`.claude/` is canonical; this command only COPIES INTO the vault's `rules/` and
`memory/` folders. It must not write to the live source.

## The single source (migration-aware)

There is exactly ONE source at a time. Today it's bsb-resources; after the
code migrates to player-development, flip this one path.

- **Default source (today):** `C:\Users\Owner\bsb-resources`
- **After migration:** `C:\Users\Owner\player-development` (or wherever
  `.claude/` lives then)
- If `$ARGUMENTS` is given, use it as the source repo path instead.

Pick the source: `$ARGUMENTS` if provided, else the default above. **Confirm the
chosen source's `.claude/rules/` exists before copying** — if it doesn't, STOP
and report (don't snapshot from the wrong place).

## Steps

1. Resolve `SRC` = source repo path (per above). Resolve the memory dir:
   `C:\Users\Owner\.claude\projects\C--Users-Owner-bsb-resources\memory`
   (this is the live agent-memory dir; it does NOT move with the code repo —
   note that if a future migration relocates it).
2. Run, reporting each:
   ```bash
   cp -r "$SRC/.claude/rules/." /c/Users/Owner/bsb-brain/rules/
   cp -r "/c/Users/Owner/.claude/projects/C--Users-Owner-bsb-resources/memory/." /c/Users/Owner/bsb-brain/memory/
   ```
3. Report a 3-line summary: source used, # rule files now in `vault/rules/`,
   # memory files now in `vault/memory/`. Flag any count that dropped vs a
   normal run (possible partial copy).

## What this does NOT do

- Does NOT write to the live `.claude/` (one-way only).
- Does NOT touch vault write-zones (`meta/`, `projects/`, `05-daily/`, etc.) —
  those are yours, never overwritten by a sync.
- Does NOT wire the MCP retrieval layer — that's a separate, future step
  (`meta/mcp-setup.md`). This is just the file-copy snapshot.

## When to run

After a batch of rule/memory changes you want reflected in the vault's graph or
retrieval. The snapshot is a point-in-time copy — for code work the agent should
read the LIVE rules, not this copy (see `meta/README-dual-run.md` on the
freshness tradeoff).
