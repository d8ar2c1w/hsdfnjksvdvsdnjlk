#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

param(
    [string]$SaveDirectory = "D:\save",
    [string]$BranchName = "vm-snapshots",
    [string]$SnapshotFolder = $env:SNAPSHOT_FOLDER
)

if (-not $SnapshotFolder) {
    Write-Host "No snapshot folder specified. Skipping restore."
    exit 0
}

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot locate repository."
}

$repoDir = $env:GITHUB_WORKSPACE
Set-Location -LiteralPath $repoDir

Write-Host "Attempting to restore snapshot '$SnapshotFolder' from branch '$BranchName' to '$SaveDirectory'..."

git fetch origin $BranchName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Could not fetch branch '$BranchName'. Skipping restore."
    exit 0
}

git cat-file -e "origin/$BranchName:snapshots/$SnapshotFolder" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Snapshot 'snapshots/$SnapshotFolder' not found in branch '$BranchName'."
    exit 0
}

git restore --source "origin/$BranchName" -- "snapshots/$SnapshotFolder"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to restore snapshot folder 'snapshots/$SnapshotFolder' into workspace."
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

