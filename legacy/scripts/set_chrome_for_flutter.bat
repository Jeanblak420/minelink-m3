@echo off
setx CHROME_EXECUTABLE "C:\Program Files\Google\Chrome\Application\chrome.exe"
setx FLUTTER_WEB_CONTINUE_AFTER_BROWSER_CLOSE "true"
echo Chrome executable for Flutter has been set to "C:\Program Files\Google\Chrome\Application\chrome.exe"
echo Flutter will continue running the server after the browser is closed.
echo These settings will be used for all future Flutter runs that use Chrome.
pause
