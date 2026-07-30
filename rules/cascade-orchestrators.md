---
paths:
  - "**/run_*.ps1"
  - "**/run_*.py"
---
# Cascade Orchestrators — run_daily.ps1 + run_monday.ps1 (Parallel)

Two PowerShell orchestrators in `pd-goals/scripts/` drive the recurring
report cascades across all 4 worktrees from the **work laptop**:

| Script | Cadence | What it runs |
|---|---|---|
| `run_daily.ps1` | every game day | boxscore, WPA, 6 postgames (pit/if/of/c/hit/br) + mazzo + br-team |
| `run_monday.ps1` | weekly (Sun-ending) | drift×2, hit/pit analysis, org-KPI, 6 weekly KPIs, stapler, weekly-fld/goals/advance×2/weekly-hit |

**The script headers are the source of truth** for the exact phase list,
commands, and channels. This rule documents the cross-cutting patterns +
invariants an agent must preserve when editing either script — and the
reusable PowerShell-parallelism pattern for any future automation.

Pairs with `combined-kpi-stapler.md` (the stapler this gates) and
`slack-channels-sync.md` (this rule syncs byte-identical to all 4 worktrees).

---

## Execution model — worker pool with `-MaxParallel` (PARALLEL since 2026-06-03)

Both scripts run phases concurrently through a `Start-Job` worker pool
capped at `-MaxParallel N`. Each phase still streams to its **own**
per-phase log (`reports/<daily|monday>_<date>/<phase>_<name>.log`); the
console shows `[START]` / `[OK]/[FAIL]` event lines, then a summary table.

| Script | Default cap | Barriers | Notes |
|---|---|---|---|
| `run_daily.ps1` | **3** (lowered from 10 on 2026-06-05) | none — all phases independent | 3 matches Monday; 10-way fan-out on a flaky VPN was linked to a silent delivery outage (see Delivery-failure detection below) |
| `run_monday.ps1` | **3** | ONE — the stapler barrier (see below) | matches the "2-3 weekly scripts at once" habit |

`-MaxParallel 1` reproduces the pre-2026-06-03 serial behavior exactly —
the escape hatch if a run misbehaves. Drop the cap (e.g. `4`) if GCSQL02
throws TCP drops or Slack 429s under the multiplied concurrent load (each
script already fires ~10-20 internal DB connections via the
`ThreadPoolExecutor` P2/P3/P4 pattern — the pool multiplies that).

### Delivery-failure detection — two layers (BLOCKING)

A phase script can **exit 0 while its Slack sends failed**. The delivery
functions historically caught each POST exception, printed `[FAIL] ... ->`,
and returned normally — so the process exit code stayed 0 and the
orchestrator marked the phase OK. On 2026-06-05 a DNS/VPN drop mid-run made
pit-pg + br-pg deliver `0 sent, 23 failed` (getaddrinfo errors) while the
summary still printed "All steps OK." Two layers now prevent that — keep
BOTH, and keep Layer 2 byte-identical across the two scripts:

**Layer 1 — source (`src/deliver.py`, all 4 worktrees):**
`send_reports_via_logic_app` + `send_to_channel` now `sys.exit(1)` after
printing the summary when `failed > 0`. Every script that delivers through
`deliver.py` (6 postgames + boxscore + br-team) propagates a non-zero exit
on any failed send. Reports still generate fully; only the exit code
changes. Scripts with their OWN inline delivery (wpa, org-kpi, combined-kpi
stapler, drift) do NOT route through `deliver.py` — Layer 2 covers them.

**Layer 2 — orchestrator net (`Invoke-Pool` in BOTH scripts):** after a
phase reaps with exit 0, the pool scans that phase's log for
delivery-failure markers and forces `Ok=$false` + `ExitCode=90` (the
delivery-failure sentinel) on a match. This catches EVERY phase regardless
of the script's own exit-code behavior — present or future, deliver.py-based
or inline. The scan regex:

