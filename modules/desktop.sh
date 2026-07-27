#!/bin/bash
# desktop.sh - macOS desktop customization
#
# The Ubuntu repo installs Plank to imitate a macOS dock. Here the real Dock
# is already present, so this module configures it via `defaults write`
# instead, along with Finder, the keyboard, and screenshot behaviour.
#
# Every change is a documented `defaults` key and is reverted by
# uninstall.sh, so nothing here is one-way.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================
# Dock
# ============================================

configure_dock() {
    local config_file="${1:-}"

    print_info "Configuring the Dock..."

    local tile_size=48
    local autohide=true

    if [[ -n "$config_file" && -f "$config_file" ]]; then
        tile_size=$(parse_yaml "$config_file" "desktop.dock_size" "$tile_size")
        autohide=$(parse_yaml "$config_file" "desktop.dock_autohide" "$autohide")
    fi

    defaults_set com.apple.dock tilesize int "$tile_size"
    defaults_set com.apple.dock autohide bool "$autohide"

    # Remove the show/hide animation delay - the single biggest perceived
    # speed-up on a machine with autohide enabled.
    defaults_set com.apple.dock autohide-delay float 0
    defaults_set com.apple.dock autohide-time-modifier float 0.4

    # Scale is less distracting than the genie effect
    defaults_set com.apple.dock mineffect string scale

    # Minimise windows into their app icon rather than a separate Dock slot
    defaults_set com.apple.dock minimize-to-application bool true

    # Do not clutter the Dock with recently used apps
    defaults_set com.apple.dock show-recents bool false

    # Show a dot under running apps
    defaults_set com.apple.dock show-process-indicators bool true

    restart_app Dock
    print_status "Dock configured (size=$tile_size, autohide=$autohide)"
}

# ============================================
# Finder
# ============================================

configure_finder() {
    print_info "Configuring Finder..."

    # Show all filename extensions - hiding them is a security foot-gun
    defaults_set NSGlobalDomain AppleShowAllExtensions bool true

    # Show hidden files
    defaults_set com.apple.finder AppleShowAllFiles bool true

    # Path bar and status bar
    defaults_set com.apple.finder ShowPathbar bool true
    defaults_set com.apple.finder ShowStatusBar bool true

    # Default to list view (Nlsv). Others: icnv, clmv, glyv
    defaults_set com.apple.finder FXPreferredViewStyle string Nlsv

    # Search the current folder by default instead of the whole Mac
    defaults_set com.apple.finder FXDefaultSearchScope string SCcf

    # Skip the warning when changing a file extension
    defaults_set com.apple.finder FXEnableExtensionChangeWarning bool false

    # Keep folders on top when sorting by name
    defaults_set com.apple.finder _FXSortFoldersFirst bool true

    # Do not write .DS_Store files to network or USB volumes
    defaults_set com.apple.desktopservices DSDontWriteNetworkStores bool true
    defaults_set com.apple.desktopservices DSDontWriteUSBStores bool true

    # Show the full POSIX path in the window title
    defaults_set com.apple.finder _FXShowPosixPathInTitle bool true

    restart_app Finder
    print_status "Finder configured"
}

# ============================================
# Keyboard and input
# ============================================

configure_keyboard() {
    print_info "Configuring keyboard..."

    # Fast key repeat - the default is sluggish for terminal work.
    # KeyRepeat=2 is ~30ms; InitialKeyRepeat=15 is ~225ms.
    defaults_set NSGlobalDomain KeyRepeat int 2
    defaults_set NSGlobalDomain InitialKeyRepeat int 15

    # Disable press-and-hold for accent characters so key repeat works in
    # editors (Vim motions in particular).
    defaults_set NSGlobalDomain ApplePressAndHoldEnabled bool false

    # Turn off text "corrections" that mangle code and commit messages
    defaults_set NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled bool false
    defaults_set NSGlobalDomain NSAutomaticDashSubstitutionEnabled bool false
    defaults_set NSGlobalDomain NSAutomaticCapitalizationEnabled bool false
    defaults_set NSGlobalDomain NSAutomaticSpellingCorrectionEnabled bool false
    defaults_set NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled bool false

    # Full keyboard access: Tab moves between all controls, not just text boxes
    defaults_set NSGlobalDomain AppleKeyboardUIMode int 3

    print_status "Keyboard configured"
}

