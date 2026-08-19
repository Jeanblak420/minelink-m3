Write-Host "Starting Flutter app on port 61783..." -ForegroundColor Green
# Hosted map tiles (Esri key) activate automatically once
# config/map_tiles.local.json exists — see map_tiles.local.json.example.
$mapArgs = @()
if (Test-Path "config/map_tiles.local.json") {
  $mapArgs = @("--dart-define-from-file=config/map_tiles.local.json")
  Write-Host "Using hosted map tiles from config/map_tiles.local.json" -ForegroundColor Cyan
}
flutter run -d chrome --web-port=61783 --web-hostname=localhost --dart-define-from-file=config/supabase.live.json @mapArgs
