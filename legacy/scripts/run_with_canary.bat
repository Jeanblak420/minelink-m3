@echo off
echo Starting Flutter app with Chrome Canary and special flags...

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
flutter run -d chrome --web-port=61783 --web-hostname=localhost --dart-define-from-file=config\supabase.live.json --web-browser-flag="--enable-unsafe-swiftshader" --web-browser-flag="--disable-web-security" --web-browser-flag="--disable-features=UseOzonePlatform" --web-browser-flag="--disable-gpu-driver-bug-workarounds" --web-browser-flag="--ignore-gpu-blocklist"

REM Reset to default Chrome
setx CHROME_EXECUTABLE "C:\Program Files\Google\Chrome\Application\chrome.exe"

echo Flutter app has been stopped. Chrome executable has been reset to the default Chrome.
pause
