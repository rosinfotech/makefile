#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowAssemble() {

    local variant branch next old reason

    variant=$(flowRequireFlow) || exit 1

    reason=""
    case "$variant" in
        1|2|3) reason="the stamp assembles on main directly (make git_flow_seal)" ;;
    esac
    flowRequireVariant "$variant" "4 5" "$reason"

    if [ "$variant" -eq 5 ]; then
        target=$(flowCurrentTrain) || exit 1
    else
        target="staging"
    fi

    branch=$(flowCurrentBranch)
    if [ "$branch" != "$target" ]; then
        main_worktree=$(flowMainWorktree)
        if [ -n "$(git -C "$main_worktree" status --porcelain)" ]; then
            cliError "The repository worktree is dirty - commit or stash before assembling"
            cliHint "git -C $main_worktree status."
            exit 1
        fi
        git -C "$main_worktree" checkout "$target" >/dev/null 2>&1 || {
            if git show-ref --verify --quiet "refs/remotes/origin/$target" 2>/dev/null; then
                git -C "$main_worktree" checkout -b "$target" "origin/$target" >/dev/null 2>&1 || {
                    cliError "Failed to switch the repository worktree to $target"
                    exit 1
                }
            else
                cliError "Failed to switch the repository worktree to $target"
                exit 1
            fi
        }
        if flowHasRemote && git show-ref --verify --quiet "refs/remotes/origin/$target" 2>/dev/null; then
            git -C "$main_worktree" fetch origin "$target" >/dev/null 2>&1 || true
            git -C "$main_worktree" merge --ff-only "origin/$target" >/dev/null 2>&1 || true
        fi
        cd "$main_worktree"
        cliInfo "Switched the repository worktree to $target"
        branch="$target"
    fi

    if [ "$variant" -eq 4 ] && [ "$branch" != "staging" ]; then
        cliError "git_flow_prepare_release runs on staging (current: ${branch:-none})"
        exit 1
    fi
    if [ "$variant" -eq 5 ]; then
        echo "$branch" | grep -qE '^release/[0-9]+\.[0-9]+$' || {
            cliError "git_flow_prepare_release runs on a release/x.y branch (current: ${branch:-none})"
            exit 1
        }
    fi

    flowRequireCleanTree || exit 1

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
    fi

    if [ -z "$(flowFragmentList)" ]; then
        cliError "No changelog fragments in $FLOW_FRAGMENTS_DIR/ - nothing to assemble"
        exit 1
    fi

    if [ "$variant" -eq 5 ]; then
        next="$(echo "$branch" | sed 's|^release/||').0"
    else
        next=$(getVersion "origin/$FLOW_MAIN_BRANCH") || exit 1
    fi

    old=$(flowLatestTag "origin/$FLOW_MAIN_BRANCH")

    if [ "$variant" -eq 5 ] && [ -n "$old" ] && isSemver "$old" &&         [ "$(semverCompare "$next" "$old")" -le 0 ]; then
        bumped="release/$(flowBumpMinorBase "$old")"
        cliWarning "The train $branch already shipped ($next <= tag $old) - bumping to $bumped"
        git branch -m "$bumped"
        if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
            git push -u origin "$bumped" >/dev/null 2>&1
            git push origin --delete "$branch" >/dev/null 2>&1
        fi
        cliInfo "Train bumped: $bumped (entering main stamps ${bumped#release/}.0)"
        branch="$bumped"
        next="${bumped#release/}.0"
    fi

    if [ -n "$old" ] && [ "$old" = "$next" ]; then
        cliError "The assembled version $next equals the last tag - nothing new to assemble"
        exit 1
    fi

    flowAssembleSection "$next"

    if [ -z "$FLOW_SECTION_MSG" ]; then
        rm -f "$FLOW_SECTION_FILE"
        cliError "The fragments are empty"
        exit 1
    fi

    flowInsertChangelogSection "$FLOW_SECTION_FILE"
    rm -f "$FLOW_SECTION_FILE"
    rm -f "$FLOW_FRAGMENTS_DIR"/*.md
    flowUpdateVersionArtifact "$next"
    if flowSubstituteVersion "$old" "$next"; then
        if ! flowConfirm "Continue with the assembly commit?"; then
            flowDeclined
        fi
    fi

    git add .
    git commit -m "$next: $FLOW_SECTION_TYPE: $FLOW_SECTION_MSG" >/dev/null 2>&1 || {
        cliError "Failed to create the assembly commit"
        exit 1
    }

    git push origin "$branch" >/dev/null 2>&1 || {
        cliError "Failed to push $branch"
        exit 1
    }

    cliSuccess "Assembled $next on $branch (fragments consumed, CHANGELOG section written)"
    printf -- '- promotion merge request: %s -> %s;\n' "$branch" "$FLOW_MAIN_BRANCH"
    printf -- '- merge request title: %s: %s;\n' "$FLOW_SECTION_TYPE" "$FLOW_SECTION_MSG"
    flowMergeRequestUrl "$branch" "$FLOW_MAIN_BRANCH"
    cliHint "Enable squash in the merge request (the title carries no version - the tag is the truth)."
    cliHint "After it merges: make git_flow_seal (it switches to $FLOW_MAIN_BRANCH itself)."

}

cliFrameInit
flowAssemble "$@"
