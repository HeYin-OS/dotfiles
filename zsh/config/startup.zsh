# 10. 启动信息
# -----------------------------------------------------------------------------
# 每个新交互 Shell 显示一次，reload 时不重复
if (( _dotfiles_first_start )); then
    if (( $+commands[fastfetch] )); then
        if [[ -t 1 && ${TERM:-dumb} != dumb ]]; then
            _dotfiles_fastfetch_config="$DOTFILES_ROOT/fastfetch/config.jsonc"
            if [[ -r "$_dotfiles_fastfetch_config" && -f "$_dotfiles_fastfetch_config" ]]; then
                fastfetch --config "$_dotfiles_fastfetch_config" ||
                    _dotfiles_warn 'Fastfetch execution failed.'
            else
                _dotfiles_warn "Fastfetch configuration not found: $_dotfiles_fastfetch_config. Using default configuration."
                fastfetch || _dotfiles_warn 'Fastfetch execution failed.'
            fi
        fi
    else
        _dotfiles_warn 'Fastfetch is not available in PATH. Install: https://github.com/fastfetch-cli/fastfetch'
    fi
fi
