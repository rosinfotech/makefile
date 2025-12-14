#!/bin/bash

set -e

sshDirectoryUpload() {
    if [ $# -lt 2 ]; then
        echo "Usage: sshDirectoryUpload <source> <destination> [exclude_pattern]"
        return 1
    fi

    local source="$1"
    local destination="$2"
    local exclude_pattern="${3:-}"

    if [ ! -d "$source" ]; then
        echo "Source directory does not exist: $source"
        return 1
    fi

    sshClient rsync "$source" "$destination" "$exclude_pattern"
}

export -f sshDirectoryUpload
