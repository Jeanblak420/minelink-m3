Write-Host "Opening the run_sql function fix page..." -ForegroundColor Green
Start-Process "run_sql_function.html"
Write-Host ""
Write-Host "Please follow the instructions in the browser window to fix the run_sql function." -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
