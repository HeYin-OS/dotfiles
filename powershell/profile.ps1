# PowerShell 7 用户配置
# 计时检查点默认关闭，可按需取消 Lap 调用的注释。

# -----------------------------------------------------------------------------
# 01. 基础环境与启动计时
# -----------------------------------------------------------------------------

# Windows 控制台编码
if ($IsWindows -and (Get-Command chcp -ErrorAction SilentlyContinue)) {
    chcp 65001 > $null
}

# 记录实际加载的配置文件
$script:DotfilesProfilePath = $PSCommandPath
$ProfileStartTime = Get-Date
$LastLapTime = $ProfileStartTime

# 记录累计耗时与阶段耗时
function Lap {
    param($Name)
    $now = Get-Date
    $totalElapsed = [int]($now - $ProfileStartTime).TotalMilliseconds
    $segmentElapsed = [int]($now - $LastLapTime).TotalMilliseconds

    Write-Host (">>> [{0,5}ms | +{1,4}ms] {2}" -f $totalElapsed, $segmentElapsed, $Name) -ForegroundColor Yellow

    $script:LastLapTime = $now
}

# Write-Host ">>> PowerShell 7 Shell Environment Initializing..." -ForegroundColor Cyan
# Lap "Init Started"

# -----------------------------------------------------------------------------
# 02. 自定义函数与别名
# -----------------------------------------------------------------------------

# 启动 Emacs 客户端
function e {
    if (Get-Command emacsclient -ErrorAction SilentlyContinue) {
        emacsclient -c -n -a "" @args
    }
    else {
        Write-Warning 'Emacsclient is not available in PATH.'
        Write-Host 'Install: https://www.gnu.org/software/emacs/'
    }
}

# 重建 Windows 图标缓存（仅手动调用）
function Reset-IconCache {
    [CmdletBinding()]
    param()

    # 操作前检查 Windows 系统组件
    if (-not $IsWindows) {
        Write-Warning 'Reset-IconCache is only supported on Windows.'
        return
    }
    if (-not $env:WINDIR -or -not $env:LOCALAPPDATA -or
        -not (Test-Path -LiteralPath "$env:WINDIR\explorer.exe" -PathType Leaf)) {
        Write-Warning 'Windows Explorer or required system paths are unavailable.'
        return
    }

    Write-Host "Stopping Windows Explorer..."

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500

    Remove-Item "$env:LOCALAPPDATA\IconCache.db" `
        -Force -ErrorAction SilentlyContinue

    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" `
        -Force -ErrorAction SilentlyContinue

    Start-Process -FilePath "$env:WINDIR\explorer.exe"
    Start-Sleep -Seconds 5

    $shell = New-Object -ComObject Shell.Application

    @($shell.Windows()) |
    Where-Object {
        try {
            $_.FullName -eq "$env:WINDIR\explorer.exe"
        }
        catch {
            $false
        }
    } |
    ForEach-Object {
        $_.Quit()
    }

    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell) |
    Out-Null

    Write-Host "Icon Db cache was deleted."
}
Set-Alias ric Reset-IconCache

# 编辑当前 Profile、列表显示目录
function cprof {
    if (-not $script:DotfilesProfilePath -or
        -not (Test-Path -LiteralPath $script:DotfilesProfilePath -PathType Leaf)) {
        Write-Warning 'The loaded profile path is unavailable.'
        return
    }
    if ($IsWindows -and (Get-Command notepad -ErrorAction SilentlyContinue)) {
        notepad $script:DotfilesProfilePath
    }
    else {
        Write-Warning 'Notepad is unavailable. Open the following file in your editor:'
        Write-Host $script:DotfilesProfilePath
    }
}
function ll { Get-ChildItem -Path $Args | Format-Table }
# Lap "Custom Functions Defined"

# -----------------------------------------------------------------------------
# 03. 终端提示符与目录跳转
# -----------------------------------------------------------------------------

