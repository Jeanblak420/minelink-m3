# Repairs missing/corrupt Flutter Windows engine artifacts (fixes MSB8066 / flutter_assemble
# when unpack_windows fails with "Unsupported file type notFound" for flutter_export.h).
# Run from any directory; requires `flutter` on PATH.

$ErrorActionPreference = "Stop"
$flutterBat = (Get-Command flutter -ErrorAction Stop).Source
$flutterRoot = Split-Path (Split-Path $flutterBat)
$engineDir = Join-Path $flutterRoot "bin\cache\artifacts\engine"

if (-not (Test-Path $engineDir)) {
    Write-Error "Engine cache not found: $engineDir"
}

$targets = @("windows-x64-release", "windows-x64-profile", "windows-x64-debug")
foreach ($t in $targets) {
    $p = Join-Path $engineDir $t
    if (-not (Test-Path $p)) { continue }
    $header = Join-Path $p "flutter_export.h"
    $items = @(Get-ChildItem $p -Force -ErrorAction SilentlyContinue)
    if ($items.Count -eq 0 -or -not (Test-Path $header)) {
        Write-Host "Removing incomplete engine folder: $p"
        Remove-Item -Recurse -Force $p
    }
}

Write-Host "Downloading Windows engine artifacts..."
& flutter precache --windows
Write-Host "Done. Run: flutter run -d windows"
