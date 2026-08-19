---
type: reference
domain: meta
source: 5 web guides on Claude Code + Obsidian / agentic note-taking / context engineering (fed Jun 18 2026)
created: 2026-06-18
updated: 2026-06-18
---

# Claude Code + Obsidian / Agentic Note-Taking / Context Engineering

Captured reference for five guides on running **Claude Code against an Obsidian vault** —
how to structure the vault so an agent can read, maintain, and reason over it, and the
broader **context-engineering** discipline behind it. Pairs with [[loop-engineering]]
(the agent-loop methodology), [[meta/obsidian-optimization]], and the BSB Brain's own
operating contract (its `CLAUDE.md` + `meta/README-dual-run.md`). Captured per
[[rules/external-resource-capture]] (summary + source link + wikilinks, never a bare URL).

> This is exactly the system the BSB Brain already runs — a root `CLAUDE.md`, a read-only
> `rules/` + `memory/` snapshot, `meta/` for methodology, `/log /context /close /sunday`
> skills, `00-inbox/` for unprocessed drops. Use these to **audit and extend** our setup.

---

## The five sources

### 1. "Stop Overthinking Obsidian — A Beginner's Guide That Actually Works" (André Monthy, Medium)
*What it is:* a vault-setup philosophy that prioritizes **writing over organizational
perfectionism.* Source: <https://medium.com/@andremonthy/stop-overthinking-obsidian-a-beginners-guide-that-actually-works-c46ae9953ac7>
- **Start writing immediately**; search finds notes later. Don't design the perfect system first.
- **Folders = note *types* only** (Daily, MOCs, People, Tasks, Notes, Attachments) — **never
  topic folders** (notes span topics). Use **tags + links** for cross-topic relationships, not
  duplication.
- A **Home MOC** (Map of Content) as the central hub; **Daily Notes** as the second foundational
  type; tags act as **MOC aliases** so a note connects to multiple topics.
- Pitfalls: obsessing over structure before writing; the **plugin trap**; over-thinking every link.

### 2. "TL;DR: Claude Code in Obsidian" (Parazettel)
*What it is:* Claude Code as an AI **consultant that reads your vault** for context-aware help.
Source: <https://parazettel.com/articles/tldr-claude-code-in-obsidian/>
- **First step = a `CLAUDE.md`** documenting vault structure + KM philosophy: *"the CLAUDE.md
  file is going to contain instructions for how this vault of knowledge is laid out."*
- Build an **agent context layer** — files like `index` (learnings about you) + `orient` (recent
  work) that **only Claude reads.**
- Reusable **skills** (`/[skillname]`) for repetitive tasks; a **`/close` skill** to summarize a
  session and update the agent context (continuity between sessions).
