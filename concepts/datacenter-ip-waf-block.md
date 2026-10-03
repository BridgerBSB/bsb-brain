---
type: concept
domain: infra-scraping
source: IndyBall Tracker session 2026-06-19
created: '2026-06-19'
---
# Datacenter-IP WAF block (Connect can't scrape some external sites)

**The trap:** Posit Connect runs on an Azure datacenter IP. Many public sites sit
behind a WAF/CDN that **blocks datacenter IP ranges** — they return **405 / 403** to
Connect but **200** to a residential IP (a laptop). So a scraper that works locally
can silently fail the *same code* once scheduled on Connect.

**Live case:** PrestoSports (`pioneerleague.com`) 405s Connect's IP; the iScore JSON
API does not. Verified ladder: raw fetch from Connect → 405; **not** on the MLB Stats
API (sportId 23 lists all 4 indy leagues but only Mexican League had 2026 splits);
free proxies (jina, allorigins) are themselves datacenters → also blocked. The only
reliable non-datacenter IP available = the work laptop.

**Why bsb-resources pins don't hit this:** they read the **internal** GC2 DB, which
Connect reaches fine. This bites only **external** sites with a datacenter-IP WAF.

**The fix pattern:** scrape the blocked source from a residential machine, write a
pin; let the Connect app/job READ the pin. For partial sources, split: Connect
refreshes what it can reach, the laptop refreshes the blocked one, and both
[[merge-union-not-primary|merge into the same pin]] coordinated by a freshness map.
Diagnose before assuming code is broken: 405/403 on Connect + 200 locally = this.

## Connected
Project: [[indyball-tracker]] · Pattern: [[merge-union-not-primary]] · Deploy: [[tracker-pin-connect-deploy]] · Fetch ladder: [[external-resource-capture]]
Map: [[MOC-astros-engineering]]
