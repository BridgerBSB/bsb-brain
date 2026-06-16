# PD Goals — Transition Report (Card 2, LIVE Apr 24 2026)

> **Extracted from `pd-goals.md` 2026-05-19** to keep the parent rule under
> the article-recommended discoverability threshold. See parent for
> `## Transition Report — Card 2` pointer. Auto-loaded with the parent on any
> Python edit in `pd-goals/`.

---

## Transition Report — Card 2 (LIVE Apr 24, 2026)

Second landing card. Questionnaire for documenting player level transitions
(promotions and demotions). Architecture = the `in-app-submission.md`
reusable pattern — follow that rules file first before making changes here.

### Files

| Role | File |
|---|---|
| Submit form | `pd-goals/pages/2_Transition.py` |
| Browse (3 tabs: Feed / Kanban / Per-Player) | `pd-goals/pages/3_Transitions_View.py` |
| Pin read/write (submissions + drafts) | `pd-goals/src/transition_pins.py` |
| View-page data layer | `pd-goals/src/transition_view_data.py` |
| PDF generator (Trello card, portrait) | `pd-goals/src/transition_pdf.py` |
| Channel routing | `pd-goals/src/transition_channels.py` |
| Logic App delivery wrapper | `pd-goals/src/transition_slack.py` |
| Cleanup CLI | `pd-goals/scripts/clean_transition_submissions.py` |

### PDF rendering — dynamic heights + page-2 spillover (May 25 2026)

`transition_pdf.py` uses a measure-then-draw pattern with per-block
heights computed from actual content (NOT fixed-pixel section heights).
Long coach answers get the room they need; short ones don't waste space.
If total content exceeds the single-page budget, overflow spills cleanly
to page 2.

**BLOCKING float-precision lesson** baked into the wrap renderer: line
counting uses `int((max_h + 0.5) // line_h)` (NOT `int(max_h // line_h)`)
because IEEE float subtraction drifts `n * 12.15` to `48.599999999999994`,
and `int(48.599... // 12.15) == 3` instead of 4. Without the 0.5px
tolerance, every block budgeted for `n` lines renders `n-1` with
spurious ellipsis.

See `in-app-submission.md` §3c for the full pattern (reusable for any
future free-text PDF in this codebase).

### Pins

- `zbridger/transition_reports` — submissions (append-on-submit, locked after write)
- `zbridger/transition_drafts` — drafts (upsert via Save Draft, deleted on submit)

Both use the existing `pd-goals/src/pins_config.py` board — no separate
auth. `CONNECT_API_KEY` in the app's Vars tab covers both pins and the
PD Goals pin.

### Form shape

Submitter name + Player (eBis dropdown, autopulls from PP_MASTER) +
Current Level (auto from `LEVELOFPLAY_LK`) + Next Level (default one up,
MLB→MLB preserved, editable for demotions) + Positions (multi) +
Working On {Off/Def/BR} + Routines {Off/Def/BR} + Effective Coaching +
MLB Support Needs + Notes.

### Delivery routing

Player's `zzz_` coach channel (from `slack_channels.csv`) + receiving
affiliate channel from `AFFILIATE_CHANNELS[next_level]`. Fallback to
`pd-automation-test` (`C0ABHSF6SCA`) on any miss.

DSL channel is currently `None` — falls through to overflow until user
provides the real channel ID.

### Test mode toggle

Checkbox above Submit reroutes every leg to `pd-automation-test` only.
Safe QA without spamming coach channels. Default off.

### Required env vars (Vars tab on Connect)

| Variable | Purpose |
|---|---|
| `CONNECT_API_KEY` | Pin auth (already set for PD Goals pin) |
| `LOGIC_APP_URL` | Slack delivery (full URL in `delivery.md`) |

If `LOGIC_APP_URL` is missing: submission still saves, just shows a
clean error banner. No data loss. This was the initial deploy failure
mode on Apr 23 2026 — pin wrote, Slack didn't; Browse view showed the
FAILED badge. Fixed by adding the env var.

### Redeliver workflow (BLOCKING — testing PDF changes without coach resubmissions)

`pd-goals/scripts/redeliver_transition.py` reads any existing submission
from the pin and rebuilds the PDF with the current codebase. Used to QA
PDF-rendering changes (layout fixes, new sections, etc.) against real
production data WITHOUT asking a coach to resubmit a form.

```powershell
# On work laptop (has corp network to reach connect2.astros.com):
cd C:\Users\zbridger\bsb-resources
git pull
$env:CONNECT_API_KEY = "<the key>"            # PER POWERSHELL SESSION

# See what's in the pin
python pd-goals/scripts/redeliver_transition.py --list

# Most common: build PDF locally, drag into Slack manually
python pd-goals/scripts/redeliver_transition.py --player "Drew Brutcher" --no-deliver
python pd-goals/scripts/redeliver_transition.py --player "Jack Moss" --no-deliver

# PDFs land in pd-goals/output/_redeliver/
```

For players without a `zzz_` coach channel yet (e.g., Moss while moving
levels), `--no-deliver` is the right move — render local, forward
manually to whichever coach via Slack DM/upload.

**CRITICAL gotcha: `$env:CONNECT_API_KEY` is per-PowerShell-session.**
Open a new terminal tab → it's blank. If `--list` shows 0 submissions
when you know the pin has real data, that's the first thing to check:

```powershell
$env:CONNECT_API_KEY    # blank = forgot to set in this window
```

