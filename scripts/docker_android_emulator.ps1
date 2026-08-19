# Docker Android emulator (noVNC + adb). See docker/flutter/docker-compose.yml (android-nvc).
param(
    [switch]$Down,
    [switch]$RunFlutter,
    [switch]$WaitBoot
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $root 'docker\flutter\docker-compose.yml'

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker not in PATH. Start Docker Desktop first.'
}

Set-Location $root

if ($Down) {
    docker compose -f $compose --profile browser-android down
    Write-Host 'Stopped android-nvc.'
    exit 0
}

Write-Host 'Starting Docker Android (API 34, Pixel 6). First pull can take several minutes...'
docker compose -f $compose --profile browser-android up -d android-nvc
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed (exit $LASTEXITCODE)" }

Write-Host ''
Write-Host 'Emulator UI:  http://localhost:6080'
Write-Host 'ADB:          adb connect 127.0.0.1:5555'
Write-Host 'Stop:         powershell -File scripts/docker_android_emulator.ps1 -Down'
Write-Host ''

$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = Join-Path $env:LOCALAPPDATA 'Android\sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'

if ($WaitBoot -or $RunFlutter) {
    if (-not (Test-Path $adb)) {
        Write-Warning "adb not found at $adb - install platform-tools or set ANDROID_HOME."
    } else {
        Write-Host 'Waiting for emulator (adb connect + boot)...'
        & $adb connect '127.0.0.1:5555' 2>&1 | Out-Null
        $deadline = (Get-Date).AddMinutes(12)
        while ((Get-Date) -lt $deadline) {
            $boot = (& $adb -s '127.0.0.1:5555' shell getprop sys.boot_completed 2>$null).Trim()
            if ($boot -eq '1') {
                Write-Host 'Android boot completed.'
                break
            }
            Start-Sleep -Seconds 3
        }
    }
}

if ($RunFlutter) {
    $cfg = Join-Path $root 'config\supabase.live.json'
    if (-not (Test-Path $cfg)) { throw "Missing $cfg" }
    flutter run -d '127.0.0.1:5555' --dart-define-from-file=config/supabase.live.json
}
