@echo off
REM BSB Brain Command Center - refresh + open. Double-click me any time.
REM v2 (Oct 15 2026): World / Command / Library. The scheduled task also refreshes it every 15 min.
py "C:\Users\Owner\bsb-brain\meta\generate_command_center_v2.py"
start "" "C:\Users\Owner\bsb-brain\Command-Center.html"
