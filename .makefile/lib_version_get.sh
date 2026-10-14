isSemver() {
    echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'
}

CLI_LIB_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_cli.sh"
[ -f "$CLI_LIB_PATH" ] && source "$CLI_LIB_PATH"

bumpPatchVersion() {
    echo "$1" | awk -F. '{ print $1 "." $2 "." ($3 + 1) }'
}

semverCompare() {
    awk -v a="$1" -v b="$2" 'BEGIN {
        split(a, x, ".")
        split(b, y, ".")
        for (i = 1; i <= 3; i++) {
            if (x[i] + 0 < y[i] + 0) { print -1; exit }
            if (x[i] + 0 > y[i] + 0) { print 1; exit }
        }
        print 0
    }'
}

# Resolves the version for the NEXT stamp (Git Flow Standard, rule
# #2610092122). The tag on the branch is the version truth (the floor); the
# intended bump is declared in .version (the skill-makefile-version-update
# contract):
#   - line 1 is the current committed version, line 2 is the future version -
#     the declaration point (version_update copies line 2 into line 1 and
#     substitutes the listed files);
#   - a declared line 2 above the last tag is stamped as is;
#   - the steady state (line 2 equal to the last tag - nothing declared) means
#     the default increment: the patch bump of the tag;
#   - a declaration below the tag-derived minimum -> Error, never a duplicate
#     or a lower version;
#   - no tags yet -> one-time bootstrap: line 2 (legacy: line 1) or 0.1.0.
# Optional argument: the ref to read the tag from (default: HEAD).
getVersion() {

    local ref="${1:-HEAD}"
    local tag line1 line2 intent floor

    tag=$(git describe --tags --abbrev=0 "$ref" 2>/dev/null)

    line1=""
    line2=""
    [ -f .version ] && line1=$(sed -n '1p' .version | tr -d '\n\r')
    [ -f .version ] && line2=$(sed -n '2p' .version | tr -d '\n\r')

    if isSemver "$line2"; then
        intent="$line2"
    elif isSemver "$line1"; then
        intent="$line1"
    else
        intent=""
    fi

    if [ -z "$tag" ] || ! isSemver "$tag"; then
        if [ -n "$intent" ]; then
            echo "$intent"
        else
            echo "0.1.0"
        fi
        return 0
    fi

    floor=$(bumpPatchVersion "$tag")

    if [ -z "$intent" ]; then
        cliWarning ".version holds no semver - using the tag floor ${floor}"
        echo "$floor"
        return 0
    fi

    if [ "$(semverCompare "$intent" "$tag")" -eq 0 ]; then
        echo "$floor"
        return 0
    fi

    if [ "$(semverCompare "$intent" "$floor")" -lt 0 ]; then
        cliError "The .version declaration ${intent} is below the minimum ${floor} (the patch bump of the tag ${tag})"
        cliHint "Raise line 2 of .version."
        exit 1
    fi

    echo "$intent"

}
