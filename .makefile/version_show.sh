#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

showVersion() {
    local tag floor line1 line2
    tag=$(git describe --tags --abbrev=0 2>/dev/null)
    printf -- '- tag (version truth): %s;\n' "${tag:-none}"
    if [ -n "$tag" ] && flowIsSemver "$tag"; then
        floor=$(flowBumpPatch "$tag")
        printf -- '- default next stamp (patch): %s;\n' "$floor"
    fi
    if [ -f .version ]; then
        line1=$(sed -n '1p' .version | tr -d '\n\r')
        line2=$(sed -n '2p' .version | tr -d '\n\r')
        printf -- '- .version line 1 (current): %s, line 2 (future): %s;\n' \
            "${line1:-?}" "${line2:-?}"
    fi
    printf -- '- next stamp resolves to: %s;\n' "$(getVersion)"
    printf '\n'
}

cliFrameInit
showVersion
