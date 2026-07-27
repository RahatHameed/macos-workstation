#!/bin/bash
# docker-cleanup.sh - Clear port conflicts and stale Docker state (macOS)
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
# Usage:
#   ./docker-cleanup.sh                     Prune networks, report port holders
#   ./docker-cleanup.sh --remove-containers Also force-remove ALL containers
#   ./docker-cleanup.sh --ports 80,443,3306 Check specific ports

LOG_FILE="/tmp/docker-cleanup.log"
REMOVE_CONTAINERS=false
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
        --ports)
            PORTS="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log "Starting Docker cleanup..."

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
# Prune stale state
# ============================================

docker network prune -f &>/dev/null
log "Pruned unused networks"

if [[ "$REMOVE_CONTAINERS" == true ]]; then
    CONTAINERS=$(docker ps -aq 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        echo "Removing all containers (--remove-containers)..."
        log "Removing all containers: $CONTAINERS"
        docker rm -f $CONTAINERS &>/dev/null
    fi
fi

log "Docker cleanup completed"

# ============================================
# Summary
# ============================================

if [ "$CONFLICTS" -gt 0 ]; then
    echo "Docker cleanup completed - $CONFLICTS non-Docker process(es) holding common ports (see above)"
    echo "Stop the listed process, or change the port mapping in your compose file."
else
    echo "Docker cleanup completed - no port conflicts found"
fi
