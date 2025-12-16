#!/bin/bash

set -e

setup() {

    if ! command -v sshpass &> /dev/null; then
        echo "Installing sshpass..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y sshpass
        elif command -v yum &> /dev/null; then
            sudo yum install -y sshpass
        elif command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            echo "Please install sshpass manually"
            exit 1
        fi
    fi

    if ! command -v rsync &> /dev/null; then
        echo "Installing rsync..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y rsync
        elif command -v yum &> /dev/null; then
            sudo yum install -y rsync
        elif command -v brew &> /dev/null; then
            brew install rsync
        else
            echo "Please install rsync manually"
            exit 1
        fi
    fi

    if ! command -v jq &> /dev/null; then
        echo "Installing jq..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            echo "Please install jq manually"
            exit 1
        fi
    fi

    chmod +x ./.makefile/*.sh

    echo "Setup completed successfully"
    echo ""

    SECRETS_FILE="$HOME/.secrets.json"

    if [ ! -f "$SECRETS_FILE" ]; then
        echo "Please create $SECRETS_FILE with your credentials:"
        echo '{
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
}'
    else
        echo "Setup completed successfully"
        echo "Secrets file already exists at $SECRETS_FILE"
    fi

}

setup "$@"
