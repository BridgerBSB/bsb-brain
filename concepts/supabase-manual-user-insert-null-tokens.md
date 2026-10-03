---
type: concept
domain: engineering/auth
source: Astro World admin session 2026-06-16
---
When you create a Supabase auth user by **raw SQL** (`insert into auth.users`)
instead of the GoTrue API, you MUST set the token columns to empty string `''`,
never leave them `NULL`:

- `confirmation_token`, `recovery_token`, `email_change`, `email_change_token_new`

These have **no DB default**, so an insert that omits them leaves `NULL`. GoTrue's
login query scans them into Go `string`s; `NULL` makes it error → the user gets an
**"invalid login credentials"** rejection **even though the password hash is correct**.

Symptom that nails it: one user logs in fine, another can't, same password method —
the broken one was hand-inserted. Fix:

```sql
update auth.users
set confirmation_token='', recovery_token='', email_change='', email_change_token_new=''
where email='...' and confirmation_token is null;
```

No redeploy needed — login hits Supabase directly, not the app build. **Better: create
users via the Admin API** (or the planned admin Users panel), which fills these correctly.

Hit live on 2026-06-16 creating `cquick@astros.com` for [[astroworld-status]].

## Links
[[astro-world]] · [[supabase-bcrypt-passwords]] · [[astroworld-status]] · [[coordinator-notes-app]] · [[MOC-astros-engineering]]
