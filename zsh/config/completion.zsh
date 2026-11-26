# 04. 自动补全
# -----------------------------------------------------------------------------
autoload -Uz compinit
_dotfiles_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# 使用缓存，但每次仍执行安全检查；忽略不安全的补全目录
if mkdir -p -- "$_dotfiles_cache" 2>/dev/null; then
    compinit -i -d "$_dotfiles_cache/zcompdump-$ZSH_VERSION" ||
        _dotfiles_warn 'Zsh completion initialization failed.'
    zstyle ':completion:*' use-cache yes
    zstyle ':completion:*' cache-path "$_dotfiles_cache"
else
    _dotfiles_warn 'Completion cache directory is unavailable. Using uncached completion.'
    compinit -i -D || _dotfiles_warn 'Zsh completion initialization failed.'
    zstyle ':completion:*' use-cache no
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' verbose yes
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[-_.]=* r:|=*'
zstyle ':completion:*:descriptions' format '%F{green}[%d]%f'
zstyle ':completion:*' group-name ''

# uv shell completion
if (( $+commands[uv] )); then
    if _dotfiles_init="$(uv generate-shell-completion zsh)"; then
        eval "$_dotfiles_init" ||
            _dotfiles_warn "uv completion initialization failed."
    else
        _dotfiles_warn "Unable to generate uv completion."
    fi
fi

# uvx shell completion
if (( $+commands[uvx] )); then
    if _dotfiles_init="$(uvx --generate-shell-completion zsh)"; then
        eval "$_dotfiles_init" ||
            _dotfiles_warn "uvx completion initialization failed."
    else
        _dotfiles_warn "Unable to generate uvx completion."
    fi
fi

unset _dotfiles_init
