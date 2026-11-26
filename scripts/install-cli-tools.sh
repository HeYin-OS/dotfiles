#!/usr/bin/env bash
# Install the shell and CLI programs in the current user's home only.
set -uo pipefail

PREFIX="${HOME:?HOME is not set}/.local"
BIN_DIR="$PREFIX/bin"
export PATH="$BIN_DIR:$PATH"

case "$(uname -s):$(uname -m)" in
    Linux:x86_64) ARCH=x86_64; FF_ARCH=amd64 ;;
    Linux:aarch64|Linux:arm64) ARCH=aarch64; FF_ARCH=aarch64 ;;
    *) echo '[ERROR] Supported platforms: Linux x86_64 / aarch64.' >&2; exit 1 ;;
esac
mkdir -p "$BIN_DIR" || exit 1

need() {
    local cmd failed=0
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf '[ERROR] Missing prerequisite: %s\n' "$cmd" >&2
            failed=1
        fi
    done
    return "$failed"
}

download() {
    curl --fail --silent --show-error --location --retry 2 \
        --connect-timeout 15 --max-time 300 --output "$2" "$1"
}

# Verify the API-provided SHA-256 digest when available. An absent digest is
# reported explicitly; release assets are fetched only from upstream GitHub.
release_asset() {
    local repo="$1" pattern="$2" tmp="$3" meta url digest
    download "https://api.github.com/repos/$repo/releases/latest" "$tmp/release.json" || return 1
    meta=$(python3 - "$tmp/release.json" "$pattern" "$repo" <<'PY'
import json, re, sys
path, pattern, repo = sys.argv[1:]
with open(path) as f:
    release = json.load(f)
assets = [a for a in release['assets'] if re.fullmatch(pattern, a['name'])]
if len(assets) != 1:
    sys.exit(f'Expected exactly one matching release asset ({pattern}); found {len(assets)}')
a = assets[0]
url = a['browser_download_url']
if not url.startswith(f'https://github.com/{repo}/releases/download/'):
    sys.exit('Unexpected release asset URL')
print(url, a.get('digest') or '-', sep='\t')
PY
    ) || return 1
    IFS=$'\t' read -r url digest <<< "$meta"
    download "$url" "$tmp/archive.tar.gz" || return 1
    if [[ $digest =~ ^sha256:([0-9a-fA-F]{64})$ ]]; then
        printf '%s  %s\n' "${BASH_REMATCH[1]}" "$tmp/archive.tar.gz" | sha256sum -c - || return 1
    elif [[ $digest == '-' ]]; then
        echo '[WARN] Release API does not provide a checksum for this asset.' >&2
    else
        echo '[ERROR] Unsupported release digest.' >&2
        return 1
    fi
}

# Discover the newest stable source release from the official checksum index.
# Exclude development builds, documentation archives, and signature files.
latest_zsh_release() {
    local index="$1"
    awk 'length($1) == 64 && $1 ~ /^[[:xdigit:]]+$/ &&
        $2 ~ /^zsh-[0-9]+(\.[0-9]+)+\.tar\.xz$/ {print $1, $2}' "$index" |
        sort -k2,2V | tail -n 1
}

