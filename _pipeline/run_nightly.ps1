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
Add-Content -Path "$root\nightly.log" -Value "===== $stamp run start ====="

# Pull first so a promote from another machine is not overwritten.
git -C "$root\.." pull -q --rebase origin master 2>&1 | Add-Content -Path "$root\nightly.log"

& python "$root\kb.py" run 2>&1 | Add-Content -Path "$root\nightly.log"

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
Add-Content -Path "$root\nightly.log" -Value "===== $stamp run end (exit $LASTEXITCODE) ====="
