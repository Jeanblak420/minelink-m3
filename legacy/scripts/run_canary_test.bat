@echo off
echo Running minimal test app with Chrome Canary...

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

REM Run the minimal test app
flutter run -d chrome --web-port=61783 --web-hostname=localhost --target=lib/canary_test_app.dart --web-browser-flag="--enable-unsafe-swiftshader" --web-browser-flag="--disable-web-security" --web-browser-flag="--disable-features=UseOzonePlatform" --web-browser-flag="--disable-gpu-driver-bug-workarounds" --web-browser-flag="--ignore-gpu-blocklist"

REM Reset to default Chrome
setx CHROME_EXECUTABLE "C:\Program Files\Google\Chrome\Application\chrome.exe"

echo Test app has been stopped. Chrome executable has been reset to the default Chrome.
pause
