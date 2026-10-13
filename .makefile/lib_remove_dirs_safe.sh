#!/bin/bash

remove_dirs_safe() {

    local dir="$1"
    local max_attempts=5
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if [ ! -d "$dir" ]; then
            echo "Directory does not exist: $dir"
            return 0
        fi

        if lsof +D "$dir" >/dev/null 2>&1; then
            echo "Directory $dir is busy by processes, attempt $attempt/$max_attempts"
            sleep 0.2
        else
            if rm -rf "$dir" 2>/dev/null; then
                # Verify the directory was actually removed
                sleep 0.1
                if [ ! -d "$dir" ]; then
                    echo "Successfully removed directory: $dir"
                    return 0
                else
                    # Directory still exists despite rm command appearing to succeed
                    echo "Warning: rm command succeeded but directory still exists: $dir"
                    echo "Attempting to force removal, attempt $attempt/$max_attempts"
                    sleep 0.2
                fi
            else
                echo "Error removing $dir, attempt $attempt/$max_attempts"
            fi
        fi

        attempt=$((attempt + 1))
    done

    echo "Failed to remove directory after $max_attempts attempts: $dir"

    return 1

}
