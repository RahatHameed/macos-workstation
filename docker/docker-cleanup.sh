#!/bin/bash
# docker-cleanup.sh - Clear port conflicts, stale Docker state and disk (macOS)
#
# DIFFERENCE FROM THE UBUNTU VERSION:
# On Linux, docker-proxy runs on the host and orphaned copies hold ports open
# after a crash - so the Ubuntu script pkills them. On macOS containers run
# inside a Linux VM, so there is no host-side docker-proxy to kill. What holds
# a port here is either Docker Desktop's own networking process
# (com.docker.backend / vpnkit) or an unrelated host process.
#
# This script therefore diagnoses the port conflict instead of blindly killing,
# then prunes stale Docker state.
#
# The disk flags also matter more on macOS: containers live inside a VM backed
# by a sparse disk image (Docker.raw / colima's diffdisk). Pruning frees space
# inside the VM, but the host image only shrinks once the VM TRIMs it back - so
# --prune-cache reports the host image size before and after.
#
# Runs on every login via startup-office.sh, so the default is non-destructive
# and never prompts. Everything that deletes data is opt-in.
#
# Usage:
#   ./docker-cleanup.sh                     Prune networks, report port holders
#   ./docker-cleanup.sh --ports 80,443,3306 Check specific ports
#   ./docker-cleanup.sh --remove-containers  Also force-remove ALL containers
#   ./docker-cleanup.sh --prune-cache        Also clear build cache, dangling
#                                            images and stopped containers
#   ./docker-cleanup.sh --prune-all          As above, plus ALL unused images
#                                            and a full builder cache wipe
#   ./docker-cleanup.sh --volumes            Also remove unused volumes - DATA LOSS
#   ./docker-cleanup.sh --dry-run            Report only, delete nothing
#   ./docker-cleanup.sh --yes                Skip the confirmation prompt

LOG_FILE="/tmp/docker-cleanup.log"
REMOVE_CONTAINERS=false
PRUNE_CACHE=false
PRUNE_ALL=false
PRUNE_VOLUMES=false
DRY_RUN=false
ASSUME_YES=false
PORTS="80,443,3306,5432,6379,8080,8081,9000"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-containers)
            REMOVE_CONTAINERS=true
            shift
            ;;
        --prune-cache)
            PRUNE_CACHE=true
            shift
            ;;
        --prune-all)
            PRUNE_CACHE=true
            PRUNE_ALL=true
            shift
            ;;
        --volumes)
            PRUNE_CACHE=true
            PRUNE_VOLUMES=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        --ports)
            PORTS="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "Starting Docker cleanup (containers=$REMOVE_CONTAINERS cache=$PRUNE_CACHE all=$PRUNE_ALL volumes=$PRUNE_VOLUMES dry-run=$DRY_RUN)"

# ============================================
# Wait for the Docker daemon
# ============================================

RETRIES=30
while [ $RETRIES -gt 0 ]; do
    if docker info &>/dev/null; then
        log "Docker daemon is ready"
        break
    fi
    sleep 1
    RETRIES=$((RETRIES - 1))
done

if [ $RETRIES -eq 0 ]; then
    log "Docker daemon not ready after 30s"
    echo "Docker daemon is not running - start Docker Desktop or 'colima start'"
    exit 1
fi

# ============================================
# Report what is holding common ports
# ============================================

CONFLICTS=0
IFS=',' read -ra PORT_LIST <<< "$PORTS"

for port in "${PORT_LIST[@]}"; do
    port="$(echo "$port" | tr -d '[:space:]')"
    [[ -z "$port" ]] && continue

    holder=$(lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | awk 'NR==2 {print $1" (pid "$2")"}')

    if [[ -n "$holder" ]]; then
        # Docker's own listeners are expected; anything else is the conflict
        case "$holder" in
            com.docke*|vpnkit*|docker*)
                ;;
            *)
                echo "Port $port is held by $holder"
                log "Port conflict on $port: $holder"
                CONFLICTS=$((CONFLICTS + 1))
                ;;
        esac
    fi
done

# ============================================
# Confirm the destructive work
# ============================================

# The VM disk image lives under ~/Library (Docker Desktop) or ~/.colima.
vm_image_size() {
    local candidates=(
        "$HOME/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw"
        "$HOME/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw"
        "$HOME/.colima/default/diffdisk"
    )

    local path
    for path in "${candidates[@]}"; do
        if [[ -f "$path" ]]; then
            # -m reports blocks actually used, not the sparse apparent size
            echo "$(du -m "$path" 2>/dev/null | awk '{print $1}')M  $path"
            return
        fi
    done
}

