# 飞书 docx 直写：已验证格式与坑（实测汇总）

来源：多轮 REST round-trip 实测（飞书 docx block API）。
Claude Code 环境走 飞书 CLI（`docs +update --command ...`），**XML 内容两者通用**。

## 读

- `docs +fetch --doc <url> --detail full`：样式（斜体/加粗/颜色/链接）机器可读；表格带
  真实结构（colgroup 宽、合并单元格）；whiteboard/bitable 是显式块。
- 块级操作后旧 block id 可能失效 —— 再操作前重新 fetch。
- 成功判据：stdout `ok == true`，不是 `code` 字段。

## 写命令映射

| 操作 | 飞书 CLI | REST 等价 |
|------|----------|-----------|
| 行内替换（跨样式 run 匹配纯文本） | `docs +update --command str_replace` | docx block 文本更新（替换文本会拍平样式，须重建标签） |
| 整块重写 | `--command block_replace` | PATCH blocks/{block_id} |
| 删除/插入 | `--command block_delete` / `block_insert_after` | DELETE / PATCH 锚定块 |
| li 子块创建（唯一通路） | `MSYS_NO_PATHCONV=1 飞书 CLI api POST "/open-apis/docx/v1/documents/<doc_id>/blocks/<li_block_id>/children" --params '{"document_revision_id":-1}' --data @temp_children.json` | 同路径 REST |
| 富文本子块 | 先建纯文本占位子块拿 id，再 block_replace 写入富文本 XML | 同 |

## 已验证的块 XML 格式

- **表格**：`<table><colgroup><col width="…"/>…</colgroup><thead><tr><th><p>标题</p></th>…</tr></thead><tbody><tr><td><p>内容</p></td>…</tr></tbody></table>`。
  表头 `<th>` 自动加粗（勿加 `<b>`）；**列宽之和必须 = 820**（满页宽）；
  支持单元格内 `<em>` 斜体、`<br/>` 换行、空单元格 `<td><p></p></td>`、合并单元格
  （`colspan`/`rowspan` 只写在首个单元格，被合并掉的格省略）。
- **Note:tips**：单列表格 `<colgroup><col width="820"/></colgroup>`，表头格
  `<th><p><span text-color="rgb(36,91,219)">Note:tips</span></p></th>`，内容行普通 `<td>`。
- **代码块**：`<pre lang="C"><code>…</code></pre>`，`<code>` 内用字面换行。
- **行内嵌套序（外→内）**：`<a>` → `<b>` → `<em>` → `<span>`；斜体跳转链接 `<a href="…"><em>类型名</em></a>`。
- **颜色无损读写**：`<span text-color="rgb(r,g,b)">`。版权行 = 加粗+斜体+灰
  `rgb(143,149,158)`：`<p><b><em><span text-color="rgb(143,149,158)">…</span></em></b></p>`。
- **li 子块结构**：fetch 读出 `<li><b>功能描述</b><p id="…">正文</p></li>` —— 正文是 li 的
  **子块**，渲染为列表项下缩进正文。children API body：
  `{"index":0,"children":[{"block_type":2,"text":{"elements":[{"text_run":{"content":"…"}}],"style":{}}},…]}`，
  一次可建多行按序落位。

## 致命坑（每个都出过事故）

1. **绝不 `block_replace` 带子块的 `<li>`** —— 子块被连带删除（历史事故「正文被并进列表项」即由此而来）。
   要素标签/li 行内文字用 str_replace（子块保留）；正文修改针对**子块自身 id** 操作。
2. **str_replace 跨样式 run 匹配会拍平原加粗/链接** —— 替换范围覆盖加粗/链接文字时，
   替换内容必须显式重建 `<b>`/`<a>`，或改用 block_replace 整块重写。
3. **替换内容含富文本标签可能乱序落位**（实测 `<b>Q：<em>evtest</em>…</b>` 渲染成
   evtest 跑到 Q 前面）—— 写后必须回读验证，错了 block_replace 整段重写。
4. **block_replace 标题后，指向它的 #share- 锚点全部失效** —— 调标题层级后重建站内跳转：
   fetch outline 拿新块 id，改 `文档URL#<新块id>` 直达链接并逐一验证。
5. **li 内嵌 `<p>` 无法用 XML/Markdown 内容写入创建**（block_replace/整篇导入/Markdown
   缩进一律被拍平）；`block_insert_after` 锚定 li 只会插到页面层级拆开列表。
   「<br/> 软换行并行方案」已被用户否决（渲染挤成一团）——唯一通路是原生 children API。
6. **Git Bash 裸调 API URL 被 MSYS 路径改写** → 404。必须 `MSYS_NO_PATHCONV=1`。
7. **命令行传中文参数偶发 UTF-8 损坏**（曾把「获取」写坏进文档）——批量修改写成 UTF-8
   `.py`/`.sh` 文件再执行；写后扫代理对（surrogates）确认无坏字符。
8. **Windows 控制台 GBK**：任何打印中文的 Python 先
   `import sys; sys.stdout.reconfigure(encoding='utf-8')`；勿用 `python -c` 内联中文路径。
9. sheet 块转换：先读 sheet 值 → `block_insert_after` 插原生表格 → **验证表格落位后才删
   sheet 块**；含图片列的表格无法转换，列 ⚠️ 需确认。

## 自动链接 pass（页内跳转，永远最后做）

先写无链接的正文修正，最后统一跑：fetch `--scope outline` 建 类型名→heading block id 映射，
对每个未链接的 `详见<类型名>` 做 str_replace 成 `<a href="<doc_url>#<heading_block_id>"><em>类型名</em></a>`。
顺序固定可避免 详见 模式歧义。

## 验收惯例

回读改动段 `--detail full` 确认样式落位（单元格内斜体/`<br/>`/链接/colgroup 宽），漏的补；
**不要再给用户列「重加斜体/换 <br>/补链接/重插图」类手动项** —— 直写后这些都已持久，属过时清单。
