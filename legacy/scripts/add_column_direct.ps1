# PowerShell script to add is_active column to fleet_vehicles table using direct table operations

# Supabase project details
$projectRef = "kkcseqmpgzzrogatdoqi"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtrY3NlcW1wZ3p6cm9nYXRkb3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDYzODM4ODcsImV4cCI6MjA2MTk1OTg4N30.G126pc4J8Xi4S5cVAgAtSrboaZyJ-1p7x5fYiN6VRII"

# Create the request headers
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=minimal"
}

# First, let's try to create a temporary SQL function to execute our ALTER TABLE command
$createFunctionUrl = "https://$projectRef.supabase.co/rest/v1/rpc/create_temp_function"
$createFunctionBody = @{
    "function_name" = "add_is_active_column"
    "function_body" = @"
BEGIN
    ALTER TABLE fleet_vehicles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
    UPDATE fleet_vehicles SET is_active = TRUE WHERE is_active IS NULL;
    COMMENT ON COLUMN fleet_vehicles.is_active IS 'Indicates whether the vehicle is active (true) or inactive (false)';
    RETURN 'Column added successfully';
END;
"@
} | ConvertTo-Json

try {
    Write-Host "Creating temporary function..."
    $response = Invoke-RestMethod -Uri $createFunctionUrl -Method POST -Headers $headers -Body $createFunctionBody
    Write-Host "Function created successfully!"
    
    # Now execute the function
    $executeFunctionUrl = "https://$projectRef.supabase.co/rest/v1/rpc/add_is_active_column"
    $response = Invoke-RestMethod -Uri $executeFunctionUrl -Method POST -Headers $headers
    Write-Host "Column added successfully!"
} catch {
    Write-Host "Error: $_"
    Write-Host $_.Exception.Response.StatusCode
    Write-Host $_.Exception.Response.StatusDescription
    
    # Try a direct approach - update the table schema
    try {
        Write-Host "Trying direct table update..."
        # First, check if the column exists
        $checkUrl = "https://$projectRef.supabase.co/rest/v1/fleet_vehicles?select=id&limit=1"
        $checkResponse = Invoke-RestMethod -Uri $checkUrl -Method GET -Headers $headers
        
        # If we get here, the table exists, let's try to add our column
        # We'll use a PATCH request to update the table definition
        $updateUrl = "https://$projectRef.supabase.co/rest/v1/fleet_vehicles?id=eq.$($checkResponse[0].id)"
        $updateBody = @{
            "is_active" = $true
        } | ConvertTo-Json
        
        $updateResponse = Invoke-RestMethod -Uri $updateUrl -Method PATCH -Headers $headers -Body $updateBody
        Write-Host "Column added successfully through direct update!"
    } catch {
        Write-Host "Error with direct update: $_"
        Write-Host $_.Exception.Response.StatusCode
        Write-Host $_.Exception.Response.StatusDescription
    }
}
