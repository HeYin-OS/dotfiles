# Zsh

模块化 Zsh 配置，适用于 Ubuntu、WSL 和 Linux 服务器（x86_64 / aarch64）。
所有目标工具和插件均安装在当前用户的 `$HOME/.local/` 下，不修改系统默认 Shell。

## 1. 安装与部署

在 **Bash** 中进入 dotfiles 仓库根目录（以下假设仓库位于 `~/dotfiles`，请按实际路径调整）：

```bash
cd "$HOME/dotfiles"
bash scripts/bootstrap.sh
```

`bootstrap.sh` 是统一入口，依次执行：

| 脚本 | 职责 |
| --- | --- |
| `install-cli-tools.sh` | 安装 Zsh、Starship、Fastfetch、Zoxide、eza、bat等CLI工具 |
| `install-zsh-plugins.sh` | 安装 zsh插件 |

安装需要 Git、curl、Python 3 等基础工具。Zsh 源码编译还需要 C 编译器、make 和 ncurses 开发库。

若缺少编译环境，可由管理员按需安装 `build-essential` 和 `libncurses-dev`。

## 2. 配置文件及安装位置

```text
$HOME/.local/bin/                      # Zsh 与 CLI 工具
$HOME/.local/share/zsh/plugins/        # Zsh 插件
```

## 3. 手动启动 Zsh

安装完成后，继续保留 Bash，不执行 `chsh`，也不在 Bash 启动时自动执行 Zsh。

直接使用已部署的 `~/.zshrc`：

```bash
"$HOME/.local/bin/zsh" -i
```

显式指定仓库里的 `.zshrc`，无需依赖 `~/.zshrc` 的软链接：

```bash
ZDOTDIR="$HOME/dotfiles/zsh" "$HOME/.local/bin/zsh" -i
```

## 4. 配置Zsh启动函数

在 Bash 中加入 `~/.bashrc`。不需要另外创建 `.sh` 文件。

```bash
# Launch Zsh with standalone dotfiles configuration.
start_zsh() {
    local zsh_bin="$HOME/.local/bin/zsh"
    local zsh_config="$HOME/dotfiles/zsh"

    if [[ ! -x "$zsh_bin" ]]; then
        printf '[ERROR] Zsh is not installed.\n' >&2
        return 1
    fi

    if [[ ! -r "$zsh_config/.zshrc" ]]; then
        printf '[ERROR] Configuration not found: %s\n' \
            "$zsh_config/.zshrc" >&2
        return 1
    fi

    ZDOTDIR="$zsh_config" "$zsh_bin" -i "$@"
}
```

重新加载：

```bash
source "$HOME/.bashrc"
```

使用 Zsh 时：

```bash
start_zsh
```

## 5. 与Zsh有关的文件结构

```text
dotfiles/
├── zsh/        # .zshrc 与 .zsh 脚本
├── starship/   # Zsh prompt 主题配置文件
├── fastgetch/  # fastfetch 配置文件
└── scripts/    # .sh 安装与部署脚本
```
