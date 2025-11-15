#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "`n=== RDP ACCESS ==="
Write-Host "Address: $env:TAILSCALE_IP"
Write-Host "Username: vum"
Write-Host "Password: $env:RDP_CREDS"
Write-Host "==================`n"

Write-Host "D:\save will be used as the persistent workspace."
Write-Host "This workflow will automatically snapshot D:\save to branch 'vm-snapshots'"
Write-Host "approximately once per minute (if enabled by the workflow input)."
Write-Host "You can cancel the workflow in GitHub Actions when you no longer"
Write-Host "need the VM; snapshots taken before cancellation will remain in Git."
Write-Host ""

$saveOnExit = $true
if ($env:SAVE_ON_EXIT) {
    $value = $env:SAVE_ON_EXIT.ToString().ToLowerInvariant()
    if ($value -eq "false" -or $value -eq "0" -or $value -eq "no") {
        $saveOnExit = $false
    }
}

while ($true) {
    if ($saveOnExit) {
        Write-Host "[$(Get-Date)] Auto snapshot of D:\save triggered..."
        & "$PSScriptRoot\win-save-snapshot.ps1"
        $rc = $LASTEXITCODE
        if ($rc -ne 0) {
            Write-Warning "Snapshot script exited with code $rc."
        }
    } else {
        Write-Host "[$(Get-Date)] Auto snapshot disabled by workflow input."
    }

    Write-Host "[$(Get-Date)] RDP Active - cancel workflow in GitHub Actions to terminate this VM."
    Start-Sleep -Seconds 60
}
