---
type: project
domain: engineering/apps
source: astroworld repo CLAUDE.md + sessions through 2026-07
---
# Astro World — Project Hub (MOC)

Internal Houston Astros **PD onboarding/learning platform** (Coursera/Udemy feel).
Delivers the org's Player Development curriculum — video, PDF, images, and page
prose — behind a login. **Live on Railway.** Repo: `C:\Users\Owner\astroworld`
(GitHub `BridgerBSB/astroworld`, branch `master`).

**Stack:** Next.js 15 + React + Tailwind · Prisma → **Supabase Postgres** ·
Supabase Auth · swappable storage adapters. Users are `@astros.com` (M365).

## Two layers (both belong in the brain)
1. **Engineering** — how the app is built (the gotchas below).
2. **Content** — what it teaches. Page blurbs, PDFs, and curriculum housed in
   Astro World are durable org IP → **each is (or becomes) a brain node.** When
   content changes in the app, mirror it here. See [[pitching-development-philosophy]].
   Content sync: `astroworld/scripts/sync-content-to-brain` (Supabase → vault).

## Map
- **State (live):** [[astroworld-status]]
- **Storage architecture:** [[astro-world-storage]]
- **Hitting content structure:** [[astro-world-hitting-structure]]
- **Curriculum:** [[pd-onboarding-curriculum]]

### Engineering gotchas (hard-won)
- [[microsoft-safe-links-breaks-email-auth]] — code-based OTP, never a link.
- [[prisma-supabase-migration-workflow]] — `db push` fails; use `migrate diff`.
- [[supabase-raw-table-needs-grant]] — raw-SQL tables need explicit grants.
- [[nextjs-db-safe-build-force-dynamic]] — build must not touch the DB.
- [[supabase-bcrypt-passwords]] · [[supabase-manual-user-insert-null-tokens]]

## Links
[[MOC-astros-engineering]] · [[pd-onboarding-curriculum]] · [[coordinator-notes-app]]


## Log
- **2026-07-14** - Azure migration + CIO architecture notes: repo now at `Baseball-Operations/astroworld` (org, clean history), Track B strip done, content = SharePoint links. Verified SharePoint iframe embedding is blocked host-independently ("refused to connect"); inline display path = Microsoft Graph (needs Entra app reg + Files.Read.All/Sites.Read.All), not the iframe on Azure. Peter (CIO) reopened the admin-role decision (Entra App Roles vs app-level DB - "coin flip"), is exploring Fabric, and has Azure auto-deploy pushing but failing at startup. Full note: [[astro-world-azure-migration-2026-07-14]].

## AstrosEDU media + quizzes (2026-08-03)

See [[astro-world-astrosedu-media-and-quizzes-2026-08-03]] for the full write-up:
the three stacked bugs that made video upload fail (10 MiB body truncation,
link-handed-to-a-video-element, and Save deleting the upload), and the quiz
system built on top of it (authoring, gating, unlimited retakes, results page).

Carries the generalisable lesson: **a form that posts a field on every save will
clear whatever that field controls, for any state the field does not represent.**
