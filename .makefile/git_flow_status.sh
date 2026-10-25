#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowBranchState() {
    local branch="$1" state=""
    git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && state="local"
    git show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null && \
        state="$state${state:++}remote"
    [ -n "$state" ] || state="missing"
    echo "$state"
}

flowStatus() {

    local variant name marker info branch train tag artifact findings=0
    local line1 line2 floor

    flowRequireGitRepo

    if ! marker=$(flowMarkerPath); then
        cliInfo "Flow not declared"
        cliHint "Run: make git_flow_init <number>."
    printf '\n' >&2
        exit 0
    fi

    info=$(flowMarkerInfo "$marker")
    if [ -z "$info" ]; then
        cliError "Malformed flow file $marker (no 'Flow: Variant #N' line)"
        exit 1
    fi
    variant="${info%%|*}"
    name="${info#*|}"

    cliHeader3 "Flow"
    printf -- '- Variant: #%s - %s;\n' "$variant" "$name"
    printf -- '- Flow file: %s;\n' "$marker"
    printf '\n'

    cliHeader3 "Branches"
    printf -- '- %s: %s;\n' "$FLOW_MAIN_BRANCH" "$(flowBranchState "$FLOW_MAIN_BRANCH")"
    [ "$variant" -ge 3 ] && printf -- '- develop: %s;\n' "$(flowBranchState develop)"
    [ "$variant" -eq 4 ] && printf -- '- staging: %s;\n' "$(flowBranchState staging)"
    if [ "$variant" -eq 5 ]; then
        for train in $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
            printf -- '- %s: %s;\n' "$train" "$(flowBranchState "$train")"
        done
    fi
    printf '\n'

    cliHeader3 "Version"
    tag=$(flowLatestTag "$FLOW_MAIN_BRANCH" 2>/dev/null)
    [ -z "$tag" ] && flowHasRemote && tag=$(flowLatestTag "origin/$FLOW_MAIN_BRANCH" 2>/dev/null)
    printf -- '- Tag (version truth): %s;\n' "${tag:-none}"
    if [ -n "$tag" ] && flowIsSemver "$tag"; then
        floor=$(flowBumpPatch "$tag")
        printf -- '- Default next tag (patch): %s;\n' "$floor"
    fi
    if [ -f .version ]; then
        line1=$(sed -n '1p' .version | tr -d '\n\r')
        line2=$(sed -n '2p' .version | tr -d '\n\r')
        printf -- '- .version line 1 (current): %s, line 2 (future): %s;\n' \
            "${line1:-?}" "${line2:-?}"
    fi
    printf '\n'

    if [ -n "$(flowFragmentList)" ]; then
        cliHeader3 "Fragments"
        for branch in $(flowFragmentList); do
            printf -- '- %s;\n' "$branch"
        done
        cliHint 'Make git_flow_seal with args="--release" tags them (the default defers).'
        printf '\n' >&2
    fi

    if [ "$variant" -ge 3 ] && [ "$(flowBranchState develop)" = "missing" ]; then
        printf -- '- finding: develop is missing (run make git_flow_init %s to create it);\n' "$variant"
        findings=$((findings + 1))
    fi
    if [ "$variant" -eq 4 ] && [ "$(flowBranchState staging)" = "missing" ]; then
        printf -- '- Finding: staging is missing (run make git_flow_init 4 to create it);\n'
        findings=$((findings + 1))
    fi
    if [ "$variant" -eq 5 ] && [ -z "$(flowCurrentTrain)" ]; then
        printf -- '- Finding: no active release/x.y train (run make git_flow_init 5 to create one);\n'
        findings=$((findings + 1))
    fi
    if [ "$variant" -le 2 ] && [ "$(flowBranchState staging)" != "missing" ]; then
        printf -- '- Finding: staging exists but variant #%s does not use it;\n' "$variant"
        findings=$((findings + 1))
    fi
    [ "$findings" -gt 0 ] && printf '\n'

    cliHeader3 "Commands"
    case "$variant" in
        1)
            printf -- '- git_flow_commit_push: enabled (the commit is the seal);\n'
            printf -- '- git_flow_task_*: blocked (variant #1 has no task branches);\n'
            printf -- '- git_flow_hotfix_start: blocked (a production fix is a regular commit);\n'
            printf -- '\n'
            printf -- '- git_flow_seal: redirects to git_flow_commit_push;\n'
            ;;
        2)
            printf -- '- git_flow_task_start: enabled (fork: %s);\n' "$FLOW_MAIN_BRANCH"
            printf -- '- git_flow_task_fragment: enabled;\n'
            printf -- '- git_flow_task_finish: enabled (free merge into %s);\n' "$FLOW_MAIN_BRANCH"
            printf -- '- git_flow_seal: enabled (after the merge);\n'
            printf -- '- git_flow_task_merge_develop: blocked (variant #2 has no develop line);\n'
            printf -- '- git_flow_hotfix_start: blocked (a hotfix is a regular task branch);\n'
            ;;
        3)
            printf -- '- git_flow_task_start: enabled (fork: %s);\n' "$FLOW_MAIN_BRANCH"
            printf -- '- git_flow_task_fragment: enabled;\n'
            printf -- '- git_flow_task_merge_develop: enabled (free merge into develop);\n'
            printf -- '- git_flow_task_finish: enabled (MR into %s);\n' "$FLOW_MAIN_BRANCH"
            printf -- '- git_flow_seal: enabled (after the MR merge);\n'
            printf -- '- git_flow_hotfix_start: blocked (no queue - a fix is a regular task);\n'
            ;;
        4)
            printf -- '- git_flow_task_start: enabled (fork: staging);\n'
            printf -- '- git_flow_task_fragment: enabled;\n'
            printf -- '- git_flow_task_merge_develop: enabled (free merge into develop);\n'
            printf -- '- git_flow_task_finish: enabled (MR into staging);\n'
            printf -- '- git_flow_hotfix_start: enabled (fork: main, bypasses the queue);\n'
            printf -- '- git_flow_seal: enabled (after the promotion / hotfix merge);\n'
            ;;
        5)
            printf -- '- git_flow_task_start: enabled (fork: release/x.y);\n'
            printf -- '- git_flow_task_fragment: enabled;\n'
            printf -- '- git_flow_task_merge_develop: enabled (free merge into develop);\n'
            printf -- '- git_flow_task_finish: enabled (MR into release/x.y);\n'
            printf -- '- git_flow_hotfix_start: enabled (fork: main, bypasses the queue);\n'
            printf -- '- git_flow_seal: enabled (after the release / hotfix merge);\n'
            ;;
        *)
            printf -- '- commands: unknown variant #%s - see the standard;\n' "$variant"
            ;;
    esac
    printf '\n'

    cliHeader3 "Rules"
    sed -n 's/^- //p' "$marker" 2>/dev/null | while read -r branch; do
        printf -- '- '
        cliPath "$branch"
        printf ';\n'
    done
    printf '\n'

}

cliFrameInit
flowStatus "$@"