# Oh My Posh：加载主题
$myConfig = Join-Path $PSScriptRoot '../oh-my-posh/default.json'
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Warning 'Oh My Posh is not available in PATH. Skipping theme initialization.'
    Write-Host 'Install: https://ohmyposh.dev/docs/installation/windows'
}
elseif (-not (Test-Path -LiteralPath $myConfig -PathType Leaf)) {
    Write-Warning "Oh My Posh theme not found: $myConfig"
}
else {
    try {
        $poshInit = oh-my-posh init pwsh --config $myConfig | Out-String
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($poshInit)) {
            throw 'Oh My Posh did not generate a valid initialization script.'
        }
        Invoke-Expression -Command $poshInit -ErrorAction Stop
    }
    catch {
        Write-Warning "Oh My Posh initialization failed: $_"
    }
}
# Lap "Oh-My-Posh Logic Finished"

# Zoxide：智能目录跳转
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try {
        $zoxideInit = zoxide init powershell | Out-String
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($zoxideInit)) {
            throw 'Zoxide did not generate a valid initialization script.'
        }
        Invoke-Expression -Command $zoxideInit -ErrorAction Stop
    }
    catch {
        Write-Warning "Zoxide initialization failed: $_"
    }
}
else {
    Write-Warning 'Zoxide is not available in PATH. Skipping directory navigation setup.'
    Write-Host 'Install: https://github.com/ajeetdsouza/zoxide'
}
# Lap "Zoxide Initialized"

# -----------------------------------------------------------------------------
# 04. 命令行编辑与补全
# -----------------------------------------------------------------------------

# PSReadLine：模块缺失或加载失败时跳过
if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        # 加载 PSReadLine
        Import-Module PSReadLine -ErrorAction Stop
        # Lap "PSReadLine Module Imported"

        # 历史命令预测
        Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
        Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        # Lap "PSReadLine Predictions Configured"

        # 补全与历史搜索快捷键
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete -ErrorAction Stop
        Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward -ErrorAction Stop
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward -ErrorAction Stop
        # Lap "PSReadLine KeyHandlers Configured"
    }
    catch {
        Write-Warning "PSReadLine setup failed: $_"
    }
}
else {
    Write-Warning 'PSReadLine is not installed. Skipping command-line editing setup.'
    Write-Host 'Install: https://github.com/PowerShell/PSReadLine'
    Write-Host 'Command: Install-Module PSReadLine -Scope CurrentUser'
}

# -----------------------------------------------------------------------------
# 05. 终端图标与系统信息
# -----------------------------------------------------------------------------

# Terminal-Icons：文件和目录图标
if (Get-Module -ListAvailable Terminal-Icons) {
    try {
        Import-Module Terminal-Icons -ErrorAction Stop
    }
    catch {
        Write-Warning "Terminal-Icons initialization failed: $_"
    }
}
else {
    Write-Warning 'Terminal-Icons is not installed. Skipping file icons.'
    Write-Host 'Install: https://github.com/devblackops/Terminal-Icons'
    Write-Host 'Command: Install-Module Terminal-Icons -Scope CurrentUser'
}
# Lap "Terminal-Icons Loaded"

# Fastfetch：启动时显示系统信息
$fastfetchConfig = Join-Path $PSScriptRoot '../fastfetch/config.jsonc'
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    try {
        if (Test-Path -LiteralPath $fastfetchConfig -PathType Leaf) {
            fastfetch --config $fastfetchConfig
        }
        else {
            Write-Warning "Fastfetch configuration not found: $fastfetchConfig"
            fastfetch
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Fastfetch exited with code $LASTEXITCODE."
        }
    }
    catch {
        Write-Warning "Fastfetch failed: $_"
    }
}
else {
    Write-Warning 'Fastfetch is not available in PATH. Skipping system information.'
    Write-Host 'Install: https://github.com/fastfetch-cli/fastfetch'
}
# Lap "Fastfetch Execution Completed"

# -----------------------------------------------------------------------------
# 06. 启动耗时汇总
# -----------------------------------------------------------------------------

$FinalTotal = [int]((Get-Date) - $ProfileStartTime).TotalMilliseconds
Write-Host "`n>>> Total Profile Load Time: $FinalTotal ms" -ForegroundColor Green