# ============================================
# Screenshots
# ============================================

configure_screenshots() {
    local config_file="${1:-}"

    print_info "Configuring screenshots..."

    local screenshot_dir="$HOME/Screenshots"

    if [[ -n "$config_file" && -f "$config_file" ]]; then
        local configured
        configured=$(parse_yaml "$config_file" "desktop.screenshot_dir" "")
        [[ -n "$configured" ]] && screenshot_dir="${configured/#\~/$HOME}"
    fi

    run mkdir -p "$screenshot_dir"

    defaults_set com.apple.screencapture location string "$screenshot_dir"
    defaults_set com.apple.screencapture type string png

    # Drop the drop-shadow around window captures
    defaults_set com.apple.screencapture disable-shadow bool true

    restart_app SystemUIServer
    print_status "Screenshots saved to $screenshot_dir"
}

# ============================================
# Misc system behaviour
# ============================================

configure_system() {
    print_info "Configuring system behaviour..."

    # Expand the save and print panels by default
    defaults_set NSGlobalDomain NSNavPanelExpandedStateForSaveMode bool true
    defaults_set NSGlobalDomain PMPrintingExpandedStateForPrint bool true

    # Save to disk by default rather than iCloud
    defaults_set NSGlobalDomain NSDocumentSaveNewDocumentsToCloud bool false

    # Disable the "Are you sure you want to open this application?" dialog
    defaults_set com.apple.LaunchServices LSQuarantine bool false

    # Show battery percentage
    defaults_set com.apple.menuextra.battery ShowPercent bool true

    print_status "System behaviour configured"
}

# ============================================
# Fonts and window management
# ============================================

install_fonts() {
    print_info "Installing fonts..."

    require_brew || return 0

    # homebrew/cask-fonts was merged into homebrew/cask in 2023, so these
    # need no extra tap.
    cask_install "font-inter"
    cask_install "font-jetbrains-mono"
    cask_install "font-fira-code"

    print_status "Fonts installed"
}

install_window_manager() {
    print_info "Installing window manager..."

    require_brew || return 0

    cask_install "rectangle" "Rectangle"

    print_warning "[MANUAL] Grant Rectangle accessibility permissions:"
    echo "  System Settings > Privacy & Security > Accessibility"
}

# ============================================
# Login items
# ============================================

configure_startup_apps() {
    print_info "Configuring login items..."

    local startup_script="$SCRIPT_DIR/../startup/startup-office.sh"
    local plist="$HOME/Library/LaunchAgents/com.workstation.startup-office.plist"

    if [[ ! -f "$startup_script" ]]; then
        print_warning "startup-office.sh not found, skipping login item setup"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would create LaunchAgent at $plist"
        return 0
    fi

    mkdir -p "$HOME/Library/LaunchAgents"

    # A LaunchAgent is the macOS equivalent of ~/.config/autostart/*.desktop
    cat > "$plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.workstation.startup-office</string>
    <key>ProgramArguments</key>
    <array>
        <string>$startup_script</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/startup-office.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/startup-office.err</string>
</dict>
</plist>
EOF

    chmod +x "$startup_script"

    # Reload so the change takes effect without a logout
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist" 2>/dev/null || true

    print_status "Login item configured: $plist"
    print_info "Disable with: launchctl unload $plist"
}

# ============================================
# Main
# ============================================

install_desktop() {
    local config_file="${1:-}"

    print_section "Desktop Customization"

    configure_dock "$config_file"
    configure_finder
    configure_keyboard
    configure_screenshots "$config_file"
    configure_system
    install_fonts
    install_window_manager
    configure_startup_apps

    print_status "Desktop customization complete"
    print_warning "Some changes need a logout or restart to fully apply"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_desktop "$1"
fi
