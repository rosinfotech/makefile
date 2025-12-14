#!/bin/bash

SECRETS_FILE="$HOME/.secrets.json"

if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: Secrets file not found: $SECRETS_FILE"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    exit 1
fi

export SECRETS_FILE

getHomeSecret() {
    local key="$1"
    jq -r "$key" "$SECRETS_FILE" 2>/dev/null
}

echo "Secrets loaded"
