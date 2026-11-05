<#
  OurNest release build (audit F42).

  Rebuilds everything the download site (landing/) serves, the same way every
  time, instead of copying build outputs by hand:
    landing/app/                     web / PWA app       (base href /app/)
    landing/OurNest-Windows-Desktop.zip  desktop copy    (base href /)
    landing/ournest.apk              Android APK (needs android/key.properties)

  It stops at the first failing step. Run from the project root:
    powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
  Optional build config (Supabase / Firebase values, see env/*.example.json):
    ... -File scripts/build_release.ps1 -DefineFile env/production.json
  Skip the APK (e.g. no signing key on this PC):
    ... -File scripts/build_release.ps1 -SkipApk

  Only run this AFTER the database migrations for this version are applied,
  because the new app expects them.
#>
param(
  [string]$DefineFile = "",
  [switch]$SkipApk
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

function Step($name, [scriptblock]$block) {
  Write-Host "`n=== $name ===" -ForegroundColor Cyan
  & $block
  if ($LASTEXITCODE -ne 0) { throw "Step failed: $name (exit $LASTEXITCODE)" }
}

$defines = @()
if ($DefineFile -ne "") {
  if (-not (Test-Path $DefineFile)) { throw "Define file not found: $DefineFile" }
  $defines = @("--dart-define-from-file=$DefineFile")
}

Step "Checks: analyze" { flutter analyze }
Step "Checks: tests"   { flutter test }

# 1. Web app served by the site at /app/
Step "Web app (/app/)" { flutter build web --release --base-href /app/ @defines }
if (Test-Path landing/app) { Remove-Item landing/app -Recurse -Force }
Copy-Item build/web landing/app -Recurse

# 2. Windows desktop zip (served from the PC itself at /)
Step "Web app for desktop zip (/)" { flutter build web --release --base-href / @defines }
$zipStage = Join-Path $env:TEMP "ournest-desktop-zip"
if (Test-Path $zipStage) { Remove-Item $zipStage -Recurse -Force }
Copy-Item build/web $zipStage -Recurse
Copy-Item landing/Start-OurNest-Desktop.bat $zipStage
if (Test-Path landing/OurNest-Windows-Desktop.zip) { Remove-Item landing/OurNest-Windows-Desktop.zip -Force }
Compress-Archive -Path (Join-Path $zipStage "*") -DestinationPath landing/OurNest-Windows-Desktop.zip
Remove-Item $zipStage -Recurse -Force

# 3. Android APK (release-signed; fails clearly without android/key.properties)
if (-not $SkipApk) {
  Step "Android APK" { flutter build apk --release @defines }
  Copy-Item build/app/outputs/flutter-apk/app-release.apk landing/ournest.apk -Force
}

# Sanity: never ship a bundled .env again (F28)
$leaked = Get-ChildItem landing -Recurse -Force -Filter ".env" -ErrorAction SilentlyContinue
if ($leaked) { throw "A .env file ended up in landing/: $($leaked.FullName -join ', ')" }

Write-Host "`nDone. Review landing/ and deploy it to Netlify." -ForegroundColor Green
