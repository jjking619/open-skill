---
name: feishu-docs-api
description: "Drive Feishu/Lark cloud documents over REST (docx / wiki / bitable): read and edit blocks, publish or sync markdown, create and archive wiki nodes, manage permissions, plus verified formats, error codes, and post-write verification. Use when a task requires editing a Feishu doc, syncing markdown into one, or building knowledge-base nodes."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# Feishu Cloud Documents over REST (Feishu Docs API)

Turn "edit a Feishu doc / sync markdown up / create a knowledge-base node / write a bitable" into a repeatable pipeline:
**get a token → resolve the target → read current state → write → publish markdown → archive → verify**.
No CLI required — plain REST plus a `tenant_access_token`.

## When to Use

- Bulk-editing Feishu documents: titles, body text, list items, tables, code blocks, inline styles
- Publishing local markdown as a Feishu docx, or syncing it in place into an existing document
- Wiki operations: resolving links, creating/moving/renaming nodes, per-day archive folders
- Reading and writing bitables (multi-dimensional tables): field rework, batch record writes, cross-base migration
- Not for: document content QA rules (use an audit skill); read-only browsing (use the Feishu client)

## Prerequisites

- An app with `FEISHU_APP_ID` / `FEISHU_APP_SECRET` (environment or a `~/.env` file) → exchange for `tenant_access_token`
- The app must be a collaborator on the target document / wiki space; insufficient permission returns `131006` or `1770032`
- **Probe before acting**: `GET /open-apis/wiki/v2/spaces/get_node?token=<wiki_token>` must return `code=0`
- Never hardcode tokens in scripts, documents, or logs; test with a plain docx rather than a wiki node

## Pipeline

**1. Get a token**
`POST /open-apis/auth/v3/tenant_access_token/internal` with `{"app_id":…,"app_secret":…}`.

**2. Resolve the target container**
- Wiki link `.../wiki/<node_token>`: `GET /wiki/v2/spaces/get_node?token=<node_token>` → `data.node.obj_token` **is** the docx document id
- Docx link `.../docx/<doc_id>`: use it directly
- **A wiki token is not a document id** — writing blocks without resolving first always fails

**3. Read current state**
`GET /docx/v1/documents/{doc}/blocks?page_size=500&document_revision_id=-1`, following `has_more`.
Block ids can become invalid after block-level edits — re-fetch before the next operation.

**4. Write content**

```bash
# Update a block's text (works for headings, text, bullets, quotes, todos, and code blocks)
PATCH /open-apis/docx/v1/documents/{doc_id}/blocks/{block_id}
body {"update_text_elements": {"elements": [{"text_run": {"content": "new full text"}}]}}
# Insert blocks at a position (index is the position among the parent's children)
POST /open-apis/docx/v1/documents/{doc_id}/blocks/{doc_id}/children
body {"children": [<block>], "index": N}          # index:-1 appends
# Delete: the range must live in the JSON body, not the query string
DELETE /open-apis/docx/v1/documents/{doc}/blocks/{parent}/children/batch_delete
body {"start_index": 0, "end_index": n}
```

Invalid forms to stop trying: `{"replace_heading3": …}` → `1770001`; `PUT` on the same path → `404`.

**Style-preserving replacement (rich-text blocks)**
Fetch the block, `deepcopy` its elements, change only `text_run.content`, then PATCH the whole element array back — existing runs keep their bold/italic/link styles instead of being flattened.
Whitespace often straddles runs (run A ends with a space, run B starts with a letter): scan **adjacent run pairs** and trim at that boundary. Keep the space in cases like `5 V` / `12 TOPS` (`prev.isdigit() and nxt.isalpha()`).
When italicising identifiers, always read back: naive regex matches words inside other words (`Enter` inside `Enterprise`), and whole-paragraph runs can go italic by accident.

**5. Publish markdown**

