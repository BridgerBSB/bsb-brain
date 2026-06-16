# BSB Brain — Vault Operating Instructions

This is Zac Bridger's knowledge vault (Houston Astros PD analytics + personal).
It is a **retrieval-first** workspace. Do NOT bulk-load it. Pull only what a
given question needs.

> **Dual-run status:** This vault is a SOFT-LAUNCH running alongside the live
> `.claude/` system in `C:\Users\Owner\bsb-resources\.claude\`. The `rules/`
> and `memory/` folders here are a **snapshot copy**. The live `.claude/` is
> still the canonical source of truth and is untouched. See
> `meta/README-dual-run.md`.

---

## The retrieval rule (this is the whole point)

When you need a rule, a past decision, or context: **search and read the one
or two relevant notes — never the whole folder.**

- Use `search_vault("keyword")` (MCP) or grep, then `read_note(path)` on the
  hit. Never read all of `rules/` or all of `memory/`.
- A single rules file can be 40–50k chars. Loading the wrong one wastes half a
  context window. Loading the *right* one costs almost nothing.
- If you don't know which note has the answer, search the index notes first:
  `rules/blocking-rules.md`, `memory/MEMORY.md`.

## Read-only discipline (Vin's rule)

In the `rules/` and `memory/` zones, you **read** on demand. You do NOT
rewrite these notes here. Any rule promotion or memory edit goes through the
live `.claude/` workflow (the `document-pattern` + `sync-rules` skills) so
there is exactly ONE writer. This keeps the snapshot from drifting into a
competing source of truth.

The `personal/`, `chatgpt-imports/`, `projects/`, `sql/`, and `00-inbox/`
zones are yours to write freely.

---

## Folder map

| Folder | What lives here | Write? |
|---|---|---|
| `rules/` | Snapshot of `.claude/rules/` — the 70 engineering rules. **Read-only.** | no |
| `memory/` | Snapshot of the agent memory dir — 124 notes + `MEMORY.md` index. **Read-only.** | no |
| `00-inbox/` | Unprocessed captures, attachments | yes |
| `05-daily/` | One note per day (`/log` writes, `/context` + `/today` read) | yes |
| `chatgpt-imports/` | Exported ChatGPT history, tagged + backlinked on ingest | yes |
| `sql/` | Saved queries, schema notes, discovery SQL | yes |
| `projects/` | Active project notes (one subfolder each) | yes |
| `personal/` | Non-work notes, reflection, learning | yes |
| `meta/` | Vault system docs (map, dual-run, MCP setup) | yes |
| `templates/` | Note templates | yes |

## The BLOCKING rules (the only thing worth pre-loading)

The 17 non-negotiable engineering rules live in `rules/blocking-rules.md`.
That ONE file is cheap and high-value — read it first for any code task in the
Astros analytics codebase. Everything else in `rules/` is retrieved on demand
by topic (e.g. a catcher metric question → search "catcher" → read
`rules/three-surface-parity.md`, not the whole folder).

## Default behaviors

- **Astros code/SQL question** → read `rules/blocking-rules.md`, then search
  `rules/` for the specific domain (db-columns, level-codes, fielding, xwoba,
  etc.) and read only the matching note.
- **"What did we ship / decide on X"** → search `memory/`, read the matching
  `*-status.md` or `*-shipped.md`. Start from `memory/MEMORY.md` index.
- **New capture** → drop into `00-inbox/`, then file into the right folder with
  `[[wikilinks]]` to related notes.
- **Connect ideas / find patterns** (the slow-but-deep insight mode) → this is
  the ONLY time it's OK to read broadly. Reserved for `personal/` +
  `chatgpt-imports/`, not the rules zone.

## The daily loop (commands)

Run Claude Code **from this vault folder** (`cd C:\Users\Owner\bsb-brain`) to get
these — they live in `.claude/commands/`. This is the "brain" workspace, separate
from the code workspace in `bsb-resources`.

| Command | When | What it does | Writes? |
|---|---|---|---|
| `/context` | Session start | Situation report — where I left off, active projects, open loops | no |
| `/log` | Evening | Brain-dump → structured daily note in `05-daily/`; proposes memory facts | `05-daily/` |
| `/today` | Morning | Briefing — top 3, the one thing, first 3 steps | no |
| `/sunday` | Weekly | Reads the week → one win / one friction / one change → `personal/reviews/` | `personal/reviews/` |
| `/drift` | On demand | Adversarial check: is current work still aligned with locked decisions? | no |

**The loop:** capture flows in through `/log` → context flows out through
`/context` + `/today` → `/sunday` closes the week and seeds the next. Writes only
ever touch write-zones; `rules/` and `memory/` stay read-only (facts are
*proposed*, never written here).

## Linking

Connect related notes with `[[note-name]]`. A `[[name]]` that doesn't resolve
yet is fine — it marks a note worth writing later (same convention the memory
system already uses).
