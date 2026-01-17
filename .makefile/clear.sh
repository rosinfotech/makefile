#!/bin/bash

source ./.makefile/kill_processes.sh

source ./.makefile/remove_dirs_safe.sh

# rm -f "package-lock.json"

# remove_dirs_safe "node_modules"

echo "Cleanup completed"
