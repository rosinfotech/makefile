#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowHelpVariantName() { # number -> the ladder name of the variant
    case "$1" in
        1) echo "Direct to Main Flow (Trunk-Based Development)" ;;
        2) echo "Free Merge to Main Flow (GitHub Flow)" ;;
        3) echo "Reviewed Merge to Main Flow (Git Flow Lite)" ;;
        4) echo "Reviewed Merge to Staging to Main Flow (GitLab Flow Lite)" ;;
        5) echo "Reviewed Merge to Release to Main Flow (Git Flow)" ;;
    esac
}

flowHelpSequence() { # variant -> the numbered delivery steps
    local n="$1" target
    case "$n" in
        1)
            cliItemNum 1 'make git_flow_commit_push "<Type>: <message>"'
            ;;
        2)
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_finish"
            cliItemNum 6 "Code review may request changes - see the Code review iterations section"
            cliItemNum 7 "cd <project directory>"
            cliItemNum 8 "make git_flow_seal"
            ;;
        3)
            cliItemNum 1 "make git_flow_task_start <label>"
            cliItemNum 2 "cd ../<project>-task-<label>"
            cliItemNum 3 'make git_flow_task_fragment "<Type>: <one English line>"'
            cliItemNum 4 'make git_flow_commit "<Type>: <message>"'
            cliItemNum 5 "make git_flow_task_merge_develop"
            cliItemNum 6 "make git_flow_task_finish"
            cliItemNum 7 "Code review may request changes - see the Code review iterations section"
            cliItemNum 8 "Merge the pull request on the platform (squash)"
            cliItemNum 9 "cd <project directory>"
            cliItemNum 10 "make git_flow_seal"
            ;;
        4|5)
            if [ "$n" = "4" ]; then
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
            cliItemNum 7 "Code review may request changes - see the Code review iterations section"
            cliItemNum 8 "Merge the pull request into $target on the platform (squash)"
            cliItemNum 9 "cd <project directory>"
            cliItemNum 10 "make git_flow_promote (auto-creates the $target -> main pull request)"
            cliItemNum 11 "Merge the promotion pull request on the platform (squash)"
            cliItemNum 12 "make git_flow_seal"
            ;;
    esac
}

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

    cliHeader1 "Git flow help: Variant #$variant - $name"

    cliHeader2 "Flow"
    cliItem "Variant: #$variant - $name"
    cliItem "Flow file: $marker"
    cliItem "Current branch: ${branch:-none}"
    printf '\n' >&3

    cliHeader2 "Command sequence"
    flowHelpSequence "$variant"
    printf '\n' >&3

    cliHeader2 "Hotfix"

    case "$variant" in
        4|5)
            cliItemNum 1 "make git_flow_hotfix_start <label>"
            cliItemNum 2 "cd ../<project>-hotfix-<label>"
            cliItemNum 3 'make git_flow_task_fragment "Fixed: <one English line>"'
            cliItemNum 4 'make git_flow_commit "Fixed: <message>"'
            cliItemNum 5 "make git_flow_hotfix_finish"
            cliItemNum 6 "Code review may request changes - iterate in ../<project>-hotfix-<label> the same way"
            cliItemNum 7 "Merge the pull request into main on the platform (squash)"
            cliItemNum 8 "cd <project directory>"
            cliItemNum 9 "make git_flow_seal (it back-merges main everywhere)"
            ;;
        *)
            cliItem "Not applicable: variant #$variant has no queue to bypass"
            ;;
    esac
    printf '\n' >&3

    cliHeader2 "Code review iterations"

    case "$variant" in
        1)
            cliItem "Not applicable: variant #1 has no merge requests - the fixes ride the next direct commit"
            ;;
        2)
            cliItemNum 1 "cd ../<project>-task-<label> (the worktree stays until the seal)"
            cliItemNum 2 'make git_flow_task_fragment "<Type>: <one English line>" (when the fix is user-visible)'
            cliItemNum 3 'make git_flow_commit "<Type>: <message>" (the branch is never published - no push to an open request)'
            cliItemNum 4 "make git_flow_task_finish (re-run - the squash into main carries the updates)"
            ;;
        3)
            cliItemNum 1 "cd ../<project>-task-<label> (the worktree stays until the seal)"
            cliItemNum 2 'make git_flow_task_fragment "<Type>: <one English line>" (when the fix is user-visible)'
            cliItemNum 3 'make git_flow_commit_push "<Type>: <message>" - one shot, or commit + make git_flow_push'
            cliItemNum 4 "make git_flow_task_merge_develop (keep develop current)"
            cliItemNum 5 "Merge the request on the platform (squash) after the re-review"
            ;;
        4|5)
            cliItemNum 1 "cd ../<project>-task-<label> (the worktree stays until the seal)"
            cliItemNum 2 'make git_flow_task_fragment "<Type>: <one English line>" (when the fix is user-visible)'
            cliItemNum 3 'make git_flow_commit_push "<Type>: <message>" - one shot, or commit + make git_flow_push'
            cliItemNum 4 "make git_flow_task_merge_develop (keep develop current)"
            cliItemNum 5 "Merge the request into the gate on the platform (squash) after the re-review"
            cliItem "Hotfix requests iterate the same way: cd ../<project>-hotfix-<label> and the same commands"
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

    cliHeader2 "Other variants"
    local other_n other_name
    for other_n in 1 2 3 4 5; do
        [ "$other_n" = "$variant" ] && continue
        other_name=$(flowHelpVariantName "$other_n")
        cliHeader1 "Variant #$other_n - $other_name"
        flowHelpSequence "$other_n"
        printf '\n' >&3
    done

    cliHeader1 "Reference"
    cliItem "make git_flow_status - the declaration, the topology, the findings"
    cliItem "make git_flow_clear - offers to remove stale branches (default: no)"
    cliItem "make git_flow_push - pushes task/hotfix updates into the open merge request"
    cliItem "The Git Flow Standard: https://github.com/rosinfotech/standards/tree/master/standards/git-flow-standard"
    printf '\n' >&3

    cliHeader1 "GitHub integration (optional)"
    cliItemNum 1 "Create a fine-grained PAT: https://github.com/settings/personal-access-tokens/new"
    cliItemNum 2 "Repository access: Only select repositories -> choose this repo"
    cliItemNum 3 "Permissions: Contents Read and write, Pull requests Read and write"
    cliItemNum 4 "Store in ~/.secrets.json under com.github.repo.<repo-name>.PAT"
    printf '\n' >&3
    cliHeader2 "What the integration provides"
    cliItem "Contents (Read and write): the seal offers GitHub release notes after the stamp"
    cliItem "Pull requests (Read and write): task finish and hotfix finish create the request automatically with the correct title"
    cliItem "Without a PAT: everything works - the commands print the request links for manual creation"
    printf '\n' >&3

}

cliFrameInit
flowHelp "$@"
