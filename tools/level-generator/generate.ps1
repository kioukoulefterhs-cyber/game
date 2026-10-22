# Regenerates the Circuit Garden campaign pack and validates it (Windows PowerShell).
# Usage: .\tools\level-generator\generate.ps1 -Godot "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
param([string]$Godot = "godot")
$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
$Game = Join-Path $Root "games\circuit-garden"
& $Godot --headless --path $Game -s res://tools/generate_levels.gd -- `
  (Join-Path $Game "puzzles\curriculum.json") (Join-Path $Game "puzzles\levels_v1.json")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python (Join-Path $Root "tools\level-validator\validate.py") (Join-Path $Game "puzzles\levels_v1.json") --expect 100
exit $LASTEXITCODE
