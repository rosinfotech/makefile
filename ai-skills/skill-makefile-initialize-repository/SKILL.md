---
name: skill-makefile-initialize-repository
description: Initializing a repository managed by the makefile project
---

## Steps

1. Check the current state of the repository:

   - Verify that the project root exists and is a git repository;
   - If it is not a git repository, abort and notify the user;

2. Create the `.version` file in the project root:

   - Line 1 — initial version (e.g. `0.0.1`);
   - Line 2 — same as line 1 (both lines must match);
   - If the user specified a different initial version, use that instead;

3. Create `CHANGELOG.md` in the project root:

   - Standard header `# Changelog`;
   - First entry with the initial version and current date in YYYY-MM-DD format (e.g. `## [0.0.1] - 2026-05-12`);;
   - Under the `### Added` subheading — a brief description of the initialization (e.g. `- Initialization`);
   - CHANGELOG.md entries must be in English;

4. Create `README.md` in the project root:

   - Only a heading with the project name (directory basename);
   - Ask the user if they want additional content (description, usage, etc.);
   - If the user confirms, supplement the file in the same language it was started in;

5. Suggest the user run the commit via the `skill-makefile-create-commit-push` skill with message `Initialization`.
