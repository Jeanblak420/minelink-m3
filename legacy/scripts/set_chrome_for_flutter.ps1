# Set Flutter configuration for Chrome
[Environment]::SetEnvironmentVariable("CHROME_EXECUTABLE", "C:\Program Files\Google\Chrome\Application\chrome.exe", "User")
[Environment]::SetEnvironmentVariable("FLUTTER_WEB_CONTINUE_AFTER_BROWSER_CLOSE", "true", "User")

Write-Host "Chrome executable for Flutter has been set to 'C:\Program Files\Google\Chrome\Application\chrome.exe'"
Write-Host "Flutter will continue running the server after the browser is closed."
Write-Host "These settings will be used for all future Flutter runs that use Chrome."
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
 