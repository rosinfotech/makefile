#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowHotfixFinish() {

    local variant branch reason

    variant=$(flowRequireFlow) || exit 1

    reason=""
    case "$variant" in
        1) reason="a production fix is a regular commit (make git_flow_commit_push)" ;;
        2) reason="a hotfix is a regular task branch (make git_flow_task_start)" ;;
        3) reason="there is no queue to bypass - a fix is a regular task (make git_flow_task_start)" ;;
    esac
    flowRequireVariant "$variant" "4 5" "$reason"

    branch=$(flowCurrentBranch)
    case "$branch" in
        hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            cliError "A task branch finishes with make git_flow_task_finish"
            exit 1
            ;;
        *)
            cliError "Not on a hotfix branch (current: ${branch:-none})"
            exit 1
            ;;
    esac

    flowRequireCleanTree || exit 1

    flowSeniorFragment "$(flowTaskLabelFromBranch "$branch")" >/dev/null || {
        cliError "The hotfix carries no changelog fragment - add one before finishing"
        cliHint "make git_flow_task_fragment \"Fixed: one English line\"."
        printf '\n' >&2
        exit 1
    }

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    if flowBranchPatchesIn "$branch" "$FLOW_MAIN_BRANCH"; then
        cliError "The hotfix is already in $FLOW_MAIN_BRANCH - nothing to finish"
        cliHint "Run make git_flow_seal on $FLOW_MAIN_BRANCH after the merge."
        printf '\n' >&2
        exit 1
    fi

    if flowHasRemote && git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null && \
        [ "$(git rev-parse "$branch" 2>/dev/null)" = "$(git rev-parse "origin/$branch" 2>/dev/null)" ]; then
        cliError "$branch is already pushed - the merge request already exists"
        cliHint "Merge the open request in the repository UI, then run make git_flow_seal."
        printf '\n' >&2
        exit 1
    fi

    git push -u origin "$branch" >/dev/null 2>&1 || {
        cliError "Failed to push $branch"
        exit 1
    }

    cliSuccess "Pushed: $branch"
    printf -- '- merge request: %s -> %s (bypasses the queue);\n' "$branch" "$FLOW_MAIN_BRANCH"
    printf '\n'
    if ! flowGitHubCreatePR "$branch" "$FLOW_MAIN_BRANCH"; then
        flowMergeRequestUrl "$branch" "$FLOW_MAIN_BRANCH"
    fi
    cliHint "Enable squash in the merge request (the title carries no version - the hotfix stamp follows)."
    cliHint "After the merge: make git_flow_seal (it switches to main and back-merges everywhere)."
    printf '\n' >&2

}

cliFrameInit
flowHotfixFinish "$@"
