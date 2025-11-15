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
$guiScript = Join-Path $workspace ".github\workflows\scripts\save_manager_gui.py"

$cmdContent = @"
@echo off
set "GITHUB_WORKSPACE=$workspace"
python "$guiScript"
"@

Set-Content -LiteralPath $cmdPath -Value $cmdContent -Encoding ASCII

Write-Host "Created D:\save-manager.cmd. Run it inside RDP to open the snapshot GUI."
