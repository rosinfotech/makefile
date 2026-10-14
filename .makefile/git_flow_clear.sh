#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowClearAsk() { # question -> 0 yes; the default is NO; a non-TTY stream declines; FLOW_CLEAR forces
    local answer
    case "${FLOW_CLEAR:-}" in
        1|[tT][rR][uU][eE]|[yY][eE][sS]) return 0 ;;
    esac
    [ -t 0 ] || return 1
    if [ "$CLI_COLOR_ERR" = "1" ]; then
        printf '%s%s [y/N]: %s' "$CLI_CYAN" "$1" "$CLI_RESET" >&2
    else
        printf '%s [y/N]: ' "$1" >&2
    fi
    if ! read -r answer; then
        printf '\n' >&2
        return 1
    fi
    printf '\n' >&2
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

flowClearRemove() { # branch -> removes the worktree, the local and the remote copy; prints dense items
    local branch="$1" worktree
    worktree=$(flowBranchWorktree "$branch")
    if [ -n "$worktree" ]; then
        if git worktree remove "$worktree" >/dev/null 2>&1 \
            || git worktree remove --force "$worktree" >/dev/null 2>&1; then
            printf -- '- removed worktree: %s;\n' "$worktree"
        else
            cliWarning "Failed to remove the worktree $worktree"
        fi
    fi
    if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        if git branch -D "$branch" >/dev/null 2>&1; then
            printf -- '- removed local: %s;\n' "$branch"
        else
            cliWarning "Failed to remove the local branch $branch"
        fi
    fi
    if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        if git push origin --delete "$branch" >/dev/null 2>&1; then
            printf -- '- removed remote: origin/%s;\n' "$branch"
        else
            cliWarning "Failed to remove origin/$branch"
        fi
    fi
}

flowClearDirtyWorktree() { # branch -> 0 when checked out dirty
    local branch="$1" worktree
    worktree=$(flowBranchWorktree "$branch")
    [ -n "$worktree" ] && [ -n "$(git -C "$worktree" status --porcelain)" ]
}

flowClearDelivered() { # branch (local or remote name) -> 0 when fully delivered to main or a gate
    local branch="$1" gate
    if flowBranchPatchesIn "$branch" "$FLOW_MAIN_BRANCH" 2>/dev/null \
        || flowBranchChangesIn "$branch" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
        echo "$FLOW_MAIN_BRANCH"
        return 0
    fi
    for gate in staging $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
        if flowBranchPatchesIn "$branch" "$gate" 2>/dev/null \
            || flowBranchChangesIn "$branch" "$gate" 2>/dev/null; then
            echo "$gate"
            return 0
        fi
    done
    return 1
}

flowClearAbandoned() { # branch -> prints the stamp version when main was sealed after the fork
    local branch="$1" fork_base latest_tag tag_commit
    latest_tag=$(git describe --tags --abbrev=0 "$FLOW_MAIN_BRANCH" 2>/dev/null)
    [ -z "$latest_tag" ] && return 1
    tag_commit=$(git rev-parse "${latest_tag}^{commit}" 2>/dev/null)
    [ -z "$tag_commit" ] && return 1
    fork_base=$(git merge-base "$branch" "$FLOW_MAIN_BRANCH" 2>/dev/null)
    [ -z "$fork_base" ] && return 1
    if [ "$fork_base" != "$tag_commit" ] \
        && git merge-base --is-ancestor "$fork_base" "$tag_commit" 2>/dev/null; then
        echo "$latest_tag"
        return 0
    fi
    return 1
}

