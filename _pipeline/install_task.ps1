# Register (or replace) the nightly scheduled task. Run once from PowerShell:
#   & C:\Users\Owner\bsb-brain\_pipeline\install_task.ps1
# Check:   Get-ScheduledTask -TaskName "BSB Knowledge Nightly" | Get-ScheduledTaskInfo
# Run now: Start-ScheduledTask -TaskName "BSB Knowledge Nightly"
# Remove:  Unregister-ScheduledTask -TaskName "BSB Knowledge Nightly" -Confirm:$false

$name = "BSB Knowledge Nightly"
$script = "C:\Users\Owner\bsb-brain\_pipeline\run_nightly.ps1"

$action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -Daily -At 4:30am
$settings = New-ScheduledTaskSettingsSet -WakeToRun -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $name -Confirm:$false
}
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings `
    -Description "bsb-brain training-knowledge pipeline: discover, fetch, summarize, promote, lint, push" | Out-Null

Get-ScheduledTask -TaskName $name | Select-Object TaskName, State
(Get-ScheduledTask -TaskName $name).Triggers | Select-Object StartBoundary, DaysInterval
