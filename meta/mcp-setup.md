# MCP Retrieval Setup — the token-savings layer

Goal: let Claude Code pull ONE relevant note per question via tools
(`search_vault`, `read_note`, `list_notes`) instead of bulk-loading 30 rule
files at session start. This is where the 40–60%+ token reduction comes from
(per the `507lucash` blueprint + the `mcp-obsidian.org` v0.6.3 lean-return
optimization). Obsidian alone does NOT save tokens — this layer does.

## Which server (recommendation)

| Server | Needs Obsidian running? | Needs a plugin? | Reads raw `.md`? | Best for |
|---|---|---|---|---|
| **mcpvault** (bitbonsai) | no | no | yes, directly | **our rules use-case** — can point straight at the live `.claude/rules` dir, BM25 search, zero moving parts |
| mcp-obsidian (MarkusPfundstein) | yes | yes (Local REST API) | via API | when you want the full live vault incl. Obsidian's own link graph |

**Recommended: mcpvault** — because it reads raw `.md` from any folder with no
Obsidian-running requirement, so it can target the **live** rules dir for
zero-staleness retrieval.

> Exact package handle + launch command will be verified before you install —
> do not run an invented command. The configs below show the SHAPE; the
> `command`/`args` get confirmed first.

## Two configs — pick by purpose

### Config A — point at the VAULT COPY (safe testing, may be stale)
Use for kicking the tires / graph-adjacent retrieval where staleness is OK.

```jsonc
// shape only — command/args TBD on verify
{
  "mcpServers": {
    "bsb-brain": {
      "command": "<verified-launcher>",
      "args": ["<server-pkg>", "--vault", "C:\\Users\\Owner\\bsb-brain"]
    }
  }
}
```

### Config B — point at the LIVE rules dir (production-correct, never stale)
Use this for real code work. Reads the canonical rules the moment you commit
them. This is the one that actually replaces the auto-load burn safely.

```jsonc
// shape only — command/args TBD on verify
{
  "mcpServers": {
    "bsb-rules": {
      "command": "<verified-launcher>",
      "args": ["<server-pkg>", "--vault", "C:\\Users\\Owner\\bsb-resources\\.claude\\rules"]
    }
  }
}
```

## Wiring it into Claude Code (NOT done automatically)

This setup does NOT modify your global Claude Code settings. When you're ready,
it's one of:

- `claude mcp add bsb-rules -- <verified command>` (CLI), or
- adding the `mcpServers` block above to the appropriate settings/`.mcp.json`.

I'll confirm the exact server + flags, then either hand you the one-liner or
wire it with your go-ahead.

## The other half: stop the bulk auto-load

The MCP only helps if you ALSO stop force-feeding all 70 rules each session.
That's a change to the LIVE `.claude/` auto-load behavior and is **out of scope
for this soft-launch** (we agreed: don't touch `.claude/` across branches).
When the retrieval path is proven, the cutover is: slim the auto-load to
`blocking-rules.md` only, and let everything else come through MCP on demand.
Decide that with a measured before/after token number.

## Optional later: local RAG (semantic search)

`507lucash` adds Ollama + `nomic-embed-text` + a local vector store
(sqlite-vec / LanceDB / Chroma) so `search_vault("run attribution fix")`
returns the 3 notes that MEAN that, not 40 keyword hits. Runs locally, never
touches Claude, free. Layer this on only if BM25 keyword search proves too
noisy on the rules corpus.
