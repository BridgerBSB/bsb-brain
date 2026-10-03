---
type: concept
domain: engineering/deploy
source: Astro World CLAUDE.md — hard-won
---
On Railway the **build must NOT touch the database** — the DB may be unreachable
at build time, and a failed prerender kills the deploy.

**Fixes:**
- Root layout is `export const dynamic = "force-dynamic"` so `next build` doesn't
  **prerender** pages (including `/_not-found`) and hit Postgres.
- `getNav()` / `getSessionUser()` **swallow DB errors and degrade gracefully**
  (nav never renders blank; page still serves) rather than throwing.

Principle: a build is a pure artifact step; anything needing live data must run at
**request** time, not build time. Same reasoning drives the storage split in
[[astro-world-storage]] (bytes served at request via signed URLs, not baked in).

## Links
[[astro-world]] · [[astroworld-status]] · [[astro-world-storage]] · [[MOC-astros-engineering]]
