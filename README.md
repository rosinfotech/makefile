[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Rosinfotech Makefile

## Predefined make commands

### `make git_commit_push`

Performs a git commit, push and push --tags with the specified commit message and version.

```bash
make git_commit_push "your commit message"
```

### `make sync_version`

Synchronizes project version values. Runs the `scripts/sync_version.sh` script. The script reads the new version value from the 2nd line of the `./.version` file. The `.version` file also contains the current version (line 1) and relative file paths where the current version should be changed.

```bash
make sync_version
```

## Additional scripts

- `scripts/setup.sh`, `scripts/ssh_client.sh`, `scripts/ssh_directory_upload.sh`, `scripts/ssh_file_upload.sh` - allow you to write deployment scripts like `scripts/local_deploy_remote.sh`

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
