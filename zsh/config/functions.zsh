# 08. 自定义函数
# -----------------------------------------------------------------------------
# 重载仓库配置，不重复清屏或显示 Fastfetch
unalias reload zshrc 2>/dev/null
alias reload='source "$DOTFILES_ZSHRC"'

# 编辑实际使用的仓库配置，默认使用 vi
zshrc() {
    if command -v "${EDITOR:-vi}" >/dev/null 2>&1; then
        command "${EDITOR:-vi}" "$DOTFILES_ZSHRC"
    elif (( $+commands[vi] )); then
        _dotfiles_warn 'Configured editor is unavailable. Using vi.'
        vi "$DOTFILES_ZSHRC"
    else
        _dotfiles_warn "No editor is available. Configuration: $DOTFILES_ZSHRC"
        return 1
    fi
}
