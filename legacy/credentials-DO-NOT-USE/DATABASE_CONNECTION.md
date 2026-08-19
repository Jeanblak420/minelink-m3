# Database Connection Guide

This guide explains how to use the direct PostgreSQL connection string for the Supabase database.

## Connection String

The connection string for the database is:

```
postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
```

## Using the Connection String

### Option 1: Run the Setup Script

For Windows PowerShell:
```
.\setup_db_connection.ps1
```

For Windows Command Prompt:
```
setup_db_connection.bat
```

This will set the connection string as an environment variable that can be accessed in your code.

### Option 2: Set Environment Variable Manually

#### Windows PowerShell
```powershell
$env:SUPABASE_DB_URL = "postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"
```

#### Windows Command Prompt
```cmd
set SUPABASE_DB_URL=postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
```

## Using with Supabase CLI

When using the Supabase CLI, you can link your project with:

```bash
supabase link --project-ref kkcseqmpgzzrogatdoqi
```

When prompted for the database password, enter:
```
BuRG3rJ3@n1995@#!
```

## Security Notes

- Do not commit the connection string or password to version control
- Keep the `.env` file in your `.gitignore`
- Consider using a password manager to store the connection string securely
