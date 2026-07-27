#!/bin/bash
# install.sh - Main installer for macOS Setup Scripts
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/RahatHameed/macos-workstation/main/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/RahatHameed/macos-workstation.git
#   cd macos-workstation
#   ./install.sh
#
# Options:
#   -h, --help          Show help
#   -i, --interactive   Interactive mode (prompts for each option)
#   -c, --config FILE   Use custom config file
#   -m, --module NAME   Install specific module only
#   --dry-run           Show what would be installed without making changes
#   --claude            Include Claude Code installation

set -e

# ============================================
# Setup
# ============================================
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/RahatHameed/macos-workstation"
CLONE_DIR="$HOME/.macos-setup-scripts"

# Check if running from curl pipe
if [[ ! -f "$ROOT_DIR/modules/common.sh" ]]; then
    echo "Downloading macos-setup-scripts..."
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR"
    cd "$CLONE_DIR"
    ROOT_DIR="$CLONE_DIR"
fi

source "$ROOT_DIR/modules/common.sh"

# ============================================
# Defaults
# ============================================
INTERACTIVE=false
CONFIG_FILE=""
MODULE=""
DRY_RUN=false
INSTALL_CLAUDE=false

# ============================================
# Parse arguments
# ============================================
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "macOS Setup Scripts - Automated workstation setup"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -h, --help          Show this help message"
            echo "  -i, --interactive   Interactive mode (prompts for each option)"
            echo "  -c, --config FILE   Use custom config file"
            echo "  -m, --module NAME   Install specific module only"
            echo "                      Modules: homebrew, shell, git, ssh, apps, docker, desktop, vpn, all"
            echo "  --dry-run           Show what would be installed"
            echo "  --claude            Include Claude Code installation"
            echo ""
            echo "Examples:"
            echo "  $0                      # Install all with defaults"
            echo "  $0 -i                   # Interactive mode"
            echo "  $0 -m homebrew          # Bootstrap Homebrew only"
            echo "  $0 -m shell             # Install only Zsh + Oh My Zsh"
            echo "  $0 -c config.yaml       # Use custom config"
            echo "  $0 --dry-run            # Preview changes"
            echo ""
            echo "Quick install:"
            echo "  curl -fsSL https://raw.githubusercontent.com/RahatHameed/macos-workstation/main/install.sh | bash"
            exit 0
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -m|--module)
            MODULE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            export DRY_RUN
            shift
            ;;
        --claude)
            INSTALL_CLAUDE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

export CONFIG_FILE

# ============================================
# Pre-flight checks
# ============================================
check_macos

print_section "macOS Setup Scripts"
echo "This script will set up your macOS workstation."
echo "  macOS:        $(macos_version)"
echo "  Architecture: $(mac_arch)"
echo "  Homebrew:     $(brew_prefix)"

if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY-RUN MODE: No changes will be made"
    echo ""
fi

# Homebrew underpins every other module, so make sure it is loaded if present
load_brew_env 2>/dev/null || true

# ============================================
# Interactive mode
# ============================================
run_interactive() {
    print_section "Interactive Setup"

    local modules=()

    confirm "Bootstrap Homebrew + Xcode CLT?" && modules+=("homebrew")
    confirm "Install Zsh + Oh My Zsh?" && modules+=("shell")
    confirm "Configure Git (user, aliases)?" && modules+=("git")
    confirm "Setup SSH key + keychain?" && modules+=("ssh")
    confirm "Install work applications?" && modules+=("apps")
    confirm "Install Docker?" && modules+=("docker")
    confirm "Apply macOS desktop settings (Dock, Finder, keyboard)?" && modules+=("desktop")
    confirm "Install VPN client?" && modules+=("vpn")

    echo ""

    if [[ ${#modules[@]} -gt 0 ]]; then
        local mod
        for mod in "${modules[@]}"; do
            case "$mod" in
                homebrew) source "$ROOT_DIR/modules/homebrew.sh" && install_homebrew_module ;;
                shell) source "$ROOT_DIR/modules/shell.sh" && install_shell ;;
                git) source "$ROOT_DIR/modules/git.sh" && install_git ;;
                ssh) source "$ROOT_DIR/modules/ssh.sh" && install_ssh ;;
                apps) source "$ROOT_DIR/modules/apps.sh" && install_apps_interactive ;;
                docker) source "$ROOT_DIR/modules/docker.sh" && install_docker "$CONFIG_FILE" ;;
                desktop) source "$ROOT_DIR/modules/desktop.sh" && install_desktop "$CONFIG_FILE" ;;
                vpn) source "$ROOT_DIR/modules/vpn.sh" && install_vpn "$CONFIG_FILE" ;;
            esac
        done
    fi

    if confirm "Install Claude Code?"; then
        install_claude_cli
    fi
}

