---
type: meta
created: '2026-06-30'
tags:
  - meta
  - obsidian
  - tooling
  - eval
  - skills
---
# kepano/obsidian-skills - Tooling Eval

Vetting of **kepano/obsidian-skills** (Steph Ango / Obsidian CEO; MIT; ~13k
GitHub stars) against what THIS vault already runs. This is the repo the "30
Obsidian Workflows" library note flagged (see [[context-library]]). Verdict up
front: the repo is **5 Agent Skills**, and the honest split is one clear ADOPT
(Bases), two ADAPT (Markdown conventions, Canvas), two SKIP-for-us (CLI,
Defuddle). Grounded in [[loop-engineering]] and [[obsidian-optimization]].

Source: <https://github.com/kepano/obsidian-skills>

## What the repo actually is

Five skills that follow the [Agent Skills spec](https://agentskills.io/specification)
(portable across Claude Code, Codex, OpenCode). Each is a `SKILL.md` with a
`name` + `description` front-matter that the model auto-loads when the
description matches the task. They are **passive reference knowledge**, not
slash commands and not MCP servers. Verified by cloning and reading every file,
not the README.

| Skill | What it teaches Claude to do | Our verdict |
|---|---|---|
| **obsidian-bases** | Author `.base` files (YAML) - database-like table/cards/list/map views over notes, with filters, computed `formulas`, and summary stats (`Average`, `Median`, `Stddev`...) | **ADOPT** |
| **obsidian-markdown** | Write valid Obsidian Flavored Markdown - wikilinks, embeds, callouts, properties, tags, comments, highlight, math, mermaid, footnotes | **ADAPT** |
| **json-canvas** | Author `.canvas` files (JSON Canvas 1.0) - nodes/edges/groups for mind maps, flowcharts, boards | **ADAPT (file-for-later)** |
| **obsidian-cli** | Drive a **running** Obsidian instance via the `obsidian` CLI (read/create/search/property/tasks/backlinks) + plugin/theme dev commands | **SKIP** |
| **defuddle** | Extract clean markdown from web pages via the `defuddle` CLI, stripping nav/ads to save tokens; a WebFetch alternative | **SKIP (optional)** |

## Per-skill assessment

### obsidian-bases - ADOPT (the one genuine new capability)

Verdict: **NEW.** The vault has **zero `.base` files today** (verified). Our
[[obsidian-optimization]] note lists **Dataview** as a top "genuine gap" for a
live queryable projects dashboard. **Bases is Obsidian's native, built-in
successor to Dataview** (no community plugin, ships in-app 1.9+). This skill
teaches Claude to build those dashboards correctly on the first try - filter
syntax (`and`/`or`/`not`), the three property namespaces (`note.` / `file.` /
`formula.`), the Duration-field gotcha (`(now() - file.ctime).days`, not
`.round()` on a raw Duration), and YAML quoting traps.

Concrete uses for us:
- A `projects/_dashboard.base` - live "active projects + status + last-modified"
  pulled from `projects/` frontmatter, replacing hand-maintained index notes.
- A [[context-library]] Base - the running external-resource index as a filtered
  table by theme/date instead of a manually clustered markdown list.
- A daily-notes index Base over `05-daily/`.

This is the highest-leverage item in the repo and closes a gap we had already
named ourselves.

### obsidian-markdown - ADAPT (mostly already-implemented, one real gap)

Verdict: **PARTIAL-OVERLAP.** We already write OFM fluently - wikilinks,
frontmatter (`type`/`created`/`tags`), tags, embeds are our daily bread. The
skill's core is already-implemented. **The one thing we do NOT do: callouts.**
Verified `> [!...]` count across the vault = **0**. The skill documents the full
callout vocabulary (`note`/`warning`/`tip`/`example`/`todo`, foldable `-`/`+`,
custom titles). Worth lifting the callout convention into our note style for
briefs/warnings/reference boxes. Do not install this skill just for that - the
callout reference alone is enough to adopt by hand. If installed, it does not
conflict with anything; it just formalizes conventions we mostly already hold.

### json-canvas - ADAPT / file-for-later

Verdict: **NEW capability, low current need.** Zero `.canvas` files in the vault.
Canvas could give us a visual ecosystem map or a spatial MOC (the 4-apps +
modeling + automation inventory as a node/edge board). Genuinely useful someday,
not a current pain. File the capability; pull it in when we actually want a
visual map rather than a markdown MOC.

### obsidian-cli - SKIP (does not fit our headless model)

Verdict: **ALREADY-COVERED by a better tool for us.** The `obsidian` CLI
**requires the Obsidian desktop app to be open** and drives it live. We operate
the vault **headless** through the `obsidian` MCP under Claude Code (see
[[mcp-setup]] / [[README-dual-run]]) - the app does not need to be running. The
CLI overlaps our MCP for read/create/search/property, and the plugin/theme-dev
half is irrelevant to us. Also not installed. Skip unless we start living in the
Obsidian UI and want scripted vault ops from a terminal.

### defuddle - SKIP (optional; our fetch ladder already covers the pain)

Verdict: **MARGINAL-OVERLAP.** Local CLI (`npm i -g defuddle`) that returns
clean markdown from a URL to save tokens - a WebFetch alternative for
`/ingest`/`/document`. But our real fetch pain is bot-blocked/paywalled pages,
and we already solved that with the fxtwitter -> jina -> ask-user ladder in
`.claude/rules/external-resource-capture.md`. Defuddle helps token economy on
ordinary long articles, not the walls we actually hit. Not installed. Optional
nice-to-have for `/ingest`; not a priority.

## Adoption path (no conflict with our existing workflow)

These are **Skills** (model-invoked by description match), which is a different
layer from our **slash commands** (`/document`, `/log`, `/today`, `/sunday`,
`/drift`, `/sync`, `/context`) and our **MCP** access. They do not collide with
or override any command - a skill is passive knowledge Claude pulls in when it
detects it is editing a `.md`/`.base`/`.canvas` file.

Install options:
1. **Marketplace (cleanest):**
   `/plugin marketplace add kepano/obsidian-skills`
   then `/plugin install obsidian@obsidian-skills`
2. **Manual, scoped to just Bases:** drop only
   `skills/obsidian-bases/` into the vault's `.claude/skills/` (the vault
   `.claude/` currently holds only `commands/` - adding a `skills/` folder is
   net-new and harmless). This is the recommended minimal footprint - take
   Bases, skip the rest.

