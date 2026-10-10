# docx/wiki REST 实测格式（2026-09 Hermes 会话验证）

直接写飞书 docx + wiki 节点时用到的 REST 端点与 body，全部经实测确认。
飞书 CLI 不可用时照此裸调。token = tenant_access_token（见各脚本 load_env/get_token）。

## 块内容更新（标题/正文/bullet）——唯一可用形式

- 端点：`PATCH /open-apis/docx/v1/documents/{doc_id}/blocks/{block_id}`
- body：`{"update_text_elements": {"elements": [{"text_run": {"content": "新全文"}}]}}`
- 适用于 heading1-9、text、bullet、quote、todo（更新后块类型不变）。
- **代码块（bt14）同样适用**（2026-09-17 实测 23 块全成功）：整组 elements 回写后
  `code.style.language` 与块类型均保留，无需 block_replace 重建块。
  补换行 = 插入 `{"text_run": {"content": "\n"}}`（新建换行 run 不给 text_element_style 即可）。
- **无效形式**：`replace_heading3`（1770001 invalid param）、PUT 同路径（404）。勿再尝试。
- 富文本块（多 run、含加粗/链接）：先 GET 该块拿完整 elements，deep-copy 后只改
  `text_run.content`，整组 elements PATCH 回去——样式 run 结构保留，不会拍平。
- 跨 run 边界清理（如汉英空格恰在 run 交界）：拼接全文定位后，对相邻 run 对
  （前 run 末尾空格 / 后 run 开头空格）分别截改再整组写回。

## 在指定位置插入块（列表项补漏等）

1. `GET /open-apis/docx/v1/documents/{doc_id}/blocks?page_size=500`，筛
   `parent_id == doc_id` 得顶层块顺序（index）。
2. `POST /open-apis/docx/v1/documents/{doc_id}/blocks/{doc_id}/children`
   body `{"children": [<新块>], "index": N}` → 插到原 index N 处（实测：锚点块 index=13，
   `index:14` 正确落在 13 与 15 之间）。新块 id 在 `data.children[0].block_id`。

## wiki 节点（知识库归档链路）

- 建节点：`POST /open-apis/wiki/v2/spaces/{space_id}/nodes`
  body `{"obj_type": "docx", "node_type": "origin", "parent_node_token": <父>, "title": ...}`
  **`obj_type` 必须传字符串 "docx"**；数字 22 → field validation failed。
  返回 `data.node.obj_token`（= docx document_id，后续写块用它）、`node_token`
  （URL = `https://<tenant>.feishu.cn/wiki/{node_token}`）。
- 列子节点：`GET /open-apis/wiki/v2/spaces/{space_id}/nodes?parent_node_token=<pid>&page_size=50`
  （page_size >50 会被拒）。items 含 title/obj_type/has_child/node_token。
- 解析 wiki token：`GET /open-apis/wiki/v2/spaces/get_node?token=<wiki_token>`
  → `data.node`：obj_token/obj_type/space_id/title/has_child。
- **坑：wiki URL 可能是整棵文档树的根**（has_child=true，本会话 <root_node_token>… 即根，
  中英各 ~60 篇子文档）。拿到链接先 get_node + 列子节点判断是单篇还是树根；
  树根本身几乎无内容，通常从「导读」(<overview_node_token>) 或英文
  Overview 开始。
- 归档模式：报告发布到专用知识库根下 `YYYY-MMDD` 目录节点（不存在则先建目录节点再
  建报告节点），实现按天归档。
- 分享与协作者（建节点后必做两步）：
  `PATCH /drive/v1/permissions/{token}/public?type=docx` body
  `{"link_share_entity":"tenant_readable","external_access_entity":"open","comment_entity":"anyone_can_view"}`
  `POST /drive/v1/permissions/{token}/members?type=docx` body
  `{"member_type":"openid","member_id":"ou_…","perm":"full_access"}`（用户本人拿管理权，
  可在 UI 里把报告移进自己的知识库/删除，无需复制粘贴）。

## 权限错误码速查

- 131006 node permission denied：应用对该 wiki 节点/文档无读权限 → 让用户在文档
  分享面板把机器人应用（切「机器人」tab 才搜得到）加成可编辑/可管理。
- 1770032 forbidden（docx 写操作）：能读不能写，协作者权限只是「可阅读」→ 提升为
  可编辑/可管理。
- wiki 跨空间移动节点（move API）会因源空间父节点无权限失败；同空间移动可行。
