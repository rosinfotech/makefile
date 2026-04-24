#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/kill_processes.sh"
source "$LIB_DIR/remove_dirs_safe.sh"

# Add any commands to remove files or directories

# rm -f "package-lock.json"

# remove_dirs_safe "node_modules"

echo "Cleanup completed"
