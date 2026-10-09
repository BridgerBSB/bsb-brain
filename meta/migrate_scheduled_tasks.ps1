# Move the 3 personal-laptop scheduled jobs to a new computer.
#
#   AFL Side Report       07:00 -07:00 daily (= 9:00 CT)  bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1
#   BSB Knowledge Nightly 04:30 -07:00 daily (= 6:30 CT)  bsb-brain\_pipeline\run_nightly.ps1  (Tread/Driveline KB)
#   BSB Command Center    07:00 -07:00 daily (= 9:00 CT) + at logon  bsb-brain\meta\refresh_and_open.ps1
#
# OLD computer:  .\migrate_scheduled_tasks.ps1 -Disable   (stops them; does not delete)
# NEW computer:  .\migrate_scheduled_tasks.ps1 -Check     (lists what is missing)
#                .\migrate_scheduled_tasks.ps1 -Install   (registers all 3)
# Once the new one has run cleanly for a day:
# OLD computer:  .\migrate_scheduled_tasks.ps1 -Remove
#
# Never leave both computers enabled: AFL would double-send to Slack and the
# nightly KB run would race the other machine's git push.
#
# The triggers copy the old tasks' StartBoundary VERBATIM, offset included
# (exported from the Surface 2026-10-09). A StartBoundary with an offset is
# "synchronize across time zones": it fires at that absolute instant whatever
# zone this machine is set to. The Surface sat on -07:00; the new laptop is on
# Central. `New-ScheduledTaskTrigger -At 7:00am` alone would have moved AFL to
# 7:00 CT, two hours earlier than it has ever run.

param([switch]$Install, [switch]$Check, [switch]$Disable, [switch]$Remove)

$names = "AFL Side Report", "BSB Knowledge Nightly", "BSB Command Center"
$u     = $env:USERPROFILE
$ps    = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$py312 = "$u\AppData\Local\Programs\Python\Python312\python.exe"

if ($Disable) { $names | ForEach-Object { Disable-ScheduledTask -TaskName $_ | Select-Object TaskName, State }; exit }
if ($Remove)  { $names | ForEach-Object { Unregister-ScheduledTask -TaskName $_ -Confirm:$false; "removed $_" }; exit }

# --- prerequisites (the scripts hardcode these paths), tagged by the task(s) they gate ---
# A = AFL Side Report, K = BSB Knowledge Nightly, C = BSB Command Center.
# -Install registers each task only when ITS lines are ok. AFL is the one that
# must never run early: started without the old sent.json it reads an empty
# state and re-sends every session in the Drive folder to Slack.
$blocked = @{}
function Line($ok, $label, $detail, $tasks) {
    if (-not $ok) { foreach ($t in $tasks.ToCharArray()) { $script:blocked["$t"] = $true } }
    "{0,-4} {1,-32} {2,-4} {3}" -f ($(if ($ok) { "ok" } else { "MISS" })), $label, "[$tasks]", $detail
}
$need = @(
    @("bullpen worktree",               "$u\bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1", "A"),
    @("bsb-brain vault",                "$u\bsb-brain\_pipeline\run_nightly.ps1",                          "KC"),
    @("Command Center script",          "$u\bsb-brain\meta\refresh_and_open.ps1",                          "C"),
    @("Python 3.12 (hardcoded path)",   $py312,                                                            "AKC"),
    @("AFL Slack URL (copy from old)",  "$u\.afl_side\logic_app_url.txt",                                  "A"),
    @("AFL sent-state (copy from old)", "$u\.afl_side\sent.json",                                          "A"),
    @("Google Drive G: AFL shortcut",   "G:\.shortcut-targets-by-id\1ZKYUUR1Uvg3f2bUGCOGQ_Bq18i3FhWEx",    "A")
)
foreach ($n in $need) { Line (Test-Path $n[1]) $n[0] $n[1] $n[2] }
foreach ($c in @(@("py", "C"), @("python", "K"), @("git", "KC"), @("claude", "K"), @("yt-dlp", "K"), @("node", "K"))) {
    $g = Get-Command $c[0] -ErrorAction SilentlyContinue
    Line ([bool]$g) "on PATH: $($c[0])" $g.Source $c[1]
}
# The paths above can all exist while a job still dies on an ImportError, which
# lands in a log nobody reads. Surface versions (2026-10-09): numpy 1.26.4,
# pandas 2.3.3, matplotlib 3.11.0, reportlab 4.0.4, plottable 0.1.5, pins 0.9.1,
# faster-whisper 1.2.1, imageio-ffmpeg 0.6.0, trafilatura 2.2.0,
# youtube-transcript-api 1.2.4, python-frontmatter 1.3.0, yt-dlp 2026.8.19.
$importCheck = @'
import importlib, sys
bad = []
for m in sys.argv[1:]:
    try:
        importlib.import_module(m)
    except Exception as e:
        bad.append(f"{m}({type(e).__name__})")
