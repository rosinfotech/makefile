#!/bin/bash

source ./scripts/get_version.sh

gitCommitPush() {
    local version
    local message="$1"

    version=$(getVersion)

    if [ $? -ne 0 ]; then
        exit 1
    fi

    # Проверяем, существует ли уже тег с текущей версией
    if git rev-parse "${version}" >/dev/null 2>&1; then
        echo "Error: Tag ${version} already exists"
        exit 1
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

    git push

    if [ $? -ne 0 ]; then
        echo "Error: Failed to push commit"
        exit 1
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
