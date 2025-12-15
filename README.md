[![rosinfo.tech](https://cdn.rosinfo.tech/id/logo/id_logo_width_160.svg "rosinfo.tech")](https://rosinfo.tech)

# Rosinfotech Makefile

- Set of useful Makefile commands:

## Commands

### `make git_commit_push`

Perform git commit and push with the specified commit message.

```bash
make git_commit_push "your commit message"
```

### `make sync_version`

Synchronize project version. Runs the `scripts/sync_version.sh` script.

```bash
make sync_version
```

### `make test`

Run project tests via the `scripts/test.sh` script.

```bash
make test
```
