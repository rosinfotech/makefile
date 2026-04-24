#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/get_version.sh"

showVersion() {
    echo "Using version: $(getVersion)"
}
