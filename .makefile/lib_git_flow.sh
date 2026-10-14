#!/bin/bash
#
# lib_git_flow.sh - the shared machinery of the Git Flow Standard commands
# (github.com/rosinfotech/standards#the-git-flow-standard). A library, not a
# command: sourced by git_flow_*.sh, git_task_*.sh, git_flow_hotfix_start.sh.
#
# The variant matrix (the fork point equals the merge-request target,
# rule #2610082116):
#   #1 Trunk-Based Development - no branches, commits land in main directly
#   #2 GitHub Flow             - fork main, free merge into main
#   #3 Git Flow Lite           - fork main, MR into main, free merge into develop
#   #4 GitLab Flow Lite        - fork staging, MR into staging, promotion to main
#   #5 Git Flow                - fork release/x.y, MR into the train, release to main

FLOW_MAIN_BRANCH="main"
FLOW_DEV_BRANCH="develop"
FLOW_DIR=".git_flow"
FLOW_MARKER_PREFIX=".git-flow-"
FLOW_LEGACY_PREFIX=".github-com-rosinfotech-"
FLOW_FRAGMENTS_DIR=".git_flow/changelog_fragments"
FLOW_TYPE_ORDER="added changed fixed deprecated removed security"
FLOW_STANDARD_API="${FLOW_STANDARD_API:-https://api.github.com/repos/rosinfotech/standards/contents/standards/git-flow-standard/assets}"
FLOW_STANDARD_RAW="${FLOW_STANDARD_RAW:-https://raw.githubusercontent.com/rosinfotech/standards/master/standards/git-flow-standard/assets}"

[ -n "$LIB_DIR" ] && [ -f "$LIB_DIR/lib_version_get.sh" ] && source "$LIB_DIR/lib_version_get.sh"
[ -n "$LIB_DIR" ] && [ -f "$LIB_DIR/lib_cli.sh" ] && source "$LIB_DIR/lib_cli.sh"

flowMarkerInfo() { # marker file -> "number|name" from its Flow line
    sed -n 's/^Flow: Variant #\([0-9][0-9]*\) - \(.*\)$/\1|\2/p' "$1" 2>/dev/null | head -n 1
}

flowMarkerPath() { # prints the regulating file: .git_flow/.git-flow-*, legacy root marker, or empty
    local marker
    for marker in "$FLOW_DIR"/"$FLOW_MARKER_PREFIX"*; do
        [ -e "$marker" ] && { echo "$marker"; return 0; }
    done
    for marker in ${FLOW_LEGACY_PREFIX}*; do
        [ -e "$marker" ] && { echo "$marker"; return 0; }
    done
    return 1
}

flowVariantLabel() { # number -> the declared variant name (the repo flow file, no network)
    local info
    if info=$(flowMarkerInfo "$(flowMarkerPath)" 2>/dev/null); then
        if [ "${info%%|*}" = "$1" ]; then
            echo "${info#*|}"
            return 0
        fi
    fi
    echo "Variant #$1"
}

flowRequireHttp() {
    command -v curl >/dev/null 2>&1 || {
        cliError "curl is required to fetch the standard assets"
        return 1
    }
}

flowStandardCatalog() { # prints "number<TAB>name<TAB>asset" per marker asset of the standard
    local listing asset info
    flowRequireHttp || return 1
    listing=$(curl -fsSL --max-time 20 "$FLOW_STANDARD_API") || {
        cliError "Cannot fetch the assets listing from the standards repository"
        cliHint "$FLOW_STANDARD_API."
        printf '\n' >&2
        return 1
    }
    for asset in $(printf '%s' "$listing" \
        | sed -n 's/.*"name": *"\('"$FLOW_MARKER_PREFIX"'[a-z0-9-]*\)".*/\1/p' | sort -u); do
        info=$(curl -fsSL --max-time 20 "$FLOW_STANDARD_RAW/$asset" \
            | sed -n 's/^Flow: Variant #\([0-9][0-9]*\) - \(.*\)$/\1|\2/p' | head -n 1)
        [ -z "$info" ] && continue
        printf '%s\t%s\t%s\n' "${info%%|*}" "${info#*|}" "$asset"
    done
}

flowFetchMarkerAsset() { # asset name dest -> writes the marker content as-is
    flowRequireHttp || return 1
    curl -fsSL --max-time 20 "$FLOW_STANDARD_RAW/$1" -o "$2" || {
        cliError "Cannot fetch the marker asset $1"
        cliHint "$FLOW_STANDARD_RAW/$1."
    printf '\n' >&2
        rm -f "$2"
        return 1
    }
}

