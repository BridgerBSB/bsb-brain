# Database TCP-Retry + Pool Pre-Ping (BLOCKING)

LIVE on `feature/barrelsville` since May 8 2026 (commit `e3c218c`).
Replicable across all worktrees' `database.py`. This rule documents the
canonical resilient `run_query` pattern that keeps long-running pin jobs
alive on flaky home-VPN networks.

Pairs with `tracker-parquet-pins.md` §10 (sparse-pin recovery — that's
the AFTER-failure cleanup). This file is the BEFORE-failure prevention.

---

## Why this rule exists

Multi-hour pin job runs (`pin_*_seasons.py`) spawn ~35 concurrent SQL
connections from the work laptop (7 levels × 5 supplemental queries
each in parallel via ThreadPoolExecutor). On home VPN with NAT-state
limits or transient congestion, individual TCP streams die randomly.

**The cascade is brutal:**
1. One TCP stream drops mid-query → SQLAlchemy raises `OperationalError`
2. The dead connection sits in the pool
3. Next thread to grab that pool slot tries to reuse the dead socket → fails immediately with the same error
4. Within ~1 second, 5+ concurrent threads all fail
5. `_get_single_level_stats` catches the per-query exception, returns empty DataFrame
6. Downstream `pitch_df.merge(pa_df, on="batter_id")` crashes with `KeyError: 'batter_id'` because empty df has no columns
7. Whole year's pin build aborts; bundle never written

**Single TCP drop → entire year wasted.** Happens semi-randomly on
home VPN. Two retries per query would have saved the run.

---

## The fix — two changes in `database.py`

### 1. `run_query` auto-retries TCP drops

Wrap the query execution with a retry loop that detects transient TCP
errors via SQLSTATE matching, disposes the SQLAlchemy pool to clear
stale connections, and retries up to 3 times with backoff.

```python
import time
from sqlalchemy.exc import OperationalError, DBAPIError

# Retry config for transient TCP errors (VPN drops, NAT state expiry,
# server kills under high concurrent load). SQLSTATE 08S01 / 08001 =
# communication link failure (pyodbc errors 10053 "aborted by host" /
# 10054 "forcibly closed by remote"). Logical SQL errors are NOT retried.
_TCP_RETRY_SQLSTATES = ("08S01", "08001")
_MAX_RETRIES = 3
_RETRY_DELAY_SECONDS = 5


def _is_tcp_drop(exc: Exception) -> bool:
    """True if the exception is a transient TCP/network failure worth retrying.
    Matches SQLSTATE 08S01 / 08001 (pyodbc 10053 / 10054)."""
    msg = str(exc)
    return any(state in msg for state in _TCP_RETRY_SQLSTATES)


def run_query(query: str, params: dict = None) -> pd.DataFrame:
    """Execute a SQL query and return results as DataFrame.

    Auto-retries up to 3 times on transient TCP failures (VPN drops,
    NAT state expiry, server kills under high concurrent load). Each
    retry disposes the SQLAlchemy connection pool so the next attempt
    starts fresh — stale TCP-killed connections in the pool would
    otherwise fail immediately on reuse.
    """
    last_exc: Optional[Exception] = None
    for attempt in range(_MAX_RETRIES):
        try:
            engine = get_engine()
            with engine.connect() as conn:
                if params:
                    result = pd.read_sql(text(query), conn, params=params)
                else:
                    result = pd.read_sql(text(query), conn)
            return result
        except (OperationalError, DBAPIError) as e:
            last_exc = e
            if not _is_tcp_drop(e) or attempt == _MAX_RETRIES - 1:
                # Not a TCP error OR final attempt — re-raise
                raise
            # Transient TCP error — dispose pool, sleep, retry
            print(
                f"  [DB-RETRY] TCP drop detected (attempt {attempt + 1}/"
                f"{_MAX_RETRIES}), disposing pool + sleeping "
                f"{_RETRY_DELAY_SECONDS}s before retry..."
            )
            try:
                engine = get_engine()
                engine.dispose()
            except Exception:
                pass
            time.sleep(_RETRY_DELAY_SECONDS)
    if last_exc:
        raise last_exc
    return pd.DataFrame()
```

### 2. `pool_pre_ping=True` on `create_engine`

SQLAlchemy issues a cheap `SELECT 1` before reusing any pooled
connection. Cost: ~1ms per query (negligible vs. multi-second SQL).
Benefit: dead connections in the pool get auto-replaced. Eliminates
the cascade where one TCP drop killed the live connection and 5+
other threads then failed on stale pool slots.

```python
# Both code paths (FreeTDS / Connect AND Windows Auth / local)
_engine = create_engine(
    engine_url,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,   # auto-replace dead connections in pool
)
```

**Critical**: must be added to **every** `create_engine` call in
`get_engine()` — the FreeTDS path (Connect deployment) AND the
Windows Auth path (local dev / pin job runs).

---

## Why both changes are needed (not just one)

`pool_pre_ping` alone catches dead connections being reused. But it
doesn't help the **active** in-flight query that's CURRENTLY having
its TCP stream killed mid-result. That query still raises
`OperationalError` — the retry loop catches it, disposes the pool
(forcing fresh sockets on the next attempt), and tries again.

`run_query` retry alone catches the active failure but doesn't solve
the cascade where 4 OTHER concurrent threads now hit the dead pool
slots and fail simultaneously. `pool_pre_ping` makes those 4 sibling
threads recover transparently because the pre-ping detects the dead
socket and grabs a fresh one.

