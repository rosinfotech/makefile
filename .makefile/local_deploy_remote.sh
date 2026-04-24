#!/bin/bash

# An example of how to use commands related SSH transferring

set -e

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/setup.sh"
source "$LIB_DIR/ssh_client.sh"
source "$LIB_DIR/ssh_file_upload.sh"
source "$LIB_DIR/ssh_directory_upload.sh"
source "$LIB_DIR/get_home_secret.sh"

main() {

    local host=$(getHomeSecret '.tech.rosinfo.ssh.host')
    local port=$(getHomeSecret '.tech.rosinfo.ssh.port')
    local username=$(getHomeSecret '.tech.rosinfo.ssh.username')
    local password=$(getHomeSecret '.tech.rosinfo.ssh.password')

    if [ -z "$host" ] || [ -z "$port" ] || [ -z "$username" ] || [ -z "$password" ]; then
        echo "Error: Failed to load SSH secrets from $SECRETS_FILE"
        exit 1
    fi

    sshClient init "$host" "$port" "$username" "$password"

    sshClient execf "rm -rf /home/rosinfo.tech/www"

    sshClient execf "mkdir -p /home/rosinfo.tech/www"

    sshDirectoryUpload "./dist" "/home/rosinfo.tech/www" "/.DS_Store"

    sshClient execf "chmod -R 0775 /home/rosinfo.tech/www"

    sshClient execf "chown -R rosinfo.tech:www /home/rosinfo.tech/www"

    sshClient cleanup

}

main "$@"
