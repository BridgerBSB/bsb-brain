---
type: meta
topic: vault-optimization
status: active
created: '2026-06-17'
---
# Obsidian Optimization — for THIS vault (not a listicle)

Gap analysis of the "30 Obsidian Workflows / second-brain" guides against what
this vault **already** has. The honest headline: **we already exceed most of the
listicle.** The vault has global commands (`/today /log /sunday /brief /ingest
/drift /sync`), the obsidian + recall MCPs, daily notes, MOCs, and is now a
private git repo. So this is about the *few* genuine gaps. See
[[loop-engineering]] for the methodology behind it.

## Already covered (don't rebuild)

| Listicle workflow | Our equivalent |
|---|---|
| Morning Synthesis | `/today` + `/brief` |
| Research Ingestion Pipeline | `/ingest` |
| Weekly Review Automation | `/sunday` |
| Meeting/Daily processing | `/log` |
| Goal-drift check | `/drift` |
| Vault-as-persistent-memory | done — CLAUDE.md defines retrieval rules |
| MCP vault access | obsidian MCP (+ recall MCP) |
| Feedback loop (#ai-generated) | `/log` proposes memory facts; agents write back |

## Genuine gaps — highest leverage first

| Add | Why it's worth it | Next step |
|---|---|---|
| **Obsidian Git plugin** | Vault is now `zbridger_astros/bsb-brain`. Auto-commit/pull keeps you + Camden in sync without manual `git push`. | Install community plugin → enable auto-commit (e.g. every 10 min) + auto-pull on start. (Camden's onboarding already includes this — see [[camden-quick]].) |
| **Dataview** | Turn the vault into a queryable DB — a live "active projects + status" dashboard pulled from `projects/` frontmatter, instead of hand-maintained index notes. | Install → add a `dataview` query block to a `projects/_dashboard.md`. |
| **Templater** | Auto-fire structured templates → consistent frontmatter → better retrieval. We have `templates/daily.md` but it's manual. | Install → bind daily/meeting/evergreen templates to note creation. |
| **Vault Health Check** workflow | Monthly: orphan notes, stalled projects, inconsistent tags, missing frontmatter. Our graph is ~310 notes and growing — rot is real. | Add a `/health` command (sibling to `/drift`) or run as a monthly Routine. |
| **Graph analysis** | At 310+ notes the graph is noisy. Ask Claude to surface hubs/clusters/bridges. | One-off `/ingest`-style command or manual prompt; not a standing need yet. |

## Verify, don't assume

- **mcpvault vs current obsidian MCP** — the guides push `mcpvault` (zero-dep BM25
  search, no Obsidian running). We use a different obsidian MCP. Worth checking
  which is faster/cheaper for retrieval before the auto-load cutover (open TODO in
  [[loop-engineering]]).
- **Periodic Notes / Calendar / Kanban / Tasks** — nice-to-have, low urgency. The
  command layer already does the periodic-notes job. Add only if you start living
  in the Obsidian UI rather than driving via Claude Code.

## The one principle to hold

Full-sentence note titles that make a claim, link-before-search, weekly inbox
review (the `_autocapture-*.md` files the new SessionEnd hook drops — see
[[hooks-setup]] — are exactly what the Friday inbox sweep processes via `/log`).


---

## UPDATE — Bases adopted (Jul 1 2026)

The "live dashboards / Dataview-successor" gap this note named is **CLOSED**. Vendored
kepano's official `obsidian-bases` skill to `.claude/skills/obsidian-bases/` and shipped
two live boards (both YAML-validated):
- **`Idea-Backlog.base`** — the council 17-tool backlog + Tier-0 foundations + ACWR as a
  filterable board (by status / domain), fed by per-idea notes in `ideas/`.
- **`Projects-and-Process.base`** — Projects, Teams & Process, and Recently-Updated views.

Both are embedded in [[Command-Center]] (the new vault home dashboard). Also lifted the one markdown
convention we lacked: **callouts** (`> [!tip]` / `> [!todo]` / `> [!info]`), demoed in Command-Center.
See the eval that drove this: [[obsidian-skills-kepano-eval]].
