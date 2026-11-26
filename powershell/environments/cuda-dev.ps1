# =============================================================================
# CUDA 开发环境初始化
# =============================================================================

# 01. 读取本机配置与环境预检
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

# 校验当前脚本所需字段
$requiredFields = @{
    MSVC  = @('Version')
    CUDA  = @('Root', 'TorchCudaArch')
    CUDNN = @('Root', 'RuntimeSubDir')
}

$invalidConfig = $false
foreach ($section in $requiredFields.Keys) {
    if ($config[$section] -isnot [System.Collections.IDictionary]) {
        Write-Host "[ERROR] Missing or invalid configuration section: $section" -ForegroundColor Red
        $invalidConfig = $true
        continue
    }
    foreach ($field in $requiredFields[$section]) {
        $value = $config[$section][$field]
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
            Write-Host "[ERROR] Missing or invalid configuration field: $section.$field" -ForegroundColor Red
            $invalidConfig = $true
        }
    }
}
if ($invalidConfig) {
    Write-Host "  Check configuration: $configPath"
    return
}

$cudaRoot = $config.CUDA.Root
$cudnnRoot = $config.CUDNN.Root
$msvcVersion = $config.MSVC.Version
$msvcVersionPattern = '^' + [regex]::Escape($msvcVersion) + '(\.|$)'

# 根据配置生成派生路径
try {
    $cudnnBin = Join-Path $cudnnRoot $config.CUDNN.RuntimeSubDir -ErrorAction Stop
    $nvccPath = Join-Path $cudaRoot 'bin\nvcc.exe' -ErrorAction Stop
}
catch {
    Write-Host "[ERROR] Invalid toolchain path: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Check configuration: $configPath"
    return
}

$cudaUrl = 'https://developer.nvidia.com/cuda-downloads'
$cudnnUrl = 'https://developer.nvidia.com/cudnn'

# 检查配置路径，不自动安装或搜索其他版本
$checks = @(
    @{ Name = 'CUDA Toolkit'; Path = $cudaRoot; Type = 'Container'; Url = $cudaUrl }
    @{ Name = 'NVCC compiler'; Path = $nvccPath; Type = 'Leaf'; Url = $cudaUrl }
    @{ Name = 'cuDNN'; Path = $cudnnRoot; Type = 'Container'; Url = $cudnnUrl }
    @{ Name = 'cuDNN runtime directory'; Path = $cudnnBin; Type = 'Container'; Url = $cudnnUrl }
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

if (-not $missing -and -not (Get-ChildItem -LiteralPath $cudnnBin -Filter 'cudnn*.dll' -File -ErrorAction SilentlyContinue)) {
    Write-Host '[ERROR] cuDNN runtime DLLs not found.' -ForegroundColor Red
    Write-Host "  Expected: $cudnnBin"
    Write-Host "  Install or repair: $cudnnUrl"
    $missing = $true
}

if ($missing) {
    Write-Host '[ERROR] CUDA development environment initialization aborted. Check the paths above.' -ForegroundColor Red
    return
}

# 检查并按需初始化 MSVC
if ($env:VCToolsVersion -notmatch $msvcVersionPattern -or
    -not (Get-Command cl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    $msvcScript = Join-Path $PSScriptRoot 'msvc-dev.ps1'
    if (-not (Test-Path -LiteralPath $msvcScript -PathType Leaf)) {
        Write-Host "[ERROR] MSVC initialization script not found: $msvcScript" -ForegroundColor Red
        return
    }
    & $msvcScript
}

# 验证依赖初始化结果
if ($env:VCToolsVersion -notmatch $msvcVersionPattern -or
    -not (Get-Command cl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] CUDA initialization aborted: MSVC $msvcVersion is unavailable." -ForegroundColor Red
    return
}

# 02. CUDA Toolkit
$env:CUDA_PATH = $cudaRoot
$env:CUDA_HOME = $cudaRoot
$env:CUDACXX = $nvccPath

# NVIDIA / MSBuild 集成
$env:CudaToolkitDir = $cudaRoot

# 03. cuDNN
$env:CUDNN_ROOT_DIR = $cudnnRoot
$env:CUDNN = $env:CUDNN_ROOT_DIR
$env:CUDNN_PATH = $env:CUDNN_ROOT_DIR

# 04. 运行时 DLL 搜索路径
$env:PATH =
(Join-Path $cudaRoot 'bin') + ';' +
(Join-Path $cudaRoot 'bin\x64') + ';' +
$cudnnBin + ';' +
$env:PATH

# 05. PyTorch CUDA 扩展编译架构
# 从本机配置读取目标 GPU 架构
$env:TORCH_CUDA_ARCH_LIST = $config.CUDA.TorchCudaArch

# 06. 环境信息与版本检查
Write-Host ('CUDA_PATH      = ' + $env:CUDA_PATH)
Write-Host ('CUDACXX        = ' + $env:CUDACXX)
Write-Host ('CUDNN_ROOT     = ' + $env:CUDNN_ROOT_DIR)

& $env:CUDACXX --version

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] NVCC version check failed. Exit code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "  Install or repair: $cudaUrl"
    return
}
