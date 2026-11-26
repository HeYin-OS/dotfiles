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
| `link-configs.sh` | 备份已有配置并建立配置文件软链接 |

安装需要 Git、curl、Python 3 等基础工具。Zsh 源码编译还需要 C 编译器、make 和 ncurses 开发库。

若缺少编译环境，可由管理员按需安装 `build-essential` 和 `libncurses-dev`。

## 2. 配置文件及安装位置

```text
$HOME/.local/bin/                      # Zsh 与 CLI 工具
$HOME/.local/share/zsh/plugins/        # Zsh 插件
```

部署时自动建立下列软链接（`XDG_CONFIG_HOME` 未设置时默认为 `~/.config`）：

```text
~/.zshrc                      -> dotfiles/zsh/.zshrc
~/.config/starship.toml         -> dotfiles/starship/starship.toml
~/.config/fastfetch/config.jsonc -> dotfiles/fastfetch/config.jsonc
```

检查当前 `.zshrc` 指向：

```bash
readlink -f "$HOME/.zshrc"
```

单独链接 Zsh 配置，可在仓库根目录执行（目标不存在时才成功，不覆盖原文件）：

```bash
ln -s "$(pwd -P)/zsh/.zshrc" "$HOME/.zshrc"
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
# Launch user-local Zsh on demand; keep Bash as the parent shell.
start_zsh() {
    local zsh_bin="$HOME/.local/bin/zsh"

    if [[ ! -x "$zsh_bin" ]]; then
        printf '[ERROR] Zsh not installed: %s\n' "$zsh_bin" >&2
        return 1
    fi

    ZDOTDIR="$HOME" "$zsh_bin" -i "$@"
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
