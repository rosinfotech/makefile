#!/bin/bash
#
# Generic secrets access: resolves the secrets file (SECRETS_FILE env
# override -> ~/.secrets.json), checks jq and provides readers plus a
# rotating backup helper. The schema inside the file is owned by the
# consumers (e.g. infra uses .infra.<server>.*). Sourcing is non-fatal;
# call requireSecrets for a fatal check.
#

SECRETS_FILE="${SECRETS_FILE:-$HOME/.secrets.json}"
export SECRETS_FILE

# How many timestamped .bak copies are kept next to the secrets file;
# older ones are rotated away after each backup. Env-overridable,
# non-numeric values fall back to 3.
SECRETS_BACKUP_KEEP="${SECRETS_BACKUP_KEEP:-3}"
case "$SECRETS_BACKUP_KEEP" in
    ''|*[!0-9]*) SECRETS_BACKUP_KEEP=3 ;;
esac
export SECRETS_BACKUP_KEEP

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

# secretsBackup - timestamped copy of the secrets file next to the
# original (<file>.YYYY_MM_DD_HHMMSS.bak), then rotation: only the
# SECRETS_BACKUP_KEEP newest *.bak copies (the fresh one included)
# survive, older ones are removed. Non-fatal: returns 1 when the file
# is missing or the copy fails, 0 after a successful backup+rotation.
secretsBackup() {
    secretsExist || return 1
    local backup="${SECRETS_FILE}.$(date +%Y_%m_%d_%H%M%S).bak"
    cp "$SECRETS_FILE" "$backup" 2>/dev/null || return 1
    ls -1t "${SECRETS_FILE}".*.bak 2>/dev/null \
        | tail -n +$((SECRETS_BACKUP_KEEP + 1)) \
        | while IFS= read -r stale; do rm -f "$stale"; done
}
