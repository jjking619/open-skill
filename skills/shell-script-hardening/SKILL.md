---
name: shell-script-hardening
description: "Make install.sh and deployment scripts solid: idempotency, set -euo pipefail, quoting and error handling, diagnosable failures, and no false success. Use when writing or reviewing one-click install, deploy, or build scripts."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Shell Script Hardening (install.sh / deploy.sh)

Three goals: **re-running never breaks anything, failures explain themselves, success never lies**.

## When to Use

- Writing or modifying one-click install, deploy, or build scripts
- A script fails intermittently, breaks when re-run, or "looks successful but did nothing"
- Reviewing someone else's `install.sh` (pairs with the checklist in `github-repo-review-and-design`)
- Not for: one-off commands you type in a shell

## Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail          # fail on command error / unset variable / pipe failure
IFS=$'\n\t'
trap 'echo "[ERR] failed at line $LINENO" >&2' ERR
```

## Six Disciplines

**① Idempotency**
Probe before acting: `command -v git`, `[ -d "$dir" ]`, `dpkg -s pkg`. If already satisfied, print `[SKIP]` and move on.
Never append to config files twice; never reinstall the full dependency set on every run.

**② Quoting and arrays**
Quote every expansion: `"$var"`, `"${arr[@]}"`. Build command arguments as arrays instead of string concatenation plus `eval`.

**③ Temp files and cleanup**
`tmp="$(mktemp -d)"` plus `trap 'rm -rf "$tmp"' EXIT`. Never hardcode `/tmp/xxx` (concurrent runs collide).

**④ Failures must be diagnosable**
Print what each step does (`echo "[STEP] installing dependencies"`); send errors to stderr and exit non-zero; give the outer layer a message naming which step failed and how to retry.

**⑤ No dangerous defaults**
No `curl ... | sh`; guard `rm -rf` against empty variables (`[ -n "$dir" ]`); use `sudo` only when needed and say so; never silently rewrite system configuration.

**⑥ Success must self-verify**
At the end, verify **side effects** instead of printing a success banner: artifact exists, service is listening (`ss -ltn` / health check), `--version` output matches expectation.

## Two Self-checks (to catch "false success")

**① Never trust the script's own narration**
Redirecting a child process's output into a **nonexistent directory** (`> logs/x.log` when `logs/` doesn't exist) means the child **never starts** — yet the script happily prints "started / All done".
Before declaring success, verify side effects: artifact files, process liveness (is CPU time increasing?), log content actually written.

**② The non-interactive shell PATH trap**
When a script runs through `su -c`, `bash -lc`, or a single ssh command, the target user's `~/.bashrc` often doesn't apply (many distros early-return for non-interactive shells), so `python3` / `node` resolve to a different version → missing-dependency errors get misdiagnosed as a project problem.
To reproduce "the user running it in a terminal", export PATH explicitly (`export PATH="$HOME/.local/bin:$PATH"`) rather than relying on `-l`.

## Pitfalls

- **`set -e` is not airtight**: commands in `cmd || true`, command substitutions, and `if` conditions don't trigger it — check critical steps explicitly.
- **Pipes swallow failures**: `a | b` reports only the last command's status → add `set -o pipefail`.
- **Unquoted variables plus spaces**: `rm -rf $dir` is at its worst when `dir="a b"`.
- **Taking the script's word for it**: see the self-checks above.
- **Appending on every run**: grep for the block before writing into `~/.bashrc` or similar.

## Verification

- [ ] Run it twice: the second run is all `[SKIP]` or idempotent, with no duplicate side effects
- [ ] Force a step to fail: the script exits non-zero and names the failing step
- [ ] No unquoted expansions; no hardcoded temp paths; no `curl | sh`
- [ ] A side-effect check at the end, not just an echoed success message