flowTypeTitle() {
    echo "$1" | awk '{ print toupper(substr($0, 1, 1)) substr($0, 2) }'
}

flowRequireGitRepo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
        cliError "Not a git repository"
        exit 1
    }
}

flowDetectVariant() {
    local marker info
    marker=$(flowMarkerPath) || return 1
    info=$(flowMarkerInfo "$marker")
    if [ -z "$info" ]; then
        cliError "Malformed flow file $marker (no 'Flow: Variant #N' line)"
        exit 1
    fi
    echo "${info%%|*}"
}

flowRequireFlow() {
    flowRequireGitRepo
    local variant
    variant=$(flowDetectVariant)
    if [ -z "$variant" ]; then
        cliError "No flow declared (.git_flow/.git-flow-* missing) - declare the variant first"
        cliHint "make git_flow_init <number>."
        printf '\n' >&2
        exit 1
    fi
    echo "$variant"
}

flowRequireVariant() {
    local variant="$1" allowed="$2" reason="$3"
    case " $allowed " in
        *" $variant "*) return 0 ;;
    esac
    cliError "$(flowVariantLabel "$variant") does not use this command - $reason"
    exit 1
}

flowHasRemote() {
    git remote | grep -q .
}

flowRemoteBaseRef() {
    if git show-ref --verify --quiet "refs/remotes/origin/$1" 2>/dev/null; then
        echo "origin/$1"
    else
        echo "$1"
    fi
}

flowCurrentBranch() {
    git symbolic-ref --short HEAD 2>/dev/null
}

flowCurrentTrain() {
    local train
    train=$(git for-each-ref --sort=committerdate --format='%(refname:short)' \
        'refs/heads/release/*' | tail -n 1)
    if [ -z "$train" ]; then
        train=$(git for-each-ref --sort=committerdate --format='%(refname:short)' \
            'refs/remotes/origin/release/*' | tail -n 1 | sed 's|^origin/||')
    fi
    [ -n "$train" ] && echo "$train"
}

flowForkBase() {
    case "$1" in
        2|3) echo "$FLOW_MAIN_BRANCH" ;;
        4) echo "staging" ;;
        5)
            flowCurrentTrain || {
                cliError "Variant #5 requires an active release/x.y train"
                cliHint "make git_flow_init 5 creates one."
                printf '\n' >&2
                exit 1
            }
            ;;
    esac
}

flowMainWorktree() {
    git worktree list --porcelain | awk '/^worktree /{ print $2; exit }'
}

flowBranchWorktree() {
    git worktree list --porcelain | awk -v b="refs/heads/$1" '
        $0 == "branch " b { print wt; exit }
        /^worktree / { wt = $2 }
    '
}

flowRequireCleanTree() {
    if [ -n "$(git status --porcelain)" ]; then
        cliError "Working tree is not clean - commit or stash first"
        return 1
    fi
}

flowTaskLabelFromBranch() {
    echo "$1" | grep -oE '[0-9]{10}' | head -n 1
}

flowSeniorFragment() { # prints "<Type>: <line>" - the senior fragment of the given task label
    local label="$1" type fragment line
    for type in $FLOW_TYPE_ORDER; do
        for fragment in "$FLOW_FRAGMENTS_DIR"/"$label"."$type".md; do
            [ -e "$fragment" ] || continue
            line=$(sed '/^[[:space:]]*$/d' "$fragment" | head -n 1)
            if [ -n "$line" ]; then
                echo "$(flowTypeTitle "$type"): $line"
                return 0
            fi
        done
    done
    return 1
}

flowRequireTaskCommitMessage() { # message -> validates "<Type>: <message>" on task/hotfix branches
    local message="$1" branch type rest
    branch=$(flowCurrentBranch)
    case "$branch" in
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*|\
hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        *)
            return 0
            ;;
    esac
    type=$(echo "${message%%:*}" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')
    rest=$(echo "${message#*:}" | sed 's/^ *//; s/ *$//')
    if ! echo "$FLOW_TYPE_ORDER" | grep -qw "$type" || [ -z "$rest" ]; then
        cliError "Task commits follow \"<Type>: <message>\" - got '${message}'"
        cliHint "Types: $(echo $FLOW_TYPE_ORDER | sed 's/ /, /g')."
        printf '\n' >&2
        exit 2
    fi
    return 0
}

