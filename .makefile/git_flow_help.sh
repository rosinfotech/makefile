#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowHelp() {

    local variant marker info name branch target
    local staged_steps=()

    if ! marker=$(flowMarkerPath); then
        cliInfo "Flow not declared"
        cliHint "make git_flow_init <number>."
    printf '\n' >&2
        exit 0
    fi

    info=$(flowMarkerInfo "$marker")
    variant="${info%%|*}"
    name="${info#*|}"
    branch=$(flowCurrentBranch 2>/dev/null)

    cliHeader2 "Flow"
    printf -- '- Variant: #%s - %s;\n' "$variant" "$name"
    printf -- '- Flow file: %s;\n' "$marker"
    printf -- '- Current branch: %s;\n' "${branch:-none}"
    printf '\n'

    cliHeader2 "Command sequence"

    case "$variant" in
        1)
            printf -- '1. make git_flow_commit_push "<Type>: <message>";\n'
            ;;
        2)
            printf -- '1. make git_flow_task_start <label>;\n'
            printf -- '2. cd ../<project>-task-<label>;\n'
            printf -- '3. make git_flow_task_fragment "<Type>: <one English line>";\n'
            printf -- '4. make git_flow_commit "<Type>: <message>";\n'
            printf -- '5. make git_flow_task_finish;\n'
            printf -- '6. cd <project directory>;\n'
            printf -- '7. make git_flow_seal;\n'
            ;;
        3)
            printf -- '1. make git_flow_task_start <label>;\n'
            printf -- '2. cd ../<project>-task-<label>;\n'
            printf -- '3. make git_flow_task_fragment "<Type>: <one English line>";\n'
            printf -- '4. make git_flow_commit "<Type>: <message>";\n'
            printf -- '5. make git_flow_task_merge_develop;\n'
            printf -- '6. make git_flow_task_finish;\n'
            printf -- '7. Merge the pull request on the platform (squash);\n'
            printf -- '8. cd <project directory>;\n'
            printf -- '9. make git_flow_seal;\n'
            ;;
        4|5)
            if [ "$variant" = "4" ]; then
                target="staging"
            else
                target="release/x.y"
            fi
            printf -- '1. make git_flow_task_start <label>;\n'
            printf -- '2. cd ../<project>-task-<label>;\n'
            printf -- '3. make git_flow_task_fragment "<Type>: <one English line>";\n'
            printf -- '4. make git_flow_commit "<Type>: <message>";\n'
            printf -- '5. make git_flow_task_merge_develop;\n'
            printf -- '6. make git_flow_task_finish;\n'
            printf -- '7. Merge the pull request into %s on the platform (squash);\n' "$target"
            printf -- '8. cd <project directory>;\n'
            printf -- '9. make git_flow_promote (auto-creates the staging -> main pull request);\n'
            printf -- '10. Merge the promotion pull request on the platform (squash);
11. make git_flow_seal;\n'
            ;;
    esac
    printf '\n'

    cliHeader2 "Hotfix"

    case "$variant" in
        4|5)
            printf -- '1. make git_flow_hotfix_start <label>;\n'
            printf -- '2. cd ../<project>-hotfix-<label>;\n'
            printf -- '3. make git_flow_task_fragment "Fixed: <one English line>";\n'
            printf -- '4. make git_flow_commit "Fixed: <message>";\n'
            printf -- '5. make git_flow_hotfix_finish;\n'
            printf -- '6. Merge the pull request into main on the platform (squash);\n'
            printf -- '7. cd <project directory>;\n'
            printf -- '8. make git_flow_seal (it back-merges main everywhere);\n'
            printf '\n'
            ;;
        *)
            printf -- '- Not applicable: variant #%s has no queue to bypass;\n' "$variant"
            printf '\n'
            ;;
    esac

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

    printf -- '- %s;\n' "$next"
    printf '\n'

    cliHeader2 "Reference"
    printf -- '- make git_flow_status - the declaration, the topology, the findings;\n'
    printf -- '- make git_flow_clear - offers to remove stale branches (default: no);\n'
    printf -- '- https://github.com/rosinfotech/standards#the-git-flow-standard;\n'
    printf '\n'

    cliHeader2 "GitHub integration (optional)"
    printf -- '1. Create a fine-grained PAT: https://github.com/settings/personal-access-tokens/new;\n'
    printf -- '2. Repository access: Only select repositories -> choose this repo;\n'
    printf -- '3. Permissions: Contents Read and write, Pull requests Read and write;\n'
    printf -- '4. Store in ~/.secrets.json under com.github.repo.<repo-name>.PAT;\n'
    printf '\n'
    printf -- '- Contents: the seal offers GitHub release notes;\n'
    printf -- '- Pull requests: finish creates the MR automatically with the correct title;\n'
    printf -- '- Without a PAT: everything works, MR links are printed for manual creation;\n'
    printf '\n'

}

cliFrameInit
flowHelp "$@"
