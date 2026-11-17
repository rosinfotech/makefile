#!/bin/bash

set -e

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
GLOBAL_ROOT="${GLOBAL_ROOT:-$(dirname "$(dirname "$SELF")")}"

PHYS_GLOBAL_ROOT="$(cd "$GLOBAL_ROOT" && pwd -P)"
PHYS_PWD="$(cd "$PWD" && pwd -P)"

source "$(cd "$(dirname "$SELF")" && pwd)/lib_cli.sh"

get_version() {
    if [ -f "$1/.version" ]; then
        head -n 1 "$1/.version"
    fi
}

get_commands() {
    sed -n '/:=/!s/^\([a-zA-Z0-9_][a-zA-Z0-9_-]*\):.*/\1/p' "$1/Makefile" 2>/dev/null | sort -u | grep -v '^init$' | tr '\n' ' ' || true
}

# cmd<TAB>script for every target whose recipe runs a script (via
# resolve_script or a direct .makefile/ path); the first script wins
get_script_commands() {
    awk '
        /^[\t]/ {
            if (cmd != "" && script == "") {
                if (match($0, /resolve_script,[^) \t]*\.sh/)) {
                    script = substr($0, RSTART + 15, RLENGTH - 15)
                } else if (match($0, /[^ \t]*\.makefile\/[^ \t]*\.sh/)) {
                    script = substr($0, RSTART, RLENGTH)
                }
            }
            next
        }
        {
            if (cmd != "" && script != "") {
                print cmd "\t" script
            }
            cmd = ""
            script = ""
            if ($0 ~ /^[a-zA-Z0-9_][a-zA-Z0-9_-]*:/ && $0 !~ /:=/) {
                cmd = $1
                sub(/:.*/, "", cmd)
                if (cmd == "init") {
                    cmd = ""
                }
            }
        }
        END {
            if (cmd != "" && script != "") {
                print cmd "\t" script
            }
        }
    ' "$1/Makefile"
}

# A command is vendored when its script lives in .makefile/vendor/rosinfotech
# (and not in the project .makefile/ - project scripts always win)
is_vendored() {
    script="$(printf '%s\n' "$SCRIPT_MAP" | awk -F '\t' -v c="$1" '$1 == c { print $2; exit }')"
    [ -z "$script" ] && return 1
    case "$script" in
        */vendor/*)
            return 0
            ;;
    esac
    [ ! -f "$PHYS_PWD/.makefile/$script" ] && [ -f "$PHYS_PWD/.makefile/vendor/rosinfotech/$script" ]
}

FRAMEWORK_VERSION="$(get_version "$PHYS_GLOBAL_ROOT")"
LOCAL_VERSION="$(get_version "$PHYS_PWD")"

cliFrameInit
cliHeader1 "Hello, ${USER:-$(whoami)}!"
util_line="util: rosinfo.tech makefile"
if [ -n "$FRAMEWORK_VERSION" ]; then
    util_line="$util_line v$FRAMEWORK_VERSION"
fi
cliItem "$util_line"
if [ "$PHYS_PWD" != "$PHYS_GLOBAL_ROOT" ] && [ -n "$LOCAL_VERSION" ]; then
    project_path="${PHYS_PWD/#$HOME/\~}"
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s- project: %s' "$CLI_TEXT" "$CLI_RESET" >&3
        cliPath "$project_path" >&3
        printf '%s (v%s);%s\n' "$CLI_TEXT" "$LOCAL_VERSION" "$CLI_RESET" >&3
    else
        printf -- '- project: ' >&3
        printf '%s' "$project_path" >&3
        printf ' (v%s);\n' "$LOCAL_VERSION" >&3
    fi
fi
if [ "$CLI_COLOR_OUT" = "1" ]; then
    printf '%s- source: %s' "$CLI_TEXT" "$CLI_RESET" >&3
    cliPath "https://github.com/rosinfotech/makefile" >&3
    printf '%s;%s\n' "$CLI_TEXT" "$CLI_RESET" >&3
else
    printf -- '- source: ' >&3
    printf '%s' "https://github.com/rosinfotech/makefile" >&3
    printf ';\n' >&3
fi
printf '\n' >&3

cliHeader2 "Available commands"

SCRIPT_MAP="$(get_script_commands "$PHYS_PWD")"

for cmd in $(get_commands "$PHYS_PWD"); do
    line="$cmd"
    if is_vendored "$cmd"; then
        if [ "$CLI_COLOR_OUT" = "1" ]; then
            line="$cmd${CLI_INFO} (vendored)${CLI_RESET}${CLI_TEXT}"
        else
            line="$cmd (vendored)"
        fi
    fi
    cliItem "$line"
done
printf '\n' >&3
