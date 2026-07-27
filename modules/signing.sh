#!/bin/bash
# signing.sh - Signed git commits via SSH key
#
# Reuses ~/.ssh/id_ed25519 as the signing key (git 2.34+, gpg.format=ssh).
# No extra software, no second key to back up, no passphrase prompts.
# GitHub renders these commits as "Verified" exactly like GPG ones.
#
# Configure via config.yaml:  signing: { method: ssh }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SIGNING_METHOD="${SIGNING_METHOD:-ssh}"
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
ALLOWED_SIGNERS="$HOME/.config/git/allowed_signers"

# ============================================
# SSH signing
# ============================================

configure_ssh_signing() {
    print_info "Configuring SSH commit signing..."

    if [[ ! -f "$SSH_KEY_PATH.pub" ]]; then
        print_error "No SSH key at $SSH_KEY_PATH.pub"
        print_info "Run: ./install.sh -m ssh"
        return 1
    fi

    # gpg.format=ssh landed in git 2.34
    local git_version major minor
    git_version=$(git --version | awk '{print $3}')
    major=$(echo "$git_version" | cut -d. -f1)
    minor=$(echo "$git_version" | cut -d. -f2)

    if [[ "$major" -lt 2 ]] || { [[ "$major" -eq 2 ]] && [[ "$minor" -lt 34 ]]; }; then
        print_error "git $git_version is too old for SSH signing (needs 2.34+)"
        print_info "Install a current git: brew install git"
        return 1
    fi

    local email
    email=$(git config --global user.email 2>/dev/null || echo "")
    if [[ -z "$email" ]]; then
        print_error "git user.email is not set - run ./install.sh -m git first"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would set gpg.format=ssh"
        print_info "[DRY-RUN] Would set user.signingkey=$SSH_KEY_PATH.pub"
        print_info "[DRY-RUN] Would enable commit.gpgsign and tag.gpgsign"
        print_info "[DRY-RUN] Would write $ALLOWED_SIGNERS for $email"
        return 0
    fi

    git config --global gpg.format ssh
    git config --global user.signingkey "$SSH_KEY_PATH.pub"
    git config --global commit.gpgsign true
    git config --global tag.gpgsign true

    # Without an allowed_signers file, git can create signatures but cannot
    # verify them locally - `git log --show-signature` reports "No principal
    # matched". GitHub verification works either way; this is for your machine.
    mkdir -p "$(dirname "$ALLOWED_SIGNERS")"

    if [[ -f "$ALLOWED_SIGNERS" ]] && grep -qF "$(cat "$SSH_KEY_PATH.pub")" "$ALLOWED_SIGNERS" 2>/dev/null; then
        print_status "Key already present in allowed_signers"
    else
        printf '%s %s\n' "$email" "$(cat "$SSH_KEY_PATH.pub")" >> "$ALLOWED_SIGNERS"
        print_status "Added key to $ALLOWED_SIGNERS"
    fi

    git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"

    print_status "SSH commit signing enabled"
    print_warning "[MANUAL] Add the SAME key to GitHub a second time, as a Signing key:"
    echo "  https://github.com/settings/ssh/new  ->  Key type: Signing Key"
    echo ""
    echo "  An Authentication key and a Signing key are separate entries on"
    echo "  GitHub even when the key material is identical. Without the"
    echo "  Signing entry your commits push fine but show as Unverified."
}

# ============================================
# Verification
# ============================================

show_signing_status() {
    print_section "Signing Configuration"

    echo "  Format:      $(git config --global gpg.format 2>/dev/null || echo 'Not set')"
    echo "  Signing key: $(git config --global user.signingkey 2>/dev/null || echo 'Not set')"
    echo "  Sign commits: $(git config --global commit.gpgsign 2>/dev/null || echo 'false')"
    echo "  Sign tags:    $(git config --global tag.gpgsign 2>/dev/null || echo 'false')"
    echo "  Allowed signers: $(git config --global gpg.ssh.allowedSignersFile 2>/dev/null || echo 'Not set')"

    echo ""
    print_info "Verify a commit with: git log --show-signature -1"
}

# ============================================
# Main
# ============================================

install_signing() {
    local config_file="${1:-}"

    print_section "Commit Signing"

    if [[ -n "$config_file" && -f "$config_file" ]]; then
        SIGNING_METHOD=$(parse_yaml "$config_file" "signing.method" "$SIGNING_METHOD")
    fi

    print_info "Method: $SIGNING_METHOD"

    case "$SIGNING_METHOD" in
        ssh)
            configure_ssh_signing || return 1
            ;;
        none)
            print_info "Signing disabled in config, skipping"
            return 0
            ;;
        *)
            print_error "Unknown signing method: $SIGNING_METHOD"
            print_info "Valid values: ssh, none"
            return 1
            ;;
    esac

    if [[ "$DRY_RUN" != true ]]; then
        show_signing_status
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_signing "$1"
fi
