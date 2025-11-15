#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "`n=== RDP ACCESS ==="
Write-Host "Address: $env:TAILSCALE_IP"
Write-Host "Username: vum"
Write-Host "Password: $env:RDP_CREDS"
Write-Host "==================`n"

Write-Host "D:\save will be used as the persistent workspace."
Write-Host "To trigger shutdown and snapshot:"
Write-Host "  1. Inside the RDP session, ensure D:\save exists."
Write-Host "  2. Create the file D:\save\.shutdown when you are finished."
Write-Host "This workflow will detect the flag, snapshot D:\save (if enabled),"
Write-Host "and then terminate, destroying the VM but keeping your data in Git."
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
    if (Test-Path -LiteralPath $shutdownFlag) {
        Write-Host "Shutdown flag detected at '$shutdownFlag'."

        if ($saveOnExit) {
            Write-Host "SAVE_ON_EXIT is true. Saving snapshot of '$saveDir'..."
            & "$PSScriptRoot\win-save-snapshot.ps1"
            $rc = $LASTEXITCODE
            if ($rc -ne 0) {
                Write-Warning "Snapshot script exited with code $rc."
            }
        } else {
            Write-Host "SAVE_ON_EXIT is false; skipping snapshot."
        }

        Write-Host "Exiting maintain loop and allowing workflow to finish."
        break
    }

    Write-Host "[$(Get-Date)] RDP Active - create D:\save\.shutdown to save and terminate, or cancel workflow to force stop."
    Start-Sleep -Seconds 60
}

