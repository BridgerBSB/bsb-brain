# Dual-Run — the safety contract

This vault runs **alongside** the live `.claude/` system. It does not replace
it, and it does not touch it. Same discipline as the codebase's dual-query-path
rule: build the new path, prove it, only then consider cutting over.

## What is canonical (untouched)

| Live source (CANONICAL) | Location |
|---|---|
| Engineering rules (70 files) | `C:\Users\Owner\bsb-resources\.claude\rules\` |
| Agent memory (124 files + MEMORY.md) | `C:\Users\Owner\.claude\projects\C--Users-Owner-bsb-resources\memory\` |

These are git-tracked across all branches and remain the only place rules and
memory are **written**. Nothing in this vault changes them.

## What this vault is

A **snapshot copy** of `rules/` + `memory/` for two purposes:

1. **Graph view + backlinks** — open the vault in Obsidian and see the 194-note
   link graph over the existing `[[wikilinks]]`. Find orphans, dead links,
   clusters. A read/audit lens.
2. **On-demand retrieval target** — an MCP server can point at this vault (or,
   for zero staleness, at the LIVE rules dir — see `mcp-setup.md`) so the agent
   pulls one note per question instead of bulk-loading 30.

## The snapshot freshness tradeoff (read this)

`rules/` and `memory/` here are a **point-in-time copy** (taken when the vault
was built). The live versions keep evolving via your normal commits.

- For **graph viewing / auditing**: a snapshot is fine.
- For **retrieval the agent trusts on a code task**: a stale rule is a
  correctness risk (your BLOCKING rules ship bugs if wrong). So when you wire
  the MCP retrieval layer for real work, point it at the **live** rules dir,
  not this copy. `mcp-setup.md` gives both configs and says which to use when.

## Re-snapshot command (refresh the copy)

When you want the vault's copy to catch up to the live rules/memory:

```bash
cp -r /c/Users/Owner/bsb-resources/.claude/rules/. /c/Users/Owner/bsb-brain/rules/
cp -r "/c/Users/Owner/.claude/projects/C--Users-Owner-bsb-resources/memory/." /c/Users/Owner/bsb-brain/memory/
```

## Cutover decision (later, not now)

Once retrieval proves it cuts the token burn, the options are: (a) keep the
snapshot + scheduled re-sync, (b) point retrieval at live and use the vault
only for graph viewing, or (c) symlink. Decide with a measured token number,
not a vibe. Nothing here forces that decision.

## Git remotes (changed 2026-09-04)

The vault's owner is now the personal account: `origin` =
`git@github-personal:BridgerBSB/bsb-brain.git`. The Astros account is kept as
a second remote named `astros` (the old origin) and receives every push as a
mirror. The pipeline in `_pipeline/` pushes to both. `00-inbox/transcripts/`
(Claude session logs, 1.4 GB) is gitignored and must never be added.