flowIsSemver() {
    echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'
}

flowLatestTag() {
    git describe --tags --abbrev=0 "$1" 2>/dev/null
}

flowBumpPatch() {
    echo "$1" | awk -F. '{ print $1 "." $2 "." ($3 + 1) }'
}

flowBumpMinorBase() {
    echo "$1" | awk -F. '{ print $1 "." ($2 + 1) }'
}

flowBootstrapVersion() {
    local legacy=""
    [ -f .version ] && legacy=$(sed -n '1p' .version | tr -d '\n\r')
    if flowIsSemver "$legacy"; then
        echo "$legacy"
    else
        echo "0.1.0"
    fi
}

flowNextVersion() {
    local last
    last=$(flowLatestTag "$1")
    if [ -n "$last" ] && flowIsSemver "$last"; then
        flowBumpPatch "$last"
    else
        flowBootstrapVersion
    fi
}

flowFragmentList() {
    local fragment
    for fragment in "$FLOW_FRAGMENTS_DIR"/*.md; do
        [ -e "$fragment" ] && echo "$fragment"
    done
}

flowFragmentListType() {
    local fragment
    for fragment in "$FLOW_FRAGMENTS_DIR"/*."$1".md; do
        [ -e "$fragment" ] && echo "$fragment"
    done
}

flowAssembleSection() {
    local version="$1" type fragment line
    FLOW_SECTION_TYPE=""
    FLOW_SECTION_MSG=""
    FLOW_SECTION_FILE="$(mktemp)"
    echo "## [$version] - $(date +%Y-%m-%d)" > "$FLOW_SECTION_FILE"
    for type in $FLOW_TYPE_ORDER; do
        [ -z "$(flowFragmentListType "$type")" ] && continue
        echo "" >> "$FLOW_SECTION_FILE"
        echo "### $(flowTypeTitle "$type")" >> "$FLOW_SECTION_FILE"
        echo "" >> "$FLOW_SECTION_FILE"
        for fragment in $(flowFragmentListType "$type"); do
            while IFS= read -r line; do
                [ -z "$line" ] && continue
                echo "- $line" >> "$FLOW_SECTION_FILE"
                if [ -z "$FLOW_SECTION_MSG" ]; then
                    FLOW_SECTION_TYPE=$(flowTypeTitle "$type")
                    FLOW_SECTION_MSG="$line"
                fi
            done < "$fragment"
        done
    done
}

flowInsertChangelogSection() {
    local section_file="$1"
    if [ ! -f CHANGELOG.md ] || ! grep -q '^# Changelog$' CHANGELOG.md; then
        {
            echo "<!-- markdownlint-disable MD041 -->"
            echo ""
            echo "# Changelog"
            echo ""
            cat CHANGELOG.md 2>/dev/null
        } > CHANGELOG.md.new
        mv CHANGELOG.md.new CHANGELOG.md
    fi
    awk -v section="$section_file" '
        /^# Changelog$/ && !done {
            print
            print ""
            while ((getline line < section) > 0) {
                print line
            }
            done = 1
            next
        }
        { print }
    ' CHANGELOG.md > CHANGELOG.md.new
    mv CHANGELOG.md.new CHANGELOG.md
}

flowUpdateVersionArtifact() {
    local version="$1" list=""
    [ -f .version ] && list=$(sed -n '3,$p' .version)
    {
        echo "$version"
        echo "$version"
        [ -n "$list" ] && printf '%s\n' "$list"
    } > .version
}

flowVersionTargets() {
    [ -f .version ] || return 0
    sed -n '3,$p' .version
}

flowSubstituteParseEntry() { # entry -> sets FLOW_ENTRY_PATH / FLOW_ENTRY_LINE
    FLOW_ENTRY_PATH="$1"
    FLOW_ENTRY_LINE=""
    case "$1" in
        *:[0-9]*)
            FLOW_ENTRY_PATH="${1%:*}"
            FLOW_ENTRY_LINE="${1##*:}"
            ;;
    esac
}

flowSubstituteScan() { # old -> prints "path:lineno" for every pending replacement
    local old="$1" entry hit
    [ -z "$old" ] && return 0
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        flowSubstituteParseEntry "$entry"
        [ -f "$FLOW_ENTRY_PATH" ] || continue
        if [ -n "$FLOW_ENTRY_LINE" ]; then
            sed -n "${FLOW_ENTRY_LINE}p" "$FLOW_ENTRY_PATH" | grep -nw "$old" >/dev/null && \
                echo "${FLOW_ENTRY_PATH}:${FLOW_ENTRY_LINE}"
        else
            grep -nw "$old" "$FLOW_ENTRY_PATH" 2>/dev/null | cut -d: -f1 | while read -r hit; do
                echo "${FLOW_ENTRY_PATH}:${hit}"
            done
        fi
    done <<TARGETS
$(flowVersionTargets)
TARGETS
}

flowSubstituteApply() { # old new
    local old="$1" new="$2" entry
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        flowSubstituteParseEntry "$entry"
        [ -f "$FLOW_ENTRY_PATH" ] || continue
        if [ -n "$FLOW_ENTRY_LINE" ]; then
            sed -i '' "${FLOW_ENTRY_LINE}s/[[:<:]]$old[[:>:]]/$new/g" "$FLOW_ENTRY_PATH"
        else
            sed -i '' "s/[[:<:]]$old[[:>:]]/$new/g" "$FLOW_ENTRY_PATH"
        fi
    done <<TARGETS
$(flowVersionTargets)
TARGETS
}

flowConfirm() { # question -> 0 yes, 1 no; FLOW_YES (agents, pipelines) or a non-TTY stream bypasses
    local answer
    case "${FLOW_YES:-}" in
        ''|0|[nN][oO]|[fF][aA][lL][sS][eE]) ;;
        *) return 0 ;;
    esac
    [ -t 0 ] || return 0
    if [ "$CLI_COLOR_ERR" = "1" ]; then
        printf '%s%s [Y/n]: %s' "$CLI_CYAN" "$1" "$CLI_RESET" >&2
    else
        printf '%s [Y/n]: ' "$1" >&2
    fi
    if ! read -r answer; then
        return 0
    fi
    printf '\n' >&2
    case "$answer" in
        ''|[yY]|[yY][eE][sS]) return 0 ;;
        [nN]|[nN][oO]) return 1 ;;
        *)
            cliError "Unknown answer '${answer}' - expected Y or n"
            exit 2
            ;;
    esac
}

flowDeclined() {
    cliInfo "Declined - the substitution stays in the working tree, nothing committed"
    cliHint "Review the files, rerun the command to continue, or revert with: git checkout -- ."
    printf '\n' >&2
    exit 1
}


flowVersionPrompt() { # computed_version -> echoes the version to use (may be overridden)
    local computed="$1" answer
    case "${FLOW_YES:-}" in
        1|[tT][rR][uU][eE]|[yY][eE][sS]) echo "$computed"; return 0 ;;
    esac
    [ -t 0 ] || { echo "$computed"; return 0; }
    printf '%sVersion to be applied: %s%s\n\n' "$CLI_CYAN" "$computed" "$CLI_RESET" >&2
    printf '%sUse this? [Y] or type a different version: %s' "$CLI_CYAN" "$CLI_RESET" >&2
    if ! read -r answer; then
        printf '\n' >&2
        echo "$computed"
        return 0
    fi
    printf '\n' >&2
    case "$answer" in
        ''|[yY]|[yY][eE][sS])
            echo "$computed"
            return 0
            ;;
        *)
            if ! flowIsSemver "$answer"; then
                cliError "Invalid version '${answer}' - expected format X.Y.Z"
                exit 2
            fi
            echo "$answer"
            return 0
            ;;
    esac
}

flowReleaseGate() { # -> 0 tag now, 1 defer; FLOW_RELEASE forces; the default (incl. a non-TTY stream) defers
    local answer
    case "${FLOW_RELEASE:-}" in
        1|[tT][rR][uU][eE]|[yY][eE][sS]) return 0 ;;
        0|[fF][aA][lL][sS][eE]|[nN][oO]) return 1 ;;
    esac
    [ -t 0 ] || return 1
    if [ "$CLI_COLOR_ERR" = "1" ]; then
        printf '%s%s [y/N]: %s' "$CLI_CYAN" "Tag now (the tag may trigger a deploy)?" "$CLI_RESET" >&2
    else
        printf 'Tag now (the tag may trigger a deploy)? [y/N]: ' >&2
    fi
    if ! read -r answer; then
        return 1
    fi
    printf '\n' >&2
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        ''|[nN]|[nN][oO]) return 1 ;;
        *)
            cliError "Unknown answer '${answer}' - expected y or N"
            exit 2
            ;;
    esac
}

flowSubstituteVersion() { # old new - applies the substitution, reports; 0 = substituted, 1 = nothing to do
    local old="$1" new="$2" scan
    [ -z "$old" ] && return 1
    [ "$old" = "$new" ] && return 1
    scan=$(flowSubstituteScan "$old")
    if [ -z "$scan" ]; then
        if [ -n "$(flowVersionTargets)" ]; then
            cliInfo "No occurrences of ${old} in the .version targets - nothing to substitute"
        fi
        return 1
    fi
    flowSubstituteApply "$old" "$new"
    cliInfo "Version substitution applied (${old} -> ${new}):"
    echo "$scan" | sed 's/^/    - /; s/$/;/'
    printf '\n'
    cliInfo "$(echo "$scan" | wc -l | tr -d ' ') location(s) substituted"
    return 0
}

flowRefreshGateFromMain() { # branch - resets a fully-promoted stale gate branch to main; reports
    local branch="$1"
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null || return 0
    git diff --quiet "$FLOW_MAIN_BRANCH" "$branch" 2>/dev/null && return 0
    if flowBranchChangesIn "$branch" "$FLOW_MAIN_BRANCH" 2>/dev/null; then
        git push . "+$FLOW_MAIN_BRANCH:$branch" >/dev/null 2>&1
        if flowHasRemote; then
            git push --force-with-lease origin "$branch" >/dev/null 2>&1
        fi
        cliInfo "$branch reset to $FLOW_MAIN_BRANCH (stale after the previous cycle)"
    else
        cliWarning "$branch has unmerged content - not resetting"
    fi
    return 0
}

flowEnsureBranch() {
    local branch="$1" base="$2"
    if ! git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
        git branch "$branch" "$base"
        cliInfo "Branch created: $branch (from $base)"
    fi
    if flowHasRemote && ! git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        if git push -u origin "$branch" >/dev/null 2>&1; then
            cliInfo "Branch pushed: $branch"
        else
            cliWarning "Failed to push $branch to origin"
        fi
    fi
}

flowUpdateBranchFromMain() {
    local branch="$1" worktree tmp
    # Clean up stale temp worktrees from previous failed merges
    local stale
    stale=$(flowBranchWorktree "$branch")
    if [ -n "$stale" ]; then
        case "$stale" in
            /tmp/*|/var/folders/*|/private/var/folders/*)
                git worktree remove --force "$stale" >/dev/null 2>&1
                rm -rf "$stale" 2>/dev/null
                git worktree prune
                ;;
        esac
    fi
    # Update the local branch from origin first (PR merges happen on the platform)
    if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
        if ! git diff --quiet "$branch" "origin/$branch" 2>/dev/null; then
            local wt
            wt=$(flowBranchWorktree "$branch")
            if [ -n "$wt" ]; then
                git -C "$wt" merge --ff-only "origin/$branch" >/dev/null 2>&1
            else
                git fetch . "origin/$branch:$branch" >/dev/null 2>&1
            fi
        fi
    fi
    flowUpdateBranchFromMainOnce "$@"
    local once_result=$?
    if [ "$once_result" -eq 0 ]; then
        # after a merge the stale-fragment delta may qualify for a reset - re-check once
        branch_tree=$(git rev-parse "$branch^{tree}" 2>/dev/null)
        main_tree=$(git rev-parse "$FLOW_MAIN_BRANCH^{tree}" 2>/dev/null)
        if [ -n "$branch_tree" ] && [ -n "$main_tree" ] && [ "$branch_tree" != "$main_tree" ] &&             [ -z "$(git diff --name-only "$FLOW_MAIN_BRANCH" "$branch" | grep -v "^$FLOW_FRAGMENTS_DIR/")" ]; then
            flowUpdateBranchFromMainOnce "$branch" "force-reset"
        fi
    fi
    return $once_result
}

flowUpdateBranchFromMainOnce() {
    local branch="$1" worktree tmp
    local branch_tree main_tree
    branch_tree=$(git rev-parse "$branch^{tree}" 2>/dev/null)
    main_tree=$(git rev-parse "$FLOW_MAIN_BRANCH^{tree}" 2>/dev/null)
    local reset_reason=""
    if [ -n "$branch_tree" ] && [ "$branch_tree" = "$main_tree" ]; then
        reset_reason="content identical"
    elif [ -n "$branch_tree" ] && [ -z "$(git diff --name-only "$FLOW_MAIN_BRANCH" "$branch" | grep -v "^$FLOW_FRAGMENTS_DIR/")" ]; then
        reset_reason="only stale fragments differ"
    fi
    if [ -n "$reset_reason" ]; then
        worktree=$(flowBranchWorktree "$branch")
        if [ -n "$worktree" ]; then
            if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
                cliWarning "$branch is checked out dirty in $worktree - reset skipped"
                return 1
            fi
            git -C "$worktree" reset --hard "$FLOW_MAIN_BRANCH" >/dev/null 2>&1
        else
            git push . "+$FLOW_MAIN_BRANCH:$branch" >/dev/null 2>&1
        fi
        if flowHasRemote; then
            git push --force-with-lease origin "$branch" >/dev/null 2>&1 || {
                cliWarning "Failed to push the $branch reset"
                return 1
            }
        fi
        printf -- '- reset: %s -> %s (%s);\n' "$branch" "$FLOW_MAIN_BRANCH" "$reset_reason"
        return 0
    fi
    if flowBranchPatchesIn "$branch" "$FLOW_MAIN_BRANCH"; then
        worktree=$(flowBranchWorktree "$branch")
        if [ -n "$worktree" ]; then
            if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
                cliWarning "$branch is checked out dirty in $worktree - reset skipped"
                return 1
            fi
            git -C "$worktree" reset --hard "$FLOW_MAIN_BRANCH" >/dev/null 2>&1
        else
            git push . "+$FLOW_MAIN_BRANCH:$branch" >/dev/null 2>&1
        fi
        if flowHasRemote; then
            git push --force-with-lease origin "$branch" >/dev/null 2>&1 || {
                cliWarning "Failed to push the $branch reset"
                return 1
            }
        fi
        printf -- '- reset: %s -> %s (fully promoted);\n' "$branch" "$FLOW_MAIN_BRANCH"
        return 0
    fi
    if [ "$branch" = "$(flowCurrentBranch)" ]; then
        flowRequireCleanTree || return 1
        if ! git merge --no-edit "$FLOW_MAIN_BRANCH"; then
            cliError "Conflict syncing $FLOW_MAIN_BRANCH into $branch - resolve manually"
            return 1
        fi
        git push origin "$branch" >/dev/null 2>&1 || {
            cliWarning "Failed to push $branch"
            return 1
        }
        printf -- '- synced: %s -> %s;\n' "$FLOW_MAIN_BRANCH" "$branch"
        return 0
    fi
    worktree=$(flowBranchWorktree "$branch")
    if [ -n "$worktree" ]; then
        if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
            cliWarning "$branch is checked out dirty in $worktree - sync skipped"
            cliHint "git -C $worktree merge $FLOW_MAIN_BRANCH."
            printf '\n' >&2
            return 1
        fi
        if ! git -C "$worktree" merge --no-edit "$FLOW_MAIN_BRANCH"; then
            cliError "Conflict syncing $FLOW_MAIN_BRANCH into $branch - resolve manually"
            return 1
        fi
        git -C "$worktree" push origin "$branch" >/dev/null 2>&1 || {
            cliWarning "Failed to push $branch"
            return 1
        }
        printf -- '- synced: %s -> %s;\n' "$FLOW_MAIN_BRANCH" "$branch"
        return 0
    fi
    if git fetch . "$FLOW_MAIN_BRANCH:$branch" 2>/dev/null; then
        git push origin "$branch" >/dev/null 2>&1 || {
            cliWarning "Failed to push $branch"
            return 1
        }
        printf -- '- synced: %s -> %s;\n' "$FLOW_MAIN_BRANCH" "$branch"
        return 0
    fi
    tmp=$(mktemp -d)
    if git worktree add "$tmp" "$branch" >/dev/null 2>&1; then
        if git -C "$tmp" merge --no-edit "$FLOW_MAIN_BRANCH" >/dev/null 2>&1; then
            git push origin "$branch" >/dev/null 2>&1
            git worktree remove --force "$tmp" >/dev/null 2>&1
            printf -- '- synced: %s -> %s (merged);\n' "$FLOW_MAIN_BRANCH" "$branch"
            return 0
        fi
        cliError "Conflict syncing $FLOW_MAIN_BRANCH into $branch - resolve in $tmp (worktree kept)"
        return 1
    fi
    rm -rf "$tmp"
    cliWarning "$branch cannot sync with $FLOW_MAIN_BRANCH - sync manually"
    cliHint "git checkout $branch && git merge $FLOW_MAIN_BRANCH."
    printf '\n' >&2
    return 1
}

flowBranchPatchesIn() { # branch ref -> 0 when every branch commit is patch-equivalent to ref
    local branch="$1" ref="$2" ahead
    git show-ref --verify --quiet "refs/remotes/origin/$ref" 2>/dev/null && ref="origin/$ref"
    ahead=$(git cherry "$ref" "$branch" 2>/dev/null | grep -c '^+')
    [ "$ahead" = "0" ]
}


flowSealMessage() { # version -> sets FLOW_SEAL_TYPE / FLOW_SEAL_MSG from the CHANGELOG section
    local version="$1" line
    FLOW_SEAL_TYPE=""
    FLOW_SEAL_MSG=""
    while IFS= read -r line; do
        line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$line" ] && continue
        case "$line" in
            "### "*)
                [ -z "$FLOW_SEAL_TYPE" ] && FLOW_SEAL_TYPE=$(printf '%s' "$line" | sed 's/^### //')
                ;;
            "- "*)
                if [ -z "$FLOW_SEAL_MSG" ]; then
                    FLOW_SEAL_MSG=$(printf '%s' "$line" | sed 's/^- //')
                fi
                ;;
        esac
    done < <(awk "/^## \[${version}\]/{found=1;next} /^## \[/{if(found)exit} found{print}" CHANGELOG.md 2>/dev/null)
}


flowGitHubCreatePR() { # branch target -> creates a PR via API, prints URL; falls back to manual link
    local branch="$1" target="$2" repo owner pat title response http_code pr_url
    url=$(git remote get-url origin 2>/dev/null)
    [ -z "$url" ] && return 1
    case "$url" in
        git@github.com:*)
            owner=$(printf '%s' "${url#git@github.com:}" | cut -d/ -f1)
            repo=$(printf '%s' "${url#git@github.com:}" | cut -d/ -f2 | sed 's/\.git$//')
            ;;
        https://github.com/* | https://github.com:*)
            owner=$(printf '%s' "${url#https://github.com/}" | cut -d/ -f1)
            repo=$(printf '%s' "${url#https://github.com/}" | cut -d/ -f2 | sed 's/\.git$//')
            ;;
        *)
            return 1
            ;;
    esac
    pat=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.secrets.json')) as f:
        d = json.load(f)
    print(d['com']['github']['repo']['$repo']['PAT'])
except Exception:
    pass
" 2>/dev/null)
    [ -z "$pat" ] && return 1
    title=$(flowSeniorFragment "$(flowTaskLabelFromBranch "$branch")" 2>/dev/null)
    [ -z "$title" ] && title="Merge $branch into $target"
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${pat}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${owner}/${repo}/pulls" \
        -d "{\"title\":\"${title}\",\"head\":\"${branch}\",\"base\":\"${target}\"}")
    http_code=$(printf '%s' "$response" | tail -1)
    if [ "$http_code" = "201" ]; then
        pr_url=$(printf '%s' "$response" | sed -n 's/.*"html_url": *"\([^"]*pull[^"]*\)".*/\1/p' | head -1)
        [ -n "$pr_url" ] && { printf '%s\n\n' "$pr_url"; return 0; }
    fi
    return 1
}

