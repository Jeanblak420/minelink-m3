# Git credential helper: uses this repo's .gh/ only (not global gh auth).
$env:GH_CONFIG_DIR = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) '.gh'
& gh auth git-credential @args
