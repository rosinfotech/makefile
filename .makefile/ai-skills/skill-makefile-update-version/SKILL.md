---
name: skill-makefile-update-version
description: Updating the version of a project managed by makefile
---

## Steps

- A makefile-managed project contains a `.version` file in the project root that controls the project version;

- Structure of the `.version` file:

  - Line 1 — the currently committed semver of the project;
  - Line 2 — the version to be set for the upcoming commit;
  - Subsequent lines — relative paths to files where the committed version should be replaced with the new one;

    - If there are no such files, the version is only declared in this file;

- If `.version` has not changed since the last commit and line 1 matches line 2, while other changes have been made to the project, the version is outdated;

- To update the project version:

  - If the user did not specify a version, increment the patch version:

    - Edit line 2 of `.version` directly;
    - Run `make update_version` to update the version in `.version`;

      - `make` commands must be run from the project root by the AI agent in the terminal;

      - `make update_version` copies the value from line 2 to line 1, after which both lines contain the new version:

        - If file paths are specified in `.version` (starting from line 3), the old version is also replaced with the new one in those files;

      - If `make update_version` is unavailable (no Makefile), perform the same action manually: copy the value from line 2 to line 1 and replace the version in the specified files;

    - After running `make update_version`, verify that `.version` was updated and lines 1 and 2 match;

  - If the user specified a concrete version, follow the same steps but set the requested version instead of incrementing.
