<!-- markdownlint-disable MD041 -->

[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Changelog

## [0.3.0] - 2026-10-13

### Added

- the `git_flow_*` command family implementing the five Git Flow Standard variants: task cycles, review gates, promotion, hotfixes and version seals
- version sealing from changelog fragments: the tag on main as the version truth, atomic main+tag pushes, `.version` substitution with `path:N` selectors
- `git_flow_clear` branch hygiene: stale, remote-only and abandoned branches with their worktrees, offered for removal (default: no)
- `AGENTS.md` agent guide and README flow diagrams (Mermaid)

### Changed

- libraries renamed to the `lib_*` convention (`lib_cli`, `lib_git_flow`, `lib_version_get`, `lib_remove_dirs_safe`, `lib_ssh_client`, `lib_secrets`); command output unified on the Output CLI Standard
- `vendor.sh` template regenerates the full git_flow target set and vendors `.rsync-exclude`
- `skill-makefile-git-flow-ready` replaces `skill-makefile-create-commit-push`; `skill-makefile-version-update` describes the selectors and the report
- `echo` and `version_show` follow the Output CLI Standard

### Removed

- the legacy `git_commit`, `git_commit_push` and `git_commit_version` commands (use `git_flow_commit_push`)

## [0.2.5] - 2026-09-26

### Changed

- `echo` redesigned for the vendor workflow: all commands are local now, commands whose scripts come from `.makefile/vendor/rosinfotech/` are marked as `(vendored)` (the old global/local marking came from the removed link mechanism)
- targets renamed to match their scripts: `show_version` -> `version_show`, `update_version` -> `version_update`
- ai-skills directory renamed: `skill-makefile-update-version` -> `skill-makefile-version-update` (frontmatter names and cross-references updated)

### Added

- vendored Makefile block now includes the `echo` target and sets `.DEFAULT_GOAL := echo`; the framework `.version` is vendored so `echo` shows the framework version
- `vendor` upgrades an outdated vendored block to the current template on repeated runs (marker-scoped, backed up)
- `vendor` warns when legacy framework targets below the vendored block would override it

### Fixed

- `vendor` no longer copies `vendor.sh` itself into vendored projects: a vendored copy resolved wrong source paths and could wipe the vendor directory when run manually

## [0.2.4] - 2026-09-26

### Changed

- README: the AI Skills section now describes the skills as cross-agent `SKILL.md`-format agent skills (usable by any agent supporting the standard, referenced from `AGENTS.md`) instead of "Kilo skills"; the missing `skill-makefile-initialize-repository` entry added

<!-- markdownlint-disable MD024 -->

## [0.2.3] - 2026-09-26

### Added

- `vendor` command: makes an existing project independent from the globally linked makefile - prepends standalone definitions (`resolve_script`, `init`, framework targets) to the project Makefile, copies all framework scripts into the project `.makefile/` (never overwrites; Makefile backed up as `Makefile.bak.<timestamp>`), validates the result with the system make and is idempotent via a marker block
- `secrets.sh`: generic secrets access (SECRETS_FILE env override -> ~/.secrets.json, jq checks, getSecret/requireSecrets helpers; the schema is owned by the consumer)
- `ssh_client.sh` now carries the full SSH transport consolidated from the infra repository: sshClient (init/exec/execf/scp/rsync/download/cleanup), retry, key-or-password auth and the file/directory transfer helpers (sshFileUpload, sshDirectoryUpload, sshDirectoryDownload, sshDirectoryDownloadAsArchive)

### Changed

- `vendor` takes an optional path argument (`make vendor /path/to/project`), scaffolds an empty project (replaces clone_makefile for the no-link workflow), refreshes `.makefile/vendor/rosinfotech/` on repeated runs (update mode) and refuses to vendor the makefile repository itself; the vendor directory carries a README manifest with the source commit SHA
- `ai-skills/` moved to the repository root and is no longer vendored into projects (reference the skills by their GitHub URLs); `vendor` copies only the framework scripts
- `resolve_script` chain: local `.makefile/` -> `.makefile/vendor/rosinfotech/` -> global repository
- version scripts renamed: `get_version.sh` -> `version_get.sh`, `show_version.sh` -> `version_show.sh`, `update_version.sh` -> `version_update.sh` (targets keep their names); the lost `show_version` target restored

### Removed

- `local_deploy_remote.sh` (a project-specific rosinfo.tech deploy example) and the duplicate transport scripts `ssh_file_upload.sh`, `ssh_directory_upload.sh`, `ssh_directory_download_as_archive.sh`, `get_home_secret.sh` (superseded by the consolidated `ssh_client.sh` and `secrets.sh`); `link.sh`, `unlink.sh` and the `make` wrapper - the global-link workflow is gone, vendoring is the only installation path; `clone_makefile.sh` - superseded by the vendor scaffolding

## [0.2.2] - 2026-09-22

### Added

- SSH key authentication in `ssh_client.sh`: optional ssh key path argument for `sshClient init`, the key takes precedence over the password;

### Changed

- `ssh_directory_download_as_archive.sh` and `local_deploy_remote.sh` use the shared auth mechanism; `local_deploy_remote.sh` reads the optional ssh key from secrets;

## [0.2.1] - 2026-09-06

### Added

- Script `.makefile/ssh_directory_download_as_archive.sh` for downloading a remote directory via SSH as a `tar.gz` archive;

## [0.2.0] - 2026-08-19

### Added

- Combined local and global command search: with a local `Makefile` present, global commands stay available, while same-named local targets and local `.makefile` scripts take precedence;
- `echo` command: greets the user, shows global and local project versions, lists available commands marked as global or local (colored output);

### Changed

- `clone_makefile` now generates a thin local `Makefile` instead of copying the global one;

## [0.1.7] - 2026-05-28

### Added

- Skill `skill-makefile-initialize-repository` for initializing a repository managed by the makefile project;

## [0.1.6] - 2026-05-01

### Changed

- Moved AI skills from `.makefile/skill-*` to `.makefile/ai-skills/skill-makefile-*` with Russian localization support;

## [0.1.5] - 2026-04-26

### Changed

- Updated English version of `skill-makefile-update-version` to match Russian version with details on `make update_version` behavior and manual fallback;

## [0.1.4] - 2026-04-26

### Added

- Skill `skill-makefile-update-version` for updating project version;

### Changed

- Skill `skill-makefile-create-commit-push` now delegates version updating to `skill-makefile-update-version`;

## [0.1.3] - 2026-04-26

### Added

- Skill `skill-makefile-create-commit-push` for creating commits and pushing with makefile;

## [0.1.2] - 2026-04-25

### Fixed

- Executing rights for .makefile/make;

## [0.1.1] - 2026-04-24

### Fixed

- Minor inaccuracies in the README.md file;

## [0.1.0] - 2026-04-24

### Release

- Global launch (linking/unlinking), cloning;

## [0.0.13] - 2026-01-17

### Fixed

- Get rid of extra commands;

## [0.0.12] - 2026-01-17

### Added

- Commands:

  - `clear`;
  - `git_commit_version`;
  - `git_commit`;
  - `kill_processes`;

## [0.0.11] - 2026-01-04

### Updated

- ssh_client command;

## [0.0.10] - 2026-01-03

### Updated

- git_commit_push command;

## [0.0.9] - 2025-12-26

### Fixed

- update_version command;
