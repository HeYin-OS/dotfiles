# 07. Aliases
# -----------------------------------------------------------------------------
# eza 缺失时回退到系统 ls
if (( $+commands[eza] )); then
    alias ls='eza'
    alias l='eza'
    alias ll='eza -lah --group-directories-first'
    alias la='eza -a'
    alias lt='eza --tree --level=2'
    alias tree='eza --tree'
else
    alias ls='ls --color=auto'
    alias l='ls -CF'
    alias ll='ls -alF'
    alias la='ls -A'
    unalias lt tree 2>/dev/null
    if (( $+commands[tree] )); then
        alias lt='tree -L 2'
    fi
    _dotfiles_warn 'eza is not available in PATH. Using ls. Install: https://github.com/eza-community/eza'
fi

# 兼容 Debian / Ubuntu 的命令名称
unalias bat 2>/dev/null
if (( ! $+commands[bat] )); then
    if (( $+commands[batcat] )); then
        alias bat='batcat'
    else
        _dotfiles_warn 'bat is not available in PATH. Install: https://github.com/sharkdp/bat'
    fi
fi

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'
alias h='history'
