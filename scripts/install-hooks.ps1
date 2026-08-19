# PowerShell script to install Git hooks.
#
# Fixed 2026-08-12: this script wrote a hook invoking `scripts/pre-commit-hook.dart`
# (hyphens) while the file on disk is `scripts/pre_commit_hook.dart` (underscores),
# so every installed hook failed to find its script. That hook's `exit 1` was also
# commented out, meaning it blocked nothing even when it did run.

$hookPath = ".git\hooks\pre-commit"

if (-not (Test-Path ".git")) {
    Write-Error "Not a git working tree (no .git). Run from the repo root."
    exit 1
}

# In a git worktree, .git is a FILE pointing at the real gitdir. This repo is
# checked out that way on Jean's machine, so resolve it rather than assuming.
$hooksDir = ".git\hooks"
if (Test-Path ".git" -PathType Leaf) {
    $gitdir = (Get-Content ".git" -Raw) -replace '^gitdir:\s*', ''
    $hooksDir = Join-Path $gitdir.Trim() "hooks"
    $hookPath = Join-Path $hooksDir "pre-commit"
}

if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
}

@'
#!/bin/sh
# Mine-Link pre-commit hook.
# Release guards (S1-5, S1-8) are BLOCKING: a raw colour, a bundled token or a
# hardcoded trend must not reach a commit.
dart run tool/release_guards.dart || {
  echo ""
  echo "pre-commit: release guards failed. Fix the violation, or if you have"
  echo "genuinely reduced a ratcheted count, re-baseline with:"
  echo "  dart run tool/release_guards.dart --update-baseline"
  exit 1
}

# Advisory only - reports methods that may be missing action tracking.
dart run scripts/pre_commit_hook.dart
'@ | Out-File -FilePath $hookPath -Encoding ascii

if (Get-Command "chmod" -ErrorAction SilentlyContinue) {
    chmod +x $hookPath
}

Write-Host "Git hooks installed to $hookPath"
Write-Host "  blocking : tool/release_guards.dart"
Write-Host "  advisory : scripts/pre_commit_hook.dart"
