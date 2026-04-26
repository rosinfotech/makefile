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

### Global launch

Makes available commands inside any context directory:

```bash
make link
```

### Canceling global launch

```bash
make unlink
```

### Cloning Makefile

Makes the Makefile part of your project - independent commands launch:

```bash
make clone_makefile
```

## Predefined make commands

### `make git_commit_push`

Performs a git commit, push and push --tags with the specified commit message and version.

```bash
make git_commit_push "your commit message"
```

### `make update_version`

Synchronizes project version values. Runs the `.makefile/update_version.sh` script. The script reads the new version value from the 2nd line of the `./.version` file. The `.version` file also contains the current version (line 1) and relative file paths where the current version should be changed.

```bash
make update_version
```

## Additional .makefile

- `.makefile/setup.sh`, `.makefile/ssh_client.sh`, `.makefile/ssh_directory_upload.sh`, `.makefile/ssh_file_upload.sh` - allow you to write deployment .makefile like `.makefile/local_deploy_remote.sh`

- `.makefile/skill-makefile-create-commit-push/` - Kilo skill for creating commits and pushing with makefile

- You should create a `$HOME/.secrets.json` file to store and manage secrets:

  ```json
  {
      "tech": {
          "rosinfo": {
              "ssh": {
                  "host": "host",
                  "port": "port",
                  "username": "username",
                  "password": "password"
              }
          }
      }
  }
  ```
