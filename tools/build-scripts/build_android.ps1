# Builds Circuit Garden for Android on Windows.
#   .\tools\build-scripts\build_android.ps1 -Godot C:\Godot\Godot_v4.7.2-stable_win64_console.exe -Mode debug
#   .\tools\build-scripts\build_android.ps1 -Godot ... -Mode release
# Release signing comes only from environment variables (set them in the shell, never in Git):
#   $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH, $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
param([string]$Godot = "godot", [ValidateSet("debug", "release")][string]$Mode = "debug")
$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
New-Item -ItemType Directory -Force -Path "$Root\build" | Out-Null
Push-Location "$Root\games\circuit-garden"
try {
  & $Godot --headless --import | Out-Null
  if ($Mode -eq "release") {
    foreach ($v in "GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD") {
      if (-not (Get-Item "env:$v" -ErrorAction SilentlyContinue)) { throw "missing $v" }
    }
    & $Godot --headless --export-release "Android Release AAB" "$Root\build\circuit-garden-release.aab"
  } else {
    & $Godot --headless --export-debug "Android" "$Root\build\circuit-garden-debug.apk"
  }
  exit $LASTEXITCODE
} finally { Pop-Location }
