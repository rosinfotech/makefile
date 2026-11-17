#!/bin/bash
#
# lib_cli.sh - the Output CLI Standard primitives (the CLI Engineer role
# rules, the 0.9.0 redesign): everything on stdout, the exit-code contract,
# the flags-only color gating, the closed role palette with the dark/light
# theme, the two heading levels, the TYPE. Text message format, the list
# helpers and the prompt primitives. A library: sourced by the framework
# commands.
#
# Message channel (the infra reading, backported): fd 3 duplicates stdout
# and carries every human block - headings, messages, hints, prompts,
# lists - while plain data results stay on stdout. Command substitutions
# inherit fd 3 but capture only stdout, so messages printed inside $( )
# helpers stay visible and the captured values stay clean.
#
# Blank-line ownership: every block prints its own trailing blank
# separator line - headings, messages, hints, prompts; a list is one block
# of dense items closed by a single blank from the call site. No block
# receives a separator above itself; two blank lines in a row are a
# violation. A run opens with one blank line before its first output
# (cliFrameOpen); the trailing separator comes from the last block itself.

# --- the theme: the dark column is the default; COLORFGBG (published by
# --- the terminal) switches to the light column on a light background ---

cliThemeDetect() {
    CLI_LIGHT=0
    [ -n "$COLORFGBG" ] || return 0
    case "${COLORFGBG##*;}" in
        7|9|10|11|12|13|14|15) CLI_LIGHT=1 ;;
    esac
    return 0
}

# --- color gating: emitted only when stdout is a TTY; the flags override --
# The only overrides are the flags (--color / --no-color, parsed by
# cliParseArgs into FLOW_COLOR); environment variables do not participate.

cliColorApply() { # sets CLI_COLOR_OUT and the closed role palette
    case "${FLOW_COLOR:-}" in
        1) CLI_COLOR_OUT=1 ;;
        0) CLI_COLOR_OUT=0 ;;
        *) if [ -t 1 ]; then CLI_COLOR_OUT=1; else CLI_COLOR_OUT=0; fi ;;
    esac
    CLI_RESET=$'\033[0m'
    cliThemeDetect
    if [ "$CLI_LIGHT" = "1" ]; then
        CLI_HEADING1=$'\033[38;5;25m'
        CLI_HEADING2=$'\033[30m'
        CLI_PROMPT=$'\033[38;5;25m'
        CLI_INFO=$'\033[38;5;25m'
        CLI_SUCCESS=$'\033[38;5;28m'
        CLI_WARNING=$'\033[38;5;130m'
        CLI_ERROR=$'\033[31m'
        CLI_TEXT=$'\033[38;5;239m'
        CLI_HINT=$'\033[38;5;246m'
    else
        CLI_HEADING1=$'\033[96m'
        CLI_HEADING2=$'\033[97m'
        CLI_PROMPT=$'\033[96m'
        CLI_INFO=$'\033[96m'
        CLI_SUCCESS=$'\033[92m'
        CLI_WARNING=$'\033[93m'
        CLI_ERROR=$'\033[91m'
        CLI_TEXT=$'\033[38;5;251m'
        CLI_HINT=$'\033[90m'
    fi
}

cliColorApply

# The message channel: fd 3 duplicates stdout for the run; $( ) captures
# inherit fd 3, never the captured stdout, so human blocks stay visible.
exec 3>&1

# --- headings: a plain colored line, two levels, no markers, no bold -------

cliHeader1() {
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s\n\n' "$CLI_HEADING1" "$1" "$CLI_RESET" >&3
    else
        printf '%s\n\n' "$1" >&3
    fi
}

cliHeader2() {
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s\n\n' "$CLI_HEADING2" "$1" "$CLI_RESET" >&3
    else
        printf '%s\n\n' "$1" >&3
    fi
}

# --- messages: the closed prefix set, TYPE. Text, the whole line in the
# --- semantic color, the text opens with a capital letter and drops the
# --- trailing period; a hint keeps it. Information renders the color
# --- alone, without a prefix (the owner's choice against prefix noise,
# --- mirroring infra; the prefix set stays closed). Every message prints
# --- its own trailing blank separator line. ------------------------------

cliMsgRender() { # color prefix text -> the "TYPE. Text" block on fd 3
    local text="$3"
    case "$text" in
        *..) ;;
        *.) text="${text%.}" ;;
    esac
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s %s%s\n\n' "$1" "$2" "$text" "$CLI_RESET" >&3
    else
        printf '%s %s\n\n' "$2" "$text" >&3
    fi
}

cliError() {
    cliMsgRender "$CLI_ERROR" "Error." "$*"
}

cliWarning() {
    cliMsgRender "$CLI_WARNING" "Warning." "$*"
}

cliSuccess() {
    cliMsgRender "$CLI_SUCCESS" "Success." "$*"
}

cliInfo() {
    local text="$*"
    case "$text" in
        *..) ;;
        *.) text="${text%.}" ;;
    esac
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s\n\n' "$CLI_INFO" "$text" "$CLI_RESET" >&3
    else
        printf '%s\n\n' "$text" >&3
    fi
}

cliHint() {
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%sHint. %s%s\n\n' "$CLI_HINT" "$*" "$CLI_RESET" >&3
    else
        printf 'Hint. %s\n\n' "$*" >&3
    fi
}

