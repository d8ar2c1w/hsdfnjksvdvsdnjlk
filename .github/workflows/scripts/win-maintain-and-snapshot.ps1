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

$saveDir = "D:\save"
$shutdownFlag = Join-Path $saveDir ".shutdown"

while ($true) {
    if ($saveOnExit) {
        if (Test-Path -LiteralPath $shutdownFlag) {
            Write-Host "Shutdown flag detected at '$shutdownFlag'. Saving snapshot once and exiting..."

            & "$PSScriptRoot\win-save-snapshot.ps1"
            $rc = $LASTEXITCODE
            if ($rc -ne 0) {
                Write-Warning "Snapshot script exited with code $rc."
            }

            Write-Host "Snapshot step finished. Exiting maintain loop."
            break
        }
    } else {
        # Auto snapshot disabled; nothing to do unless config changes
    }

    Start-Sleep -Seconds 60
}
