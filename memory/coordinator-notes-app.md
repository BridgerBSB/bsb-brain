---
name: coordinator-notes-app
description: Internal Astros PD app for coordinators to submit affiliate visit
  notes. Streamlit + Supabase + Claude RAG, live on Railway. PRODUCTION.
type: project
domain: engineering
source: C:/Users/Owner/coordinator-app repo + CLAUDE.md
updated: 2026-07-09
---

**PD Coordinator Notes** is an internal Houston Astros app where Player Development coordinators submit structured notes after visiting minor league affiliates. Notes feed a Claude RAG agent for cross-visit trend analysis. Sibling app to [[astroworld-status]]; both are personal-GitHub + Railway.

**Status:** PRODUCTION (as of 2026-07-09). Feature-complete, live.

- **Repo:** `C:\Users\Owner\coordinator-app`. GitHub `BridgerBSB/coordinator-app` (PERSONAL, `github-personal` remote), branch `master`. Railway auto-deploys on push to master.
- **Live URL:** `astro-production-ee058.up.railway.app` (~$5/mo).
- **Stack:** Python Streamlit multipage + Supabase (Postgres + pgvector) + Claude Haiku 4.5 RAG. Embeddings are LOCAL open-source `sentence-transformers` (never OpenAI). Email via Resend HTTP API (Railway blocks outbound SMTP).
- **Auth:** per-user Supabase Auth (email + password, manually created accounts), `is_active` flag for fired coordinators. See [[supabase-bcrypt-passwords]] + [[supabase-manual-user-insert-null-tokens]]. Zac's login: `zbridger@astros.com` / `AstrosPD2026!` (shared default kept for Zac + Sam; not private).

**8 tables:** `profiles`, `affiliates`, `visits`, `visit_embeddings`, `chat_messages`, `players`, `visit_player_summaries`, `staff`, plus `mlb_orgs` (added 2026-07-09). 18 coordinators, 6 affiliates (AAA down to DSL).

## The two halves
- **Questionnaire + schema:** 18 text questions across 12 sections + 3 identity fields, draft/submit lifecycle, plus the 2026-07-09 optional Opposing Org Observation section. Full detail: [[coordinator-notes-questionnaire]].
- **RAG pipeline:** local embeddings on submit, pgvector search, Haiku agent with roster context. Full detail: [[coordinator-notes-rag]].

## Key rules
Drafts are private to their coordinator and skip embedding; only submitted visits embed and are visible to all. Submitted visits cannot be edited or deleted. Login page is incognito (no branding). Shares the reusable [[in-app-submission]] pattern with [[pd-goals-transition]]. Questionnaire answers also feed [[player-evaluator]].

## Links
[[MOC-astros-engineering]] · [[coordinator-notes-questionnaire]] · [[coordinator-notes-rag]] · [[astroworld-status]] · [[in-app-submission]] · [[supabase-bcrypt-passwords]] · [[supabase-manual-user-insert-null-tokens]] · [[rag-architectures]]
