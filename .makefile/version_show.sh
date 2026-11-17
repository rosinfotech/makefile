#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

showVersion() {
    local tag floor line1 line2
    cliHeader1 "Version"
    tag=$(git describe --tags --abbrev=0 2>/dev/null)
    cliItem "tag (version truth): ${tag:-none}"
    if [ -n "$tag" ] && flowIsSemver "$tag"; then
        floor=$(flowBumpPatch "$tag")
        cliItem "default next stamp (patch): $floor"
    fi
    if [ -f .version ]; then
        line1=$(sed -n '1p' .version | tr -d '\n\r')
        line2=$(sed -n '2p' .version | tr -d '\n\r')
        cliItem ".version line 1 (current): ${line1:-?}, line 2 (future): ${line2:-?}"
    fi
    cliItem "next stamp resolves to: $(getVersion)"
    printf '\n' >&3
}

cliFrameInit
showVersion
