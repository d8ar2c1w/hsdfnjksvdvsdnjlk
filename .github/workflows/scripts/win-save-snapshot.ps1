#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$SaveDirectory = "D:\save"
$BranchName = "vm-snapshots"
$SnapshotTarget = $env:SNAPSHOT_TARGET

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

# Best-effort cleanup of stale Git lock files to avoid interactive prompts
$lockFiles = @(
    ".git\index.lock",
    ".git\config.lock",
    ".git\HEAD.lock"
) | ForEach-Object { Join-Path $repoDir $_ }

foreach ($lock in $lockFiles) {
    if (Test-Path -LiteralPath $lock) {
        try {
            Remove-Item -LiteralPath $lock -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to remove stale Git lock file '$lock': $_"
        }
    }
}

# Avoid any interactive Git prompts
$env:GIT_TERMINAL_PROMPT = "0"

$env:GIT_AUTHOR_NAME  = "github-actions[bot]"
$env:GIT_AUTHOR_EMAIL = "github-actions[bot]@users.noreply.github.com"
$env:GIT_COMMITTER_NAME  = $env:GIT_AUTHOR_NAME
$env:GIT_COMMITTER_EMAIL = $env:GIT_AUTHOR_EMAIL

git fetch origin $BranchName 2>$null

# Bring existing snapshots tree from vm-snapshots branch into the working tree (if it exists)
git ls-remote --exit-code origin "refs/heads/$BranchName" 2>$null
if ($LASTEXITCODE -eq 0) {
    git restore --source "origin/$BranchName" -- "snapshots" 2>$null
}

if ([string]::IsNullOrWhiteSpace($SnapshotTarget)) {
    Write-Host "SNAPSHOT_TARGET is not set or empty. Skipping snapshot."
    exit 0
}

$SnapshotTarget = $SnapshotTarget.Trim()
$snapshotRelative = "snapshots/$SnapshotTarget"

$snapshotDir = Join-Path $repoDir $snapshotRelative

if (-not (Test-Path -LiteralPath $snapshotDir)) {
    New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
}

Write-Host "Copying '$SaveDirectory' to '$snapshotDir'..."

$null = robocopy $SaveDirectory $snapshotDir /MIR /NFL /NDL /NJH /NJS /NC /NS
$rc = $LASTEXITCODE
if ($rc -ge 8) {
    throw "Robocopy failed with exit code $rc while copying snapshot."
}

git add $snapshotDir

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$commitMsg = "Snapshot $timestamp from $SaveDirectory"
git commit -m $commitMsg 2>$null
$commitExit = $LASTEXITCODE
if ($commitExit -ne 0) {
    Write-Host "No changes to commit for snapshot (directory unchanged)."
}

git push origin HEAD:refs/heads/$BranchName --force-with-lease="refs/heads/$BranchName"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to push snapshot branch '$BranchName' to origin."
}

if ($commitExit -eq 0) {
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($SaveDirectory.Length).TrimStart('\')
        Write-Host "$relative 已保存"
    }
}

if ($env:GITHUB_ENV) {
    "SNAPSHOT_TIMESTAMP=$timestamp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

exit 0