DESTRUCTIVE=()
[[ "$REMOVE_CONTAINERS" == true ]] && DESTRUCTIVE+=("ALL containers, running included")
[[ "$PRUNE_CACHE" == true ]] && DESTRUCTIVE+=("build cache, dangling images, stopped containers")
[[ "$PRUNE_ALL" == true ]] && DESTRUCTIVE+=("ALL unused images")
[[ "$PRUNE_VOLUMES" == true ]] && DESTRUCTIVE+=("unused volumes (DATA LOSS)")

if [[ "$PRUNE_CACHE" == true ]]; then
    echo "Current Docker disk usage:"
    docker system df
    VM_BEFORE="$(vm_image_size)"
    [[ -n "$VM_BEFORE" ]] && echo "VM disk image: $VM_BEFORE"
    echo
fi

if [[ "$DRY_RUN" == true ]]; then
    if [[ ${#DESTRUCTIVE[@]} -gt 0 ]]; then
        echo "[DRY-RUN] Would remove:"
        printf '  - %s\n' "${DESTRUCTIVE[@]}"
    fi
    echo "[DRY-RUN] Would prune unused networks"
    echo "[DRY-RUN] Nothing was deleted."
    log "Dry run completed"
    exit 0
fi

# Prompt only when a human is watching. A non-TTY caller (startup-office.sh,
# cron, CI) passed the flags deliberately and must not block on stdin.
if [[ ${#DESTRUCTIVE[@]} -gt 0 && "$ASSUME_YES" != true && -t 0 ]]; then
    echo "About to remove:"
    printf '  - %s\n' "${DESTRUCTIVE[@]}"
    read -r -p "Continue? [y/N] " reply
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        log "Aborted by user"
        exit 0
    fi
fi

# ============================================
# Prune stale state
# ============================================

# Force-remove containers first: it frees the images they pin, so a following
# prune can actually reclaim them.
if [[ "$REMOVE_CONTAINERS" == true ]]; then
    CONTAINERS=$(docker ps -aq 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        echo "Removing all containers (--remove-containers)..."
        log "Removing all containers: $CONTAINERS"
        docker rm -f $CONTAINERS &>/dev/null
    fi
fi

if [[ "$PRUNE_CACHE" == false ]]; then
    # Default path: networks only, nothing that costs data.
    docker network prune -f &>/dev/null
    log "Pruned unused networks"
else
    # system prune covers networks too, so it replaces the call above.
    PRUNE_ARGS=(-f)
    [[ "$PRUNE_ALL" == true ]] && PRUNE_ARGS+=(-a)
    [[ "$PRUNE_VOLUMES" == true ]] && PRUNE_ARGS+=(--volumes)

    echo "Pruning..."
    if OUTPUT=$(docker system prune "${PRUNE_ARGS[@]}" 2>&1); then
        echo "$OUTPUT" | tail -1
        log "system prune: $(echo "$OUTPUT" | tail -1)"
    else
        echo "docker system prune failed:"
        echo "$OUTPUT"
        log "system prune failed: $OUTPUT"
        exit 1
    fi

    # Backstop: `system prune -a` already clears the default builder's cache, so
    # this is usually a 0B no-op. It earns its place for buildx builders using
    # the docker-container driver, whose cache lives outside the daemon's own
    # accounting and survives system prune.
    if [[ "$PRUNE_ALL" == true ]]; then
        if BUILDER_OUTPUT=$(docker builder prune -af 2>&1); then
            echo "$BUILDER_OUTPUT" | tail -1
            log "builder prune: $(echo "$BUILDER_OUTPUT" | tail -1)"
        else
            # Alternate/older builders may not support this - not fatal
            log "builder prune unavailable: $BUILDER_OUTPUT"
        fi
    fi
fi

log "Docker cleanup completed"

# ============================================
# Summary
# ============================================

if [[ "$PRUNE_CACHE" == true ]]; then
    echo
    echo "Remaining Docker disk usage:"
    docker system df

    VM_AFTER="$(vm_image_size)"
    if [[ -n "$VM_AFTER" ]]; then
        echo
        echo "VM disk image before: $VM_BEFORE"
        echo "VM disk image after:  $VM_AFTER"
        echo "If the image did not shrink, macOS has not reclaimed the sparse blocks yet."
        echo "Restarting Docker Desktop (or 'colima stop && colima start') triggers the TRIM."
    fi
    echo
fi

if [ "$CONFLICTS" -gt 0 ]; then
    echo "Docker cleanup completed - $CONFLICTS non-Docker process(es) holding common ports (see above)"
    echo "Stop the listed process, or change the port mapping in your compose file."
else
    echo "Docker cleanup completed - no port conflicts found"
fi
