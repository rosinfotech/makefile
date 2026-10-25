#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowTaskStart() {

    local label="$1" variant base base_ref branch worktree utlbl

    variant=$(flowRequireFlow) || exit 1
    flowRequireVariant "$variant" "2 3 4 5" \
        "variant #1 commits directly into main (make git_flow_commit_push)"

    if [ -z "$label" ]; then
        cliError "The task label is required"
        cliHint "make git_flow_task_start <label>."
    printf '\n' >&2
        exit 2
    fi

    label=$(echo "$label" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//')

    if [ -z "$label" ]; then
        cliError "The label must contain letters or digits"
        exit 2
    fi

    base=$(flowForkBase "$variant") || exit 1

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    base_ref=$(flowRemoteBaseRef "$base")

    if ! git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null 2>&1; then
        cliError "Fork base '$base_ref' does not exist"
        exit 1
    fi

    utlbl=$(date +%y%m%d%H%M)
    branch="task-${utlbl}-${label}"
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

    if [ "$variant" -eq 5 ]; then
        train_version="$(echo "$base" | sed 's|^release/||').0"
        if [ -f "$worktree/.version" ]; then
            sed -i '' "2s/.*/$train_version/" "$worktree/.version"
        fi
    fi

    cliSuccess "Task branch $branch created (fork: $base_ref)"
    printf -- '- worktree: %s;\n' "$worktree"
    printf '\n'
    cliHeader3 "Next steps"
    printf '1. cd %s;\n' "$worktree"
    printf '2. make git_flow_task_fragment "Added: one English line";\n'
    printf '3. make git_flow_task_merge_develop (variants #3-#5);\n'
    printf '\n'

}

cliFrameInit
cliParseArgs "$@"
flowTaskStart "${CLI_ARG_POSITIONAL:-}"
