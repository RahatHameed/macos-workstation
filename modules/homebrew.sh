#!/bin/bash
# homebrew.sh - Homebrew + Xcode Command Line Tools bootstrap
#
# This module is a prerequisite for every other module. It has no Ubuntu
# equivalent: apt ships with the distro, Homebrew does not.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================
# Xcode Command Line Tools
# ============================================

install_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        print_status "Xcode Command Line Tools already installed"
        return 0
    fi

    print_info "Installing Xcode Command Line Tools..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would run: xcode-select --install"
        return 0
    fi

    # `xcode-select --install` opens a GUI dialog and returns immediately, so
    # poll until the tools actually land.
    xcode-select --install &>/dev/null || true

    print_warning "A system dialog has opened - click 'Install' and accept the licence."
    print_info "Waiting for Xcode Command Line Tools to finish installing..."

    local waited=0
    local timeout=1800  # 30 minutes
    until xcode-select -p &>/dev/null; do
        sleep 5
        waited=$((waited + 5))
        if (( waited >= timeout )); then
            print_error "Timed out waiting for Xcode Command Line Tools."
            print_info "Install them manually, then re-run this script."
            return 1
        fi
        if (( waited % 60 == 0 )); then
            print_info "Still waiting... (${waited}s)"
        fi
    done

    print_status "Xcode Command Line Tools installed"
}

# ============================================
# Homebrew
# ============================================

install_homebrew() {
    if command_exists brew || load_brew_env; then
        print_status "Homebrew already installed ($(brew_prefix))"
        return 0
    fi

    print_info "Installing Homebrew to $(brew_prefix)..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install Homebrew via the official installer"
        return 0
    fi

    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    load_brew_env
    print_status "Homebrew installed"
}

# Apple Silicon installs to /opt/homebrew, which is not on the default PATH.
# Intel installs to /usr/local, which is. Add the shellenv line either way so
# the config is explicit and portable between machines.
configure_brew_shellenv() {
    local prefix
    prefix="$(brew_prefix)"

    local shell_config
    if [[ -f "$HOME/.zprofile" || "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zprofile"
    else
        shell_config="$HOME/.bash_profile"
    fi

    if [[ -f "$shell_config" ]] && grep -q "brew shellenv" "$shell_config"; then
        print_status "Homebrew shellenv already configured in $shell_config"
        return 0
    fi

    print_info "Adding Homebrew to PATH in $shell_config..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would append brew shellenv to $shell_config"
        return 0
    fi

    cat >> "$shell_config" << EOF

# Homebrew
eval "\$($prefix/bin/brew shellenv)"
EOF

    print_status "Homebrew added to PATH in $shell_config"
}

install_brew_essentials() {
    print_info "Installing essential CLI tools..."

    brew_install git
    brew_install curl
    brew_install wget
    brew_install jq
    brew_install mas   # Mac App Store CLI, used by the apps module
}

update_homebrew() {
    print_info "Updating Homebrew..."
    run brew update
    print_status "Homebrew updated"
}

install_homebrew_module() {
    print_section "Homebrew Bootstrap"

    install_xcode_clt || return 1
    install_homebrew

    if ! require_brew; then
        return 1
    fi

    configure_brew_shellenv
    update_homebrew
    install_brew_essentials

    print_status "Homebrew bootstrap complete"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_homebrew_module
fi
