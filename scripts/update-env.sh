#!/bin/bash

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Directory configurations
BACKUP_DIR="${PROJECT_ROOT}/backups"
ENV_FILE="${PROJECT_ROOT}/.env"
ENV_EXAMPLE="${PROJECT_ROOT}/.env.example"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "Using directories:"
echo "- Project root: $PROJECT_ROOT"
echo "- Backup dir: $BACKUP_DIR"
echo "- Script dir: $SCRIPT_DIR"

# Function to generate a secure password
generate_password() {
    openssl rand -base64 24 | tr -d '/+=' | cut -c1-20
}

# Function to update .env file
update_env() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local temp_file="${PROJECT_ROOT}/.env.temp"
    local backup_file="${BACKUP_DIR}/env.backup.${timestamp}"
    
    # Create backup of current .env
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$backup_file"
        echo "Created backup of current .env at: $backup_file"
    fi
    
    # Rest of the function remains the same...
}

# Move any existing backups from root to backup directory
if ls .env.backup.* 1> /dev/null 2>&1; then
    echo "Moving existing backups to backup directory..."
    mv .env.backup.* "$BACKUP_DIR/" 2>/dev/null || true
fi 