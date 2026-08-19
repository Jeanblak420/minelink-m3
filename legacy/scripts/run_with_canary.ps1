Write-Host "Starting Flutter app with Chrome Canary and special flags..." -ForegroundColor Green

# Find Chrome Canary path
$canaryPath = "C:\Users\$env:USERNAME\AppData\Local\Google\Chrome SxS\Application\chrome.exe"

# Check if Canary exists
if (-not (Test-Path $canaryPath)) {
    Write-Host "Chrome Canary not found at $canaryPath" -ForegroundColor Red
    Write-Host "Please install Chrome Canary or update the path in this script." -ForegroundColor Yellow
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Set Chrome Canary as the browser for Flutter
[Environment]::SetEnvironmentVariable("CHROME_EXECUTABLE", $canaryPath, "User")
Write-Host "Set Chrome executable to Canary: $canaryPath" -ForegroundColor Cyan

# Run Flutter with special flags for Chrome Canary
flutter run -d chrome --web-port=61783 --web-hostname=localhost `
    --dart-define-from-file=config/supabase.live.json `
    --web-browser-flag="--enable-unsafe-swiftshader" `
    --web-browser-flag="--disable-web-security" `
    --web-browser-flag="--disable-features=UseOzonePlatform" `
    --web-browser-flag="--disable-gpu-driver-bug-workarounds" `
    --web-browser-flag="--ignore-gpu-blocklist"

# Reset to default Chrome
[Environment]::SetEnvironmentVariable("CHROME_EXECUTABLE", "C:\Program Files\Google\Chrome\Application\chrome.exe", "User")
Write-Host "Flutter app has been stopped. Chrome executable has been reset to the default Chrome." -ForegroundColor Green
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
