---
name: project-reproduction
description: "Reproduce or deploy a project exactly as documented: follow the README, tutorial, or install.sh step by step, keep a full trail, fix errors along the cheapest-to-most-expensive path and make fixes permanent in files, and deliver a report plus the modified files. Use when asked to reproduce, deploy, or get a project running."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Project Reproduction (follow the docs, fix, make it repeatable)

Goal: **a predictable process and a reusable result** — the next person following "report + modified files" succeeds in one pass.

## When to Use

- Reproducing, deploying, or getting a project / demo / open-source code running per its README, tutorial, or `install.sh`
- Executing documented steps while recording each result and every deviation
- When reproduction fails and needs systematic troubleshooting, a trail, and a deliverable
- Not for: pure code review; fixing an already-identified single bug; throwaway spikes
- For board/device work over adb, pair this with `adb-device-toolkit` (same repo)

## Output Layout (create it before starting)

```text
<output-dir>/repro_<project>_<YYYYMMDD_HHMM>/
├─ README-FIRST-overview.md   # human-facing, plain language: conclusion / how to use / file map
├─ 00_reproduction-report.md  # main report
├─ 01_execution-log.md        # appended as you go; never written up afterwards
├─ 02_problems-and-fixes.md   # one complete record per error
├─ 03_fixed-files/            # final usable files, original relative paths kept
└─ 04_baseline-snapshot/      # original docs and pre-change files, or a commit hash
```

Confirm the output directory with the user before running; never write to the desktop or leave absolute paths in the report.

## Procedure

### P0 Prepare

1. **Collect and read the source document in full**: README/tutorial/install.sh, source location, target environment type (host machine / attached device).
2. **Agree on the acceptance criterion**: which command, which observable behavior, which output counts as "working" (e.g. a program exits cleanly, a page responds, a log line appears). Without it, "optimal" is undefined.
3. **Create the workspace**; copy the source doc and key original files into `04_baseline-snapshot` (record the commit hash if the project is a git repo).
4. **Record an environment snapshot in `01_execution-log`**: OS, interpreter versions (note that `python3` and `python` may be different interpreters), dependency list, network/proxy, working directory; for a device add its model, connection state, firmware, and free space on the root filesystem.

### P1 Execute the documented steps faithfully

5. **Decompose the source into a step sequence.** Per step record: the original sentence → the command executed (literally as written, not pre-corrected) → actual output / exit code / duration → verdict pass or deviation.
6. **Stay faithful to the document.** When the document conflicts with reality (path missing, the command itself errors), run it as written once and log it as a "documentation deviation" — don't silently fix the author's work.
7. **Journal as you go**: append each step to `01_execution-log.md` immediately.
8. **Pass criterion**: the actual result matches the document and satisfies the P0 acceptance criterion.

### P2 Errors → cheapest path (the core)

9. **Capture complete evidence**: full raw error text + stack + exit code + relevant log paths. Never log only a summary or a "translated" error.
10. **Root-cause order** (cheapest first; try one branch at a time):
    - **a. Environment mismatch** (most common): dependency / interpreter / OS version, missing package, proxy, permissions → build a "documented version vs actual version" table
    - **b. Configuration**: config file, paths, URLs, ports, credentials
    - **c. Code vs docs mismatch** → minimal patch
    - **d. Platform-specific traps**: consult the pitfalls below; Windows file-writing issues (`windows-shell-tooling`); device issues (`adb-device-toolkit`)
11. **Stop-loss**: if a branch shows no progress after ≤ 2 attempts, switch branches or report upward. Never retry the same failing command indefinitely.
12. **Minimal change, made permanent**: change one thing at a time; prefer writing the fix into the project itself (`install.sh`, config, source, doc errata) over a one-off manual command — the fix must survive so the next person following the docs doesn't hit the same wall. When bilingual docs exist, update both.
13. **Verify and log immediately after each change**: re-run the failed step and everything downstream of it, then write the entry into `02_problems-and-fixes.md`.

### P3 Wrap up and deliver

14. **Re-run the critical path** end to end and confirm the final state meets the acceptance criterion.
15. **Produce the change list and diff**: prefer `git diff`; otherwise diff `03_fixed-files` against `04_baseline-snapshot`.
16. **Main report** — use this structure:
    ```
    # Reproduction report: <project>
    1. Basics          — date, source doc path/URL, source revision, target environment
    2. Environment     — OS, interpreter versions, dependencies, network/permissions
    3. Acceptance      — the agreed definition of "working"
    4. Steps & results — table: # | source step | command | result | notes
    5. Problems        — table: # | raw error | root cause (a/b/c/d) | fix + where made permanent | verification
    6. Changed files   — table: relative path | change | type (fix/errata/new) | required to succeed?
    7. Conclusion      — passed as documented / passed after N fixes / not reproduced (where it stopped, why)
    8. Repeat guide    — 1. overlay 03_fixed-files, 2. run the steps marked passing, 3. expected result
    ```
17. **Archive final files** into `03_fixed-files/` keeping relative paths. In the report, state plainly which steps fail by the letter of the document unless the fixed files are used.
18. **Report**: give the absolute output path, a conclusion summary (passed as documented / passed after fixes / not reproduced + why), and the residual risk — don't paste the whole report into the conversation.

## Pitfalls

- **A script's "All done" is not success**: redirecting a child's output into a missing directory means the child never starts while the script still reports success. Verify side effects (artifact files, process liveness, log content) before accepting anything.
- **Execution identity ≠ environment identity**: running scripts via non-interactive shells (`su -c`, `bash -lc`, single ssh command) often skips the target user's PATH setup, so `python3` resolves to the system version and missing dependencies get misdiagnosed as project bugs. Export PATH explicitly to reproduce "the user in a terminal".
- **Transfer binaries with the tool's own transfer command** (`adb push` for devices), then compare checksums on both sides — never through a shell redirect.
- **Long tasks**: use a background handle plus completion notification instead of blocking; for servers, health-check before continuing.
- **Remote long tasks and reboots**: detach with `setsid … > log 2>&1 < /dev/null &` and poll the log; use `systemctl --no-block reboot`.
- **Keep raw error text**: don't paraphrase or translate while reading — information gets lost.
- **Disk full**: small root filesystems ship nearly full; if an install reports out of space, run `df` before concluding a package is missing.
- **Windows/git-bash paths**: native tools need `C:/...` style paths (see `windows-shell-tooling`).

## Verification

- [ ] `01_execution-log` covers every step of the source (original quote + actual result), appended live
- [ ] `02_problems-and-fixes` covers every error, and each fix was made permanent in a file
- [ ] `03_fixed-files` exists and matches the change list one-to-one
- [ ] `README-FIRST-overview.md` exists with a one-sentence conclusion and a file map
- [ ] The report's conclusion is explicit, and report + fixed files reproduce the result
- [ ] Acceptance was performed as the target user identity (not just as an elevated/admin shell)
