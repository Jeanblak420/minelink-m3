# Run gh CLI with this repo's GitHub account only.
$env:GH_CONFIG_DIR = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) '.gh'
& gh @args
