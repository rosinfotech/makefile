#!/bin/bash
#
# Abstract SSH transport: sshClient (init/exec/execf/scp/rsync/download/
# cleanup) plus the file/directory transfer helpers. Auth: password via
# sshpass or an ssh key; the key takes precedence. Pure transport - no
# server registry, no secrets schema, no logging (those live in the
# consuming project or in lib_secrets.sh).
#

CLI_LIB_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_cli.sh"
[ -f "$CLI_LIB_PATH" ] && source "$CLI_LIB_PATH"

SSH_DEFAULT_PORT=22

SSH_PASSWORD=""
SSH_KEY=""
SSH_OPTIONS_BASE="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10 -o NumberOfPasswordPrompts=1"
SSH_OPTIONS="$SSH_OPTIONS_BASE"
SSH_AUTH_CMD=()
SSH_CONNECTION=""


sshClientSetupAuth() {
    SSH_OPTIONS="$SSH_OPTIONS_BASE"
    SSH_AUTH_CMD=()

    if [ -n "$SSH_KEY" ] && [ -f "$SSH_KEY" ]; then
        SSH_OPTIONS="${SSH_OPTIONS} -i ${SSH_KEY} -o IdentitiesOnly=yes -o BatchMode=yes"
    elif [ -n "$SSH_PASSWORD" ]; then
        SSH_AUTH_CMD=(sshpass -p "$SSH_PASSWORD")
    else
        cliError "Neither ssh key nor password is available"
        return 1
    fi
}

sshClientStatus() {
    if [ -z "$SSH_CONNECTION" ]; then
        cliError "SSH not initialized - call sshClient init first"
        return 2
    fi

    local err
    local exit_code=0
    err=$(mktemp)
    "${SSH_AUTH_CMD[@]}" ssh $SSH_OPTIONS $SSH_CONNECTION "true" 2>"$err" || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        rm -f "$err"
        return 0
    elif grep -qi "permission denied" "$err"; then
        rm -f "$err"
        return 1
    else
        rm -f "$err"
        return 2
    fi
}

