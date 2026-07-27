#!/bin/bash
# ssh.sh - SSH key and agent setup module
#
# macOS differs from Linux here: launchd already runs ssh-agent for every
# session, so there is no need to start one from the shell rc file. Instead
# we lean on the Keychain integration (UseKeychain / --apple-use-keychain)
# so the passphrase is stored once and the key is loaded automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SSH_KEY_TYPE="ed25519"
SSH_KEY_PATH="$HOME/.ssh/id_$SSH_KEY_TYPE"

generate_ssh_key() {
    if [[ -f "$SSH_KEY_PATH" ]]; then
        print_status "SSH key already exists: $SSH_KEY_PATH"
        return 0
    fi

    print_info "Generating SSH key ($SSH_KEY_TYPE)..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would generate SSH key at $SSH_KEY_PATH"
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    local email
    email=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -z "$email" ]]; then
        read -p "Enter your email for SSH key: " email
    fi

    ssh-keygen -t "$SSH_KEY_TYPE" -C "$email" -f "$SSH_KEY_PATH" -N ""

    print_status "SSH key generated: $SSH_KEY_PATH"
}

configure_ssh_config() {
    local ssh_config="$HOME/.ssh/config"

    if [[ -f "$ssh_config" ]] && grep -q "AddKeysToAgent" "$ssh_config"; then
        print_status "SSH config already set up"
        return 0
    fi

    print_info "Configuring SSH client..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would configure ~/.ssh/config"
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # UseKeychain is macOS-only - it stores the passphrase in the login
    # keychain so the key is unlocked automatically after a reboot.
    cat >> "$ssh_config" << EOF

# Global SSH settings
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentitiesOnly yes
    IdentityFile $SSH_KEY_PATH

# GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH

# GitLab
Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile $SSH_KEY_PATH
EOF

    chmod 600 "$ssh_config"
    print_status "SSH config updated: $ssh_config"
}

add_key_to_keychain() {
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        print_warning "No SSH key to add"
        return 0
    fi

    print_info "Adding SSH key to the agent and login keychain..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would run: ssh-add --apple-use-keychain $SSH_KEY_PATH"
        return 0
    fi

    # --apple-use-keychain replaced -K in macOS 12; fall back for older systems
    if ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null; then
        print_status "SSH key added to agent and keychain"
    elif ssh-add -K "$SSH_KEY_PATH" 2>/dev/null; then
        print_status "SSH key added to agent and keychain (legacy -K)"
    else
        print_warning "Could not add key to keychain, adding to agent only"
        ssh-add "$SSH_KEY_PATH" 2>/dev/null || true
    fi
}

show_public_key() {
    local pub_key="$SSH_KEY_PATH.pub"

    if [[ ! -f "$pub_key" ]]; then
        print_warning "No public key found at $pub_key"
        return 1
    fi

    print_section "Your SSH Public Key"
    echo ""
    cat "$pub_key"
    echo ""
    print_info "Add this key to:"
    echo "  GitHub:  https://github.com/settings/ssh/new"
    echo "  GitLab:  https://gitlab.com/-/profile/keys"
    echo ""

    # pbcopy is always available on macOS - no xclip/xsel dance needed
    pbcopy < "$pub_key"
    print_status "Public key copied to clipboard!"
}

install_ssh() {
    print_section "SSH Setup"

    # openssh ships with macOS; no package install needed.
    generate_ssh_key
    configure_ssh_config
    add_key_to_keychain

    if [[ "$DRY_RUN" != true ]]; then
        show_public_key
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_ssh
fi
