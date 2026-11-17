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

- `lib_cli.sh` — the Output CLI Standard primitives (the CLI Engineer role
  rules, 0.9.0): `cliError`, `cliWarning`, `cliSuccess`, `cliInfo`,
  `cliHint`, the two heading levels (`cliHeader1`/`cliHeader2`), `cliText`,
  `cliPath`, `cliItem`/`cliItemNum`, the prompt primitives (`cliConfirm`,
  `cliConfirmNo`, `cliAsk`), the flags-only color gating (`--color`/
  `--no-color` over the TTY baseline) with the dark/light role palette,
  and `cliParseArgs`. Every human block travels fd 3, which duplicates
  stdout at source time - command substitutions inherit fd 3 but capture
  only stdout, so messages printed inside `$( )` helpers stay visible and
  the captured values stay clean; plain data results (a version number, a
  catalog listing) stay on stdout. Every block (heading, message, hint,
  prompt) prints its own trailing blank separator line - a list is closed
  by one blank from the call site; messages follow the `TYPE. Text` format
  (the message drops the trailing period, a hint keeps it).
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
  `args="--force"` forces. Dirty worktrees, unmerged content and checked-out
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

## Interactive prompts and command input (args)

Prompts render in the prompt color, print to stdout and take the blank
line after the answer; the shapes are `[Y/n]?` (an empty answer accepts)
and `[y/N]?` (an empty answer refuses). An accepting confirmation in a
non-TTY stream is refused with an `Error.` message and exit code 2 - rerun
with `args="--yes"`; the refusing prompts take their safe default.

- input reaches a command through a single channel: `make <command> ["<one positional>"] [args="<flags>"]`;
- long `--kebab-case` flags are canonical, a single-letter short form only for high-frequency flags, an unknown flag fails with exit code 2;
- `args="--release"` / `args="--defer"` — forces/defers the seal tag gate (non-TTY defers);
- `args="--yes"` (or `-y`) — accepts the confirm-style prompts (agents, pipelines);
- `args="--force"` — forces `git_flow_clear` removal;
- `args="--color"` / `args="--no-color"` — forces the color on (even into a pipe) or off; environment variables do not participate in the color decision - color is emitted only when stdout is a TTY, and only these flags override it.

## Output CLI standard and exit codes

Every command follows the Output CLI Standard: everything the command
prints - the result, special messages, hints, prompts, prompt refusals -
goes to stdout; the redirected file tells the same story as the terminal,
only without the color. Blocks: a heading is a plain colored line (two
levels, no markers, no bold); exactly one blank separator line follows
every block, including the last; no two consecutive blank lines. The
closed message prefixes are `Error.`, `Warning.`, `Success.`, `Hint.`;
Information renders the Information color alone, without a prefix (the
owner's choice against prefix noise, mirroring infra). Exit codes: 0
success, 1 runtime failure, 2 usage error — through make a failed recipe
surfaces as make's exit 2 with `make: *** [target] Error N` (N is the
script's code).

Validation: `.flow_test_logs/validate.py` checks the blank discipline of a
captured log (messages, dense lists, trailing blank, no double blanks; a
make diagnostic may end the file when preceded by a blank; CR line endings
from a pty capture are normalized).

## Testing changes

The full matrix lives in `.flow_test_logs/full_run.sh <prefix>` (requires
the test repository): V1-V5 positive cycles, both hotfix cycles with
fragments, the negative paths (blocked commands, bad fragment type, bad
commit message, the fragment guard, duplicate finishes, dirty tree), plus
post-condition assertions (branch topology, trains, worktrees, open PRs).
A passing run prints `ALL CLEAN`; three consecutive clean runs are the
acceptance bar for a release.
