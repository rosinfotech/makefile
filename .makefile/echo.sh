#!/bin/bash

set -e

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
GLOBAL_ROOT="${GLOBAL_ROOT:-$(dirname "$(dirname "$SELF")")}"

PHYS_GLOBAL_ROOT="$(cd "$GLOBAL_ROOT" && pwd -P)"
PHYS_PWD="$(cd "$PWD" && pwd -P)"

if [ -t 1 ]; then
    BLUE="\033[0;34m"
    GREEN="\033[0;32m"
    NC="\033[0m"
else
    BLUE=""
    GREEN=""
    NC=""
fi

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

echo
echo
echo -e "Hello, ${BLUE}${USER:-$(whoami)}${NC}!"
echo -e "This is rosinfo.tech makefile util ${BLUE}v$FRAMEWORK_VERSION${NC}"
echo "See https://github.com/rosinfotech/makefile"
LOCAL_VERSION="$(get_version "$PHYS_PWD")"
if [ "$PHYS_PWD" != "$PHYS_GLOBAL_ROOT" ] && [ -n "$LOCAL_VERSION" ]; then
    echo
    echo "Current project"
    echo -e "$PHYS_PWD ${BLUE}v$LOCAL_VERSION${NC}"
fi
echo
echo "Available commands:"

SCRIPT_MAP="$(get_script_commands "$PHYS_PWD")"

for cmd in $(get_commands "$PHYS_PWD"); do
    if is_vendored "$cmd"; then
        echo -e "  ${GREEN}${cmd}${NC} (vendored)"
    else
        echo -e "  ${GREEN}${cmd}${NC}"
    fi
done

echo
echo
