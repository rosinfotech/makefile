#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowPush() {

    local branch

    branch=$(flowCurrentBranch)
    case "$branch" in
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*|\
hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        *)
            cliError "git_flow_push updates an open task or hotfix merge request - current branch is ${branch:-none}"
            cliHint "On main the version belongs to git_flow_commit_push (variant #1) or git_flow_seal."
            exit 1
            ;;
    esac

    if [ -n "$(git status --porcelain)" ]; then
        cliError "Working tree is not clean - commit first (make git_flow_commit)"
        exit 1
    fi

    flowTaskUpdatePush "$branch" || exit 1

}

cliFrameInit
cliParseArgs "$@"
flowPush "${CLI_ARG_POSITIONAL:-}"
