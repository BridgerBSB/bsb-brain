---
name: Coordinator Notes App — New Project
description: Internal Astros coordinator visit notes app with Supabase, Streamlit, RAG agent. Hosted on personal GitHub (BridgerBSB), NOT company GitHub.
type: project
---

## Overview
Web app for Astros coordinators to submit affiliate visit notes. Questionnaire → Supabase → RAG agent for trend analysis.

**Status:** PLANNING (Apr 8, 2026)

## Key Architecture Decisions
- **Hosting:** Personal GitHub (BridgerBSB), NOT company zbridger_astros
- **Stack:** Python Streamlit + Supabase (Postgres + pgvector) + Claude API + OpenAI embeddings
- **Auth:** Supabase Auth (email + password), is_active flag for fired coordinators
- **Database:** Supabase shared with boss (Sam Niedorf)
- **Hosting target:** Railway or Streamlit Cloud paid (private app)
- **NOT on Posit Connect** — needs AI/vector DB capabilities Posit restricts

## GitHub Constraint
Claude Code is connected to WORK GitHub (zbridger_astros). This project goes on PERSONAL GitHub (BridgerBSB). Need to either:
- Switch SSH keys / git remote per-project
- Use a separate worktree with different git remote
- Or use a completely separate directory with its own git config

## Pages
1. **Landing** — Astros branding, auth gate
2. **Questionnaire** — 13 text fields (manager, coaches, facility, staff, forward-looking)
3. **Recent Visits** — all submitted visits, newest first, expandable cards
4. **By Coordinator** — filter by coordinator dropdown
5. **By Affiliate** — filter by affiliate dropdown
6. **AI Insights** — RAG chat box, Claude-powered, source attribution

## Database Schema (Supabase)
- `profiles` — coordinator accounts + is_active flag
- `affiliates` — Astros affiliates (AAA through DSL)
- `visits` — one row per trip, 13 question fields, status (draft/submitted)
- `visit_embeddings` — chunked + embedded text for RAG (pgvector)

## Questionnaire Fields
1. Coordinator name (from auth, not editable)
2. Affiliate (dropdown)
3. Visit dates (start + end)
4. Manager strengths / improvements (2 fields)
5. Pitching coach strengths / improvements (2 fields)
6. Hitting coach strengths / improvements (2 fields)
7. Development coach strengths / improvements (2 fields)
8. Clubhouse experience
9. Meals quality
10. Staff standout positive
11. Staff needs support
12. Improvement goal for next visit

## Key Rules
- Drafts: yes, but once submitted = locked forever
- No edit/delete of submitted visits
- All coordinators can see all submitted visits
- AI agent available to everyone
- Email notification on submit (to Zach + Sam)
- ~10-15 coordinators total

## Skills/Tools to Reference
- https://github.com/obra/superpowers
- https://github.com/thedotmack/claude-mem
- https://github.com/anthropics/claude-code/blob/main/plugins/frontend-design/skills/frontend-design/SKILL.md
- https://github.com/skills-directory/skill-codex
- https://github.com/affaan-m/everything-claude-code
- https://github.com/manaflow-ai/cmux
- https://github.com/JackChen-me/open-multi-agent

## Build Phases
1. Scaffold + Auth (Supabase Auth + Streamlit multipage)
2. Database + Form (questionnaire, drafts, submit)
3. Views (recent visits, by coordinator, by affiliate)
4. RAG Pipeline (embeddings on submit, pgvector search, Claude agent)
5. Polish + Deploy (branding, notifications, Railway/Streamlit Cloud)

**Why:** Boss (Sam Niedorf) assignment. Coordinators visit affiliates and take notes — currently no structured way to capture and analyze them.

**How to apply:** This is a SEPARATE project from bsb-resources. Needs its own repo, its own CLAUDE.md, its own directory. Do NOT mix with existing work GitHub.
