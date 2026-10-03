---
type: project
domain: engineering
source: coordinator-app/pages/1_questionnaire.py + CLAUDE.md
created: 2026-07-09
feeds: coordinator-notes-app
---

# Coordinator Notes - Questionnaire + Schema

The visit-report form for [[coordinator-notes-app]]. One `visits` row per trip. Built on the [[in-app-submission]] pattern.

## Identity (3, auto/dropdown/date)
Coordinator name (from auth, locked), Affiliate visited (dropdown), Visit dates (start + end).

## Text questions (18 across 12 sections)
Manager, Pitching Coach, Hitting Coach, Development Coach, S&C Coach, Athletic Trainer, Dietitian each get Strengths + Improvements (14). Then Facility & Operations (1 combined `facility_ops_notes`), Staff Highlights (positive standout + needs support), Staff Development (cultivated + goals-aligned), Looking Ahead (improvement goal), Feedback (delivered).

## Opposing Org Observation (OPTIONAL, added 2026-07-09)
End-of-form section. Org dropdown sourced from the `mlb_orgs` table (30 orgs, defaults to N/A) + 2 text questions (how the org operates, opposing staff standout). Stored in 3 nullable `visits` columns: `opp_org_observed`, `opp_org_operations_notes`, `opp_org_staff_standout`. N/A stores NULL. **Kept out of the section progress bar and the minimum-answers submit check** so it never blocks submit. Also mirrored into the submission email (only when filled) and embedded for RAG. `mlb_orgs` is a reference table read via the admin client so the RAG tool can query it like the coordinator roster.

## Lifecycle
Draft (private, no embedding) -> Submit (embeds, visible to all, locked forever). Displayed on Recent Visits / By Coordinator / By Affiliate pages.

## Deprecated (write-frozen 2026-05-26, still read)
`clubhouse_notes` + `meals_notes` (merged into `facility_ops_notes`); `visit_player_summaries` table (summaries no longer captured on the form, legacy rows still display + embed).

## Gotchas
- **Required selectors must default to an unselected placeholder, not the first option.** The affiliate dropdown defaulting to the first affiliate caused mis-filed reports. Same rule applied to the new org dropdown (N/A first).
- Email goes through Resend HTTP API because Railway blocks outbound SMTP.
- Drafts persist new fields automatically because the form spreads the answers dict into the `visits` upsert.

## Links
[[coordinator-notes-app]] · [[coordinator-notes-rag]] · [[in-app-submission]] · [[pd-goals-transition]] · [[player-evaluator]] · [[MOC-astros-engineering]]
