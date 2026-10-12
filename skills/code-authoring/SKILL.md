---
name: code-authoring
description: "Load before writing new code or editing code you did not just create: comment hygiene (write why, follow the file's conventions) and minimal-sufficient-diff discipline. Keeps diffs reviewable and prevents scope creep."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Code Authoring: Minimal Sufficient Diff & Comment Hygiene

## When to Use

- Writing new feature code.
- Before modifying code **not created in this session** (bug fixes, refactoring, tests, config-as-code).
- Whenever the diff must stay small so "while I was in there" edits don't bury the real change.

> **Not for**: pre-commit review alone; the test-driven-development loop itself; post-commit bulk cleanup; throwaway spikes.

> **Conflict priority**: existing project style > this skill's defaults; root-cause fix > minimal diff (if they conflict, explain first, then act); correctness/safety > brevity.

## Six Rules

1. This skill is self-contained and covers only the *authoring* phase: new code, and edits to existing code.
2. Its trigger surface covers any production-code write or edit — not just "new features".
3. Comments: follow the file's existing language (English by default for new files); write **why** only; never paste prompts, requirement text, or conversation content into comments.
4. Changes follow the **minimal sufficient diff**: change exactly enough to fully resolve the requirement or defect — no more, no less.
5. Before touching existing code, build a **current-state snapshot**: read existing conventions, run the baseline.
6. Before delivering: self-check scope, comments, and whether you actually ran it.

## Procedure

**Step 1 — Current-state snapshot (mandatory before editing existing code)**

① Read the file/module conventions: naming, comment language, error handling, logging, dependencies, layout.
② Find and run the baseline: build / tests / lint, or the smallest reproducible command. Record current behavior and output.
③ New file with no siblings: English comments; otherwise follow the neighbor files.

Pass criterion: you can state "what it did before my change" and show the baseline command plus its actual output.

**Step 2 — Bound the change (minimal sufficient diff)**

① Write one sentence: what the requirement/defect is, and what the acceptance criterion is.
② List the minimum "must change" set: target function/file + its call sites + necessary tests.
③ Blacklist (never do "while you're there"): reformatting or reordering lines, renaming, reordering imports, adding unrequested logging/params/flags/fallbacks/abstractions, introducing new dependencies, changing public signatures, broad cross-file reshuffles.
④ Whitelist (required — otherwise you ship half a fix): input validation, error/exception handling, resource release, updating call sites of changed functions, required tests, changes forced by formatters (black/ruff/prettier).
⑤ Never add special cases, hardcode values, comment out assertions, or bypass validation to make tests pass — fix the root cause. If the root cause is out of scope, explain and get agreement first.

**Step 3 — Write the code**

① Follow existing style and structure; only new files use the defaults.
② No opportunistic optimization. Record unrelated problems in a list instead of fixing them here (unless explicitly agreed).

**Step 4 — Comment hygiene**

① Language follows the file; new files default to English.
② Content: explain **why** (rationale), boundary conditions, units, side effects, provenance. **What** (params/returns/exceptions) belongs only in function-level API docs.
③ Length: if naming already expresses it, skip the comment; single-line comments ≤ 1 line, block comments ≤ 3 lines.
④ Banned (greppable): prompts / requirement text / conversation snippets, "AI-generated" or "as requested" attributions, date-stamped change logs (`2026-10-02 fix`), emoji, decorative separators, commented-out dead code, vague TODOs, `@author` placeholders.

```bash
# Comment hygiene self-check (adjust extensions per language)
rg -n "AI[- ]?generated|as requested|\d{4}-\d{2}-\d{2}|TODO|FIXME" -g '!*test*' -g '!*.md' .
```

**Step 5 — Self-check and verify**

① Run the baseline plus the new tests; if you cannot run them, say why and give substitute evidence (static checks, manual repro steps).
② Review the diff: does it touch anything unrelated? Is every hunk justifiable in one sentence?
③ Re-check comments against the Step 4 banned list.
④ Deliverable: change list (`file:line` + why it is necessary) + verification commands and results.

**Step 6 — Report**

① Conclusions and evidence only: what changed, why it was necessary, how it was verified.
② Unrelated issues and follow-ups go in a separate list, never mixed into this change.

## Pitfalls

- **Trigger too narrow**: treating only "new features" as in scope misses bug fixes, refactors, and tests.
- **Misjudging "someone else's code"**: the test is "not created in this session / you don't yet understand its context" — not "every file in the repo". If you don't understand it, understand it first.
- **The classic misuse of "minimal"**: patching tests green (special cases, hardcoding, commenting assertions) is a banned item, not minimality.
- **Defaults over consistency**: inserting English comments into a Chinese-commented project isn't "standard" — follow the existing style.
- **Comments that restate code**: `@param x the value of x` is noise. If naming suffices, don't comment.
- **Reformatting while you're there**: buries the real diff, blocks review, makes rollback risky.
- **Fix-it-now urge**: unrelated defects get recorded, not fixed — otherwise scope and accountability dissolve.
- **grep catches form only**: the banned list finds literal violations, not "explains what instead of why" — review by hand.

## Verification

- [ ] Baseline recorded before the change (command + actual output)
- [ ] Diff contains only the "must change" set; blacklist zero hits
- [ ] Comment language matches the file; banned list zero hits
- [ ] Every hunk justifiable in one sentence
- [ ] Verification actually run, or the reason it couldn't be plus substitute evidence
- [ ] Unrelated issues recorded but not modified
