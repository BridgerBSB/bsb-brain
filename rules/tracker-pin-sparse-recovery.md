---
paths:
  - "**/*tracker*.py"
  - "**/pin_*.py"
---
# Tracker Parquet Pins — Sparse-Pin Recovery (parent section 10)

> **Extracted from `tracker-parquet-pins.md` 2026-05-19** to keep the
> parent rule under the article-recommended discoverability threshold.
> Parent has section pointers to this file. Auto-loaded with the parent
> on any tracker-related Python edit.

---

## 10. Sparse-pin recovery — when a long run writes incomplete data

Documented Apr 23-24 2026 after Intangibles OF + IF 2024 pin builds
were ruined by VPN/TCP drops over multi-hour runs. The pin CLI logs
each query failure but **continues writing the bundle**, so the final
pin can have empty (`0 rows`) or sparse (10-50% of expected) slices.
Subsequent runs read the bad pin, never re-query DB, and rewrite the
same garbage. Lost 6+ hours twice before realizing.

### 10.1. Failure mode signature

You ran `python scripts/pin_*_seasons.py --year YYYY --domain X`. It
took multiple hours, completed with `OK`, wrote the pin. But:

1. Bundle keys exist with `0 rows` (visible in the script's "writing
   pin" final summary).
2. OR bundle keys are populated but with significantly fewer rows than
   the same key in a known-good year (e.g. `2024 monthly_fielders_all:
   791` vs `2025 monthly_fielders_all: 8861`).
3. App users see correct data on some H/A toggles, EMPTY tables on others.
4. Subsequent CLI runs report `SERVED FROM PIN` and finish in seconds —
   they're not re-querying DB.

If you see all four signs, the pin is sparse. Don't run the full CLI
again expecting different results — pin-first is short-circuiting.

### 10.2. Diagnostic — compare row counts to a reference year

```powershell
python -c "from src.tracker_pins import load_tracker_bundle; b = load_tracker_bundle('OF', 2024); [print(f'{k}: {len(v)} rows') for k,v in sorted(b.items())]"
python -c "from src.tracker_pins import load_tracker_bundle; b = load_tracker_bundle('OF', 2025); [print(f'{k}: {len(v)} rows') for k,v in sorted(b.items())]"
```

Eyeball each slice's row count vs. the reference year. Any slice with
`<50%` of the reference's count is suspect. Empty (`0`) is automatic.

Diagnostic targets:
- 0 rows → definitely needs retry
- <50% of reference → needs retry
- 50-95% of reference → judgment call, probably retry
- 95-105% of reference → fine

### 10.3. The repair script — `repair_tracker_pin.py`

Lives in each app's `scripts/` dir. Currently shipped in:
- `intangibles/scripts/repair_tracker_pin.py` (covers OF + IF, shared module)

Three modes (in increasing scope):

| Flag | What it queries | When to use |
|---|---|---|
| (none) | Auto-detect 0-row slices, retry those | First-line fix when only a few slices are empty |
| `--force KEY [KEY ...]` | Empty slices + listed keys, retry all | When some slices are non-zero but suspect (low count) |
| `--rebuild` | All 15 slices regardless of state | When multiple slices are wrong and `--force` listing each is tedious |

Plus a transport modifier:

| Flag | Effect |
|---|---|
| `--per-level` | Query levels sequentially (mlb → aaa → aax → afa → afx → rok → dsl) instead of all-parallel. Cuts peak DB connections from ~15-20 to ~3. **Use this on flaky VPN.** |
| `--dry-run` | Print detected targets, exit before any DB hits. |

### 10.4. How it bypasses pin-first

The data module (`fielding_tracker_data.py`, etc.) checks
`_TRACKER_PINS_AVAILABLE` at the top of every `get_*` function. Repair
script monkey-patches `ftd._TRACKER_PINS_AVAILABLE = False` BEFORE any
`get_*` import resolves. Every subsequent call falls through to live DB.

Pattern in the script:
```python
from src import fielding_tracker_data as ftd
ftd._TRACKER_PINS_AVAILABLE = False  # before importing get_* functions
from src.fielding_tracker_data import get_fielder_leaderboard, ...
```

Order matters — set the flag BEFORE importing the get_* functions.
Different module patches don't share state.

### 10.5. Failure semantics

The repair script never deletes the existing pin. On per-slice failure:
- Existing data preserved (unchanged in the bundle)
- 0-row results from a re-run are treated as failure (don't overwrite
  preserved data with empty)
- Final write-back includes the merged dict — succeeded slices replaced,
  failed slices keep their original (possibly sparse) data
- Pin only re-written if at least one slice succeeded

Idempotent: running the same command again only retries what's still
wrong. Already-good slices stay good.

### 10.6. Hardening recommendation for the future

The full CLI (`pin_*_seasons.py`) should:
1. Abort with non-zero exit code if any single (level, prefix, ha)
   query returns 0 rows or raises an exception. Don't silently write
   a sparse pin.
2. Add `--per-level` mode mirroring the repair script. Optional flag,
   off by default for fast networks but available when network is flaky.
3. Add `--no-pin` / `--force-db` flag to bypass `_TRACKER_PINS_AVAILABLE`
   from the CLI invocation directly, without monkey-patching.

These are TODOs for whoever picks up tracker pin maintenance next.

### 10.7. Replication checklist for a new app

When adding repair_tracker_pin.py-style recovery to Arm Farm, BR,
or Catcher trackers:

1. Confirm the data module exposes a `_TRACKER_PINS_AVAILABLE` module flag.
2. Confirm the data module exposes the `PREFIX_*` constants and
   matching `get_*` functions (one per prefix).
3. Copy `repair_tracker_pin.py` from intangibles, adjust imports to
   the new app's data module + `tracker_pins` module path.
4. Update `PREFIX_TO_QUERY` dict to map prefix → (function,
   takes_seasons_list_arg). Note some functions take `season=int`,
   others `seasons=List[int]`. The bool tells the runner which.
5. Test with `--dry-run` first to confirm parser sees expected slices.
6. Document in this rules file: bug history + how recovery worked.

### 10.8. Bug history (Apr 23-24 2026)

- Apr 23 — Initial OF + IF 2024 build via full CLI on work laptop
  ran 6+ hours each. TCP drops on long-running queries left empty
  H/A slices. Subsequent retries served from bad pin.
- Apr 23 — `repair_tracker_pin.py` written with monkey-patch +
  auto-detect-empties + `--force` + `--dry-run`. Fixed initial
  EMPTY slices on first pass.
- Apr 23 — Second VPN drop revealed sparse-but-non-zero slices the
  auto-detect missed. Added `--per-level` flag to halve concurrent
  DB load and improve per-level visibility.
- Apr 24 — `--rebuild` flag added so user doesn't need to enumerate
  every suspect slice when many are wrong. Now `--rebuild --per-level`
  is the safest "redo it all" hammer.

Commits: `c44ce86` (initial repair), `f9e888a` (generalized
domain/year), `2b34a4b` (import fix), `f4a088c` (--per-level),
`a595068` (--rebuild).

---