print(" ".join(bad) if bad else "OK")
'@
$pkgs = @(
    @("AFL Python packages", "A", @("pandas", "numpy", "matplotlib", "PIL", "scipy", "pins", "plotly", "sqlalchemy", "requests")),
    @("KB Python packages",  "K", @("yaml", "requests", "trafilatura", "youtube_transcript_api", "faster_whisper", "imageio_ffmpeg", "frontmatter"))
)
foreach ($k in $pkgs) {
    $r = if (Test-Path $py312) { ($importCheck | & $py312 - @($k[2]) 2>$null | Select-Object -Last 1) } else { "no Python 3.12" }
    $ok = ("$r".Trim() -eq "OK")
    Line $ok $k[0] $(if ($ok) { "$($k[2].Count) modules import" } else { "failed: $r" }) $k[1]
}
$ready = @{ A = -not $blocked["A"]; K = -not $blocked["K"]; C = -not $blocked["C"] }
"ready: AFL=$($ready.A)  KB=$($ready.K)  CommandCenter=$($ready.C)"
if ($Check -or -not $Install) { exit }

# --- register (mirrors the Surface's exported XML, 2026-10-09) ---
function Reg($name, $file, $wd, $triggers, $settings, $desc) {
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`""
    $a = if ($wd) { New-ScheduledTaskAction -Execute $ps -WorkingDirectory $wd -Argument $arg }
         else     { New-ScheduledTaskAction -Execute $ps -Argument $arg }
    $old = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    # Re-running -Install (e.g. to add AFL later) must not cut off a live run.
    if ($old -and $old.State -eq "Running") { "KEPT $name (running now; re-run -Install after it finishes to refresh it)"; return }
    if ($old) { Unregister-ScheduledTask -TaskName $name -Confirm:$false }
    $p = @{ TaskName = $name; Action = $a; Trigger = $triggers; Settings = $settings }
    if ($desc) { $p.Description = $desc }
    Register-ScheduledTask @p | Out-Null
    "registered $name"
}
function Daily($startBoundary) {
    $t = New-ScheduledTaskTrigger -Daily -At ([datetime]::Parse($startBoundary))
    $t.StartBoundary = $startBoundary          # keep the original offset verbatim
    $t
}
$base = @{ StartWhenAvailable = $true; AllowStartIfOnBatteries = $true; DontStopIfGoingOnBatteries = $true; MultipleInstances = "IgnoreNew" }

if ($ready.A) {
$afl = Daily "2026-10-06T07:00:00-07:00"
$afl.EndBoundary = "2026-12-01T00:00:00"      # AFL season: last run Nov 30
Reg "AFL Side Report" "$u\bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1" "$u\bsb-wt-bullpen\bullpen-report" `
    $afl (New-ScheduledTaskSettingsSet @base -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30)) `
    "AFL Side Report: new AFL TrackMan sessions from the shared Drive folder to each pitcher's z_ channel. Ends Nov 30 2026."
} else { "SKIPPED AFL Side Report: fix its [A] MISS lines, then run -Install again" }

if ($ready.K) {
Reg "BSB Knowledge Nightly" "$u\bsb-brain\_pipeline\run_nightly.ps1" $null `
    (Daily "2026-09-05T04:30:00-07:00") (New-ScheduledTaskSettingsSet @base -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 3)) $null
} else { "SKIPPED BSB Knowledge Nightly: fix its [K] MISS lines" }

if ($ready.C) {
Reg "BSB Command Center" "$u\bsb-brain\meta\refresh_and_open.ps1" $null `
    @((Daily "2026-07-18T07:00:00-07:00"), (New-ScheduledTaskTrigger -AtLogOn -User "$env:COMPUTERNAME\$env:USERNAME")) `
    (New-ScheduledTaskSettingsSet @base -ExecutionTimeLimit (New-TimeSpan -Minutes 5)) $null
} else { "SKIPPED BSB Command Center: fix its [C] MISS lines" }

Get-ScheduledTask -TaskName $names -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo | Select-Object TaskName, NextRunTime
