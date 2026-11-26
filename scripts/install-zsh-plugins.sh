#!/usr/bin/env bash
set -uo pipefail

PLUGIN_DIR="${HOME:?HOME is not set}/.local/share/zsh/plugins"
if ! command -v git >/dev/null 2>&1; then
    echo '[ERROR] git is required.' >&2
    exit 1
fi
mkdir -p "$PLUGIN_DIR" || exit 1
failed=()
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    target="$PLUGIN_DIR/$plugin"
    if [[ -r "$target/$plugin.zsh" ]]; then
        echo "[SKIP] $plugin already installed."
        continue
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        echo "[ERROR] Existing incomplete installation: $target" >&2
        failed+=("$plugin")
        continue
    fi
    echo "[INSTALL] $plugin"
    if ! git clone --depth=1 "https://github.com/zsh-users/$plugin.git" "$target" ||
        [[ ! -r "$target/$plugin.zsh" ]]; then
        failed+=("$plugin")
    fi
done
printf '[SUMMARY] Plugin failures: %s\n' "${failed[*]:-none}"
(( ${#failed[@]} == 0 ))
