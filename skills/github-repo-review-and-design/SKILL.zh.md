# GitHub 整仓代码审查 + 仓库文件设计

一个 skill 两大工作流，共享「定位仓库 + 模式判定」前置：

- **Workflow A — 整仓代码审查**：克隆全量分析，输出分级报告。两档模式：
  评估档（第三方仓库，只读给采用建议）/ 发布档（自家仓库，可动手整改到可发布）。
- **Workflow B — 仓库文件设计**：为新项目设计目录树 + 文件职责 + 标准文件要点，
  输出设计文档；对杂乱旧仓库做重组方案；可选直接生成骨架。

## When to Use（何时使用）

- 整仓审查 / 评估：给定 owner/repo、URL 或本地路径，判断代码质量、可用性、合规性
- 选型、学习、二次开发前的整仓评估
- 仓库文件结构设计 / 规划：新项目、新 demo 的目录组织
- 杂乱旧仓库的重组 / 整改方案

不适用（转相关技能）：
- PR/diff 级审查、给 GitHub PR 留行内评论（PR 级审查流程）
- 自己 commit 前的小改动自审（提交前自审流程）
- 只要 LOC/语言统计（本 skill A1 内部也会调它）

## 前置

- `gh` 已认证，或 `GITHUB_TOKEN` 可用（认证细节见 `github-auth` skill）
- git；Python3（个别扫描脚本用）

```bash
gh auth status >/dev/null 2>&1 && echo AUTH=gh || { [ -n "$GITHUB_TOKEN" ] && echo AUTH=token || echo "需要先 gh auth login 或设 GITHUB_TOKEN"; }
```

## Step 0 — 定位仓库 & 模式判定（共用）

1. **定位**：URL 或 owner/repo → 克隆；本地路径 → 直接用。
   ```bash
   # 深审默认：浅克隆（大仓库可加 --filter=blob:none 只拉文件树）
   gh repo clone owner/repo "$WORK" -- --depth 1
   # 快速档（只看结构/README/依赖，不克隆）：
   gh api "repos/owner/repo/git/trees/HEAD?recursive=1" --jq '.tree[].path'
   gh api repos/owner/repo/readme --jq '.content' | base64 -d
   ```
   Windows 注意：克隆目标用 `C:/...` 风格路径（git 是原生程序，不识别 `/tmp`）。
2. **模式判定**（决定后续一切，先问清/查清）：
   - 自家/可写仓库（remote 属自己或所在组织，或用户明说）→ **发布档**：审查后可整改。
   - 第三方仓库 → **评估档**：只读，给采用建议，不改代码。
   - 深审 vs 快速档：用户只想知道「值不值得深入」→ A1 元数据 + README + 依赖扫描后直接出评估卡。

Workflow A 从 A1 继续；Workflow B 从 B1 继续。

---

# Workflow A — 整仓代码审查

## A1 元数据快照

```bash
gh repo view owner/repo                     # 描述/语言/star/许可证/默认分支
gh api repos/owner/repo --jq '{archived, pushed_at, license: .license.spdx_id, open_issues, default_branch}'
# 文件类型分布 + LOC（在克隆目录）
find . -path ./.git -prune -o -type f -print | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -15
pygount --format=summary --folders-to-skip=".git,node_modules,venv,.venv,__pycache__,dist,build,models,assets" .
# 活跃度（第三方评估，需完整历史时另行 clone）
git log --since="1 year ago" --oneline | wc -l
# CI 真实性（L5：有配置文件 ≠ 真在跑；查官方运行记录，为空/全失败 = 僵尸 CI 🟡 起步）
gh api "repos/owner/repo/actions/workflows" --jq '.workflows[] | select(.state=="active") | .path' 2>/dev/null
gh api "repos/owner/repo/actions/runs?per_page=3" --jq '.workflow_runs[] | "\(.name): \(.status)/\(.conclusion) \(.created_at)"' 2>/dev/null
```

记入报告草稿：语言 / 规模 / LOC / 最近提交日期 / 许可证声明 / 是否 archived / 目录职责一览。

## A2 结构与架构理解（先「宣称」后「核对」）

1. 读 README / docs/：宣称做什么、怎么跑、目录怎么讲。
2. 找入口与主流程：根目录脚本、main.py / app.py / package.json scripts / Cargo.toml。
3. 画模块地图：顶层目录职责 + 互相引用（Python 看 import；其余读关键文件）。
4. **核对表（翻车高发区）**：
   - 宣称能力 vs 实际代码（README 的功能在代码里是 TODO / 不存在）。
   - 示例/教程里的命令路径 vs 真实入口（开源 demo 重灾区：教程写 python3 main.py，实际入口在别处）。
   - 配置文件键 vs 代码实际读取（config.yaml 有键代码没读 / 代码要的键配置里没有）。
