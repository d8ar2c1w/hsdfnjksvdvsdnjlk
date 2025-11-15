#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

param(
    [string]$SaveDirectory = "D:\save",
    [string]$BranchName = "vm-snapshots"
)

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot locate repository."
}

$repoDir = $env:GITHUB_WORKSPACE

if (-not (Test-Path -LiteralPath $SaveDirectory)) {
    Write-Host "Save directory '$SaveDirectory' does not exist. Skipping snapshot."
    exit 0
}

Write-Host "Preparing to snapshot '$SaveDirectory' into branch '$BranchName'..."

Set-Location -LiteralPath $repoDir

git config user.name  "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

git fetch origin $BranchName 2>$null

$branchExists = git branch -a --format="%(refname:short)" | Where-Object { $_ -eq $BranchName }
if ($branchExists) {
    git checkout $BranchName
} else {
    git checkout -b $BranchName
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$snapshotRelative = "snapshots/$timestamp"
$snapshotDir = Join-Path $repoDir $snapshotRelative

if (-not (Test-Path -LiteralPath $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

Write-Host "Copying '$SaveDirectory' to '$snapshotDir'..."

$null = robocopy $SaveDirectory $snapshotDir /E /NFL /NDL /NJH /NJS /NC /NS
$rc = $LASTEXITCODE
if ($rc -ge 8) {
    throw "Robocopy failed with exit code $rc while copying snapshot."
}

git add $snapshotDir

$commitMsg = "Snapshot $timestamp from $SaveDirectory"
git commit -m $commitMsg 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "No changes to commit for snapshot (directory unchanged)."
} else {
    git push origin $BranchName
    Write-Host "Snapshot committed and pushed to '$BranchName' at '$snapshotRelative'."
}

"SNAPSHOT_TIMESTAMP=$timestamp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

