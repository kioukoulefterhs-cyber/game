# Creates the Play upload keystore OUTSIDE the repository (Windows PowerShell).
#   .\tools\build-scripts\new_upload_keystore.ps1
# Default location: %USERPROFILE%\.circuit-garden-keys\upload.jks (never inside Git).
# The password is typed by you and never written to disk by this script.
# Use Play App Signing: Google keeps the app signing key, this is only the upload key.
# BACK UP the .jks file and the password somewhere safe (password manager + offline copy).
param([string]$Path = "$env:USERPROFILE\.circuit-garden-keys\upload.jks", [string]$Alias = "upload")
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path "$PSScriptRoot\..\..").Path
$Full = [System.IO.Path]::GetFullPath($Path)
if ($Full.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Refusing to create a keystore inside the repository: $Full" }
if (Test-Path $Full) { throw "Keystore already exists: $Full (not overwriting)" }
$Keytool = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\keytool.exe" } else { "keytool" }
New-Item -ItemType Directory -Force -Path (Split-Path $Full) | Out-Null
$Secure = Read-Host "New keystore password (min 6 chars)" -AsSecureString
$Plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure))
try {
  & $Keytool -genkeypair -v -keystore $Full -alias $Alias -keyalg RSA -keysize 4096 -validity 10000 `
    -storepass $Plain -keypass $Plain -dname "CN=Circuit Garden, O=Circuit Garden"
  if ($LASTEXITCODE -ne 0) { throw "keytool failed" }
  & $Keytool -list -v -keystore $Full -alias $Alias -storepass $Plain | Select-String "SHA256:"
} finally { $Plain = $null }
Write-Host ""
Write-Host "Created $Full"
Write-Host "Before a release build, set in the SAME PowerShell window (not saved anywhere):"
Write-Host "  `$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = '$Full'"
Write-Host "  `$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = '$Alias'"
Write-Host "  `$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = Read-Host 'keystore password'"
Write-Host "Back up the keystore file and password now. If the upload key is lost, Play support can reset it, but it takes days."
