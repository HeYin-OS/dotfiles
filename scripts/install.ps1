#Requires -Version 7.0
# Windows Dotfiles：安装 Shell 依赖，不修改现有配置。
[CmdletBinding()]
param(
    [switch]$CheckOnly
)

if (-not $IsWindows) { Write-Warning 'This installer supports Windows only.'; return }

# 01. 依赖清单
$packages = @(
    @{ Name = 'Git'; Command = 'git'; Id = 'Git.Git'; Url = 'https://git-scm.com/download/win' }
    @{ Name = 'Oh My Posh'; Command = 'oh-my-posh'; Id = 'JanDeDobbeleer.OhMyPosh'; Url = 'https://ohmyposh.dev/docs/installation/windows' }
    @{ Name = 'Zoxide'; Command = 'zoxide'; Id = 'ajeetdsouza.zoxide'; Url = 'https://github.com/ajeetdsouza/zoxide' }
    @{ Name = 'Fastfetch'; Command = 'fastfetch'; Id = 'Fastfetch-cli.Fastfetch'; Url = 'https://github.com/fastfetch-cli/fastfetch' }
    @{ Name = 'Emacs'; Command = 'emacsclient'; Id = 'GNU.Emacs'; Url = 'https://www.gnu.org/software/emacs/' }
)
$modules = @('PSReadLine', 'Terminal-Icons')
$results = [System.Collections.Generic.List[object]]::new()
function Add-Result($Name, $Status) {
    $results.Add([pscustomobject]@{ Name = $Name; Status = $Status })
    if (-not $CheckOnly) { Write-Host "[$Status] $Name" }
}

# 02. 包管理器：缺失时安装，不升级现有版本
function Update-SessionPath {
    $paths = @($env:Path -split ';') + @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
    ) + @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';')
    $env:Path = ($paths | Where-Object { $_ } | ForEach-Object {
            [Environment]::ExpandEnvironmentVariables($_)
        } | Select-Object -Unique) -join ';'
}

function Test-Cli($Name) {
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (Test-Cli winget) {
    Add-Result 'WinGet' 'Present'
}
elseif ($CheckOnly) { Add-Result 'WinGet' 'Missing from PATH' }
else {
    try {
        if (-not (Get-Module -ListAvailable Microsoft.WinGet.Client)) {
            Install-Module Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
        }
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop
        Repair-WinGetPackageManager -ErrorAction Stop | Out-Host
        Update-SessionPath
        if (Test-Cli winget) { Add-Result 'WinGet' 'Installed' }
        else { Add-Result 'WinGet' 'Repair completed; restart required' }
    }
    catch {
        Add-Result 'WinGet' 'Failed'
        Write-Warning "$_"
        Write-Host 'Install: https://aka.ms/getwinget'
    }
}

if (Test-Cli scoop) { Add-Result 'Scoop' 'Present' }
elseif ($CheckOnly) { Add-Result 'Scoop' 'Missing from PATH' }
else {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Run the installer in a non-elevated PowerShell session to install Scoop.'
        }
        if ((Get-ExecutionPolicy) -notin @('RemoteSigned', 'Unrestricted', 'Bypass')) {
            throw 'Scoop requires RemoteSigned, Unrestricted or Bypass. Review your execution policy before retrying.'
        }
        # 下载官方安装脚本到临时目录，执行后清理
        $tempInstaller = Join-Path ([IO.Path]::GetTempPath()) ("scoop-install-" + [guid]::NewGuid() + '.ps1')
        try {
            Invoke-WebRequest 'https://get.scoop.sh' -OutFile $tempInstaller -ErrorAction Stop
            & $tempInstaller
        }
        finally { Remove-Item -LiteralPath $tempInstaller -Force -ErrorAction SilentlyContinue }
        Update-SessionPath
        if (-not (Test-Cli scoop)) { throw 'Scoop is not available in PATH after installation.' }
        Add-Result 'Scoop' 'Installed'
    }
    catch {
        Add-Result 'Scoop' 'Failed'
        Write-Warning "$_"
        Write-Host 'Install: https://scoop.sh/'
    }
}

# 03. CLI 程序：使用 WinGet，兼容已有 Scoop/手动安装
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
foreach ($package in $packages) {
    if (Get-Command $package.Command -ErrorAction SilentlyContinue) {
        Add-Result $package.Name 'Present'; continue
    }
    if ($CheckOnly) { Add-Result $package.Name 'Missing from PATH'; continue }
    if (-not $hasWinget) {
        Add-Result $package.Name 'Skipped'
        Write-Warning 'WinGet is unavailable. Install App Installer from Microsoft Store.'
        Write-Host $package.Url
        continue
    }
    try {
        # 已被 WinGet 识别的安装也不重复安装
        winget list --id $package.Id --exact --source winget --accept-source-agreements | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Add-Result $package.Name 'Registered; check PATH'; continue
        }
        winget install --id $package.Id --exact --source winget --no-upgrade --accept-source-agreements --accept-package-agreements | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "WinGet exit code: $LASTEXITCODE" }
        Update-SessionPath
        Add-Result $package.Name 'Installed'
    }
    catch {
        Add-Result $package.Name 'Failed'
        Write-Warning "${_}"
        Write-Host $package.Url
    }
}

# 04. PowerShell 模块：仅安装到当前用户
foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        Add-Result $module 'Present'; continue
    }
    if ($CheckOnly) { Add-Result $module 'Missing'; continue }
    try {
        if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
            throw 'Install-Module is unavailable. Install or repair PowerShellGet.'
        }
        Install-Module -Name $module -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
        Add-Result $module 'Installed'
    }
    catch {
        Add-Result $module 'Failed'
        Write-Warning "${_}"
        Write-Host "https://www.powershellgallery.com/packages/$module"
    }
}

# 05. 字体：检测当前用户及系统注册的字体
function Test-JetBrainsMonoNerdFont {
    $keys = @(
        'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    )
    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) {
            $names = (Get-Item -LiteralPath $key).GetValueNames()
            if ($names -match 'JetBrains\s*Mono.*(?:Nerd\s*Font|NF)') { return $true }
        }
    }
    return $false
}

$fontName = 'JetBrainsMono Nerd Font'
if (Test-JetBrainsMonoNerdFont) { Add-Result $fontName 'Present' }
elseif ($CheckOnly) { Add-Result $fontName 'Not detected' }
elseif (Test-Cli oh-my-posh) {
    try {
        oh-my-posh font install JetBrainsMono | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Font installer exit code: $LASTEXITCODE" }
        if (Test-JetBrainsMonoNerdFont) { Add-Result $fontName 'Installed' }
        else { Add-Result $fontName 'Installer completed; verify font registration' }
    }
    catch {
        Add-Result $fontName 'Failed'
        Write-Warning "$_"
        Write-Host 'Install: https://www.nerdfonts.com/font-downloads'
    }
}
else {
    Add-Result $fontName 'Skipped'
    Write-Warning 'Oh My Posh is unavailable. Restart the terminal and rerun the installer.'
    Write-Host 'Install: https://www.nerdfonts.com/font-downloads'
}

# 06. 汇总与手动安装项
$results | Format-Table -AutoSize
if (-not $CheckOnly) {
    Write-Host 'MSVC: https://visualstudio.microsoft.com/downloads/'
    Write-Host 'CUDA: https://developer.nvidia.com/cuda-toolkit-archive'
    Write-Host 'cuDNN: https://developer.nvidia.com/cudnn'
    Write-Host 'Restart Windows Terminal to refresh PATH and verify the installed commands.'
}
