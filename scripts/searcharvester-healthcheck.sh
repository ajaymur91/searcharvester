#!/usr/bin/env bash
set -u

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.search.yaml"
HEALTH_URL="${SEARCHARVESTER_HEALTH_URL:-http://localhost:8081/health}"
COMPOSE_COMMAND="${COMPOSE_COMMAND:-docker-compose}"

log_message() {
    logger -t searcharvester-healthcheck -- "$*" 2>/dev/null || printf '%s\n' "$*" >&2
}

if curl --fail --silent --show-error --max-time 15 "$HEALTH_URL" >/dev/null; then
    exit 0
fi

log_message "Health check failed for $HEALTH_URL; restarting searcharvester stack"

if ! "$COMPOSE_COMMAND" -f "$COMPOSE_FILE" restart; then
    log_message "Existing containers could not be restarted; attempting to bring the stack up"
fi

if ! "$COMPOSE_COMMAND" -f "$COMPOSE_FILE" up -d --no-build; then
    log_message "Failed to bring up searcharvester stack"
    exit 1
fi

for attempt in {1..12}; do
    if curl --fail --silent --show-error --max-time 15 "$HEALTH_URL" >/dev/null; then
        log_message "Searcharvester stack recovered after restart"
        exit 0
    fi
    sleep 5
done

log_message "Searcharvester health check still failing after restart"
exit 1
