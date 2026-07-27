#!/bin/bash
# nordvpn.sh - NordVPN provider (macOS)
#
# IMPORTANT DIFFERENCE FROM THE UBUNTU REPO:
# NordVPN ships a full `nordvpn` CLI on Linux, but the macOS app has no
# official command-line interface. Connect/disconnect therefore drive the GUI
# app via `open`, and the user completes the action in the app window.
#
# Only the connection *state* can be detected reliably, not the exit country.
# If you need scripted country switching on macOS, use Mullvad.

provider_name() {
    echo "NordVPN"
}

provider_check_installed() {
    [[ -d "/Applications/NordVPN.app" ]]
}

# ============================================
# Installation
# ============================================

provider_install() {
    if provider_check_installed; then
        print_status "NordVPN already installed"
        return 0
    fi

    print_info "Installing NordVPN..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install the nordvpn cask"
        return 0
    fi

    cask_install "nordvpn" "NordVPN"

    print_status "NordVPN installed"
}

provider_configure() {
    print_warning "NordVPN on macOS has no CLI - sign in through the app."
    print_info "Open NordVPN.app and log in with your Nord account."
    print_info "Enable 'Auto-connect' in the app's settings for startup behaviour."
}

# ============================================
# Connection management
# ============================================

provider_connect() {
    local country="${1:-}"
    local city="${2:-}"

    if ! provider_check_installed; then
        echo "NordVPN is not installed"
        return 1
    fi

    open -a NordVPN

    if [[ -n "$country" ]]; then
        echo "Opened NordVPN. Select $country${city:+ / $city} in the app to connect."
    else
        echo "Opened NordVPN. Click Quick Connect in the app."
    fi

    echo "Note: NordVPN provides no macOS CLI, so this cannot be automated further."
}

provider_disconnect() {
    if ! provider_check_installed; then
        echo "NordVPN is not installed"
        return 1
    fi

    open -a NordVPN
    echo "Opened NordVPN. Click Disconnect in the app."
}

provider_status() {
    if ! provider_check_installed; then
        echo "NordVPN: not installed"
        return 1
    fi

    if ! pgrep -qx NordVPN 2>/dev/null && ! pgrep -q -f "NordVPN.app" 2>/dev/null; then
        echo "NordVPN: not running"
        return 0
    fi

    if provider_is_connected; then
        echo "NordVPN: running, tunnel interface active"
    else
        echo "NordVPN: running, no tunnel detected"
    fi

    echo "External IP: $(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo unknown)"
}

# Detect a live tunnel rather than asking the app, which cannot be queried.
# NordLynx (WireGuard) and OpenVPN both surface as a utun interface carrying
# a default route.
provider_is_connected() {
    local iface
    iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    [[ "$iface" == utun* ]]
}
