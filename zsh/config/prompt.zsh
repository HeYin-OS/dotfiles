# 09. Starship
# -----------------------------------------------------------------------------
export STARSHIP_CONFIG="$DOTFILES_ROOT/starship/starship.toml"

# 主题缺失时使用基础提示符
PROMPT='%F{cyan}%n%f@%F{yellow}%m%f:%F{blue}%~%f$ '
if (( $+commands[starship] )); then
    if [[ -r "$STARSHIP_CONFIG" ]]; then
        if _dotfiles_init="$(starship init zsh)" && [[ -n $_dotfiles_init ]]; then
            eval "$_dotfiles_init" || _dotfiles_warn 'Starship initialization failed.'
        else
            _dotfiles_warn 'Unable to generate Starship initialization.'
        fi
    else
        _dotfiles_warn "Starship configuration not found: $STARSHIP_CONFIG"
    fi
else
    _dotfiles_warn 'Starship is not available in PATH. Install: https://starship.rs/guide/'
fi
