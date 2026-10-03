---
type: concept
domain: engineering/auth
source: Astro World CLAUDE.md — hard-won
---
Users on **Microsoft 365** (`@astros.com`) sit behind **Safe Links**, which
**pre-clicks every link in inbound mail (a GET) before the user sees it.**

Supabase's default reset/confirm emails use a **one-time LINK** consumed the
instant it's opened → the scanner burns it → the real user gets `otp_expired`.
**Any clickable auth link to an `@astros.com` inbox WILL break.**

**Fix — a typed 6-digit CODE, never a link:**
- Email template uses `{{ .Token }}`, NOT `{{ .ConfirmationURL }}`.
- Reset: `resetPasswordForEmail(email)` → user types code →
  `verifyOtp({ email, token, type:'recovery' })` → `updateUser({ password })`.
- Signup: disable email confirmation (instant-active) OR make it code-based too.
  Never a clickable confirmation link.

Applies to **any** M365-tenant email auth (Astro World, [[coordinator-notes-app]]).

## Links
[[astro-world]] · [[astroworld-status]] · [[supabase-bcrypt-passwords]] · [[supabase-manual-user-insert-null-tokens]] · [[MOC-astros-engineering]]