Pin reads fail silently when the key is missing — `board_connect()`
returns a board object, but `pin_read()` raises an auth error, my
`_pin_read` catches it with a hidden `logger.warning`, returns `None`,
caller falls back to an empty local CSV. Net effect: script reports 0
rows and says "no submission matching player." First debug step is
ALWAYS to verify the env var.

See `in-app-submission.md` §3f for the full failure-mode breakdown and
§6b for the redeliver pattern as a reusable template for other apps.

### Cleanup workflow

```powershell
# Work laptop, CONNECT_API_KEY set
python pd-goals/scripts/clean_transition_submissions.py --list
python pd-goals/scripts/clean_transition_submissions.py --clear-all --confirm
# OR
python pd-goals/scripts/clean_transition_submissions.py --delete <uuid> <uuid>
```

Pin data is independent of the deployed app. After cleanup:
- View page is cached for 60s per user session (`@st.cache_data(ttl=60)`)
- Wait 60s OR hard-refresh the browser to see fresh state
- No redeploy / restart needed

### Known Streamlit gotchas (all resolved in current code, don't reintroduce)

1. Widget-key state cannot be mutated AFTER the widget renders in the same run. Load Draft uses the deferred-load pattern: click → stash row in `t_pending_draft_load` + `st.rerun()` → `_apply_pending_load()` at top of next run hydrates state BEFORE widgets instantiate. Full explanation in `in-app-submission.md` §5.
2. Never pass both `value=` and `key=` on a widget. Key-only state throughout.
3. Reactive dropdowns (player → level defaults) must update `st.session_state` BEFORE the level selectbox renders. Change-detection block lives between the player selectbox and the Current Level selectbox.

### Pitcher variant — `report_type` split (LIVE May 3, 2026)

Same form, same pin, two question blocks. Auto-detects role from selected
player's `PP_MASTER.POSITION_LK` and conditionally renders the right
questionnaire. PDF + browse view both branch on `report_type` to render
the right layout.

**Detection (single source of truth):** `_PITCHER_POSITIONS` constant in
`pd-goals/pages/2_Transition.py` = `frozenset({'RHP','LHP','RHS','RHR',
'LHS','LHR','P','SHS','TWP'})`. Matches the canonical pitcher list in
`rules/draft-tables.md`. **TWP routes to pitcher** (more specialized
question set; rare in Astros system, no manual override).

**Schema (in `transition_pins.py::SUBMISSION_COLUMNS`):**
- `report_type` — `"position"` | `"pitcher"`. Defaults to `"position"`
  on read via `_conform` for legacy rows submitted before May 3.
- 7 nullable pitcher-specific columns: `daily_routine_day_before`,
  `daily_routine_day_after`, `daily_routine_side_day`,
  `daily_routine_game_day`, `side_structure`, `review_process`,
  `coaching_preference`.
- Position columns (`working_on_*`, `routines_*`, `effective_coaching`,
  `mlb_support_needs`) stay populated only on position rows.
- `_collect_form_row` writes ONLY the active role's fields; the other
  role's columns get explicit `None` so stale half-typed answers from a
  prior player selection can't bleed into the wrong submission.

**Form behavior:**
- Tiny role badge (green `POSITION` or navy `PITCHER`) above the
  question block tells the coordinator which variant rendered.
- Pitcher form swaps `Positions` multiselect for auto-set (uses
  player's `POSITION_LK` directly).
- `_validate` branches per role: pitcher requires ≥1 pitcher answer;
  position keeps the existing Working-On rule.
- `_form_signature` + `_apply_pending_load` cover both field families
  so drafts of either type round-trip cleanly through Save → Load.

**PDF (`transition_pdf.py`):** `build_transition_pdf` branches on
`row["report_type"]`. Two body functions (`_draw_body` for position,
`_draw_body_pitcher` for pitcher) share the navy header / outer card /
level pills / footer chrome. Pitcher layout = 2x2 Daily Routine grid
(via `_draw_quad_card`) → Side Structure | Review Process →
Coaching Preference | Notes. Same `HEADER_RESERVE` (36px) for question
prompts on both layouts.

**Question prompts on the PDF:** `POSITION_QUESTIONS` and
`PITCHER_QUESTIONS` dicts in `transition_pdf.py` hold the canonical
prompts. `_draw_question_header` renders them in bold dark text
(fontsize 10, wrapped to 2 lines max). Match the form's prompts in
`pd-goals/pages/2_Transition.py` exactly — both files reference the
same string content. **If you change a prompt in one place, update the
other.**

**Browse view (`3_Transitions_View.py`):** Feed cards show a
`POSITION` / `PITCHER` pill next to the player name. Preview text
falls back to pitcher fields (game-day routine → side structure →
review process → coaching prefs → day-before routine) when
`working_on_offense` is empty. Expanded view branches per
`report_type` to show the right field layout.

**Form ergonomics fixes (May 3, 2026):**
- `_cached_all_drafts()` + `_cached_drafts_for_name()` wrap the pin
  reads with `@st.cache_data(ttl=30)`. Without this, every text_area
  blur triggered 2 uncached pin reads and made typing feel laggy.
  `_invalidate_drafts_cache()` MUST be called after every Save Draft /
  Submit / Discard / Delete or the resume banner shows stale state.
- Post-submit form clear via `_apply_pending_form_clear()` (deferred
  pattern, mirrors `_apply_pending_load`). Submit handler sets
  `t_pending_form_clear = True`; helper at top of next run wipes the
  answer-field session_state keys before any widget instantiates.
  Preserves submitter_name, player_select, level selects, positions,
  and test_mode so a coordinator can file multiple transitions in a
  row without re-picking those.
