---
name: github-repo-review-and-design
description: "Review a whole GitHub repository and produce a graded report, or design the file structure for a new open-source demo or project. Covers repository assessment, layered code review, automated scans, release-readiness checks, and layout templates. Use for repo triage, selection, or project scaffolding."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# GitHub Repo Review & File Design

One skill, two workflows sharing the same "locate the repo + decide the mode" preamble:

- **Workflow A — whole-repo code review**: clone, analyse in full, emit a graded report. Two modes: **assessment** (third-party repo, read-only, adoption advice) and **release** (your own repo, fix it up to a publishable state).
- **Workflow B — repository file design**: design the directory tree, file responsibilities, and standard-file contents for a new project; produce a reorganisation plan for a messy existing repo; optionally scaffold it.

## When to Use

- Whole-repo review / assessment: given `owner/repo`, a URL, or a local path, judge quality, usability, and compliance
- Selection, learning, or pre-fork evaluation
- Repository file-structure design for a new project or demo
- Reorganisation plan for a messy legacy repo

Route elsewhere: PR/diff-level review and inline PR comments; pre-commit self-review of your own small change; LOC/language statistics only (`pygount` is used inside A1 here).

## Prerequisites

```bash
gh auth status >/dev/null 2>&1 && echo AUTH=gh || { [ -n "$GITHUB_TOKEN" ] && echo AUTH=token || echo "run 'gh auth login' or set GITHUB_TOKEN"; }
```

## Step 0 — Locate the repo and decide the mode

1. **Locate**: URL or `owner/repo` → clone; local path → use directly.
   ```bash
   gh repo clone owner/repo "$WORK" -- --depth 1        # shallow by default; add --filter=blob:none for tree only
   gh api "repos/owner/repo/git/trees/HEAD?recursive=1" --jq '.tree[].path'   # fast path, no clone
   gh api repos/owner/repo/readme --jq '.content' | base64 -d
   ```
   On Windows, give git a native path (`C:/...`) — it doesn't understand `/tmp`.
2. **Mode** (this decides everything downstream):
   - Your own / writable repo → **release mode**: fix issues after review.
   - Third-party repo → **assessment mode**: read-only, advisory only, never modify.
   - Deep vs fast: if the user only wants "is this worth a look?", stop after A1 (metadata + README + dependency scan) and emit the assessment card.

Workflow A continues at A1; Workflow B at B1.

---

# Workflow A — Whole-repo code review

## A1 Metadata snapshot

```bash
gh repo view owner/repo
gh api repos/owner/repo --jq '{archived, pushed_at, license: .license.spdx_id, open_issues, default_branch}'
find . -path ./.git -prune -o -type f -print | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
pygount --format=summary --folders-to-skip=".git,node_modules,venv,.venv,__pycache__,dist,build,models,assets" .
git log --since="1 year ago" --oneline | wc -l
# CI reality (L5): a config file is not the same as a running pipeline
gh api "repos/owner/repo/actions/workflows" --jq '.workflows[] | select(.state=="active") | .path' 2>/dev/null
gh api "repos/owner/repo/actions/runs?per_page=3" --jq '.workflow_runs[] | "\(.name): \(.status)/\(.conclusion) \(.created_at)"' 2>/dev/null
```

Record: language, size, LOC, last commit date, licence claim, archived flag, directory responsibilities.

## A2 Structure and architecture ("claims" before "verification")

