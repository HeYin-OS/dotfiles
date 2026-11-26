# =============================================================================
# 本机工具链配置（Windows / PowerShell 7）
# =============================================================================
if (-not $IsWindows) { Write-Warning 'This script requires Windows PowerShell 7 (pwsh).'; return }
$configDir = Join-Path $PSScriptRoot '../powershell/config'
$examplePath = Join-Path $configDir 'toolchain.example.psd1'
$localPath = Join-Path $configDir 'toolchain.local.psd1'
$fields = [ordered]@{
    MSVC  = @('Root', 'InstanceId', 'Version', 'TargetArch', 'HostArch', 'Language')
    CUDA  = @('Root', 'Version', 'TorchCudaArch')
    CUDNN = @('Root', 'Version', 'RuntimeSubDir')
}

# 01. 初始化本地配置
try {
    if (-not (Test-Path -LiteralPath $localPath -PathType Leaf)) {
        $null = Import-PowerShellDataFile -LiteralPath $examplePath -ErrorAction Stop
        Copy-Item -LiteralPath $examplePath -Destination $localPath -ErrorAction Stop
        Write-Host '[OK] Local configuration created from template. Values are not yet verified.' -ForegroundColor Green
    }
    $config = Import-PowerShellDataFile -LiteralPath $localPath -ErrorAction Stop
    foreach ($section in $fields.Keys) {
        if ($config[$section] -isnot [System.Collections.IDictionary]) { throw "Invalid section: $section" }
        foreach ($field in $fields[$section]) {
            if ($config[$section][$field] -isnot [string]) { throw "Missing or invalid field: $section.$field" }
        }
    }
}
catch { Write-Warning "Cannot load configuration: $_"; return }

# 02. 通用交互与安全保存
function Read-Value($Label, $Default) {
    $value = Read-Host "$Label [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return [string]$Default }
    return $value.Trim()
}
function Read-Root($Label, $Default) {
    $value = (Read-Value $Label $Default).Trim('"')
    if ($value -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\]+\\[^\\]+)') { throw 'Enter a complete absolute Windows path.' }
    return [IO.Path]::GetFullPath($value)
}
function Select-Item($Label, [array]$Items, [int]$Default = 0) {
    for ($i = 0; $i -lt $Items.Count; $i++) { Write-Host "[$($i+1)] $($Items[$i])" }
    Write-Host '[M] Enter manually'
    while ($true) {
        $choice = Read-Host "$Label [$($Default+1)]"
        if ($choice -eq 'M') { return -1 }
        if (-not $choice) { return $Default }
        $n = 0
        if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) { return ($n - 1) }
        Write-Warning 'Invalid selection.'
    }
}
function Copy-Config($Data) {
    $copy = @{}
    foreach ($section in $Data.Keys) { $copy[$section] = $Data[$section].Clone() }
    return $copy
}
function Save-Config($Data) {
    # 保留额外字符串字段，拒绝不支持的数据类型，避免静默丢失
    $lines = @('@{')
    $sections = @($fields.Keys) + @($Data.Keys | Where-Object { $_ -notin $fields.Keys } | Sort-Object)
    foreach ($section in $sections) {
        if ($section -notmatch '^\w+$' -or $Data[$section] -isnot [System.Collections.IDictionary]) { throw "Unsupported section: $section" }
        $lines += "    # $section"
        $lines += "    $section = @{"
        $keys = @($fields[$section] | Where-Object { $_ }) + @($Data[$section].Keys | Where-Object { $_ -notin $fields[$section] } | Sort-Object)
        foreach ($key in $keys) {
            $v = $Data[$section][$key]
            if ($key -notmatch '^\w+$' -or $v -isnot [string]) { throw "Unsupported field: $section.$key" }
            $lines += "        $key = '" + $v.Replace("'", "''") + "'"
        }
        $lines += '    }'
        $lines += ''
    }
    $lines += '}'
    $tmp = Join-Path $configDir ('.toolchain-' + [guid]::NewGuid().ToString('N') + '.psd1')
    try {
        Set-Content -LiteralPath $tmp -Value $lines -Encoding utf8 -ErrorAction Stop
        $null = Import-PowerShellDataFile -LiteralPath $tmp -ErrorAction Stop
        $backup = Join-Path $configDir ('.toolchain-' + [guid]::NewGuid().ToString('N') + '.bak')
        [IO.File]::Replace($tmp, $localPath, $backup)
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        Write-Host '[OK] Configuration saved.' -ForegroundColor Green
    }
    finally { if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force } }
}

