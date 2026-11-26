# =============================================================================
# Mihomo Configuration
# =============================================================================

# Skip if Mihomo is not installed.
[[ -x "$HOME/.local/bin/mihomo" ]] || return 0

MIHOMO_BIN="$HOME/.local/bin/mihomo"
MIHOMO_DIR="$HOME/.config/mihomo"
MIHOMO_LOG="$MIHOMO_DIR/mihomo.log"

MIHOMO_HTTP="http://127.0.0.1:7890"
MIHOMO_SOCKS="socks5h://127.0.0.1:7891"
MIHOMO_API="http://127.0.0.1:9090"

# Start Mihomo
clash_start() {
    if pgrep -u "$(id -u)" -x mihomo >/dev/null; then
        echo "[SKIP] Mihomo is already running."
        return 0
    fi

    if [[ ! -x "$MIHOMO_BIN" ]]; then
        echo "[ERROR] Mihomo is not installed."
        return 1
    fi

    (
        umask 077
        nohup "$MIHOMO_BIN" -d "$MIHOMO_DIR" \
            > "$MIHOMO_LOG" 2>&1 < /dev/null &!
    )

    sleep 1

    if pgrep -u "$(id -u)" -x mihomo >/dev/null; then
        echo "[OK] Mihomo process started."
    else
        echo "[ERROR] Mihomo failed to start."
        tail -n 20 "$MIHOMO_LOG"
        return 1
    fi
}

# Stop Mihomo
clash_stop() {
    if ! pgrep -u "$(id -u)" -x mihomo >/dev/null; then
        echo "[SKIP] Mihomo is not running."
        return 0
    fi

    pkill -TERM -u "$(id -u)" -x mihomo || return 1

    local i
    for i in {1..10}; do
        if ! pgrep -u "$(id -u)" -x mihomo >/dev/null; then
            echo "[OK] Mihomo stopped."
            return 0
        fi
        sleep 0.5
    done

    echo "[ERROR] Mihomo has not stopped."
    return 1
}

# Restart Mihomo
clash_restart() {
    clash_stop && clash_start
}

# Check status
clash_status() {
    pgrep -a -u "$(id -u)" -x mihomo ||
        echo "[INFO] Mihomo is not running."
}

# View logs
clash_logs() {
    tail -n 30 -f "$MIHOMO_LOG"
}

# =============================================================================
# Shell Proxy Environment
# =============================================================================

proxy_on() {
    if ! pgrep -u "$(id -u)" -x mihomo >/dev/null; then
        echo "[ERROR] Start Mihomo using clash_start first."
        return 1
    fi

    export http_proxy="$MIHOMO_HTTP"
    export https_proxy="$MIHOMO_HTTP"
    export all_proxy="$MIHOMO_SOCKS"

    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$https_proxy"
    export ALL_PROXY="$all_proxy"

    echo "[OK] Proxy enabled."
}

proxy_off() {
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY

    echo "[OK] Proxy disabled."
}

proxy_status() {
    echo "===== Mihomo ====="
    clash_status

    echo "===== Proxy Environment ====="
    env | grep -iE '^(http|https|all)_proxy=' ||
        echo "Proxy disabled."
}