#!/bin/bash

source ./.makefile/get_version.sh

gitCommitPush() {

    local version
    local message="$1"
    local current_branch
    local remote_name="origin"

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
        git commit -m "${version}"
    else
        git commit -m "${version}: ${message}"
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create commit"
        exit 1
    fi

    if ! git push 2>/dev/null; then
        echo "Warning: Push failed, trying to set upstream and push..."
        if git push --set-upstream "${remote_name}" "${current_branch}"; then
            echo "Upstream set successfully"
        else
            echo "Error: Failed to push commit"
            exit 1
        fi
    fi

    git tag "${version}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create tag ${version}"
        exit 1
    fi

    git push --tags

    if [ $? -ne 0 ]; then
        echo "Error: Failed to push tags"
        exit 1
    fi

    echo "Successfully committed, pushed, and tagged with version ${version}"

}

gitCommitPush "$@"
