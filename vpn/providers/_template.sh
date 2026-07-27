#!/bin/bash
# _template.sh - Template for adding new VPN providers
#
# To add a new provider:
# 1. Copy this file: cp _template.sh myvpn.sh
# 2. Implement all functions below
# 3. Test: VPN_PROVIDER=myvpn ./vpn-connect.sh status
#
# The provider filename (without .sh) becomes the provider name.
# Example: expressvpn.sh -> VPN_PROVIDER=expressvpn
#
# macOS note: many VPN vendors ship a Linux CLI but a GUI-only macOS client.
# If yours has no CLI, drive the app with `open -a AppName` and detect the
# connection state from the default route (see nordvpn.sh for that pattern).

# ============================================
# Required: Installation (used by modules/vpn.sh)
# ============================================

provider_install() {
    # Install the VPN client.
    # Use cask_install for GUI apps, brew_install for CLI tools.
    # Example:
    #   cask_install "myvpn" "MyVPN"
    echo "TODO: Implement installation"
}

provider_configure() {
    # Post-installation configuration.
    # Handle account setup, initial config, etc.
    # Example:
    #   print_warning "Run 'myvpn login' to authenticate"
    echo "TODO: Implement configuration"
}

# ============================================
# Required: Connection management (used by vpn-connect.sh)
# ============================================

provider_connect() {
    local country="${1:-}"
    local city="${2:-}"
    # Connect to VPN, optionally to a specific country/city.
    # Example (CLI client):
    #   myvpn connect "$country"
    # Example (GUI-only client):
    #   open -a MyVPN
    echo "TODO: Implement connect"
}

provider_disconnect() {
    # Disconnect from VPN
    # Example:
    #   myvpn disconnect
    echo "TODO: Implement disconnect"
}

provider_status() {
    # Print human-readable status
    # Example:
    #   myvpn status
    echo "TODO: Implement status"
}

provider_is_connected() {
    # Return 0 if connected, 1 if not (for scripting).
    #
    # With a CLI client:
    #   myvpn status | grep -q "Connected"
    #
    # Without one, check whether the default route runs over a tunnel:
    #   local iface
    #   iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')
    #   [[ "$iface" == utun* ]]
    return 1
}

# ============================================
# Optional: Provider metadata
# ============================================

provider_name() {
    echo "MyVPN"  # Human-readable name
}

provider_check_installed() {
    # Return 0 if the VPN client is installed.
    # Example (CLI):  command -v myvpn &>/dev/null
    # Example (app):  [[ -d "/Applications/MyVPN.app" ]]
    return 1
}
