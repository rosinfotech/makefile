#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowHelp() {

    local variant marker info name branch target
    local staged_steps=()

    if ! marker=$(flowMarkerPath); then
        cliInfo "Flow not declared"
        cliHint "make git_flow_init <number>."
        exit 0
    fi

    info=$(flowMarkerInfo "$marker")
    variant="${info%%|*}"
    name="${info#*|}"
    branch=$(flowCurrentBranch 2>/dev/null)

    cliHeader2 "Flow"
    cliItem "Variant: #$variant - $name"
    cliItem "Flow file: $marker"
    cliItem "Current branch: ${branch:-none}"
    printf '\n' >&3

    cliHeader2 "Command sequence"

    case "$variant" in
        1)
            cliItemNum 1 'make git_flow_commit_push "<Type>: <message>"'
            ;;
        2)
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_finish"
            cliItemNum 6 "cd <project directory>"
            cliItemNum 7 "make git_flow_seal"
            ;;
        3)
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Merge the pull request on the platform (squash)"
            cliItemNum 8 "cd <project directory>"
            cliItemNum 9 "make git_flow_seal"
            ;;
        4|5)
            if [ "$variant" = "4" ]; then
                target="staging"
            else
                target="release/x.y"
            fi
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Merge the pull request into $target on the platform (squash)"
            cliItemNum 8 "cd <project directory>"
            cliItemNum 9 "make git_flow_promote (auto-creates the staging -> main pull request)"
            cliItemNum 10 "Merge the promotion pull request on the platform (squash)"
            cliItemNum 11 "make git_flow_seal"
            ;;
    esac
    printf '\n' >&3

    cliHeader2 "Hotfix"

    case "$variant" in
        4|5)
            cliItemNum 1 "make git_flow_hotfix_start <label>"
            cliItemNum 2 "cd ../<project>-hotfix-<label>"
            cliItemNum 3 'make git_flow_task_fragment "Fixed: <one English line>"'
            cliItemNum 4 'make git_flow_commit "Fixed: <message>"'
            cliItemNum 5 "make git_flow_hotfix_finish"
            cliItemNum 6 "Merge the pull request into main on the platform (squash)"
            cliItemNum 7 "cd <project directory>"
            cliItemNum 8 "make git_flow_seal (it back-merges main everywhere)"
            ;;
        *)
            cliItem "Not applicable: variant #$variant has no queue to bypass"
            ;;
    esac
    printf '\n' >&3

    cliHeader2 "Next step"

    local next="(Unknown - see the sequence above)"

    case "$branch" in
        task-[0-9]*)
            if [ -n "$(git status --porcelain)" ]; then
                next='Commit your changes: make git_flow_commit "<Type>: <message>"'
            elif [ -z "$(flowFragmentList)" ]; then
                next='Add a changelog fragment: make git_flow_task_fragment "<Type>: <one English line>"'
            elif flowBranchPatchesIn "$branch" develop 2>/dev/null || flowBranchPatchesIn "$branch" staging 2>/dev/null; then
                if [ "$variant" = "2" ]; then
                    next='Finish the task: make git_flow_task_finish'
                else
                    next='Finish the task: make git_flow_task_finish (then merge the pull request)'
                fi
            else
                if [ "$variant" -ge 3 ]; then
                    next='Integrate into develop: make git_flow_task_merge_develop'
                else
                    next='Finish the task: make git_flow_task_finish'
                fi
            fi
            ;;
        hotfix-[0-9]*)
            if [ -n "$(git status --porcelain)" ]; then
                next='Commit your fix: make git_flow_commit "Fixed: <message>"'
            elif [ -z "$(flowFragmentList)" ]; then
                next='Add a changelog fragment: make git_flow_task_fragment "Fixed: <one English line>"'
            elif git merge-base --is-ancestor "$branch" "refs/remotes/origin/$FLOW_MAIN_BRANCH" 2>/dev/null; then
                next='The hotfix is already in main: make git_flow_seal (on main)'
            else
                next='Finish the hotfix: make git_flow_hotfix_finish'
            fi
            ;;
        "$FLOW_MAIN_BRANCH")
            if [ -n "$(flowFragmentList)" ]; then
                next="Seal the entry: make git_flow_seal (on $FLOW_MAIN_BRANCH)"
            elif [ "$variant" = "4" ] && [ "$(git branch --list staging | wc -l | tr -d ' ')" -gt 0 ]; then
                local staging_frag
                staging_frag=$(git ls-tree --name-only staging "$FLOW_FRAGMENTS_DIR" 2>/dev/null | head -1)
                if [ -n "$staging_frag" ]; then
                    next='Promote the queue: make git_flow_promote (the fragments ride the gate to main)'
                fi
            fi
            ;;
        staging)
            if [ -n "$(flowFragmentList)" ]; then
                next='Promote the queue: make git_flow_promote (the fragments ride the gate to main)'
            else
                next='The staging queue is assembled: Merge the promotion pull request into main'
            fi
            ;;
        release/*)
            if [ -n "$(flowFragmentList)" ]; then
                next='Promote the train: make git_flow_promote (the fragments ride the train to main)'
            else
                next='The train is assembled: merge the release pull request into main'
            fi
            ;;
    esac

    if [ "$next" = "(Unknown - see the sequence above)" ] && [ -n "$(flowFragmentList)" ]; then
        next="Seal the entry: make git_flow_seal"
    fi

    cliItem "$next"
    printf '\n' >&3

    cliHeader2 "Reference"
    cliItem "make git_flow_status - the declaration, the topology, the findings"
    cliItem "make git_flow_clear - offers to remove stale branches (default: no)"
    cliItem "https://github.com/rosinfotech/standards#the-git-flow-standard"
    printf '\n' >&3

    cliHeader2 "GitHub integration (optional)"
    cliItemNum 1 "Create a fine-grained PAT: https://github.com/settings/personal-access-tokens/new"
    cliItemNum 2 "Repository access: Only select repositories -> choose this repo"
    cliItemNum 3 "Permissions: Contents Read and write, Pull requests Read and write"
    cliItemNum 4 "Store in ~/.secrets.json under com.github.repo.<repo-name>.PAT"
    printf '\n' >&3
    cliItem "Contents: the seal offers GitHub release notes"
    cliItem "Pull requests: finish creates the MR automatically with the correct title"
    cliItem "Without a PAT: everything works, MR links are printed for manual creation"
    printf '\n' >&3

}

cliFrameInit
flowHelp "$@"
