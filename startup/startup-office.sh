#!/bin/bash
# startup-office.sh
# Launches essential work applications on login.
#
# Installed as a LaunchAgent by modules/desktop.sh:
#   ~/Library/LaunchAgents/com.workstation.startup-office.plist
#
# On Ubuntu this is an autostart .desktop entry; on macOS launchd owns
# login-time execution, so the equivalent is a LaunchAgent plist.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config.yaml"

# Apply IPv6 config (disabled by default to prevent VPN leaks).
# Skipped silently when it needs a sudo password that nobody can type at login.
"$SCRIPT_DIR/../vpn/ipv6-toggle.sh" apply 2>/dev/null \
    || echo "Warning: IPv6 config skipped (needs sudo). Continuing anyway..."

# Try to connect VPN if auto_connect=true in config
"$SCRIPT_DIR/../vpn/vpn-connect.sh" auto-connect \
    || echo "Warning: VPN auto-connect failed. Continuing anyway..."

# Launch apps. `open -g` keeps them from stealing focus during login;
# drop the -g if you want an app to come to the front.
open_if_present() {
    local app="$1"
    if [[ -d "/Applications/$app.app" ]]; then
        open -g -a "$app"
    else
        echo "Skipping $app (not installed)"
    fi
}

open_if_present "PhpStorm"
open_if_present "Slack"
open_if_present "Microsoft Teams"
open_if_present "Google Chrome"
open_if_present "Docker"

# Outlook as a Chrome PWA, matching the Ubuntu setup.
# Replace the app id if yours differs (chrome://apps shows it).
if [[ -d "/Applications/Google Chrome.app" ]]; then
    open -g -a "Google Chrome" --args \
        --profile-directory=Default \
        --app-id=faolnafnngnfdaknnbpnkhgohbobgegn
fi

# Terminal: prefer iTerm2 if installed
if [[ -d "/Applications/iTerm.app" ]]; then
    open -g -a "iTerm"
else
    open -g -a "Terminal"
fi

# Run Docker cleanup in the background once Docker has had time to start
(sleep 15 && "$SCRIPT_DIR/../docker/docker-cleanup.sh") &
