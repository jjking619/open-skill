---
name: windows-shell-tooling
description: "Running commands and writing scripts on Windows with git-bash / MSYS: unconverted paths, CRLF vs LF, backslash escaping, GBK console, pty line endings, paths with spaces. Use when script behavior is odd or native tools can't find a path."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows]
---

# Windows Shell Tooling (git-bash / MSYS)

Field-tested pitfalls and workarounds for running commands, writing scripts, and mixing native Windows tools (git / node / python / rg) inside git-bash (MSYS2).
Goal: **the same command works on someone else's machine**.

## When to Use

- A native Windows program launched from git-bash reports "no such file", "cannot change to", or similar
- A generated or edited script misbehaves: extra carriage returns, vanished backslashes, mojibake
- You're unsure whether to use a POSIX or a Windows path, or whether quoting is needed
- An interactive CLI never reacts to piped input on Windows
- Not for: WSL2 (that is real Linux), or a pure PowerShell environment

## Six Core Rules

**① Path conversion is off by default**
Pass native tools `C:/Users/x/file` (forward slashes) or `C:\Users\x\file`. **Do not** pass `/c/Users/x`.
`cd` is a bash builtin, so `/c/...` works for it — "`cd` worked but the next native tool can't find the path" is the classic symptom.

**② Don't use PowerShell syntax**
`$env:FOO`, `Get-ChildItem`, `Select-String` don't work in git-bash; use `$FOO`, `ls`, `grep`.

**③ Quote paths containing spaces or non-ASCII characters**
e.g. `"/d/projects/my dir/file"` — including after `cd`.

**④ Use LF line endings**
Ship a `.gitattributes` with `* text=auto eol=lf`. Scripts themselves use LF; don't commit files produced with CRLF by a Windows editor.

**⑤ Set UTF-8 explicitly for output**
The console is often GBK — Python that prints non-ASCII should first run
`import sys; sys.stdout.reconfigure(encoding='utf-8')`, or export `PYTHONIOENCODING=utf-8`.
Avoid `python -c` with non-ASCII paths or long non-ASCII strings (double escaping/encoding risk).

**⑥ Submit interactive input with a real Enter**
On Windows, Enter is CR; sending only `\n` frequently does nothing → use a "text + Enter" submit path, or better, prefer non-interactive flags (`--yes`, `--with-token`, config files).

## File Writes and Escaping

- **heredoc**: use a quoted `<<'EOF'` so variables are not expanded.
- **Backslash fidelity**: not guaranteed through multiple escaping layers. To test whether a file contains literal backslashes, use a **byte check** (`od -c`, `grep -c $'\x5c'`) rather than code like `count("\\n")`.
- **Long files / files with many paths**: write the whole file at once; don't debug a heredoc character by character. If it looks corrupted, rewrite it wholesale.
- **Read back after writing**: compare byte length and the first few bytes (`od -c`) to confirm nothing was truncated and no stray `\r` crept in.

## Troubleshooting Order

1. Is the command a bash builtin or a native program? → for native programs, rewrite the path as `C:/...`
2. Does the path contain spaces, non-ASCII, or backslashes? → quote the whole thing and retry
3. Mojibake or extra carriage returns? → check encoding (GBK vs UTF-8) and line endings (CRLF vs LF)
4. Stuck on an interactive prompt? → switch to a non-interactive flag or a submit-style input
5. None of the above? → print the actual environment with `od -c` / `--version` / `pwd` instead of guessing

## Pitfalls

- **Half-fixed paths**: `cd /c/x` succeeding does not mean `/c/x` is valid for git or python.
- **Sending `\n` as "Enter"**: interactive programs ignore it — it looks like the command was sent but never executed.
- **Non-ASCII `print` crashing on encoding**: `UnicodeEncodeError` or question marks — set UTF-8 before debugging anything else.
- **CRLF leaking into diffs**: whole files show as modified when only line endings differ → check editor settings and `.gitattributes`.

## Verification

- [ ] No `$env:` or PowerShell builtins in scripts; path arguments use `C:/` or are quoted
- [ ] Generated files look right under `od -c`: no extra `\r`, no truncation, readable non-ASCII
- [ ] UTF-8 is set explicitly (in-script or via environment)
- [ ] The command still passes when re-run from a clean shell
