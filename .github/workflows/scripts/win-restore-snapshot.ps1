#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$SaveDirectory  = "D:\save"
$BranchName     = "vm-snapshots"
$SnapshotFolder = $env:SNAPSHOT_FOLDER

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot locate repository."
}

$repoDir = $env:GITHUB_WORKSPACE
Set-Location -LiteralPath $repoDir

if (-not $SnapshotFolder) {
    exit 0
}

git fetch origin $BranchName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not fetch branch '$BranchName'. Skipping restore."
    exit 0
}

git restore --source "origin/$BranchName" -- "snapshots/$SnapshotFolder"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Snapshot 'snapshots/$SnapshotFolder' not found in origin/$BranchName."
    exit 0
}

$sourceDir = Join-Path $repoDir "snapshots\$SnapshotFolder"
if (-not (Test-Path -LiteralPath $sourceDir)) {
    throw "Restored snapshot directory not found at '$sourceDir'."
}

if (-not (Test-Path -LiteralPath $SaveDirectory)) {
    New-Item -ItemType Directory -Path $SaveDirectory -Force | Out-Null
}

Write-Host "Copying snapshot from '$sourceDir' to '$SaveDirectory'..."

$null = robocopy $sourceDir $SaveDirectory /E /NFL /NDL /NJH /NJS /NC /NS
$rc = $LASTEXITCODE
if ($rc -ge 8) {
    throw "Robocopy failed with exit code $rc while restoring snapshot."
}

Write-Host "Snapshot '$SnapshotFolder' successfully restored to '$SaveDirectory'."

exit 0
