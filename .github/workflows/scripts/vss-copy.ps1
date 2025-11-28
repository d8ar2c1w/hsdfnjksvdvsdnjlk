#!/usr/bin/env pwsh
<#
.SYNOPSIS
    使用 VSS (Volume Shadow Copy) 复制被占用的文件
.DESCRIPTION
    创建卷影副本，从快照中复制文件，即使文件被锁定也能备份
.PARAMETER SourcePath
    源目录路径 (如 D:\save)
.PARAMETER DestinationPath
    目标目录路径
.EXAMPLE
    .\vss-copy.ps1 -SourcePath "D:\save" -DestinationPath "C:\backup\save"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
)

$ErrorActionPreference = "Stop"

# 获取源路径所在的卷 (如 D:)
$volume = (Get-Item -LiteralPath $SourcePath).PSDrive.Root
if (-not $volume) {
    throw "无法确定源路径 '$SourcePath' 所在的卷。"
}

# 确保卷格式正确 (如 D:\)
if ($volume -notmatch '\\$') {
    $volume = "$volume\"
}

Write-Host "源路径: $SourcePath"
Write-Host "目标路径: $DestinationPath"
Write-Host "卷: $volume"
Write-Host ""

$shadow = $null
$shadowPath = $null

try {
    Write-Host "正在创建卷影副本..."
    
    # 使用 WMI 创建卷影副本
    $shadowClass = [WMICLASS]"root\cimv2:Win32_ShadowCopy"
    $createResult = $shadowClass.Create($volume, "ClientAccessible")
    
    if ($createResult.ReturnValue -ne 0) {
        throw "创建卷影副本失败，错误代码: $($createResult.ReturnValue)"
    }
    
    $shadowId = $createResult.ShadowID
    Write-Host "卷影副本已创建，ID: $shadowId"
    
    # 获取卷影副本对象
    $shadow = Get-WmiObject -Class Win32_ShadowCopy | Where-Object { $_.ID -eq $shadowId }
    if (-not $shadow) {
        throw "无法找到刚创建的卷影副本。"
    }
    
    # 获取卷影副本的设备路径 (如 \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1)
    $shadowDevicePath = $shadow.DeviceObject
    Write-Host "卷影设备路径: $shadowDevicePath"
    
    # 计算源路径在卷内的相对路径
    $relativePath = $SourcePath.Substring($volume.Length).TrimStart('\')
    
    # 构建卷影副本中的源路径
    $shadowSourcePath = Join-Path "$shadowDevicePath\" $relativePath
    Write-Host "卷影源路径: $shadowSourcePath"
    Write-Host ""
    
    # 确保目标目录存在
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    Write-Host "正在从卷影副本复制文件..."
    
    # 使用 robocopy 从卷影副本复制 (现在文件不会被锁定)
    $null = robocopy $shadowSourcePath $DestinationPath /MIR /R:3 /W:2 /NFL /NDL /NJH /NJS /NC /NS
    $rc = $LASTEXITCODE
    
    # robocopy 返回值 < 8 表示成功
    if ($rc -ge 8) {
        throw "Robocopy 从卷影副本复制失败，退出代码: $rc"
    }
    
    Write-Host "文件复制完成！"
}
catch {
    Write-Error "VSS 备份失败: $_"
    throw
}
finally {
    # 清理：删除卷影副本
    if ($shadow) {
        Write-Host ""
        Write-Host "正在删除卷影副本..."
        try {
            $shadow.Delete()
            Write-Host "卷影副本已删除。"
        }
        catch {
            Write-Warning "删除卷影副本失败: $_"
        }
    }
}

Write-Host ""
Write-Host "VSS 备份成功完成！"