5. 有测试就跑基线：`python -m pytest -q` 或对应框架，先记录通过/失败数。

## A3 分层代码审查

按价值排序扫描（时间紧可截断，但 L1/L2 必扫）：
L1 入口与启动流程 → L2 核心业务逻辑 → L3 配置/接口/设备访问 → L4 工具脚本（install.sh 等）→ L5 测试/CI

每层过六维清单：正确性 / 安全 / 代码质量 / 测试 / 性能 / 文档与工程化（各项要点见附录 A）。
**边看边记**：`文件:行 + 级别(🔴🟡💡) + 一句话问题 + 建议`——不要看完再回忆。

## A4 自动化扫描（克隆目录内，bash 一条龙）

```bash
# 1) 敏感信息：密钥/口令/私钥/内网 IP/个人路径痕迹（Windows 用户名等）
grep -rInE --exclude-dir=.git "(api[_-]?key|secret|passw(or)?d|token)[[:space:]]*[:=][[:space:]]*['\"][^'\"]{8,}['\"]" .
grep -rInE --exclude-dir=.git "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" .
grep -rInE --exclude-dir=.git "C:\\\\Users\\\\[A-Za-z]+|/home/[a-z]+" --include=*.py --include=*.sh --include=*.md .
grep -rInE --exclude-dir=.git "\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9.]+" --include=*.py --include=*.sh --include=*.json .
# 2) 残留标记
grep -rInE --exclude-dir=.git "TODO|FIXME|HACK|XXX" --include=*.py --include=*.js --include=*.c .
# 3) 大文件/模型误入库（>10MB）
git ls-files | while read -r f; do [ -f "$f" ] && s=$(stat -c%s "$f") && [ "$s" -gt 10485760 ] && echo "$((s/1024/1024))MB $f"; done
# 4) 依赖漏洞审计（按项目类型选）
[ -f requirements.txt ] && (pip install pip-audit -q 2>/dev/null; pip-audit -r requirements.txt 2>/dev/null | head -20)
[ -f package.json ] && npm audit --omit=dev 2>/dev/null | tail -15
# 5) 死代码/未用依赖（Python，可选）
python -m vulture . --min-confidence 70 2>/dev/null || pip install vulture -q 2>/dev/null && python -m vulture . --min-confidence 70
# 6) LICENSE 检查：根 LICENSE 缺失？与 README/包元数据声明不一致？
```

**历史敏感信息扫描（发布档必做；浅克隆无历史，需另 clone 一份全量）**：

```bash
gh repo clone owner/repo "$WORK/full"          # 不带 --depth 1 = 全历史
cd "$WORK/full"
git log -p --all -G "(api[_-]?key|secret|passw(or)?d|BEGIN (RSA|EC|OPENSSH )?PRIVATE KEY)" -- '*.py' '*.sh' '*.json' '*.yaml' '*.yml' '*.md' | grep -iE '^\+.*(api[_-]?key|secret|password|token|PRIVATE KEY)' | head -30
```

命中行前缀 `+` = 该次 commit 新增的内容（含早已删除的文件/行）；逐条人工复核后计入报告附表「历史 commit 痕迹」。评估档第三方仓库可不做；若打算 fork/二次开发建议查一遍。

结果分级记录。**敏感信息命中必须人工复核**——示例密钥、测试夹具、假密钥是常见假阳性，确认属实才上报。

## A5 输出报告

按下列结构出报告，模式二选一（结构见附录 B）：
- **评估档**：结论卡（维护活跃度/代码质量/文档上手成本/依赖许可风险/安全面/生态）+ 采用建议（✅直接用 / 🔶参考学习并摘出要点 / ❌放弃+理由）。
- **发布档**：就绪度结论 + 就绪检查表逐项打勾 + 🔴🟡 整改清单。
- 报告落 `<输出目录>\<repo名>_审查报告_<YYYYMMDD>.md`（终端同时给结论摘要；不再输出桌面）；用户要求贴到 GitHub PR 时改走 PR 行内评论流程。

**整改闭环（仅发布档/自家仓库）**：按 🔴→🟡 逐条修复，修完重跑 A4 验证；敏感信息清零 + 测试绿才算就绪。第三方仓库只读，绝不顺手改码。

---

# Workflow B — 仓库文件设计

## B1 定类型（四类基座见附录 C）

- 开源 demo（嵌入式/AI demo：可运行性 + 一键部署优先）
- 应用 / 服务（Flask/FastAPI/后端等）
- 库 / SDK
- 内部工具 / 脚本

信息不足先问一句：项目一句话定位、技术栈、运行平台、是否开源、谁会来安装使用（有无非工程师）。

## B2 目录树 + 文件职责表