flowClear() {

    local variant branch reason gate target current_train
    local merged_local=() merged_remote=() merged_notes=()
    local unused_local=() unused_remote=() unused_notes=()
    local removed_total=0

    variant=$(flowRequireFlow) || exit 1

    if flowHasRemote; then
        git fetch origin --prune >/dev/null 2>&1 || true
    fi

    # --- group 1: merged task and hotfix branches --------------------------
    for branch in $(git for-each-ref --format='%(refname:short)' \
        'refs/heads/task-*' 'refs/heads/hotfix-*'); do
        if flowClearDirtyWorktree "$branch"; then
            merged_notes+=("Warning: the $branch worktree is dirty - left alone")
            continue
        fi
        if target=$(flowClearDelivered "$branch"); then
            merged_local+=("$branch|delivered to $target")
        elif target=$(flowClearAbandoned "$branch"); then
            merged_local+=("$branch|abandoned - main stamped $target after the fork")
        else
            merged_notes+=("Information: kept $branch - it has unmerged content")
        fi
    done
    for branch in $(git for-each-ref --format='%(refname:short)' \
        'refs/remotes/origin/task-*' 'refs/remotes/origin/hotfix-*' | sed 's|^origin/||'); do
        git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && continue
        if target=$(flowClearDelivered "origin/$branch"); then
            merged_remote+=("$branch|remote copy only, delivered to $target")
        elif target=$(flowClearAbandoned "origin/$branch"); then
            merged_remote+=("$branch|remote copy only, abandoned - main stamped $target after the fork")
        else
            merged_notes+=("Information: kept origin/$branch - it has unmerged content")
        fi
    done

    if [ "${#merged_local[@]}" -gt 0 ] || [ "${#merged_remote[@]}" -gt 0 ] || [ "${#merged_notes[@]}" -gt 0 ]; then
        cliHeader3 "Task and hotfix branches"
        for entry in "${merged_local[@]}" "${merged_remote[@]}"; do
            [ -n "$entry" ] || continue
            printf -- '- %s (%s);\n' "${entry%%|*}" "${entry#*|}"
        done
        if [ "${#merged_local[@]}" -gt 0 ] || [ "${#merged_remote[@]}" -gt 0 ]; then
            printf '\n'
        fi
        for note in "${merged_notes[@]}"; do
            [ -n "$note" ] || continue
            case "$note" in
                Warning:*) cliWarning "${note#Warning: }" ;;
                Information:*) cliInfo "${note#Information: }" ;;
            esac
        done
        if [ "${#merged_local[@]}" -gt 0 ] || [ "${#merged_remote[@]}" -gt 0 ]; then
            if flowClearAsk "Remove these branches with their worktrees and remote copies?"; then
                for entry in "${merged_local[@]}"; do
                    [ -n "$entry" ] || continue
                    flowClearRemove "${entry%%|*}"
                    removed_total=$((removed_total + 1))
                done
                for entry in "${merged_remote[@]}"; do
                    [ -n "$entry" ] || continue
                    branch="${entry%%|*}"
                    git push origin --delete "$branch" >/dev/null 2>&1 \
                        && printf -- '- removed remote: origin/%s;\n' "$branch"
                    removed_total=$((removed_total + 1))
                done
                printf '\n'
                cliSuccess "Merged branches cleaned: $removed_total"
            else
                cliInfo "Declined - the branches stay"
            fi
        fi
    fi

    # --- group 2: flow branches not used by the declared variant ------------
    for gate in develop staging; do
        case "$variant:$gate" in
            1:develop|2:develop|1:staging|2:staging|3:staging) reason="not used by variant #$variant" ;;
            *) continue ;;
        esac
        if git show-ref --verify --quiet "refs/heads/$gate" 2>/dev/null; then
            if [ "$gate" = "$(flowCurrentBranch)" ] || [ -n "$(flowBranchWorktree "$gate")" ]; then
                unused_notes+=("Warning: $gate is checked out - left alone")
            elif flowBranchChangesIn "$gate" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
                unused_local+=("$gate|$reason, fully promoted")
            else
                unused_notes+=("Warning: $gate has unmerged content - left alone")
            fi
        fi
        if git show-ref --verify --quiet "refs/remotes/origin/$gate" 2>/dev/null; then
            if ! git show-ref --verify --quiet "refs/heads/$gate" 2>/dev/null; then
                if flowBranchChangesIn "origin/$gate" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
                    unused_remote+=("$gate|remote copy only, $reason")
                fi
            fi
        fi
    done
    current_train=$(flowCurrentTrain 2>/dev/null)
    for branch in $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
        if [ "$variant" = "5" ] && [ "$branch" = "$current_train" ]; then
            continue
        fi
        if [ "$variant" != "5" ]; then
            reason="not used by variant #$variant"
        else
            reason="superseded by $current_train"
        fi
        if [ "$branch" = "$(flowCurrentBranch)" ] || [ -n "$(flowBranchWorktree "$branch")" ]; then
            unused_notes+=("Warning: $branch is checked out - left alone")
        elif flowBranchChangesIn "$branch" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
            unused_local+=("$branch|$reason, fully promoted")
        else
            unused_notes+=("Warning: $branch has unmerged content - left alone")
        fi
    done

    if [ "${#unused_local[@]}" -gt 0 ] || [ "${#unused_remote[@]}" -gt 0 ] || [ "${#unused_notes[@]}" -gt 0 ]; then
        cliHeader3 "Flow branches not used by variant #$variant"
        for entry in "${unused_local[@]}" "${unused_remote[@]}"; do
            [ -n "$entry" ] || continue
            printf -- '- %s (%s);\n' "${entry%%|*}" "${entry#*|}"
        done
        if [ "${#unused_local[@]}" -gt 0 ] || [ "${#unused_remote[@]}" -gt 0 ]; then
            printf '\n'
        fi
        for note in "${unused_notes[@]}"; do
            [ -n "$note" ] || continue
            cliWarning "${note#Warning: }"
        done
        if [ "${#unused_local[@]}" -gt 0 ] || [ "${#unused_remote[@]}" -gt 0 ]; then
            if flowClearAsk "Remove these flow branches (local and remote)?"; then
                for entry in "${unused_local[@]}" "${unused_remote[@]}"; do
                    [ -n "$entry" ] || continue
                    flowClearRemove "${entry%%|*}"
                    removed_total=$((removed_total + 1))
                done
                printf '\n'
                cliSuccess "Flow branches cleaned (total removals: $removed_total)"
            else
                cliInfo "Declined - the flow branches stay"
            fi
        fi
    fi

    if [ "$removed_total" -eq 0 ] && [ "${#merged_local[@]}" -eq 0 ] \
        && [ "${#merged_remote[@]}" -eq 0 ] && [ "${#unused_local[@]}" -eq 0 ] \
        && [ "${#unused_remote[@]}" -eq 0 ]; then
        cliSuccess "Nothing to clean - no stale branches"
    fi

}

cliFrameInit
flowClear "$@"
