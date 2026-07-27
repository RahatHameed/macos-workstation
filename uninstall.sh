#!/bin/bash
# uninstall.sh - Uninstall/revert macOS Setup Scripts changes
#
# Usage:
#   ./uninstall.sh              # Interactive mode
#   ./uninstall.sh -m shell     # Uninstall specific module
#   ./uninstall.sh --all        # Uninstall everything
#   ./uninstall.sh --dry-run    # Preview changes
#
# Safe by default:
#   - SSH keys are kept
#   - Git user.name/email are kept
#   - Homebrew itself is kept (removing it would break unrelated tooling)

set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/modules/common.sh"

# Defaults
DRY_RUN=false
MODULE=""
UNINSTALL_ALL=false

# ============================================
# Parse arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "macOS Setup Scripts - Uninstaller"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help          Show this help message"
            echo "  -m, --module NAME   Uninstall specific module"
            echo "                      Modules: shell, git, ssh, signing, apps, docker, vpn"
            echo "  --all               Uninstall everything"
            echo "  --dry-run           Show what would be removed"
            echo ""
            echo "Examples:"
            echo "  $0                   # Interactive mode"
            echo "  $0 -m apps           # Uninstall only apps"
            echo "  $0 --all --dry-run   # Preview full uninstall"
            exit 0
            ;;
        -m|--module)
            MODULE="$2"
            shift 2
            ;;
        --all)
            UNINSTALL_ALL=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            export DRY_RUN
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

check_macos
load_brew_env 2>/dev/null || true

# ============================================
# Helpers
# ============================================

cask_uninstall() {
    local cask="$1"
    local app_name="${2:-$cask}"

    if ! command_exists brew; then
        print_warning "Homebrew not available, skipping $cask"
        return 0
    fi

    if ! brew list --cask "$cask" &>/dev/null; then
        return 0
    fi

    print_info "Removing $app_name..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would run: brew uninstall --cask $cask"
    else
        brew uninstall --cask "$cask" 2>/dev/null || true
        print_status "$app_name removed"
    fi
}

defaults_delete() {
    local domain="$1"
    local key="$2"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would reset $domain $key"
        return 0
    fi

    defaults delete "$domain" "$key" 2>/dev/null || true
}

# ============================================
# Uninstall functions
# ============================================

uninstall_shell() {
    print_section "Uninstalling Shell (Zsh + Oh My Zsh)"

    # Revert to the system zsh rather than bash - macOS default since Catalina
    if [[ "$SHELL" == *"$(brew_prefix)"* ]]; then
        print_info "Reverting default shell to /bin/zsh..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would run: chsh -s /bin/zsh"
        else
            chsh -s /bin/zsh
            print_status "Default shell reverted to /bin/zsh"
        fi
    else
        print_status "Already using the system shell"
    fi

    # Remove Oh My Zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_info "Removing Oh My Zsh..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would remove ~/.oh-my-zsh"
        else
            rm -rf "$HOME/.oh-my-zsh"
            print_status "Oh My Zsh removed"
        fi
    fi

    # Remove .zshrc
    if [[ -f "$HOME/.zshrc" ]]; then
        print_info "Removing .zshrc..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would remove ~/.zshrc"
        else
            rm -f "$HOME/.zshrc"
            print_status ".zshrc removed"
        fi
    fi

    print_warning "Homebrew zsh kept (remove manually: brew uninstall zsh)"
}

uninstall_git() {
    print_section "Uninstalling Git Configuration"

    print_info "Removing git aliases..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would remove git aliases"
    else
        git config --global --remove-section alias 2>/dev/null || true
        print_status "Git aliases removed"
    fi

    print_info "Removing global gitignore setting..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would unset core.excludesfile"
    else
        git config --global --unset core.excludesfile 2>/dev/null || true
        print_status "Global gitignore unset (~/.gitignore_global kept)"
    fi

    print_warning "Git user.name and user.email kept (remove manually if needed)"
    print_warning "Git package kept (remove manually: brew uninstall git)"
}

