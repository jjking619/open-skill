# 发布前仓库审计（Pre-publish Repo Audit）

**公开是不可逆的**：一旦推上去，历史、缓存、被下载的副本都收不回来。所以顺序永远是
**先判定 → 先扫描 → 再看用户态度 → 最后才推**，绝不「先推了再说」。

## 何时使用（When to Use）

- 把私有仓库改成公开、把内部工具开源、把仓库交给第三方/客户
- 把技能、模板、文档集对外发布（含发布到 skills / plugin 目录）
- 例行检查：定期确认公开仓里没有夹带内部信息
- 不适用：纯内网私有仓的日常提交

## 门禁三步（Gate）

**① 可见性判定（先看清现状，不用 token）**
```bash
curl -s -o /dev/null -w "%{http_code}\n" https://github.com/<owner>/<repo>   # 404=私有 200=公开
git ls-remote https://github.com/<owner>/<repo> refs/heads/main             # 匿名能拿到 = 公开
curl -s "https://raw.githubusercontent.com/<owner>/<repo>/main/README.md" | head -3   # 能下到内容 = 公开
```
⚠️ **别用不带参数的 raw 结果判定"已私有"**：raw 走 CDN 缓存，改私有后仍可能短时返回旧内容。
加 cache-buster 再测：`.../README.md?cb=$RANDOM$RANDOM` → 404 才说明真的私有生效。

**② 内容扫描（命中即停手）**

密钥与凭据：
```bash
grep -rInE "(api[_-]?key|secret|password|passwd|token)\s*[:=]" . --include='*.py' --include='*.md' --include='*.yaml' --include='*.json' | head -40
git log -p --all -G "(api[_-]?key|secret|password|BEGIN (RSA|EC|OPENSSH )?PRIVATE KEY)" -- '*.py' '*.sh' '*.json' '*.yml' '*.yaml' '*.md' | grep -iE '^\+.*(api[_-]?key|secret|password|token|PRIVATE KEY)' | head -30
```
> 正确姿势：仓库里**只留环境变量名**，值一律来自 `~/.env` 或运行时注入。发现硬编码密钥 → 先撤销/轮换密钥，再清仓库。

内部标识（比密钥更常见）：
```bash
grep -rInoE "[A-Za-z]{2,6}[0-9A-Za-z]{15,}" .        # 长 token（文档/表格/节点 ID）
grep -rInE "<内网域名>|<公司产品线名>|[A-Za-z]:\\\\[^ )\"]+" .   # 内部域名 / 内部盘符路径
grep -rInE "\b(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9.]+" .   # 内网 IP
```
把命中的类型列成清单（token / app id / 内部路径 / 内部域名 / 雇主名 / 个人 handle / 邮箱），
逐项决定「改占位符」还是「整篇不发布」。

卫生检查：
```bash
git ls-files -z | xargs -0 du -h 2>/dev/null | sort -h | tail -15   # 大文件误入库
git log --oneline | head; git log --all --diff-filter=D --name-only | head  # 历史里删过的敏感文件仍在历史
```
`git log -S`/`-G` 能证明「文件现在删了但历史里还在」—— 历史里的敏感内容必须靠重写历史（filter-repo / BFG）或删仓重建解决，
**单纯删文件提交一次不算清除**。

**③ 处置与沟通**
- 命中内部内容且目标是公开 → **停下问用户**，一次把选项摆清（改私有 / 出脱敏另稿 / 只发通用部分 / 确认可公开），不替用户决定。
- 脱敏版**另出副本**，在副本上替换（占位符化），源仓一个字节不动；替换完要**回读线上内容再扫一次**。
- 改私有只能仓库管理员在网页 Settings 操作；改完**复测**（含 cache-buster）确认 404。

## 仓库卫生清单（Hygiene）

| 项 | 判据 |
|---|---|
| LICENSE | 存在且与 README 声明一致（MIT / Apache-2.0 …） |
| README 门面 | 首屏说清是什么、给安装/使用命令；数字类断言（版本、文件数）与目录实况一致 |
| .gitignore | 覆盖 OS/编辑器垃圾、`__pycache__`、构建产物、本地配置、`.env` |
| .gitattributes | `* text=auto eol=lf`（跨平台统一 LF） |
| 提交卫生 | 不提交构建产物与二进制大文件；提交信息可读 |
| 元数据 | topics / 描述 / 默认分支已设置，便于他人在目录站被检索到 |
| 双仓同步 | 私有内部版与公开脱敏版**目录结构同构**，便于增量同步；各自记录「哪些不进公开版」 |

## 坑（Pitfalls）

- **先推后问**：公开仓的推送不可撤回 —— 门禁必须排在 push 之前。
- **只看当前文件、不看历史**：删除过的敏感文件仍在 `git log -p` 里。
- **CDN 缓存误判**：不带 cache-buster 会把「已私有」看成「仍公开」，反之亦然。
- **把密钥改成占位符就算完**：已经暴露过的凭据必须**轮换**，否则等于没处理。
- **只扫代码不扫文档**：内部域名、节点 ID、内部路径最常出现在 md / 示例 / 注释里。
- **只改本地不复扫线上**：push 后要用匿名请求把线上内容抓回来再扫一次。

## 验收（Verification）

- [ ] 可见性判定有明确结论（含 cache-buster 复测）
- [ ] 密钥扫描 0 命中；若有历史残留，已重写历史或轮换凭据
- [ ] 内部标识扫描 0 命中（**本地 + 线上各一次**）
- [ ] 卫生清单逐项打过勾；README 数字与目录实况一致
- [ ] 公开后匿名可访问（`raw` + 仓库页），且内容与本地 commit SHA 一致
