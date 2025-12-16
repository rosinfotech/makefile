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
        echo "Error: Not on any branch (detached HEAD state)"
        exit 1
    fi

    local upstream=$(git rev-parse --abbrev-ref "${current_branch}@{upstream}" 2>/dev/null)
    if [ -z "$upstream" ]; then
        echo "Warning: Current branch '${current_branch}' has no upstream branch."
        echo "To push and set the upstream, run: git push --set-upstream origin ${current_branch}"
        echo "Do you want to set upstream automatically? (y/N)"
        read -r response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "Setting upstream for branch '${current_branch}'..."
            git push --set-upstream "${remote_name}" "${current_branch}"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to set upstream branch"
                exit 1
            fi
        else
            echo "Aborting: Upstream not set"
            exit 1
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