sshFileUpload() {
    if [ $# -lt 2 ]; then
        cliError "sshFileUpload requires <source> <destination>"
        return 1
    fi
    if [ ! -f "$1" ]; then
        cliError "Source file does not exist: $1"
        return 1
    fi
    sshClient scp "$1" "$2"
}

sshDirectoryUpload() {
    if [ $# -lt 2 ]; then
        cliError "sshDirectoryUpload requires <source> <destination> [exclude_pattern]"
        return 1
    fi
    if [ ! -d "$1" ]; then
        cliError "Source directory does not exist: $1"
        return 1
    fi
    sshClient rsync "$1" "$2" "${3:-}"
}

sshDirectoryDownloadAsArchive() {
    if [ $# -ne 2 ]; then
        cliError "sshDirectoryDownloadAsArchive requires <remote_directory> <local_archive>"
        return 1
    fi

    if [ -z "$SSH_CONNECTION" ]; then
        cliError "SSH not initialized - call sshClient init first"
        return 1
    fi

    local remote_directory="$1"
    local local_archive="$2"
    local remote_parent="${remote_directory%/*}"
    local remote_name="${remote_directory##*/}"
    local exit_code=0

    "${SSH_AUTH_CMD[@]}" ssh $SSH_OPTIONS $SSH_CONNECTION \
        "tar -czf - -C '${remote_parent}' '${remote_name}'" > "$local_archive" || exit_code=$?

    # tar exit 1 = "file changed as we read it" and similar warnings:
    # the archive is still written and valid - warn but accept.
    if [ $exit_code -eq 1 ]; then
        cliWarning "Remote tar reported warnings (exit 1, e.g. files changed while reading) - archive accepted: ${local_archive}"
        exit_code=0
    fi

    if [ $exit_code -ne 0 ] || [ ! -s "$local_archive" ]; then
        cliError "Archive download failed: $local_archive"
        rm -f "$local_archive"
        return 1
    fi
}

sshClient() {
    case $1 in
        init)
            if [ $# -lt 4 ]; then
                cliError "sshClient init requires <host> <port> <username> [password] [ssh_key]"
                return 1
            fi
            SSH_HOST="$2"
            SSH_PORT="$3"
            SSH_USERNAME="$4"
            SSH_PASSWORD="${5:-}"
            SSH_KEY="${6:-}"
            SSH_KEY="${SSH_KEY/#\~/$HOME}"
            if [ -n "$SSH_KEY" ] && [ ! -f "$SSH_KEY" ]; then
                cliWarning "Ssh key not found: $SSH_KEY"
                SSH_KEY=""
            fi
            SSH_CONNECTION="${SSH_USERNAME}@${SSH_HOST} -p ${SSH_PORT}"
            sshClientSetupAuth || return 1
            ;;
        exec)
            if [ -z "$SSH_CONNECTION" ]; then
                cliError "SSH not initialized - call sshClient init first"
                return 1
            fi
            if [ $# -lt 2 ]; then
                cliError "sshClient exec requires <command>"
                return 1
            fi
            local attempt=0
            local err
            local exit_code=0
            err=$(mktemp)
            while :; do
                exit_code=0
                "${SSH_AUTH_CMD[@]}" ssh -n $SSH_OPTIONS $SSH_CONNECTION "$2" 2>"$err" || exit_code=$?
                if [ $exit_code -ne 255 ] || ! grep -qi "permission denied" "$err"; then
                    break
                fi
                attempt=$((attempt + 1))
                if [ $attempt -ge 3 ]; then
                    break
                fi
                cliInfo "SSH auth failed (attempt ${attempt}/3), retrying in 3s"
                sleep 3
            done
            cat "$err"
            rm -f "$err"
            if [ $exit_code -ne 0 ]; then
                cliError "SSH command failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        execf)
            if [ -z "$SSH_CONNECTION" ]; then
                cliError "SSH not initialized - call sshClient init first"
                return 1
            fi
            if [ $# -lt 2 ]; then
                cliError "sshClient execf requires <command>"
                return 1
            fi
            local attempt=0
            local err
            local exit_code=0
            err=$(mktemp)
            while :; do
                exit_code=0
                "${SSH_AUTH_CMD[@]}" ssh -n $SSH_OPTIONS $SSH_CONNECTION "$2" 2>"$err" || exit_code=$?
                if [ $exit_code -ne 255 ] || ! grep -qi "permission denied" "$err"; then
                    break
                fi
                attempt=$((attempt + 1))
                if [ $attempt -ge 3 ]; then
                    break
                fi
                cliInfo "SSH auth failed (attempt ${attempt}/3), retrying in 3s"
                sleep 3
            done
            cat "$err"
            rm -f "$err"
            return 0
            ;;
        scp)
            if [ -z "$SSH_CONNECTION" ]; then
                cliError "SSH not initialized - call sshClient init first"
                return 1
            fi
            if [ $# -lt 3 ]; then
                cliError "sshClient scp requires <source> <destination>"
                return 1
            fi
            local exit_code=0
            "${SSH_AUTH_CMD[@]}" scp -P "$SSH_PORT" \
                $SSH_OPTIONS \
                "$2" "${SSH_USERNAME}@${SSH_HOST}:$3" || exit_code=$?
            if [ $exit_code -ne 0 ]; then
                cliError "SCP failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        rsync)
            if [ -z "$SSH_CONNECTION" ]; then
                cliError "SSH not initialized - call sshClient init first"
                return 1
            fi
            if [ $# -lt 3 ]; then
                cliError "sshClient rsync requires <source> <destination> [exclude_pattern]"
                return 1
            fi
            local exit_code=0
            local exclude_opts=""
            local exclude_file_opts=""
            if [ -n "$4" ]; then
                exclude_opts="--exclude=$4"
            fi
            if [ -f "$SERVER_LIB_DIR/.rsync-exclude" ]; then
                exclude_file_opts="--exclude-from=$SERVER_LIB_DIR/.rsync-exclude"
            fi
            "${SSH_AUTH_CMD[@]}" rsync -avz -e "ssh -p $SSH_PORT $SSH_OPTIONS" \
                $exclude_file_opts \
                $exclude_opts \
                "$2/" "${SSH_USERNAME}@${SSH_HOST}:$3/" || exit_code=$?
            if [ $exit_code -ne 0 ]; then
                cliError "Rsync failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
        download)
            if [ -z "$SSH_CONNECTION" ]; then
                cliError "SSH not initialized - call sshClient init first"
                return 1
            fi
            if [ $# -lt 3 ]; then
                cliError "sshClient download requires <remote> <local> [exclude_pattern]"
                return 1
            fi
            local exit_code=0
            local exclude_opts=""
            if [ -n "$4" ]; then
                exclude_opts="--exclude=$4"
            fi
            mkdir -p "$3"
            "${SSH_AUTH_CMD[@]}" rsync -avz -e "ssh -p $SSH_PORT $SSH_OPTIONS" \
                $exclude_opts \
                "${SSH_USERNAME}@${SSH_HOST}:$2/" "$3/" || exit_code=$?
            if [ $exit_code -ne 0 ]; then
                cliError "Rsync download failed with exit code: $exit_code"
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
            cliError "sshClient requires one of: init, exec, execf, scp, rsync, download, cleanup"
            return 1
            ;;
    esac
}

sshDirectoryDownload() {
    if [ $# -lt 2 ]; then
        cliError "sshDirectoryDownload requires <remote_directory> <local_directory> [exclude_pattern]"
        return 1
    fi
    sshClient download "$1" "$2" "${3:-}"
}
