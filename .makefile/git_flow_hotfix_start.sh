#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowHotfixStart() {

    local label="$1" variant reason base_ref branch worktree utlbl

    variant=$(flowRequireFlow) || exit 1

    reason=""
    case "$variant" in
        1) reason="a production fix is a regular commit (make git_flow_commit_push)" ;;
        2) reason="a hotfix is a regular task branch (make git_flow_task_start)" ;;
        3) reason="there is no queue to bypass - a fix is a regular task (make git_flow_task_start)" ;;
    esac
    flowRequireVariant "$variant" "4 5" "$reason"

    if [ -z "$label" ]; then
        cliError "The hotfix label is required"
        cliHint "make git_flow_hotfix_start <label>."
    printf '\n' >&2
        exit 2
    fi

    label=$(echo "$label" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//')

    if [ -z "$label" ]; then
        cliError "The label must contain letters or digits"
        exit 2
    fi

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    base_ref=$(flowRemoteBaseRef "$FLOW_MAIN_BRANCH")

    utlbl=$(date +%y%m%d%H%M)
    branch="hotfix-${utlbl}-${label}"
    worktree="../$(basename "$PWD")-${branch}"

    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        cliError "Branch $branch already exists"
        exit 1
    fi

    if [ -e "$worktree" ]; then
        cliError "Worktree path already exists: $worktree"
        exit 1
    fi

    git worktree add -b "$branch" "$worktree" "$base_ref" >/dev/null 2>&1 || {
        cliError "Failed to create the worktree $worktree"
        exit 1
    }

    cliSuccess "Hotfix branch $branch created (fork: $base_ref, bypasses the queue)"
    printf -- '- worktree: %s;\n' "$worktree"
    printf '\n'
    cliHeader3 "Next steps (rule #2610082120)"
    printf '1. cd %s;\n' "$worktree"
    printf '2. make git_flow_task_fragment "Fixed: one English line";\n'
    printf '3. commit the fix, then create the MR into %s;\n' "$FLOW_MAIN_BRANCH"
    printf '4. after the merge: make git_flow_seal (it back-merges main everywhere);\n'
    printf '\n'

}

cliFrameInit
cliParseArgs "$@"
flowHotfixStart "${CLI_ARG_POSITIONAL:-}"