1. Read README / docs: what it claims to do, how it says to run it, how it describes the layout.
2. Find the entry point and main flow: root scripts, `main.py` / `app.py`, `package.json` scripts, `Cargo.toml`.
3. Draw a module map: top-level directory responsibilities and cross-references (imports in Python; key files elsewhere).
4. **Verification checklist (where things crash most)**:
   - Claimed features vs actual code (a README feature that is a TODO or absent).
   - Commands in examples/tutorials vs the real entry point (the classic demo failure: docs say `python3 main.py`, the entry lives elsewhere).
   - Config keys vs keys actually read (a key in `config.yaml` nobody reads, or code wanting a key that isn't there).
5. If tests exist, run the baseline (`python -m pytest -q` or the project's runner) and record pass/fail counts.

## A3 Layered code review

Scan in value order (truncate when time-boxed, but L1/L2 are mandatory):
**L1 entry & startup → L2 core business logic → L3 configuration/interfaces/device access → L4 tooling scripts → L5 tests/CI**

| Layer | Focus |
|---|---|
| L1 | Argument parsing, exception fallbacks, behaviour when hardware/driver/network is missing, startup order |
| L2 | Algorithms, main loop, state machine, event flow — compared line by line against claimed capability |
| L3 | Config reading, serial/GPIO/USB/camera/HTTP APIs, resource release, timeouts and reconnection |
| L4 | install/build/helper scripts: reproducibility, idempotency, error handling |
| L5 | Can tests run, do they cover critical paths, is CI actually executing |

Run each layer through six dimensions: **correctness · security · code quality · tests · performance · docs & engineering.** Record as you go: `file:line — severity (🔴🟡💡) — one-line issue + suggestion`. Never "look at everything, then remember".

What each dimension looks for (abridged):

- **Correctness**: empty/full input, division by zero, timeouts, re-entrancy, reconnection; swallowed exceptions; resource release (files/devices/connections/threads); illegal state transitions; missing watchdog/heartbeat; claimed vs actual behaviour.
- **Security**: hardcoded secrets (including test dirs and examples, and in history); private-network IPs and personal path traces; injection (SQL, shell concat, `eval`/`exec`, `pickle`, non-safe `yaml.load`); path traversal, arbitrary writes, unverified downloads (`curl | sh`); dependency vulnerabilities (`pip-audit`, `npm audit`); disabled certificate validation; default credentials/backdoors.
- **Code quality**: naming, single responsibility, magic numbers; dead code, unused dependencies, duplicated implementations; comments disagreeing with code; oversized functions, nesting > 4, global mutable state.
- **Tests**: do they exist, do they run, baseline counts; failure/exception/boundary cases rather than happy path only; hardware/network dependence without mocks (fine to note, not to block).
- **Performance**: repeated IO/logging/image work inside loops (N+1); large long-lived objects (frames, models, unbounded caches); thread/process leaks; slow startup.
- **Docs & engineering**: README commands actually work; tutorial paths match the real entry; LICENSE present and consistent with the badge; `.gitignore` missing large files/secrets/logs; CI present but never run; pinned dependencies; versioning/CHANGELOG/release strategy.

Language quick-checks:

| Language | Typical findings |
|---|---|
| Python | leftover `print`/debugger, bare `except:`, `open()` without `with`, global mutable state, unpinned requirements, `sys.path` hacks, hardcoded `\` paths, `yaml.load`, `subprocess shell=True`, `requests verify=False` |
| C / embedded | `strcpy`/`sprintf`/`gets`, leaked `malloc`, interrupts/timers/watchdog not reset, raw register writes without comments, platform macros leaking into business logic, hardcoded pins/addresses |
| Shell | no `set -e`, `rm -rf $VAR` unguarded, `curl \| sh`, absolute-path assumptions, unprompted `sudo`, non-idempotent `install.sh` |
| JS/TS | leftover `console.log`, `any` abuse, `innerHTML` from user input, unhandled promise rejections, no lockfile |

Embedded / AI-demo specifics: is the model file's provenance and checksum documented; SoC model hardcoded vs read from `/proc/device-tree/model`; device node numbers baked in (the USB camera ending up as `video73`); can the app run straight from a factory-default terminal (no shell assumptions, no absolute interpreter paths); are `/dev` access and udev rules installed by `install.sh`; do dependencies/models go somewhere other than a small root filesystem.

## A4 Automated scans (run inside the clone)

```bash
# 1) Sensitive data
grep -rInE --exclude-dir=.git "(api[_-]?key|secret|passw(or)?d|token)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}['\"]" .
grep -rInE --exclude-dir=.git "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" .
grep -rInE --exclude-dir=.git "C:\\\\Users\\\\[A-Za-z]+|/home/[a-z]+" --include=*.py --include=*.sh --include=*.md .
grep -rInE --exclude-dir=.git "\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9.]+" --include=*.py --include=*.sh --include=*.json .
# 2) Leftover markers
grep -rInE --exclude-dir=.git "TODO|FIXME|HACK|XXX" --include=*.py --include=*.js --include=*.c .
# 3) Large files committed by mistake (>10MB)
git ls-files | while read -r f; do [ -f "$f" ] && s=$(stat -c%s "$f") && [ "$s" -gt 10485760 ] && echo "$((s/1024/1024))MB $f"; done
# 4) Dependency audit
[ -f requirements.txt ] && (pip install pip-audit -q 2>/dev/null; pip-audit -r requirements.txt 2>/dev/null | head -20)
[ -f package.json ] && npm audit --omit=dev 2>/dev/null | tail -15
# 5) LICENSE present and consistent with README/package metadata
```

History scan (mandatory in release mode; a shallow clone has no history — clone again in full):

```bash
gh repo clone owner/repo "$WORK/full" && cd "$WORK/full"
git log -p --all -G "(api[_-]?key|secret|passw(or)?d|BEGIN (RSA|EC|OPENSSH )?PRIVATE KEY)" -- '*.py' '*.sh' '*.json' '*.yaml' '*.yml' '*.md' \
  | grep -iE '^\+.*(api[_-]?key|secret|password|token|PRIVATE KEY)' | head -30
```

A leading `+` means that commit added it — including files deleted long ago. Review each hit by hand and list it in the report's "history traces" appendix. **Sensitive-data hits always need human review**: example keys, test fixtures, and placeholders are common false positives.

## A5 Report

Choose the shape by mode:

- **Assessment mode** — conclusion card:

| Dimension | Verdict | Evidence |
|---|---|---|
| Maintenance activity | 🟢🟡🔴 | commits in the last year, last commit date, issue response |
| Code quality | | L1/L2 sampling, dead code, complexity |
| Docs & onboarding cost | | README reproducibility, example completeness |
| Dependency & licence risk | | audit results, LICENSE consistency |
| Security surface | | sensitive-data / injection scan results |
| Ecosystem | | stars/forks, alternatives |

Adoption advice: ✅ use directly (+ version/commit to pin) · 🔶 learn from it (list the modules worth borrowing) · ❌ drop it (why: unmaintained / licence incompatible / poor quality / better alternative).

- **Release mode** — readiness verdict plus a ticked checklist: secrets cleared (including history and test dirs) · LICENSE consistent · README complete with working commands · `.gitignore` covering run artifacts and no large files committed · tests green · versioning/CHANGELOG/tag strategy · entry-point consistency (tutorial commands equal the real entry) · contributing guide if contributions are wanted.

- **Findings**, always grouped by severity, each with `path:line`, one-line issue, and suggestion; plus a ✅ highlights section. Paths are relative to the repo root; merge multiple findings in the same file into one entry.

- **Scan results appendix**: sensitive-data hits (real vs false positive), history traces (with commit SHAs), dependency vulnerabilities by severity, TODO/FIXME leftovers, large files with a proposed destination, LICENSE consistency, test baseline.

Write the report to an agreed output directory (`<output-dir>/<repo>_review_<YYYYMMDD>.md`); give only the conclusion summary in the conversation.

**Fix loop (release mode only)**: work 🔴 then 🟡, re-run A4 after each fix; "ready" means secrets cleared and tests green. Third-party repos stay read-only — never fix them "while you're there".

---

# Workflow B — Repository file design

## B1 Choose the type

Open-source demo (embedded/AI: runnability and one-click deploy first) · application/service · library/SDK · internal tool/script.

If information is missing, ask once: one-line purpose, tech stack, target platform, open-source or not, who installs it (any non-engineers?).

## B2 Directory tree and responsibility table

Trim from the templates below — never invent directories:

| Type | Skeleton | Key points |
|---|---|---|
| Open-source demo | `README.md` ●, `LICENSE` ○, `install.sh` ○, `main.py` ●, `config.yaml` ○, `requirements.txt` ●, `modules/` ○, `models/` ◇ (`.gitkeep` + download instructions), `assets/` ○, `tests/` ◇, `.gitignore` ● | Runs from a clean environment by following the README; runs directly from the factory-default terminal; model provenance documented and downloadable; no absolute paths or shell assumptions; permissions/udev configured by `install.sh` |
| Application/service | `README.md` ●, `src/<pkg>/` ● (`main.py`/`server.py`, `config.py`, `api/`, `services/`, `models/`, `utils/`), `tests/` ○, `requirements.txt`/`pyproject.toml` ●, `.env.example` ○, `Dockerfile` ◇, `.github/workflows/ci.yml` ◇, `.gitignore` ● | Config: usable defaults, env-var overrides, no secrets in the repo; thin routes, thick services; `.env.example` keys match what the code reads |
| Library/SDK | `README.md` ●, `LICENSE` ●, `pyproject.toml`/`package.json` ●, `src/<pkg>/` ●, `tests/` ●, `examples/` ○, `docs/` ○, `CHANGELOG.md` ○ | Minimal public surface; typed/documented API; runnable examples; semantic versioning; licence compatible with dependencies |
| Internal tool/script | `README.md` ●, `<tool>.py`/`.sh` ●, `requirements.txt` ◇, `tests/` ◇, `config.example.yaml` ◇, `.gitignore` ● | One file per tool, under 500 lines or split; parameters via argparse not edits; clean parseable stdout; idempotent; no dependence on a personal environment |

Rules: every entry in the tree gets one line in the responsibility table; **the entry script name must match the README/tutorial exactly**; drop anything the project doesn't need.

`.gitignore` starting point: `*.log`, `.DS_Store`, `Thumbs.db`, `.idea/`, `.vscode/`; Python: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `.pytest_cache/`, `.mypy_cache/`, `dist/`, `build/`, `*.egg-info/`; models/data: `*.pt`, `*.onnx`, `*.h5`, `*.pth`, `*.bin`; embedded: `*.o`, `*.elf`, build outputs; always ignore `models/`, `weights/`, `datasets/` contents (keep the directory with `.gitkeep`).

## B3 Standard files, item by item

- **README**: outline per the design doc below; for bilingual projects give a paragraph-mapping table and a "both versions move together" rule.
- **LICENSE**: only for open source; pick per the user's declaration and check dependency compatibility.
- **.gitignore**: per language plus run artifacts (see above).
- **install.sh / quick start** (demos): one-click semantics covering dependency install + model/resource acquisition + permissions.
- **Config**: demo values are defaults; thresholds, time windows, model paths, device numbers are configurable rather than hardcoded.
- **CI** (optional): a light lint + smoke job is enough for a demo; don't force a heavy pipeline.

## B4 Deliverable

Design document structure:

```
1. Project definition  — one-liner, stack, platform, open-source?, target users
2. Repo type & rationale — which template and why
3. Final directory tree
4. File responsibility table (path | responsibility | required/optional | notes)
5. Standard-file contents — README outline, LICENSE choice, .gitignore list, install.sh actions + acceptance, CI scope
6. Ignore/hosting strategy — models to releases/LFS/download script; credentials out of the repo (.env.example)
7. Risks & TODOs — one next action per item
8. Landing checklist — ordered list of files to create (directory + placeholder + content)
```

Deliver either the document, the generated skeleton, or both; write it to `<output-dir>/<project>_repo-design_<YYYYMMDD>.md`.

## Embedded/open-source-demo conventions (overridable)

- `install.sh` covers one-click deploy; afterwards the app must run directly in the **factory-default terminal** (no shell switching, no absolute interpreter paths); such fixes belong in `install.sh` itself, not in one hand-patched machine.
- Parameterise thresholds, time windows, and model paths through config; demo values are defaults only.
- Keep bilingual READMEs in mirror sync.
- Model weights and large files stay out of the repo → releases/LFS plus a download script.
- Separate demos live in separate repositories without cross-dependencies.

## Pitfalls

- **Large repos**: default to `--depth 1`; assessment mode doesn't need full history; `--filter=blob:none` fetches only the tree.
- **submodules / LFS**: after cloning, check whether subdirectories are empty (submodule dirs often are); use `--recurse-submodules` when needed; a model directory may be an LFS pointer.
- **False-positive secrets**: review regex hits by hand (examples, fixtures, placeholders); don't over- or under-report history traces.
- **Mode misjudgement**: treating a third-party repo as release mode ends in failed pushes — decide in Step 0.
- **Windows git-bash**: use `C:/...` paths for native git/gh; `stat -c%s` works.
- **Read-only discipline**: assessment mode reports and stops — no edits, no branches.
- **Fast-path routing**: "is this worth looking at?" ends at A1 with an assessment card, not a full audit.

## Verification

- Review: the report covers L1/L2/L3 plus A4 scan results; every 🔴 carries `file:line`; the mode matches the conclusion.
- Design: no orphan files in the tree, no entry lacking a responsibility, the README outline maps one-to-one to the tree, and `.gitignore` covers all run artifacts.
