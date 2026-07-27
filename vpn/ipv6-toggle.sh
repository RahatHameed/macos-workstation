#!/bin/bash
# ipv6-toggle.sh - IPv6 leak protection for VPN use (macOS)
#
# Many VPNs tunnel IPv4 only. If IPv6 stays up, traffic to dual-stack sites
# leaves over IPv6 outside the tunnel and exposes your real address.
#
# The Ubuntu repo does this with sysctl (net.ipv6.conf.all.disable_ipv6).
# macOS has no such knob - IPv6 is configured per network service, so this
# script drives `networksetup` across every active service instead.
#
# Usage:
#   ./ipv6-toggle.sh            Apply the config.yaml setting (default: disable)
#   ./ipv6-toggle.sh disable    Force IPv6 off
#   ./ipv6-toggle.sh enable     Restore IPv6 to automatic
#   ./ipv6-toggle.sh status     Show per-service state and external IPs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"

# ============================================
# Config
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

IPV6_DISABLE=$(parse_yaml_value "$CONFIG_FILE" "vpn" "ipv6_disable" "true")

# ============================================
# Network services
# ============================================

# List every network service, skipping disabled ones (prefixed with '*')
list_services() {
    networksetup -listallnetworkservices 2>/dev/null \
        | tail -n +2 \
        | grep -v '^\*'
}

set_ipv6() {
    local mode="$1"   # off | automatic
    local changed=0

    while IFS= read -r service; do
        [[ -z "$service" ]] && continue

        if [[ "$mode" == "off" ]]; then
            if sudo networksetup -setv6off "$service" 2>/dev/null; then
                echo "  [✓] IPv6 disabled on: $service"
                changed=$((changed + 1))
            fi
        else
            if sudo networksetup -setv6automatic "$service" 2>/dev/null; then
                echo "  [✓] IPv6 set to automatic on: $service"
                changed=$((changed + 1))
            fi
        fi
    done <<< "$(list_services)"

    if [[ $changed -eq 0 ]]; then
        echo "  [!] No network services were changed"
        return 1
    fi
}

disable_ipv6() {
    echo "Disabling IPv6 (requires sudo)..."
    set_ipv6 off
    echo "[✓] IPv6 disabled - changes persist across reboots"
}

enable_ipv6() {
    echo "Enabling IPv6 (requires sudo)..."
    set_ipv6 automatic
    echo "[✓] IPv6 restored to automatic"
}

show_status() {
    echo "=== IPv6 Status ==="
    echo ""

    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        local info
        info=$(networksetup -getinfo "$service" 2>/dev/null | grep -i "IPv6:" | head -1)
        printf "  %-28s %s\n" "$service" "${info:-unknown}"
    done <<< "$(list_services)"

    echo ""
    echo "=== External IPs ==="
    local v4 v6
    v4=$(curl -s --max-time 5 -4 https://ifconfig.co 2>/dev/null || echo "none")
    v6=$(curl -s --max-time 5 -6 https://ifconfig.co 2>/dev/null || echo "none (good for VPN use)")
    echo "  IPv4: $v4"
    echo "  IPv6: $v6"

    echo ""
    echo "=== Default route ==="
    local iface
    iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    if [[ "$iface" == utun* ]]; then
        echo "  $iface (tunnel - VPN appears active)"
    else
        echo "  ${iface:-unknown} (not a tunnel)"
    fi
}

# ============================================
# Main
# ============================================

case "${1:-}" in
    disable)
        disable_ipv6
        ;;
    enable)
        enable_ipv6
        ;;
    status)
        show_status
        ;;
    ""|apply)
        # Apply whatever config.yaml says
        if [[ "$IPV6_DISABLE" == "true" ]]; then
            disable_ipv6
        else
            enable_ipv6
        fi
        ;;
    help|--help|-h)
        sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "Unknown command: $1"
        echo "Usage: $(basename "$0") [disable|enable|status|apply]"
        exit 1
        ;;
esac
