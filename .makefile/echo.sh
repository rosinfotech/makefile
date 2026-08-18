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

GLOBAL_VERSION=$(get_version "$PHYS_GLOBAL_ROOT")
LOCAL_VERSION=""
if [ -f "$PWD/.version" ] && [ "$PHYS_PWD" != "$PHYS_GLOBAL_ROOT" ]; then
    LOCAL_VERSION=$(get_version "$PHYS_PWD")
fi

echo
echo
echo -e "Hello, ${BLUE}${USER:-$(whoami)}${NC}!"
echo -e "This is rosinfo.tech makefile util ${BLUE}v$GLOBAL_VERSION${NC}"
echo "See https://github.com/rosinfotech/makefile"
if [ -n "$LOCAL_VERSION" ]; then
    echo
    echo "Current project"
    echo -e "$PWD ${BLUE}v$LOCAL_VERSION${NC} (local)"
fi
echo
echo "Available commands:"

GLOBAL_COMMANDS=$(get_commands "$PHYS_GLOBAL_ROOT")
LOCAL_COMMANDS=""
if [ -f "$PWD/Makefile" ] && [ "$PHYS_PWD" != "$PHYS_GLOBAL_ROOT" ]; then
    LOCAL_COMMANDS=$(get_commands "$PHYS_PWD")
fi

for cmd in $GLOBAL_COMMANDS; do
    case " $LOCAL_COMMANDS " in
        *" $cmd "*)
            ;;
        *)
            if [ -x "$PWD/.makefile/$cmd.sh" ] || [ -f "$PWD/.makefile/$cmd.sh" ]; then
                echo -e "  ${GREEN}$cmd${NC} (local, overrides global)"
            else
                echo -e "  ${GREEN}$cmd${NC} (global)"
            fi
            ;;
    esac
done

for cmd in $LOCAL_COMMANDS; do
    case " $GLOBAL_COMMANDS " in
        *" $cmd "*)
            echo -e "  ${GREEN}$cmd${NC} (local, overrides global)"
            ;;
        *)
            echo -e "  ${GREEN}$cmd${NC} (local)"
            ;;
    esac
done

echo
echo