uninstall_ssh() {
    print_section "Uninstalling SSH Configuration"

    if [[ -f "$HOME/.ssh/config" ]]; then
        print_info "Removing GitHub/GitLab entries from SSH config..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would remove our entries from ~/.ssh/config"
        else
            # BSD sed needs the empty backup suffix
            sed -i '' '/# Global SSH settings/,/IdentityFile.*id_ed25519/d' "$HOME/.ssh/config"
            print_status "SSH config entries removed"
        fi
    fi

    print_info "Removing key from the agent..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would run: ssh-add -d ~/.ssh/id_ed25519"
    else
        ssh-add -d "$HOME/.ssh/id_ed25519" 2>/dev/null || true
        print_status "Key removed from agent"
    fi

    print_warning "SSH keys kept for safety (remove manually: rm ~/.ssh/id_ed25519*)"
    print_warning "Keychain entry kept (remove via Keychain Access if needed)"
}

uninstall_signing() {
    print_section "Disabling Commit Signing"

    print_info "Removing git signing configuration..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would unset commit.gpgsign, tag.gpgsign, gpg.format,"
        print_info "[DRY-RUN]   user.signingkey and gpg.ssh.allowedSignersFile"
    else
        git config --global --unset commit.gpgsign 2>/dev/null || true
        git config --global --unset tag.gpgsign 2>/dev/null || true
        git config --global --unset gpg.format 2>/dev/null || true
        git config --global --unset user.signingkey 2>/dev/null || true
        git config --global --unset gpg.ssh.allowedSignersFile 2>/dev/null || true
        print_status "Signing configuration removed"
    fi

    # The allowed_signers file and any GPG keys are user data - keeping them
    # means re-enabling signing later does not need a new key.
    print_warning "~/.config/git/allowed_signers kept (delete manually if unwanted)"
    print_warning "Keys registered on GitHub must be removed there:"
    echo "  https://github.com/settings/keys"
}

uninstall_apps() {
    print_section "Uninstalling Applications"

    cask_uninstall "slack" "Slack"
    cask_uninstall "microsoft-teams" "Microsoft Teams"
    cask_uninstall "microsoft-outlook" "Microsoft Outlook"
    cask_uninstall "visual-studio-code" "VS Code"
    cask_uninstall "spotify" "Spotify"
    cask_uninstall "discord" "Discord"
    cask_uninstall "zoom" "Zoom"
    cask_uninstall "postman" "Postman"
    cask_uninstall "dbeaver-community" "DBeaver"
    cask_uninstall "google-chrome" "Google Chrome"
    cask_uninstall "jetbrains-toolbox" "JetBrains Toolbox"
    cask_uninstall "iterm2" "iTerm2"
    cask_uninstall "raycast" "Raycast"

    print_warning "IDEs installed via JetBrains Toolbox must be removed from Toolbox first"
}

uninstall_docker() {
    print_section "Uninstalling Docker"

    # Colima
    if command_exists colima; then
        print_info "Stopping and removing Colima..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would stop and delete the colima VM"
        else
            colima stop 2>/dev/null || true
            colima delete --force 2>/dev/null || true
            brew uninstall colima docker docker-compose docker-buildx 2>/dev/null || true
            print_status "Colima removed"
        fi
    fi

    # Docker Desktop
    if [[ -d "/Applications/Docker.app" ]]; then
        print_info "Removing Docker Desktop..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would quit and remove Docker Desktop"
        else
            osascript -e 'quit app "Docker"' 2>/dev/null || true
            sleep 2
            brew uninstall --cask docker-desktop 2>/dev/null \
                || brew uninstall --cask docker 2>/dev/null \
                || true
            print_status "Docker Desktop removed"
        fi
    fi

    print_warning "Docker images and volumes in ~/Library/Containers/com.docker.docker are kept"
    print_warning "Remove them manually to reclaim disk space (this cannot be undone)"
}

