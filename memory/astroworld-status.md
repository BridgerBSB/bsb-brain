---
name: astroworld-status
description: "Astro World — internal Astros PD learning platform (Next.js). Alpha built, ready to show Sam; hosting decision pending."
metadata: 
  node_type: memory
  type: project
  originSessionId: 196af78a-1076-4240-9b6f-14e06621ab6a
---

**Astro World** — internal Astros Player Development onboarding/learning platform
(Coursera/Udemy feel). Separate from bsb-resources.

- **Repo:** `C:\Users\Owner\astroworld` (personal laptop). GitHub:
  `BridgerBSB/astroworld` (personal, via `github-personal` remote), branch `master`.
  Railway can only connect this personal GitHub (NOT the Astros org one).
- **Stack:** Next.js 15 + Prisma + **Postgres (Supabase, project `yqzooxunhjbvnikbihvu`)**
  + swappable storage adapter (local uploads). Runs via `npm run dev` → localhost:3000.
- **Admin password:** `SamZac#2026` (Zac + Sam). Entry: footer "Admin" link or
  `/admin`.

**Full handoff:** `astroworld/docs/2026-06-04-alpha-status.md` (read this to
resume — architecture, key files, env, findings, hosting options).

**State (2026-06-04):** Alpha DONE + Chrome-verified. Content types (video/pdf/
image), 3-across card grid → modal, custom thumbnails (add + edit), password gate
+ admin bar + preview-as-viewer, Manage organized by Domain→Page dropdowns,
upload-first (SharePoint embed links confirmed BLANK in-tenant → not viable).

**Open:** re-upload the lost video+PDF (I deleted them in a bad cleanup — see
[[feedback-no-blanket-delete-during-cleanup]]). **Parked for Sam:** drag-reorder.

**HOSTING DECIDED = Railway** (2026-06-04). Posit dropped — corp network blocks
external Supabase + needs IT to enable Node off-host; not worth it for the alpha.
Deploy prep COMMITTED + pushed (`10d67bb`): Prisma sqlite→postgresql, build runs
`prisma generate`, `railway.json` (db push then start), Node>=20, `.env.example`
updated. Storage stays the proven `local` adapter — on Railway it MUST point at a
persistent volume (`LOCAL_STORAGE_DIR=/data/uploads`) or uploads wipe on redeploy.
**Remaining to go live (4 steps in `astroworld/docs/2026-06-04-railway-deploy.md`):**
(1) paste Supabase Postgres URI into `DATABASE_URL` (local `.env` + Railway Vars);
(2) Railway → deploy from personal GitHub; (3) add volume mounted `/data`, set
`LOCAL_STORAGE_DIR=/data/uploads`; (4) open URL. Local dev now needs the Postgres
URI pasted too (provider is postgresql; old `dev.db` unused) → `npm run db:push`
+ `db:seed`. Future in-tenant path (only if IT demands it): swap Prisma provider
→ `sqlserver`/GCSQL02 + `STORAGE_DRIVER=sharepoint` — config swap, not a rebuild.
