#!/bin/bash
# git.sh - Git configuration module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

configure_git_user() {
    print_info "Configuring Git user..."

    local current_name
    local current_email
    current_name=$(git config --global user.name 2>/dev/null || echo "")
    current_email=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -n "$current_name" && -n "$current_email" ]]; then
        print_status "Git user already configured: $current_name <$current_email>"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would prompt for git user.name and user.email"
        return 0
    fi

    if [[ -z "$current_name" ]]; then
        read -p "Enter your full name for Git: " git_name
        git config --global user.name "$git_name"
        print_status "Git user.name set to: $git_name"
    fi

    if [[ -z "$current_email" ]]; then
        read -p "Enter your email for Git: " git_email
        git config --global user.email "$git_email"
        print_status "Git user.email set to: $git_email"
    fi
}

configure_git_defaults() {
    print_info "Configuring Git defaults..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would configure git defaults"
        return 0
    fi

    git config --global init.defaultBranch main
    print_status "Default branch: main"

    if command_exists code; then
        git config --global core.editor "code --wait"
        print_status "Default editor: VS Code"
    elif command_exists vim; then
        git config --global core.editor vim
        print_status "Default editor: vim"
    fi

    git config --global push.autoSetupRemote true
    print_status "Auto-setup remote tracking enabled"

    git config --global pull.rebase false
    print_status "Pull strategy: merge (default)"

    git config --global color.ui auto
    print_status "Color output enabled"

    # macOS-specific: HFS+/APFS is case-insensitive by default, and Finder
    # scatters .DS_Store files through every directory.
    git config --global core.precomposeunicode true
    print_status "Unicode normalisation enabled (macOS filenames)"

    configure_global_gitignore
}

# macOS litters repos with .DS_Store; ignore it globally rather than per-repo
configure_global_gitignore() {
    local ignore_file="$HOME/.gitignore_global"

    if [[ -f "$ignore_file" ]] && grep -q ".DS_Store" "$ignore_file"; then
        print_status "Global gitignore already configured"
        git config --global core.excludesfile "$ignore_file"
        return 0
    fi

    print_info "Creating global gitignore..."

    cat >> "$ignore_file" << 'EOF'
# macOS
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100
.Trashes
EOF

    git config --global core.excludesfile "$ignore_file"
    print_status "Global gitignore configured: $ignore_file"
}

configure_git_aliases() {
    print_info "Configuring Git aliases..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would configure git aliases"
        return 0
    fi

    git config --global alias.st "status"
    git config --global alias.co "checkout"
    git config --global alias.br "branch"
    git config --global alias.ci "commit"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.lg "log --oneline --graph --decorate -10"
    git config --global alias.lga "log --oneline --graph --decorate --all -20"
    git config --global alias.df "diff"
    git config --global alias.dfs "diff --staged"

    print_status "Git aliases configured (st, co, br, ci, lg, df, etc.)"
}

show_git_config() {
    print_section "Current Git Configuration"

    echo "User:"
    echo "  Name:  $(git config --global user.name 2>/dev/null || echo 'Not set')"
    echo "  Email: $(git config --global user.email 2>/dev/null || echo 'Not set')"
    echo ""
    echo "Settings:"
    echo "  Default branch: $(git config --global init.defaultBranch 2>/dev/null || echo 'Not set')"
    echo "  Editor: $(git config --global core.editor 2>/dev/null || echo 'Not set')"
    echo "  Global ignore: $(git config --global core.excludesfile 2>/dev/null || echo 'Not set')"
    echo ""
    echo "Aliases:"
    git config --global --get-regexp alias 2>/dev/null | sed 's/alias\./  /' || echo "  None configured"
}

install_git() {
    print_section "Git Configuration"

    # macOS ships an Xcode-stub git; install a current one via Homebrew
    require_brew && brew_install git

    configure_git_user
    configure_git_defaults
    configure_git_aliases

    if [[ "$DRY_RUN" != true ]]; then
        show_git_config
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_git
fi
