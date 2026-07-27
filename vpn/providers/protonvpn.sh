#!/bin/bash
# protonvpn.sh - ProtonVPN provider (macOS)
#
# IMPORTANT DIFFERENCE FROM THE UBUNTU REPO:
# The Linux `protonvpn-cli` has no macOS counterpart - the macOS client is
# GUI-only. Connect/disconnect open the app; the user finishes in the UI.
#
# Only the connection *state* is detectable. For scripted control, use Mullvad.

provider_name() {
    echo "ProtonVPN"
}

provider_check_installed() {
    [[ -d "/Applications/ProtonVPN.app" ]]
}

# ============================================
# Installation
# ============================================

provider_install() {
    if provider_check_installed; then
        print_status "ProtonVPN already installed"
        return 0
    fi

    print_info "Installing ProtonVPN..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install the protonvpn cask"
        return 0
    fi

    cask_install "protonvpn" "ProtonVPN"

    print_status "ProtonVPN installed"
}

provider_configure() {
    print_warning "ProtonVPN on macOS has no CLI - sign in through the app."
    print_info "Open ProtonVPN.app and log in with your Proton account."
    print_info "Enable 'Connect on launch' in the app's settings for startup behaviour."
}

# ============================================
# Connection management
# ============================================

provider_connect() {
    local country="${1:-}"
    local city="${2:-}"

    if ! provider_check_installed; then
        echo "ProtonVPN is not installed"
        return 1
    fi

    open -a ProtonVPN

    if [[ -n "$country" ]]; then
        echo "Opened ProtonVPN. Select $country${city:+ / $city} in the app to connect."
    else
        echo "Opened ProtonVPN. Click Quick Connect in the app."
    fi

    echo "Note: ProtonVPN provides no macOS CLI, so this cannot be automated further."
}

provider_disconnect() {
    if ! provider_check_installed; then
        echo "ProtonVPN is not installed"
        return 1
    fi

    open -a ProtonVPN
    echo "Opened ProtonVPN. Click Disconnect in the app."
}

provider_status() {
    if ! provider_check_installed; then
        echo "ProtonVPN: not installed"
        return 1
    fi

    if ! pgrep -q -f "ProtonVPN.app" 2>/dev/null; then
        echo "ProtonVPN: not running"
        return 0
    fi

    if provider_is_connected; then
        echo "ProtonVPN: running, tunnel interface active"
    else
        echo "ProtonVPN: running, no tunnel detected"
    fi

    echo "External IP: $(curl -s --max-time 5 https://ipinfo.io/ip 2>/dev/null || echo unknown)"
}

provider_is_connected() {
    local iface
    iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    [[ "$iface" == utun* ]]
}