**Together: a single TCP drop logs ONE retry message and the run
continues. No cascade.**

---

## When to retry vs not — the SQLSTATE filter

The retry only fires on `08S01` or `08001` SQLSTATE — these are
**network-level failures**:
- `08S01` — communication link failure (pyodbc 10053 / 10054)
- `08001` — connection failure (rarer, similar shape)

**Not retried** (should fail fast):
- `42000` — syntax error
- `42S02` — table not found
- `42S22` — column not found
- `23000` — integrity constraint violation
- Any other SQLSTATE — propagates immediately

This way, a typo in a query name doesn't spin for 15 seconds before
erroring — the developer sees the real error immediately. Only genuine
network blips trigger the retry path.

---

## What the user sees in the log

**Before (cascade failure):**
```
[2025/away/all] batters ...   [TRACKER] pa query failed for afa/2025: (pyodbc.OperationalError) ('08S01', '...10054)')
  [TRACKER] pa query failed for aaa/2025: (...same...)
  [TRACKER] pitch query failed for afx/2025: (...same...)
  ...
KeyError: 'batter_id'
```

**After (transparent recovery):**
```
[2025/away/all] batters ...   [DB-RETRY] TCP drop detected (attempt 1/3), disposing pool + sleeping 5s before retry...
... 5563 rows (49.2s)
[2025/away/all] monthly_batters ... 16048 rows (28.0s)
```

If retries exhaust (3 consecutive same-query failures), the original
error propagates. That's a real outage, not a transient blip.

---

## Replication checklist for other worktrees

Apply this pattern to every worktree's `database.py`:

| Worktree | File | Status |
|---|---|---|
| `bsb-wt-hitting/barrelsville` | `src/database.py` | ✅ Done May 8 2026 (`e3c218c`) |
| `bsb-wt-bullpen/bullpen-report` | `src/database.py` | TODO |
| `bsb-wt-intangibles/astros-intangibles/intangibles` | `src/database.py` | TODO |
| `bsb-resources/pd-goals` | `src/database.py` | TODO |

### Steps per worktree

1. **Read the existing `database.py`** to find `run_query` and `create_engine` calls.
2. **Add imports**: `import time`, `from sqlalchemy.exc import OperationalError, DBAPIError`.
3. **Add module constants**: `_TCP_RETRY_SQLSTATES`, `_MAX_RETRIES`, `_RETRY_DELAY_SECONDS`.
4. **Add `_is_tcp_drop` helper.**
5. **Wrap `run_query` body** with the retry loop pattern shown above. Preserve the original signature (`query: str, params: dict = None`) so existing callers don't break.
6. **Add `pool_pre_ping=True`** to every `create_engine` call. Use `replace_all=True` if both FreeTDS + Windows Auth paths use the same arg pattern.
7. **Test with `python -c "from src.database import run_query; print(run_query('SELECT 1', {}))"`** — should still work normally on a happy path.

### What NOT to do

- **Don't change `run_query`'s signature.** It's called from many places. The retry is internal — callers see the same return type (DataFrame) or the same exception (final-attempt re-raise).
- **Don't widen the SQLSTATE filter.** Retrying syntax errors / missing-table errors hides real bugs. Stick to `08S01` / `08001`.
- **Don't bump `_MAX_RETRIES` past 3.** Past 3, the issue is real network downtime — sitting in retry loops just delays the inevitable.
- **Don't drop `pool_pre_ping=True`.** It's the half of the fix that prevents cascade — without it, one drop still cascades to all 5 sibling threads holding dead pool slots.
- **Don't forget the second `create_engine` call** if your worktree has both FreeTDS AND Windows Auth paths.
- **Don't add retry to other functions** (e.g. `test_connection`, `get_active_roster_ids`). They're either rare (test only) or already fail-fast for a reason. Only `run_query` benefits from the retry.

---

## Bug history

- **May 8 2026** — Barrelsville pin job: TCP drops at `[2025/home/r] monthly_batters` (first attempt) and `[2025/away/all] batters` (second attempt) caused full year aborts. The `[TRACKER] {label} query failed` per-query try/except returned empty DataFrame, then `pitch_df.merge(pa_df, on="batter_id")` raised `KeyError: 'batter_id'` because empty df has no columns. Fixed in `e3c218c`. Subsequent run completed all 5 years successfully — the user (zac) noted "that allowed '25 and '26 to go fast!!!"
- **Apr 23 2026** (precedent in intangibles) — same failure mode discovered during OF + IF 2024 pin builds. Different fix path: built `repair_tracker_pin.py` (sparse-pin recovery) but didn't address the BEFORE-failure prevention. This rule fills that gap.

---

## Cross-references

- `tracker-parquet-pins.md` §10 — sparse-pin recovery (AFTER failure)
- `tracker-parquet-pins.md` §5.13 — pin CLI bypass via `_TRACKER_PINS_AVAILABLE = False`
- `tracker-parquet-pins.md` §10.6 — the original `--per-level` mitigation (still useful as a fallback if retry exhausts on a genuinely degraded network)
- `streamlit-tracker-column-pinning.md` — Streamlit-side companion (different concern, same May 8 2026 work session)
- `kpi-parallelization.md` — explains the P2/P3/P4 parallelism that creates the concurrent-connection load this rule mitigates
