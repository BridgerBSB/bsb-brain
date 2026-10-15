# BSB Brain Command Center - scheduled refresh.
# Regenerates the dashboard, and ONCE per calendar day opens it in the default
# browser. Any extra triggers the same day just refresh the data silently (no
# tab-spam). NO LONGER the scheduled action (Oct 15 2026): the task now runs
# pyw.exe generate_command_center_v2.py --open-once-daily, which does both steps
# without a console window. Kept for running by hand.
py "C:\Users\Owner\bsb-brain\meta\generate_command_center_v2.py"

$marker = Join-Path $env:TEMP ("bsb_cc_opened_" + (Get-Date -Format 'yyyyMMdd'))
if (-not (Test-Path $marker)) {
    Get-ChildItem (Join-Path $env:TEMP 'bsb_cc_opened_*') -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    New-Item -ItemType File -Path $marker -Force | Out-Null
    Start-Process "C:\Users\Owner\bsb-brain\Command-Center.html"
}
