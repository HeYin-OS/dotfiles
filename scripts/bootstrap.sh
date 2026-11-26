#!/usr/bin/env bash
set -uo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P) || exit 1
export PATH="${HOME:?HOME is not set}/.local/bin:$PATH"
failed=()
for script in install-cli-tools.sh install-zsh-plugins.sh link-configs.sh; do
    printf '\n===== %s =====\n' "$script"
    if ! bash "$ROOT/scripts/$script"; then failed+=("$script"); fi
done
if (( ${#failed[@]} )); then
    printf '\n[ERROR] Failed stages: %s\n' "${failed[*]}" >&2
    echo '[INFO] Correct the errors and rerun bootstrap.sh; completed components are skipped.'
    exit 1
fi
printf '\n[DONE] Start Zsh with: %s\n' "$HOME/.local/bin/zsh"
echo '[INFO] Login shell and system configuration have not been changed.'
