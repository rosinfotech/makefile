# AGENTS.md — the makefile framework agent guide

This repository is the source of the vendored makefile framework. Agents
working here or in consumer projects need two mental models: the command
family in `.makefile/` and the Git Flow Standard implemented by the
`git_flow_*` commands. Everything below applies to the framework repo and to
any project that vendored it (`.makefile/vendor/rosinfotech/`).

## Repository layout

- `.makefile/` — the framework itself: libraries (`lib_*.sh`), commands
  (the rest), the vendor installer (`vendor.sh`, never vendored itself);
- `Makefile` — the root wrapper: every command below is a make target;
- `ai-skills/` — cross-agent SKILL.md workflows (commit/push, repository
  initialization, version update);
- `CHANGELOG.md`, `.version` — the framework's own versioning (the framework
  eats its own dog food).

## Libraries vs commands

Only `lib_*.sh` files are sourced by other scripts; everything else is a
command with a make target:

- `lib_cli.sh` — the Output CLI Standard primitives: `cliError`,
  `cliWarning`, `cliSuccess`, `cliInfo`, `cliHint`, headers, `cliPath`,
  the color-gating chain, frames. Message helpers print their own trailing
  blank line; a hint group is closed by an explicit `printf '\n' >&2` at the
  call site.
- `lib_git_flow.sh` — the flow engine: marker detection, variant gates,
  branch/worktree helpers, gates sync, version resolution and substitution,
  GitHub integration, merged-branch detection. Sourced by every
  `git_flow_*` command plus `version_show.sh` and `version_update.sh`.
- `lib_version_get.sh` — semver helpers and `getVersion()` (tag-first
  resolution); sources `lib_cli.sh`.
- `lib_remove_dirs_safe.sh` — safe directory removal, sourced by `clear.sh`.
- `lib_ssh_client.sh`, `lib_secrets.sh` — transport and secrets access for
  consumer projects (nothing inside this repo sources them; external
  contract).

A change in `lib_git_flow.sh` affects all 17 consumers and requires the full
test matrix; a change in `lib_cli.sh` affects every command's output.

## Command reference

Run every command from the project root through make: `make <target>`.

### General

- `make echo` — greeting: framework version, project version, the command
  list (vendored commands marked);
- `make clear` — project cleanup (sources `kill_processes.sh` and
  `lib_remove_dirs_safe.sh`; careful: it kills processes and removes
  directories);
- `make setup` — installs system prerequisites (sshpass, rsync);
- `make vendor [path]` — makes the target project independent: refreshes
  `.makefile/vendor/rosinfotech/` wholesale and upgrades the standalone
  Makefile block (marker-guarded). Only runs from a clone of this
  repository;
- `make version_show` — the version truth: latest tag, `.version` lines,
  the resolved next stamp;
- `make version_update` — applies `.version` line 2: substitutes the old
  version into the target files (lines 3+, `path` or `path:N` selectors,
  word-boundary match), then copies line 2 to line 1. Reports every
  substituted location; no-op with `Information: version already up to date`
  when the lines already match.

### Flow lifecycle

- `make git_flow_init <1..5>` — declares the variant: writes the
  `.git_flow/.git-flow-*` marker (fetched from the standards repository),
  commits it to main, creates/refreshes the branch skeleton. Stale gate
  branches (develop/staging/trains) that are fully promoted are reset to
  main automatically;
- `make git_flow_status` — the declaration, branch topology, version truth,
  fragments, per-variant command availability, findings;
- `make git_flow_help` — the step sequence for the current context,
  including the suggested next step.

### Task cycle (variants 2-5)

- `make git_flow_task_start <label>` — forks a task branch
  `task-<UTLBL>-<label>` into a dedicated worktree `../<project>-task-...`
  from the variant's fork base (main / staging / the release train);
- `make git_flow_task_fragment "<Type>: <one English line>"` — appends the
  changelog fragment `.git_flow/changelog_fragments/<UTLBL>.<type>.md`;
  types: added, changed, fixed, deprecated, removed, security;
- `make git_flow_commit "<Type>: <message>"` — `git add .` + commit; on
  task/hotfix branches the message must follow `<Type>: <message>`
  (exit 2 otherwise);
- `make git_flow_task_merge_develop` — free merge of the task into develop
  (variants 3-5), no gate; aborts and restores on conflict;
