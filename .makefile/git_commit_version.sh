#!/bin/bash

source ./.makefile/get_version.sh

gitCommitVersion() {

    local version
    local message="$1"
    local current_branch

    version=$(getVersion)

    if [ $? -ne 0 ]; then
        exit 1
    fi

    if git rev-parse "${version}" >/dev/null 2>&1; then
        echo "Error: Tag ${version} already exists"
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

    if [ -z "$message" ]; then
        commit_msg="${version}"
        git commit -m "${version}"
    else
        commit_msg="${version}: ${message}"
        git commit -m "${version}: ${message}"
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create commit"
        exit 1
    fi

    echo "Successfully committed with message: ${commit_msg}"

}

gitCommitVersion "$@"