License: **MIT** (Steph Ango, 2026) - safe to vendor/modify.

## Watch-outs (dual-run + read-only snapshot design)

- **Read-only zones are the skill's blind spot.** Our `rules/` and `memory/`
  folders are read-only snapshots of the live `.claude/` (see
  [[README-dual-run]]). These skills teach Claude to *write* `.md`/`.base`/
  `.canvas` files and know nothing about our write-zone discipline. Skills
  themselves do not auto-write, so this is not an active conflict - but if we
  ever install **obsidian-cli** and use `create`/`property:set`, it is
  zone-agnostic and could write anywhere. Our MCP-driven `/document` respects
  zones; a raw CLI would not. Another reason CLI stays SKIP.
- **Trigger breadth.** The obsidian-markdown skill's description fires on "any
  `.md` file in Obsidian," i.e. potentially every vault edit, adding a little
  standing context. Benign, but a reason to install Bases-only rather than the
  whole bundle.
- **Version floor.** Bases needs Obsidian 1.9+ (Bases shipped natively in 2025).
  Confirm the desktop app is current before leaning on `.base` rendering.
- **Do not let Bases replace prose MOCs.** A Base is a query view, not a
  claim-making note. Keep our full-sentence-title MOC discipline
  ([[obsidian-optimization]]); use Bases for the dashboard/index layer only.

## Bottom line

One clear win: **install obsidian-bases** to finally build the live projects /
context-library dashboards we already wanted (it is the native Dataview we named
as a gap). Lift the **callout** convention from obsidian-markdown by hand.
Shelve **json-canvas** until we want a visual map. **Skip obsidian-cli**
(headless-MCP mismatch) and **defuddle** (our fetch ladder already covers the
real pain). Nothing here threatens the dual-run design as long as CLI stays out.

Related: [[loop-engineering]] · [[obsidian-optimization]] · [[context-library]] · [[claude-code-toolkit-raycfu]] · [[README-dual-run]] · [[mcp-setup]]
