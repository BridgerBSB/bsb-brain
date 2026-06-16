# External Resource Capture + Fetching Bot-Blocked Pages

Two paired conventions:
1. **How to fetch content the user links** when the page blocks bots / sits
   behind a soft paywall (X/Twitter, etc.).
2. **What to do with every link/resource the user feeds us** — capture it into
   the Obsidian knowledge-base vault so it's referenceable from any branch,
   instead of evaporating when the session ends.

This exists because the user is actively feeding reference material (X threads,
articles, repos) and context rot has been eating it. Capturing once, durably,
beats re-fetching or losing it.

---

## Part 1 — Fetching bot-blocked / paywalled pages

`WebFetch` fails on many modern sites that wall off bots. Escalation ladder,
fastest-working-first:

### X / Twitter — use the fxtwitter API (WORKS)

Swap the host `x.com` (or `twitter.com`) → `api.fxtwitter.com`, keep the rest
of the path. Returns the tweet as JSON (text, author, linked article, media) —
no login, no key.

```
https://x.com/sairahul1/status/2064279904989147577
        ↓  swap host
https://api.fxtwitter.com/sairahul1/status/2064279904989147577
```

Then `WebFetch` that URL with a prompt like *"Return the full verbatim tweet
text and any linked article title/URL from this JSON."*

**Verified ladder (2026-06-12):**

| Approach | Result on x.com | Use |
|---|---|---|
| `WebFetch` raw `x.com/...` | **402 Payment Required** | ❌ never works |
| `WebFetch https://r.jina.ai/https://x.com/...` (jina reader proxy) | **451 Unavailable For Legal Reasons** | ❌ blocked for X |
| `WebFetch https://api.fxtwitter.com/<user>/status/<id>` | **200, JSON with text** | ✅ **canonical** |

Notes:
- The `text` field can be empty when the tweet is just an image + a link — the
  JSON still carries the linked article title/URL, which is usually what matters.
- Sibling mirrors `vxtwitter.com` / `api.vxtwitter.com` work the same way if
  fxtwitter is ever down.
- Case in the username doesn't matter for the API path.

### General sites (non-X) — jina reader proxy

For ordinary bot-blocked pages (not X), prepend the jina reader proxy:

```
https://r.jina.ai/https://<the-blocked-url>
```

Renders server-side, returns clean markdown. (It's X specifically that returns
451 through jina — for most other sites it works.)

### Still blocked? Fall back to the user

If both fail, **don't burn turns retrying** — give the user the clean link(s)
and ask them to paste the content, then file it per Part 2. Losing 30 seconds
to a paste beats five failed fetches.

---

## Part 2 — Capture every resource into the Obsidian KB

**The vault:** `C:\Users\Owner\bsb-brain` (the "BSB Brain" second-brain — see
its own `CLAUDE.md` + `meta/README-dual-run.md`). Reached via the `obsidian`
MCP tools (`mcp__obsidian__write_note`, `read_note`, `search_notes`,
`list_directory`, `get_vault_stats`).

### The convention (BLOCKING for resource-feeds)

When the user feeds a link, article, repo, video, or any external resource:

1. **Fetch it** (Part 1) so you capture the actual content, not just a dead URL.
2. **Write it to the vault** with: a one-line "what it is," a short summary of
   the substance, the **source link**, and `[[wikilinks]]` to related notes.
3. **Group by topic.** Topic-specific reference notes live in `meta/` (vault
   system/workflow docs) or a topic folder; loose unprocessed captures go to
   `00-inbox/` first, then get filed.
4. **Never lose the link.** Even if a fetch fails, write the bare URL + the
   user's framing so it's recoverable later.

### Where things go (vault write-zones only)

| Resource kind | Home in vault |
|---|---|
| Workflow / methodology refs (loop engineering, Obsidian setups, agent patterns) | `meta/<topic>.md` (e.g. `meta/loop-engineering.md`) |
| Unprocessed drop / "look at this later" | `00-inbox/` then file |
| SQL snippets, schema notes | `sql/` |
| Project-specific material | `projects/<name>/` |
| Personal / learning | `personal/` |

**Read-only zones — never write here:** `rules/` and `memory/` in the vault are
SNAPSHOT COPIES of the live `.claude/` system. Durable engineering facts are
*proposed*, then written through the live `.claude/` workflow (this rule file is
an example — it lives in `.claude/rules/`, not the vault). One writer per source
of truth. See the vault's `meta/README-dual-run.md`.

### Reference impl

`meta/loop-engineering.md` in the vault (created 2026-06-12) — captured 9 X
threads on loop/context engineering via the fxtwitter trick, each with a summary
+ source link + the actionable takeaways. Mirror that shape for new topic
captures.

---

## Why this matters (context rot)

The vault's whole point is moving context OUT of the chat window into durable,
retrievable notes so a `/clear` doesn't wipe it. A link the user pastes that
only lives in one chat turn is gone the moment the session ends. Capturing it to
the vault makes it survive across branches, sessions, and clears — and makes it
retrievable on demand (one note per question) instead of re-fetched or
re-explained. See the vault commands `/context` `/log` `/today` `/sunday`
`/drift` (run Claude Code from `cd C:\Users\Owner\bsb-brain`).

---

## What NOT to do

- **Don't** `WebFetch` raw `x.com` URLs and give up at the 402 — use
  `api.fxtwitter.com`.
- **Don't** retry the same blocked URL 5 different ways. Climb the ladder once
  (fxtwitter → jina → ask user), then move on.
- **Don't** write captured resources into the vault's `rules/` or `memory/`
  folders — those are read-only snapshots. Use `meta/` / `00-inbox/` / topic
  folders. Durable engineering rules go to the LIVE `.claude/rules/` (and sync
  across worktrees), not the vault.
- **Don't** capture just a bare URL when you could fetch the content. A summary
  + link is referenceable; a dead link is a future re-fetch.
- **Don't** drop the source link when summarizing — always keep the URL so it's
  traceable.
- **Don't** treat the vault as the canonical store for engineering rules/memory.
  It's a snapshot + a personal-knowledge workspace. The live `.claude/` remains
  the one writer for rules + agent memory.

---

## Cross-references

- Obsidian vault `CLAUDE.md` + `meta/README-dual-run.md` + `meta/mcp-setup.md`
  — the second-brain operating contract (dual-run, retrieval-first, MCP layer).
- `meta/loop-engineering.md` (vault) — reference capture + the loop/context-rot
  methodology behind this convention.
- `slack-channels-sync.md` — same cross-worktree sync discipline this rule file
  follows (lives byte-identical in all 4 worktrees).
- `memory-cleanup` skill / live `memory/` — the canonical agent-memory writer
  (NOT the vault snapshot).

---

## Bug history

- **2026-06-12** — User fed 9 X/Twitter thread links on loop/context engineering.
  `WebFetch` on raw x.com → 402; `r.jina.ai` proxy → 451. Discovered
  `api.fxtwitter.com` returns the tweet JSON with no auth. Captured all 9 into
  `meta/loop-engineering.md` in the vault. User asked to document the fetch trick
  + the resource-capture convention as a rule across every branch — this file.