# 03. Visual Studio 实例与 MSVC 版本
function Get-VsInstances {
    $cmd = Get-Command vswhere.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $exe = if ($cmd) { $cmd.Source } else { Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe' }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { return }
    # 显式按 UTF-8 解码，避免本地化描述导致解析失败
    $oldEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        try {
            $json = & $exe -products '*' -all -prerelease -format json -utf8
            if ($LASTEXITCODE -ne 0) { throw "vswhere exit code: $LASTEXITCODE" }
            $instances = @(($json -join "`n") | ConvertFrom-Json -ErrorAction Stop)
            $instances | Where-Object { $_.installationPath -and $_.instanceId } |
            Select-Object instanceId, installationPath, installationVersion, displayName
            return
        }
        catch {
            # JSON 无效时，回退到文本格式，仅提取必要字段
            $lines = & $exe -products '*' -all -prerelease -format text -nologo -utf8
            if ($LASTEXITCODE -ne 0) { throw "vswhere text query failed: $LASTEXITCODE" }
            $rows = @()
            $row = $null
            foreach ($line in $lines) {
                if ($line -match '^instanceId:\s*(.+)$') {
                    if ($row -and $row.installationPath -and $row.instanceId) { $rows += [pscustomobject]$row }
                    $row = @{ instanceId = $Matches[1].Trim(); installationPath = ''; installationVersion = ''; displayName = '' }
                }
                elseif ($null -ne $row -and $line -match '^(installationPath|installationVersion|displayName):\s*(.*)$') {
                    $row[$Matches[1]] = $Matches[2].Trim()
                }
            }
            if ($row -and $row.installationPath -and $row.instanceId) { $rows += [pscustomobject]$row }
            if (-not $rows.Count -and ($lines -join '').Trim()) { throw 'No valid instance records found in vswhere text output.' }
            $rows
        }
    }
    catch { Write-Warning "vswhere detection failed: $_" }
    finally { [Console]::OutputEncoding = $oldEncoding }
}
function Configure-MSVC($Data) {
    $c = $Data.MSVC
    $instances = @(Get-VsInstances | Where-Object { Test-Path -LiteralPath (Join-Path $_.installationPath 'VC/Tools/MSVC') -PathType Container })
    $selected = $null
    if ($instances.Count) {
        $labels = @($instances | ForEach-Object { "$($_.displayName) | $($_.installationVersion) | $($_.installationPath)" })
        $idx = 0
        for ($i = 0; $i -lt $instances.Count; $i++) { if ($instances[$i].installationPath -eq $c.Root) { $idx = $i; break } }
        $pick = Select-Item 'Visual Studio instance' $labels $idx
        if ($pick -ge 0) { $selected = $instances[$pick] }
    }
    $oldRoot = $c.Root
    if ($selected) { $c.Root = $selected.installationPath } else { $c.Root = Read-Root 'Visual Studio installation root' $c.Root }
    $match = $instances | Where-Object { $_.installationPath.TrimEnd([char[]]'\/') -eq $c.Root.TrimEnd([char[]]'\/') } | Select-Object -First 1
    if ($match) { $c.InstanceId = [string]$match.instanceId; Write-Host "[Detected] Instance ID: $($c.InstanceId)" }
    else { $c.InstanceId = Read-Value 'Visual Studio instance ID' $(if ($oldRoot -eq $c.Root) { $c.InstanceId } else { '' }) }
    $c.HostArch = Read-Value 'Host architecture' $c.HostArch
    $c.TargetArch = Read-Value 'Target architecture' $c.TargetArch
    if ($c.HostArch -notin @('x86', 'x64', 'arm64') -or $c.TargetArch -notin @('x86', 'x64', 'arm', 'arm64')) { throw 'Unsupported MSVC architecture.' }
    $compiler = "bin/Host$($c.HostArch)/$($c.TargetArch)/cl.exe"
    $versions = @(Get-ChildItem -LiteralPath (Join-Path $c.Root 'VC/Tools/MSVC') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+\.\d+(\.\d+){0,2}$' -and (Test-Path -LiteralPath (Join-Path $_.FullName $compiler) -PathType Leaf) } | Sort-Object { [version]$_.Name } -Descending | Select-Object -ExpandProperty Name)
    $defaultFile = Join-Path $c.Root 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt'
    $defaultVersion = if (Test-Path -LiteralPath $defaultFile -PathType Leaf) { (Get-Content -LiteralPath $defaultFile -Raw).Trim() } else { '' }
    if ($versions.Count) {
        $pattern = '^' + [regex]::Escape($c.Version) + '(\.|$)'
        $idx = 0
        for ($i = 0; $i -lt $versions.Count; $i++) { if ($versions[$i] -eq $defaultVersion) { $idx = $i; break } }
        for ($i = 0; $i -lt $versions.Count; $i++) { if ($versions[$i] -match $pattern) { $idx = $i; break } }
        $labels = @($versions | ForEach-Object { $v = $_; $tag = if ($v -eq $defaultVersion) { ' (VS default)' } else { '' }; if ($v -match $pattern) { $tag += ' (current series)' }; "$v$tag" })
        $pick = Select-Item 'MSVC toolchain' $labels $idx
        if ($pick -ge 0) {
            $full = $versions[$pick]; $prefix = ($full.Split('.')[0..1] -join '.')
            $c.Version = Read-Value "Version to save (series or full: $full)" $prefix
        }
        else { $c.Version = Read-Value 'MSVC version' $c.Version }
    }
    else { Write-Warning 'No matching cl.exe found. Manual configuration is unverified.'; $c.Version = Read-Value 'MSVC version' $c.Version }
    $c.Language = Read-Value 'Output language (LCID)' $c.Language
    if ($c.Version -notmatch '^\d+\.\d+(\.\d+){0,2}$' -or $c.Language -notmatch '^\d+$') { throw 'Invalid MSVC version or language.' }
}

# 04. CUDA 路径、版本与 GPU 架构
function Configure-CUDA($Data) {
    $c = $Data.CUDA
    $roots = @($c.Root, $env:CUDA_PATH)
    $roots += @(Get-ChildItem Env:CUDA_PATH_V* -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value)
    $nvcc = Get-Command nvcc.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($nvcc) { $roots += Split-Path (Split-Path $nvcc.Source -Parent) -Parent }
    $standard = Join-Path $env:ProgramFiles 'NVIDIA GPU Computing Toolkit/CUDA'
    $roots += @(Get-ChildItem -LiteralPath $standard -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $roots = @($roots | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'bin/nvcc.exe') -PathType Leaf) } | Select-Object -Unique)
    $pick = if ($roots.Count) { Select-Item 'CUDA installation' $roots } else { -1 }
    if ($pick -ge 0) { $c.Root = $roots[$pick] } else { $c.Root = Read-Root 'CUDA installation root' $c.Root }
    $exe = Join-Path $c.Root 'bin/nvcc.exe'
    $detected = $null
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        $output = & $exe --version | Out-String
        if ($LASTEXITCODE -eq 0 -and $output -match 'release\s+(\d+\.\d+)') { $detected = $Matches[1]; Write-Host "[Detected] CUDA $detected" }
    }
    $c.Version = Read-Value 'CUDA version' $(if ($detected) { $detected } else { $c.Version })
    $smi = Get-Command nvidia-smi.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $caps = @()
    if ($smi) {
        $gpu = & $smi.Source '--query-gpu=name,compute_cap' '--format=csv,noheader' 2>$null
        if ($LASTEXITCODE -eq 0) {
            $gpu | ForEach-Object { Write-Host "[Detected GPU] $_" }
            $caps = @($gpu | ForEach-Object { if ($_ -match ',\s*(\d+\.\d+)\s*$') { $Matches[1] } } | Select-Object -Unique)
        }
    }
    $arch = if ($caps.Count) { $caps -join ';' } else { $c.TorchCudaArch }
    $c.TorchCudaArch = Read-Value 'TORCH_CUDA_ARCH_LIST (semicolon separated)' $arch
    if ($c.TorchCudaArch -notmatch '^\d+\.\d+(\+PTX)?([; ]+\d+\.\d+(\+PTX)?)*$') { throw 'Invalid CUDA architecture list.' }
}

