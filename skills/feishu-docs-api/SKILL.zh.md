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

- 应用凭据 `FEISHU_APP_ID` / `FEISHU_APP_SECRET`（环境变量或 `~/.env` 文件）→ 换 `tenant_access_token`
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

## 附录：关键格式速查（内联）

### 块类型编号（docx children，创建与读回一致）

| block_type | 类型 | 说明 |
|---|---|---|
| 1 | page（文档根，block_id == document_id） | — |
| 2 | text | `{"block_type":2,"text":{"elements":[{"text_run":{"content":"…"}}]}}` |
| 3–7 | heading 1–5 | 同 text 结构，key 换 `heading1`…`heading5` |
| 12 / 13 | bullet / ordered | key `bullet` / `ordered` |
| 14 | code | `style.language` |
| 15 | quote | key `quote` |
| 17 | todo | `"style":{"done":true\|false}` |
| 19 / 34 | callout / quote_container | 内容在其子块 |
| 27 | image | 绝不改写或删除 |
| 30 | 嵌入式 sheet | 按需转成原生表格 |
| 31 / 32 | 原生表格 / 表格单元格 | 单元格是 bt32 |

「提示：xxx」是否合规范，看它的**父块**：父是 bt19/bt34 说明已是高亮/引用容器；只有父是页面根的裸文本才需要转。

### 常用端点

| 动作 | 端点 |
|---|---|
| 取 token | `POST /open-apis/auth/v3/tenant_access_token/internal` |
| 解析 wiki 链接 | `GET /wiki/v2/spaces/get_node?token=<wiki_token>` → `data.node.obj_token` |
| 读块（分页） | `GET /docx/v1/documents/{doc}/blocks?page_size=500&document_revision_id=-1` |
| 改块文本 | `PATCH /docx/v1/documents/{doc}/blocks/{block_id}` + `update_text_elements` |
| 插块 / 删块 | `POST` / `DELETE /docx/v1/documents/{doc}/blocks/{parent}/children`（删块区间必须放 JSON body） |
| 建 wiki 节点 | `POST /wiki/v2/spaces/{space_id}/nodes`（`obj_type` 传字符串 `"docx"`） |
| 移动 / 改名节点 | `…/nodes/{node_token}/move`、`…/nodes/{node_token}/update_title` |
| 删文档 | `DELETE /drive/v1/files/{obj_token}?type=docx`（异步，返回 task_id） |
| 共享与协作者 | `PATCH /drive/v1/permissions/{token}/public?type=docx`、`POST …/members?type=docx` |

无效写法（别再试）：`{"replace_heading3": …}` → 1770001；同路径 `PUT` → 404。

保留样式的替换：先 GET 取完整 elements，deepcopy 后只改 `text_run.content`，整组 PATCH 回去。空格常跨 run 分布（run A 尾空格 / run B 首空格）→ 扫**相邻 run 对**再截；`5 V`、`12 TOPS` 这类数字+单位之间的空格要保留。标识符斜体必须回读抽查（正则会把 `Enter` 命中 `Enterprise` 内部）。

### md → 飞书渲染要点

- 支持：`#`~`####` 标题、`> ` 引用、`- [ ]` / `- [x]` 待办、`- ` `* ` `1. ` 列表、`---` 分隔线、围栏代码块、表格、`**粗体**`、`` `行内代码` ``、`[文字](URL)`
- **单表上限 9 行（含表头）**，超出报 1770001；解析器会自动拆表并重复表头
- **列宽要自己算**：不传 `column_width` 时飞书默认每列 100px（总宽 500）；按内容算（CJK 记 2 单位、西文 1 单位，约 7px/单位 + 16px 内边距），总和贴近正文宽度
- 单元格内容 = 飞书为每个单元格自动建的空文本块，改它用 `PATCH /blocks/{cell_inner_block_id}`；往单元格 POST 新块会多出一个空段落
- **不要在 md 里嵌套代码围栏**：解析器按「首个围栏行开、下一个围栏行闭」朴素匹配，内层围栏会让外层提前闭合，其后内容全部退化为纯文本
- 发布前先在本地解析一遍：统计块型、并检查是否有文本块内容里含围栏标记（有 = 围栏破损，别推）

### 错误码速查

| 码 | 含义 | 处置 |
|---|---|---|
| 131006 | 节点/文档无权限 | 分享面板切「机器人」tab 把应用加成可编辑；建节点需知识库空间成员 |
| 1770032 | docx 写操作被拒 | 协作者权限只是「可阅读」→ 提到可编辑/可管理 |
| 99991672 | scope 未开通（如 wiki:wiki） | 报错里自带一键授权链接 |
| 99992402 | 字段校验失败 | 多为枚举类型传错（报错会列出可选值） |
| 131002 | page_size 超限 | 节点列表上限 50 |
| 1770001 | invalid param | 例如表格超过 9 行 |
| 1254061 | NumberFieldConvFail | bitable 数字字段读回是字符串，`batch_create` 前 `int()` 转换 |

### 写后核对（别信脚本自述）

回读**分页**块数（按 `has_more` 循环，别把单页 500 当总数），与本地解析结果比对：**表格块数（`block_type == 31`）必须相等**；顶层块末块不应停在表格上；顶层块数 = 解析块总数 + 表格数。
