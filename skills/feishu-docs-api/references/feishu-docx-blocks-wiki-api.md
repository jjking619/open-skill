# 飞书 docx 块类型编号 / 报告上云 / wiki 节点创建（实测 2026-09）

来源：md 上云 + wiki 节点创建实测（REST + tenant_access_token，无 CLI 环境）。

## 1. docx children 块类型编号（创建与读回一致，写 children 用 JSON key=类型名）

| block_type | 类型 | 写入 JSON 要点 |
|---|---|---|
| 1 | page（文档根，block_id=document_id） | — |
| 2 | text | `{"block_type":2,"text":{"elements":[{"text_run":{"content":"..."}}]}}` |
| 3/4/5/6/7 | heading1/2/3/4/5 | 同 text 结构，key 换 heading1…heading5 |
| 12 | bullet | key `bullet` |
| 13 | ordered | key `ordered`（步骤列表） |
| 14 | code | key `code`，style.language 有值 |
| 15 | quote | key `quote` |
| 17 | todo（勾选） | key `todo`，`"style":{"done":true|false}` |
| 19 | callout 高亮块 | 有 emoji_id/背景色；内容是其子块 |
| 27 | image | 不写不改（安全规则：绝不 block_replace/delete） |
| 30 | **sheet（嵌入式电子表格）** | `"sheet":{"token":"<spreadsheetToken_sheetId>"}`——建议转成原生表格 |
| 31 | table（原生表格，合规） | `"table":{"cells":[cell_block_ids...]}`，cell 是 bt32 |
| 32 | table_cell | 表格单元格容器 |
| 34 | quote_container（引用容器） | 提示内容常挂在 bt19/bt34 下 |

**判断"提示：xxx"是否合规**：看其父块——父是 bt19(callout)/bt34(quote_container) = 已是高亮/引用容器，**不要**转 Note:tips；只有父是 bt1(页面根) 的裸文本才需要转成高亮块。

## 2. md 上云：md → 飞书 docx（已验证路线）

- **不要走** upload_all + import_tasks（实测 1061002 params error 反复失败）。
- **可靠路线**：
  1. `POST /docx/v1/documents {"title": ...}` 创建空文档
  2. 解析 md → 块数组：`#/##/###`→heading 3/4/5；`> `→quote(15)；`- [ ]/- [x]`→todo(17, done 对应)；`- `→bullet(12)；其余→text(2)
  3. `POST /docx/v1/documents/{doc}/blocks/{doc}/children` 批量写入，每批 ≤40 块，`index:-1` 追加
  4. `PATCH /drive/v1/permissions/{doc_id}/public?type=docx` → tenant_readable
  5. 加用户协作者（见 §3）→ 输出 `https://<tenant>.feishu.cn/docx/{doc_id}`

## 3. 让用户能把报告放进自己的 wiki（免复制粘贴）

应用创建的文档归应用；用户要"移动到知识库"需对该文档有管理权。发布后立即：

```
POST /drive/v1/permissions/{doc_id}/members?type=docx
  {"member_type": "openid", "member_id": "<用户open_id ou_...>", "perm": "full_access"}
```

用户 open_id 从任意其名下文档的 metas/owner_id 拿（`ou_` 开头，如 ou_<open_id>）。脚本默认值可用 `REPORT_OWNER_OPENID` 环境变量覆盖。用户随后在飞书里"移动到知识库/添加到知识库"即可，无需复制内容。

## 4. wiki 节点解析与创建（2026-09 实测，含坑）

- 解析 wiki URL → 底层 obj / space：
  - `POST /drive/v1/metas/batch_query {"request_docs":[{"doc_token":"<wiki token>","doc_type":"wiki"}]}` → `data.metas[0].obj_token/title`
  - 或 `GET /wiki/v2/spaces/get_node?token=<wiki token>` → `data.node.{space_id,obj_token,title,parent_node_token}`
- **创建节点** `POST /wiki/v2/spaces/{space_id}/nodes`：
  - `obj_type` 必须传**字符串枚举名**（`"docx"`/`"bitable"`/`"sheet"`/`"mindnote"`...）；传数字（如 22）报 99992402 field validation failed，field_violations 会写明 options
  - 需**空间级编辑权限**；缺 → 131006 "tenant needs edit permission"。文档级协作者 ≠ 空间成员：应用必须被加进知识库空间的成员管理（或空间链接分享=组织内可编辑），只分享单个文档不生效
- get_node 需 wiki scope：`wiki:wiki` / `wiki:wiki:readonly` / `wiki:node:read`；未开通 → 99991672，报错信息自带一键授权链接 `open.feishu.cn/app/<app_id>/auth?q=...`

## 5. bitable 应用授权模型（给 Base 配字段/写记录前必读）

- 分享面板搜应用：默认搜"成员（人）"**搜不到应用/机器人** → 必须切「机器人/应用」tab 再搜应用名
- 应用写 Base（字段增删改、batch_create）需协作者权限 ≥ **可管理(full_access)**；只给「可阅读」时读通、写全 403（91403 Forbidden，rename field/batch_create/update app 全部 403）
- 加协作者 API：`POST /drive/v1/permissions/{app_token}/members?type=bitable`，member_type 可用 `openid`/`appid`/`email`（user_id 纯数字格式实测 field validation failed，改用 openid）
- 应用自己创建的 Base 天然 full_access；用户自建 Base 需上述两步（机器人 tab + 可管理）才能被应用 API 写
