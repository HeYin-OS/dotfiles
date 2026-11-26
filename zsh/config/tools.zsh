# 06. CLI 工具初始化
# -----------------------------------------------------------------------------
# Zoxide：智能目录跳转
if (( $+commands[zoxide] )); then
    if _dotfiles_init="$(zoxide init zsh)" && [[ -n $_dotfiles_init ]]; then
        eval "$_dotfiles_init" || _dotfiles_warn 'Zoxide initialization failed.'
    else
        _dotfiles_warn 'Unable to generate Zoxide initialization.'
    fi
else
    _dotfiles_warn 'Zoxide is not available in PATH. Install: https://github.com/ajeetdsouza/zoxide'
fi
