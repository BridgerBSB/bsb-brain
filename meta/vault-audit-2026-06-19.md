---
type: meta
topic: vault-maintenance
created: '2026-06-19'
status: proposed — awaiting Zac confirmation before any deletion
---
# Vault Audit — 2026-06-19

Full sweep of `C:\Users\Owner\bsb-brain` via the obsidian MCP. **352 notes, 17 folders.**
Sized every note + checked frontmatter. **Nothing deleted — this is a proposal.** Per the
"never blanket-delete during cleanup" rule, every action below is per-file and needs a
green light first. `rules/` + `memory/` were NOT audited for deletion (read-only `/sync`
snapshots — managed by the live `.claude/` workflow, one writer).

## 🗑️ DELETE — empty / stray (3)
| File | Why |
|---|---|
| `Sam.md` (root) | **0 bytes.** Empty. If [[Sam]] is worth a note, it belongs in `people/sam.md` with content — not an empty root file. |
| `user-preferences.md` (root) | **0 bytes.** Empty placeholder. Real prefs live in the live `.claude/` memory + `CLAUDE.md`. Either fill it as a vault-side pointer or delete. |
| `Untitled.canvas` (root) | Stray default Obsidian canvas (the name = accidental "+canvas" click). Almost certainly empty. Delete unless you parked something in it. |

## 🔀 RESTRUCTURE / MOVE (2)
| Item | Recommendation |
|---|---|
| `Sam.md` → `people/` | If kept: move to `people/sam.md`, add frontmatter + one line (who Sam is — Farm Director / boss), wikilink from where he's mentioned. Matches the `people/` convention ([[colby-morris]], [[camden-quick]], etc.). |
| Root note hygiene | Root currently holds 3 MOCs (fine) + `Sam.md` + `user-preferences.md` + `Untitled.canvas` + `CLAUDE.md`. After the deletes above, root is clean (MOCs + CLAUDE.md only). |

## 🧹 MANIPULATE — inbox curation (`00-inbox/`)
| File | Action |
|---|---|
| `_autocapture-2026-06-17.md` | Curated into daily notes → **safe to clear.** |
| `_autocapture-2026-06-18.md` | Curated into `05-daily/2026-06-18.md` → **safe to clear.** |
| `_autocapture-2026-06-19.md` | **KEEP** — has an un-`/log`'d session pointer (14:03 UTC, `cwd …/pd-goals`, a different project). Clear only after that session is logged. |
| `00-inbox/transcripts/` | Raw `.jsonl` session transcripts — the source material for `/log`. Leave; prune later if it bloats. |

## 🟡 DORMANT ZONES — aware, no action needed
- `personal/` — only `README.md`; no notes yet. Designated zone, just unused. Keep.
- `chatgpt-imports/` — only `README.md`; unused import staging. Keep.
- All folder `README.md` stubs (92–1099 B) — intentional folder-purpose docs, NOT cruft.

## ✅ CLEAN — no action
- **`concepts/` (66 notes):** all have real content + frontmatter; smallest is `era.md` (445 B) — a legit atomic metric def, not empty.
- **`people/` / `org/` (7):** small (166–701 B) but all real atomic stubs.
- **`projects/`, `meta/`, `sql/`, `05-daily/`:** all substantive.
- This session's new notes ([[indyball-tracker]], [[datacenter-ip-waf-block]]) verified healthy + linked into both MOCs.

## Deeper pass available (not yet run)
A true **orphan check** (notes with zero inbound `[[links]]`) needs a backlink graph — heavier
(read every note). The empties above are the obvious orphans; say the word for the full pass.

## Links
- [[vault-map]] · [[obsidian-optimization]] · [[README-dual-run]] · [[MOC-astros-engineering]] · [[MOC-baseball-analytics]]

---

## ✅ Executed 2026-06-19 (Zac: "clean it")
**Deleted:** `Sam.md` (0 B), `user-preferences.md` (0 B), `00-inbox/_autocapture-2026-06-17.md`, `00-inbox/_autocapture-2026-06-18.md` (both curated), `Untitled.canvas` (stray, via filesystem).
**Kept:** `_autocapture-2026-06-19.md` (un-logged pd-goals session pointer). Dormant `personal/` + `chatgpt-imports/` left as designated zones.
**Repeatable:** this audit is now the `/tidy` slash command (`~/.claude/commands/tidy.md`).
