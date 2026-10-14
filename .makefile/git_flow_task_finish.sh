#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowTaskFinish() {

    local variant branch target worktree current_physical main_worktree

    variant=$(flowRequireFlow) || exit 1
    flowRequireVariant "$variant" "2 3 4 5" \
        "variant #1 commits directly into main (make git_flow_commit_push)"

    branch=$(flowCurrentBranch)
    case "$branch" in
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            cliError "A hotfix merges via its own MR into main (see git_flow_hotfix_start output)"
            exit 1
            ;;
        *)
            cliError "Not on a task branch (current: ${branch:-none})"
            exit 1
            ;;
    esac

    flowRequireCleanTree || exit 1

    if flowBranchPatchesIn "$branch" "$(flowForkBase "$variant" 2>/dev/null || echo "$FLOW_MAIN_BRANCH")"; then
        cliError "The task is already in its merge-request target - nothing to finish"
        cliHint "Run make git_flow_seal on $FLOW_MAIN_BRANCH after the merge."
        printf '\n' >&2
        exit 1
    fi

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    if [ "$variant" -eq 2 ]; then
        senior=$(flowSeniorFragment "$(flowTaskLabelFromBranch "$branch")") || {
            cliError "The task carries no changelog fragment - add one before finishing"
            cliHint "make git_flow_task_fragment \"Added: one English line\"."
            printf '\n' >&2
            exit 1
        }
        current_physical="$(cd . && pwd -P)"
        main_worktree=$(flowBranchWorktree "$FLOW_MAIN_BRANCH")

        if [ -n "$main_worktree" ] && [ "$main_worktree" != "$current_physical" ]; then
            if [ -n "$(git -C "$main_worktree" status --porcelain)" ]; then
                cliError "main is checked out dirty in $main_worktree - commit or stash there first"
                exit 1
            fi
            git -C "$main_worktree" merge --ff-only "origin/$FLOW_MAIN_BRANCH" >/dev/null 2>&1
            git -C "$main_worktree" merge --squash "$branch" >/dev/null 2>&1 || {
                git -C "$main_worktree" merge --abort >/dev/null 2>&1
                cliError "Conflict merging $branch into main - resolve in $main_worktree"
                exit 1
            }
            git -C "$main_worktree" commit -m "$senior" >/dev/null 2>&1 || {
                cliError "Failed to create the squash commit in $main_worktree"
                exit 1
            }
            git -C "$main_worktree" push origin "$FLOW_MAIN_BRANCH" >/dev/null 2>&1 || {
                cliError "Failed to push main"
                exit 1
            }
        else
            git checkout "$FLOW_MAIN_BRANCH" >/dev/null 2>&1 || exit 1
            git merge --ff-only "origin/$FLOW_MAIN_BRANCH" >/dev/null 2>&1
            git merge --squash "$branch" >/dev/null 2>&1 || {
                git merge --abort >/dev/null 2>&1
                git checkout "$branch" >/dev/null 2>&1
                cliError "Conflict merging $branch into main - resolve manually"
                cliHint "git checkout $FLOW_MAIN_BRANCH && git merge --squash $branch."
                printf '\n' >&2
                exit 1
            }
            git commit -m "$senior" >/dev/null 2>&1 || {
                cliError "Failed to create the squash commit"
                exit 1
            }
            git push origin "$FLOW_MAIN_BRANCH" >/dev/null 2>&1 || {
                cliError "Failed to push main"
                exit 1
            }
            git checkout "$branch" >/dev/null 2>&1
        fi

        cliSuccess "Task entered main as one commit: $senior"
        cliHint "Stamp the version: make git_flow_seal (it switches to main itself)."
        printf '\n' >&2
        return 0
    fi

    target=$(flowForkBase "$variant") || exit 1

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
    printf -- '- merge request: %s -> %s;\n' "$branch" "$target"
    printf '\n'
    if ! flowGitHubCreatePR "$branch" "$target"; then
        flowMergeRequestUrl "$branch" "$target"
    fi
    cliHint "Integrate into develop first when not done yet: make git_flow_task_merge_develop."
    if [ "$variant" -ge 4 ]; then
        cliHint "After the merge: make git_flow_promote (it creates the $target -> $FLOW_MAIN_BRANCH pull request)."
    else
        cliHint "After the MR merge: make git_flow_seal (on $FLOW_MAIN_BRANCH)."
    fi
    printf '\n' >&2

}

cliFrameInit
flowTaskFinish "$@"
