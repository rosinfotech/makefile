# ADR 0003: The merge-request iteration commands

- Status: accepted (2026-11-21);
- Scope: the task/hotfix branch lifecycle of the rosinfotech makefile framework (variants #2-#5) and every repository built on it.

## Context

A merge request opened by git_flow_task_finish / git_flow_hotfix_finish usually survives a code review: the reviewer requests changes, the author adds commits to the same branch and the request updates. Before this decision the framework had no command for that leg: git_flow_task_finish refused on re-run ("already pushed - the merge request already exists"), and git_flow_commit_push - the variant #1 stamp command - dragged the whole version machinery onto the task branch when reused there (a y at its tag gate stamped a tag onto a task-branch commit, .version mutated on the branch, and the later seal hit "Tag already exists" re-stamp churn).

## Decision

- `git_flow_commit_push` differentiates the context:
  - a task/hotfix branch means merge-request iteration: validate the "<Type>: <message>" format, commit, push into the open request; without a message and a clean tree it degrades to a bare guarded push; no stamp machinery runs - the seal owns the version on every variant;
  - a gate branch (develop/staging/release/*) refuses: gates receive content through merge requests only;
  - main keeps the previous behavior (the variant #1 stamp or the deferred plain commit);
- `git_flow_push` is the standalone push of the same iteration (a clean tree required);
- both share flowTaskUpdatePush with a guard chain: the branch must already be published (finish/hotfix_finish own the initial publish), the sync is ff-only (divergence refuses), and the delivered check runs against the PUBLISHED tip origin/<branch> - when the request was squash-merged, the published commits are patch-equivalent to main or a gate, and later local commits must not resurrect a closed request but ride a new task.

## Rejected alternatives

- re-running git_flow_task_finish for updates: its duplicate guards exist to stop double delivery; widening them for updates would blur the publish/iterate boundary;
- teaching the delivered check against the local branch: new local commits look undelivered after a squash merge, quietly reopening dead requests;
- a dedicated "review fix" command family: the context differentiation keeps one command per intent (commit+push or push) instead of multiplying near-duplicates.

## Consequences

- the review loop is two commands in the task worktree (fragment + git_flow_commit_push) or three for a series (commits + git_flow_push); variant #2 re-runs git_flow_task_finish instead - its branch is never published, there is no open request to push into;
- variant #1 is unaffected: without task branches the iteration commands have nothing to iterate (git_flow_push refuses outside task/hotfix branches);
- git_flow_status documents the loop as the Review case and git_flow_help carries the Code review iterations section.
