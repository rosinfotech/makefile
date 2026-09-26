#!/bin/bash
#
# Generic secrets access: resolves the secrets file (SECRETS_FILE env
# override -> ~/.secrets.json), checks jq and provides readers. The
# schema inside the file is owned by the consumers (e.g. infra uses
# .infra.<server>.*). Sourcing is non-fatal; call requireSecrets for a
# fatal check.
#

SECRETS_FILE="${SECRETS_FILE:-$HOME/.secrets.json}"
export SECRETS_FILE

secretFile() {
    echo "$SECRETS_FILE"
}

secretsExist() {
    [ -f "$SECRETS_FILE" ]
}

requireSecrets() {
    if ! secretsExist; then
        echo "Error: secrets file not found: $SECRETS_FILE" >&2
        return 1
    fi
    if ! command -v jq > /dev/null 2>&1; then
        echo "Error: jq is not installed" >&2
        return 1
    fi
}

# getSecret <jq-path> [jq-args...] - raw value (empty when missing).
getSecret() {
    secretsExist || return 1
    jq -r "$@" "$SECRETS_FILE" 2>/dev/null
}
