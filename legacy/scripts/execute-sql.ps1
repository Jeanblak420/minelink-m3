param (
    [Parameter(Mandatory=$true)]
    [string]$SqlCommand
)

# Get the project reference from the linked project
$projectRef = "kkcseqmpgzzrogatdoqi"  # Hardcoded from your previous output

# Execute the SQL command using the Supabase REST API
$apiUrl = "https://$projectRef.supabase.co/rest/v1/rpc/execute_sql"

# Get the anon key from the environment or use the one from your previous output
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrY3NlcW1wZ3p6cm9nYXRkb3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzODM4ODcsImV4cCI6MjA2MTk1OTg4N30.G126pc4J8Xi4S5cVAgAtSrboaZyJ-1p7x5fYiN6VRII"

# Create a temporary function to execute SQL
$createFunctionSql = @"
CREATE OR REPLACE FUNCTION execute_sql(sql_command text)
RETURNS text AS \$\$
BEGIN
    EXECUTE sql_command;
    RETURN 'SQL executed successfully';
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;
"@

# First create the function using the Supabase CLI
Write-Host "Creating temporary SQL execution function..."
./supabase-cli.ps1 db query "$createFunctionSql" --db-url "postgresql://postgres:postgres@localhost:54322/postgres"

# Now execute the SQL command using the function
Write-Host "Executing SQL command..."
$body = @{
    "sql_command" = $SqlCommand
} | ConvertTo-Json

$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=minimal"
}

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Headers $headers -Body $body
    Write-Host "SQL executed successfully!"
    return $response
} catch {
    Write-Host "Error executing SQL: $_"
    Write-Host $_.Exception.Response.StatusCode
    Write-Host $_.Exception.Response.StatusDescription
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host $responseBody
    }
    return $null
}