基于模板裁剪，不凭空造目录：
- 树中每个文件/目录都有一句职责；模板用不上的删掉。
- 命名约定：目录小写连字符；**入口脚本名与 README/教程完全一致**（团队惯例：main.py 出厂终端直跑）。

## B3 标准文件逐项给要点

- **README**：按设计模板给逐节大纲；中英双语项目给段落对照表 + 「两版同步更新」约定。
- **LICENSE**：开源才要；按用户声明选（MIT/Apache-2.0/GPL 等），不与依赖许可证冲突。
- **.gitignore**：按语言 + 运行产物（权重/模型、日志、虚拟环境、构建产物）逐条给。
- **install.sh / 快速开始**（demo 类）：一键部署语义要覆盖依赖安装 + 模型获取 + 权限。
- **配置**：演示值只作默认，阈值/时段等参数可配置动态调，不写死（团队惯例）。
- **CI**（可选）：demo 给轻量 lint+冒烟即可，不硬塞重型流水线。

## B4 输出

按附录 D 的结构输出设计文档（目录树、职责表、标准文件要点、README 大纲、忽略/托管策略、待办）。
交付形态二选一或都要：设计文档（md）/ 直接生成骨架（目录 + 占位 + 标准文件）；设计文档落 `<输出目录>\<项目名>_仓库设计_<YYYYMMDD>.md`。

## 内嵌默认惯例（开源 demo 类，用户可覆盖）

- install.sh 一键部署；装完在**出厂默认终端直接 `python3 main.py` 跑通**——不改默认 shell、不要求敲 bash 切换、不写绝对路径解释器；修复必须固化进 install.sh（如桌面终端 ENV 注入），而非仅手工改单板。
- 参数配置化：阈值/时段/模型路径等走 config.yaml，演示数值只作默认。
- 中英 README 镜像同步，改中文必查英文版。
- 模型权重/大文件不入库 → release 附件或 LFS，仓库内只放下载脚本/说明。
- 多 demo 各自独立仓库，不互相依赖。

## Pitfalls

- **大仓库**：默认 `--depth 1`；评估档无需全历史；`--filter=blob:none` 可只拉树。
- **submodule / LFS**：clone 后先看子目录是否为空（submodule 目录常是空的），需要时 `--recurse-submodules`；模型目录常是 LFS 指针。
- **敏感信息假阳性**：正则命中先人工复核（示例/测试夹具/占位符），别误报别漏报历史 commit（发布档应查 `git log -p` 扫描痕迹）。
- **模式误判**：第三方仓库按发布档整改会 push 失败——Step 0 必须先行判定。
- **Windows git-bash**：克隆/脚本目标路径用 `C:/...`（原生 git/gh 不认 `/tmp`）；`stat -c%s` 可用。
- **只读纪律**：评估档看完即报告，不改第三方代码、不建分支。
- **快速档分流**：用户只要「值不值得看」就在 A1 后直接出评估卡，别默认全量深审。

## Verification（收尾自查）

- 审查：报告覆盖 L1/L2/L3 三层 + A4 扫描结果；每个 🔴 都带 `文件:行`；模式与结论一致。
- 设计：目录树无孤儿文件、无「有树无职责」条目；README 大纲与目录一一对应；.gitignore 覆盖全部运行产物。

## 附录 A：六维审查要点（配合 L1–L5 分层扫描）

- **正确性**：空/满输入、除零、超时、并发重入、断连恢复；异常被吞？失败有提示？资源（文件/设备/连接/线程）释放？非法状态转换、复位后状态残留、看门狗缺失；**宣称 vs 实际**（README/注释与代码不一致 = 🟡 起步）。
- **安全**：硬编码密钥/口令/证书（**含测试目录与示例，历史 commit 也要查**）；内网 IP、个人路径痕迹；注入（SQL、shell 拼接、`eval`/`exec`、`pickle`、非 safe 的 `yaml.load`）；路径穿越、任意写、下载未校验（`curl|sh`）；依赖漏洞（`pip-audit` / `npm audit`）；关闭证书校验；默认口令/隐藏远程开关。
- **代码质量**：命名语义化、职责单一、魔法数；死代码、未用依赖、重复实现；注释与代码不符、整段注释掉的代码；超长函数、嵌套 > 4 层、全局可变状态、隐式依赖。
- **测试**：有测试吗、能跑吗、基线通过数；失败/异常/边界用例而非只有 happy path；依赖真实硬件或网络且无 mock（嵌入式 demo 高发，注明即可不阻塞）。
- **性能**：循环内重复 IO/日志/图像处理/查询（N+1）；大对象常驻（帧、模型、无上限缓存）；线程/进程泄漏、启动过慢。
- **文档与工程化**：README 命令照着能跑；教程路径 == 真实入口；LICENSE 存在且与声明/徽章一致；`.gitignore` 漏大文件/密钥/日志？CI 配置存在但从不跑？依赖是否锁版本、有无 CHANGELOG/release 策略。