- **Sacred human-only zones:** keep personal/reflective writing areas the agent never writes into
  (so it doesn't dilute the vault with its own thoughts). Sparse vaults → poor results.

### 3. "Agentic Note-Taking with Obsidian + Claude Code" (Stefan Imhoff)
*What it is:* automating org/metadata/discovery across a **6,000+ note** vault.
Source: <https://www.stefanimhoff.de/writing/agentic-note-taking-obsidian-claude-code/>
- **Hybrid Zettelkasten + PARA** numbered folder taxonomy (priority-ordered):
  ```
  00 - Maps of Content   01 - Projects   02 - Areas   03 - Resources
  04 - Permanent   05 - Fleeting (YYYYMMDDHHmm)   06 - Daily (YYYYMMDD)
  07 - Archives   99 - Meta (templates, assets, scripts)
  ```
- **`/init`** → Claude writes a `CLAUDE.md` documenting structure/templates/conventions.
- Faster agent search via a local **QMD** engine (full-text + vector + LLM re-rank) — "significantly
  faster" than Obsidian's built-in search for the agent.
- Automate the busywork: bulk image → WebP + CV-based renames + link updates; scan daily notes to
  **extract unmapped resources** (books/people/podcasts/companies), template + backlink them; D3
  force-graph scripts in a `scripts` folder.
- **Teach the agent iteratively:** *"Claude constantly wrote down information about my vault and how
  I work with it in its memory file."* Gotcha: **clean taxonomy + consistent YAML schema first** —
  inconsistent frontmatter causes link failures; session continuity depends on keeping `CLAUDE.md`
  updated.

### 4. "Context Engineering: 100x Claude Code" (Emergent Insights, Substack)
*What it is:* the discipline of **structuring the information an AI accesses** — beyond prompt
engineering. Source: <https://emergentinsights.substack.com/p/context-engineering-100x-claude-code>
- Core thesis: *"Your notes are not just notes anymore. They are the world your AI wakes up
  inside."* Context quality, not just question quality, determines output.
- A root **`CLAUDE.md`/`AGENT.md`** as default-loaded orientation each session.
- **Semantic markdown headings = "retrieval handles"** for machines; proper nesting cuts tokens +
  improves comprehension. (Why our deep notes use heavy `##`/tables.)
- **Daily notes for chronology, quarterly for intent** — layered context.
- **Discriminate ruthlessly:** *"A context window is not memory. It is an expensive, lossy working
  surface."* Too much context degrades output; index docs (e.g. jdocmunch) so the agent pulls only
  the section it needs.
- **Place directives at the prompt's start or end** — middle-buried info is routinely missed.
- Knowledge **garden, not stream**: connection/theme over chronology; bidirectional linking; a
  Zettelkasten "secondary memory" reduces hallucination.

### 5. "Claude Code + Obsidian: how I use it (short guide)" (Reddit r/ClaudeAI) — ⚠️ FETCH BLOCKED
Source: <https://www.reddit.com/r/ClaudeAI/comments/1qr19df/claude_code_obsidian_how_i_use_it_short_guide/>
Reddit blocks bots (direct WebFetch 403, jina proxy 451/403, and the `.json` endpoint all failed
Jun 18). **Paste the post body** and I'll fold its specifics in here. Captured as a live link so it
isn't lost (per [[rules/external-resource-capture]]).

---

## Cross-cutting themes (what they all agree on)
1. **A root orientation file** (`CLAUDE.md` / `AGENT.md`) is step one — it's the vault's API for the agent.
2. **An agent memory/context layer** the agent updates each session (`index`/`orient`/memory file) +
   a **session-close ritual** (`/close`) for continuity. *(We have `memory/` + `/log` + `/close`.)*
3. **Folders by type, not topic; links + tags + MOCs carry meaning.** Numbered taxonomy for agent
   priority (Imhoff) vs minimalist type-folders (Monthy) — both reject topic folders.
4. **Skills/slash commands** for recurring maintenance; **fast search** for the agent (QMD).
5. **Context engineering > prompt engineering:** semantic headings, ruthless inclusion, directives
   at edges, garden-not-stream, the vault as the agent's working world.
6. **Protect human-only zones** so the agent doesn't pollute genuine reflection.

## What to adopt / audit for the BSB Brain
- ✅ Already have: root `CLAUDE.md`, read-only `rules/`+`memory/` snapshot, `meta/`, `00-inbox/`,
  `/log /context /close /sunday /drift /today` skills, the dual-run contract.
- 🔎 Consider: a **faster agent search** layer (QMD-style vector+rerank) for the growing vault;
  a **resource-extraction skill** that scans daily notes for unmapped books/people/orgs and
  backlinks them (we do this manually via [[rules/external-resource-capture]]); **quarterly intent
  notes** alongside dailies; tightening **semantic-heading discipline** so notes are clean retrieval
  surfaces (the deep hitting notes already model this).
- 🧠 Frame check: the context-engineering thesis = exactly why we capture into the vault instead of
  letting context rot in chat (the whole point of [[loop-engineering]] + the dual-run brain).

## Links
- [[loop-engineering]] · [[meta/obsidian-optimization]] · [[rules/external-resource-capture]] ·
  [[maker-checker-split]] · [[minimum-viable-loop]] · [[loop-state-file]]
- [[MOC-astros-engineering]]
