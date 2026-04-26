---
name: skill-makefile-create-commit-push
description: Creating a commit and pushing with the makefile project
---

## Steps

1. Check the project version via the `.version` file:

   - The file must be located in the project root;
   - If it hasn't changed since the last commit, the version needs to be updated (see below);

1.1. Review changes to be committed:

   - Changes include modified, new (untracked), and deleted files;
   - If there are no changes, notify the user and stop;

2. Accept a task from the user specifying which version to commit and push:

   - The version must be updated following the skill `.makefile/skill-makefile-update-version/SKILL.md`;

3. Add an entry to `CHANGELOG.md`:

   - New entry goes at the top of the file;
   - Include the commit date in YYYY-MM-DD format;
   - Include the version from step 2;
   - Use subheadings: Added, Changed, Fixed, Deprecated, Removed, Security;
   - List changes under each subheading as briefly as possible;
   - Put the most significant change first — it will be used for the commit message;
   - CHANGELOG.md entries must be in English;

4. If `README.md` hasn't changed since the last commit, offer to update it:

   - If the user confirms, update it in the same language it was originally written in;

5. Finally, suggest the command `make git_commit_push "<message>"`, where `<message>` is the commit message:

   - Keep it short and reflect the most significant change (the first one in CHANGELOG.md);

   - It must start with a verb matching the main subheading from CHANGELOG.md, e.g. Added, Changed, Fixed, Deprecated, Removed, or Security:

     - Followed by a colon and a short description starting with a capital letter, e.g. `Added: Support for new API endpoint`;
     - While CHANGELOG.md may contain more detailed descriptions, the commit message should be as concise as possible since it appears in commit history and must be easy to read;

   - Do not include the version in the message — it is added automatically;

5.1. The user must run this command themselves!
