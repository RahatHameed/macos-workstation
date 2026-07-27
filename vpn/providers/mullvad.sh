#!/bin/bash
# mullvad.sh - Mullvad VPN provider (macOS)
#
# Mullvad is the only one of the three bundled providers that ships a real
# CLI on macOS, so this is the only provider with full scripted control.

MULLVAD_APP_CLI="/Applications/Mullvad VPN.app/Contents/Resources/mullvad"

provider_name() {
    echo "Mullvad VPN"
}

# The pkg inside the cask normally symlinks `mullvad` onto the PATH, but fall
# back to the binary inside the app bundle if it did not.
mullvad_cli() {
    if command -v mullvad &>/dev/null; then
        command mullvad "$@"
    elif [[ -x "$MULLVAD_APP_CLI" ]]; then
        "$MULLVAD_APP_CLI" "$@"
    else
        echo "Mullvad CLI not found" >&2
        return 1
    fi
}

provider_check_installed() {
    command -v mullvad &>/dev/null || [[ -x "$MULLVAD_APP_CLI" ]]
}

# ============================================
# Installation
# ============================================

provider_install() {
    if provider_check_installed; then
        print_status "Mullvad VPN already installed"
        return 0
    fi

    print_info "Installing Mullvad VPN..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install the mullvad-vpn cask"
        return 0
    fi

    cask_install "mullvad-vpn" "Mullvad VPN"

    print_status "Mullvad VPN installed"
}

provider_configure() {
    local account_number="${VPN_ACCOUNT_NUMBER:-}"

    if [[ -n "$account_number" ]]; then
        print_info "Logging into Mullvad..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would login with account number"
        else
            mullvad_cli account login "$account_number"
            print_status "Mullvad account configured"
        fi
    else
        print_warning "Run 'mullvad account login YOUR_ACCOUNT_NUMBER' to authenticate"
    fi
}

# ============================================
# Connection management
# ============================================

provider_connect() {
    local country="${1:-}"
    local city="${2:-}"

    if [[ -n "$country" && -n "$city" ]]; then
        mullvad_cli relay set location "$country" "$city"
    elif [[ -n "$country" ]]; then
        mullvad_cli relay set location "$country"
    fi

    mullvad_cli connect
}

provider_disconnect() {
    mullvad_cli disconnect
}

provider_status() {
    mullvad_cli status
}

provider_is_connected() {
    mullvad_cli status 2>/dev/null | grep -q "Connected"
}
