#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowTaskIntegrate() {

    local variant branch worktree base reason

    variant=$(flowRequireFlow) || exit 1

    reason=""
    case "$variant" in
        1) reason="variant #1 commits directly into main" ;;
        2) reason="variant #2 merges the task into main directly (git_flow_task_finish)" ;;
    esac
    flowRequireVariant "$variant" "3 4 5" "$reason"

    branch=$(flowCurrentBranch)
    case "$branch" in
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            cliError "Hotfix branches bypass develop (rule #2610082120)"
            exit 1
            ;;
        *)
            cliError "Not on a task branch (current: ${branch:-none})"
            exit 1
            ;;
    esac

    flowRequireCleanTree || exit 1

    if git show-ref --verify --quiet "refs/remotes/origin/develop" 2>/dev/null && \
        flowBranchPatchesIn "$branch" "develop"; then
        cliError "$branch is already integrated into origin/develop - nothing to integrate"
        exit 1
    fi

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    if ! git show-ref --verify --quiet "refs/heads/develop" 2>/dev/null; then
        base=$(flowRemoteBaseRef "$FLOW_MAIN_BRANCH")
        git branch develop "$base"
        cliInfo "Branch created: develop (from $base)"
        flowHasRemote && git push -u origin develop >/dev/null 2>&1
    fi

    worktree=$(flowBranchWorktree develop)
    current_physical="$(cd . && pwd -P)"

    if [ -n "$worktree" ] && [ "$worktree" != "$current_physical" ]; then
        if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
            cliError "develop is checked out dirty in $worktree - commit or stash there first"
            exit 1
        fi
        git -C "$worktree" merge --no-edit "$branch" >/dev/null 2>&1 || {
            git -C "$worktree" merge --abort >/dev/null 2>&1
            cliError "Conflict merging $branch into develop - resolve in $worktree"
            cliHint "git -C $worktree merge $branch."
            printf '\n' >&2
            exit 1
        }
        git -C "$worktree" push origin develop >/dev/null 2>&1 || {
            cliError "Failed to push develop"
            exit 1
        }
    else
        git checkout develop >/dev/null 2>&1 || exit 1
        git merge --no-edit "$branch" >/dev/null 2>&1 || {
            git merge --abort >/dev/null 2>&1
            git checkout "$branch" >/dev/null 2>&1
            cliError "Conflict merging $branch into develop - resolve manually"
            cliHint "git checkout develop && git merge $branch."
            printf '\n' >&2
            exit 1
        }
        git push origin develop >/dev/null 2>&1 || {
            cliError "Failed to push develop"
            exit 1
        }
        git checkout "$branch" >/dev/null 2>&1
    fi

    cliSuccess "Integrated: $branch -> develop (free merge, no gate)"
    cliHint "Finish with: make git_flow_task_finish."
    printf '\n' >&2

}

cliFrameInit
cliParseArgs "$@"
flowTaskIntegrate "${CLI_ARG_POSITIONAL:-}"
