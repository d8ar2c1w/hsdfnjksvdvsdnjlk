# Create a local user for RDP with a strong random password
$ErrorActionPreference = "Stop"

$userName = "vum"

function New-ComplexPassword {
    param(
        [int]$Length = 20
    )

    $upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lower   = "abcdefghijklmnopqrstuvwxyz"
    $digits  = "0123456789"
    $symbols = "!@#$%^&*_-+=?"

    $allChars = ($upper + $lower + $digits + $symbols).ToCharArray()

    $rand = [System.Random]::new()
    $passwordChars = @()

    # Ensure complexity: at least one from each class
    $passwordChars += $upper[$rand.Next(0, $upper.Length)]
    $passwordChars += $lower[$rand.Next(0, $lower.Length)]
    $passwordChars += $digits[$rand.Next(0, $digits.Length)]
    $passwordChars += $symbols[$rand.Next(0, $symbols.Length)]

    while ($passwordChars.Count -lt $Length) {
        $passwordChars += $allChars[$rand.Next(0, $allChars.Length)]
    }

    -join ($passwordChars | Sort-Object { Get-Random })
}

Write-Host "Creating local RDP user '$userName'..."

# Remove existing user if present to avoid conflicts
$existing = Get-LocalUser -Name $userName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Existing user '$userName' found, removing it first..."
    Remove-LocalUser -Name $userName
}

# Prefer a simple, fixed password if allowed by policy
# You can also override via env var RDP_PASSWORD
$preferredPassword = if ($env:RDP_PASSWORD) { $env:RDP_PASSWORD } else { "123456" }

$plainPassword = $preferredPassword
$securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

try {
    New-LocalUser `
        -Name $userName `
        -Password $securePassword `
        -AccountNeverExpires `
        -PasswordNeverExpires `
        -FullName "GitHub Actions RDP User" `
        -Description "User for GitHub Actions Windows RDP session"
    Write-Host "User created with preferred password."
}
catch {
    # Most likely InvalidPasswordException due to local password policy.
    Write-Warning "Preferred password was rejected by local policy. Generating a complex password instead."

    $plainPassword = New-ComplexPassword -Length 20
    $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

    New-LocalUser `
        -Name $userName `
        -Password $securePassword `
        -AccountNeverExpires `
        -PasswordNeverExpires `
        -FullName "GitHub Actions RDP User" `
        -Description "User for GitHub Actions RDP session (complex password)"

    Write-Host "User created with a complex, policy-compliant password."
}

# Grant RDP permission
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $userName -ErrorAction SilentlyContinue

# Optional: admin rights if needed for development
Add-LocalGroupMember -Group "Administrators" -Member $userName -ErrorAction SilentlyContinue

# Export password to GitHub environment for later steps
if (-not $env:GITHUB_ENV) {
    throw "GITHUB_ENV is not set; cannot export RDP credentials."
}

"RDP_CREDS=$plainPassword" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append

Write-Host "User '$userName' created and added to RDP groups."
