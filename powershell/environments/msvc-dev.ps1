# =============================================================================
# MSVC / C++ 开发环境初始化
# =============================================================================

# 01. 读取本机配置与字段校验
$configPath = Join-Path $PSScriptRoot '../config/toolchain.local.psd1'

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Host "[ERROR] Local toolchain configuration not found: $configPath" -ForegroundColor Red
    Write-Host '  Create powershell/config/toolchain.local.psd1 before initialization.'
    return
}

try {
    $config = Import-PowerShellDataFile -LiteralPath $configPath -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Failed to read toolchain configuration: $($_.Exception.Message)" -ForegroundColor Red
    return
}

if ($config.MSVC -isnot [System.Collections.IDictionary]) {
    Write-Host '[ERROR] Missing or invalid configuration section: MSVC' -ForegroundColor Red
    Write-Host "  Check configuration: $configPath"
    return
}

$invalidConfig = $false
foreach ($field in @('Root', 'InstanceId', 'Version', 'TargetArch', 'HostArch', 'Language')) {
    $value = $config.MSVC[$field]
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        Write-Host "[ERROR] Missing or invalid configuration field: MSVC.$field" -ForegroundColor Red
        $invalidConfig = $true
    }
}
if ($invalidConfig) {
    Write-Host "  Check configuration: $configPath"
    return
}

$vsRoot = $config.MSVC.Root
$vsInstanceId = $config.MSVC.InstanceId
$msvcVersion = $config.MSVC.Version
$targetArch = $config.MSVC.TargetArch
$hostArch = $config.MSVC.HostArch
$vsLanguage = $config.MSVC.Language
$msvcVersionPattern = '^' + [regex]::Escape($msvcVersion) + '(\.|$)'
$devCmdArguments = "-arch=$targetArch -host_arch=$hostArch -vcvars_ver=$msvcVersion"

# 02. 工具链路径预检
try {
    $vsDevShell = Join-Path $vsRoot 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll' -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Invalid Visual Studio path: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check configuration: $configPath"
    return
}
$vsUrl = 'https://visualstudio.microsoft.com/downloads/'

# 检查配置路径，不自动安装或搜索其他版本
$checks = @(
    @{ Name = 'Visual Studio Build Tools'; Path = $vsRoot; Type = 'Container'; Url = $vsUrl }
    @{ Name = 'Visual Studio DevShell'; Path = $vsDevShell; Type = 'Leaf'; Url = $vsUrl }
)

$missing = $false
foreach ($check in $checks) {
    if (-not (Test-Path -LiteralPath $check.Path -PathType $check.Type)) {
        Write-Host "[ERROR] $($check.Name) not found at the configured path." -ForegroundColor Red
        Write-Host "  Expected: $($check.Path)"
        Write-Host "  Install or repair: $($check.Url)"
        $missing = $true
    }
}

if ($missing) {
    Write-Host '[ERROR] MSVC initialization aborted.' -ForegroundColor Red
    return
}

# 03. 初始化并验证 MSVC 工具链
try {
    Import-Module $vsDevShell -ErrorAction Stop
    Enter-VsDevShell $vsInstanceId `
        -SkipAutomaticLocation `
        -DevCmdArguments $devCmdArguments `
        -ErrorAction Stop

    if ($env:VCToolsVersion -notmatch $msvcVersionPattern -or
        -not (Get-Command cl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        throw "MSVC $msvcVersion or cl.exe is unavailable."
    }
}
catch {
    Write-Host "[ERROR] MSVC initialization failed: $_" -ForegroundColor Red
    Write-Host "  Install the Desktop development with C++ workload and MSVC $msvcVersion toolset."
    Write-Host "  Install or repair: $vsUrl"
    return
}

# 04. 设置编译工具输出语言
$env:VSLANG = $vsLanguage

Write-Host ('VCToolsVersion = ' + $env:VCToolsVersion)
