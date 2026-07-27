#!/bin/bash
# common.sh - Shared functions for all modules

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Globals
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Print functions
print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_section() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

# Dry run wrapper - executes command only if not in dry run mode
run() {
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would execute: $*"
        return 0
    else
        if [[ "$VERBOSE" == true ]]; then
            print_info "Executing: $*"
        fi
        "$@"
    fi
}

# ============================================
# Platform checks
# ============================================

# Check if running on macOS
check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_error "This script is designed for macOS. Exiting."
        exit 1
    fi
}

# Return "arm64" (Apple Silicon) or "x86_64" (Intel)
mac_arch() {
    uname -m
}

# macOS product version, e.g. 15.2
macos_version() {
    sw_vers -productVersion
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# BSD sed needs an explicit backup suffix for -i; GNU sed does not.
# Usage: sed_inplace 's/foo/bar/' file
sed_inplace() {
    local expr="$1"
    local file="$2"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would edit $file with: $expr"
        return 0
    fi
    sed -i '' "$expr" "$file"
}

# ============================================
# Homebrew helpers
# ============================================

# Homebrew lives in different prefixes depending on architecture
brew_prefix() {
    if [[ "$(mac_arch)" == "arm64" ]]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

# Make brew available in the current shell, even if the profile has not been
# reloaded yet (matters on a fresh machine right after bootstrap).
load_brew_env() {
    local prefix
    prefix="$(brew_prefix)"
    if [[ -x "$prefix/bin/brew" ]]; then
        eval "$("$prefix/bin/brew" shellenv)"
        return 0
    fi
    return 1
}

# Fail loudly if a module needs brew and it is not there
require_brew() {
    if command_exists brew; then
        return 0
    fi
    if load_brew_env; then
        return 0
    fi
    print_error "Homebrew is not installed."
    print_info "Run: ./install.sh -m homebrew"
    return 1
}

brew_installed() {
    brew list --formula "$1" &>/dev/null
}

cask_installed() {
    brew list --cask "$1" &>/dev/null
}

# Install a Homebrew formula (CLI tool) if not present
brew_install() {
    local formula="$1"
    if brew_installed "$formula"; then
        print_status "$formula already installed"
    else
        print_info "Installing $formula..."
        run brew install "$formula"
        print_status "$formula installed"
    fi
}

# Install a Homebrew cask (GUI app) if not present
cask_install() {
    local cask="$1"
    if cask_installed "$cask"; then
        print_status "$cask already installed"
        return 0
    fi

    # A cask can also be installed manually into /Applications - respect that
    # rather than failing or clobbering it.
    local app_name="${2:-}"
    if [[ -n "$app_name" && -d "/Applications/$app_name.app" ]]; then
        print_status "$app_name already present in /Applications (not via brew)"
        return 0
    fi

    print_info "Installing $cask (cask)..."
    run brew install --cask "$cask"
    print_status "$cask installed"
}

# Add a Homebrew tap if not already tapped
tap_add() {
    local tap="$1"
    if brew tap | grep -qx "$tap"; then
        print_status "Tap $tap already added"
    else
        print_info "Adding tap $tap..."
        run brew tap "$tap"
        print_status "Tap $tap added"
    fi
}

# Install a Mac App Store app by numeric id (requires `mas`)
mas_install() {
    local app_id="$1"
    local app_name="${2:-$app_id}"

    if ! command_exists mas; then
        print_warning "mas not installed, skipping $app_name (brew install mas)"
        return 0
    fi

    if mas list | grep -q "^$app_id "; then
        print_status "$app_name already installed"
    else
        print_info "Installing $app_name from the App Store..."
        run mas install "$app_id"
        print_status "$app_name installed"
    fi
}

# ============================================
# macOS defaults helpers
# ============================================

# Write a macOS default, respecting dry-run
# Usage: defaults_set com.apple.dock tilesize int 48
defaults_set() {
    local domain="$1"
    local key="$2"
    local type="$3"
    local value="$4"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would set $domain $key = $value"
        return 0
    fi

    defaults write "$domain" "$key" "-$type" "$value"
}

# Restart an app so defaults take effect (no-op if not running)
restart_app() {
    local app="$1"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would restart $app"
        return 0
    fi
    killall "$app" &>/dev/null || true
}

# ============================================
# Prompts
# ============================================

# Prompt for confirmation (returns 0 for yes, 1 for no)
confirm() {
    local prompt="${1:-Continue?}"
    read -p "$prompt (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ============================================
# Config parsing
# ============================================

# Parse simple YAML config (key: value format)
parse_config() {
    local config_file="$1"
    local key="$2"

    if [[ -f "$config_file" ]]; then
        grep "^${key}:" "$config_file" | sed "s/^${key}:[[:space:]]*//" | tr -d '"' | tr -d "'"
    fi
}

# Parse YAML list items (returns space-separated values)
#
# Note: the obvious `awk "/^section:$/,/^[a-z]/"` range does NOT work here.
# awk tests the end pattern against the same record that opened the range, and
# the header line "apps:" matches both patterns - so the range collapses to
# that single line and no items are ever returned. Track the section with an
# explicit flag instead.
parse_config_list() {
    local config_file="$1"
    local section="$2"

    [[ -f "$config_file" ]] || return 0

    awk -v sec="$section" '
        # Section header: "apps:" with nothing after it
        $0 == sec ":" { inside = 1; next }

        # A new top-level key ends the section (comments/blank lines do not)
        inside && /^[^[:space:]#]/ { inside = 0 }

        # List item: "  - chrome"   (commented-out items are skipped)
        inside && /^[[:space:]]*-[[:space:]]+/ {
            line = $0
            sub(/^[[:space:]]*-[[:space:]]+/, "", line)
            sub(/[[:space:]]*#.*$/, "", line)      # strip trailing comment
            sub(/[[:space:]]+$/, "", line)
            gsub(/["'"'"']/, "", line)
            if (line != "") print line
        }
    ' "$config_file" | tr '\n' ' '
}

# Check if item is in config list
config_has() {
    local config_file="$1"
    local section="$2"
    local item="$3"

    local items
    items=$(parse_config_list "$config_file" "$section")
    [[ " $items " == *" $item "* ]]
}

# Parse nested YAML value (e.g., "vpn.provider" for vpn: provider: value)
# Usage: parse_yaml config.yaml "vpn.provider" "default_value"
parse_yaml() {
    local config_file="$1"
    local key_path="$2"
    local default="${3:-}"

    if [[ ! -f "$config_file" ]]; then
        echo "$default"
        return
    fi

    # Split key path (e.g., "vpn.provider" -> "vpn" and "provider")
    local section="${key_path%%.*}"
    local key="${key_path#*.}"

    # If no dot in path, use simple parse
    if [[ "$section" == "$key" ]]; then
        local value
        value=$(parse_config "$config_file" "$key")
        echo "${value:-$default}"
        return
    fi

    # Parse nested value - find section, then find key within it
    local value
    value=$(sed -n "/^${section}:\$/,/^[a-zA-Z_]/p" "$config_file" \
        | grep "^  ${key}:" \
        | head -1 \
        | sed "s/^  ${key}:[[:space:]]*//" \
        | tr -d '"' | tr -d "'")

    echo "${value:-$default}"
}
