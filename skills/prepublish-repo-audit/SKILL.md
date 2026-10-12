---
name: prepublish-repo-audit
description: "Pre-publish gate before open-sourcing, making a repo public, or handing it to a third party: visibility check, secret and credential scan, internal-identifier and internal-path scan, large-file and hygiene checks, history and cache residue. Run it before every publish."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Pre-publish Repo Audit

**Publishing is irreversible**: once pushed, history, caches, and downloaded copies cannot be recalled. The order is always
**check visibility → scan content → get the user's decision → only then push**. Never "push first, ask later".

## When to Use

- Flipping a private repo to public, open-sourcing an internal tool, handing a repo to a client or third party
- Publishing skills, templates, or document sets (including to skill/plugin directories)
- Periodic checks that a public repo hasn't accumulated internal information
- Not for: routine commits inside a private network repo

## The Gate

**① Visibility check (see the current state first — no token needed)**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://github.com/<owner>/<repo>   # 404=private, 200=public
git ls-remote https://github.com/<owner>/<repo> refs/heads/main             # resolvable anonymously = public
curl -s "https://raw.githubusercontent.com/<owner>/<repo>/main/README.md" | head -3   # fetchable = public
```

⚠️ **Never judge "now private" from an uncached raw fetch alone**: raw is CDN-cached and may keep serving old content for a while after you flip the repo private.
Re-test with a cache-buster: `.../README.md?cb=$RANDOM$RANDOM` must return 404 before you call it private.

**② Content scan (stop the moment you hit something)**

Secrets and credentials:

```bash
grep -rInE "(api[_-]?key|secret|password|passwd|token)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}['\"]" . --exclude-dir=.git
grep -rInE "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" . --exclude-dir=.git
git log -p --all -G "(api[_-]?key|secret|passw(or)?d|BEGIN (RSA|EC|OPENSSH )?PRIVATE KEY)" -- '*.py' '*.sh' '*.json' '*.yaml' '*.yml' '*.md' \
  | grep -iE '^\+.*(api[_-]?key|secret|password|token|PRIVATE KEY)' | head -30
```

> The right pattern: the repo contains only **environment variable names**; values come from `~/.env` or runtime injection. If a hardcoded secret is found, **rotate the credential first**, then clean the repo.

Internal identifiers (more common than secrets):

```bash
grep -rInoE "[A-Za-z]{2,6}[0-9A-Za-z]{15,}" .                                    # long tokens (doc/sheet/node/object IDs)
grep -rInE "<internal-domain>|<employer-product-name>|[A-Za-z]:\\\\[^ )\"]+" .   # internal domains / Windows drive-letter paths
grep -rInE "\b(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9.]+" .                # private-network IPs
```

List the hit types (token / app id / internal path / internal domain / employer name / personal handle / email) and decide per item: replace with a placeholder, or don't publish that file at all.

Hygiene checks:

```bash
git ls-files -z | xargs -0 du -h 2>/dev/null | sort -h | tail -15      # oversized files committed by mistake
git log --all --diff-filter=D --name-only | head                     # files deleted now but still in history
```

`git log -S` / `-G` proves "the file is gone from HEAD but lives on in history" — history residue requires history rewriting (git-filter-repo / BFG) or recreating the repo. **Deleting the file in a new commit is not removal.**

**③ Disposition and communication**

- Internal content found and the target is public → **stop and ask the user**, laying out the options at once (make private / produce a sanitized second copy / publish only the generic parts / explicit approval to publish), never decide for them.
- Sanitized versions are prepared **on a copy**: replace on the copy, leave the source repo untouched, then **re-fetch the published content and scan again**.
- Only a repo admin can flip visibility (web Settings); afterwards **re-test** (with a cache-buster) to confirm 404.

## Repo Hygiene Checklist

| Item | Criterion |
|---|---|
| LICENSE | Present and consistent with the README claim (MIT / Apache-2.0 / …) |
| README facade | First screen says what it is and how to install/use; numeric claims (version, file counts) match the directory |
| .gitignore | Covers OS/editor junk, `__pycache__`, build outputs, local config, `.env` |
| .gitattributes | `* text=auto eol=lf` (uniform LF across platforms) |
| Commit hygiene | No build outputs or large binaries; readable commit messages |
| Metadata | Topics / description / default branch set so directory sites can index it |
| Twin-repo sync | Private internal edition and public sanitized edition share the same layout for easy incremental sync; record what stays private |

## Pitfalls

- **Push first, ask later**: a push to a public repo cannot be undone — the gate must run before the push.
- **Looking only at HEAD**: deleted secrets still sit in `git log -p`.
- **CDN cache misjudgment**: without a cache-buster you can read "already private" as "still public" (and vice versa).
- **Replacing a secret with a placeholder and calling it done**: an exposed credential must be **rotated**, otherwise nothing was fixed.
- **Scanning code but not docs**: internal domains, node IDs, and internal paths show up most often in markdown, examples, and comments.
- **Fixing locally without re-scanning the remote**: after pushing, fetch the published content anonymously and scan it again.

## Verification

- [ ] Visibility has an explicit verdict (including the cache-buster re-test)
- [ ] Secret scan zero hits; history residue rewritten or credentials rotated
- [ ] Internal-identifier scan zero hits — **both locally and from the published content**
- [ ] Hygiene checklist ticked item by item; README numbers match the directory
- [ ] Anonymous access works after publishing, and remote SHA equals the local commit
