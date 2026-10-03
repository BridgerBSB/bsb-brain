---
type: project-log
date: 2026-07-14
project: astro-world
source: Teams convo with Peter Yee (CIO) + build session
---
# AstroWorld - Azure Migration + Peter (CIO) Architecture Notes (2026-07-14)

Capture of where AstroWorld's Azure/Astros-environment move stands, plus the
Teams conversation with **Peter Yee (CIO)** that reopened two architecture
decisions. Hub: [[astro-world]] · status memory: [[astroworld-status]] ·
people: [[camden-quick]] (third content admin).

## Where the app is
- **Repo (source of truth):** `github.com/Baseball-Operations/astroworld` - its
  own repo in the Baseball-Operations org (every app there is a standalone repo).
  Clean single-commit history, no Supabase/AI/Railway/old-password anywhere.
  Default branch `main`; feature branch -> PR -> main -> Azure auto-deploy.
  Personal repos (`zbridger_astros/astroworld`, `BridgerBSB/astroworld`) are
  stale fallbacks.
- **Track B strip DONE:** removed the AI assistant, ALL login/auth (localhost
  runs with NO login), Supabase auth + storage. Content model = pasted SharePoint
  links. Admin can add, edit (incl. **swap the content link in place**), reorder,
  set an image-URL thumbnail, delete. Auth seam preserved in `src/lib/auth.ts`
  (isAdmin/canManageSections stubbed true locally) for a future Entra swap.
  Prisma/Postgres content catalog KEPT for now.
- **~95% functional** (Zac's estimate to Peter). Runs locally in Edge signed into
  Astros M365.

## The verified technical finding (corrects a belief - IMPORTANT)
Testing on the work laptop, signed into Astros M365, on **localhost**: adding a
SharePoint video/PDF and opening it shows **"astros.sharepoint.com refused to
connect"** in the in-app frame, while the "Open in a new tab" link opens the file
fine.

- That "refused to connect" is SharePoint's **X-Frame-Options / CSP** blocking
  itself from being put in an iframe. It is **enforced by the browser from
  SharePoint's response headers and is HOST-INDEPENDENT**. Being on Azure will
  NOT change it. Being signed into Entra lets you OPEN the file (worked) but does
  not make it EMBED.
- So the iframe approach is a dead end for SharePoint content, on any host.

**The real path to inline PDF/video display = Microsoft Graph.** With the Entra
app registration + delegated **`Files.Read.All` / `Sites.Read.All`**, the app
asks SharePoint (via Graph) for the file itself (PDF bytes / a video URL) and
**serves it inline itself** - no iframe, nothing to refuse. Content stays in
SharePoint. Alternative: **Azure Blob** (moves files out of SharePoint, app
serves them). Graph is preferred (keeps content in SharePoint). Thumbnails have
the same constraint: Graph auto-thumbnail, or Blob, or a pasted image URL.

So Zac's instinct ("once we're in the Microsoft/Entra system it works") is right
about the DESTINATION but wrong about the MECHANISM: it's Graph, not the iframe
on Azure.

## Peter Yee (CIO) - what he said (Teams, this week)
- **Deploy:** connecting the Azure Web App to the GitHub repo for auto-deploy from
  `main`; wants feature branches tested locally then merged. **Got it pushing to
  Azure from a GitHub push, but it's "failing at some point in the startup"** -
  still sorting. (Likely env vars / start config - `DATABASE_URL` must be set in
  App Service Application settings, which we flagged.)
- **Org repo was required:** he hit a wall deploying from a personal/private repo;
  moving to the Baseball-Operations org fixed the GitHub-Actions-to-Azure path.
- **Auth - he's reconsidering Entra App Roles (the coin flip):** "putting the
  role-level security into Entra could become complicated if we had 10-20
  different apps... it requires a global Entra / AD change to people's groups. I
  think it's a coin flip at this point... if we put the role security into Entra,
  or if we bake it into the app-level security using a database." => This reopens
  our "no database" stance for the ADMIN/ROLE layer specifically.
- **Fabric:** exploring Microsoft Fabric as an easy way to stand up a backend;
  will report back.
- **Wants a common-components/foundation pattern** across the ecosystem's apps
  (his app + AstroWorld sharing architecture learnings).
- Asked about **timeline** to publish AstroWorld to the org.

## Open decisions (pending Peter / joint)
1. **Admin/role security: Entra App Roles vs app-level DB.** Peter leans it's a
   coin flip and worries Entra roles don't scale across many apps. Tension: we
   removed the DB. If we go app-level roles, we re-introduce a small store (or use
   Fabric). Tenant SIGN-IN gate (single-tenant Easy Auth) is not in question -
   only WHERE the admin/"content-publisher" role lives.
2. **Inline SharePoint display: Graph vs Blob.** Graph (keep in SharePoint) needs
   the app registration + Files.Read.All/Sites.Read.All. Blob moves files to Azure
   storage. Iframe is ruled out.
3. **Thumbnails:** Graph auto-thumbnail / Blob / pasted image URL.
4. **Deploy startup failure:** needs the Azure log; almost certainly missing
   `DATABASE_URL`/`DIRECT_URL` in App Service config or a start-command mismatch.
5. **Fabric** as a possible shared backend - Peter to report.

## Next steps (buildable now vs blocked)
- **Now (no Peter):** clean "Open in SharePoint" fallback for embed-blocked items
  (so it looks intentional, not "refused to connect"); scaffold the Graph adapter
  so it's ready to wire the moment the app registration exists; keep migrating
  content structure/copy.
- **Blocked on Peter:** the Entra app registration (sign-in + Graph read perms),
  the role-model decision, the Azure App Service env config + deploy fix, Fabric.

## The concrete ask for Peter (inline display)
The app registration needs Microsoft Graph **delegated** `Files.Read.All` and
`Sites.Read.All` so the app can read SharePoint files on behalf of the signed-in
user and render them inline. That is the specific unlock for PDFs/videos in-app.

## Cross-links
[[astro-world]] · [[astroworld-status]] · [[camden-quick]] ·
[[supabase-manual-user-insert-null-tokens]] (legacy auth, now removed) ·
[[MOC-astros-engineering]]
