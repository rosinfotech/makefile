#!/bin/bash

set -e

SSH_PASSWORD=""
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
SSH_CONNECTION=""
SSH_HOST=""
SSH_PORT=""
SSH_USERNAME=""

sshClient() {
    case $1 in
        init)
            if [ $# -lt 4 ]; then
                echo "Usage: sshClient init <host> <port> <username> <password>"
                return 1
            fi
            SSH_HOST="$2"
            SSH_PORT="$3"
            SSH_USERNAME="$4"
            SSH_PASSWORD="$5"
            SSH_CONNECTION="${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT}"
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
            sshpass -p "$SSH_PASSWORD" ssh $SSH_OPTIONS $SSH_CONNECTION "$cmd"
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
            sshpass -p "$SSH_PASSWORD" ssh $SSH_OPTIONS $SSH_CONNECTION "$cmd" || true
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

            sshpass -p "$SSH_PASSWORD" scp -P "$SSH_PORT" \
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

            sshpass -p "$SSH_PASSWORD" rsync -avz -e "ssh -p $SSH_PORT $SSH_OPTIONS" \
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
