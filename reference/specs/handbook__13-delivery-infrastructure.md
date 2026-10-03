# Delivery Infrastructure

PDFs we generate end up in three places: per-player Slack channels,
per-affiliate Slack channels, and the org-wide
`weekly-player-updates` channel. Plus parquet pins on Posit Connect
that cache tracker data, goals data, and submitted transition
reports. Plus six Connect-scheduled jobs that refresh those pins
every six hours.

This chapter is the operational backbone --- the Logic App pipeline,
Slack channel routing, the parquet pin pattern, and the
Connect-scheduled job setup playbook.

::: tip
**What you'll learn:** the Logic App payload contract, the two
delivery functions (`send_reports_via_logic_app` vs
`send_to_channel`), the slack_channels.csv 5-copy sync rule, the
parquet pin architecture, the Connect-scheduled job 8-bug playbook,
and the combined KPI stapler.
:::

## The Logic App pipeline

```
Python CLI / Streamlit submit handler
         │
         │ generates PDF on disk
         ▼
   base64-encode PDF
         │
         │ POST {"channel": cid, "filename": fn, "pdf": b64}
         ▼
Azure Logic App HTTP trigger
         │
         │ pd-report-delivery → astros-file-uploader
         ▼
       Slack channel
```

The Logic App is a **dumb pipe** --- routing happens in Python, the
Logic App just translates HTTP POST → Slack file upload. We pay no
Azure costs for it (it's a single workflow, free tier).

### Payload shape (BLOCKING)

The Logic App expects **exactly three fields** with these exact names:

```python
payload = {
    "channel":  channel_id,    # "C..." Slack channel ID
    "filename": filename,      # os.path.basename(pdf_path)
    "pdf":      pdf_b64,       # base64.b64encode(pdf_bytes).decode("utf-8")
}
requests.post(logic_app_url, json=payload, timeout=60)
```

::: blocking
**The Logic App returns HTTP 200/202 for any JSON body, even if the
fields are wrong.** If you name the base64 field `content_base64`,
`file`, `data`, or `body`, the HTTP call succeeds, the script prints
"Delivered to C...", but **nothing appears in Slack**. There is no
error. Only missing files in Slack are the signal.

Three rules:

1. NEVER write a `_deliver_pdf` function from scratch. Always copy
   from a working script (`generate_of_report.py`,
   `generate_br_daily_report.py`, `generate_if_report.py`,
   `generate_catcher_report.py`).
2. Field name for base64 is `pdf`, not `content_base64`, not `file`,
   not `attachment`. No exceptions.
3. Do NOT add extra fields (`message`, `text`, `caption`) --- the
   Logic App ignores them but their presence suggests the author
   didn't read a reference.

Historical incident: `mazzo_special.py` was written with
`"content_base64"` instead of `"pdf"` (Apr 17 2026). Delivered
successfully with HTTP 200 for a day before the channel was checked
and found empty.
:::

### Logic App URL

```
https://prod-23.southcentralus.logic.azure.com:443/workflows/3292e67eb848406cb462ebccc1e90974/triggers/When_an_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_an_HTTP_request_is_received%2Frun&sv=1.0&sig=jWC_Z81adrGeLEEQ4WQBH0VSla1l7qDrP6IFpQAdnas
```

Set in environment via `LOGIC_APP_URL`. On the work laptop, add to
PowerShell `$PROFILE`:

```powershell
$env:LOGIC_APP_URL = "https://prod-23.southcentralus.logic.azure.com..."
```

Then all CLIs pick it up automatically --- no `--logic-app-url` flag
needed.

## Two delivery functions

### `send_reports_via_logic_app()` --- per-player routing

Used by: postgame (Arm Farm, Barrelsville), BR, OF/IF daily.

```python
send_reports_via_logic_app(
    pdf_dir,
    logic_app_url,
    channel_col='channel_id',    # 'channel_id' (zzz_) or 'z_channel_id' (z_)
)
```

**Routing:** filename → parse `groundcontrol_id` → CSV lookup →
channel_id → POST.
**Fallback chain:** `z_channel_id` → `zzz_channel_id` (fallback) →
overflow channel (`pd-automation-test`, `C0ABHSF6SCA`).

### `send_to_channel()` --- explicit channel routing

Used by: advance batch (Barrelsville), IF per-affiliate, KPI reports.

```python
send_to_channel(
    pdf_paths,
    channel_id='C0ABC123DEF',   # explicit channel, no CSV lookup
    logic_app_url=url,
)
```

**No routing logic** --- caller provides the channel directly. Used
when delivering to team/level channels instead of per-player channels.

### `deliver.py` --- three copies

| Project | File |
|---|---|
| Arm Farm | `bullpen-report/src/deliver.py` |
| Barrelsville | `barrelsville/src/deliver.py` |
| Intangibles | `intangibles/src/deliver.py` |

All three are functionally identical. They read from
`pd-goals/data/slack_channels.csv` (which is mirrored across all four
worktrees). PD Engine doesn't have its own `deliver.py` --- it has
`transition_slack.py` and inline calls in CLI scripts.

## Slack channel routing

### Channel naming convention

| Pattern | Purpose |
|---|---|
| `zzz_<player_name>` | Coach-facing channel for that player (postgame, KPI, advance) |
| `z_<player_name>` | Player-facing athlete channel (PD goals, transition, dev feedback) |
| `<affiliate>_<domain>` (e.g. `sugarland_barrelsville`, `corpus_intangibles`) | Per-affiliate per-domain channels (one per app per level) |
| `z1_sugar_land`, `z2_corpus_christi`, `z3_asheville`, `z4_fayetteville`, `wpb_complex` (FCL), `z8_dominican_academy` (DSL) | General affiliate channels |
| `pd-automation-test` (`C0ABHSF6SCA`) | Overflow / test channel |
| `weekly-player-updates` (`C0AVBKPEG8H`) | Org-wide analysis + KPI snapshots (single channel, Zac + Sam) |
| `milb_boxscores` (`C0APYUYFYMP`) | All boxscore PDFs (Barrelsville) |

### Two channel types: zzz_ vs z_

::: blocking
**NEVER rename a `zzz_` row to `z_` in `slack_channels.csv`.** They
are DIFFERENT channels. When adding a `z_` channel for a player,
ALWAYS add a NEW row. The `zzz_` row must remain untouched. Both rows
must exist in the CSV.

`pd-goals/data/slack_channels.csv` has BOTH columns:

- `groundcontrol_id` --- player's GC ID (join key)
- `channel_id` --- `zzz_` coach channel ID
- `z_channel_id` --- `z_` athlete channel ID
:::

### `slack_channels.csv` --- the 5-copy sync rule (BLOCKING)

`pd-goals/data/slack_channels.csv` is the single source of truth for
channel routing across ALL four apps. It exists in **five copies**
that must stay in sync:

| Path | Worktree |
|---|---|
| `bsb-resources/pd-goals/data/slack_channels.csv` | PD Engine main |
| `bsb-wt-bullpen/pd-goals/data/slack_channels.csv` | Arm Farm |
| `bsb-wt-hitting/pd-goals/data/slack_channels.csv` | Barrelsville |
| `bsb-wt-intangibles/astros-intangibles/pd-goals/data/slack_channels.csv` | Intangibles (canonical path) |
| `bsb-wt-intangibles/astros-intangibles/intangibles/data/slack_channels.csv` | Intangibles internal fallback |

The fallback in `intangibles/data/` is a never-fires-at-runtime safety
net (the canonical PD-Goals path always wins), but it must stay in
sync because `intangibles/src/deliver.py:47-49` checks the canonical
FIRST and only falls back to the internal copy if the canonical is
missing.

### How to add/edit/remove a row

```bash
# Update ALL five at once with printf, NOT one-at-a-time editing
for f in \
  /c/Users/Owner/bsb-resources/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-bullpen/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-hitting/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/pd-goals/data/slack_channels.csv \
  /c/Users/Owner/bsb-wt-intangibles/astros-intangibles/intangibles/data/slack_channels.csv; do
  printf '<gc_id>,<Player Name>,<channel_name>,,<channel_id>,coach,\r\n' >> "$f"
done
```

**Verify with `wc -l`:** all 5 line counts must match. CRLF line
endings preserved (Windows convention). Commit + push on EACH
worktree's feature branch (4 separate commits).

## Channel routing tables

### Intangibles per-affiliate channels (BR/OF/IF/Catcher daily + KPI)

| Route Key | Channel Name | Channel ID |
|---|---|---|
| mlb | `pd-automation-test` | `C0ABHSF6SCA` |
| aaa | `sugarland_intangibles` | `C0AKNKW1UKU` |
| aax | `corpus_intangibles` | `C0AL1HM1CDP` |
| afa | `asheville_intangibles` | `C0AK76YS1NK` |
| afx | `fayetteville_intangibles` | `C0AKNL9BGN6` |
| rok | `fcl_intangibles` | `C0AKG8WA267` |
| dsl | `dsl_intangibles` | `C0AK777QM47` |

**DSL/FCL split:** both use `level_code='rok'` in DB. Split by
`gc2_level_code`: `'dsl'` → `dsl`, `'rok'` → `rok`.

### Combined KPI stapler --- affiliate channels (Apr 28 2026)

| Level | Combined PDF goes to | Channel name |
|---|---|---|
| `mlb` | `C0ABHSF6SCA` | pd-automation-test (overflow) |
| `aaa` | `GFYF1JQR1` | z1_sugar_land |
| `aax` | `CFXS0BMLG` | z2_corpus_christi |
| `afa` | `GFYF4K3GB` | z3_asheville |
| `afx` | `GFYJ94D2N` | z4_fayetteville |
| `rok` | `C0516HKL6KX` | wpb_complex (FCL) |
| `dsl` | `CFZLA3W2K` | z8_dominican_academy |

This map lives ONLY in
`pd-goals/scripts/generate_combined_kpi.py`. **Never duplicate it in
any other file.**

## The Combined KPI Stapler

The 6 weekly KPI reports each deliver to their per-domain channel
(e.g. Hitter to `sugarland_barrelsville`). Until Apr 2026, each ALSO
delivered to the affiliate channels (`z1_sugar_land`, etc.) ---
meaning every Sunday those channels got blasted with 6 PDFs in a row.
That was the spam.

### The fix --- two-stage delivery

```
                                  (each script lives in its own worktree)
┌─────────────────────────┐    ┌──────────────────────────────────┐
│  6 individual KPI       │----->│  Per-domain Slack channels      │
│  scripts                │    │  (sugarland_barrelsville, etc.)  │
│  (run sequentially      │    │  ← single PDF per script         │
│   on Sunday, untouched  │    └──────────────────────────────────┘
│   by this pattern)      │
└─────────────────────────┘
            │
            │ writes 6 per-level PDFs to each
            │ worktree's output/ directory
            ▼
┌─────────────────────────┐    ┌──────────────────────────────────┐
│  Combined stapler       │----->│  General affiliate channels     │
│  pd-goals/scripts/      │    │  (z1_sugar_land, etc.)           │
│  generate_combined_     │    │  ← ONE combined PDF per level    │
│  kpi.py                 │    │  ← MLB → pd-automation-test      │
│  (run AFTER the 6)      │    └──────────────────────────────────┘
└─────────────────────────┘
```

**Stage 1** (per-domain): each of the 6 scripts continues to deliver
its single PDF to its own per-domain channel. This is unchanged.

**Stage 2** (combined affiliate): AFTER the 6 finish, the stapler
runs once. It does not re-query DB, does not re-render any report; it
reads the PDFs the 6 scripts already wrote to disk, trims their first
page, staples them with `pypdf`, and POSTs ONE combined PDF per level
to the affiliate-channel map.

### CLI usage

```bash
# Default — generate all 7 levels, no Slack delivery
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26

# Generate + deliver to affiliate channels
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26 --deliver

# Single level (testing)
python pd-goals/scripts/generate_combined_kpi.py --end 2026-04-26 --level aaa --deliver
```

### Sunday run order

```bash
# 1) Run the 6 individual KPI scripts (existing weekly workflow)
python barrelsville/scripts/generate_hitter_kpi_report.py --end <date> --weeks 2 --deliver
python bullpen-report/scripts/generate_pitcher_kpi_report.py --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_of_kpi_report.py        --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_if_kpi_report.py        --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_br_kpi_report.py        --end <date> --weeks 2 --deliver
python intangibles/scripts/generate_c_kpi_report.py         --end <date> --weeks 2 --deliver

# 2) Then the stapler — picks up the 6 PDFs, builds + delivers combined PDFs
python pd-goals/scripts/generate_combined_kpi.py --end <date> --deliver
```

### What CHANGED in each of the 6 KPI scripts

ALL SIX scripts had `AFFILIATE_CHANNEL_IDS` dict + a 4-line delivery
block. Both were removed. Each modified script now has a tripwire
comment in place:

```python
# Affiliate-channel delivery is owned by pd-goals/scripts/generate_combined_kpi.py
# (the combined-KPI stapler). This script only sends to the per-domain channels
# above. Run the combined script after all 6 weekly KPI runs finish.
```

::: blocking
**NEVER re-add `AFFILIATE_CHANNEL_IDS` or affiliate-channel delivery
to any of the 6 individual KPI scripts.** That's how the spam comes
back. The tripwire comment is the last line of defense.
:::

## Parquet pins on Posit Connect

Posit Connect provides a `pins` package that lets us write Python
objects (DataFrames, dicts of DataFrames) to Connect-managed storage
that survives container restarts and is shareable across apps.

### What we pin

| Pin name | Type | Refresh | Purpose |
|---|---|---|---|
| `zbridger/pd_goals_data` | parquet DataFrame | 6h via `pin_goals.py` (Connect-scheduled) | Goals roster (mirrored from `goals.csv`) |
| `zbridger/<app>_tracker_<year>` | joblib bundle (dict of DFs) | 6h for current year, frozen for historical | Trackers (5 trackers × 6 years = 30 pins) |
| `zbridger/transition_reports` | parquet DataFrame | On submit (live) | Transition Report submissions |
| `zbridger/transition_drafts` | parquet DataFrame | On save (live) | Transition Report drafts |

### Reading a pin

```python
# pins_config.py — adjust per app
from pins import board_connect

def get_board():
    return board_connect(
        server_url="https://connect2.astros.com",
        api_key=os.environ["CONNECT_API_KEY"],
        allow_pickle_read=True,    # required for joblib bundles
    )

# Reading a tracker bundle
board = get_board()
bundle = board.pin_read("zbridger/barrelsville_tracker_2024")
# bundle is a dict: {"batters_all": df, "monthly_orgs_home": df, ...}
```

::: blocking
**`allow_pickle_read=True` is required for joblib bundle pins**
(tracker pins are joblib because dict-of-DataFrames doesn't fit in
parquet's tabular schema). Without it, every pin read raises
`PinsInsecureReadError`. Parquet pins (e.g. `pd_goals_data`) don't
need it.
:::

### Writing a pin (work laptop, not Connect)

```bash
$env:CONNECT_API_KEY = "..."
python pin_goals.py          # writes zbridger/pd_goals_data
```

Or via a Connect-scheduled job (see next section).

## Connect-scheduled jobs

Some pin refreshes run on Connect's scheduler --- typically every 6
hours during the season. They're deployed as Jupyter notebooks
(`appmode: jupyter-static`) wrapping a Python script.

### Architecture

```
{app}/connect_pins/
├── pin_tracker_2026.ipynb       # Notebook wrapping the .py script's main()
├── deploy.ps1                   # PowerShell deploy automation
├── .gitignore                   # excludes bundled-at-deploy copies
└── (manifest.json, requirements.txt, src/, pin_*.py — generated at deploy time)
```

The notebook uses `importlib.util.spec_from_file_location` to load the
wrapped script (it's not a Python package, so a regular import doesn't
work). `deploy.ps1` copies the script + needed `src/*.py` modules into
`connect_pins/` at deploy time, runs `rsconnect`, then deletes the
copies.

### Required Connect content vars

| Var | Purpose |
|---|---|
| `CONNECT_API_KEY` | Pin RW auth (auto-injected by Connect, but doesn't hurt to set) |
| `DB_USER` | FreeTDS user (e.g. `rs_connect_ro`) --- required because Linux containers can't do Windows Auth |
| `DB_PASS` | FreeTDS password |

### The 8 deploy gotchas (BLOCKING)

These bit us during the Barrelsville pilot. Avoid them all:

1. **Streamlit `manifest.json` poisons notebook deploys.** Deploying
   from a project root that has a Streamlit manifest makes Connect
   classify the new content as Streamlit too. Schedule tab grayed
   out. Fix: deploy from a clean subdirectory (`connect_pins/`).
2. **`rsconnect-python` rejects `appmode python-script`.** Use
   `appmode: jupyter-static` with a notebook wrapper that
   imports + calls the .py script's `main()`.
3. **Local Python version mismatched with Connect runtime.**
   `rsconnect` bundles metadata using whatever Python is running it.
   If local is 3.14 and Connect only has 3.11/3.12, deploy fails.
   Fix: hand-write `manifest.json` with `platform: "3.11.0"` +
   `python.version: "3.11.0"`. Don't rely on auto-detection.
4. **PowerShell `Set-Content -Encoding utf8` writes BOM.** Python
   `json.loads` rejects UTF-8 BOM. Fix: use .NET
   `File.WriteAllText` with `UTF8Encoding($false)`.
5. **`requirements.txt` must exist BEFORE manifest checksums.**
   If the manifest references `requirements.txt` but the file
   doesn't exist when the bundle uploads, Connect's build fails.
   Fix: generate `requirements.txt` FIRST, then compute checksums.
6. **Manifest must have `metadata.entrypoint`.** Without it,
   Connect's launch step fails.
7. **Connect's Linux container can't do Windows Auth.** Set
   `DB_USER` + `DB_PASS` in the Connect content's Vars tab.
8. **Em-dashes in `.ps1` get mangled by Windows encoding.** ASCII-only
   in `.ps1` files.

Plus minor friction: PowerShell execution policy blocks unsigned
scripts. Per-session bypass:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

::: blocking
**Pin CLIs MUST bypass `_TRACKER_PINS_AVAILABLE` to force a fresh DB
read.** Otherwise the CLI reads from its own pin and writes back the
same data. Pattern:

```python
import src.{tracker}_tracker_data as _td
_td._TRACKER_PINS_AVAILABLE = False  # force DB queries
```

Apr 27 2026 incident: SQL filter changes weren't propagating to pins
even after re-running the CLI. Cache layer was eating the change.
Fix lives in all four pin CLIs.
:::

### Step-by-step deploy for a new tracker

1. Add 2026 to `PINNED_YEARS` in `pins_config.py`.
2. Initial 2026 backfill on work laptop.
3. Build `<app>/connect_pins/` directory with notebook + deploy.ps1.
4. Run `deploy.ps1` from the work laptop.
5. Configure Connect UI: Vars + Schedule.
6. Verify the deployed app loads fast on 2026 data.

Full playbook (with the 8 gotchas detailed): `.claude/rules/tracker-parquet-pins.md`.

## Sparse pin recovery (rare)

When a multi-hour pin write fails partway (TCP drop, VPN hiccup), the
pin gets written with empty / sparse slices. The pin CLI logs each
query failure but **continues writing** the bundle, so the final pin
can have empty (`0 rows`) or sparse (10-50% of expected) slices.

Symptoms:

- Pin completes with `OK`, but bundle keys have `0 rows` or much
  fewer than reference year.
- App users see correct data on some H/A toggles, EMPTY tables on
  others.
- Subsequent CLI runs report `SERVED FROM PIN` --- they're not
  re-querying.

Fix: each Intangibles tracker has a `repair_tracker_pin.py` script
that:

1. Sets `_TRACKER_PINS_AVAILABLE = False` at module import (bypasses
   pin-first).
2. Auto-detects 0-row slices.
3. `--force KEY [KEY ...]` to retry suspect non-zero slices.
4. `--rebuild` for "redo all 15 slices regardless."
5. `--per-level` to query levels sequentially (lower DB connection
   peak --- helpful on flaky VPN).

Pattern can be ported to other apps' pin CLIs as needed.

## Where to look next

- **Chapter 14** for the "deploy a new feature" recipe.
- `.claude/rules/delivery.md` --- the canonical delivery rule.
- `.claude/rules/slack-channels-sync.md` --- the 5-copy CSV sync.
- `.claude/rules/combined-kpi-stapler.md` --- stapler architecture.
- `.claude/rules/tracker-parquet-pins.md` --- the full pin playbook
  (one of the longest rule files; ~1100 lines).
- `.claude/rules/in-app-submission.md` --- pin pattern for live forms.
