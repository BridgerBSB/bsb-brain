---
name: Never assume user hasn't redeployed
description: User always redeploys after we push a new commit. Don't treat "not redeployed" as a likely cause when diagnosing deployed-app issues.
type: feedback
originSessionId: 334240cb-a752-4e3e-b002-cdd449d74366
---
When diagnosing a deployed-app problem after a code change ships, NEVER list
"did you redeploy?" as a candidate cause. The user always redeploys after
pushing — it's step 1 for them, every time.

**Why:** User explicitly flagged this as an annoying assumption (Apr 21, 2026).
After pushing pin infrastructure + extending the tracker year options, the
deployed Barrelsville app was behaving slowly on 2025. I asked "did you
redeploy?" as diagnostic #1 — they had already redeployed and the deploy log
was visible in the same message I was replying to. Wasted turn and implied
user negligence.

**How to apply:** In any diagnostic flow after a push:
- Assume the user has already `git pull`ed and redeployed.
- Go straight to runtime causes: env vars in Connect Vars tab, pin read
  errors in app logs, package availability, network / SSL issues, actual
  code path bugs in what was just pushed.
- If redeploy status is genuinely ambiguous (e.g., they're asking an
  abstract question), phrase it as "once the app picks up the new code"
  rather than "assuming you've redeployed."
- Reach for app logs first. Connect logs for the Barrelsville app will show
  pin_read errors, CONNECT_API_KEY warnings, or runtime exceptions — that's
  the fast path to the real cause.
