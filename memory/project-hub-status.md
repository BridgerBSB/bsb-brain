---
name: project-hub-status
description: "PD Project Hub kanban app — current state on feature/project-hub, deployed to Connect, work-laptop redeploy required for latest fixes"
metadata: 
  node_type: memory
  type: project
  originSessionId: bfb48537-87d0-4bf8-9669-c215e2de08f4
---

# PD Project Hub — Status (2026-05-26 evening)

## What it is

Internal kanban (Backlog / Active / Done) for tracking PD projects.
Native Streamlit (not iframe). Single parquet pin
`zbridger/project_hub_records`. Shared workspace, no per-user
attribution (Zac/Camden naming removed at user request).

## Worktree + branch

- Worktree: `C:\Users\Owner\bsb-wt-project-hub` (personal)
- Work-laptop equivalent: `C:\Users\zbridger\bsb-wt-project-hub`
- Branch: `feature/project-hub`
- App folder: `project-hub/`

## Deployed Connect content

- Content GUID: `e69ed6e9-a1cc-4a32-8021-252ed4928a6a`
- Content ID: `867`
- Title: `pd-project-hub`
- Brand mark: **AH** (was PH, user renamed)
- A duplicate `pd-project-hub` got accidentally created on Connect during
  the back-and-forth; user needs to delete the dup via Connect UI →
  Content → kebab menu → Delete Content. The keeper is GUID
  `e69ed6e9-...` / Content ID `867`.

## Commits on feature/project-hub (newest first)

| Commit | What |
|---|---|
| `63594b92` | 3 critical audit fixes: clean_pin owner KeyError, quick-add session_state mutation race, _pin_write silent-data-loss guard |
| `64b30888` | st.toast icon fix — real emoji (✅ ⚠️ ✏️) instead of look-alike symbol chars |
| `0b826793` | Dark-theme inputs — .streamlit/config.toml + strengthened CSS to kill white-on-white |
| `df2f78a1` | **REAL working kanban**: replaced broken iframe with native Streamlit. Dropped Zac/Camden everywhere |
| `7c0e933e` | deploy.ps1 uses `deploy manifest` (matches other apps); ASCII-only |
| `9c947c78` | (superseded by 7c0e933e) |
| `7f20d14d` | TLS-verify disabled for Connect self-traffic only |
| `fdc3f6fb` | Brand mark PH → AH |
| `01850448` | Audit-round-2 fixes (XSS, H1 reorder bug, archive throttle, owner filter, quick-add) |
| `51615f05` | Initial build |

## CRITICAL — work-laptop steps to get the live app current

```powershell
cd C:\Users\zbridger\bsb-wt-project-hub
git pull
cd project-hub
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
$env:CONNECT_API_KEY = "<key>"
.\deploy.ps1
```

User has redeployed several times; final pending one is for `64b30888`
(emoji fix). Without that, the deployed app crashes with
`StreamlitAPIException` the moment a card renders with move buttons.

## Bugs found and shipped during the session (audit-style log)

The Apr-23 / May-26 build had several issues that only surfaced in real
deployed-use. Documenting so the pattern is recognized next time:

1. **st.components.v1.html is ONE-WAY.** Built the original kanban
   as a custom iframe with SortableJS + setComponentValue back to
   Python. Drag events fired in the iframe; Python never received them.
   `components.v1.html()` doesn't support bidirectional component
   values — only `declare_component()` does. **Fix**: full rewrite to
   native Streamlit columns + per-card buttons. Loses drag animation,
   gains actually-persisting moves. Commit `df2f78a1`.

2. **Em-dashes in deploy.ps1** broke PowerShell parser with bogus
   "Array index expression" errors. Documented trap in
   `tracker-parquet-pins.md §12.3.8`. Knew the rule, broke it anyway.
   ASCII-only in PS scripts. Commit `7c0e933e`.

3. **`deploy streamlit` vs `deploy manifest`.** First version used
   `rsconnect deploy streamlit` which REGENERATES manifest.json from
   the local Python version. Local Python is 3.14 → Connect rejects
   (only has 3.11). Other apps in the fleet use `deploy manifest` →
   respects the manifest's declared 3.11.0. Commit `7c0e933e`.

4. **TLS verify failed server-to-itself** on Connect. Container
   doesn't trust Astros internal CA that signs connect2.astros.com.
   Pin write internally calls /api/v1/user → handshake fails. **Fix**:
   when `RSTUDIO_PRODUCT=CONNECT` (Connect-only env var), monkey-patch
   `requests.Session.request` to set `verify=False` ONLY for
   connect2.astros.com URLs. Other HTTPS calls keep strict TLS.
   Commit `7f20d14d`.

5. **White-on-white inputs.** Streamlit 1.49 default light theme on
   input chrome overrides any custom dark CSS. **Fix**:
   `.streamlit/config.toml` with `base = "dark"` + brand colors,
   plus strengthened input CSS targeting `.stTextInput input`,
   `.stTextArea textarea`, `.stSelectbox` etc. Commit `0b826793`.

