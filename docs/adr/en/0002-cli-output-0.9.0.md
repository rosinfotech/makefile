# ADR 0002: The CLI output follows the 0.9.0 Output CLI Standard

- Status: accepted (2026-11-18);
- Scope: the output contract of the rosinfotech makefile framework commands and every repository built on it; supersedes the color-gate clause of ADR 0001.

## Context

The framework output predated the 0.9.0 redesign of the Output CLI Standard (the CLI Engineer role rules, standards commit 2429f745): errors, warnings and hints traveled stderr; message prefixes used a colon (`Error:`); headings carried `== x ==` / `-- x --` markers in bold; four header levels existed; the color decision mixed TTY detection with the NO_COLOR, CLICOLOR, CLICOLOR_FORCE and TERM=dumb gates; every hint needed an explicit blank from its call site. Moving everything to stdout (the "file mirrors the terminal" rule) exposed a trap: messages printed inside `$( )` command substitutions were captured into the values - `variant=$(flowRequireFlow)` swallowed its own error, the seal version prompt was invisible inside its capture.

## Decision

- every human block (headings, messages, hints, prompts, lists) travels fd 3, which duplicates stdout at source time: command substitutions inherit fd 3 but capture only stdout, so messages stay visible and captured values stay clean; plain data results (a version number, a catalog listing) stay on stdout;
- the message format is `TYPE. Text` - the closed prefix set Error / Warning / Success / Hint, the whole line in the semantic color, the text drops the trailing period (a hint keeps it); Information renders the Information color alone, without a prefix - the owner's choice against prefix noise, mirroring infra;
- the palette is closed and role based (Heading 1/2, Prompt, Information, Success, Warning, Error, Text, Hint), nothing prints in bold; the theme follows COLORFGBG when the terminal publishes it, Dark otherwise;
- headings are plain colored lines, two levels, no markers;
- color is emitted only when stdout is a TTY; the only overrides are the `--color` / `--no-color` flags - environment variables do not participate (supersedes the ADR 0001 clause "only industry signals are read (NO_COLOR, CLICOLOR, TERM, TTY detection)");
- prompts render in the prompt color with the `[Y/n]?` / `[y/N]?` shapes and the blank after the answer; an accepting confirmation in a non-TTY stream refuses with an Error message and exit code 2 (`--yes` bypasses); the refusing prompts take their safe default;
- every block prints its own trailing blank separator line; a list is dense items closed by one blank from the call site;
- PR and MR links render in the Information color (`cliLink`).

## Rejected alternatives

- keeping the NO_COLOR / CLICOLOR / TERM gates: the 0.9.0 standard makes the flags the only override; a silent environment switch fights the redirected-file contract (the file must mirror the terminal);
- an OSC 11 terminal-background probe for the theme: a bash `read` in canonical mode never delivers the reply (the driver buffers until a newline) and the stale bytes can corrupt a later prompt answer - COLORFGBG is the deterministic channel;
- OSC 8 clickable hyperlinks: the terminals in the field differ too much; a colored URL line is the portable subset;
- automatic capitalization of message texts (the infra cliCap approach): the framework messages legitimately open with literals (`curl`, `main`, branch names) that must keep their exact spelling.

## Consequences

- consumers pick the change up wholesale via `make vendor` (the vendored copy is fully managed);
- non-interactive pipelines that relied on the old silent auto-accept of confirmations must pass `args='--yes'` - the refusal is exit code 2 by design;
- the blank-discipline validator (.flow_test_logs/validate.py, local) checks the new message prefixes, dense lists and the CR normalization of pty captures;
- ADR 0001 keeps its input-channel decision untouched except the color-gate clause superseded here.
