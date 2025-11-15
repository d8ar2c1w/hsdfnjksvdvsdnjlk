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

function Get-SaveDirectoryHash {
    param(
        [string]$Path = "D:\save"
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $files = Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName
    if (-not $files) {
        return $null
    }

    $sb = New-Object System.Text.StringBuilder
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($Path.Length).TrimStart('\')
        try {
            $fileHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            [void]$sb.AppendLine("$relativePath`:$fileHash")
        }
        catch {
            Write-Warning "Failed to hash file '$($file.FullName)'; skipping. $_"
        }
    }

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    return -join ($hashBytes | ForEach-Object { $_.ToString("x2") })
}

$saveOnExit = $true
if ($env:SAVE_ON_EXIT) {
    $value = $env:SAVE_ON_EXIT.ToString().ToLowerInvariant()
    if ($value -eq "false" -or $value -eq "0" -or $value -eq "no") {
        $saveOnExit = $false
    }
}

$lastHash = $null

while ($true) {
    if ($saveOnExit) {
        $currentHash = Get-SaveDirectoryHash -Path "D:\save"

        if ($null -ne $currentHash -and $currentHash -ne $lastHash) {
            & "$PSScriptRoot\win-save-snapshot.ps1"
            $rc = $LASTEXITCODE
            if ($rc -ne 0) {
                Write-Warning "Snapshot script exited with code $rc."
            } else {
                $lastHash = $currentHash
            }
        }
    } else {
        # Auto snapshot disabled; nothing to do unless config changes
    }

    Start-Sleep -Seconds 60
}
