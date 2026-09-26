#!/bin/bash
#
# make vendor [path] - makes the project at <path> (default: the current
# directory) independent from the globally linked makefile:
#
#   .makefile/vendor/rosinfotech/   framework scripts + README manifest
#                                   (source repo, commit SHA, update hints)
#   Makefile                        standalone block prepended on the first
#                                   run (marker-guarded, backed up); on
#                                   later runs only the vendor directory is
#                                   refreshed (update mode)
#
# When <path> has no Makefile a minimal project is scaffolded (Makefile
# with the standalone block, .version, CHANGELOG.md, README.md,
# .editorconfig) when the target has no Makefile.
#
# The vendor directory is fully managed: it is replaced wholesale on
# every run; project scripts in .makefile/ are never touched.

set -e

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
PROJECT_ROOT="$(dirname "$(dirname "$SELF")")"
SRC="$PROJECT_ROOT/.makefile"

MARKER="# --- vendored makefile framework (make vendor) ---"
DEST_REL=".makefile/vendor/rosinfotech"

TARGET="${1:-$PWD}"
if [ ! -d "$TARGET" ]; then
    mkdir -p "$TARGET" || { echo "Error: cannot create directory: $TARGET" >&2; exit 1; }
fi
TARGET="$(cd "$TARGET" && pwd)"
if [ "$TARGET" = "$PROJECT_ROOT" ]; then
    echo "Error: refusing to vendor the makefile repository itself" >&2
    exit 1
fi
cd "$TARGET"

# --- 1. Scaffold an empty project (first run without a Makefile) -------

scaffold=0
if [ ! -f "Makefile" ]; then
    scaffold=1
    [ -f "$SRC/../.editorconfig" ] && cp "$SRC/../.editorconfig" ./.editorconfig
    [ -f .version ] || printf '0.0.1\n0.0.1\n' > .version
    if [ ! -f CHANGELOG.md ]; then
        cat > CHANGELOG.md << 'CHANGELOG_HEAD'
<!-- markdownlint-disable MD041 -->

[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Changelog

CHANGELOG_HEAD
        printf '## [0.0.1] - %s\n\n### Initialization\n\n- Welcome!\n' "$(date +%Y-%m-%d)" >> CHANGELOG.md
    fi
    [ -f README.md ] || printf '# Welcome\n' > README.md
fi

# --- 2. Makefile: prepend the standalone block on the first run --------

if [ "$scaffold" -eq 1 ]; then
    : > Makefile
elif grep -qF "$MARKER" Makefile; then
    echo "Makefile already vendored - refreshing ${DEST_REL}/ only"
else
    backup="Makefile.bak.$(date +%Y_%m_%d_%H%M%S)"
    cp Makefile "$backup"
fi

if [ "$scaffold" -eq 1 ] || ! grep -qF "$MARKER" Makefile 2>/dev/null; then
    {
        printf '%s\n' "$MARKER"
        printf '%s\n' '# Standalone definitions: this Makefile does not require the globally'
        printf '%s\n' '# linked make (update: make vendor <this path>; remove: delete this block'
        printf '%s\n' '# and .makefile/vendor/rosinfotech/).'
        printf '\n'
        printf 'define resolve_script\n$(if $(wildcard $(CURDIR)/.makefile/$(1)),$(CURDIR)/.makefile/$(1),$(CURDIR)/.makefile/vendor/rosinfotech/$(1))\nendef\n\n'
        printf '.PHONY: init clear git_commit git_commit_push git_commit_version kill_processes setup show_version update_version\n'
        printf '.SILENT: init clear git_commit git_commit_push git_commit_version kill_processes setup show_version update_version\n\n'
        printf 'init:\n\tchmod +x $(wildcard $(CURDIR)/.makefile/*.sh) $(wildcard $(CURDIR)/.makefile/vendor/rosinfotech/*.sh)\n\n'
        printf 'clear: init\n\t$(call resolve_script,clear.sh)\n\n'
        printf 'git_commit: init\n\t$(call resolve_script,git_commit.sh) "$(filter-out $@,$(MAKECMDGOALS))"\n\n'
        printf 'git_commit_push: init\n\t$(call resolve_script,git_commit_push.sh) "$(filter-out $@,$(MAKECMDGOALS))"\n\n'
        printf 'git_commit_version: init\n\t$(call resolve_script,git_commit_version.sh) "$(filter-out $@,$(MAKECMDGOALS))"\n\n'
        printf 'kill_processes: init\n\t$(call resolve_script,kill_processes.sh)\n\n'
        printf 'setup: init\n\t$(call resolve_script,setup.sh)\n\n'
        printf 'show_version: init\n\t$(call resolve_script,version_show.sh)\n\n'
        printf 'update_version: init\n\t$(call resolve_script,version_update.sh)\n\n'
        printf '# --- end vendored makefile framework ---\n\n'
        [ "$scaffold" -eq 0 ] && cat "$backup"
    } > Makefile.new
    mv Makefile.new Makefile
    if [ "$scaffold" -eq 0 ]; then
        echo "Makefile: standalone definitions prepended (backup: ${backup#./})"
    else
        echo "Makefile: created with the standalone definitions"
    fi
fi

# --- 3. Refresh the vendor directory (fully managed) --------------------

rm -rf "$DEST_REL"
mkdir -p "$DEST_REL"
count=0
for item in "$SRC"/*.sh; do
    [ -e "$item" ] || continue
    cp -R "$item" "$DEST_REL/"
    count=$((count + 1))
done
find "$DEST_REL" -name "*.sh" -exec chmod +x {} +

# --- 4. README manifest ---------------------------------------------------

commit_sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "${DEST_REL}/README.md" <<MANIFEST
# Vendored rosinfotech/makefile

- Source:  git@github.com:rosinfotech/makefile.git
- Commit:  ${commit_sha} ($(date +%Y-%m-%d))
- Items:   ${count} (framework scripts, make wrapper, ai-skills)

Update:   git pull in a clone of the makefile repository, then
          make vendor "$(cd "$TARGET" && pwd)"
Remove:   rm -rf ${DEST_REL} and delete the "${MARKER}" block from the Makefile

This directory is fully managed - never edit it by hand.
MANIFEST

echo "Vendored: ${count} items -> ${DEST_REL}/ (commit ${commit_sha})"

# --- 5. Validate with the system make --------------------------------------

MAKE_BIN="$(command -v make)"
[ -x /usr/bin/make ] && MAKE_BIN=/usr/bin/make
if "$MAKE_BIN" -n -C "$TARGET" init > /dev/null 2>&1; then
    echo "Validation ok: standalone make parses the Makefile (init)"
else
    if [ -n "${backup:-}" ] && [ -f "$backup" ]; then
        cp "$backup" Makefile
        echo "Error: validation failed - the Makefile was restored from the backup" >&2
    fi
    rm -rf "$DEST_REL"
    echo "Error: validation failed - the vendor directory was removed" >&2
    exit 1
fi

echo "Done: the project is independent from the linked makefile"
