#!/bin/bash
# apps.sh - Work applications installation module
#
# Everything here goes through Homebrew Cask. The second argument to
# cask_install is the /Applications bundle name, so an app that was already
# installed by hand is detected instead of being reinstalled.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================
# Individual app installers
# ============================================

install_chrome() {
    cask_install "google-chrome" "Google Chrome"
}

install_slack() {
    cask_install "slack" "Slack"
}

install_teams() {
    cask_install "microsoft-teams" "Microsoft Teams"
}

# Note: a .pkg cask, so it needs sudo and cannot install unattended.
install_outlook() {
    cask_install "microsoft-outlook" "Microsoft Outlook"
}

install_jetbrains_toolbox() {
    cask_install "jetbrains-toolbox" "JetBrains Toolbox"
    print_info "Use Toolbox to install PhpStorm, IntelliJ, etc."
}

install_vscode() {
    cask_install "visual-studio-code" "Visual Studio Code"
}

install_spotify() {
    cask_install "spotify" "Spotify"
}

install_discord() {
    cask_install "discord" "Discord"
}

install_zoom() {
    cask_install "zoom" "zoom.us"
}

install_postman() {
    cask_install "postman" "Postman"
}

install_dbeaver() {
    cask_install "dbeaver-community" "DBeaver"
}

install_rectangle() {
    cask_install "rectangle" "Rectangle"
    print_info "Rectangle: window snapping via keyboard shortcuts"
}

install_iterm() {
    cask_install "iterm2" "iTerm"
}

install_raycast() {
    cask_install "raycast" "Raycast"
    print_info "Raycast: Spotlight replacement / launcher"
}

# Screen sharing: macOS has a built-in VNC server (Screen Sharing), so unlike
# the Ubuntu repo there is nothing to install - it just needs enabling.
enable_screen_sharing() {
    print_info "macOS has a built-in VNC server (Screen Sharing)."
    print_warning "[MANUAL] Enable it in System Settings > General > Sharing > Screen Sharing"
    print_info "Connect with: vnc://$(hostname)"
}

# ============================================
# Main function
# ============================================

install_apps() {
    local config_file="${1:-}"

    print_section "Installing Work Applications"

    require_brew || return 1

    if [[ -n "$config_file" && -f "$config_file" ]]; then
        # Install only apps specified in config
        config_has "$config_file" "apps" "chrome" && install_chrome
        config_has "$config_file" "apps" "slack" && install_slack
        config_has "$config_file" "apps" "teams" && install_teams
        config_has "$config_file" "apps" "outlook" && install_outlook
        config_has "$config_file" "apps" "jetbrains-toolbox" && install_jetbrains_toolbox
        config_has "$config_file" "apps" "vscode" && install_vscode
        config_has "$config_file" "apps" "discord" && install_discord
        config_has "$config_file" "apps" "zoom" && install_zoom
        config_has "$config_file" "apps" "postman" && install_postman
        config_has "$config_file" "apps" "spotify" && install_spotify
        config_has "$config_file" "apps" "dbeaver" && install_dbeaver
        config_has "$config_file" "apps" "rectangle" && install_rectangle
        config_has "$config_file" "apps" "iterm2" && install_iterm
        config_has "$config_file" "apps" "raycast" && install_raycast
        config_has "$config_file" "apps" "screen-sharing" && enable_screen_sharing
    else
        # Default: install core work apps only
        install_chrome
        install_slack
        install_teams
        install_outlook
        install_jetbrains_toolbox
    fi

    # Surface anything that failed, without having aborted the whole run
    report_cask_failures || true

    return 0
}

# ============================================
# Interactive selection
# ============================================

install_apps_interactive() {
    print_section "Select Applications to Install"

    require_brew || return 1

    local apps=()

    confirm "Install Google Chrome?" && apps+=("chrome")
    confirm "Install Slack?" && apps+=("slack")
    confirm "Install Microsoft Teams?" && apps+=("teams")
    confirm "Install Microsoft Outlook?" && apps+=("outlook")
    confirm "Install JetBrains Toolbox?" && apps+=("jetbrains-toolbox")
    confirm "Install VS Code?" && apps+=("vscode")
    confirm "Install Spotify?" && apps+=("spotify")
    confirm "Install Discord?" && apps+=("discord")
    confirm "Install Zoom?" && apps+=("zoom")
    confirm "Install Postman?" && apps+=("postman")
    confirm "Install DBeaver?" && apps+=("dbeaver")
    confirm "Install Rectangle (window manager)?" && apps+=("rectangle")
    confirm "Install iTerm2?" && apps+=("iterm2")
    confirm "Install Raycast?" && apps+=("raycast")

    echo ""

    # Guard against an empty array - bash 3.2 errors on "${arr[@]}" when unset
    if [[ ${#apps[@]} -eq 0 ]]; then
        print_info "No applications selected"
        return 0
    fi

    local app
    for app in "${apps[@]}"; do
        case "$app" in
            chrome) install_chrome ;;
            slack) install_slack ;;
            teams) install_teams ;;
            outlook) install_outlook ;;
            jetbrains-toolbox) install_jetbrains_toolbox ;;
            vscode) install_vscode ;;
            spotify) install_spotify ;;
            discord) install_discord ;;
            zoom) install_zoom ;;
            postman) install_postman ;;
            dbeaver) install_dbeaver ;;
            rectangle) install_rectangle ;;
            iterm2) install_iterm ;;
            raycast) install_raycast ;;
        esac
    done

    report_cask_failures || true
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "-i" || "$1" == "--interactive" ]]; then
        install_apps_interactive
    else
        install_apps "$1"
    fi
fi
