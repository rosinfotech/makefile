---
name: skill-makefile-git-flow-ready
description: Formulates a git_flow action plan for promoting the made changes to a fully formed commit and a production version
---

## Triggers

- The user explicitly asks to prepare a commit: "prepare commit", "prepare a commit", "get the commit ready", "подготовить коммит", "подготовь коммит", "оформи коммит" and close phrasings;
- Without an explicit user request the skill does not activate;

## Principle

- The skill never prescribes the LLM to perform commits, pushes, merges or tags - those always stay with the user;
- The exclusive outcome of the skill is formulated instructions (a plan of commands and platform steps) depending on the situation and the repository status;
- Every command of the plan is executed by the user personally;

## Actions allowed to the agent

The agent may apply two kinds of proposed changes itself - but only when the current git flow and its current status do not contradict them:

1. Version file change: set the proposed future version into line 2 of `.version` and run `make version_update` (substitution into the target files + copying line 2 to line 1);
2. Changelog change: add the proposed section to `CHANGELOG.md` (version, date, typed lines);

Non-contradiction conditions (all must hold simultaneously):

- The repository is set up for git flow: the `.git_flow/.git-flow-*` marker is present and declares variant 1. Without a declared flow the repository is not ready yet - edits are forbidden and the agent recommends them as plan steps (including `make git_flow_init`); under variants 2-5 the version and the changelog belong to the seal and the fragments - manual edits contradict the flow and are forbidden (the agent proposes fragment commands instead);
- The proposed version is a valid semver, strictly greater than the current line 1 of `.version`;
- A section with the proposed version does not yet exist in `CHANGELOG.md`;
- No unconsumed fragments and no unfinished seal (the status per `make git_flow_status`);
- The working branch is main; on task/hotfix branches and gate branches the version and changelog files do not belong to the agent;

When any condition breaks, the agent only formulates instructions and the user applies the edits.

## Steps

