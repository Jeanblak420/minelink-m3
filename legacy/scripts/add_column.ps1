# PowerShell script to add is_active column to fleet_vehicles table

# Supabase project details
$projectRef = "kkcseqmpgzzrogatdoqi"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrY3NlcW1wZ3p6cm9nYXRkb3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzODM4ODcsImV4cCI6MjA2MTk1OTg4N30.G126pc4J8Xi4S5cVAgAtSrboaZyJ-1p7x5fYiN6VRII"

# SQL command to add the column
$sql = "ALTER TABLE fleet_vehicles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;"

# Create the request URL
$url = "https://$projectRef.supabase.co/rest/v1/rpc/execute_sql"

# Create the request body
$body = @{
    "sql" = $sql
} | ConvertTo-Json

# Create the request headers
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
    "Content-Type" = "application/json"
}

# Make the request
try {
    Write-Host "Executing SQL: $sql"
    $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body
    Write-Host "SQL executed successfully!"
    Write-Host $response
} catch {
    Write-Host "Error executing SQL: $_"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host $responseBody
    }
}
