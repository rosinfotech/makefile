#!/bin/bash

VERSION_FILE="./.version"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

current_version=$(sed -n '1p' "$VERSION_FILE")
new_version=$(sed -n '2p' "$VERSION_FILE")

if [ -z "$current_version" ] || [ -z "$new_version" ]; then
    echo "Error: Invalid .version file format"
    exit 1
fi

if [ "$current_version" = "$new_version" ]; then
    echo "Version already up to date: $current_version"
    exit 0
fi

escaped_current=$(echo "$current_version" | sed 's/\./\\./g')

sed -n '3,$p' "$VERSION_FILE" | while read -r file; do
    if [ -f "$file" ]; then
        sed -i '' "s/\"$escaped_current\"/\"$new_version\"/g" "$file"
        echo "Updated: $file"
    else
        echo "Warning: File not found - $file"
    fi
done

sed -i '' "1s/.*/$new_version/" "$VERSION_FILE"
echo "Version updated: $current_version → $new_version"