flowBranchChangesIn() { # branch ref -> 0 when every file the branch changed matches ref
    local branch="$1" ref="$2" base file
    base=$(git merge-base "$branch" "$ref") || return 1
    [ -n "$base" ] || return 1
    for file in $(git diff --name-only "$base" "$branch" 2>/dev/null | grep -v "^$FLOW_FRAGMENTS_DIR/"); do
        git diff --quiet "$ref" "$branch" -- "$file" 2>/dev/null || return 1
    done
    return 0
}

flowMergedBranchList() { # prints task/hotfix branches fully delivered to main or a gate branch
    local branch gate
    for branch in $(git for-each-ref --format='%(refname:short)' \
        'refs/heads/task-*' 'refs/heads/hotfix-*'); do
        flowBranchPatchesIn "$branch" "$FLOW_MAIN_BRANCH" && { echo "$branch"; continue; }
        flowBranchChangesIn "$branch" "$FLOW_MAIN_BRANCH" && { echo "$branch"; continue; }
        for gate in staging $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
            flowBranchPatchesIn "$branch" "$gate" && { echo "$branch"; break; }
            flowBranchChangesIn "$branch" "$gate" && { echo "$branch"; break; }
        done
    done
}

flowCleanupMergedBranches() { # removes the merged branches after a report and a confirmation
    local branch worktree
    local merged
    merged=$(flowMergedBranchList)
    [ -z "$merged" ] && return 0
    cliInfo "Merged task branches to clean up:"
    for branch in $merged; do
        printf -- '- %s;\n' "$branch"
    done
    printf '\n'
    if ! flowConfirm "Remove the merged branches (and their worktrees)?"; then
        cliInfo "Declined - the branches stay"
        return 0
    fi
    for branch in $merged; do
        worktree=$(flowBranchWorktree "$branch")
        if [ -n "$worktree" ]; then
            if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
                cliWarning "The $branch worktree is dirty in $worktree - skipped"
                continue
            fi
            git worktree remove "$worktree" >/dev/null 2>&1 || \
                git worktree remove --force "$worktree" >/dev/null 2>&1
        fi
        git branch -D "$branch" >/dev/null 2>&1
        if git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
            git push origin --delete "$branch" >/dev/null 2>&1
        fi
        printf -- '- removed: %s;\n' "$branch"
    done
    printf '\n'
}


