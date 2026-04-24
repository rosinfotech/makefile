#!/bin/bash

set -e

EXPECTED_URL="url = git@github.com:rosinfotech/makefile.git"

if [ ! -f ".git/config" ]; then
    echo "Error: not a git repository" >&2
    exit 1
fi

if ! grep -qF "$EXPECTED_URL" .git/config; then
    echo "Error: not in makefile project context" >&2
    exit 1
fi

mkdir -p ~/.local/bin
ln -sf "$(pwd)/.makefile/make" ~/.local/bin/make
echo "Linked: ~/.local/bin/make -> $(pwd)/.makefile/make"

if ! echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
    echo "Warning: ~/.local/bin is not in your PATH"
    echo "Add 'export PATH=\"\$HOME/.local/bin:\$PATH\"' to your ~/.zshrc"
fi
