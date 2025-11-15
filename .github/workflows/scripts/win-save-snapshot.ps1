#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$SaveDirectory = "D:\save"
$BranchName = "vm-snapshots"

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot locate repository."
}

$repoDir = $env:GITHUB_WORKSPACE

if (-not (Test-Path -LiteralPath $SaveDirectory)) {
    exit 0
}

$files = Get-ChildItem -LiteralPath $SaveDirectory -Recurse -File
if (-not $files) {
    exit 0
}

Set-Location -LiteralPath $repoDir

git config user.name  "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

git fetch origin $BranchName 2>$null

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
$commitExit = $LASTEXITCODE
if ($commitExit -ne 0) {
    Write-Host "No changes to commit for snapshot (directory unchanged)."
}

git push origin HEAD:refs/heads/$BranchName
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push snapshot branch '$BranchName' to origin."
}

if ($commitExit -eq 0) {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($SaveDirectory.Length).TrimStart('\')
        Write-Host "$relative 已保存"
    }
}

"SNAPSHOT_TIMESTAMP=$timestamp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

exit 0
