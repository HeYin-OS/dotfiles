# WSL：仅在 WSL 中提供 Windows 互操作函数
_dotfiles_kernel=''
[[ -r /proc/sys/kernel/osrelease ]] && _dotfiles_kernel="$(</proc/sys/kernel/osrelease)"
if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} || ${_dotfiles_kernel:l} == *microsoft* ]]; then
    open() {
        local target="${1:-.}" winpath
        if ! (( $+commands[explorer.exe] && $+commands[wslpath] )); then
            _dotfiles_warn 'Windows Explorer or wslpath is unavailable.'
            return 1
        fi
        winpath="$(wslpath -a -w "$target")" || return 1
        explorer.exe "$winpath" >/dev/null 2>&1
        # Explorer 正常启动时也可能返回非零状态
        return 0
    }

    cpath() {
        local target="${1:-$PWD}" winpath
        if ! (( $+commands[wslpath] && $+commands[clip.exe] )); then
            _dotfiles_warn 'wslpath or clip.exe is unavailable.'
            return 1
        fi
        winpath="$(wslpath -a -w "$target")" || return 1
        if print -rn -- "$winpath" | clip.exe; then
            print -r -- "Copied: $winpath"
        else
            _dotfiles_warn 'Unable to copy the Windows path.'
            return 1
        fi
    }
fi
