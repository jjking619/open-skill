# Changelog

All notable changes to this skill pack are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each skill also carries its
own `version` in its `SKILL.md` frontmatter — that is the version to cite for a single skill.

## [Unreleased]

## [0.1.0] - 2026-10-12

Initial public release: 10 client-agnostic skills, each one a self-contained `SKILL.md` with a
Chinese edition (`SKILL.zh.md`) alongside it.

### Added

- `code-authoring` v0.1.0 — comment hygiene (write *why*) and minimal-sufficient-diff discipline
- `github-repo-review-and-design` v1.1.2 — whole-repo graded review plus repository layout design
- `project-reproduction` v0.1.0 — reproduce or deploy a project from its own docs, fixing forward in files
- `prepublish-repo-audit` v0.1.0 — pre-publish gate: visibility, secrets, internal identifiers, repo hygiene
- `windows-shell-tooling` v0.1.0 — Windows + git-bash traps: paths, line endings, encoding, file writing
- `shell-script-hardening` v0.1.0 — idempotent, diagnosable install/deploy scripts that never fake success
- `adb-device-toolkit` v0.1.0 — adb workflows: identifying devices, execution identity, transfers, detached jobs
- `feishu-docs-api` v0.1.0 — Feishu/Lark docx, wiki and bitable driven over REST
- `doc-consistency-audit` v0.1.0 — consistency audit for document batches and translation mirrors
- `deliverable-pack` v0.1.0 — reviewable deliverable pack: overview, report, log, problem log, snapshot
- `README.md` / `README.zh.md` — English and Chinese facades with a matching skill index
- `tools/check-doc-sync.sh` — verifies that the README (and optionally a published document) index matches `skills/`

### Changed

- Skills are **client-agnostic**: any Agent Skills–compatible client can load them; no client-specific
  metadata, no local machine paths, no references to skills that are not in this repository.
- Layout follows the Agent Skills tap convention: `skills/<skill-name>/SKILL.md` (directory name equals
  the frontmatter `name`), so the tree can be copied wholesale.

### Removed

- Bundled reference files: every skill is now a single self-contained `SKILL.md` (Chinese edition
  alongside), so a skill never breaks because an auxiliary file is missing.

### Notes

- Skills are obtained from this repository. Do not copy individual skill files between projects —
  update the repository and re-copy, so the index here stays authoritative.
