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
        exit 0
    fi

    info=$(flowMarkerInfo "$marker")
    if [ -z "$info" ]; then
        cliError "Malformed flow file $marker (no 'Flow: Variant #N' line)"
        exit 1
    fi
    variant="${info%%|*}"
    name="${info#*|}"

    cliHeader2 "Flow"
    cliItem "Variant: #$variant - $name"
    cliItem "Flow file: $marker"
    printf '\n' >&3

    cliHeader2 "Branches"
    cliItem "$FLOW_MAIN_BRANCH: $(flowBranchState "$FLOW_MAIN_BRANCH")"
    [ "$variant" -ge 3 ] && cliItem "develop: $(flowBranchState develop)"
    [ "$variant" -eq 4 ] && cliItem "staging: $(flowBranchState staging)"
    if [ "$variant" -eq 5 ]; then
        for train in $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
            cliItem "$train: $(flowBranchState "$train")"
        done
    fi
    printf '\n' >&3

    cliHeader2 "Version"
    tag=$(flowLatestTag "$FLOW_MAIN_BRANCH" 2>/dev/null)
    [ -z "$tag" ] && flowHasRemote && tag=$(flowLatestTag "origin/$FLOW_MAIN_BRANCH" 2>/dev/null)
    cliItem "Tag (version truth): ${tag:-none}"
    if [ -n "$tag" ] && flowIsSemver "$tag"; then
        floor=$(flowBumpPatch "$tag")
        cliItem "Default next tag (patch): $floor"
    fi
    if [ -f .version ]; then
        line1=$(sed -n '1p' .version | tr -d '\n\r')
        line2=$(sed -n '2p' .version | tr -d '\n\r')
        cliItem ".version line 1 (current): ${line1:-?}, line 2 (future): ${line2:-?}"
    fi
    printf '\n' >&3

    if [ -n "$(flowFragmentList)" ]; then
        cliHeader2 "Fragments"
        for branch in $(flowFragmentList); do
            cliItem "$branch"
        done
        printf '\n' >&3
        cliHint 'Make git_flow_seal with args="--release" tags them (the default defers).'
    fi

    if [ "$variant" -ge 3 ] && [ "$(flowBranchState develop)" = "missing" ]; then
        cliItem "Finding: develop is missing (run make git_flow_init $variant to create it)"
        findings=$((findings + 1))
    fi
    if [ "$variant" -eq 4 ] && [ "$(flowBranchState staging)" = "missing" ]; then
        cliItem "Finding: staging is missing (run make git_flow_init 4 to create it)"
        findings=$((findings + 1))
    fi
    if [ "$variant" -eq 5 ] && [ -z "$(flowCurrentTrain)" ]; then
        cliItem "Finding: no active release/x.y train (run make git_flow_init 5 to create one)"
        findings=$((findings + 1))
    fi
    if [ "$variant" -le 2 ] && [ "$(flowBranchState staging)" != "missing" ]; then
        cliItem "Finding: staging exists but variant #$variant does not use it"
        findings=$((findings + 1))
    fi
    [ "$findings" -gt 0 ] && printf '\n' >&3

    cliHeader2 "Commands"
    case "$variant" in
        1)
            cliItem "git_flow_commit_push: enabled (the commit is the seal)"
            cliItem "git_flow_task_*: blocked (variant #1 has no task branches)"
            cliItem "git_flow_hotfix_start: blocked (a production fix is a regular commit)"
            cliItem "git_flow_seal: redirects to git_flow_commit_push"
            ;;
        2)
            cliItem "git_flow_task_start: enabled (fork: $FLOW_MAIN_BRANCH)"
            cliItem "git_flow_task_fragment: enabled"
            cliItem "git_flow_task_finish: enabled (free merge into $FLOW_MAIN_BRANCH)"
            cliItem "git_flow_seal: enabled (after the merge)"
            cliItem "git_flow_task_merge_develop: blocked (variant #2 has no develop line)"
            cliItem "git_flow_hotfix_start: blocked (a hotfix is a regular task branch)"
            ;;
        3)
            cliItem "git_flow_task_start: enabled (fork: $FLOW_MAIN_BRANCH)"
            cliItem "git_flow_task_fragment: enabled"
            cliItem "git_flow_task_merge_develop: enabled (free merge into develop)"
            cliItem "git_flow_task_finish: enabled (MR into $FLOW_MAIN_BRANCH)"
            cliItem "git_flow_seal: enabled (after the MR merge)"
            cliItem "git_flow_hotfix_start: blocked (no queue - a fix is a regular task)"
            ;;
        4)
            cliItem "git_flow_task_start: enabled (fork: staging)"
            cliItem "git_flow_task_fragment: enabled"
            cliItem "git_flow_task_merge_develop: enabled (free merge into develop)"
            cliItem "git_flow_task_finish: enabled (MR into staging)"
            cliItem "git_flow_hotfix_start: enabled (fork: main, bypasses the queue)"
            cliItem "git_flow_seal: enabled (after the promotion / hotfix merge)"
            ;;
        5)
            cliItem "git_flow_task_start: enabled (fork: release/x.y)"
            cliItem "git_flow_task_fragment: enabled"
            cliItem "git_flow_task_merge_develop: enabled (free merge into develop)"
            cliItem "git_flow_task_finish: enabled (MR into release/x.y)"
            cliItem "git_flow_hotfix_start: enabled (fork: main, bypasses the queue)"
            cliItem "git_flow_seal: enabled (after the release / hotfix merge)"
            ;;
        *)
            cliItem "commands: unknown variant #$variant - see the standard"
            ;;
    esac
    printf '\n' >&3

    cliHeader2 "Rules"
    sed -n 's/^- //p' "$marker" 2>/dev/null | while read -r branch; do
        if [ "$CLI_COLOR_OUT" = "1" ]; then
            printf '%s- %s' "$CLI_TEXT" "$CLI_RESET" >&3
            cliPath "$branch" >&3
            printf '%s;%s\n' "$CLI_TEXT" "$CLI_RESET" >&3
        else
            printf -- '- ' >&3
            printf '%s' "$branch" >&3
            printf ';\n' >&3
        fi
    done
    printf '\n' >&3

}

cliFrameInit
flowStatus "$@"
