#!/bin/bash

set -e

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_cli.sh"

cliFrameInit

install_package() { # name brew_formula cmd... -> installs the package with the detected package manager
    local name="$1" brew_formula="$2"
    shift 2
    if ! command -v "$name" &> /dev/null; then
        cliInfo "Installing $name"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y "$name"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "$name"
        elif command -v brew &> /dev/null; then
            brew install "$brew_formula"
        else
            cliError "Install $name manually - no supported package manager found"
            exit 1
        fi
    fi
}

install_package sshpass hudochenkov/sshpass/sshpass
install_package rsync rsync
install_package jq jq

chmod +x ./.makefile/*.sh

SECRETS_FILE="$HOME/.secrets.json"

if [ ! -f "$SECRETS_FILE" ]; then
    cliSuccess "Setup completed"
    cliInfo "Create $SECRETS_FILE with your credentials:"
    cat >&3 <<'JSON_EXAMPLE'
{
    "tech": {
        "rosinfo": {
            "demo": {
                "alpha": {
                    "ssh": {
                        "host": "host",
                        "port": "port",
                        "username": "username",
                        "password": "password"
                    }
            },
            "docker": {
                "host": "host",
                "password": "password",
                "username": "username"
            }
        }
    }
}
JSON_EXAMPLE
    printf '\n' >&3
else
    cliSuccess "Setup completed"
    cliInfo "Secrets file already exists at $SECRETS_FILE"
fi
