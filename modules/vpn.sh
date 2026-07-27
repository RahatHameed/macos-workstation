#!/bin/bash
# vpn.sh - VPN installation module with pluggable providers
#
# Supported providers are defined in vpn/providers/*.sh
# To add a new provider, create a new file in that directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROVIDERS_DIR="$SCRIPT_DIR/../vpn/providers"

# Default values (can be overridden by config)
VPN_PROVIDER="${VPN_PROVIDER:-mullvad}"
VPN_DEFAULT_COUNTRY="${VPN_DEFAULT_COUNTRY:-de}"
VPN_ACCOUNT_NUMBER="${VPN_ACCOUNT_NUMBER:-}"

# ============================================
# Provider management
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
        print_error "Unknown VPN provider: $provider"
        print_info "Available providers: $(list_providers | tr '\n' ' ')"
        print_info "To add a new provider, copy $PROVIDERS_DIR/_template.sh"
        return 1
    fi

    source "$provider_file"
}

# ============================================
# VPN Connect Script Configuration
# ============================================

configure_vpn_script() {
    local vpn_script="$SCRIPT_DIR/../vpn/vpn-connect.sh"

    if [[ -f "$vpn_script" ]]; then
        print_info "Updating VPN connection script..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would update vpn-connect.sh with provider=$VPN_PROVIDER, country=$VPN_DEFAULT_COUNTRY"
        else
            # BSD sed needs the empty backup suffix
            sed -i '' "s/^VPN_PROVIDER=.*/VPN_PROVIDER=\"\${VPN_PROVIDER:-$VPN_PROVIDER}\"/" "$vpn_script"
            sed -i '' "s/^DEFAULT_COUNTRY=.*/DEFAULT_COUNTRY=\"\${DEFAULT_COUNTRY:-$VPN_DEFAULT_COUNTRY}\"/" "$vpn_script"
            print_status "VPN script configured: provider=$VPN_PROVIDER, country=$VPN_DEFAULT_COUNTRY"
        fi
    fi
}

# ============================================
# Main installation
# ============================================

install_vpn() {
    local config_file="${1:-${CONFIG_FILE:-}}"

    print_section "VPN Setup"

    require_brew || return 1

    # Read config if available
    if [[ -n "$config_file" ]] && [[ -f "$config_file" ]]; then
        VPN_PROVIDER=$(parse_yaml "$config_file" "vpn.provider" "$VPN_PROVIDER")
        VPN_DEFAULT_COUNTRY=$(parse_yaml "$config_file" "vpn.default_country" "$VPN_DEFAULT_COUNTRY")
        VPN_ACCOUNT_NUMBER=$(parse_yaml "$config_file" "vpn.account_number" "$VPN_ACCOUNT_NUMBER")
    fi

    print_info "VPN Provider: $VPN_PROVIDER"
    print_info "Default Country: $VPN_DEFAULT_COUNTRY"
    print_info "Available providers: $(list_providers | tr '\n' ' ')"

    if ! load_provider "$VPN_PROVIDER"; then
        return 1
    fi

    provider_install
    provider_configure

    configure_vpn_script

    print_status "VPN setup complete"
    print_info "Use 'vpn-connect.sh' or the 'vpn' alias to manage connections"
}

# Run directly if executed as script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_vpn "$1"
fi
