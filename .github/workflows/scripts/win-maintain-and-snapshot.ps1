#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "`n=== RDP ACCESS ==="
Write-Host "Address: $env:TAILSCALE_IP"
Write-Host "Username: vum"
Write-Host "Password: $env:RDP_CREDS"
Write-Host "==================`n"

Write-Host "D:\save will be used as the persistent workspace."
Write-Host "Use D:\save-manager.cmd inside the RDP session to:"
Write-Host "  - Save D:\save to a named snapshot"
Write-Host "  - Restore D:\save from a snapshot"
Write-Host ""
Write-Host "When you are finished, go to GitHub Actions and Cancel this workflow"
Write-Host "to terminate the VM. No automatic snapshots will be taken."
Write-Host ""

while ($true) {
    Start-Sleep -Seconds 300
}