```
\[FAIL\]\s.*->|Delivery complete:\s*\d+\s*sent,\s*[1-9]\d*\s*failed|Delivery failed|Delivery error
```

Select-String is case-insensitive, so the bare `Delivery failed` /
`Delivery error` phrases cover EVERY delivery-failure print used across the
4 worktrees (enumerated 2026-06-05): `[FAIL] file -> channel` (deliver.py /
wpa / org-kpi), `Delivery complete: N sent, M failed` with M>0 (deliver.py),
`[ERROR] Delivery failed: {e}` (KPI / advance / combined-kpi / org-2b3b /
br-daily), `Delivery failed ({status})` and `Delivery error: {e}` (mazzo /
catcher-hexbin / paa-eo-direction — `requests`/urllib3 `HTTPSConnectionPool`
exceptions), `ERROR: Delivery failed:` (barrelsville advance), and `Slack
delivery failed` (drift). It does NOT match benign `Headshot load failed` /
`query failed` / `render failed` / report-gen `Failed: N` lines — none of
those put "Delivery" adjacent to "failed"/"error". The success summary
`Delivery complete: N sent, 0 failed` is also NOT matched (the `[1-9]\d*`
guard, and "Delivery complete" ≠ "Delivery failed"). **Exit 90 in the
summary table = "reports generated but a send failed"** (distinct from a
crash / non-zero script exit). Re-run only the flagged phase(s) once the
network is back.

> **Adding a new delivery code path?** Make its failure print start with
> `Delivery failed` or `Delivery error` (or use `deliver.py`), or the
> Layer-2 net won't see it. The 2026-06-05 mazzo miss was a `Delivery
> error:` marker the original regex didn't enumerate.

### Monday's two-stage split (BLOCKING invariant)

Monday has exactly ONE hard ordering constraint: **kpi → stapler** (the
stapler reads the 6 KPI PDFs off disk — see `combined-kpi-stapler.md`).
Execution is partitioned around it:

```
STAGE 1 (pool): every phase BEFORE the stapler
                (drift×2, hit/pit-analysis, org-kpi, + the 6 KPIs)
   |
   +-- BARRIER: wait for Stage 1; confirm all 6 KPIs passed
   |
STAGE 2 (pool): stapler (GATED on the 6 KPIs) + everything AFTER it
                (weekly-fld×2, goals, advance×2, weekly-hit)
```

- If **any** of the 6 KPIs fails: the stapler is dropped from Stage 2,
  a `[HALT]` line + `-Resume stapler` hint print, and a `stapler-skipped`
  result is recorded. **The post-stapler phases still run** (keep-going).
- The stapler runs concurrently with the post-stapler work in Stage 2 —
  nothing downstream depends on it.
- `-Resume stapler` → Stage 1 is empty, `kpiRan=false`, gate treats it as
  pass, stapler runs against the prior run's PDFs on disk. Correct.

Daily has no barriers — one pool over all phases.

---

## The reusable PowerShell worker-pool pattern (+ 2 BLOCKING gotchas)

Any future PowerShell automation that fans out child commands should copy
this shape. Two non-obvious bugs were found in testing — do NOT reintroduce.

```powershell
# Job body: $Command passed as a PARAMETER (not Start-Process -ArgumentList)
# so PowerShell does not re-quote embedded quotes (e.g. --csv "...").
$JobScript = {
    param($Wt, $Command, $Log, $PyEnc)
    $env:PYTHONIOENCODING = $PyEnc
    # GOTCHA 1: full path to cmd.exe. A Start-Job runspace can have a
    # minimal PATH where bare 'cmd' fails "term not recognized". ComSpec
    # is always set.
    $comspec = if ($env:ComSpec) { $env:ComSpec } else { 'C:\Windows\System32\cmd.exe' }
    Set-Location $Wt
    & $comspec /c "$Command 2>&1" | Out-File -FilePath $Log -Encoding UTF8
    $LASTEXITCODE        # emitted as the job's ONLY output object
}

