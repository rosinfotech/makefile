#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowStamp() {

    local variant branch mode next old recompute attempt train
    local variant_sync="" sync_open=1

    variant=$(flowRequireFlow) || exit 1

    if [ "$variant" = "1" ]; then
        cliWarning "Direct to Main Flow: the commit is the seal - redirecting to make git_flow_commit_push"
        exec "$LIB_DIR/git_flow_commit_push.sh" "$@" --redirected
    fi

    cliParseArgs "$@"

    branch=$(flowCurrentBranch)
    if [ "$branch" != "$FLOW_MAIN_BRANCH" ]; then
        main_worktree=$(flowMainWorktree)
        if [ -n "$(git -C "$main_worktree" status --porcelain)" ]; then
            cliError "The repository worktree is dirty - commit or stash before stamping"
            cliHint "git -C $main_worktree status."
            printf '\n' >&2
            exit 1
        fi
        git -C "$main_worktree" checkout "$FLOW_MAIN_BRANCH" >/dev/null 2>&1 || {
            cliError "Failed to switch the repository worktree to $FLOW_MAIN_BRANCH"
            exit 1
        }
        cd "$main_worktree"
        cliInfo "Switched the repository worktree to $FLOW_MAIN_BRANCH"
    fi

    flowRequireCleanTree || exit 1

    if flowHasRemote; then
        git fetch origin >/dev/null 2>&1 || true
        if git show-ref --verify --quiet "refs/remotes/origin/$FLOW_MAIN_BRANCH" 2>/dev/null; then
            git merge --ff-only "origin/$FLOW_MAIN_BRANCH" >/dev/null 2>&1 || {
                cliError "$FLOW_MAIN_BRANCH diverged from origin/$FLOW_MAIN_BRANCH - rebase manually"
                exit 1
            }
        fi
    fi

    if [ -n "$(flowFragmentList)" ]; then
        mode="assemble"
        if ! flowReleaseGate; then
            cliInfo "Stamp deferred - the fragments accumulate into the next version"
            cliHint 'Answer y at the gate or rerun with args="--release" to tag.'
            printf '\n' >&2
            exit 0
        fi
        next=$(getVersion) || exit 1
        next=$(flowVersionPrompt "$next")
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
        old=$(flowLatestTag "origin/$FLOW_MAIN_BRANCH")
        flowSubstituteVersion "$old" "$next"

        echo "=== CHANGELOG section assembled:"
        printf '\n'
        sed -n "/^## \[$next\]/,/^## \[/p" CHANGELOG.md | sed '$d' | sed -e :a -e '/^$/{$d;N;ba' -e '}'
        printf '\n'
        cliHint "You can edit CHANGELOG.md now, then answer Y."
        printf '\n' >&2
        if ! flowConfirm "Continue with the seal?"; then
            cliInfo "Declined - the assembled changes stay in the working tree, nothing committed"
            cliHint "Edit CHANGELOG.md and rerun make git_flow_seal, or reset with: git checkout -- ."
            printf '\n' >&2
            exit 1
        fi

        git add .
        git commit -m "$next: $FLOW_SECTION_TYPE: $FLOW_SECTION_MSG" >/dev/null 2>&1 || {
            cliError "Failed to create the seal commit"
            exit 1
        }
    else
        next=$(sed -n '1p' .version | tr -d '\n\r' 2>/dev/null)
        old=$(flowLatestTag "origin/$FLOW_MAIN_BRANCH")
        if flowIsSemver "$next" && [ "$old" = "$next" ]; then
            cliInfo "Already stamped: $next - syncing the branches"
            variant_sync=1
        else
            cliError "No changelog fragments on $FLOW_MAIN_BRANCH - nothing to stamp"
            exit 1
        fi
    fi

    if [ -z "$variant_sync" ]; then

    attempt=0
    while :; do
        attempt=$((attempt + 1))

        if [ "$attempt" -eq 1 ]; then
            if git rev-parse "$next" >/dev/null 2>&1; then
                cliError "Tag $next already exists"
                exit 1
            fi
        else
            git tag -d "$next" >/dev/null 2>&1
        fi

        git tag "$next" >/dev/null 2>&1 || {
            cliError "Failed to create the tag $next"
            exit 1
        }

        if ! flowHasRemote; then
            cliSuccess "Stamped $next (local tag, no remote to push)"
            break
        fi

        if git show-ref --verify --quiet "refs/remotes/origin/$FLOW_MAIN_BRANCH" 2>/dev/null; then
            git push --atomic origin "$FLOW_MAIN_BRANCH" "refs/tags/$next" >/dev/null 2>&1 && break
        else
            git push --atomic --set-upstream origin "$FLOW_MAIN_BRANCH" "refs/tags/$next" >/dev/null 2>&1 && break
        fi

        git fetch origin --tags >/dev/null 2>&1

        recompute=$(flowNextVersion "origin/$FLOW_MAIN_BRANCH")

        if [ "$recompute" = "$next" ] || [ "$attempt" -ge 3 ]; then
            cliError "Failed to push $FLOW_MAIN_BRANCH and the tag $next"
            exit 1
        fi

        cliWarning "Tag $next was taken concurrently - re-stamping as $recompute"
        sed -i '' "s|^## \[$next\]|## [$recompute]|" CHANGELOG.md
        flowUpdateVersionArtifact "$recompute"
        flowSubstituteVersion "$next" "$recompute" >/dev/null
        git add .
        if [ "$mode" = "assemble" ]; then
            git commit --amend -m "$recompute: $FLOW_SECTION_TYPE: $FLOW_SECTION_MSG" >/dev/null 2>&1
        else
            git commit -m "$recompute: Changed: Version re-stamp after a concurrent entry" >/dev/null 2>&1
        fi
        next="$recompute"
    done
    fi

    if [ -z "$variant_sync" ]; then
        if flowHasRemote; then
            cliSuccess "Stamped $next (tag pushed atomically with $FLOW_MAIN_BRANCH)"
        fi
        flowGitHubRelease "$next"
    fi

    case "$variant" in
        3)
            flowUpdateBranchFromMain develop && printf '\n'
            ;;
        4)
            flowUpdateBranchFromMain develop
            flowUpdateBranchFromMain staging && printf '\n'
            ;;
        5)
            flowUpdateBranchFromMain develop
            sync_open=$?
            for train in $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
                train_version="$(echo "$train" | sed 's|^release/||').0"
                if [ -n "$train_version" ] && flowIsSemver "$train_version" && \
                    [ "$(semverCompare "$train_version" "$next")" -le 0 ]; then
                    bumped="release/$(flowBumpMinorBase "$next")"
                    if [ "$bumped" != "$train" ]; then
                        [ "$sync_open" -eq 0 ] && printf '\n'
                        sync_open=1
                        cliWarning "The train $train already shipped - bumping to $bumped"
                        git branch -m "$train" "$bumped" 2>/dev/null
                        if git show-ref --verify --quiet "refs/remotes/origin/$train" 2>/dev/null; then
                            git push -u origin "$bumped" >/dev/null 2>&1
                            git push origin --delete "$train" >/dev/null 2>&1
                        fi
                        cliInfo "Train bumped: $bumped"
                    fi
                else
                    flowUpdateBranchFromMain "$train"
                    sync_open=$?
                fi
            done
            [ "$sync_open" -eq 0 ] && printf '\n'
            ;;
    esac

    flowCleanupMergedBranches

}

cliFrameInit
flowStamp "$@"
