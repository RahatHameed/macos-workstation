#!/bin/bash
# shell.sh - Zsh + Oh My Zsh module
#
# macOS has shipped Zsh as the default shell since Catalina, so this module
# installs a current Zsh via Homebrew (the system one lags) and layers
# Oh My Zsh on top.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_zsh() {
    require_brew || return 1
    brew_install zsh
}

install_oh_my_zsh() {
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_status "Oh My Zsh already installed"
        return 0
    fi

    print_info "Installing Oh My Zsh..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install Oh My Zsh"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    print_status "Oh My Zsh installed"
}

install_zsh_plugins() {
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        print_warning "Oh My Zsh not present, skipping plugins"
        return 0
    fi

    # zsh-autosuggestions
    if [[ -d "$custom/plugins/zsh-autosuggestions" ]]; then
        print_status "zsh-autosuggestions already installed"
    else
        print_info "Installing zsh-autosuggestions..."
        run git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions \
            "$custom/plugins/zsh-autosuggestions"
        print_status "zsh-autosuggestions installed"
    fi

    # zsh-syntax-highlighting
    if [[ -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
        print_status "zsh-syntax-highlighting already installed"
    else
        print_info "Installing zsh-syntax-highlighting..."
        run git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "$custom/plugins/zsh-syntax-highlighting"
        print_status "zsh-syntax-highlighting installed"
    fi

    print_warning "[MANUAL] Enable them in ~/.zshrc:"
    echo "  plugins=(git zsh-autosuggestions zsh-syntax-highlighting)"
}

set_default_shell() {
    local brew_zsh
    brew_zsh="$(brew_prefix)/bin/zsh"

    if [[ ! -x "$brew_zsh" ]]; then
        print_warning "Homebrew zsh not found, keeping system zsh"
        return 0
    fi

    if [[ "$SHELL" == "$brew_zsh" ]]; then
        print_status "Homebrew zsh already the default shell"
        return 0
    fi

    print_info "Setting $brew_zsh as the default shell..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would add $brew_zsh to /etc/shells and run chsh"
        return 0
    fi

    # chsh refuses shells that are not listed in /etc/shells
    if ! grep -qx "$brew_zsh" /etc/shells; then
        print_info "Adding $brew_zsh to /etc/shells (requires sudo)..."
        echo "$brew_zsh" | sudo tee -a /etc/shells > /dev/null
    fi

    chsh -s "$brew_zsh"
    print_status "Default shell set to $brew_zsh (takes effect on next login)"
}

install_shell() {
    print_section "Shell Setup (Zsh + Oh My Zsh)"

    install_zsh || return 1
    install_oh_my_zsh
    install_zsh_plugins
    set_default_shell

    print_warning "Open a new terminal for shell changes to take effect"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_shell
fi
