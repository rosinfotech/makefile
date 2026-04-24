#!/bin/bash

set -e

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
PROJECT_ROOT="$(dirname "$(dirname "$SELF")")"

FILES=(.editorconfig Makefile)

for file in "${FILES[@]}"; do
    if [ -e "$PWD/$file" ]; then
        echo "Skipped (exists): $file"
    else
        cp "$PROJECT_ROOT/$file" "$PWD/$file"
        echo "Copied: $file"
    fi
done

if [ -f "$PWD/.version" ]; then
    echo "Skipped (exists): .version"
else
    printf '0.0.1\n0.0.1\n' > "$PWD/.version"
    echo "Created: .version"
fi

if [ -f "$PWD/CHANGELOG.md" ]; then
    echo "Skipped (exists): CHANGELOG.md"
else
    cat > "$PWD/CHANGELOG.md" << 'EOF'
<!-- markdownlint-disable MD041 -->

[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Changelog

<!-- markdownlint-disable MD024 -->

## [0.0.1] - YYYY-MM-DD

### Initialization

- Welcome!
EOF
    echo "Created: CHANGELOG.md"
fi

if [ -f "$PWD/README.md" ]; then
    echo "Skipped (exists): README.md"
else
    cat > "$PWD/README.md" << 'EOF'
<!-- markdownlint-disable MD041 -->

[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Welcome

EOF
    echo "Created: README.md"
fi

if [ -d "$PWD/.makefile" ]; then
    echo "Skipped (exists): .makefile/"
else
    cp -R "$PROJECT_ROOT/.makefile" "$PWD/.makefile"
    chmod +x .makefile/*.sh
    echo "Copied: .makefile/"
fi
