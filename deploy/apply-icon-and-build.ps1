<#
  Regenerates every launcher-icon density from assets/icon/manofit_icon.png,
  then builds the release APK.

  Put the icon PNG (square, >= 1024x1024) at:
      SIH-2026\assets\icon\manofit_icon.png
  then run:
      cd SIH-2026\deploy
      .\apply-icon-and-build.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$icon = Join-Path $root 'assets\icon\manofit_icon.png'
if (-not (Test-Path $icon)) {
  throw "Missing $icon — drop the square icon PNG there first."
}

$flutter = 'C:\Users\asus\flutter\bin\flutter'
$env:GRADLE_USER_HOME = 'D:\android-dev\gradle'

Write-Host "Generating launcher icons..." -ForegroundColor Cyan
& $flutter pub get
& $flutter pub run flutter_launcher_icons

Write-Host "Building release APK..." -ForegroundColor Cyan
& $flutter build apk --release

$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
  $mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
  Write-Host "`nAPK ready: $apk  ($mb MB)" -ForegroundColor Green
  Write-Host "Install:  adb install -r `"$apk`"" -ForegroundColor DarkGray
} else {
  throw "Build finished but APK not found at $apk"
}
