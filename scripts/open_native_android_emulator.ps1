# Native Android Emulator on Windows (real phone window, NOT browser / Docker).
# If packages are missing, opens Android Studio Device Manager to install + start.
param(
    [switch]$RunFlutter,
    [string]$AvdName = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
# sdkmanager breaks when TEMP points at broken paths; keep temp on C:
$env:TMP = 'C:\AndroidTmp'
$env:TEMP = 'C:\AndroidTmp'
New-Item -ItemType Directory -Force -Path $env:TMP | Out-Null
$sdk = $env:ANDROID_SDK_ROOT
if (-not $sdk) { $sdk = $env:ANDROID_HOME }
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\sdk' }
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_HOME = $sdk

$emu = Join-Path $sdk 'emulator\emulator.exe'
$studio = 'C:\Program Files\Android\Android Studio\bin\studio64.exe'
$adb = Join-Path $sdk 'platform-tools\adb.exe'

function Test-AvdBootable([string]$name) {
    if (-not (Test-Path $emu)) { return $false }
    $ini = Join-Path $env:USERPROFILE ".android\avd\$name.avd\config.ini"
    if (-not (Test-Path $ini)) { return $false }
    $cfg = Get-Content $ini -Raw
    if ($cfg -notmatch 'image\.sysdir\.1=(.+)') { return $false }
    $rel = $Matches[1].Trim() -replace '\\', '/'
    $imgDir = Join-Path $sdk ($rel -replace '/', [IO.Path]::DirectorySeparatorChar)
    return (Test-Path (Join-Path $imgDir 'kernel-ranchu'))
}

function Start-Avd([string]$name) {
    Write-Host "Starting native emulator window: $name"
    Start-Process -FilePath $emu -ArgumentList @('-avd', $name, '-netdelay', 'none', '-netspeed', 'full')
}

# Stop Docker browser emulator if it stole adb port 5555.
$compose = Join-Path $root 'docker\flutter\docker-compose.yml'
if ((Get-Command docker -ErrorAction SilentlyContinue) -and (Test-Path $compose)) {
    docker compose -f $compose --profile browser-android down 2>$null | Out-Null
}

if (-not (Test-Path $emu)) {
    throw "Android emulator not found. Install Android Studio and SDK Emulator package."
}

$avds = @(& $emu -list-avds 2>$null | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ })
if ($AvdName) {
    $target = $AvdName
} else {
    $preferred = @('Mineral_Guide_API35', 'Mineral_Guide_API34')
    $target = $preferred | Where-Object { $avds -contains $_ -and (Test-AvdBootable $_) } | Select-Object -First 1
    if (-not $target) {
        $target = $avds | Where-Object { Test-AvdBootable $_ } | Select-Object -First 1
    }
    if (-not $target) { $target = $avds | Select-Object -First 1 }
}

if ($target -and (Test-AvdBootable $target)) {
    Start-Avd $target
} else {
    Write-Host ""
    Write-Host "No working AVD found (system image may be incomplete)." -ForegroundColor Yellow
    Write-Host "Opening Android Studio - use Device Manager:" -ForegroundColor Yellow
    Write-Host "  1. SDK Manager -> install 'Android 14 (API 34)' + 'Google APIs Intel x86_64 System Image'"
    Write-Host "  2. Device Manager -> Create Device -> Pixel 6 -> API 34 -> Finish -> Play (triangle)"
    Write-Host "  That opens a REAL emulator window on your desktop (not a browser)."
    Write-Host ""
    if (Test-Path $studio) {
        Start-Process -FilePath $studio -ArgumentList @($root)
    } else {
        throw "Install Android Studio from https://developer.android.com/studio"
    }
    exit 0
}

if ($RunFlutter) {
    if (-not (Test-Path $adb)) { throw "adb not found: $adb" }
    Write-Host "Waiting for emulator boot..."
    & $adb wait-for-device
    $deadline = (Get-Date).AddMinutes(8)
    while ((Get-Date) -lt $deadline) {
        $boot = (& $adb shell getprop sys.boot_completed 2>$null).Trim()
        if ($boot -eq '1') { break }
        Start-Sleep -Seconds 2
    }
    Set-Location $root
    flutter run --dart-define-from-file=config/supabase.live.json
}
