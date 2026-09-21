#!/bin/bash

set -e

sshDirectoryDownloadAsArchive() {
    if [ $# -lt 2 ]; then
        echo "Usage: sshDirectoryDownloadAsArchive <remote_source> <local_archive>"
        return 1
    fi

    if [ -z "$SSH_CONNECTION" ]; then
        echo "Error: SSH not initialized. Call sshClient init first."
        return 1
    fi

    local source="$1"
    local archive="$2"
    local parent
    local name
    local archive_dir
    local exit_code=0

    parent="$(dirname "$source")"
    name="$(basename "$source")"
    archive_dir="$(dirname "$archive")"
    mkdir -p "$archive_dir"

    "${SSH_AUTH_CMD[@]}" ssh $SSH_OPTIONS $SSH_CONNECTION \
        "tar -czf - -C '${parent}' '${name}'" > "$archive" || exit_code=$?

    if [ $exit_code -ne 0 ] || [ ! -s "$archive" ]; then
        echo "Archive download failed: $archive"
        rm -f "$archive"
        return 1
    fi
}

export -f sshDirectoryDownloadAsArchive
