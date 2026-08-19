# Supabase CLI Usage Guide

This repo targets the live Supabase project only. Use the CLI for live project
administration, migrations, type generation, and Edge Function deployment.

## Installation

The Supabase CLI has been installed globally using Scoop, a package manager for Windows. You can use it directly from the command line.

## Using the CLI

You can use the Supabase CLI in several ways:

### 1. Direct Command Line

You can run the Supabase CLI directly from the command line:

```bash
supabase <command>
```

### 2. Using npm scripts

We've added several npm scripts to make it easier to use the Supabase CLI:

```bash
# Run Supabase CLI commands
npm run supabase -- <command>

# Create a new Edge Function
npm run supabase:functions:new -- <function-name>

# Deploy Edge Functions
npm run supabase:functions:deploy -- <function-name>
```

### 3. Using the convenience scripts

We've created convenience scripts that you can use:

```bash
# Windows Command Prompt
supabase-cli.bat <command>

# PowerShell
./supabase-cli.ps1 <command>
```

## Common Commands

Here are some common Supabase CLI commands for the live project:

```bash
# Authenticate the CLI
npx supabase login

# Link this repo to the live project
npx supabase link --project-ref yftazblpmicqtamyiwyb

# Push tracked migrations to the linked live project
npx supabase db push

# Create a new Edge Function
npx supabase functions new <function-name>

# Deploy an Edge Function
npx supabase functions deploy <function-name>

# List all Edge Functions
npx supabase functions list

# Generate TypeScript types from the live database schema
npx supabase gen types typescript --linked > lib/models/supabase_types.ts

# Pull the remote schema into a new migration file
npx supabase db pull
```

## Troubleshooting

If you encounter any issues with the Supabase CLI, try the following:

1. Make sure you're in the project directory when running the commands
2. Check that Node.js and npm are properly installed
3. Try running `npx supabase --version` to verify the CLI is installed
4. Run `npx supabase projects list` to confirm your account can access the live project
5. If you get permission errors, try running the commands with administrator privileges

For more information, see the [Supabase CLI documentation](https://supabase.com/docs/reference/cli/about).
