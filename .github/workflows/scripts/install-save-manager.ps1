#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot install save-manager.cmd."
}

$workspace = $env:GITHUB_WORKSPACE
$psScript  = Join-Path $workspace ".github\workflows\scripts\save-manager.ps1"

if (-not (Test-Path -LiteralPath $psScript)) {
    throw "Save manager script not found at '$psScript'."
}

$cmdPath = "D:\save-manager.cmd"

$cmdContent = @"
@echo off
set "GITHUB_WORKSPACE=$workspace"
pwsh.exe -NoLogo -ExecutionPolicy Bypass -File "$psScript" %*
"@

Set-Content -LiteralPath $cmdPath -Value $cmdContent -Encoding ASCII

Write-Host "Created D:\save-manager.cmd. You can run it inside RDP to manage snapshots."
