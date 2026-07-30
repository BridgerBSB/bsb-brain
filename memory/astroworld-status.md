---
name: astroworld-status
description: "Astro World — internal Astros PD learning platform (Next.js). LIVE
  on Railway. 2026-07-13: IT GREENLIT for Astros systems — repo migrating from
  personal (BridgerBSB) to the Astros GitHub org, dev moving to the work
  machine."
metadata:
  node_type: memory
  type: project
  originSessionId: 196af78a-1076-4240-9b6f-14e06621ab6a
---

**Astro World** — internal Astros Player Development onboarding/learning platform
(Coursera/Udemy feel). Structure hub: [[astro-world]]. Storage: [[astro-world-storage]].

- **Repo:** `C:\Users\Owner\astroworld` (home machine — full git history, source of truth).
  Personal remote: GitHub `BridgerBSB/astroworld`, branch `master`
  (Railway connects the personal GitHub, not the Astros org).
- **Stack:** Next.js 15 + Prisma + **Supabase Postgres** (project `yqzooxunhjbvnikbihvu`) +
  swappable storage adapters. **LIVE on Railway.**

## 2026-07-13 — IT GREENLIT + repo migration to Astros org
Realizes the long-parked "[[astroworld-possible-internal-move]]" chatter — **IT approved
Astro World** for Astros systems (came out of an IT meeting demo).

**Migration plan (in progress):**
1. **Home machine (source of truth):** commit pending work, add the Astros org as a 2nd
   remote, `git push astros --all` (preserves full history + LINEAGE/gotchas).
   Auth to the push as the **Astros GitHub identity** (org write access).
2. **Work machine:** `git clone` the Astros repo → **recreate `.env`** (it's gitignored,
   so it does NOT come with the clone) → `npm install` → `npm run dev` → `localhost:3000`.
3. Open **Claude Code inside the cloned folder** on the work machine = the new dev home.
4. Delete the old browser-ZIP copy (`Downloads\astroworld-master`, no `.git`) — dead end.

**Work-machine environment facts (learned the hard way):**
- Node **v26** present (`C:\Users\zbridger\...`). No admin needed for the app itself.
- **IT application-allowlisting** ("Astros IT Security Policy" popup, ThreatLocker-style)
  blocked Prisma's **`schema-engine-windows.exe`** (publisher Unknown) during `npm install`.
  **This is the binary IT greenlit** — authorize it if the prompt returns.
- **PowerShell execution policy** blocks `npm.ps1` ("running scripts is disabled").
  Fix: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` (session-only,
  no admin), OR call `npm.cmd install` / `npm.cmd run dev` (`.cmd` dodges the policy).
- Demo constraint that held during the meeting: **couldn't run locally** (allowlist) and
  **couldn't use a personal laptop** — greenlight resolved it.

**Security hygiene — DO AFTER MOVE:**
- ⚠️ Admin password **`SamZac#2026` is committed in plaintext** in `docs/2026-06-04-alpha-status.md`
  and `docs/2026-06-04-railway-deploy.md` (in history). Going into a shared company repo.
  **Rotate `ADMIN_PASSWORD`** so the committed one is dead; optionally scrub those docs or
  seed the Astros repo with a single clean commit to drop it from history.
- `.env` confirmed **never committed** — DB password (`AstrosAnalytics%232026`) is not in git.
  `.env` values live only in the file; the DB URLs + admin/session secrets were re-pasted
  onto the work machine during setup.

## State (2026-07-11) — LIVE
- **Auth = per-user Supabase login** (email + password), **admin-by-role** —
  `zbridger@`, `saniedorf@`, `cquick@astros.com`. No shared password anymore.
  Email is **code-based** (M365 Safe Links → [[microsoft-safe-links-breaks-email-auth]]).
  Offboarding = `profiles.is_active=false`, checked at login. Reset shows success even
  if the email doesn't exist (no enumeration).
- **Storage:** video + images + thumbnails → **Supabase Storage** (private, signed
  URLs); PDFs → Railway persistent volume `/data/uploads`. Volume attached +
  `LOCAL_STORAGE_DIR` set (2026-06-20, verified). Full design: [[astro-world-storage]].
- **Content:** page prose lives in `Page.blurb` (e.g. `pitching/philosophy` →
  [[pitching-development-philosophy]], added 2026-07-09). Content is org IP →
  mirrored to the brain via `astroworld/scripts/sync-content-to-brain`.

## Open
- **Repo migration to Astros org** (2026-07-13, above) — in progress.
- **Post-move hygiene:** rotate `ADMIN_PASSWORD`; decide history-scrub vs keep.
- **Hosting on Astros infra** — greenlit; path/timeline TBD with IT (Railway still live for now).
- **Security hardening** — phased hardening + audit plan in progress (coordinator
  parity, advisor findings, thumbnails). See repo `docs/`.
- **Thumbnail load speed** — A (render-time signed + cache) vs B (public thumb bucket);
  decision pending (see [[astro-world-storage]]).
- **Parked for Sam:** drag-reorder.

## Engineering gotchas (nodes)
[[microsoft-safe-links-breaks-email-auth]] · [[prisma-supabase-migration-workflow]] ·
[[supabase-raw-table-needs-grant]] · [[nextjs-db-safe-build-force-dynamic]] ·
[[supabase-bcrypt-passwords]] · [[supabase-manual-user-insert-null-tokens]]