**按语言速查**：Python（`print`/调试器残留、裸 `except:`、`open()` 无 `with`、requirements 未锁、`sys.path` hack、路径 `\` 硬编码、`yaml.load`、`subprocess shell=True`、`requests verify=False`）· C/嵌入式（`strcpy`/`sprintf`/`gets`、`malloc` 泄漏、中断/看门狗未复位、magic 寄存器直写、平台宏泄漏、硬编码引脚地址）· Shell（无 `set -e`、`rm -rf $VAR` 未判空、`curl|sh`、绝对路径假设、install.sh 非幂等）· JS/TS（`console.log` 残留、`any` 滥用、`innerHTML` 拼用户输入、未捕获 promise、无 lockfile）。

**嵌入式/AI demo 专项**：模型来源与校验说明；SoC 型号硬编码 vs 运行时读 `/proc/device-tree/model`；设备节点号写死（USB 摄像头落到 `video73` 类问题）；出厂默认终端能否直跑（shell 假设、绝对路径解释器）；`/dev` 访问与 udev 规则是否随 `install.sh` 配好；小根分区（如 8G）的空间约束。

## 附录 B：报告结构

- **评估档（第三方只读）**：结论卡六维（维护活跃度 / 代码质量 / 文档与上手成本 / 依赖与许可风险 / 安全面 / 生态）+ 采用建议（✅ 直接用并锁定版本 / 🔶 参考学习并摘出可借鉴模块 / ❌ 放弃及理由）。
- **发布档（自家可整改）**：就绪度结论 + 就绪检查表逐项打勾（敏感信息清零含历史与测试目录、LICENSE 一致、README 命令可复现、`.gitignore` 覆盖运行产物、测试绿、版本与 CHANGELOG 策略、入口一致性）+ 🔴🟡 整改清单。
- **发现明细**：按 🔴 阻断 / 🟡 警告 / 💡 建议 / ✅ 亮点分组，每条 `相对路径:行 — 一句话问题 + 建议`；同一文件多处合并。
- **附：自动化扫描结果表**（敏感信息命中数/属实与假阳性、历史 commit 痕迹、依赖漏洞、TODO 残留、大文件入库、LICENSE 一致性、测试基线）。

## 附录 C：四类目录基座

| 类型 | 要点 | 关键文件 |
|---|---|---|
| 开源 demo | 可运行性第一：干净环境照 README 一次跑通、出厂默认终端直跑、模型来源清晰 | `README.md`● `main.py`● `install.sh`○ `config.yaml`○ `requirements.txt`● `modules/`○ `models/`◇ `assets/`○ `.gitignore`● |
| 应用 / 服务 | 配置三原则（默认值可用、环境变量可覆盖、密钥不进库）；路由薄、服务厚 | `src/<pkg>/`●（`main.py`/`server.py`、`config.py`、`api/`、`services/`、`models/`、`utils/`）`tests/`○ `.env.example`○ `Dockerfile`◇ `.github/workflows/ci.yml`◇ |
| 库 / SDK | 公开面最小化、类型与文档成体系、示例可运行、语义化版本 + CHANGELOG | `pyproject.toml`● `src/<pkg>/`● `tests/`● `examples/`○ `docs/`○ `CHANGELOG.md`○ |
| 内部工具 / 脚本 | 单文件可读（< 500 行，超了拆）、argparse 参数化、stdout 干净、幂等 | `<tool>.py`/`.sh`● `requirements.txt`◇ `config.example.yaml`◇ |

`.gitignore` 起手：`*.log` `.DS_Store` `Thumbs.db` `.idea/` `.vscode/`；Python：`__pycache__/` `*.pyc` `.venv/` `.pytest_cache/` `dist/` `build/` `*.egg-info/`；模型：`*.pt` `*.onnx` `*.h5` `*.pth` `*.bin`；嵌入式：`*.o` `*.elf` 编译产物。

## 附录 D：设计文档结构

```
1 项目定位（一句话 / 技术栈 / 运行平台 / 是否开源 / 目标用户与上手场景）
2 仓库类型与选型依据（四类基座之一 + 理由）
3 目录树（最终）
4 文件职责表（路径 | 职责 | 必须/可选 | 说明）
5 标准文件要点（README 逐节大纲 / LICENSE 选型与兼容性 / .gitignore 清单 / install.sh 动作与验收 / CI 范围）
6 忽略与托管策略（模型权重 → release 或 LFS 或下载脚本；密钥不入库；日志与运行产物 gitignore）
7 风险与待办（每条给下一步动作）
8 落地清单（按顺序列出要创建的文件，供直接生成骨架）
```
