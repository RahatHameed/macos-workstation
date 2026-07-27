#!/bin/bash
# docker.sh - Docker module
#
# There is no native Docker Engine on macOS: containers always run inside a
# Linux VM. Two runtimes are supported here.
#
#   docker-desktop  Official app. GUI, Kubernetes, easiest. Requires a paid
#                   licence for larger companies.
#   colima          Open-source Lima VM + the docker CLI. No GUI, no licence.
#
# Choose via config.yaml:  docker: { runtime: docker-desktop }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DOCKER_RUNTIME="${DOCKER_RUNTIME:-docker-desktop}"

# ============================================
# Docker Desktop
# ============================================

install_docker_desktop() {
    if [[ -d "/Applications/Docker.app" ]]; then
        print_status "Docker Desktop already installed"
        return 0
    fi

    print_info "Installing Docker Desktop..."

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would install the docker-desktop cask"
        return 0
    fi

    # Homebrew renamed the cask from `docker` to `docker-desktop` in 2025.
    # Try the current name, fall back to the old one on older Homebrew.
    if brew install --cask docker-desktop 2>/dev/null; then
        print_status "Docker Desktop installed"
    elif brew install --cask docker 2>/dev/null; then
        print_status "Docker Desktop installed (legacy cask name)"
    else
        print_error "Could not install Docker Desktop"
        return 1
    fi

    print_warning "Launch Docker.app once to finish setup and grant privileges"
}

# ============================================
# Colima (lightweight alternative)
# ============================================

install_colima() {
    print_info "Installing Colima + Docker CLI..."

    brew_install colima
    brew_install docker
    brew_install docker-compose
    brew_install docker-buildx

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would start the colima VM"
        return 0
    fi

    if colima status &>/dev/null; then
        print_status "Colima VM already running"
    else
        print_info "Starting the Colima VM (first start takes a minute)..."
        colima start --cpu 4 --memory 8 --disk 60
        print_status "Colima VM started"
    fi

    # The Homebrew docker CLI does not pick up plugins automatically
    configure_docker_cli_plugins
}

configure_docker_cli_plugins() {
    local plugin_dir="$HOME/.docker/cli-plugins"
    local prefix
    prefix="$(brew_prefix)"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY-RUN] Would link compose and buildx into $plugin_dir"
        return 0
    fi

    mkdir -p "$plugin_dir"

    [[ -x "$prefix/bin/docker-compose" ]] && \
        ln -sf "$prefix/bin/docker-compose" "$plugin_dir/docker-compose"
    [[ -x "$prefix/bin/docker-buildx" ]] && \
        ln -sf "$prefix/bin/docker-buildx" "$plugin_dir/docker-buildx"

    print_status "Docker CLI plugins linked"
}

# ============================================
# Main
# ============================================

install_docker() {
    local config_file="${1:-}"

    print_section "Docker Setup"

    require_brew || return 1

    if [[ -n "$config_file" && -f "$config_file" ]]; then
        DOCKER_RUNTIME=$(parse_yaml "$config_file" "docker.runtime" "$DOCKER_RUNTIME")
    fi

    print_info "Runtime: $DOCKER_RUNTIME"

    case "$DOCKER_RUNTIME" in
        docker-desktop)
            install_docker_desktop
            ;;
        colima)
            install_colima
            ;;
        *)
            print_error "Unknown docker runtime: $DOCKER_RUNTIME"
            print_info "Valid values: docker-desktop, colima"
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_docker "$1"
fi
