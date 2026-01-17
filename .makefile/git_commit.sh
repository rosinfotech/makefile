#!/bin/bash

gitCommit() {

    local message="$1"
    local current_branch

    if [ -z "$message" ]; then
        echo "Error: Commit message is required"
        exit 1
    fi

    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            echo "Error: Not on any branch (detached HEAD state)"
            exit 1
        else
            current_branch=$(git config --get init.defaultBranch || echo "main")
            echo "New repository detected. Will use branch '${current_branch}'"
        fi
    fi

    git add .

    git commit -m "${message}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create commit"
        exit 1
    fi

    echo "Successfully committed with message: ${message}"

}

gitCommit "$@"
