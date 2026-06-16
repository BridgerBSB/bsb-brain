---
type: meta
topic: bsb-resources-inventory
status: draft-confirm-sensitivity
created: '2026-06-15'
---
# bsb-resources — Folder Inventory (the junk-drawer map)

Read-only analysis of every top-level folder in `C:\Users\Owner\bsb-resources`
so the brain/agents know what's there. This is a PRIVATE vault note (never
pushed). Pairs with the migration plan ([[context-preservation-roadmap]] / the
`player-development` repo move) — it answers "what moves, what's reference, what
stays personal."

> ⚠️ **SENSITIVITY IS UNCONFIRMED.** Zac flagged that some folders are
> *pre-Astros / former-company* material — keep personally, NEVER expose to the
> shared org repo. I can't tell from the files alone which those are. The
> "Origin?" column is my best guess; **Zac must confirm** before any tag is
> trusted. Until confirmed, treat every "personal/3rd-party?" row as
> DO-NOT-MIGRATE.

## CORE — live Astros work (migrates to player-development)

| Folder | Size | What it is |
|---|---|---|
| `pd-goals` | 179M | The live PD Engine app (PD Goals / Transition / WPA / Org Board / Defense Matrix). **The thing that migrates first.** |
| `sql-queries` | 1.4M | GroundControl SQL library (112 .sql) + DATABASE_REFERENCE. |
| `gcpy` | 683K | The org's canonical DB-access lib ("universal approach to connecting to the DB from Python"). Also a Baseball-Operations repo — the answer to Catherine's "align with our DB architecture." |
| `scripts` | 80K | Small misc scripts. |
| `docs` | 2.8M | BSB Resources archived references (overflow from CLAUDE.md; PD Goals state notes). Astros-internal. |

## ASTROS REFERENCE DOCS (Astros-internal — keep, not app code)

| Folder | Size | What it is |
|---|---|---|
| `astros-docs` | 944K | GroundControl glossary — Astros internal metric definitions (EN/ES): wOBA, wRC+, ORP-Bat, etc. |
| `ds-docs` | 4.3M | Data-science docs / package cheatsheets / viz examples for reference. |
| `r-resources-astros` | 2.9M | Astros R + Posit Connect templates (DB connection strings, Shiny, email reports). |
| `design-system` | 8K | Astros **Arm Farm** design-system master file (page styling rules). |
| `astros-pd-project` | 22M | Zac's **Astros PD Analyst take-home assessment** (Shiny dashboard, due Jan 2). Old, not wired to anything live. Personal-ish but Astros-context. |

## LEARNING / THIRD-PARTY (public — low sensitivity)

| Folder | Size | What it is | Origin? |
|---|---|---|---|
| `awesome-claude-skills` | 13M | Third-party Claude skills/plugin collection. | public |
| `rag-simple` | 29M | Public "Simple Local RAG" tutorial (PDF→chat, local GPU). | public |
| `pst26` | 124K | "Data Science Best Practices" project-structure guide (Linux VM workflows). | public/template |
| `tjstats-pitching` | 13M | "TJStats" pitching-summary graphic code — a known public baseball-analytics project. | 3rd-party public |

## PERSONAL / ONE-OFF PROJECTS — ⚠️ CONFIRM which are pre-Astros/former-company

| Folder | Size | What it is | Origin? |
|---|---|---|---|
| `dudz-batter-pitcher` | 18M | MLB batter-pitcher scouting-report generator (2024 pitch data, PDF + heatmaps). | personal? ⚠️ |
| `og-pena` | 2.1M | Jeremy Peña Statcast analysis (R viz app, public data). | personal? ⚠️ |
| `pitch-design-colby` | 2.6M | Pitch-design automation (Streamlit + ML + decision-tree). | personal? ⚠️ |
| `swing-path` | 303M | MLB Swing Path Visualizer — "research platform maintained by Zac Bridger" (3D bat-tracking Streamlit). | Zac's own ⚠️ |
| `personal-bsbres` | 262M | "AI Prompting Context for Baseball Analytics" + analytics examples. Personal prompting/role context. | personal ⚠️ |
| `send-from-2b` | 318M | Send-runner analysis (LightGBM models, MLB send dataset). | personal? ⚠️ pre-Astros? |

**The 3 mega-folders** (`swing-path` 303M, `send-from-2b` 318M, `personal-bsbres`
262M) carry the identical "📚 Baseball Analytics Examples" readme and are the
prime "personal, do-not-share" candidates — but `swing-path`'s own CLAUDE.md says
it's Zac's research platform, so "former-company" ≠ obviously these. **Needs Zac's
call.**

## Open action
- [ ] Zac: tag which rows are **pre-Astros / former-company** (never to the org repo).
- [ ] Add confirmed-sensitive folders to a DO-NOT-MIGRATE guardrail + the new repo's `.gitignore`.
- [ ] Migration only ever COPIES the CORE rows (`pd-goals` first) → `player-development`. Personal rows stay in `bsb-resources` on the laptop, never copied.
