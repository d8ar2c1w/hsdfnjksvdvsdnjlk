#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

$RepoDir = $env:GITHUB_WORKSPACE
if (-not $RepoDir) {
    # 兜底：如果环境变量不存在，默认用当前脚本所在仓库根目录
    $RepoDir = Split-Path -LiteralPath (Split-Path -LiteralPath $PSScriptRoot -Parent) -Parent
}

$SaveDir    = "D:\save"
$BranchName = "vm-snapshots"

$WinSave    = Join-Path $RepoDir ".github\workflows\scripts\win-save-snapshot.ps1"
$WinRestore = Join-Path $RepoDir ".github\workflows\scripts\win-restore-snapshot.ps1"

function Ensure-Repo {
    if (-not (Test-Path -LiteralPath $RepoDir)) {
        throw "Repository path '$RepoDir' does not exist."
    }
}

function Get-SnapshotNames {
    Ensure-Repo
    Push-Location $RepoDir
    try {
        git fetch origin $BranchName 2>$null | Out-Null
        $names = git ls-tree --name-only "origin/$BranchName:snapshots" 2>$null
        return $names
    }
    finally {
        Pop-Location
    }
}

function Show-SnapshotList {
    $names = Get-SnapshotNames
    if (-not $names) {
        Write-Host "当前分支 '$BranchName' 下还没有任何快照。"
        return
    }

    Write-Host "分支 '$BranchName' 中已有的快照："
    $idx = 1
    foreach ($n in $names) {
        Write-Host "  [$idx] $n"
        $idx++
    }
}

function Invoke-SnapshotSave {
    param(
        [string]$TargetName
    )

    Ensure-Repo

    if (-not $TargetName) {
        Write-Host "快照名称不能为空，已取消保存。"
        return
    }

    $name = $TargetName.Trim()

    $env:SNAPSHOT_TARGET = $name
    Push-Location $RepoDir
    try {
        & $WinSave
    }
    finally {
        Pop-Location
        Remove-Item Env:SNAPSHOT_TARGET -ErrorAction SilentlyContinue
    }
}

function Invoke-SnapshotRestore {
    param(
        [string]$Name
    )

    Ensure-Repo

    if (-not $Name) {
        Write-Host "快照名称不能为空，已取消还原。"
        return
    }

    $env:SNAPSHOT_FOLDER = $Name.Trim()
    Push-Location $RepoDir
    try {
        & $WinRestore
    }
    finally {
        Pop-Location
        Remove-Item Env:SNAPSHOT_FOLDER -ErrorAction SilentlyContinue
    }
}

function Stop-ProcessesUsingSave {
    Write-Host "正在扫描可执行文件位于 $SaveDir 下的进程..."

    $procs = @()
    foreach ($p in Get-Process) {
        try {
            $path = $p.MainModule.FileName
        }
        catch {
            continue
        }

        if ($path -and $path.StartsWith($SaveDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $procs += [PSCustomObject]@{
                Id   = $p.Id
                Name = $p.ProcessName
                Path = $path
            }
        }
    }

    if (-not $procs) {
        Write-Host "未发现可执行文件位于 $SaveDir 下的进程。"
        return
    }

    Write-Host "将要终止以下进程："
    $procs | ForEach-Object {
        Write-Host "  PID $($_.Id) - $($_.Name) - $($_.Path)"
    }

    foreach ($p in $procs) {
        try {
            Stop-Process -Id $p.Id -Force -ErrorAction Stop
            Write-Host "已终止 PID $($p.Id) ($($p.Name))"
        }
        catch {
            Write-Warning "终止 PID $($p.Id) 失败: $_"
        }
    }
}

Write-Host "=== D:\save 快照管理器 ==="
Write-Host "仓库路径: $RepoDir"
Write-Host "数据目录: $SaveDir"
Write-Host ""

$answer = Read-Host "是否要【保存并结束本次使用】？(y/N)"
if ($answer -match '^(y|Y)$') {
    $doKill = Read-Host "保存前是否尝试结束所有运行在 $SaveDir 下的程序？(y/N)"
    if ($doKill -match '^(y|Y)$') {
        Stop-ProcessesUsingSave
    }

    Show-SnapshotList
    $target = Read-Host "输入要保存到的快照名称（可新建，不可为空）"
    if ($target) {
        Invoke-SnapshotSave -TargetName $target
        Write-Host ""
        Write-Host "保存完成。"
        Write-Host "注意：GitHub Actions 不会自动停止，请回到网页手动 Cancel 当前 workflow。"
    }
    else {
        Write-Host "未提供快照名称，未执行保存。"
    }
    exit 0
}

while ($true) {
    Write-Host ""
    Write-Host "请选择操作："
    Write-Host "  1) 列出已有快照"
    Write-Host "  2) 将当前 D:\save 保存到指定快照（可新建）"
    Write-Host "  3) 从指定快照还原到 D:\save（会删除多余文件）"
    Write-Host "  Q) 退出"

    $choice = Read-Host "请输入选项"

    switch ($choice) {
        '1' {
            Show-SnapshotList
        }
        '2' {
            $doKill = Read-Host "保存前是否尝试结束所有运行在 $SaveDir 下的程序？(y/N)"
            if ($doKill -match '^(y|Y)$') {
                Stop-ProcessesUsingSave
            }
            Show-SnapshotList
            $target = Read-Host "输入要保存到的快照名称（可新建，不可为空）"
            if ($target) {
                Invoke-SnapshotSave -TargetName $target
            }
            else {
                Write-Host "未提供快照名称，未执行保存。"
            }
        }
        '3' {
            Show-SnapshotList
            $name = Read-Host "输入要还原的快照名称"
            if ($name) {
                $confirm = Read-Host "确认要用 '$name' 完全覆盖 D:\save 吗？(y/N)"
                if ($confirm -match '^(y|Y)$') {
                    Invoke-SnapshotRestore -Name $name
                }
                else {
                    Write-Host "已取消还原。"
                }
            }
            else {
                Write-Host "未提供快照名称，未执行还原。"
            }
        }
        'q' { break }
        'Q' { break }
        default {
            Write-Host "无效选项。"
        }
    }
}

