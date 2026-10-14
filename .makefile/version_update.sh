#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

VERSION_FILE="./.version"

cliFrameInit

if [ ! -f "$VERSION_FILE" ]; then
    cliError "$VERSION_FILE not found"
    exit 1
fi

current_version=$(sed -n '1p' "$VERSION_FILE" | tr -d '\n\r')
new_version=$(sed -n '2p' "$VERSION_FILE" | tr -d '\n\r')

if [ -z "$current_version" ] || [ -z "$new_version" ]; then
    cliError "Invalid .version file format"
    exit 1
fi

if [ "$current_version" = "$new_version" ]; then
    cliInfo "Version already up to date: $current_version"
    exit 0
fi

flowSubstituteVersion "$current_version" "$new_version"

sed -i '' "1s/.*/$new_version/" "$VERSION_FILE"
cliSuccess "Version updated: $current_version -> $new_version"
