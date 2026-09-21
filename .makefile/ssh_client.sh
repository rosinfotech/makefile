#!/bin/bash

set -e

SSH_PASSWORD=""
SSH_KEY=""
SSH_AUTH_CMD=()
SSH_OPTIONS_BASE="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_OPTIONS="$SSH_OPTIONS_BASE"
SSH_CONNECTION=""
SSH_HOST=""
SSH_PORT=""
SSH_USERNAME=""

sshClientSetupAuth() {
    SSH_OPTIONS="$SSH_OPTIONS_BASE"
    SSH_AUTH_CMD=()

    if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
        SSH_OPTIONS="${SSH_OPTIONS} -i ${SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes"
    elif [ -n "$SSH_PASSWORD" ]; then
        SSH_AUTH_CMD=(sshpass -p "$SSH_PASSWORD")
    else
        echo "Error: Neither ssh key nor password is available"
        return 1
    fi
}

sshClient() {
    case $1 in
        init)
            if [ $# -lt 4 ]; then
                echo "Usage: sshClient init <host> <port> <username> [password] [ssh_key]"
                return 1
            fi
            SSH_HOST="$2"
            SSH_PORT="$3"
            SSH_USERNAME="$4"
            SSH_PASSWORD="${5:-}"
            SSH_KEY="${6:-}"
            SSH_KEY="${SSH_KEY/#\~/$HOME}"
            if [ -n "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
                echo "Warning: ssh key not found: $SSH_KEY"
                SSH_KEY=""
            fi
            SSH_CONNECTION="${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT}"
            sshClientSetupAuth || return 1
            ;;
        exec)
            if [ -z "$SSH_CONNECTION" ]; then
                echo "Error: SSH not initialized. Call sshClient init first."
                return 1
            fi

            if [ $# -lt 2 ]; then
                echo "Usage: sshClient exec <command>"
                return 1
            fi

            local cmd="$2"
            "${SSH_AUTH_CMD[@]}" ssh $SSH_OPTIONS $SSH_CONNECTION "$cmd"
            local exit_code=$?

            if [ $exit_code -ne 0 ]; then
                echo "SSH command failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        execf)
            if [ -z "$SSH_CONNECTION" ]; then
                echo "Error: SSH not initialized. Call sshClient init first."
                return 1
            fi

            if [ $# -lt 2 ]; then
                echo "Usage: sshClient execf <command>"
                return 1
            fi

            local cmd="$2"
            "${SSH_AUTH_CMD[@]}" ssh $SSH_OPTIONS $SSH_CONNECTION "$cmd" || true
            return 0
            ;;
        scp)
            if [ -z "$SSH_CONNECTION" ]; then
                echo "Error: SSH not initialized. Call sshClient init first."
                return 1
            fi

            if [ $# -lt 3 ]; then
                echo "Usage: sshClient scp <source> <destination>"
                return 1
            fi

            local source="$2"
            local destination="$3"

            "${SSH_AUTH_CMD[@]}" scp -P "$SSH_PORT" \
                $SSH_OPTIONS \
                "$source" "${SSH_USERNAME}@${SSH_HOST}:${destination}"
            local exit_code=$?

            if [ $exit_code -ne 0 ]; then
                echo "SCP failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        rsync)
            if [ -z "$SSH_CONNECTION" ]; then
                echo "Error: SSH not initialized. Call sshClient init first."
                return 1
            fi

            if [ $# -lt 3 ]; then
                echo "Usage: sshClient rsync <source> <destination> [exclude_pattern]"
                return 1
            fi

            local source="$2"
            local destination="$3"
            local exclude_pattern="${4:-}"

            local exclude_opts=""
            if [ -n "$exclude_pattern" ]; then
                exclude_opts="--exclude='$exclude_pattern'"
            fi

            "${SSH_AUTH_CMD[@]}" rsync -avz -e "ssh -p $SSH_PORT $SSH_OPTIONS" \
                --exclude-from='./.makefile/.rsync-exclude' \
                $exclude_opts \
                "$source/" "${SSH_USERNAME}@${SSH_HOST}:${destination}/"
            local exit_code=$?

            if [ $exit_code -ne 0 ]; then
                echo "Rsync failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        cleanup)
            SSH_PASSWORD=""
            SSH_KEY=""
            SSH_AUTH_CMD=()
            SSH_OPTIONS="$SSH_OPTIONS_BASE"
            SSH_CONNECTION=""
            SSH_HOST=""
            SSH_PORT=""
            SSH_USERNAME=""
            ;;
        *)
            echo "Usage: sshClient {init|exec|execf|scp|rsync|cleanup}"
            return 1
            ;;
    esac
}

export -f sshClient
