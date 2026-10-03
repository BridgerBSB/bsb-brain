---
type: concept
domain: engineering/auth
source: Astro World admin session 2026-06-16
---
Supabase (GoTrue) stores passwords as a **one-way bcrypt hash** in
`auth.users.encrypted_password` (e.g. `$2a$10$...`). There is **no plaintext
password anywhere** — not in the dashboard, not in any table, not in an export.
Passwords are unrecoverable by design: if the DB leaks, attackers still don't get
them. Login works by hashing the typed password and comparing hashes.

Consequences:
- You can't "look up" a forgotten password — only **set a new one** or have the
  user run a reset (code-based here; see [[microsoft-safe-links-breaks-email-auth]]).
- To check a *guess* without changing anything, re-hash and compare:
  ```sql
  select encrypted_password = extensions.crypt('guess', encrypted_password) as ok
  from auth.users where email='...';
  ```
  (`pgcrypto` lives in the `extensions` schema on Supabase.)
- Setting a password via SQL: `encrypted_password = extensions.crypt(pw, extensions.gen_salt('bf'))`.

## Links
[[astro-world]] · [[supabase-manual-user-insert-null-tokens]] · [[astroworld-status]] · [[coordinator-notes-app]] · [[MOC-astros-engineering]]
