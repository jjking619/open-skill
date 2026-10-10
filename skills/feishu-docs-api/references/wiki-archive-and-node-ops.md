# 报告归档目录 + 知识库节点运维（2026-09-10 实测）

> 本文件**更正** `docx-block-edit-and-wiki-tree-ops.md` §2 里两条旧记录：
> 「归档目录=YYYY-MM（`get_or_create_month_dir`）」和「删 wiki 节点靠人前端操作」。
> 现状：函数已改名 `get_or_create_archive_dir`，目录按**天**；节点删除有可用通道（见下）。

## 归档目录：按天，不按月

- 目录标题 = `YYYY-MMDD`（如 `2026-0905`），由发布脚本的 `--date` 推导
  （`2026-09-05` → `2026-0905`：`day[:7] + day[8:10]`），不传 `--date` 用当天；不存在自动建。
- 同一天的报告放同一层（如 `2026-0905` 下放多份检查报告与 1 份全库专项清单）。
- **为什么不能按月**：月目录（`2026-09`）粒度太粗，同批报告会被拆到两层；用户会直接指出
  「今天 2026-09-10，怎么只有 2026-09」。判据：目录名要能一眼看出是哪天出的。
- 建错粒度后的补救：把报告 `move` 到正确目录（URL 不变），旧目录弃用；删不掉就改名标「可删」。

## 节点命名约定（树内）

- `[文档名] 报告类型`，如 `[某文档] 检查报告`、`[某文档] 检查报告（修改模式）`
- 全库专项：`[全库] 专项名`，如 `[全库] 代码块命令粘连问题清单`
- **节点名取报告 md 的 H1** → 写报告时就把 H1 写成这个格式，树内名与文档内标题天然一致；
  已建节点改名用下面的 update_title，改完树和文档内 H1 要一起改（H1 是文档块，`--doc` 重推即同步）。

## 实测可用的 wiki 节点端点

```text
# 移动（同空间）：只换父节点，node_token 不变 → 已发出去的 wiki 链接继续有效
POST /wiki/v2/spaces/{space_id}/nodes/{node_token}/move
     body {"target_parent_token": "<目标父节点token>", "target_space_id": "<space_id>"}

# 改节点名
POST /wiki/v2/spaces/{space_id}/nodes/{node_token}/update_title
     body {"title": "[全库] 代码块命令粘连问题清单"}

# 列子节点（page_size 上限 50，传 100 → 131002）
GET  /wiki/v2/spaces/{space_id}/nodes?parent_node_token={pid}
```

## 删除：节点级没权限，文档级可以

- 节点级 `DELETE /wiki/v2/spaces/{space_id}/nodes/{node_token}` → `99991672 Access denied`（应用未开通）。
  不要在这条路上反复试参数（`obj_type` 之类的变体同样被拒）。
- 文档级可行：`node.obj_token` 是底层 doc id →
  `DELETE /drive/v1/files/{obj_token}?type=docx`（异步，返回 task_id）。
  注意删掉父目录 docx 后，其下报告会弹回父目录根，不会跟着删。

## 教训：别拿 wiki 节点当 API 探针

测接口/测渲染时建 wiki 节点，事后清不掉（见上），只能留下「可删-TEST探针N」这种垃圾让人手动收拾。
正确做法：`<发布脚本> <md> --no-wiki` 建普通 docx，验证完用
`DELETE /drive/v1/files/{doc_id}?type=docx` 清掉——本会话的表格/代码块/列宽验证全走这条路。

## 相关

- 报告 md 的语法支持、表格 9 行上限、列宽按内容计算、单元格与删块的 API 形态：`references/report-md-to-wiki.md`
- 表格日期字段 formatter 用 `yyyy/MM/dd HH:mm`（只到天会让同日多轮分不出先后）。