# --- text, paths and lists ---------------------------------------------------

cliText() { # a paragraph line in the Text color with its separator
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s\n\n' "$CLI_TEXT" "$*" "$CLI_RESET" >&3
    else
        printf '%s\n\n' "$*" >&3
    fi
}

cliPath() { # an inline path in the Information color (no newline)
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s' "$CLI_INFO" "$1" "$CLI_RESET"
    else
        printf '%s' "$1"
    fi
}

cliLink() { # a URL result line in the Information color with its separator
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s%s\n\n' "$CLI_INFO" "$*" "$CLI_RESET" >&3
    else
        printf '%s\n\n' "$*" >&3
    fi
}

cliItem() { # "- <text>;" - a dense leaf list line in the Text color
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s- %s;%s\n' "$CLI_TEXT" "$*" "$CLI_RESET" >&3
    else
        printf -- '- %s;\n' "$*" >&3
    fi
}

cliItemNum() { # "<number>. <text>;" - a dense ordered leaf line in the Text color
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s. %s;%s\n' "$CLI_TEXT" "$1" "${*:2}" "$CLI_RESET" >&3
    else
        printf -- '%s. %s;\n' "$1" "${*:2}" >&3
    fi
}

# --- the run frame: one blank line before the first output ------------------

cliFrameOpen() {
    printf '\n' >&3
}

cliFrameClose() {
    :
}

cliFrameInit() {
    cliFrameOpen
    trap 'cliFrameClose' EXIT
}

# --- prompts: the prompt color, fd 3, the blank after the answer ----------
# A prompt in a non-TTY stream is refused with an Error. message and exit
# code 2; --yes / --force bypass the prompts. An empty answer selects the
# default.

cliConfirm() { # question -> 0 yes, 1 no; [Y/n]? - the empty answer accepts
    local answer
    if [ "${FLOW_YES:-}" = "1" ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        cliError "The confirmation requires an interactive terminal - rerun with args='--yes' to accept it"
        exit 2
    fi
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s [Y/n]? %s' "$CLI_PROMPT" "$1" "$CLI_RESET" >&3
    else
        printf '%s [Y/n]? ' "$1" >&3
    fi
    if ! read -r answer; then
        printf '\n' >&3
        return 0
    fi
    printf '\n' >&3
    case "$answer" in
        ''|[yY]|[yY][eE][sS]) return 0 ;;
        [nN]|[nN][oO]) return 1 ;;
        *)
            cliError "Unknown answer '${answer}' - expected Y or n"
            exit 2
            ;;
    esac
}

cliConfirmNo() { # question -> 0 yes, 1 no; [y/N]? - the empty answer refuses;
                 # a non-TTY stream takes the default (no)
    local answer
    if [ "${FLOW_YES:-}" = "1" ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        return 1
    fi
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s [y/N]? %s' "$CLI_PROMPT" "$1" "$CLI_RESET" >&3
    else
        printf '%s [y/N]? ' "$1" >&3
    fi
    if ! read -r answer; then
        printf '\n' >&3
        return 1
    fi
    printf '\n' >&3
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        ''|[nN]|[nN][oO]) return 1 ;;
        *)
            cliError "Unknown answer '${answer}' - expected y or N"
            exit 2
            ;;
    esac
}

cliAsk() { # question -> echoes the typed answer on stdout; a non-TTY stream echoes nothing
    local answer=""
    if [ ! -t 0 ]; then
        return 0
    fi
    if [ "$CLI_COLOR_OUT" = "1" ]; then
        printf '%s%s %s' "$CLI_PROMPT" "$1" "$CLI_RESET" >&3
    else
        printf '%s ' "$1" >&3
    fi
    if read -r answer; then
        printf '\n' >&3
    fi
    printf '%s' "$answer"
}

cliParseArgs() { # "$@" -> FLOW_* globals + CLI_ARG_POSITIONAL; the single input channel: flags and the one positional
    CLI_ARG_POSITIONAL=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --yes|-y) FLOW_YES=1 ;;
            --release) FLOW_RELEASE=1 ;;
            --defer) FLOW_RELEASE=0 ;;
            --force) FLOW_CLEAR=1 ;;
            --color) FLOW_COLOR=1; cliColorApply ;;
            --no-color) FLOW_COLOR=0; cliColorApply ;;
            --redirected) FLOW_REDIRECTED=1 ;;
            --)
                shift
                if [ $# -gt 1 ] || { [ $# -eq 1 ] && [ -n "$CLI_ARG_POSITIONAL" ]; }; then
                    cliError "Expected at most one positional argument - got: $*"
                    exit 2
                fi
                [ $# -eq 1 ] && CLI_ARG_POSITIONAL="$1"
                return 0
                ;;
            -*)
                cliError "Unknown flag: $1"
                cliHint 'Supported: --yes (-y), --release, --defer, --force, --color, --no-color.'
                exit 2
                ;;
            *)
                if [ -n "$CLI_ARG_POSITIONAL" ]; then
                    cliError "Expected at most one positional argument - got '$CLI_ARG_POSITIONAL' and '$1'"
                    exit 2
                fi
                CLI_ARG_POSITIONAL="$1"
                ;;
        esac
        shift
    done
    return 0
}
