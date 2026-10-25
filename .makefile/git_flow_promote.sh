#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowPromote() {

    local variant source reason

    variant=$(flowRequireFlow) || exit 1

    reason=""
    case "$variant" in
        1|2|3) reason="variants #1-#3 have no staging or release branch to promote" ;;
    esac
    flowRequireVariant "$variant" "4 5" "$reason"

    if [ "$variant" -eq 4 ]; then
        source="staging"
    else
        source=$(flowCurrentTrain) || exit 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/$source" 2>/dev/null && \
        ! git show-ref --verify --quiet "refs/remotes/origin/$source" 2>/dev/null; then
        cliError "Branch $source does not exist"
        exit 1
    fi

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    local source_ref
    source_ref=$(flowRemoteBaseRef "$source")

    if git diff --quiet "$source_ref" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
        cliInfo "$source has no unmerged changes - nothing to promote"
        exit 0
    fi

    cliSuccess "Promoting $source -> $FLOW_MAIN_BRANCH"
    printf -- '- merge request: %s -> %s;\n' "$source" "$FLOW_MAIN_BRANCH"
    printf '\n'
    if ! flowGitHubCreatePR "$source" "$FLOW_MAIN_BRANCH"; then
        flowMergeRequestUrl "$source" "$FLOW_MAIN_BRANCH"
    fi
    cliHint "Merge the pull request (squash), then run: make git_flow_seal."
    printf '\n' >&2

}

cliFrameInit
cliParseArgs "$@"
flowPromote "${CLI_ARG_POSITIONAL:-}"
