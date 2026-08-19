Write-Host "Starting Flutter app on port 61783 with safe settings..." -ForegroundColor Green
flutter run -d chrome --web-port=61783 --web-hostname=localhost --dart-define-from-file=config/supabase.live.json
