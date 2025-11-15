#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$Lang = "zh-CN"

Write-Host "Configuring Windows language to Chinese ($Lang)..."

try {
    Write-Host "Trying Install-Language for $Lang..."
    Install-Language -Language $Lang -CopyToSettings -ErrorAction Stop
}
catch {
    Write-Warning "Install-Language failed or not available, trying Add-WindowsCapability..."

    $capabilities = @(
        "Language.Basic~~~$Lang~0.0.1.0",
        "Language.Handwriting~~~$Lang~0.0.1.0",
        "Language.OCR~~~$Lang~0.0.1.0",
        "Language.Speech~~~$Lang~0.0.1.0",
        "Language.TextToSpeech~~~$Lang~0.0.1.0"
    )

    foreach ($cap in $capabilities) {
        try {
            Add-WindowsCapability -Online -Name $cap -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            Write-Warning "Failed to add capability $cap: $_"
        }
    }
}

Write-Host "Setting system locale, culture and UI language to $Lang..."

try {
    # 系统区域（影响非 Unicode 程序）
    Set-WinSystemLocale -SystemLocale $Lang
}
catch {
    Write-Warning "Failed to set system locale: $_"
}

try {
    # 当前会话的文化信息（日期/时间/货币等格式）
    Set-Culture $Lang
}
catch {
    Write-Warning "Failed to set culture: $_"
}

try {
    # 当前会话的 UI 语言覆盖
    Set-WinUILanguageOverride -Language $Lang
}
catch {
    Write-Warning "Failed to set UI language override: $_"
}

try {
    # 区域设为中国
    Set-WinHomeLocation -GeoId 45  # 45 = China
}
catch {
    Write-Warning "Failed to set home location: $_"
}

try {
    # 设置当前用户的输入语言列表
    $list = New-WinUserLanguageList -Language $Lang
    Set-WinUserLanguageList -LanguageList $list -Force | Out-Null
}
catch {
    Write-Warning "Failed to set user language list: $_"
}

Write-Host "Chinese (Simplified, China) language configuration completed. Some UI text may require a new session to fully apply."

