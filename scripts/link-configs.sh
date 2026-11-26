#!/usr/bin/env bash
# Link the existing repository configuration; do not edit its contents.
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
: "${HOME:?HOME is not set}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
failed=0

link_config() {
    local src="$1" dst="$2" backup
    if [[ ! -f "$src" ]]; then
        printf '[ERROR] Missing source: %s\n' "$src" >&2
        return 1
    fi
    mkdir -p -- "$(dirname -- "$dst")" || return 1
    if [[ -L "$dst" && "$dst" -ef "$src" ]]; then
        printf '[SKIP] %s already linked.\n' "$dst"
        return 0
    fi
    if [[ -d "$dst" && ! -L "$dst" ]]; then
        printf '[ERROR] Refusing to replace directory: %s\n' "$dst" >&2
        return 1
    fi
    backup=''
    if [[ -e "$dst" || -L "$dst" ]]; then
        # Reserve a unique backup name, then move the old entry there.
        backup=$(mktemp -- "$dst.backup.XXXXXXXX") || return 1
        if ! mv -T -- "$dst" "$backup"; then
            rm -f -- "$backup"
            return 1
        fi
        printf '[BACKUP] %s -> %s\n' "$dst" "$backup"
    fi
    if ! ln -sT -- "$src" "$dst"; then
        if [[ -n $backup && ! -e $dst && ! -L $dst ]]; then
            mv -T -- "$backup" "$dst" || echo "[ERROR] Restore manually: $backup" >&2
        fi
        return 1
    fi
    printf '[LINK] %s -> %s\n' "$dst" "$src"
}

link_config "$ROOT/zsh/.zshrc" "$HOME/.zshrc" || failed=1
# Zsh's existing configuration refers to these files in the repository directly;
# the extra links also make them discoverable when CLI tools run outside Zsh.
link_config "$ROOT/starship/starship.toml" "$CONFIG_DIR/starship.toml" || failed=1
link_config "$ROOT/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc" || failed=1
exit "$failed"