1. Determine the repository state (read-only, no mutating commands):

  - The flow variant - from the `.git_flow/.git-flow-*` marker in the project root;
  - The current branch: main / task-* / hotfix-* / staging / release/*;
  - Whether the tree is dirty (`git status --porcelain`);
  - Whether changelog fragments exist (`.git_flow/changelog_fragments/`);
  - Unpushed commits, open merge requests, the tag vs `.version` relation;
  - Running `make git_flow_status` and `make git_flow_help` is allowed - they are safe (read-only);

2. Analyze the made changes and propose the changelog entries:

  - Sources: `git status --porcelain`, `git diff` (and `git diff --staged`), the current branch's unpushed commits (`git log @{u}..HEAD --oneline` when an upstream exists);
  - Understand the meaning of the changes, do not enumerate files: what new capability the code gains, what is fixed, what is removed;
  - Propose one or more fragment lines to the user in the `<Type>: <one English line>` format (types: Added, Changed, Fixed, Deprecated, Removed, Security):

    - Every line in English, as brief as possible, reflecting the change from the project user's perspective, not the implementation;
    - The most significant change goes first: the senior line becomes the MR title and the basis of the commit message;
    - One semantic change - one line; mechanical noise (formatting, temporary files) never enters the fragments;

  - When a fragment for the task already exists - compare it with the diffs: propose adding (a new line via the same command appends to the existing fragment) or keeping it as is;
  - Include the ready commands into the plan: `make git_flow_task_fragment "<Type>: <line>"` - the user just pastes them;

3. Formulate the further action plan for the phase the repository is in. The plan is a numbered list of exact commands for the user to enter, plus platform steps (merging the MR). The user runs the commands personally!

  Possible phases and plans:

  - No flow declared: the agent applies nothing itself; suggest `make git_flow_init <1..5>` (help choose the variant), then the chosen variant's plan; include the `.version` and `CHANGELOG.md` edits as user steps of the plan (the ready section text + setting the future version, e.g. via the skill-makefile-version-update skill);

  - Variant 1, changes on main: `make git_flow_commit_push "<Type>: <message>"`; answer y at the `Tag now?` prompt - the version, the tag and the push go atomically (the tag = the production release); the commit message is built from the senior proposed changelog line; when the "Actions allowed to the agent" conditions hold, the agent itself sets the future version in `.version` and adds the `CHANGELOG.md` section;

  - On a task branch with a dirty tree: first `make git_flow_commit "<Type>: <message>"`;
  - On a task branch without a fragment: `make git_flow_task_fragment "<Type>: <one English line>"` with the lines proposed at step 2 - the fragment becomes a CHANGELOG line and the MR title;
  - Then per variant:
    - Variant 2: `make git_flow_task_finish` (squash into main) -> `make git_flow_seal`;
    - Variant 3: `make git_flow_task_merge_develop` -> `make git_flow_task_finish` -> merge the MR into main (squash) -> `make git_flow_seal`;
    - Variant 4: `make git_flow_task_merge_develop` -> `make git_flow_task_finish` -> merge the MR into staging (squash) -> `make git_flow_promote` -> merge the staging -> main MR (squash) -> `make git_flow_seal`;
    - Variant 5: `make git_flow_task_merge_develop` -> `make git_flow_task_finish` -> merge the MR into the release/x.y train (squash) -> `make git_flow_promote` -> merge the train -> main MR (squash) -> `make git_flow_seal` (stamps x.y.0 and bumps the train);
  - On a hotfix branch (variants 4-5): the fragment is mandatory - `make git_flow_task_fragment "Fixed: <one English line>"` -> `make git_flow_commit "Fixed: <message>"` -> `make git_flow_hotfix_finish` -> merge the MR into main (squash) -> `make git_flow_seal`;
  - An open MR awaits merging: merge it (squash) on the platform -> `make git_flow_seal`;
  - On main with unconsumed fragments: `make git_flow_seal`;
  - On main, everything stamped: report that there is nothing to promote - the tag on main matches `.version`;

4. Plan requirements:

  - Every command with its path (task work starts with `cd ../<project>-task-<label>`, the seal always runs from the project root);
  - Mark platform steps (MR merges) explicitly: "manually on GitHub";
  - State the expected outcome of the plan: tag vX.Y.Z on main, gates synced, the CHANGELOG assembled from the fragments (including the lines proposed at step 2);
  - Never put the version into commit messages - the seal stamps it automatically;
  - Never edit CHANGELOG.md under variants 2-5 - `make git_flow_seal` assembles the section from the fragments; under variant 1 and without a flow the "Actions allowed to the agent" section applies;

5. Before finishing the plan, offer to reflect the changes in README.md when it has not changed since the last commit (updated in its original language, riding the same task commits); the README edits are made by the user - or by the agent, but only on a separate explicit user request, outside this skill;

6. ADR and runbook assessment - based on the change analysis (step 2), judge their necessity:

  - An ADR (`docs/adr/[lang_code]/*`) - the change embodies an architectural decision:
    - a new dependency or a technology choice;
    - a shift of service boundaries or the data model;
    - a rejected alternative worth recording;
  - A runbook (`docs/runbooks/[lang_code]/*`) - the change introduces or alters an operational procedure:
    - deployment, migration, rollback;
    - incident recovery;
  - The degree of necessity is determined as follows:
    - at the agent's discretion - propose the document with a one-line justification;
    - by a direct user instruction - the document is drafted unconditionally;
  - When warranted, formulate the document text and include its creation as a plan step:
    - follow the naming, numbering and format of the existing documents of the target directory;
    - the language matches the existing documents of the target directory;
    - an empty or absent directory - the language of the project README;
    - the document rides the same task commits;
  - The file edits follow the README rule of step 5: applied by the user, or by the agent;
  - A direct user instruction for the document is an explicit request for the agent;
  - When not warranted, state briefly in the finale that no ADR or runbook is needed;

7. Finale: hand the plan to the user as a single summary - from the current state to the tag on main. The user runs the commands personally.
