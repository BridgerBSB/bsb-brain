# Move the 3 personal-laptop scheduled jobs to a new computer.
#
#   AFL Side Report       07:00 daily  bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1
#   BSB Knowledge Nightly 04:30 daily  bsb-brain\_pipeline\run_nightly.ps1  (Tread/Driveline KB)
#   BSB Command Center    07:00 daily + at logon  bsb-brain\meta\refresh_and_open.ps1
#
# OLD computer:  .\migrate_scheduled_tasks.ps1 -Disable   (stops them; does not delete)
# NEW computer:  .\migrate_scheduled_tasks.ps1 -Check     (lists what is missing)
#                .\migrate_scheduled_tasks.ps1 -Install   (registers all 3)
# Once the new one has run cleanly for a day:
# OLD computer:  .\migrate_scheduled_tasks.ps1 -Remove
#
# Never leave both computers enabled: AFL would double-send to Slack and the
# nightly KB run would race the other machine's git push.

param([switch]$Install, [switch]$Check, [switch]$Disable, [switch]$Remove)

$names = "AFL Side Report", "BSB Knowledge Nightly", "BSB Command Center"
$u     = $env:USERPROFILE
$ps    = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

if ($Disable) { $names | ForEach-Object { Disable-ScheduledTask -TaskName $_ | Select-Object TaskName, State }; exit }
if ($Remove)  { $names | ForEach-Object { Unregister-ScheduledTask -TaskName $_ -Confirm:$false; "removed $_" }; exit }

# --- prerequisites (the scripts hardcode these paths) ---
$need = [ordered]@{
    "bullpen worktree"                 = "$u\bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1"
    "bsb-brain vault"                  = "$u\bsb-brain\_pipeline\run_nightly.ps1"
    "Python 3.12 (AFL script path)"    = "$u\AppData\Local\Programs\Python\Python312\python.exe"
    "AFL Slack URL (copy from old)"    = "$u\.afl_side\logic_app_url.txt"
    "AFL sent-state (copy from old)"   = "$u\.afl_side\sent.json"
    "Google Drive G: AFL shortcut"     = "G:\.shortcut-targets-by-id\1ZKYUUR1Uvg3f2bUGCOGQ_Bq18i3FhWEx"
}
$missing = 0
foreach ($k in $need.Keys) {
    $ok = Test-Path $need[$k]; if (-not $ok) { $missing++ }
    "{0,-4} {1,-32} {2}" -f ($(if ($ok) { "ok" } else { "MISS" })), $k, $need[$k]
}
foreach ($cmd in "py", "python", "git", "claude", "yt-dlp") {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue; if (-not $c) { $missing++ }
    "{0,-4} {1,-32} {2}" -f ($(if ($c) { "ok" } else { "MISS" })), "on PATH: $cmd", $c.Source
}
"$missing missing"
if ($Check -or -not $Install) { exit }
if ($missing) { "Fix the MISS lines first (or re-run with them fixed)."; exit 1 }

# --- register ---
function Reg($name, $file, $wd, $triggers, $settings) {
    $a = New-ScheduledTaskAction -Execute $ps -WorkingDirectory $wd `
         -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`""
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $name -Confirm:$false }
    Register-ScheduledTask -TaskName $name -Action $a -Trigger $triggers -Settings $settings | Out-Null
    "registered $name"
}
$base = @{ StartWhenAvailable = $true; AllowStartIfOnBatteries = $true; DontStopIfGoingOnBatteries = $true; MultipleInstances = "IgnoreNew" }

Reg "AFL Side Report" "$u\bsb-wt-bullpen\bullpen-report\scripts\run_afl_side_local.ps1" "$u\bsb-wt-bullpen\bullpen-report" `
    (New-ScheduledTaskTrigger -Daily -At 7:00am) (New-ScheduledTaskSettingsSet @base -ExecutionTimeLimit (New-TimeSpan -Hours 1))

Reg "BSB Knowledge Nightly" "$u\bsb-brain\_pipeline\run_nightly.ps1" "$u\bsb-brain\_pipeline" `
    (New-ScheduledTaskTrigger -Daily -At 4:30am) (New-ScheduledTaskSettingsSet @base -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 3))

Reg "BSB Command Center" "$u\bsb-brain\meta\refresh_and_open.ps1" "$u\bsb-brain\meta" `
    @((New-ScheduledTaskTrigger -Daily -At 7:00am), (New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME)) `
    (New-ScheduledTaskSettingsSet @base -ExecutionTimeLimit (New-TimeSpan -Minutes 15))

Get-ScheduledTask -TaskName $names | Get-ScheduledTaskInfo | Select-Object TaskName, NextRunTime
