# =============================================================================
# Zsh 公共交互配置
# =============================================================================

[[ -o interactive ]] || return 0

# 01. 基础环境与启动计时
# -----------------------------------------------------------------------------
zmodload zsh/datetime 2>/dev/null
_dotfiles_start_time=${EPOCHREALTIME:-$SECONDS}

# 解析实际配置文件位置，支持 source 和符号链接
typeset -g DOTFILES_ZSHRC="${${(%):-%N}:A}"
typeset -g DOTFILES_ROOT="${DOTFILES_ZSHRC:h:h}"

# 仅当前 Shell 保存启动状态，不传给子 Shell
if [[ -z ${_dotfiles_zsh_started:-} ]]; then
    typeset -g _dotfiles_first_start=1
    typeset -g _dotfiles_zsh_started=1
    if [[ -t 1 && ${TERM:-dumb} != dumb ]] && (( $+commands[clear] )); then
        clear
    fi
else
    typeset -g _dotfiles_first_start=0
fi

_dotfiles_warn() {
    print -ru2 -- "[WARNING] $*"
}

# 按依赖顺序加载模块；local.zsh 是可选的机器专属配置。
for _dotfiles_module in \
    core local history completion keybindings tools aliases functions wsl \
    prompt startup plugins
do
    _dotfiles_module_path="$DOTFILES_ROOT/zsh/config/$_dotfiles_module.zsh"
    if [[ -r "$_dotfiles_module_path" ]]; then
        source "$_dotfiles_module_path" ||
            _dotfiles_warn "Configuration returned an error: $_dotfiles_module_path"
    elif [[ $_dotfiles_module != local ]]; then
        _dotfiles_warn "Configuration module not found: $_dotfiles_module_path"
    fi
done
unset _dotfiles_module _dotfiles_module_path

# 启动耗时（包含 Fastfetch 与插件加载）
_dotfiles_elapsed=$(( (${EPOCHREALTIME:-$SECONDS} - _dotfiles_start_time) * 1000.0 ))
printf '\n>>> Total Profile Load Time: %.0f ms\n' "$_dotfiles_elapsed"

# 清理临时变量
unset _dotfiles_start_time _dotfiles_elapsed _dotfiles_first_start
unset _dotfiles_cache _dotfiles_init _dotfiles_kernel _dotfiles_fastfetch_config _dotfiles_plugin_path
return 0
