---
name: feishu-docs-api
description: "用 REST API 直写、同步、归档飞书云文档（docx / wiki / bitable）：块读写、md 上云、wiki 节点与归档目录、权限链路、实测坑与写后核对。需要改飞书文档、把 md 同步上云、建知识库节点时使用。"
version: 0.1.0
author: "kane.ji, Hermes Agent"
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [feishu, lark, docx, wiki, bitable, rest, api, 飞书]
---

# 飞书云文档 REST 操作（Feishu Docs API）

把「改飞书文档 / 把 md 同步上云 / 建知识库节点归档 / 读写多维表格」从一次性手工调试变成可复现流程：
**取 token → 解析目标 → 读现状 → 写 → 上云 → 归档 → 写后核对**。
无 CLI 依赖，纯 REST + `tenant_access_token`。

## 何时使用（When to Use）

- 批量修改飞书云文档：标题、正文、列表项、表格、代码块、行内样式
- 把本地 md 发布成飞书 docx，或原地同步进用户指定的既有文档
- 知识库（wiki）节点：解析链接、建节点、移动、改名、按天归档目录
- 读写多维表格（bitable）：字段改造、批量写记录、跨库搬迁
- 不适用：文档内容质检规则（审查类技能）、只读浏览（用飞书客户端）

## 前置（Prerequisites）

- 应用凭据 `FEISHU_APP_ID` / `FEISHU_APP_SECRET`（环境变量或 `~/.hermes/.env`）→ 换 `tenant_access_token`
- 应用必须被加为目标文档 / 知识库空间的协作者，权限不够会返回 131006 / 1770032（见 §4）
- **动手前先探活**：`GET /wiki/v2/spaces/get_node?token=<wiki_token>` 返回 `code=0` 再往下做

## 流程（Procedure）

**1. 取 token**
`POST /open-apis/auth/v3/tenant_access_token/internal`，body `{"app_id":..., "app_secret":...}`。

**2. 解析目标容器**
- wiki 链接 `.../wiki/<node_token>`：`GET /wiki/v2/spaces/get_node?token=<node_token>` → `data.node.obj_token` 才是 docx document_id
- docx 链接 `.../docx/<doc_id>`：直接用
- **wiki token ≠ doc id**，不解析直接写块必失败

**3. 读现状**
`GET /docx/v1/documents/{doc}/blocks?page_size=500&document_revision_id=-1`，按 `has_more` 翻页。
块级改动后旧 block id 可能失效 —— 再操作前重新 fetch。

**4. 写内容**
- 改块文本（标题/正文/列表/代码块通用）：`PATCH /docx/v1/documents/{doc}/blocks/{block_id}`，body `{"update_text_elements": {"elements": [{"text_run": {"content": "..."}}]}}`
- 富文本块（多 run、加粗/链接）：先 GET 拿完整 elements，deep-copy 后只改 `content`，整组写回 → 样式不被拍平
- 插块 / 删块：走 `blocks/{parent}/children`（`index` 定位；删块区间必须放 JSON body）
- 表格单元格：单元格内是独立文本块，改它要 PATCH 该单元格块

**5. md 上云**
本地把 md 解析成块数组（`#`→heading、`> `→quote、`- [ ]`→todo、`- `→bullet、其余→text、表格→原生表格）→ `POST .../blocks/{doc}/children` 批量写入（每批 ≤40 块，`index:-1` 追加）→ 设链接共享 → 加用户为协作者（见 references）。

**6. 归档与节点**
归档目录按**天** `YYYY-MMDD`（由 `--date` 推导，不存在自动建）；建节点
`POST /wiki/v2/spaces/{space_id}/nodes`，`obj_type` 必须是字符串（`"docx"`）。

**7. 写后核对（必做，别信脚本自述）**
分页回读云端块数，与本地解析结果比对：**表格块数（`block_type == 31`）必须相等**；顶层块末块不应停在表格上；顶层块数 = 解析块总数 + 表格数。

## 资产（Assets）

| 文件 | 用法 |
|---|---|
| `references/direct-write-verified-formats.md` | 已验证的块 XML/格式（表格、Note、代码块、颜色、li 子块）与 9 个出过事故的坑 |
| `references/docx-rest-verified.md` | docx / wiki REST 端点与 body 实测；权限错误码速查 |
| `references/feishu-docx-blocks-wiki-api.md` | block_type 编号表、md 上云路线、wiki 节点创建、bitable 授权模型 |
| `references/docx-block-edit-and-wiki-tree-ops.md` | 保留样式的 run 级替换、跨 run 边界、标识符斜体、节点树操作、bitable 迁移 |
| `references/wiki-archive-and-node-ops.md` | 归档目录粒度、节点命名、move / update_title / 删除通道 |
| `references/report-md-to-wiki.md` | md → 飞书块语法支持矩阵、单表 9 行上限、列宽计算、单元格改写 |
| `references/feishu-md-writeback-pitfalls.md` | 围栏嵌套坑、推云前本地自检、写后核对口径修正 |
| `references/sync-md-to-existing-doc.md` | 把 md 原地写进用户指定的既有文档（不建节点、不改标题、幂等） |

## 坑（Pitfalls）

- **wiki token ≠ document_id**：先 `get_node` 解析成 `obj_token` 再写块
- **`obj_type` 必须传字符串枚举名**（`"docx"`），传数字报 field validation failed
- **分享面板默认搜不到机器人**：搜应用要切「机器人 / 应用」tab
- **权限分层**：文档级协作者 ≠ 空间成员；wiki 建节点需空间成员（可管理）；bitable 写需 Base 可管理
- **单表上限 9 行（含表头）**，超出报 1770001；`column_width` 不传时飞书默认每列 100px，需按内容计算
- **md 里不要嵌套代码围栏**：解析器按「首个行首围栏起、下一个行首围栏止」朴素匹配，会提前闭合
- **git-bash / MSYS**：裸调 API URL 会被路径改写（404）→ `MSYS_NO_PATHCONV=1`
- **Windows 控制台 GBK**：打印中文的脚本先 `sys.stdout.reconfigure(encoding='utf-8')`
- **回读必须翻页**：别把单页 500 当总数；`page_size > 50` 的节点列表接口会被拒（131002）
- **凭据不落盘**：token 从环境变量取，别写进脚本默认值、文档或日志

## 验收（Verification）

- [ ] 写后回读：云端块数 / 表格数与本地解析结果一致，末块不在表格上
- [ ] 幂等：对同一目标文档重复同步，URL 与节点名不变
- [ ] 权限异常能区分：131006（无权限）/ 1770032（只读）/ 99991672（scope 未开通）
- [ ] 文档里不出现内部标识与凭据；测试产物用后即删（测试用普通 docx，别用 wiki 节点当探针）