flowGitHubRelease() { # version -> creates a GitHub release if a repo PAT is configured
    local version="$1" repo owner pat body answer response http_code url
    url=$(git remote get-url origin 2>/dev/null)
    [ -z "$url" ] && return 1
    case "$url" in
        git@github.com:*)
            owner=$(printf '%s' "${url#git@github.com:}" | cut -d/ -f1)
            repo=$(printf '%s' "${url#git@github.com:}" | cut -d/ -f2 | sed 's/\.git$//')
            ;;
        https://github.com/* | https://github.com:*)
            owner=$(printf '%s' "${url#https://github.com/}" | cut -d/ -f1)
            repo=$(printf '%s' "${url#https://github.com/}" | cut -d/ -f2 | sed 's/\.git$//')
            ;;
        *)
            return 1
            ;;
    esac
    pat=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.secrets.json')) as f:
        d = json.load(f)
    print(d['com']['github']['repo']['$repo']['PAT'])
except Exception:
    pass
" 2>/dev/null)
    [ -z "$pat" ] && return 1
    printf '%s%s [y/N]: %s' "$CLI_CYAN" "Create GitHub release notes for ${version}?" "$CLI_RESET" >&2
    if ! read -r answer; then
        printf '\n\n' >&2
        return 0
    fi
    if [ -t 0 ]; then
        printf '\n' >&2
    else
        printf '\n\n' >&2
    fi
    case "$answer" in
        [yY]|[yY][eE][sS]) ;;
        *)
            cliInfo "GitHub release skipped"
            return 0
            ;;
    esac
    body=$(awk "/^## \[${version}\]/{found=1;next} /^## \[/{if(found)exit} found{print}" CHANGELOG.md 2>/dev/null | sed '/^$/d')
    body_json=$(printf '%s' "$body" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${pat}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${owner}/${repo}/releases" \
        -d "{\"tag_name\":\"${version}\",\"name\":\"${version}\",\"body\":${body_json}}")
    http_code=$(printf '%s' "$response" | tail -1)
    if [ "$http_code" = "201" ]; then
        cliSuccess "GitHub release created: https://github.com/${owner}/${repo}/releases/tag/${version}"
    else
        cliWarning "GitHub release creation failed (HTTP ${http_code})"
        printf '%s\n' "$response" | head -3 >&2
        printf '\n' >&2
        cliHint "Check the fine-grained PAT has Contents: Read and write for ${owner}/${repo}."
        printf '\n' >&2
    fi
    return 0
}

flowMergeRequestUrl() {
    local branch="$1" target="$2" url
    url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$url" ]; then
        printf '\n' >&2
        cliWarning "No origin remote - create the merge request manually: $branch -> $target"
        return 0
    fi
    case "$url" in
        git@*)
            url=$(printf '%s' "${url#git@}" | sed 's|\.git$||; s|:|/|')
            url="https://$url"
            ;;
        *.git)
            url="${url%.git}"
            ;;
    esac
    case "$url" in
        *github.com*)
            if [ "$target" != "$FLOW_MAIN_BRANCH" ]; then
                printf '%s\n\n' "$url/compare/$target...$branch?expand=1"
            else
                printf '%s\n\n' "$url/pull/new/$branch"
            fi
            ;;
        *gitlab*)
            printf '%s\n\n' "$url/-/merge_requests/new?merge_request%5Bsource_branch%5D=$branch"
            ;;
        *)
            printf '\n' >&2
            cliWarning "Unknown forge - create the merge request manually: $branch -> $target ($url)"
            ;;
    esac
}