6. **`st.toast(icon=)` rejects look-alike Unicode symbols** like ✓
   (U+2713), ⚠ (U+26A0), ✏ (U+270F), ↩ (U+21A9). They need to be
   real emoji or have the U+FE0F variation selector. Commit
   `64b30888`.

7. **Same-column reorder no-op** in `move_project()` — the map()
   targeted numeric pandas index instead of project_id. Silent failure.
   Fixed by rewriting the reorder logic to splice into a fresh
   ordered_ids list and renumber contiguously. Commit `01850448`.

8. **javascript: URL XSS** in user-typed link fields. Fixed via
   `_safe_url()` allowlist (http/https/mailto only). Same commit.

## Open items / future polish

### From high-effort code-review audit (12 deferred findings)

The 3 critical ones from the audit shipped in `63594b92`. These 12
remain — none are ship-blocking but worth a sweep next time someone
opens this project:

1. `update_project` lacks `VALID_STATUSES` check (move_project does
   validate — defensive code drift).
2. Concurrent-edit race: read-modify-write of the whole pin with no
   ETag/version. Acceptable for 2-user load; would need real per-row
   version field if it grows.
3. `force_identical_write=True` creates a pin version on EVERY write —
   long-term Connect storage growth + slower reads. Should be
   conditional / only set on initial write.
4. `archive_stale_done` throttle is per-session (st.session_state).
   New browser tab = fresh session = fires immediately even seconds
   after another tab did. Should be cross-session (module-level
   timestamp or pin metadata row).
5. TLS-verify monkey-patch is GLOBAL — overwrites `requests.Session.request`
   for the whole worker process. Can't be undone. `urllib3.disable_warnings`
   masks InsecureRequestWarning for every other library too.
6. `_safe_url` prefix-allowlist accepts `http://attacker.tld/@victim.tld`
   style confusion URLs. Better: `urllib.parse.urlparse` based check.
7. `archive_stale_done` sets the throttle timestamp even when
   `_pin_write` fails → silent hour-long stall before next attempt,
   no user-visible toast.
8. `move_project` coerces `order_idx` to int for ALL rows — pandas
   sort stability across rows with equal keys isn't guaranteed across
   major pandas releases; the next upgrade could reorder cards on
   every move.
9. Note timestamp `fromisoformat` parsing: edge cases on tz-aware
   strings degrade to raw display (cosmetic).
10. `'Z' → '+00:00'` `.replace()` is unsafe mid-string (only matters if
    future code writes non-naive timestamps).
11. `archive_stale_done` mixed tz-naive `datetime.utcnow().isoformat()`
    writes into a column that's been seen as tz-aware elsewhere —
    pandas TypeError potential on mixed-tz data.
12. `src/kanban_component.py` still in `manifest.json` files block.
    Orphaned (no imports anywhere). 670+ lines of unused JS deployed.
    Harmless but should be removed from the deploy bundle.

### Other follow-ups

- True drag-and-drop would require a real Streamlit custom component
  (declare_component). Not worth it for 2-user app.
- Apprentice / external user setup: doesn't need Python at all to USE
  the deployed Hub — just the URL.
- README.md still references the original schema with owner/created_by.
  Not user-visible (just docs); update on next pass.

## Recurring bug pattern (the meta-lesson)

Every bug shipped this session was a **deployed-runtime-only** issue —
local smoke tests passed because the data layer was sound, but Streamlit
behaviors (component bridge, widget-key mutation, emoji validator),
Connect specifics (TLS chain, manifest Python version), and shell
specifics (em-dash encoding, execution policy) only fired when the
bundle actually ran on Connect.

**For any future Streamlit-on-Connect app:** the smoke test MUST
include a deployed-environment run, not just local import + CRUD. The
canonical loop is:

1. Local smoke (imports + CRUD + py_compile) — what we already do
2. `streamlit run` locally and click every action — catches widget-key
   mutation bugs, toast emoji rejections, white-on-white CSS
3. Actual `deploy.ps1` to Connect + Connect-log scan — catches TLS
   chain issues, manifest Python mismatch, env-var-missing crashes,
   `st.components.v1.html` non-bridging
4. Click every action ON THE DEPLOYED URL — catches the integration
   bugs of (2) + (3)

Steps 2-4 weren't run before declaring "done" round 1. That's why we
shipped 8+ deployed-only bugs across the session.

## Pin info

- Name: `zbridger/project_hub_records`
- Format: parquet, single DataFrame
- Schema (13 cols, post-cleanup):
  `project_id, title, description, category, priority, status,
  order_idx, created_at, updated_at, target_date, done_at,
  notes_json, links_json`
- Doesn't exist on Connect yet (per latest log: "not yet created —
  first run?"). Will be created on first successful `add_project()`
  through the deployed app once the SSL fix + emoji fix both land.
