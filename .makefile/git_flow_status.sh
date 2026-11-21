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

    cliHeader1 "Flow"
    cliItem "Variant: #$variant - $name"
    cliItem "Flow file: $marker"
    printf '\n' >&3

    cliHeader1 "Branches"
    cliItem "$FLOW_MAIN_BRANCH: $(flowBranchState "$FLOW_MAIN_BRANCH")"
    [ "$variant" -ge 3 ] && cliItem "develop: $(flowBranchState develop)"
    [ "$variant" -eq 4 ] && cliItem "staging: $(flowBranchState staging)"
    if [ "$variant" -eq 5 ]; then
        for train in $(git for-each-ref --format='%(refname:short)' 'refs/heads/release/*'); do
            cliItem "$train: $(flowBranchState "$train")"
        done
    fi
    printf '\n' >&3

    cliHeader1 "Version"
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
        cliHeader1 "Fragments"
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

    cliHeader1 "Initialization case"
    cliItemNum 1 "make git_flow_init <1..5> (declare the variant or migrate - the marker refreshes from the standard, the gate skeleton follows)"
    printf '\n' >&3

    case "$variant" in
        1)
            cliHeader1 "Delivery case"
            cliItemNum 1 'make git_flow_commit_push "<Type>: <message>" (the commit is the seal)'
            printf '\n' >&3
            cliHeader1 "Review case"
            cliItem "Not applicable: the fixes ride the next direct commit (variant #1 has no merge requests)"
            printf '\n' >&3
            ;;
        2)
            cliHeader1 "Delivery case"
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_finish"
            cliItemNum 6 "Code review may request changes - see the Review case below"
            cliItemNum 7 "cd <project directory>"
            cliItemNum 8 "make git_flow_seal"
            printf '\n' >&3
            cliHeader1 "Review case"
            cliItemNum 1 "cd ../<project>-task-<label>"
            cliItemNum 2 'make git_flow_task_fragment "<Type>: <one English line>" (when the fix is user-visible)'
            cliItemNum 3 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 4 "make git_flow_task_finish (re-run - the branch is not published, the squash carries the updates)"
            cliItemNum 5 "cd <project directory>"
            cliItemNum 6 "make git_flow_seal"
            printf '\n' >&3
            ;;
        3)
            cliHeader1 "Delivery case"
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Code review may request changes - see the Review case below"
            cliItemNum 8 "Merge the request on the platform (squash)"
            cliItemNum 9 "cd <project directory>"
            cliItemNum 10 "make git_flow_seal"
            printf '\n' >&3
            cliHeader1 "Review case"
            cliItemNum 1 "cd ../<project>-task-<label>"
            cliItemNum 2 'make git_flow_commit_push "<Type>: <message>"'
            cliItemNum 3 "make git_flow_task_merge_develop"
            cliItemNum 4 "Merge the request on the platform (squash)"
            printf '\n' >&3
            ;;
        4)
            cliHeader1 "Delivery case"
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Code review may request changes - see the Review case below"
            cliItemNum 8 "Merge the request into staging on the platform (squash)"
            cliItemNum 9 "cd <project directory>"
            cliItemNum 10 "make git_flow_promote"
            cliItemNum 11 "Merge the promotion request on the platform (squash)"
            cliItemNum 12 "make git_flow_seal"
            printf '\n' >&3
            cliHeader1 "Review case"
            cliItemNum 1 "cd ../<project>-task-<label>"
            cliItemNum 2 'make git_flow_commit_push "<Type>: <message>"'
            cliItemNum 3 "make git_flow_task_merge_develop"
            cliItemNum 4 "Merge the request into staging on the platform (squash) after the re-review"
            printf '\n' >&3
            cliHeader1 "Hotfix case"
            cliItemNum 1 "make git_flow_hotfix_start <label>"
            cliItemNum 2 "cd ../<project>-hotfix-<label>"
            cliItemNum 3 'make git_flow_task_fragment "Fixed: <one English line>"'
            cliItemNum 4 'make git_flow_commit "Fixed: <message>"'
            cliItemNum 5 "make git_flow_hotfix_finish"
            cliItemNum 6 "Code review may request changes - iterate in ../<project>-hotfix-<label> as the Review case describes"
            cliItemNum 7 "Merge the request into main on the platform (squash)"
            cliItemNum 8 "cd <project directory>"
            cliItemNum 9 "make git_flow_seal"
            printf '\n' >&3
            ;;
        5)
            cliHeader1 "Delivery case"
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Code review may request changes - see the Review case below"
            cliItemNum 8 "Merge the request into release/x.y on the platform (squash)"
            cliItemNum 9 "cd <project directory>"
            cliItemNum 10 "make git_flow_promote"
            cliItemNum 11 "Merge the promotion request on the platform (squash)"
            cliItemNum 12 "make git_flow_seal (stamps x.y.0)"
            printf '\n' >&3
            cliHeader1 "Review case"
            cliItemNum 1 "cd ../<project>-task-<label>"
            cliItemNum 2 'make git_flow_commit_push "<Type>: <message>"'
            cliItemNum 3 "make git_flow_task_merge_develop"
            cliItemNum 4 "Merge the request into release/x.y on the platform (squash) after the re-review"
            printf '\n' >&3
            cliHeader1 "Hotfix case"
            cliItemNum 1 "make git_flow_hotfix_start <label>"
            cliItemNum 2 "cd ../<project>-hotfix-<label>"
            cliItemNum 3 'make git_flow_task_fragment "Fixed: <one English line>"'
            cliItemNum 4 'make git_flow_commit "Fixed: <message>"'
            cliItemNum 5 "make git_flow_hotfix_finish"
            cliItemNum 6 "Code review may request changes - iterate in ../<project>-hotfix-<label> as the Review case describes"
            cliItemNum 7 "Merge the request into main on the platform (squash)"
            cliItemNum 8 "cd <project directory>"
            cliItemNum 9 "make git_flow_seal (stamps the patch)"
            printf '\n' >&3
            ;;
    esac

    cliHeader1 "Rules"
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