- `make git_flow_task_finish` —
  - variant 2: squash-merges the task into main directly and pushes;
  - variants 3-5: pushes the branch and opens a merge request into the
    variant's gate (main / staging / the train) via the GitHub API, falling
    back to a compare URL without a PAT.
  Guards: refuses when the task is already delivered ("already in its
  merge-request target") or already pushed with an open MR ("already
  pushed - the merge request already exists").

### Promotion and the seal

- `make git_flow_promote` — opens the gate -> main merge request (staging
  -> main, or the train -> main);
- `make git_flow_seal` — the sole versioning act. On main (switches the
  repository worktree itself when run elsewhere):
  1. assembles the changelog section from the fragments;
  2. resolves the version (tag floor; `.version` intent; prompt allows an
     override), writes `.version`, substitutes the old version in the
     target files;
  3. commits, tags and pushes main + tag atomically (retry with a
     re-stamp when the tag is taken concurrently);
  4. offers GitHub release notes;
  5. syncs the gates (develop, staging, trains) from main — resets fully
     promoted ones, merges the rest, bumps shipped trains;
  6. offers to remove the merged task/hotfix branches with their worktrees.
  Without fragments and with `.version` line 1 equal to the latest tag it
  degrades to a sync-only run. Variant 1 redirects to
  `git_flow_commit_push`.

### Hotfix (variants 4-5)

- `make git_flow_hotfix_start <label>` — forks `hotfix-<UTLBL>-<label>`
  from main into a worktree (bypasses the queue);
- the fix requires a changelog fragment (`task_fragment "Fixed: ..."`,
  enforced by `hotfix_finish`);
- `make git_flow_hotfix_finish` — pushes and opens the hotfix -> main MR;
  same duplicate guards as the task finish. The seal then back-merges main
  into the gates.

### Hygiene

- `make git_flow_clear` — scans local and remote task/hotfix branches and
  flow branches unused by the declared variant; offers removal of: fully
  delivered branches (worktree + local + remote), remote-only copies,
  abandoned ones (main was stamped after their fork point), superseded
  trains. The prompt defaults to NO; non-interactive runs report only;
  `FLOW_CLEAR=1` forces. Dirty worktrees, unmerged content and checked-out
  branches are never offered.

## The five flow variants

| # | Name | Fork base | Path to main |
|---|------|-----------|--------------|
| 1 | Direct to Main (Trunk-Based) | main | direct commit |
| 2 | Free Merge to Main (GitHub Flow) | main | task_finish squashes into main |
| 3 | Reviewed Merge to Main (Git Flow Lite) | main | task -> develop, MR -> main |
| 4 | Reviewed Merge to Staging (GitLab Flow Lite) | staging | task -> develop, MR -> staging, promote -> main |
| 5 | Reviewed Merge to Release to Main (Git Flow) | release/x.y | task -> develop, MR -> train, promote -> main; entering main stamps x.y.0 |

See the README for the diagrams.

## Versioning model

- The tag on main is the version truth (`git describe --tags --abbrev=0`);
- `.version`: line 1 — current, line 2 — future intent, lines 3+ —
  substitution targets (`path` or `path:N`), replaced at word boundaries;
- every version is created by exactly one of: `git_flow_commit_push`
  (variant 1, standalone projects) or `git_flow_seal` (variants 2-5);
- fragments ride the gate branches unconsumed; the seal consumes them.

## Interactive prompts and environment overrides

Prompts are cyan, never bold; the blank line after an answer belongs to the
prompt helper. Defaults: `[y/N]` refuses, `[Y/n]` accepts.

- `FLOW_RELEASE=1|0` — forces/defers the seal tag gate (non-TTY defers);
- `FLOW_YES=1` — accepts the confirm-style prompts (agents, pipelines);
- `FLOW_CLEAR=1` — forces `git_flow_clear` removal.

## Output CLI standard and exit codes

Every command follows the Output CLI Standard: stdout carries the result,
stderr carries errors/warnings/hints; messages auto-blank after themselves;
lists are dense (`- item;`), one blank after the list; no two consecutive
blank lines; the TTY output is framed. Exit codes: 0 success, 1 runtime
failure, 2 usage error — through make a failed recipe surfaces as make's
exit 2 with `make: *** [target] Error N` (N is the script's code).

Validation: `.flow_test_logs/validate.py` and `validate.sh` check the blank
discipline of a captured log (headers, messages, dense lists, trailing
blank; a make diagnostic may end the file when preceded by a blank).

## Testing changes

The full matrix lives in `.flow_test_logs/full_run.sh <prefix>` (requires
the test repository): V1-V5 positive cycles, both hotfix cycles with
fragments, the negative paths (blocked commands, bad fragment type, bad
commit message, the fragment guard, duplicate finishes, dirty tree), plus
post-condition assertions (branch topology, trains, worktrees, open PRs).
A passing run prints `ALL CLEAN`; three consecutive clean runs are the
acceptance bar for a release.
