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
    ".git\config.lock",
    ".git\HEAD.lock",
    ".git\logs\HEAD.lock",
    ".git\logs\refs\heads\vm-snapshots.lock"
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

# Disable reflog to avoid permission issues with .git/logs
git config --local core.logAllRefUpdates false

# Use a dedicated index file for snapshot operations to avoid conflicts
$env:GIT_INDEX_FILE = Join-Path $repoDir ".git\vm-snapshots.index"

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

git add $snapshotRelative
if ($LASTEXITCODE -ne 0) {
    throw "git add failed for path '$snapshotRelative'."
}

# 检查是否真的有快照变更被 staged
git diff --cached --quiet -- $snapshotRelative
$diffExit = $LASTEXITCODE
if ($diffExit -eq 0) {
    Write-Host "No staged changes for snapshot '$SnapshotTarget' (directory unchanged or empty). Skipping commit and push."
    if ($env:GITHUB_ENV) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        "SNAPSHOT_TIMESTAMP=$timestamp" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
    exit 0
}
elseif ($diffExit -ne 1) {
    throw "git diff --cached failed with exit code $diffExit for path '$snapshotRelative'."
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$commitMsg = "Snapshot $timestamp from $SaveDirectory"
git commit -m $commitMsg
$commitExit = $LASTEXITCODE
if ($commitExit -ne 0) {
    throw "git commit failed with exit code $commitExit for snapshot '$SnapshotTarget'."
}

git push origin HEAD:refs/heads/$BranchName --force
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
