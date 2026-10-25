#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

flowTaskFragment() {

    local argument="$1" variant type line branch utlbl fragment

    variant=$(flowRequireFlow) || exit 1
    flowRequireVariant "$variant" "2 3 4 5" \
        "variant #1 writes the CHANGELOG section in the commit itself"

    if [ -z "$argument" ]; then
        cliError "The fragment argument is required"
        cliHint "make git_flow_task_fragment \"<Type>: <one English line>\"."
        cliHint "Types: added, changed, fixed, deprecated, removed, security."
        printf '\n' >&2
        exit 2
    fi

    type=$(echo "${argument%%:*}" | tr '[:upper:]' '[:lower:]' | sed 's/^ *//; s/ *$//')
    line=$(echo "${argument#*:}" | sed 's/^ *//; s/ *$//')

    if ! echo "$FLOW_TYPE_ORDER" | grep -qw "$type"; then
        cliError "Unknown type '${type}' - expected one of: $(echo $FLOW_TYPE_ORDER | sed 's/ /, /g')"
        exit 2
    fi

    if [ -z "$line" ]; then
        cliError "The fragment line is empty"
        exit 2
    fi

    branch=$(flowCurrentBranch)
    case "$branch" in
        task-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*|\
hotfix-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-*)
            ;;
        *)
            cliError "Not on a task/hotfix branch (current: ${branch:-none})"
            exit 1
            ;;
    esac

    utlbl=$(flowTaskLabelFromBranch "$branch")
    if [ -z "$utlbl" ]; then
        cliError "Cannot derive the task label from the branch name $branch"
        exit 1
    fi

    fragment="$FLOW_FRAGMENTS_DIR/$utlbl.$type.md"

    if [ -e "$fragment" ] && grep -Fxq "$line" "$fragment"; then
        cliInfo "The line is already in $fragment - nothing to add"
        exit 0
    fi

    if [ -e "$fragment" ] && [ -s "$fragment" ]; then
        echo "$line" >> "$fragment"
        cliInfo "Fragment line appended: $fragment"
    else
        mkdir -p "$FLOW_FRAGMENTS_DIR"
        echo "$line" > "$fragment"
        cliSuccess "Fragment created: $fragment"
    fi

    cliHint "Commit it with the task: make git_flow_commit \"${argument%%:*}: work in progress\"."
    printf '\n' >&2

}

cliFrameInit
cliParseArgs "$@"
flowTaskFragment "${CLI_ARG_POSITIONAL:-}"
