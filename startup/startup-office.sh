#!/bin/bash
# startup-office.sh
# Launches essential work applications on login.
#
# Not installed automatically. To run it at login, register it as a
# LaunchAgent - launchd owns login-time execution on macOS:
#
#   cat > ~/Library/LaunchAgents/com.workstation.startup-office.plist <<EOF
#   <?xml version="1.0" encoding="UTF-8"?>
#   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
#     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#   <plist version="1.0">
#   <dict>
#     <key>Label</key><string>com.workstation.startup-office</string>
#     <key>ProgramArguments</key><array><string>PATH_TO_THIS_SCRIPT</string></array>
#     <key>RunAtLoad</key><true/>
#     <key>StandardOutPath</key><string>/tmp/startup-office.log</string>
#     <key>StandardErrorPath</key><string>/tmp/startup-office.err</string>
#   </dict>
#   </plist>
#   EOF
#   launchctl load ~/Library/LaunchAgents/com.workstation.startup-office.plist

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

open_if_present "Microsoft Outlook"

# Terminal: prefer iTerm2 if installed
if [[ -d "/Applications/iTerm.app" ]]; then
    open -g -a "iTerm"
else
    open -g -a "Terminal"
fi

# Run Docker cleanup in the background once Docker has had time to start
(sleep 15 && "$SCRIPT_DIR/../docker/docker-cleanup.sh") &
