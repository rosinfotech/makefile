# ADR 0001: The single args input channel

- Status: accepted (2026-10-25);
- Scope: the command interface of the rosinfotech makefile framework and every repository built on it.

## Context

Command input reached the framework commands through three channels: a quoted positional string (MAKECMDGOALS), the FLOW_* environment variables (FLOW_YES, FLOW_RELEASE, FLOW_CLEAR) and - for consumers - the flags= make variable. The channels behaved differently under make, CI and bare script runs; environment overrides leaked across a whole shell session; typos in variable names were silently ignored; and the make "--" passthrough could not carry arguments with spaces, "=" or "$" (verified experimentally - make flattens goals into a space-joined string).

## Decision

- user input passes through a single channel: `make <command> ["<one positional>"] [args="<flags>"]`;
- the framework parser `cliParseArgs` (lib_cli.sh) owns the flag dictionary: `--yes`/`-y`, `--release`, `--defer`, `--force` (plus the internal `--redirected`);
- long `--kebab-case` forms are canonical; a single-letter short form exists only for high-frequency flags; an unknown flag fails with exit code 2;
- the exec bridge seal -> commit_push passes `--redirected` in argv - no environment transport between scripts;
- environment variables are not a command interface: only industry signals are read (NO_COLOR, CLICOLOR, TERM, TTY detection).

## Rejected alternatives

- the FLOW_* environment interface: hidden session state, silently ignored typos, no self-documentation - the reason the whole interface was replaced;
- the make `--` passthrough: quote grouping, "=" and "$" values do not survive make's goal model;
- the `flags=` variable name (the infra-era convention): renamed to `args=` - the variable carries arguments, not only flags; CMake's `make test ARGS=...` is the closest make-ecosystem precedent.

## Consequences

- consumers migrate `flags=` -> `args=` on the next `make vendor` run (infra migrated 2026-10-25);
- CI and agents repeat `args="--yes --release"` per invocation instead of one session-wide export - the accepted price for per-invocation determinism;
- the rule is fixed as the standards asset AGENTS-STANDARD-MAKE-ARGS.md and reaches all repositories through the AGENTS inclusions.
