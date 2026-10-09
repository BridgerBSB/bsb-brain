# Nightly training-knowledge run. Installed by install_task.ps1 as the
# Windows scheduled task "BSB Knowledge Nightly" (04:30 local, wake to run).
#
# discover -> fetch -> promote -> (backfill 8/source if queue < 40) -> summarize -> lint -> commit+push
# Every step is idempotent against _pipeline/state.json, so a missed or
# interrupted night costs nothing. Output goes to nightly.log (gitignored).

$ErrorActionPreference = "Continue"
$env:PYTHONIOENCODING = "utf-8"
$env:PYTHONUTF8 = "1"
$root = "C:\Users\Owner\bsb-brain\_pipeline"
Set-Location $root

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Add-Content -Encoding utf8 -Path "$root\nightly.log" -Value "===== $stamp run start ====="

# Wait for the network. The laptop sleeps overnight (Modern Standby drops
# Wi-Fi), so this task usually fires the second it WAKES, before Wi-Fi is back.
# On 2026-10-09 08:35 that run failed DNS on every feed, could not push, and
# still ended "exit 0". A real TCP connect, not a DNS lookup: Windows can answer
# DNS from cache while offline. No network after 10 min -> exit 1, so the task
# shows a failure instead of a clean run that did nothing.
function Test-Net {
    param([string]$HostName = "github.com", [int]$Port = 443)
    $c = New-Object System.Net.Sockets.TcpClient
    try { return ($c.ConnectAsync($HostName, $Port).Wait(3000) -and $c.Connected) } catch { return $false } finally { $c.Dispose() }
}
$waited = 0
while (-not (Test-Net) -and $waited -lt 600) { Start-Sleep -Seconds 15; $waited += 15 }
if (-not (Test-Net)) {
    Add-Content -Encoding utf8 -Path "$root\nightly.log" -Value "===== $(Get-Date -Format 'yyyy-MM-dd HH:mm') no network after ${waited}s - run skipped (exit 1) ====="
    exit 1
}
if ($waited) { Add-Content -Encoding utf8 -Path "$root\nightly.log" -Value "network up after ${waited}s" }

# Pull first so a promote from another machine is not overwritten.
git -C "$root\.." pull -q --rebase --autostash origin master 2>&1 | Add-Content -Encoding utf8 -Path "$root\nightly.log"

& python "$root\kb.py" run 2>&1 | Add-Content -Encoding utf8 -Path "$root\nightly.log"

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Add-Content -Encoding utf8 -Path "$root\nightly.log" -Value "===== $stamp run end (exit $LASTEXITCODE) ====="
