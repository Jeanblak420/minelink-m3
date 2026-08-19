@echo off
echo Starting Flutter app with Chrome Canary and special flags (with fixes)...

REM Find Chrome Canary path
set CANARY_PATH="C:\Users\%USERNAME%\AppData\Local\Google\Chrome SxS\Application\chrome.exe"

REM Check if Canary exists
if not exist %CANARY_PATH% (
  echo Chrome Canary not found at %CANARY_PATH%
  echo Please install Chrome Canary or update the path in this script.
  pause
  exit /b 1
)

REM Set Chrome Canary as the browser for Flutter
setx CHROME_EXECUTABLE %CANARY_PATH%

REM Run Flutter with special flags for Chrome Canary
echo Running with the following fixes:
echo - Fixed debug_loader.js to handle document.body not being ready
echo - Added safe early logging mechanism
echo - Improved WebGL configuration for Chrome Canary
echo - Added error handling for script loading
echo.
echo Starting Flutter...

flutter run -d chrome --web-port=61783 --web-hostname=localhost ^
  --dart-define-from-file=config\supabase.live.json ^
  --web-browser-flag="--enable-unsafe-swiftshader" ^
  --web-browser-flag="--disable-web-security" ^
  --web-browser-flag="--disable-features=UseOzonePlatform" ^
  --web-browser-flag="--disable-gpu-driver-bug-workarounds" ^
  --web-browser-flag="--ignore-gpu-blocklist" ^
  --web-browser-flag="--no-sandbox"

REM Reset to default Chrome
setx CHROME_EXECUTABLE "C:\Program Files\Google\Chrome\Application\chrome.exe"

echo Flutter app has been stopped. Chrome executable has been reset to the default Chrome.
pause
