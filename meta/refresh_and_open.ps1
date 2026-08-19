# BSB Brain Command Center - scheduled refresh.
# Regenerates the dashboard, and ONCE per calendar day opens it in the default
# browser. Any extra triggers the same day just refresh the data silently (no
# tab-spam). Driven by the "BSB Command Center" scheduled task.
py "C:\Users\Owner\bsb-brain\meta\generate_command_center.py"

$marker = Join-Path $env:TEMP ("bsb_cc_opened_" + (Get-Date -Format 'yyyyMMdd'))
if (-not (Test-Path $marker)) {
    Get-ChildItem (Join-Path $env:TEMP 'bsb_cc_opened_*') -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    New-Item -ItemType File -Path $marker -Force | Out-Null
    Start-Process "C:\Users\Owner\bsb-brain\Command-Center.html"
}