install_zsh() (
    local tmp archive release zsh_sha256 zsh_filename zsh_version
    need curl tar xz sha256sum make cc awk sed grep mktemp sort tail || return 1
    # Check for usable ncurses development headers and library.
    tmp=$(mktemp -d) || return 1
    trap 'rm -rf -- "$tmp"' EXIT
    if ! printf '#include <curses.h>\nint main(void){return endwin();}\n' |
        cc -x c - -o "$tmp/ncurses-check" -lncursesw >/dev/null 2>&1; then
        echo '[ERROR] Zsh build requires ncurses development headers/libraries.' >&2
        echo '[HINT] Ubuntu: apt install build-essential libncurses-dev (administrator only).' >&2
        return 1
    fi
    download "https://www.zsh.org/pub/SHA256SUM" "$tmp/SHA256SUM" || return 1
    release=$(latest_zsh_release "$tmp/SHA256SUM") || return 1
    if [[ -z $release ]]; then
        echo '[ERROR] No stable Zsh source archive found in the official checksum index.' >&2
        return 1
    fi
    read -r zsh_sha256 zsh_filename <<< "$release"
    zsh_version=${zsh_filename#zsh-}
    zsh_version=${zsh_version%.tar.xz}
    printf '[INFO] Latest stable Zsh: %s\n' "$zsh_version"
    archive="$tmp/$zsh_filename"
    download "https://www.zsh.org/pub/$zsh_filename" "$archive" ||
        download "https://downloads.sourceforge.net/project/zsh/zsh/$zsh_version/$zsh_filename" "$archive" || return 1
    printf '%s  %s\n' "$zsh_sha256" "$archive" | sha256sum -c - || return 1
    tar -xJf "$archive" -C "$tmp" || return 1
    cd "$tmp/zsh-$zsh_version" || return 1
    ./configure --prefix="$PREFIX" --enable-multibyte || return 1
    # Conservative default for shared servers; override with JOBS=N.
    make -j"${JOBS:-2}" || return 1
    make install || return 1
    "$BIN_DIR/zsh" -f -c 'zmodload zsh/datetime && autoload -Uz compinit && compinit -i -D' || return 1
)

install_release() (
    local name="$1" repo="$2" pattern="$3" tmp binary
    need curl python3 tar gzip sha256sum find install mktemp || return 1
    tmp=$(mktemp -d) || return 1
    trap 'rm -rf -- "$tmp"' EXIT
    release_asset "$repo" "$pattern" "$tmp" || return 1
    mkdir -p "$tmp/unpacked" || return 1
    tar -xzf "$tmp/archive.tar.gz" -C "$tmp/unpacked" --no-same-owner --no-same-permissions || return 1
    binary=$(find "$tmp/unpacked" -type f -name "$name" -print -quit) || return 1
    if [[ -z $binary ]]; then
        echo "[ERROR] Executable not found in archive: $name" >&2
        return 1
    fi
    chmod u+x "$binary" || return 1
    "$binary" --version || return 1
    install -m 755 "$binary" "$BIN_DIR/$name" || return 1
)

installed=() skipped=() failed=()
run_install() {
    local name="$1"; shift
    # Only skip a usable user-local program, not a system-wide installation.
    if [[ -x "$BIN_DIR/$name" ]] && "$BIN_DIR/$name" --version >/dev/null 2>&1; then
        if [[ $name != zsh ]] || "$BIN_DIR/zsh" -f -c 'zmodload zsh/datetime && autoload -Uz compinit && compinit -i -D' >/dev/null 2>&1; then
            printf '[SKIP] %s already installed in %s\n' "$name" "$BIN_DIR"
            skipped+=("$name")
            return 0
        fi
    fi
    # Never replace an existing executable/symlink without explicit user action.
    if [[ -e "$BIN_DIR/$name" || -L "$BIN_DIR/$name" ]]; then
        echo "[ERROR] Existing but unusable: $BIN_DIR/$name; inspect or move it before retrying." >&2
        failed+=("$name")
        return 0
    fi
    printf '\n[INSTALL] %s\n' "$name"
    if "$@"; then installed+=("$name"); else failed+=("$name"); fi
}

printf '[INFO] User: %s | Prefix: %s | Architecture: %s\n' "$(id -un)" "$PREFIX" "$ARCH"
run_install zsh install_zsh
run_install starship install_release starship starship/starship "starship-${ARCH}-unknown-linux-musl\.tar\.gz"
run_install fastfetch install_release fastfetch fastfetch-cli/fastfetch "fastfetch-linux-${FF_ARCH}\.tar\.gz"
run_install zoxide install_release zoxide ajeetdsouza/zoxide "zoxide-[0-9][0-9A-Za-z.\-]*-${ARCH}-unknown-linux-musl\.tar\.gz"
run_install eza install_release eza eza-community/eza "eza_${ARCH}-unknown-linux-gnu\.tar\.gz"
run_install bat install_release bat sharkdp/bat "bat-v[0-9][0-9A-Za-z.\-]*-${ARCH}-unknown-linux-musl\.tar\.gz"
printf '\n[SUMMARY] Installed: %s\n' "${installed[*]:-none}"
printf '[SUMMARY] Skipped:   %s\n' "${skipped[*]:-none}"
printf '[SUMMARY] Failed:    %s\n' "${failed[*]:-none}"
(( ${#failed[@]} == 0 ))
