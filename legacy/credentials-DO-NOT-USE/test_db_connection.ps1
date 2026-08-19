# Test Database Connection Script
# This script tests the connection to the Supabase PostgreSQL database

# Set the database connection string
$connectionString = "postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"

# Check if psql is installed
try {
    $psqlVersion = psql --version
    Write-Host "PostgreSQL client found: $psqlVersion"
} catch {
    Write-Host "PostgreSQL client (psql) not found. Please install PostgreSQL client tools."
    Write-Host "You can download it from: https://www.postgresql.org/download/windows/"
    exit 1
}

# Test the connection
Write-Host "Testing connection to the database..."
Write-Host "This will attempt to connect and run a simple query."
Write-Host ""

try {
    # Use the PGPASSWORD environment variable to pass the password
    $password = $connectionString -replace ".*:(.*)@.*", '$1'
    $env:PGPASSWORD = $password
    
    # Extract connection details
    $host = $connectionString -replace ".*@(.*):[0-9]+/.*", '$1'
    $port = $connectionString -replace ".*:([0-9]+)/.*", '$1'
    $database = $connectionString -replace ".*/([^/]+)$", '$1'
    $username = $connectionString -replace ".*://([^:]+):.*", '$1'
    
    # Run a simple query
    $query = "SELECT current_database() as database, current_user as user, version() as version;"
    $result = psql -h $host -p $port -d $database -U $username -c $query
    
    Write-Host "Connection successful!"
    Write-Host $result
} catch {
    Write-Host "Connection failed: $_"
} finally {
    # Clear the password from environment
    $env:PGPASSWORD = ""
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
