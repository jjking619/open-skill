---
name: doc-consistency-audit
description: "Audit a batch of documents for consistency: missing or extra sections, out-of-sync translations, broken or unencoded links, glued shell commands in code blocks, inconsistent terminology, and leftover placeholders. Produces a severity-graded report with locatable evidence. Use when reviewing a doc set or a multi-language doc tree."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Documentation Consistency Audit

Turn "are these documents actually consistent?" into **repeatable checks plus a verifiable report**:
run mechanical scans first (anything a script can find is never eyeballed), then sample the semantic layer, then report by severity.

## When to Use

- A batch of documents (a directory tree, a knowledge base, one product line) is about to ship
- A multi-language doc tree: are both sides in sync, is anything untranslated
- Pre-release documentation regression: leftover placeholders, TODOs, dead links, broken code blocks
- Not for: polishing a single page (just edit it); marketing copy review

## Prerequisites

- A defined **scope** and the **mirror relations** (which documents are the same content in another language)
- Access to the sources as plain text (local markdown, a repository, or a platform API)

## Procedure

**① Define scope and mirror pairs**
List the documents to check; build the Chinese ↔ English pairing table (pair by path or a content fingerprint — **never by literal title**, because mirrored titles are translations). Record the pairing method at the top of the report.

**② Mechanical scan (scriptable — do this first)**
Each item below yields `file + line + snippet` when it hits. Use the fixed finding-type enum in the last table so results stay countable.

| Category | What to check |
|---|---|
| Structure | Modules claimed by the TOC/feature list actually have sections (missing/extra); heading levels don't skip; no empty sections; manual numbering is gap-free |
| Links | No spaces or unencoded characters in URLs; `#fragments` resolve; relative paths exist; external links return 2xx/3xx; no duplicate definitions |
| Code blocks | Commands glued to trailing comments; several commands crammed on one line; missing language tag; fences paired; no stray prompts (`$ `, `> `); output mixed into command blocks |
| Placeholders | Revision-history `-` rows, `TBD`, `TODO`, `xxxx`, unreplaced template fields |
| Terminology | One spelling per proper noun; consistent full/half-width punctuation and casing; the project's own CJK/Latin spacing rule applied consistently; acronyms expanded on first use; units formatted uniformly (`5V` vs `5 V`) |
| Layout | Table rows match the header column count; every table has a separator row; every image has a caption/alt; list nesting consistent |

**③ Semantic sampling (what scripts can't see)**
- Structure vs claims: every module or feature named in the TOC has a section (and nothing extra).
- Numbers and configuration: thresholds, version numbers, and parameter names in the docs match the config files and real output.
- Mirror parity: chapter counts, code-block counts, table counts, and image counts are comparable; missing paragraphs are listed.
- Figure/text agreement: images are captioned, and the caption points at the same object the text describes.

**④ Record findings**
One record per finding: `file | location | type | evidence snippet | severity | suggestion`.
Severity: 🔴 blocking (functional or factual error) · 🟡 should fix (consistency/readability) · 💡 suggestion (style preference).

**⑤ Write the report**
```
# <scope> documentation consistency audit
> date | scope (documents count) | method: full mechanical scan + sampled semantic pass
> mirror pairing: by path / by fingerprint | unpaired: N (listed in appendix)

## Conclusion (one sentence)
<shippable / N items to fix first / N blocking issues>; fixed directly: N; needs confirmation: N

## 1. Fixed directly
| # | document | location | type | before → after |

## 2. Outstanding, by severity
### 🔴 blocking   ### 🟡 should fix   ### 💡 suggestions
| # | document | location | type | evidence | suggestion |

## 3. Tally by type    ## 4. Mirror alignment (chapter/code-block/table counts per pair)
## Appendix: scan method, unpaired documents, uncovered areas
```

## Fix Discipline

- **Fix unambiguous problems directly**: typos, link encoding, leftover placeholders, glued commands — no need to ask per item.
- **Keep mirrors in step**: whenever one language changes, check and update its counterpart.
- **List semantic or judgment calls**: suspected-but-uncertain issues and anything needing business context go to "needs confirmation" rather than being changed silently.
- **Record what changed**: the report separates "fixed" from "outstanding" and notes the location of each fix.

## Finding Types (fixed enum)

`structure-missing` · `structure-extra` · `heading-level` · `empty-section` ·
`link-encoding` · `link-anchor` · `link-dead` ·
`code-glue` · `code-lang` · `code-fence` ·
`term-variant` · `spacing` · `unit-format` ·
`table-shape` · `placeholder-leftover` ·
`mirror-missing` · `mirror-mismatch`

## Pitfalls

- **Pairing mirrored docs by literal title**: titles are translations — pair by path or content fingerprint.
- **Scanning without reading**: mechanical checks cover only pattern-able issues; missing sections, wrong numbers, and mismatched figures need sampling.
- **One giant unreviewable diff**: fix unambiguous issues directly, but keep "structural reshuffles" separate from "word-level fixes".
- **Reporting style differences as problems**: without an agreed style guide, variance is at most a 💡 suggestion — never a blocking item.

## Verification

- [ ] The report states scope, method, and mirror pairing, with a locatable snippet per finding
- [ ] Fixed and outstanding items are listed separately, and counts match the tables
- [ ] Both sides of every mirror pair were checked (not just one language)
- [ ] No "consider optimizing" entries without a concrete location and action
