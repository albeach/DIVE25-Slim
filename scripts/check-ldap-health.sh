#!/bin/bash

# Set error handling
set -euo pipefail

# Load environment variables if .env file exists
if [ -f .env ]; then
    source .env
fi

# Configuration
LDAP_HOST=${LDAP_HOST:-"localhost"}
LDAP_PORT=${LDAP_PORT:-"389"}
METRICS_PORT=${METRICS_PORT:-"9330"}
LOG_FILE="/var/log/ldap-health.log"

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $level: $message" | tee -a "$LOG_FILE"
}

# Check LDAP server health
check_ldap() {
    ldapsearch -x -H "ldap://${LDAP_HOST}:${LDAP_PORT}" \
        -D "cn=readonly,dc=dive25,dc=local" \
        -w "${LDAP_READONLY_PASSWORD}" \
        -b "dc=dive25,dc=local" \
        -s base > /dev/null 2>&1
    
    return $?
}

# Check metrics exporter
check_metrics() {
    curl -s "http://${LDAP_HOST}:${METRICS_PORT}/metrics" > /dev/null
    return $?
}

# Main health check
main() {
    local exit_code=0

    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"

    log "INFO" "Starting LDAP health check..."

    echo "Checking LDAP server..."
    if check_ldap; then
        log "INFO" "✓ LDAP server is healthy"
        echo "✓ LDAP server is healthy"
    else
        log "ERROR" "✗ LDAP server check failed"
        echo "✗ LDAP server check failed"
        exit_code=1
    fi

    echo "Checking metrics exporter..."
    if check_metrics; then
        log "INFO" "✓ Metrics exporter is healthy"
        echo "✓ Metrics exporter is healthy"
    else
        log "ERROR" "✗ Metrics exporter check failed"
        echo "✗ Metrics exporter check failed"
        exit_code=1
    fi

    if [ $exit_code -eq 0 ]; then
        log "INFO" "All health checks passed"
    else
        log "ERROR" "One or more health checks failed"
    fi

    return $exit_code
}

# Run main function
main 