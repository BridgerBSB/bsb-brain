---
type: concept
domain: engineering/db
source: Astro World CLAUDE.md — hard-won
---
`prisma db push` **FAILS** against this Supabase project (**P4002**): the engine
can't introspect the cross-schema `public.profiles → auth.users` FK.

**Workflow to change the catalog schema:**
1. Edit `prisma/schema.prisma`.
2. Generate SQL:
   `npx prisma migrate diff --from-empty --to-schema-datamodel prisma/schema.prisma --script`
3. Apply via the **Supabase SQL editor / MCP** (`apply_migration`).

**The deploy does NOT run migrations** — schema changes are a manual, explicit step.

Connection strings: `DATABASE_URL` (transaction pooler, `:6543`, `?pgbouncer=true`)
+ `DIRECT_URL` (session pooler, `:5432`). Password containing `#` → URL-encode as `%23`.

New raw-SQL tables then need grants → see [[supabase-raw-table-needs-grant]].

## Links
[[astro-world]] · [[astroworld-status]] · [[supabase-raw-table-needs-grant]] · [[MOC-astros-engineering]]
