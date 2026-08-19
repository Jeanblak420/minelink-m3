# Supabase Edge Functions Deployment Automation
# Features: Logging, Error Handling, Selective & Parallel Deployment, Pre/Post Hooks

param(
    [string[]]$FunctionNames
)

$ErrorActionPreference = 'Stop'

# Timestamp for log file
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logDir = Join-Path $PSScriptRoot 'deploy_logs'
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "deploy_${timestamp}.log"

function Log {
    param([string]$msg)
    $msg | Tee-Object -FilePath $logFile -Append
}

function Invoke-HookScript {
    param([string]$hookScript)
    if (Test-Path $hookScript) {
        Log "[Hook] Running $hookScript..."
        & $hookScript | Tee-Object -FilePath $logFile -Append
        Log "[Hook] $hookScript completed."
    } else {
        Log "[Hook] $hookScript not found, skipping."
    }
}

$functionsPath = Join-Path $PSScriptRoot 'supabase/functions'
if ($FunctionNames -and $FunctionNames.Count -gt 0) {
    $functionsToDeploy = $FunctionNames
} else {
    $functionsToDeploy = Get-ChildItem -Path $functionsPath -Directory | ForEach-Object { $_.Name }
}

Log "[Deploy] Starting deployment at $timestamp"
Log "[Deploy] Functions to deploy: $($functionsToDeploy -join ', ')"


# Run pre-deploy hook
Invoke-HookScript (Join-Path $PSScriptRoot 'pre_deploy_hook.ps1')

# Deploy in parallel
$jobs = @()
foreach ($funcName in $functionsToDeploy) {
    $job = Start-Job -ScriptBlock {
        param($funcName, $scriptRoot, $logFile)
        $ErrorActionPreference = 'Stop'
        function LogJob { param($msg, $logFile) $msg | Tee-Object -FilePath $logFile -Append }
        LogJob "[Deploy] Deploying function $funcName" $logFile
        & "$scriptRoot/supabase-cli.ps1" functions deploy $funcName 2>&1 | Tee-Object -FilePath $logFile -Append
        LogJob "[Deploy] Success for $funcName" $logFile
    } -ArgumentList $funcName, $PSScriptRoot, $logFile
    $jobs += $job
}

# Wait for all jobs to finish
if ($jobs.Count -gt 0) {
    foreach ($job in $jobs) { 
        Receive-Job -Job $job -Wait | Out-Null 
    }
    Remove-Job -Job $jobs
}


# Run post-deploy hook
Invoke-HookScript (Join-Path $PSScriptRoot 'post_deploy_hook.ps1')

Log "[Deploy] Deployment finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Deployment complete. See log $logFile"
