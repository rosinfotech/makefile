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
    - Run `make update-version` to update the version in `.version`;

      - `make` commands must be run from the project root;

    - After running `make update-version`, verify that lines 1 and 2 of `.version` match;

  - If the user specified a concrete version, follow the same steps but set the requested version instead of incrementing.
