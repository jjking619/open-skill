---
name: deliverable-pack
description: "Turn one-off work into a reviewable deliverable pack: a human-facing overview, a structured main report, an append-as-you-go execution log, a problem-and-fix ledger, and raw snapshots. Use for reproduction, migration, audit, and research work that must be handed over."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Deliverable Pack

The same piece of work has **three readers**: a decision-maker who wants only the conclusion, an operator who re-runs your report, and an auditor who checks the log and snapshots. Satisfy all three with a fixed five-file pack.

## When to Use

- Reproduction / migration / deployment / audit / research / troubleshooting work that someone else must receive
- When a third party must be able to **repeat your work**, or when "what exactly was done?" must be answerable later
- Not for: answering a question in chat, one-off scripts

## The Pack

```text
<artifact-type>_<subject>_<YYYYMMDD_HHMM>/
├─ README-FIRST-overview.md   # required: 1-2 screens, plain language (decision-maker starts here)
├─ 00_main-report.md          # structured conclusion + evidence (operator follows this)
├─ 01_execution-log.md        # appended as you go; never written up afterwards
├─ 02_problems-and-fixes.md   # one complete record per problem
├─ 03_artifacts/              # final usable files, original relative paths kept
└─ 04_baseline-snapshot/      # pre-change files / git commit, so the diff has a base
```

## What Each File Must Contain

**① `README-FIRST-overview.md` (most important — never skip)**
- One-sentence conclusion (passed / passed with caveats / failed, and why)
- What was done, and how to use it now (copy-pasteable commands)
- **File map**: label "important (read this)", "results", "process record (usually skip)"
- Open items and risks
- Rules: no jargon, no log dumps, at most 2 screens

**② `00_main-report.md`**
Fixed sections: task info → environment → acceptance criteria → steps and results → conclusion → how to repeat.
Every conclusion carries **evidence**: command + actual output excerpt + location, so a third party can verify it directly.

**③ `01_execution-log.md`**
One entry per step: source sentence → actual command → output and exit code → verdict (pass / fail / deviation).
Append **while you work**; never reconstruct from memory afterwards (memory flatters the process and erases real deviations).

**④ `02_problems-and-fixes.md`**
Per problem: raw error text (not a translated summary) → root cause → fix action and **where it was made permanent** → verification method and result.

**⑤ `03_artifacts/` and `04_baseline-snapshot/`**
Artifacts keep their original relative paths so they can be dropped in directly. The snapshot preserves pre-change files or a commit hash so the diff has a baseline.

## Discipline

- **Conclusions first**: the report opens with the conclusion; process comes after.
- **Log and overview stay separate**: a process record is not a deliverable; never stuff a running commentary into "read me first".
- **Every conclusion is verifiable**: give the command, the path, the output excerpt — never "verified".
- **Relative or placeholder paths**: references inside the pack are relative; never bake machine-specific absolute paths into documents.
- **Timestamp the directory**: multiple deliveries per day must not overwrite each other.

## Pitfalls

- **Report without an overview**: the recipient has to dig through dozens of pages for the conclusion — effectively nothing was delivered.
- **Writing the log afterwards**: memory rewrites the process and erases deviations.
- **Keeping only a summary of errors**: root-causing and re-running become impossible.
- **Missing file map**: ten files in a directory and the recipient doesn't know where to start.
- **Process treated as conclusion**: long running commentary fills the report and drowns the conclusion.

## Verification

- [ ] All five parts present; the overview states a one-sentence conclusion and a file map
- [ ] Every main-report conclusion has a command + output/location
- [ ] The execution log is chronologically appended (with exit codes), not summarized
- [ ] Every problem reads as raw error → root cause → fix location → verification
- [ ] Artifacts and snapshot exist; a third party can re-run from the report alone
