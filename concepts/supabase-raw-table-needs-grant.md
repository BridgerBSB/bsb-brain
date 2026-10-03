---
type: concept
domain: engineering/db
source: Astro World CLAUDE.md — hard-won
---
A table created via **raw SQL** (not the Supabase table UI) gets **no auto-grant**
— Supabase's automatic grants don't apply. A public table read by **PostgREST**
needs an **explicit** `grant select ... to authenticated` (RLS still filters rows
on top of the grant).

**This bit us:** `profiles` had no grant → every PostgREST read returned nothing →
`isAdmin()` was silently **always false**. The hash/RLS looked correct; the missing
grant was invisible.

Rule: after any `create table` in raw SQL / a migration, grant the roles that read
it (`authenticated`, sometimes `anon`) — grant is capability, RLS is row policy;
**you need both.**

Pairs with the migration workflow: [[prisma-supabase-migration-workflow]].

## Links
[[astro-world]] · [[astroworld-status]] · [[prisma-supabase-migration-workflow]] · [[MOC-astros-engineering]]
