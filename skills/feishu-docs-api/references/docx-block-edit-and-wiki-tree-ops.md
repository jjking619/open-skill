# docx 块编辑 + wiki 树操作 + bitable 数据迁移（REST 实测 2026-09）

来源：某文档修改模式全流程（标题序号删除/汉英空格清理/登陆→登录/标识符斜体）
+ 多维表格（Base）跨知识库搬迁。Hermes 环境无 飞书 CLI，全部 REST + tenant_access_token。

## 1. docx 块编辑（改现有块内容，核心发现）

**唯一可用端点**：`PATCH /docx/v1/documents/{doc}/blocks/{block_id}`
body：`{"update_text_elements": {"elements": [{"text_run": {"content": "..."}}]}}`

- 对 **text(2)、heading3(5) 等一律生效**——heading 改内容也用 update_text_elements
- **PUT 同端点 = 404**；`{"replace_heading3": ...}` = 1770001 invalid param（不要用）
- 标题去手动序号（"1.1 什么是 XX？"→"什么是 XX？"）= 直接 update_text_elements
- **写权限**：应用需文档协作者且 ≥ 可编辑；只有读权限时 PATCH 返回 1770032 Forbidden
  （分享面板改权限即可，无需重新发布应用版本）

### 保留样式的文本替换（富文本块必备）

块内是多个 run（text_run 带 text_element_style: bold/italic/link...）。正确流程：

1. `GET /docx/v1/documents/{doc}/blocks/{bid}` 取原始 elements
2. 对每个 element `copy.deepcopy`，**只改** `text_run.content`，其余样式原样保留
3. PATCH 回去 update_text_elements（可跨 run 重组：一段文字拆成多 run，各带各的样式）

### 跨 run 边界问题（汉英空格清理踩过的坑）

空格常跨 run 分布：run A 以空格结尾 + run B 以汉字/字母开头。单 run 内正则扫不到，
必须**扫描相邻 run 对**：A 尾字符与 B 首字符构成 汉字+空格+字母（或反之）即删 A 尾空格/B 首空格。
保留特例：数字+单位间空格（"5 V/5 A"、"12 TOPS"）不删——判据 prev.isdigit() and nxt.isalpha()。

### 标识符斜体——正则误伤教训

对整段匹配标识符列表并 split run 设 italic=true 后，**必须回读抽查**。实测误伤：
- `Enter` 命中 "Enterprise" → 拆成 "[Enter]prise" 破坏单词 → 标识符正则要带词边界或更长上下文
- 整段被一起斜体（root 段连带"提示："）→ 需把标识符独立成 run、其余 run 保持非斜体
修复 = 重读块、重建 run 序列（标识符 italic=true、其余 false）PATCH 回去。

## 2. wiki 节点树操作（按天归档，实测）

- **同空间移动节点**：`POST /wiki/v2/spaces/{space_id}/nodes/{node_token}/move`
  body `{"target_parent_token": "<目标父节点>"}` —— 报告移入归档目录用这个
- **跨空间移动**：应用对源空间父节点无编辑权时 → 131006 "no source parent node permission"。
  应用自建 Base 搬库走不通 move，改用：新空间创建 bitable 节点 + 数据复制（见 §3）
- **删除 wiki docx 节点**：wiki 节点 DELETE 要 obj_type 参数易报错；直接
  `DELETE /drive/v1/files/{obj_token}?type=docx`（obj_token 是底层 doc id，异步删除，返回 task_id）
- **删父节点副作用**：删除归档目录 docx 后，其下报告会**弹回父目录根**（不会一起删），需重建目录再移回
- **列出子节点**：`GET /wiki/v2/spaces/{space_id}/nodes?parent_node_token={pid}`，
  **page_size 上限 50**（传 100 → 131002）
- **节点创建返回**：`node.obj_token` = 底层 docx id（写内容用），`node.node_token` = wiki 链接 id
- **归档目录自动创建模式**：发布前找/建标题=YYYY-MMDD 的子节点（get_or_create_archive_dir），报告建其下

### 文档树根节点识别

用户贴 wiki URL 可能指向**整棵树的根/汇总页**（内容块很少 + has_child=true）——先 `get_node`
看 has_child + 列子节点树（get_node 返回 space_id 后可递归 list），确认是单篇还是树入口，
再决定处理哪篇（可按「导读 → 正文 → …」的既有顺序推进）。

## 3. bitable 数据迁移/结构操作（Base 搬库实测）

- **数字字段读回是字符串**（"21" 不是 21）：从旧 Base 复制记录到新 Base 时，发现问题数/已修正数
  等字段必须 `int()` 转换，否则 batch_create → 1254061 NumberFieldConvFail
- **表改名 = PATCH 不是 PUT**：`PATCH /bitable/v1/apps/{app}/tables/{table_id}` body `{"name": ...}`
  （PUT → 404）
- **新建表必须带 ≥1 字段**：`POST /bitable/v1/apps/{app}/tables` body
  `{"table": {"name": ..., "default_view_name": ..., "fields": [{"field_name": ..., "type": 1}]}}`
  （fields 空数组会报错）
- **新 Base/新表自带空行**（默认 5 行左右）：数据迁入后按主键字段为空批量删除
  `batch_delete {"records": [...]}`，否则表格里出现幽灵空行
- 建子表默认字段：Text(主键)/Single option/Date/Attachment——先重命名/改造主键为文档名，
  单选字段改状态、Date 字段改时间戳(date_formatter `yyyy/MM/dd HH:mm`，便于区分同日多轮)、删附件字段

## 4. 权限链路速查（机器人应用）

- wiki 读：需 wiki scope（wiki:wiki/wiki:wiki:readonly/wiki:node:read）+ 文档级协作者
- wiki 建节点：需**知识库空间成员(可管理)**，文档级协作者不够（131006）
- docx 直写：文档协作者 ≥ 可编辑
- bitable 写：Base 协作者 ≥ 可管理(full_access)；分享面板搜应用要切「机器人」tab
- 用户 open_id 取法：任意用户名下文档 metas/owner_id（ou_ 开头）