# ============================================
# Install specific module
# ============================================
run_module() {
    local module="$1"

    case "$module" in
        homebrew)
            source "$ROOT_DIR/modules/homebrew.sh"
            install_homebrew_module
            ;;
        shell)
            source "$ROOT_DIR/modules/shell.sh"
            install_shell
            ;;
        git)
            source "$ROOT_DIR/modules/git.sh"
            install_git
            ;;
        ssh)
            source "$ROOT_DIR/modules/ssh.sh"
            install_ssh
            ;;
        apps)
            source "$ROOT_DIR/modules/apps.sh"
            install_apps "$CONFIG_FILE"
            ;;
        docker)
            source "$ROOT_DIR/modules/docker.sh"
            install_docker "$CONFIG_FILE"
            ;;
        desktop)
            source "$ROOT_DIR/modules/desktop.sh"
            install_desktop "$CONFIG_FILE"
            ;;
        vpn)
            source "$ROOT_DIR/modules/vpn.sh"
            install_vpn "$CONFIG_FILE"
            ;;
        all)
            run_all
            ;;
        *)
            print_error "Unknown module: $module"
            echo "Available modules: homebrew, shell, git, ssh, apps, docker, desktop, vpn, all"
            exit 1
            ;;
    esac
}

# ============================================
# Install all modules
# ============================================
run_all() {
    # Homebrew first - everything below depends on it
    source "$ROOT_DIR/modules/homebrew.sh"
    install_homebrew_module

    source "$ROOT_DIR/modules/shell.sh"
    install_shell

    source "$ROOT_DIR/modules/git.sh"
    install_git

    source "$ROOT_DIR/modules/ssh.sh"
    install_ssh

    source "$ROOT_DIR/modules/apps.sh"
    install_apps "$CONFIG_FILE"

    source "$ROOT_DIR/modules/docker.sh"
    install_docker "$CONFIG_FILE"

    source "$ROOT_DIR/modules/desktop.sh"
    install_desktop "$CONFIG_FILE"

    source "$ROOT_DIR/modules/vpn.sh"
    install_vpn "$CONFIG_FILE"
}

# ============================================
# Claude Code installation
# ============================================
install_claude_cli() {
    if command_exists claude; then
        print_status "Claude Code already installed"
        return 0
    fi

    print_info "Installing Claude Code..."
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install Claude Code"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        print_warning "Run 'claude' to authenticate"
    fi
    print_status "Claude Code installed"
}

# ============================================
# Main
# ============================================
main() {
    if [[ "$INTERACTIVE" == true ]]; then
        run_interactive
    elif [[ -n "$MODULE" ]]; then
        run_module "$MODULE"
    else
        run_all
    fi

    # Optional: Claude Code
    if [[ "$INSTALL_CLAUDE" == true ]]; then
        install_claude_cli
    fi

    # Summary
    print_section "Setup Complete!"

    echo "Installed components:"
    [[ -z "$MODULE" || "$MODULE" == "homebrew" || "$MODULE" == "all" ]] && echo "  - Homebrew + Xcode CLT"
    [[ -z "$MODULE" || "$MODULE" == "shell" || "$MODULE" == "all" ]] && echo "  - Zsh + Oh My Zsh"
    [[ -z "$MODULE" || "$MODULE" == "git" || "$MODULE" == "all" ]] && echo "  - Git configuration"
    [[ -z "$MODULE" || "$MODULE" == "ssh" || "$MODULE" == "all" ]] && echo "  - SSH key + keychain"
    [[ -z "$MODULE" || "$MODULE" == "apps" || "$MODULE" == "all" ]] && echo "  - Work applications"
    [[ -z "$MODULE" || "$MODULE" == "docker" || "$MODULE" == "all" ]] && echo "  - Docker"
    [[ -z "$MODULE" || "$MODULE" == "desktop" || "$MODULE" == "all" ]] && echo "  - macOS desktop settings"
    [[ -z "$MODULE" || "$MODULE" == "vpn" || "$MODULE" == "all" ]] && echo "  - VPN client"

    echo ""
    echo "Next steps:"
    echo "  1. Open a new terminal for shell and PATH changes to take effect"
    echo "  2. Grant accessibility permissions to Rectangle (System Settings > Privacy & Security)"
    echo "  3. Launch Docker.app once to finish its setup"
    echo "  4. Add your SSH key to GitHub (it is already on your clipboard)"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY-RUN: No changes were made"
    fi
}

main
