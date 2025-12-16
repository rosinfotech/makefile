#!/bin/bash

set -e

sshFileUpload() {
    if [ $# -lt 2 ]; then
        echo "Usage: sshFileUpload <source> <destination>"
        return 1
    fi

    local source="$1"
    local destination="$2"

    if [ ! -f "$source" ]; then
        echo "Source file does not exist: $source"
        return 1
    fi

    sshClient scp "$source" "$destination"
}

export -f sshFileUpload
