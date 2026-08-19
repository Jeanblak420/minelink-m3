Write-Host "Opening the database error fix page..." -ForegroundColor Green
Start-Process "fix_database_errors.html"
Write-Host ""
Write-Host "Please follow the instructions in the browser window to fix the database errors." -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
