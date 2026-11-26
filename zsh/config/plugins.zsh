# 11. Zsh 插件（语法高亮最后加载）
# -----------------------------------------------------------------------------
# 优先用户级目录，兼容旧目录和系统包安装位置
_dotfiles_find_plugin() {
    local plugin="$1" candidate
    local -a candidates
    candidates=(
        "$HOME/.local/share/zsh/plugins/$plugin/$plugin.zsh"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -r "$candidate" ]]; then
            typeset -g _dotfiles_plugin_path="$candidate"
            return 0
        fi
    done
    _dotfiles_warn "$plugin not found. Install: https://github.com/zsh-users/$plugin"
    return 1
}

# 已加载插件不重复 source，避免重复注册 hooks
if [[ -z ${_dotfiles_autosuggestions_loaded:-} ]]; then
    if _dotfiles_find_plugin zsh-autosuggestions; then
        if source "$_dotfiles_plugin_path"; then
            typeset -g _dotfiles_autosuggestions_loaded=1
        else
            _dotfiles_warn "Unable to load plugin: $_dotfiles_plugin_path"
        fi
    fi
fi

if [[ -z ${_dotfiles_highlighting_loaded:-} ]]; then
    if _dotfiles_find_plugin zsh-syntax-highlighting; then
        if source "$_dotfiles_plugin_path"; then
            typeset -g _dotfiles_highlighting_loaded=1
        else
            _dotfiles_warn "Unable to load plugin: $_dotfiles_plugin_path"
        fi
    fi
fi
