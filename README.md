<!-- markdownlint-disable MD041 -->

[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Rosinfotech Makefile

## Quick start

### Cloning

Clone the project and run following commands inside directory context:

### Setup

Makes available work with SSH files/directories transferring and other:

```bash
make setup
```

### Vendoring (project independence)

Makes a project independent from this repository - the only installation
path (the global-link workflow is gone):

```bash
make vendor /path/to/project     # from a clone of this repository
```

What it does:

- copies the framework into `.makefile/vendor/rosinfotech/` (fully managed
  directory, replaced wholesale on every run; a README manifest inside
  records the source commit SHA and update instructions);
- prepends standalone definitions to the project Makefile on the first run
  (marker-guarded; the original is backed up as `Makefile.bak.<timestamp>`;
  repeated runs only refresh the vendor directory);
- when the target has no Makefile, scaffolds a minimal project
  (`.version`, `CHANGELOG.md`, `README.md`, `.editorconfig`) - this
  scaffolds the project files when the target has no Makefile;
- validates the result with the system make and rolls back on failure.

Project scripts in `.makefile/` are never touched and take precedence over
the vendored ones (`resolve_script` chain: `.makefile/` ->
`.makefile/vendor/rosinfotech/`). After vendoring the plain system `make`
runs the project everywhere - no clone of this repository is required on
the machines using the project. Update the framework with `git pull` in a
clone of this repository followed by `make vendor /path/to/project`.

## Predefined make commands

### `make git_commit_push`

Performs a git commit, push and push --tags with the specified commit message and version.

```bash
make git_commit_push "your commit message"
```

### `make echo`

Greets the user, shows the current version and lists available commands marking them as global or local:

```bash
make echo
```

### `make update_version`

Synchronizes project version values. Runs the `.makefile/version_update.sh` script. The script reads the new version value from the 2nd line of the `./.version` file. The `.version` file also contains the current version (line 1) and relative file paths where the current version should be changed.

```bash
make update_version
```

## Additional .makefile

- `.makefile/ssh_client.sh` - the shared SSH transport: `sshClient` (init/exec/execf/scp/rsync/download/cleanup) plus the file/directory transfer helpers (`sshFileUpload`, `sshDirectoryUpload`, `sshDirectoryDownload`, `sshDirectoryDownloadAsArchive`). Auth: password via sshpass or an ssh key (the key takes precedence). Pure transport - no server registry and no logging; consumers layer their own on top (see the infra repository for the server-registry pattern).

- `.makefile/secrets.sh` - generic secrets access: resolves the secrets file (`SECRETS_FILE` env override -> `~/.secrets.json`), checks jq and provides `getSecret <jq-path>`, `secretFile`, `requireSecrets`. The schema inside the file is owned by the consumer.

- `.makefile/setup.sh` - installs the system prerequisites (sshpass, rsync);

- You should create a `$HOME/.secrets.json` file to store and manage secrets (schema is owned by the consumer; `SECRETS_FILE` env var overrides the path):

  ```json
  {
      "example": {
          "ssh": {
              "host": "host",
              "port": "port",
              "username": "username",
              "password": "password",
              "ssh": "~/.ssh/id_ed25519"
          }
      }
  }
  ```

  The `ssh` field is optional: it points to a local private key — when set and the file exists, key authentication is used instead of the password (accepted as an optional `sshClient init` argument as well).

## AI Skills

Agent skills in the cross-agent `SKILL.md` format (any agent that supports the standard can use them - Kilo, Claude Code and others; typically referenced by their GitHub URLs from an `AGENTS.md` instructions file):

- `ai-skills/skill-makefile-create-commit-push/` - commit and push following the makefile workflow (github.com/rosinfotech/makefile/tree/main/ai-skills);

- `ai-skills/skill-makefile-initialize-repository/` - initialize a git repository for the makefile workflow;

- `ai-skills/skill-makefile-update-version/` - update the project version (.version, CHANGELOG.md);
