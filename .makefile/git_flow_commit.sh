#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

gitCommit() {

    local message="$1"
    local current_branch

    if [ -z "$message" ]; then
        cliError "The commit message is required"
        exit 2
    fi

    flowRequireTaskCommitMessage "$message"

    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            cliError "Not on any branch (detached HEAD state)"
            exit 1
        else
            current_branch=$(git config --get init.defaultBranch || echo "main")
            cliWarning "New repository detected - will use branch '${current_branch}'"
        fi
    fi

    if [ "$current_branch" = "$FLOW_MAIN_BRANCH" ] && (flowDetectVariant) >/dev/null 2>&1; then
        cliWarning "Committing directly on main without a version stamp"
        cliHint "Use make git_flow_commit_push \"<Type>: <message>\" to stamp the version."
        printf '\n' >&2
    fi

    git add .

    git commit -m "${message}" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        cliError "Failed to create commit"
        exit 1
    fi

    cliSuccess "Committed with message: ${message}"

}

cliFrameInit
cliParseArgs "$@"
gitCommit "${CLI_ARG_POSITIONAL:-}"
