# Rebuilds the Circuit Garden campaign pack (measured difficulty curve) and validates it (Windows PowerShell).
# Usage: .\tools\level-generator\generate.ps1 -Godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
$Pack = Join-Path $Root "games\circuit-garden\puzzles\levels_v1.json"
python (Join-Path $Root "tools\level-generator\build_campaign.py") --godot $Godot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $Root "tools\level-validator\validate.py") $Pack --expect 100
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $Root "tools\level-analyzer\analyze.py") $Pack --csv (Join-Path $Root "docs\difficulty\levels.csv") | Out-Null
exit $LASTEXITCODE
