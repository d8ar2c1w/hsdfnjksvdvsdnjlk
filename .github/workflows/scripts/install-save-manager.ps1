#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

if (-not $env:GITHUB_WORKSPACE) {
    throw "GITHUB_WORKSPACE is not set; cannot install save-manager.cmd."
}

$workspace = $env:GITHUB_WORKSPACE
$token = $env:GITHUB_TOKEN

# 授予 Users 组对工作区和 D:\save 的完全控制权限，
# 确保 RDP 用户 (vum) 可以读取脚本并执行 Git 操作，以及写入数据目录。
$dirsToGrant = @($workspace)
if (Test-Path -LiteralPath "D:\save") {
    $dirsToGrant += "D:\save"
}

foreach ($dir in $dirsToGrant) {
    Write-Host "Granting 'Users' full control on '$dir'..."
    # (OI)(CI)F = Object Inherit, Container Inherit, Full Control
    $null = icacls $dir /grant "Users:(OI)(CI)F" /T
}

$cmdPath = "D:\save-manager.cmd"
$guiScript = Join-Path $workspace ".github\workflows\scripts\save_manager_gui.py"

$cmdContent = @"
@echo off
set "GITHUB_WORKSPACE=$workspace"
set "GH_TOKEN=$token"
python "$guiScript"
if %ERRORLEVEL% NEQ 0 (
    echo Execution failed with error code %ERRORLEVEL%
    pause
)
"@

Set-Content -LiteralPath $cmdPath -Value $cmdContent -Encoding ASCII

Write-Host "Created D:\save-manager.cmd with auth token. Run it inside RDP to open the snapshot GUI."
