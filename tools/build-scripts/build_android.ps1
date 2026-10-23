# Builds Circuit Garden for Android on Windows.
#   .\tools\build-scripts\build_android.ps1 -Godot C:\Godot\Godot_v4.7.2-stable_win64_console.exe -Mode debug
#   .\tools\build-scripts\build_android.ps1 -Godot ... -Mode release
# Release signing comes only from environment variables (set them in the shell, never in Git):
#   $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH, $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD   (create the keystore with new_upload_keystore.ps1)
# Release builds need JDK 17 and the Android SDK (ANDROID_HOME or Godot editor settings);
# the Gradle build template is installed into games/circuit-garden/android/build (ignored by Git).
param([string]$Godot = "godot", [ValidateSet("debug", "release")][string]$Mode = "debug")
$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\..\.."
New-Item -ItemType Directory -Force -Path "$Root\build" | Out-Null
Push-Location "$Root\games\circuit-garden"
try {
  # The first import after a clean checkout can exit non-zero while classes register; run twice.
  & $Godot --headless --import | Out-Null
  & $Godot --headless --import | Out-Null
  if ($Mode -eq "release") {
    foreach ($v in "GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD") {
      if (-not (Get-Item "env:$v" -ErrorAction SilentlyContinue)) { throw "missing $v" }
    }
    $ks = (Resolve-Path $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH).Path
    if ($ks.StartsWith($Root.Path, [System.StringComparison]::OrdinalIgnoreCase)) { throw "keystore must live outside the repository" }
    if (-not (Test-Path "android\build\build.gradle")) {
      # `--install-android-build-template` hangs when run on its own in 4.7.2 headless, so do what
      # the editor does: unpack the export templates' android_source.zip and record its version.
      $Source = "$env:APPDATA\Godot\export_templates\4.7.2.stable\android_source.zip"
      if (-not (Test-Path $Source)) { throw "missing $Source (install the Godot 4.7.2 export templates)" }
      Expand-Archive $Source "android\build" -Force
      [System.IO.File]::WriteAllText("$PWD\android\.build_version", "4.7.2.stable")
      New-Item -ItemType File -Force "android\build\.gdignore" | Out-Null
    }
    $Out = "$Root\build\circuit-garden-release.aab"
    & $Godot --headless --export-release "Android Release AAB" $Out
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Out)) { throw "release export failed" }
    $Jarsigner = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\jarsigner.exe" } else { "jarsigner" }
    & $Jarsigner -verify $Out
    if ($LASTEXITCODE -ne 0) { throw "AAB signature does not verify" }
    Write-Host "Signed AAB: $Out ($([math]::Round((Get-Item $Out).Length / 1MB, 1)) MB)"
    (Get-FileHash $Out -Algorithm SHA256).Hash
  } else {
    & $Godot --headless --export-debug "Android" "$Root\build\circuit-garden-debug.apk"
  }
  exit $LASTEXITCODE
} finally { Pop-Location }