# 05. cuDNN 路径、版本头文件与 DLL
function Configure-CUDNN($Data) {
    $c = $Data.CUDNN
    $c.Root = Read-Root 'cuDNN installation root' $c.Root
    $headers = @(Get-ChildItem -LiteralPath $c.Root -Filter 'cudnn_version.h' -File -Recurse -ErrorAction SilentlyContinue)
    $versions = @($headers | ForEach-Object {
            $txt = Get-Content -LiteralPath $_.FullName -Raw
            if ($txt -match '(?m)^\s*#\s*define\s+CUDNN_MAJOR\s+(\d+)') { $major = $Matches[1] } else { return }
            if ($txt -match '(?m)^\s*#\s*define\s+CUDNN_MINOR\s+(\d+)') { $minor = $Matches[1] } else { return }
            if ($txt -match '(?m)^\s*#\s*define\s+CUDNN_PATCHLEVEL\s+(\d+)') { "$major.$minor.$($Matches[1])" } else { "$major.$minor" }
        } | Select-Object -Unique)
    $v = $c.Version
    if ($versions.Count -eq 1) { $v = $versions[0]; Write-Host "[Detected] cuDNN $v" }
    elseif ($versions.Count -gt 1) { $p = Select-Item 'cuDNN version' $versions; if ($p -ge 0) { $v = $versions[$p] } }
    $c.Version = Read-Value 'cuDNN version' $v
    $dirs = @(Get-ChildItem -LiteralPath $c.Root -Filter 'cudnn*.dll' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object { [IO.Path]::GetRelativePath($c.Root, $_.DirectoryName) } | Select-Object -Unique)
    if ($dirs.Count) {
        $idx = 0
        for ($i = 0; $i -lt $dirs.Count; $i++) { if ($dirs[$i] -eq $c.RuntimeSubDir) { $idx = $i; break } }
        $p = Select-Item 'cuDNN runtime directory' $dirs $idx
        if ($p -ge 0) { $c.RuntimeSubDir = $dirs[$p] } else { $c.RuntimeSubDir = Read-Value 'Runtime subdirectory' $c.RuntimeSubDir }
    }
    else { Write-Warning 'No cuDNN DLLs found. Manual configuration is unverified.'; $c.RuntimeSubDir = Read-Value 'Runtime subdirectory' $c.RuntimeSubDir }
    if ([IO.Path]::IsPathRooted($c.RuntimeSubDir) -or $c.RuntimeSubDir -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Runtime subdirectory must remain relative to the cuDNN root.' }
}

# 06. 静态校验（不初始化环境）
function Test-Config($Data) {
    $m = $Data.MSVC; $c = $Data.CUDA; $d = $Data.CUDNN
    $msvcMatch = $false
    if ($m.Root -and $m.Version) {
        $pattern = '^' + [regex]::Escape($m.Version) + '(\.|$)'
        $msvcMatch = [bool](@(Get-ChildItem -LiteralPath (Join-Path $m.Root 'VC/Tools/MSVC') -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $pattern -and (Test-Path -LiteralPath (Join-Path $_.FullName "bin/Host$($m.HostArch)/$($m.TargetArch)/cl.exe") -PathType Leaf) }).Count)
    }
    $instances = @(Get-VsInstances)
    $idStatus = if (-not $instances.Count) { 'Unverified' } elseif ($m.Root -and @($instances | Where-Object { $_.instanceId -eq $m.InstanceId -and $_.installationPath.TrimEnd([char[]]'\/') -eq $m.Root.TrimEnd([char[]]'\/') }).Count) { 'OK' } else { 'Mismatch' }
    $checks = [ordered]@{
        'MSVC DevShell'         = [bool]($m.Root -and (Test-Path -LiteralPath (Join-Path $m.Root 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll') -PathType Leaf))
        'MSVC compiler/version' = $msvcMatch
        'CUDA nvcc'             = [bool]($c.Root -and (Test-Path -LiteralPath (Join-Path $c.Root 'bin/nvcc.exe') -PathType Leaf))
        'cuDNN runtime DLL'     = [bool]($d.Root -and $d.RuntimeSubDir -and @(Get-ChildItem -LiteralPath (Join-Path $d.Root $d.RuntimeSubDir) -Filter 'cudnn*.dll' -File -ErrorAction SilentlyContinue).Count)
    }
    $rows = @([pscustomobject]@{ Check = 'Visual Studio instance ID'; Status = $idStatus })
    foreach ($key in $checks.Keys) { $rows += [pscustomobject]@{ Check = $key; Status = $(if ($checks[$key]) { 'OK' } else { 'Missing / invalid' }) } }
    $rows | Format-Table -AutoSize | Out-Host
}

# 07. 交互菜单；确认后才写入修改
while ($true) {
    Clear-Host
    Write-Host "=== Toolchain Configuration ===" -ForegroundColor Cyan
    Write-Host "[1] Configure MSVC`n[2] Configure CUDA`n[3] Configure cuDNN`n[4] Configure all`n[5] Show configuration`n[6] Validate configuration`n[0] Exit"
    $choice = Read-Host 'Select an option'
    if ($choice -eq '0') { break }
    try {
        if ($choice -eq '5') { $config | ConvertTo-Json -Depth 8 | Out-Host; continue }
        if ($choice -eq '6') { Test-Config $config; continue }
        if ($choice -notin @('1', '2', '3', '4')) { Write-Warning 'Invalid option.'; continue }
        $draft = Copy-Config $config
        if ($choice -in @('1', '4')) { Configure-MSVC $draft }
        if ($choice -in @('2', '4')) { Configure-CUDA $draft }
        if ($choice -in @('3', '4')) { Configure-CUDNN $draft }
        Test-Config $draft
        $draft | ConvertTo-Json -Depth 8 | Out-Host
        if ((Read-Host 'Save configuration (including unverified values)? [y/N]') -eq 'y') { Save-Config $draft; $config = $draft }
        else { Write-Host 'Changes discarded.' }
    }
    catch { Write-Warning "Configuration failed: $_" }
    finally {
        # 保留操作结果，确认后清屏返回主菜单
        $null = Read-Host 'Press Enter to return to the main menu'
    }
}
