#!/bin/bash
# vpn-connect.sh - VPN connection wrapper with pluggable providers
#
# Usage:
#   ./vpn-connect.sh connect [country] [city]
#   ./vpn-connect.sh disconnect
#   ./vpn-connect.sh status
#   ./vpn-connect.sh is-connected
#   ./vpn-connect.sh list-providers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVIDERS_DIR="$SCRIPT_DIR/providers"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"

# ============================================
# Config parsing
# ============================================

parse_yaml_value() {
    local file="$1"
    local section="$2"
    local key="$3"
    local default="$4"

    [[ ! -f "$file" ]] && echo "$default" && return

    local value
    value=$(sed -n "/^${section}:\$/,/^[a-zA-Z_]/p" "$file" \
        | grep "^  ${key}:" \
        | head -1 \
        | sed "s/^  ${key}:[[:space:]]*//" \
        | tr -d '"' | tr -d "'")

    echo "${value:-$default}"
}

# ============================================
# Configuration (priority: env var > config.yaml > default)
# ============================================

VPN_PROVIDER="${VPN_PROVIDER:-mullvad}"
DEFAULT_COUNTRY="${DEFAULT_COUNTRY:-de}"

load_config() {
    local config_provider
    local config_country
    local config_city
    local config_auto_connect

    config_provider=$(parse_yaml_value "$CONFIG_FILE" "vpn" "provider" "$VPN_PROVIDER")
    config_country=$(parse_yaml_value "$CONFIG_FILE" "vpn" "default_country" "$DEFAULT_COUNTRY")
    config_city=$(parse_yaml_value "$CONFIG_FILE" "vpn" "default_city" "")
    config_auto_connect=$(parse_yaml_value "$CONFIG_FILE" "vpn" "auto_connect" "false")

    VPN_PROVIDER="${VPN_PROVIDER:-$config_provider}"
    DEFAULT_COUNTRY="${DEFAULT_COUNTRY:-$config_country}"
    DEFAULT_CITY="${DEFAULT_CITY:-$config_city}"
    AUTO_CONNECT="${AUTO_CONNECT:-$config_auto_connect}"
}

load_config

# ============================================
# Minimal print helpers
#
# This script is also run standalone (from a LaunchAgent, or via the `vpn`
# alias), so it cannot rely on modules/common.sh being sourced. Define the
# handful of helpers the providers use, but only if they are not already set.
# ============================================

if ! declare -f print_status &>/dev/null; then
    print_status()  { echo "[✓] $1"; }
    print_warning() { echo "[!] $1"; }
    print_error()   { echo "[✗] $1"; }
    print_info()    { echo "[i] $1"; }
fi

if ! declare -f cask_install &>/dev/null; then
    cask_install() { echo "[i] Install manually: brew install --cask $1"; }
fi

# ============================================
# Provider loading
# ============================================

list_providers() {
    local providers=()
    local f
    for f in "$PROVIDERS_DIR"/*.sh; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f" .sh)
        [[ "$name" == _* ]] && continue  # Skip templates
        providers+=("$name")
    done
    [[ ${#providers[@]} -eq 0 ]] && return 0
    printf '%s\n' "${providers[@]}"
}

load_provider() {
    local provider="$1"
    local provider_file="$PROVIDERS_DIR/${provider}.sh"

    if [[ ! -f "$provider_file" ]]; then
        echo "Error: Unknown provider '$provider'"
        echo "Available providers: $(list_providers | tr '\n' ' ')"
        echo "To add a new provider, copy $PROVIDERS_DIR/_template.sh"
        exit 1
    fi

    source "$provider_file"
}

# ============================================
# Connection helpers
# ============================================

vpn_wait_connected() {
    local timeout="${1:-10}"
    local i
    for ((i=1; i<=timeout; i++)); do
        if provider_is_connected; then
            echo "VPN connected ($(provider_name))"
            return 0
        fi
        sleep 1
    done
    echo "VPN connection timeout"
    return 1
}

# ============================================
# CLI
# ============================================

show_help() {
    cat <<EOF
VPN Connection Manager (macOS)

Usage: $(basename "$0") <command> [options]

Commands:
  connect [country] [city]   Connect to VPN (default: $DEFAULT_COUNTRY $DEFAULT_CITY)
  auto-connect               Connect only if auto_connect=true in config
  disconnect                 Disconnect from VPN
  status                     Show connection status
  is-connected               Exit 0 if connected, 1 if not
  list-providers             List available VPN providers

Configuration (from config.yaml):
  VPN_PROVIDER=$VPN_PROVIDER
  DEFAULT_COUNTRY=$DEFAULT_COUNTRY
  DEFAULT_CITY=$DEFAULT_CITY

To change settings, edit config.yaml:
  vpn:
    provider: mullvad
    default_country: de
    default_city: ""

Or override via environment:
  VPN_PROVIDER=mullvad DEFAULT_COUNTRY=se ./vpn-connect.sh connect

macOS caveat:
  Only Mullvad ships a CLI on macOS. The NordVPN and ProtonVPN clients are
  GUI-only, so connect/disconnect open the app rather than switching servers
  directly. Status detection works for all three.

Adding new providers:
  cp $PROVIDERS_DIR/_template.sh $PROVIDERS_DIR/myvpn.sh
  # Implement the required functions
EOF
}

main() {
    local command="${1:-}"

    # Handle list-providers before loading a provider
    if [[ "$command" == "list-providers" ]]; then
        echo "Available providers:"
        list_providers | while read -r p; do
            if [[ "$p" == "$VPN_PROVIDER" ]]; then
                echo "  $p (current)"
            else
                echo "  $p"
            fi
        done
        exit 0
    fi

    load_provider "$VPN_PROVIDER"

    case "$command" in
        connect)
            local country="${2:-$DEFAULT_COUNTRY}"
            local city="${3:-$DEFAULT_CITY}"
            provider_connect "$country" "$city"
            vpn_wait_connected
            ;;
        auto-connect)
            if [[ "$AUTO_CONNECT" != "true" ]]; then
                echo "VPN auto-connect disabled in config"
                exit 0
            fi
            local country="${2:-$DEFAULT_COUNTRY}"
            local city="${3:-$DEFAULT_CITY}"
            provider_connect "$country" "$city"
            vpn_wait_connected
            ;;
        disconnect)
            provider_disconnect
            echo "VPN disconnected"
            ;;
        status)
            provider_status
            ;;
        is-connected)
            if provider_is_connected; then
                echo "Connected"
                exit 0
            else
                echo "Disconnected"
                exit 1
            fi
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
