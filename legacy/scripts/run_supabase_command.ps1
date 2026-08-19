# PowerShell script to run Supabase CLI commands
param (
    [Parameter(Mandatory=$true)]
    [string]$Command
)

# Set the working directory to the project root
Set-Location -Path "C:\Users\Somebody Someone\Desktop\Bryson Mansoor\TryMinGuideLikeBoltsays"

# Run the Supabase command
Write-Host "Running command: supabase $Command"
& supabase $Command

# Display completion message
Write-Host "Command completed."
