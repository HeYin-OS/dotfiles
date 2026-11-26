# PowerShell 环境配置

Windows / PowerShell 7 的日常 Shell、MSVC 与 CUDA 开发环境。安装、配置和初始化相互独立。

## 1. 手动安装

- [PowerShell 7](https://github.com/PowerShell/PowerShell)：使用 Microsoft Store 或 `winget install --id Microsoft.PowerShell --exact`。
- [Windows Terminal](https://aka.ms/terminal)：使用 Microsoft Store 或 `winget install --id Microsoft.WindowsTerminal --exact`。
- [WinGet / App Installer](https://aka.ms/getwinget)：若系统没有 `winget`，可先从 Microsoft Store 安装或更新 App Installer。安装脚本也会尝试自动修复 WinGet。
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/)：仅 C/C++ 或 CUDA 开发需要。安装 Desktop development with C++、所需 MSVC x64/x86 工具集及 Windows SDK。
- [CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit-archive) 与 [cuDNN](https://developer.nvidia.com/cudnn)：仅 CUDA 开发需要。选择与宿主编译器、GPU 及项目兼容的版本。

WinGet 安装或修复的备用方法（PowerShell 7）：

```powershell
Install-Module Microsoft.WinGet.Client -Repository PSGallery -Scope CurrentUser
Import-Module Microsoft.WinGet.Client
Repair-WinGetPackageManager
```

确认 `winget --version` 可正常执行。普通 Shell 不需要安装 MSVC、CUDA 或 cuDNN。

## 2. 自动安装基础依赖

在非管理员 PowerShell 7 中执行：

```powershell
cd "$HOME/dotfiles"
.\scripts\install.ps1 -CheckOnly
.\scripts\install.ps1
```

默认检测并安装 WinGet、Scoop、Git、Oh My Posh、Zoxide、Fastfetch、Emacs、PSReadLine、Terminal-Icons 和 JetBrainsMono Nerd Font。已有依赖会跳过，不主动升级。

安装完成后重新打开终端，再运行 `-CheckOnly` 检查结果。如 Scoop 安装受执行策略限制，参考 [Scoop 官方安装说明](https://scoop.sh/)；不要为此关闭系统级安全限制。

## 3. 配置本机开发工具链

```powershell
.\scripts\configure.ps1
```

首次执行时，从 `powershell/config/toolchain.example.psd1` 创建 `toolchain.local.psd1`；已有本地配置不会被模板覆盖。按需选择菜单中的 MSVC、CUDA 或 cuDNN 配置，确认检测结果及版本后保存。

- MSVC：通过 vswhere 检测 Visual Studio 实例，扫描已安装的 MSVC 版本，支持手动指定路径。
- CUDA：检测 Toolkit 路径、版本与 GPU 计算架构。
- cuDNN：指定安装根目录，检测版本与 DLL 所在目录。
- 选择 `[6] Validate configuration` 检查配置。通过检查不等于已通过实际编译测试。

只使用普通 Shell 时可跳过本步骤。请勿将 `*.local.psd1` 提交到 Git。

## 4. Windows Terminal 启动配置

在 Windows Terminal 设置中创建或修改对应 Profile 的 **Command line（命令行）**。

以下命令假设仓库位于 `$HOME/dotfiles`。

且 `pwsh.exe`（旧版powershell）或  `"X:\Users\YYY\AppData\Local\Microsoft\WindowsApps\Microsoft.PowerShell_8wekyb3d8bbwe\pwsh.exe"`（新版powershell）可用。

### 普通 PowerShell

```text
pwsh.exe -NoExit -NoProfile -Command ". (Join-Path $HOME 'dotfiles/powershell/profile.ps1')"
```

### MSVC 开发环境

```text
pwsh.exe -NoExit -NoProfile -Command ". (Join-Path $HOME 'dotfiles/powershell/profile.ps1'); . (Join-Path $HOME 'dotfiles-HeYinKazune/powershell/environments/msvc-dev.ps1')"
```

### CUDA 开发环境

```text
pwsh.exe -NoExit -NoProfile -Command ". (Join-Path $HOME 'dotfiles/powershell/profile.ps1'); . (Join-Path $HOME 'dotfiles-HeYinKazune/powershell/environments/cuda-dev.ps1')"
```

CUDA 脚本会按需初始化 MSVC。`-NoProfile` 避免重复加载默认 Profile；Dot Sourcing (`.`) 将配置加载到当前 Shell。若 `pwsh.exe` 无法定位，可替换为本机 PowerShell 7 的完整可执行文件路径（使用双引号包围）。

在 Windows Terminal 的 Appearance（外观）中选择 `JetBrainsMono Nerd Font`（或实际安装的对应 Mono 字体）。主题文件由 Profile 从仓库的 `oh-my-posh/default.json` 加载。

测试：MSVC 终端运行 `cl`，CUDA 终端运行 `nvcc --version`。

## 5. 与powershell有关的文件结构

```text
dotfiles/
├── powershell/
│   ├── README.md
│   ├── profile.ps1
│   ├── config/
│   │   ├── toolchain.example.psd1
│   │   └── toolchain.local.psd1   # 本机配置，不提交
│   └── environments/
│       ├── msvc-dev.ps1
│       └── cuda-dev.ps1
├── oh-my-posh/
│   └── default.json
└── scripts/
    ├── install.ps1
    └── configure.ps1
```

仓库根目录 `.gitignore` 包含：

```gitignore
*.local.psd1
```

日常维护直接修改仓库中的配置，重新打开终端即可生效。更换工具链路径或版本时，重新执行 `configure.ps1`。