# Reaping a finished job:
# GOTCHA 2: wrap in @(...) and check .Count. A SUCCESSFUL job emits the
# int 0, and `if ($out)` reads 0 as $false -> would mislabel every
# success as a failure (exit 1).
$out  = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
$code = if ($out.Count -gt 0) { $out[-1] } else { $null }
if ($null -eq $code -or $job.State -ne 'Completed') {
    $exit = if ($null -ne $code) { [int]$code } else { 1 }  # crashed -> fail
} else {
    $exit = [int]$code
}
```

The pool loop: keep `-MaxParallel` jobs running; when a slot frees, launch
the next queued step (worker pool, NOT fixed batches — a slow step doesn't
stall a free slot). See `Invoke-Pool` in either script for the canonical
loop. Results are appended as PSCustomObjects (`Name/ExitCode/Ok/Phase/
Skipped/Elapsed`); the summary sorts by `$PhaseOrder` index since the pool
finishes out of order.

---

## Delivery conventions (channel routing per phase)

| Cascade | Default-channel flag | Athlete-channel flag | Semantics |
|---|---|---|---|
| **Daily postgames** | `--deliver` (zzz coach / affiliate) | `--deliver --z-channel` | **switching** (one or the other) |
| **Monday per-player** | `--deliver` | `--deliver --deliver-z` | **additive** (both zzz + z) |

Daily and Monday use DIFFERENT athlete flags — `--z-channel` (switch) vs
`--deliver-z` (additive). Don't cross them.

**Daily pit-pg EXCEPTION (BLOCKING, user direction 2026-06-02):** pitcher
postgame delivers plain `--deliver` → **zzz COACH** channel, NOT the z
athlete channel. The other three daily postgames (hitter, catcher, br-pg)
DO use `--z-channel`. Pitching is coach-facing here.

**pit-pg auto-includes position players who pitched (Jun 2026).** The pitcher
postgame gate is the **full** org roster (not pitcher-only), so a position
player who threw a pitch (mop-up / two-way) gets a pitcher postgame → their
zzz coach channel, no flag needed. Their fully-untagged outing renders via
`coerce_unclassified_outing` (see `arm-farm.md`). Only fires for players who
*actually pitched* (driven from pitches thrown), so it never adds non-pitching
position players. Behavioral change to the pit-pg phase — don't be surprised
when a SS shows up in a pitcher postgame run.

The 6 Monday KPI scripts do NOT `--deliver` — only the stapler delivers
(one combined PDF per affiliate). See `combined-kpi-stapler.md`.

---

## Other invariants (both scripts)

- **Preflight does NOT `git pull`.** The caller runs `git pull` on every
  worktree first. There is NO `-SkipPull` flag. Auto-pulling mid-cascade
  could introduce surprise changes between phases.
- **`-DryRun`** strips every delivery flag (rehearsal — generates PDFs,
  skips the `LOGIC_APP_URL` check, posts nothing). Run it before the first
  real run after any change.
- **`-Resume <phase>`** starts at a named phase (ValidateSet must match the
  script's `$PhaseOrder`). The summary prints the exact `-Resume` line for
  any failed phase.
- **Keep-going:** a failed phase never blocks the others (the stapler gate
  is the only conditional skip, and only the stapler).
- **`-Date`:** `run_daily.ps1` defaults to **yesterday** (local time) if
  omitted; `run_monday.ps1` **requires** `-Date`. Both print the resolved
  date in the banner — eyeball it before delivery, especially if running
  just after midnight.
- **`$env:PYTHONIOENCODING = "utf-8"`** is set in preflight so child
  Python processes don't crash on em-dashes/smart-quotes under cp1252.
- **Worktree paths** are the work-laptop layout (`C:\Users\zbridger\...`)
  with intangibles dual-layout runtime-detection (nested vs flat). These
  run on the work laptop only (DB access).

---

## What NOT to do

- **Don't start the stapler before all 6 KPIs finish.** The Stage-1 barrier
  is the mechanism. If any KPI fails, the stapler MUST be skipped (it would
  staple a stale/partial set). Post-stapler phases still run.
- **Don't use bare `cmd`** in a `Start-Job` body — use `$env:ComSpec`.
- **Don't use `if ($out)`** to capture a job's exit code — use
  `@(Receive-Job).Count` (falsy-zero mislabels successes).
- **Don't pass the command via `Start-Process -ArgumentList`** — embedded
  quotes (Monday's `--csv "..."`) get re-quoted and break. Pass `$Command`
  as a job parameter and run it through `cmd /c`.
- **Don't add `git pull` to preflight** or re-add a `-SkipPull` flag.
- **Don't cross the athlete flags** — daily uses `--z-channel` (switch),
  Monday uses `--deliver-z` (additive).
- **Don't route daily pit-pg to the z athlete channel** — it's coach-facing
  (`--deliver` only).
- **Don't default daily to a huge fan-out blindly on a degraded network** —
  if a run TCP-drops, drop `-MaxParallel` to ~4. It's still much faster
  than serial.
- **Don't edit only one script** when changing the shared `$JobScript` /
  `Invoke-Pool` engine — keep both in sync (they're byte-identical).
- **Don't remove either delivery-failure layer.** Layer 1 (`sys.exit(1)` in
  `deliver.py` on `failed > 0`) and Layer 2 (the `Invoke-Pool` log-scan net →
  exit 90) are belt-and-suspenders. Removing the net re-opens the "exit 0 but
  0 sent" hole for inline-delivery scripts; removing the source exit makes
  manual single-script runs lie about their outcome.
- **Don't broaden the delivery-failure scan regex to a bare `failed`.** It
  would match benign `Headshot load failed` / `query failed` / report-gen
  `Failed: N` lines and false-FAIL healthy phases. Keep it scoped to the
  delivery markers (per-file `[FAIL] ... ->`, `Delivery complete: N sent, M
  failed` with M>0, `[ERROR] Delivery failed`, `Slack delivery failed`).

---

## Bug history

- **2026-06-02** — `run_daily.ps1` added (10-phase daily orchestrator,
  commit `99178881`). pit-pg routed to zzz coach channel, not z athlete
  (`bd73e618`).
- **2026-06-03** — both cascades parallelized via the `Start-Job` worker
  pool (`fb395242`). Two engine bugs caught in testing and fixed before
  ship: bare `cmd` not found in the job runspace (→ `$env:ComSpec`), and
  `if ($out)` reading a successful job's emitted `0` as false (→
  `@(Receive-Job).Count`). Verified: pool smoke test (cap, exit 0/3,
  keep-going, skip, logs, 4.3s vs ~8s serial) + Monday gate test (all-pass
  runs stapler; KPI-fail drops it + keeps post-work; `-Resume stapler`
  runs against prior PDFs).
- **2026-06-05** — silent delivery outage. A DNS/VPN drop mid-`run_daily`
  (MaxParallel 10) made pit-pg + br-pg deliver `0 sent, 23 failed`
  (`getaddrinfo failed` — same error hit headshot/mlbstatic loads, the tell
  that it was a network outage not a code bug), yet the summary printed
  "All steps OK" because `generate_postgame.py` discarded the delivery
  result and exited 0. Three fixes: (1) daily `MaxParallel` default 10 → 3;
  (2) Layer 1 — `deliver.py` (4 worktrees) `sys.exit(1)` on `failed > 0`;
  (3) Layer 2 — `Invoke-Pool` log-scan net forces FAIL + exit 90 on
  delivery-failure markers even when the script exits 0. See
  "Delivery-failure detection" above. Reports had generated fine; recovery
  was re-running the 5 flagged phases with `--deliver` once the network
  returned.
