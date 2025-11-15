# Create RDP user with fixed password
$password = "123456"
$securePass = ConvertTo-SecureString $password -AsPlainText -Force

# Create the local user
New-LocalUser -Name "vum" -Password $securePass -AccountNeverExpires

# Add to Administrators group
Add-LocalGroupMember -Group "Administrators" -Member "vum"

# Add to Remote Desktop Users group
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "vum"

# Output credentials to GitHub Actions environment variable (if running in Actions)
echo "RDP_CREDS=User: vum | Password: $password" >> $env:GITHUB_ENV

# Verify user creation
if (-not (Get-LocalUser -Name "vum")) { throw "User creation failed" }

Write-Output "User 'vum' created successfully with password 123456"