1. Create an empty document: `POST /docx/v1/documents {"title": …}`
2. Parse the markdown into blocks: `#/##/###` → heading 3/4/5, `> ` → quote, `- [ ]` / `- [x]` → todo (with `done`), `- ` → bullet, `1. ` → ordered, `---` → divider, tables → native tables, everything else → text
3. Write in batches: `POST /docx/v1/documents/{doc}/blocks/{doc}/children`, ≤ 40 blocks per call, `index:-1`
4. Set link sharing: `PATCH /drive/v1/permissions/{doc_id}/public?type=docx` → `tenant_readable`
5. Add the human as a collaborator (below) so they can move it into their own space without copy-paste

Do **not** use `upload_all` + `import_tasks` (repeated `1061002 params error`).

**6. Wiki nodes and archiving**

```bash
# Create (obj_type MUST be the string enum, e.g. "docx"; a number → 99992402 field validation failed)
POST /wiki/v2/spaces/{space_id}/nodes
body {"obj_type": "docx", "node_type": "origin", "parent_node_token": <parent>, "title": …}
# Move within a space (node_token is unchanged → existing links keep working)
POST /wiki/v2/spaces/{space_id}/nodes/{node_token}/move
body {"target_parent_token": "<parent>", "target_space_id": "<space_id>"}
# Rename / list children (page_size > 50 → 131002)
POST /wiki/v2/spaces/{space_id}/nodes/{node_token}/update_title   body {"title": …}
GET  /wiki/v2/spaces/{space_id}/nodes?parent_node_token=<pid>
# Delete: node-level DELETE usually has no permission; delete the underlying docx instead
DELETE /drive/v1/files/{obj_token}?type=docx        # async, returns task_id
```

Archive folders are **per day** (`YYYY-MMDD`, derived from a `--date` argument, created on demand). A wiki URL may point at the root of a whole tree (`has_child=true`, little content) — call `get_node`, list children, and decide whether you're looking at one page or a tree entry before acting.
Deleting a folder docx makes its children bounce back to the parent directory root; they are not deleted with it.
**Don't use wiki nodes as API probes** — create a plain docx for testing and delete it afterwards.

**7. Permissions and sharing (after creating)**

```bash
PATCH /drive/v1/permissions/{token}/public?type=docx
body {"link_share_entity":"tenant_readable","external_access_entity":"open","comment_entity":"anyone_can_view"}
POST /drive/v1/permissions/{token}/members?type=docx
body {"member_type":"openid","member_id":"ou_<open_id>","perm":"full_access"}
```

The user's `open_id` can be read from `metas/owner_id` of any document they own. Granting `full_access` lets them move or delete the report in the UI — no copy-paste needed.
For bitables the same endpoint takes `?type=bitable`; the **share panel cannot find an app by default** — switch to the "Bots / Apps" tab. Writing a base requires full_access (read-only collaborators get `91403 Forbidden` on renames and `batch_create`).