uninstall_vpn() {
    print_section "Uninstalling VPN"

    local vpn_found=false

    # Restore IPv6 first - leaving it disabled after removing the VPN is a
    # confusing state to debug later.
    if [[ -x "$ROOT_DIR/vpn/ipv6-toggle.sh" ]]; then
        print_info "Restoring IPv6 to automatic..."
        if [[ "$DRY_RUN" == true ]]; then
            print_info "[DRY-RUN] Would run: vpn/ipv6-toggle.sh enable"
        else
            "$ROOT_DIR/vpn/ipv6-toggle.sh" enable || print_warning "Could not restore IPv6"
        fi
    fi

    # Mullvad
    if [[ -d "/Applications/Mullvad VPN.app" ]]; then
        vpn_found=true
        if [[ "$DRY_RUN" != true ]] && command_exists mullvad; then
            mullvad disconnect 2>/dev/null || true
        fi
        cask_uninstall "mullvad-vpn" "Mullvad VPN"
    fi

    # NordVPN
    if [[ -d "/Applications/NordVPN.app" ]]; then
        vpn_found=true
        if [[ "$DRY_RUN" != true ]]; then
            osascript -e 'quit app "NordVPN"' 2>/dev/null || true
        fi
        cask_uninstall "nordvpn" "NordVPN"
    fi

    # ProtonVPN
    if [[ -d "/Applications/ProtonVPN.app" ]]; then
        vpn_found=true
        if [[ "$DRY_RUN" != true ]]; then
            osascript -e 'quit app "ProtonVPN"' 2>/dev/null || true
        fi
        cask_uninstall "protonvpn" "ProtonVPN"
    fi

    if [[ "$vpn_found" == false ]]; then
        print_status "No VPN installed"
    fi
}

# ============================================
# Interactive mode
# ============================================
run_interactive() {
    print_section "Interactive Uninstall"

    print_warning "This will remove components installed by macOS Setup Scripts"
    echo ""

    confirm "Uninstall Zsh + Oh My Zsh?" && uninstall_shell
    confirm "Remove Git aliases?" && uninstall_git
    confirm "Remove SSH configuration?" && uninstall_ssh
    confirm "Disable commit signing?" && uninstall_signing
    confirm "Uninstall applications (Chrome, Slack, etc.)?" && uninstall_apps
    confirm "Uninstall Docker?" && uninstall_docker
    confirm "Uninstall VPN?" && uninstall_vpn
}

# ============================================
# Run specific module
# ============================================
run_module() {
    case "$MODULE" in
        shell) uninstall_shell ;;
        git) uninstall_git ;;
        ssh) uninstall_ssh ;;
        signing) uninstall_signing ;;
        apps) uninstall_apps ;;
        docker) uninstall_docker ;;
        vpn) uninstall_vpn ;;
        *)
            print_error "Unknown module: $MODULE"
            echo "Available modules: shell, git, ssh, signing, apps, docker, vpn"
            exit 1
            ;;
    esac
}

# ============================================
# Uninstall all
# ============================================
run_all() {
    print_warning "This will remove ALL components installed by macOS Setup Scripts"
    echo ""

    if [[ "$DRY_RUN" != true ]]; then
        if ! confirm "Are you sure you want to continue?"; then
            echo "Aborted."
            exit 0
        fi
    fi

    uninstall_vpn
    uninstall_apps
    uninstall_docker
    uninstall_signing
    uninstall_ssh
    uninstall_git
    uninstall_shell

    print_warning "Homebrew itself was kept - other tooling probably depends on it."
    print_info "To remove it: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
}

# ============================================
# Main
# ============================================
main() {
    print_section "macOS Setup Scripts - Uninstaller"

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY-RUN MODE: No changes will be made"
        echo ""
    fi

    if [[ "$UNINSTALL_ALL" == true ]]; then
        run_all
    elif [[ -n "$MODULE" ]]; then
        run_module
    else
        run_interactive
    fi

    print_section "Uninstall Complete"

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY-RUN: No changes were made"
    else
        echo "Some changes require a logout or restart to take full effect."
    fi
}

main
