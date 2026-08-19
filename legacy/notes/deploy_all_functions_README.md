# Supabase Edge Functions Deployment Automation

This script automates the deployment of Supabase Edge Functions with the following features:
- Logging of all deployment actions and results
- Error handling for each function deployment
- Selective deployment (deploy only specified functions, or all if none specified)
- Parallel deployment for faster execution
- Pre- and post-deployment hooks for custom tasks

## Usage

### Deploy All Functions
```powershell
pwsh ./deploy_all_functions.ps1
```

### Deploy Specific Functions
```powershell
pwsh ./deploy_all_functions.ps1 -FunctionNames func1,func2
```

### Log Output
Deployment logs are saved to `./deploy_logs/deploy_YYYYMMDD_HHMMSS.log`.

### Pre/Post Hooks
- Add custom commands to `pre_deploy_hook.ps1` and `post_deploy_hook.ps1`.

## Script Features

- **Logging:** All output and errors are logged per run.
- **Error Handling:** Errors are caught and logged for each function.
- **Selective Deployment:** Use the `-FunctionNames` parameter to deploy only specific functions.
- **Parallel Deployment:** Deploys functions in parallel jobs for speed.
- **Pre/Post Hooks:** Run custom scripts before and after deployment.

## Requirements
- PowerShell 7+
- Supabase CLI installed and configured

## Directory Structure
```
project-root/
  deploy_all_functions.ps1
  pre_deploy_hook.ps1
  post_deploy_hook.ps1
  deploy_logs/
  supabase/
    functions/
      <function-names>/
```
