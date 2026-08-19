# Build Android release APK using docker/flutter/docker-compose.yml (Linux toolchain inside container).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compose = Join-Path $root 'docker\flutter\docker-compose.yml'
if (-not (Test-Path $compose)) { throw "Missing $compose" }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw "Docker not in PATH. Run scripts/install_docker.ps1 or install Docker Desktop." }
Set-Location $root
docker compose -f $compose run --rm flutter-apk
Write-Host "Done. APK: $root\build\app\outputs\flutter-apk\app-release.apk"
