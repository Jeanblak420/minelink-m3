# PowerShell script to push migrations and automatically respond to prompts
$process = Start-Process -FilePath "supabase" -ArgumentList "db", "push" -NoNewWindow -PassThru -RedirectStandardInput $true -RedirectStandardOutput $true -RedirectStandardError $true

# Wait a moment for the process to start and display the prompt
Start-Sleep -Seconds 5

# Send "Y" to the process
$process.StandardInput.WriteLine("Y")

# Wait for the process to complete
$process.WaitForExit()

# Display the output
$output = $process.StandardOutput.ReadToEnd()
$error = $process.StandardError.ReadToEnd()

Write-Host "Output:"
Write-Host $output

Write-Host "Error:"
Write-Host $error

Write-Host "Exit Code: $($process.ExitCode)"