**8. Verify after writing (never trust a script's own narration)**
Page through the blocks again (`has_more` loop — a single page of 500 is not the total) and compare with the local parse: **the number of table blocks (`block_type == 31`) must match**, the top-level last block should not be a table, and top-level blocks should equal parsed blocks + tables.

## Block types (docx children, create and read use the same numbers)

| type | block | notes |
|---|---|---|
| 1 | page (root; block_id == document_id) | — |
| 2 | text | `{"block_type":2,"text":{"elements":[{"text_run":{"content":"…"}}]}}` |
| 3–7 | heading 1–5 | same shape, key `heading1`…`heading5` |
| 12 / 13 | bullet / ordered | keys `bullet` / `ordered` |
| 14 | code | `style.language` |
| 15 | quote | key `quote` |
| 17 | todo | `"style":{"done":true|false}` |
| 19 / 34 | callout / quote container | content lives in child blocks |
| 27 | image | never rewrite or delete |
| 30 | embedded sheet | convert to a native table where policy requires it |
| 31 / 32 | native table / table cell | cells are block type 32 |

Whether a "Note: …" line is already styled correctly depends on its **parent**: bt19/bt34 means it is already a callout/quote container; only bare text whose parent is the page root needs converting.

## Markdown → Feishu rendering (what the parser accepts)

| Markdown | Feishu block | Note |
|---|---|---|
| `#` … `####` | heading 1–4 | deeper levels fall back to text |
| `> text` | quote | one block per line — good for date/scope/basis headers |
| `- [ ]` / `- [x]` | todo | checkable in the UI; doubles as a work queue |
| `- ` / `* ` / `1. ` | bullet / ordered | |
| `---` | divider | |
| fenced code block | code | multi-line content in a single `text_run` with `\n` works |
| `\| a \| b \|` + separator | native table | **max 9 rows including the header**; longer tables are split with the header repeated |
| `**bold**`, `` `code` ``, `[text](url)` | inline styles / link | URLs are percent-encoded automatically |

- **Column widths must be computed**: omit `column_width` and every column defaults to 100px. Measure content (CJK = 2 units, Latin = 1, ≈ 7px per unit + 16px padding), give short columns a minimum, let wide columns share the remainder, and keep the total near the document body width.
- Cell content lives in an auto-created empty text block inside the cell — edit that with `PATCH /blocks/{cell_inner_block_id}` + `update_text_elements`. Posting a new block into a cell adds a stray empty paragraph.
- **Never nest code fences in markdown**: the parser treats the first fenced line as an opening fence and the next fenced line as its close, so an inner fence closes the outer block early and everything after degrades to plain text.
- Pre-parse locally before publishing: count block types and flag any text block whose content holds a fence marker — that means a broken fence, so don't publish yet.

## Error codes

| Code | Meaning | Action |
|---|---|---|
| 131006 | node permission denied | add the app as a collaborator (share panel → "Bots" tab), or as a wiki space member for node creation |
| 1770032 | forbidden on a docx write | collaborator permission is read-only → raise to edit/manage |
| 99991672 | scope not granted (e.g. `wiki:wiki`, `wiki:node`) | the error message includes a one-click authorisation link for the app |
| 99992402 | field validation failed | usually a wrong enum type (the error lists the accepted options) |
| 131002 | page_size too large | node listing caps at 50 |
| 1770001 | invalid param | e.g. a table exceeding 9 rows, or an unsupported JSON shape |
| 1254061 | NumberFieldConvFail | bitable numbers read back as strings — cast with `int()` before `batch_create` |

## Pitfalls

- **A wiki token is not a document id** — resolve with `get_node` first.
- **`obj_type` must be a string enum** (`"docx"`), not a number.
- **App-created documents belong to the app**: grant the human `full_access` via `open_id`, then they can move them into their own knowledge base.
- **Share panel hides bots**: switch tabs before searching for the app name.
- **Permission layers differ**: document collaborator ≠ space member; wiki node creation needs space membership (manage), bitable writes need base manage.
- **Table limits**: 9 rows including the header, width computed by hand, and `header_row: true` is valid inside `property`.
- **Deleting blocks**: the index range belongs in the JSON body.
- **Posting new blocks into a cell** creates an extra empty paragraph — patch the existing inner block instead.
- **Don't use wiki nodes as test probes**; they are hard to delete.
- **Checksum the round trip**: re-read the document and compare counts rather than trusting the publishing script.
- **Windows/git-bash**: a bare API URL gets path-rewritten by MSYS (`404`) → prefix `MSYS_NO_PATHCONV=1`; scripts printing non-ASCII should set `PYTHONIOENCODING=utf-8` or `sys.stdout.reconfigure(encoding='utf-8')`.
- **One call, one document** for long publishes; use a background handle with completion notification instead of blocking.

## Verification

- [ ] Block and table counts read back from the cloud match the local parse; the last top-level block is not a table
- [ ] Re-publishing to the same target is idempotent (URL and node title unchanged)
- [ ] Permission failures are distinguished correctly (131006 vs 1770032 vs 99991672)
- [ ] No tokens, internal identifiers, or credentials appear in documents, scripts, or logs
- [ ] Test artifacts deleted afterwards (plain docx, not wiki nodes)
