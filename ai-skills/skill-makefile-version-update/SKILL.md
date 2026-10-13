---
name: skill-makefile-version-update
description: Updating the version of a project managed by makefile
---

## Steps

- A makefile-managed project contains a `.version` file in the project root that controls the project version;

- When the project is under a declared git flow (the `.git_flow/` marker), the flow stamps the version itself: `make git_flow_commit_push` or `make git_flow_seal` update `.version` and substitute the version into the target files automatically - the manual algorithm below applies only on an explicit user request or in projects without a git flow;

- Structure of the `.version` file:

  - Line 1 — the currently committed semver of the project;
  - Line 2 — the version to be set for the upcoming commit;
  - Subsequent lines — relative paths to files where the committed version should be replaced with the new one:

    - Entry format: `path/to/file` — replace in the whole file, or `path/to/file:N` — replace only on line N (when the version literal lives on a known line);
    - The replacement matches the version literal exactly at word boundaries: `0.30.1` is not replaced inside `0.30.10`;
    - If there are no such files, the version is only declared in this file;

- If `.version` has not changed since the last commit and line 1 matches line 2, while other changes have been made to the project, the version is outdated;

- To update the project version:

  - If the user did not specify a version, increment the patch version:

    - Edit line 2 of `.version` directly;
    - Run `make version_update` to update the version in `.version`;

      - `make` commands must be run from the project root by the AI agent in the terminal;

      - `make version_update` does the following:

        - When lines 1 and 2 already match — reports `Information: version already up to date` and changes nothing;
        - Otherwise substitutes the new version into the target files (entries from line 3 on, honoring the `:N` selectors) and prints a report: the list of substituted locations (`path:N`) and the number of substitutions;
        - When the old version has no occurrences in the target files — reports `Information: no occurrences ... nothing to substitute`, while line 1 of `.version` still becomes equal to line 2;
        - After the substitution it copies the value from line 2 to line 1: both lines contain the new version;

      - If `make version_update` is unavailable (no Makefile), perform the same action manually: copy the value from line 2 to line 1 and replace the version (at word boundaries) in the specified files, honoring the `:N` selectors;

    - After running `make version_update`, verify that `.version` was updated and lines 1 and 2 match;

  - If the user specified a concrete version, follow the same steps but set the requested version instead of incrementing.
