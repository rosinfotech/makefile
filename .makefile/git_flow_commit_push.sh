#!/bin/bash

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$LIB_DIR/lib_git_flow.sh"

gitCommitPush() {

    local message="$1"
    local version
    local current_branch
    local remote_name="origin"
    local attempt=0
    local recompute old_version

    version=$(getVersion)

    if [ $? -ne 0 ]; then
        exit 1
    fi

    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "$current_branch" ]; then
        if git rev-parse --verify HEAD >/dev/null 2>&1; then
            cliError "Not on any branch (detached HEAD state)"
            exit 1
        else
            current_branch=$(git config --get init.defaultBranch || echo "main")
            cliWarning "New repository detected - will use branch '${current_branch}'"
        fi
    fi

    old_version=$(git describe --tags --abbrev=0 2>/dev/null)
    if [ -z "$old_version" ] && [ -f .version ]; then
        old_version=$(sed -n '1p' .version | tr -d '\n\r')
    fi

    if flowHasRemote && git show-ref --verify --quiet "refs/remotes/${remote_name}/${current_branch}" 2>/dev/null; then
        git fetch "${remote_name}" >/dev/null 2>&1 || true
        git merge --ff-only "${remote_name}/${current_branch}" >/dev/null 2>&1 || {
            cliError "${current_branch} diverged from ${remote_name}/${current_branch} - sync manually before stamping"
            exit 1
        }
    fi

    if (flowDetectVariant) >/dev/null 2>&1 && ! flowReleaseGate; then
        if [ -z "$message" ]; then
            cliError "The commit message is required when the tagging is deferred"
            exit 2
        fi
        git add .
        git commit -m "${message}" >/dev/null 2>&1 || {
            cliError "Failed to create commit"
            exit 1
        }
        if git rev-parse --verify "${remote_name}/${current_branch}" >/dev/null 2>&1; then
            git push "${remote_name}" "${current_branch}" >/dev/null 2>&1 || {
                cliError "Failed to push ${current_branch}"
                exit 1
            }
        elif git remote | grep -q .; then
            git push --set-upstream "${remote_name}" "${current_branch}" >/dev/null 2>&1 || {
                cliError "Failed to push ${current_branch}"
                exit 1
            }
        else
            cliWarning "No remote configured - the deferred commit stays local"
            cliSuccess "Tagging deferred - the commit carries no version or tag"
            exit 0
        fi
        cliInfo "Tagging deferred - the commit carries no version or tag"
        cliHint "The next tagged stamp versions the accumulated work."
        printf '\n' >&2
        exit 0
    fi

    while :; do
        attempt=$((attempt + 1))

        flowUpdateVersionArtifact "${version}"
        if flowSubstituteVersion "$old_version" "${version}"; then
            if [ "$attempt" -eq 1 ] && ! flowConfirm "Continue with the stamp?"; then
                flowDeclined
            fi
        fi

        git add .

        if [ "$attempt" -eq 1 ]; then
            if [ -z "$message" ]; then
                git commit -m "${version}" >/dev/null
            else
                git commit -m "${version}: ${message}" >/dev/null
            fi
        else
            if [ -z "$message" ]; then
                git commit --amend -m "${version}" >/dev/null
            else
                git commit --amend -m "${version}: ${message}" >/dev/null
            fi
        fi

        if [ $? -ne 0 ]; then
            cliError "Failed to create commit"
            exit 1
        fi

        if [ "$attempt" -eq 1 ]; then
            if git rev-parse "${version}" >/dev/null 2>&1; then
                cliError "Tag ${version} already exists"
                exit 1
            fi
        else
            git tag -d "${version}" >/dev/null 2>&1
        fi

        git tag "${version}" >/dev/null 2>&1 || {
            cliError "Failed to create tag ${version}"
            exit 1
        }

        push_output=""
        if git rev-parse --verify "${remote_name}/${current_branch}" >/dev/null 2>&1; then
            push_output=$(git push --atomic "${remote_name}" "${current_branch}" "refs/tags/${version}" 2>&1)
        else
            push_output=$(git push --atomic --set-upstream "${remote_name}" "${current_branch}" "refs/tags/${version}" 2>&1)
        fi

        if [ $? -eq 0 ]; then
            cliSuccess "Committed, pushed, and tagged with version ${version}"
            exit 0
        fi

        if ! git remote | grep -q .; then
            cliWarning "No remote configured - the commit and the tag ${version} stay local"
            exit 0
        fi

        git fetch "${remote_name}" --tags >/dev/null 2>&1

        if git ls-remote "${remote_name}" "refs/tags/${version}" 2>/dev/null | grep -q .; then
            if [ "$attempt" -ge 3 ]; then
                cliError "Failed to push commit and tag ${version}"
                printf '%s\n' "$push_output" | sed 's/^/    /' >&2
                exit 1
            fi
            recompute=$(bumpPatchVersion "${version}")
            cliWarning "Tag ${version} was taken concurrently - re-stamping as ${recompute}"
            git tag -d "${version}" >/dev/null 2>&1
            old_version="${version}"
            version="${recompute}"
        else
            git tag -d "${version}" >/dev/null 2>&1
            cliError "Failed to push ${current_branch} and the tag ${version}"
            printf '%s\n' "$push_output" | sed 's/^/    /' >&2
            exit 1
        fi

    done

}

if [ -z "$FLOW_REDIRECTED" ]; then
    cliFrameInit
fi
gitCommitPush "$@"
