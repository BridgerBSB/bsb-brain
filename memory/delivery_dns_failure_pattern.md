---
name: Delivery DNS failure pattern (work laptop / VPN drops)
description: When CLI delivery shows "getaddrinfo failed" / errno 11001 mass-failures, it's DNS not code — VPN dropped or network blip. PDFs already rendered to disk; just need to reconnect and re-run.
type: reference
originSessionId: 91d5febc-c818-4065-9bfc-fc70f42f7e55
---
**Symptom:** All N reports `[FAIL]` with the same error pattern:
```
<urlopen error [Errno 11001] getaddrinfo failed>
```
Headshot fetch in the render phase typically also fails with the same error before delivery starts (it hits mlb.com for player photos via DNS too).

**Root cause:** DNS lookup failure on the work laptop. Either:
- Astros VPN dropped mid-run
- Network adapter blip
- DNS server unreachable

NOT a code bug. NOT a Logic App issue. NOT a Slack issue. Don't chase it as one.

**Diagnostic on work laptop:**
```powershell
Test-NetConnection prod-23.southcentralus.logic.azure.com -Port 443
ping prod-23.southcentralus.logic.azure.com
```
Both should resolve + succeed. If they don't, network is the problem.

**Recovery:**
1. Reconnect Astros VPN.
2. Verify DNS resolution per above.
3. Re-run the same CLI command. PDFs already on disk get overwritten — same final state.

**Annoying gap:** No CLI scripts currently have a `--deliver-from-disk` / `--redeliver-only` mode. A delivery-failure due to network forces a full re-render (re-query DB, re-plot all N reports, re-render PDFs). For weekly batch runs at 49+ players, that's 5-10 minutes wasted. Candidate small CLI improvement when it next bites:
- New flag `--deliver-from-dir <path>` that scans a directory for existing PDFs, parses gc_id from filenames (existing `parse_gc_id_from_filename` helper in `deliver.py` already does this), and runs only the Logic App delivery loop.
- Applies to: `generate_postgame.py`, `generate_weekly_hitter.py`, `generate_hitter_kpi_report.py`, `generate_pitcher_kpi_report.py`, OF/IF/BR/Catcher KPI scripts. Same helper pattern across all.

**Apps affected by the same DNS pattern:**
- Any `--deliver` CLI run (Postgame, Weekly Hitter, KPI Weekly × 6, Combined Stapler, Advance Batch).
- Slack channel CSV reads are local file IO so they don't fail; only the HTTP POSTs to the Azure Logic App URL fail.
- Posit Connect-deployed apps and Connect-scheduled jobs are NOT affected — they run from Connect's network, not the work laptop. So daily tracker pins keep refreshing fine even when work laptop's VPN is flaky.

## Work-laptop network topology (May 4 2026 observed)

`ipconfig /all` from work laptop while on VPN:

```
Adapter: PANGP Virtual Ethernet Adapter Secure (GlobalProtect / Palo Alto)
  IPv4: 172.27.1.1 (corp tunnel)
DNS Servers: 10.1.100.172 (primary)
             10.1.100.152 (secondary)
DNS Suffix Search List: astros.com
```

**Both DNS servers are internal corp resolvers.** No public DNS fallback (no
8.8.8.8 / 1.1.1.1 in the list). When 10.1.100.172 + 10.1.100.152 both hiccup,
the laptop returns NXDOMAIN for ALL names — corp AND public — until the corp
resolvers recover. That's why `Resolve-DnsName google.com` came back as
"DNS name does not exist" today even though google.com obviously exists; the
corp resolver was returning NXDOMAIN for the brief outage window.

## Full diagnostic recipe

```powershell
# 1. Confirm DNS state — google.com is the canary (it always exists; if
#    it NXDOMAINs, corp DNS is the problem, not the destination host)
Resolve-DnsName google.com
Resolve-DnsName prod-23.southcentralus.logic.azure.com
Test-NetConnection prod-23.southcentralus.logic.azure.com -Port 443

# 2. Confirm DNS servers + VPN state
ipconfig /all
# Look for: PANGP adapter present, DNS Servers = 10.1.100.172 / 10.1.100.152

# 3. Recovery
ipconfig /flushdns
# Then disconnect + reconnect VPN (right-click GlobalProtect tray icon)

# 4. Re-test
Resolve-DnsName google.com   # should return an answer this time
```

If google.com STILL NXDOMAINs after VPN reconnect: corp DNS is genuinely
down — IT problem, not laptop problem. Loop in Chris Josefy.

## Resolution speed today

- ~8:00-8:30 AM CT: DNS broken, postgame + catcher 5/3 runs failed
- ~8:30-9:00 AM CT: corp DNS recovered on its own; KPI weekly delivery
  succeeded (HTTP 202 across all 6 levels) without any explicit fix
- DNS cache flush still worth running to clear any stale negative caches
  from the broken window

## Future improvement candidate (logged earlier)

`--deliver-from-disk` flag for postgame + catcher + weekly hitter + KPI
scripts. Scans an output directory for existing PDFs, parses gc_id from
filename via existing `parse_gc_id_from_filename` helper in `deliver.py`,
runs only the Logic App delivery loop. ~30 lines per script. Saves
5-10 min of re-rendering on every DNS hiccup.

**History:**
- May 4 2026 morning — postgame 5/3 (49 reports) + catcher 5/3 (6 reports)
  failed delivery with errno 11001 mid-run. PDFs saved to disk. Diagnostic
  showed corp DNS returning NXDOMAIN for everything (even google.com).
  Resolved within ~30 min as corp DNS recovered. Re-run after recovery
  shipped them. Confirmed today's `ipconfig /all` topology + diagnostic
  recipe for next time.
