<div align="center">

# open-skill

**面向日常工作流的 Hermes Agent 技能集**

代码编写 · 代码审查 · 项目复现 · 飞书云文档 API

[![Skills](https://img.shields.io/badge/skills-4-2f81f7?style=flat-square)](#skills)
[![Agent](https://img.shields.io/badge/Hermes%20Agent-skill%20package-8b5cf6?style=flat-square)](https://hermes-agent.nousresearch.com/docs)
[![Standard](https://img.shields.io/badge/Agent%20Skills-open%20format-0ea5e9?style=flat-square)](https://agentskills.io)
[![License](https://img.shields.io/badge/license-MIT-16a34a?style=flat-square)](#license)

</div>

> 把日常里**重复且有判断力**的活儿，沉淀成 AI Agent 可直接加载执行的技能包。
> 每个技能 = 一个独立目录：`SKILL.md` 定义**触发条件 + 执行流程 + 实测坑**，`references/` 承载**清单与实测格式**，`templates/` 承载**产出物模板**。
> 复制进 Hermes Agent 的技能目录即可使用，无外部依赖。

---

<a id="toc"></a>

## 目录（Table of Contents）

| | 章节 |
|---|---|
| 📦 | [技能一览（Skills Overview）](#skills) |
| ✍️ | [代码编写 · code-authoring](#authoring) |
| 🔍 | [代码审查 · github-repo-review-and-design](#code-review) |
| 🧪 | [项目复现 · project-reproduction](#reproduction) |
| 📄 | [飞书云文档 API · feishu-docs-api](#feishu-api) |
| 🚀 | [快速开始（Quick Start）](#quickstart) |
| 🗂️ | [仓库结构（Repository Layout）](#layout) |
| 📐 | [设计约定（Conventions）](#conventions) |
| 📜 | [许可（License）](#license) |

---

<a id="skills"></a>

## 技能一览（Skills Overview）

| 技能 | 包名 / 版本 | 解决什么问题 | 典型触发语 |
|:--|:--|:--|:--|
| ✍️ **代码编写** | `code-authoring`<br>`v0.2.0` | 写新代码 / 改他人代码的**注释规范 + 最小充分改动**纪律，防止 diff 被顺手改动淹没 | 写新功能、改他人代码之前 |
| 🔍 **代码审查** | `github-repo-review-and-design`<br>`v1.1.2` | 给定 `owner/repo`、URL 或本地路径做**整仓分级审查**；并为新项目**设计仓库文件结构** | 「看下这个仓库值不值得用」「给这个 demo 设计仓库结构」 |
| 🧪 **项目复现** | `project-reproduction`<br>`v0.1.1` | 按 README / 教程 / `install.sh` **逐步复现跑通**，报错走最优路径并把修复**固化进文件**，产出报告 | 「按这份教程 / install.sh 复现、部署、跑通」 |
| 📄 **飞书云文档 API** | `feishu-docs-api`<br>`v0.1.0` | 用 REST 直写 / 同步 / 归档飞书云文档（docx / wiki / bitable）：块读写、md 上云、节点归档、权限链路 | 「改这篇飞书文档」「把 md 同步到飞书」「建知识库节点」 |

**四者的关系**：一条完整的交付链 —— 写代码时守 `code-authoring` 的纪律 → 交付前用 `github-repo-review-and-design` 审整仓 → 用户侧按 `project-reproduction` 复现验收 → 配套文档用 `feishu-docs-api` 直写/同步上云。

---

<a id="details"></a>

## 技能详解（Skill Details）

### <a id="authoring"></a>✍️ 1. 代码编写 —— `code-authoring`

**定位**：只管「产码阶段」的两件事 —— **注释该写什么**、**改动该有多大**。

**六条规则**：独立成篇；触发面覆盖任何生产代码的写或改；注释跟随文件既有语言（新文件默认英文）、只写 **why**；最小充分改动；改他人代码前先建**现状快照**；交付前自检范围、注释、是否真跑过。

**最小充分改动**：

| | 内容 |
|:--|:--|
| ✅ 白名单（必须做） | 输入校验、错误与异常处理、资源释放、被改函数的调用点同步更新、必要测试、格式化工具强制的改动 |
| ⛔ 黑名单（禁止顺手做） | 重新格式化 / 调换行、重命名、调整 import 顺序、加未被要求的日志与开关与抽象层、引入新依赖、改公共接口签名、跨文件大范围重排 |
| 🚫 底线 | 禁止为让测试通过而加特判 / hardcode / 注释掉断言 / 绕过校验 —— 要修根因，根因超范围先说明再动 |

**流程**：建现状快照（读既有约定 + 跑基线）→ 界定范围（一句话需求 + 验收判据）→ 写代码 → 注释规范 → 自检验证（跑基线 + diff 复核）→ 汇报（只给结论与证据）。

**资产**：`SKILL.md`（含注释违规自检命令与完成度自查清单）。

---

### <a id="code-review"></a>🔍 2. 代码审查 —— `github-repo-review-and-design`

**定位**：**一个技能、两条工作流**，共享「定位仓库 + 模式判定」前置。

| 工作流 | 做什么 | 模式 |
|:--|:--|:--|
| **A 整仓代码审查** | 克隆全量分析，输出分级报告（🔴 阻断 / 🟡 警告 / 💡 建议 / ✅ 亮点，条目带 `文件:行`） | **评估档**（第三方仓库，只读给采用建议）／ **发布档**（自家仓库，可整改到可发布） |
| **B 仓库文件设计** | 为新项目设计目录树 + 文件职责 + 标准文件要点；杂乱旧仓库给重组方案；可选直接生成骨架 | 四类基座：开源 demo / 应用服务 / 库 SDK / 内部工具 |

```text
owner/repo | URL | 本地路径 | 一句话任务
   │
   ▼  Step 0  定位仓库 + 模式判定 ← 决定一切行为的岔路口
   ├── Workflow A  整仓审查 ─► 分级报告（评估档结论卡 / 发布档就绪检查表）
   └── Workflow B  文件设计 ─► 设计文档（目录树 + 职责表 + 标准文件要点）
```

**A 线扫描内容**：元数据与活跃度 → 结构与架构（宣称 vs 实际核对）→ 分层审查（L1 入口 / L2 核心逻辑 / L3 配置接口 / L4 工具脚本 / L5 测试 CI，六维清单）→ 自动化扫描（敏感信息、密钥、个人路径痕迹、残留标记、大文件误入库、依赖漏洞审计、死代码）→ 报告与整改闭环。

**只读纪律**：评估档绝不改第三方代码、不建分支；发布档修完必须重扫验证。

**资产**：`SKILL.md` + `references/`（`review-checklist.md` 六维×五层清单、`report-template.md`、`layout-templates.md` 四类基座、`design-output-template.md`）。

---

### <a id="reproduction"></a>🧪 3. 项目复现 —— `project-reproduction`

**定位**：把「按教程装一遍」做成**过程可预测、结果可复用**的交付 —— 下一次照着「报告 + 修改后文件」能一次通过。

```text
P0 准备 ─► P1 按原文逐步执行（忠实原文，偏差记「文档偏差」）
        ─► P2 报错 → 最优路径（环境差异 → 配置 → 代码/文档不符 → 平台特有坑）
        ─► P3 收尾（全量重跑 + diff + 报告 + 归档）
```

**核心纪律**：

- **忠实原文**：先按原文字面执行一次，不提前替作者「修正」，把不符记为文档偏差；
- **归因顺序**：按成本从低到高，一次只试一个分支；同一分支重试 ≤ 2 次无进展必须换分支或上报；
- **修复必须固化**：写进 `install.sh` / config / 源码 / 文档本身，禁止用一次性手工命令绕过；成对文档两版同步改；
- **验收用目标身份**：目标设备上通过 `adb` 执行时默认是 root，但文档按普通用户视角写 —— 必须以目标用户身份复验通过才算通过。

**产出目录**（每次复现一套，含逐步留痕与原始快照）：

```text
复现结果_<项目名>_<YYYYMMDD_HHMM>/
├─ 先读我_通俗总结.md    # 面向人的总览：一句话结论 / 怎么用 / 文件地图
├─ 00_复现报告.md        # 主报告（模板生成）
├─ 01_执行日志.md        # 逐步留痕，边做边写，禁止事后补
├─ 02_问题与修复记录.md  # 每个报错一条完整记录（原文 / 归因 / 固化位置 / 验证）
├─ 03_修改后文件/        # 最终可用文件，保留原相对路径
└─ 04_原始快照/          # 原文副本 + 改动前文件 / git commit，供 diff
```

**精选坑**：脚本打印「All done」不等于成功（子进程可能根本没启动，要验证副作用）；非交互 shell 里用户 `PATH` 常不生效，会把环境问题误判成项目问题；`adb` 传二进制必须 `adb push` 并 md5 双边核对；目标设备根分区小，报错先 `df` 而不是判定缺包。

**资产**：`SKILL.md` + `templates/reproduction-report.md`。

---

### <a id="feishu-api"></a>📄 4. 飞书云文档 API —— `feishu-docs-api`

**定位**：把「改飞书文档 / 把 md 同步上云 / 建知识库节点归档」从一次性手工调试变成可复现流程 —— 纯 REST + `tenant_access_token`，无 CLI 依赖。

```text
取 token ─► 解析目标（wiki token ≠ doc id）─► 读现状 ─► 写内容 ─► md 上云 ─► 归档节点 ─► 写后核对
```

**覆盖范围**：

| 场景 | 关键端点 / 机制 |
|:--|:--|
| 改文档内容（标题 / 正文 / 列表 / 代码块） | `PATCH /docx/v1/documents/{doc}/blocks/{block_id}` + `update_text_elements`（保留样式需整组 elements 回写） |
| 插入 / 删除块 | `blocks/{parent}/children`（删块区间放 JSON body） |
| md 上云 | 本地解析 md → 块数组 → 批量 children 写入（每批 ≤40，`index:-1`） |
| 知识库归档 | 按天目录 `YYYY-MMDD`；`POST /wiki/v2/spaces/{space_id}/nodes`（`obj_type` 传字符串） |
| 多维表格 | 字段改造、批量写记录、跨库搬迁（数字字段读回是字符串） |
| 写后核对 | 回读云端块数 vs 本地解析块数，表格块（`block_type == 31`）数必须相等 |

**实测坑精选**：`obj_type` 传数字报 field validation failed；分享面板默认搜不到机器人应用（要切 tab）；单表上限 9 行（含表头）、列宽要按内容算；md 里嵌套代码围栏会提前闭合；git-bash 裸调 API URL 需 `MSYS_NO_PATHCONV=1`；回读必须翻页。

**资产**：`SKILL.md` + `references/`（8 篇：直写格式、REST 端点、块类型表、节点树操作、归档与命名、md 渲染矩阵、写回坑、原地同步）。

---

<a id="quickstart"></a>

## 快速开始（Quick Start）

```bash
# 方式一：作为 Hermes Agent 的 tap 订阅（可随时更新）
hermes skills tap add jjking619/open-skill
hermes skills search 复现 --source github
hermes skills install jjking619/open-skill/skills/software-development/project-reproduction

# 方式二：装到其他支持 Agent Skills 格式的客户端
npx skills add jjking619/open-skill

# 方式三：整树复制进 Hermes Agent 技能目录
git clone git@github.com:jjking619/open-skill.git
cp -r open-skill/skills/*  ~/AppData/Local/hermes/skills/     # Windows (git-bash)
cp -r open-skill/skills/*  ~/.hermes/skills/                  # Linux / macOS
```

- **无需安装依赖**：技能是纯 Markdown 资产，命令按需在运行时执行。
- **如何被加载**：Agent 依据每个 `SKILL.md` frontmatter 里的 `description`（含触发词）判断是否加载；也可手动 `skill_view(name='code-authoring')`。
- **改回自己的环境**：技能里出现的产出目录（如复现报告、审查报告的落盘路径）按自己习惯改 `SKILL.md` 里的路径常量即可。

<a id="layout"></a>

## 仓库结构（Repository Layout）

```text
open-skill/
├── README.md                                   # 本文件：技能门面与使用说明
├── LICENSE                                     # MIT
├── .gitignore
├── .gitattributes
└── skills/
    ├── productivity/
    │   └── feishu-docs-api/                    # 📄 飞书云文档 API
    │       ├── SKILL.md                        #   流程 / 权限 / 写后核对 / 坑
    │       └── references/                     #   8 篇：直写格式 / REST 端点 / 渲染矩阵 …
    ├── github/
    │   └── github-repo-review-and-design/      # 🔍 代码审查 + 仓库文件设计
    │       ├── SKILL.md
    │       └── references/                     #   4 篇：审查清单 / 报告模板 / 目录基座 / 设计模板
    └── software-development/
        ├── project-reproduction/               # 🧪 项目复现
        │   ├── SKILL.md
        │   └── templates/                      #   复现报告模板
        └── code-authoring/                     # ✍️ 代码编写
            └── SKILL.md
```

目录层级与 Hermes Agent 技能库一致（`skills/<分类>/<技能名>/`），技能目录名等于 `SKILL.md` frontmatter 的 `name`，因此可以**整树复制**，无需改名或调整结构。

<a id="conventions"></a>

## 设计约定（Conventions）

- **分层组织**：流程写 `SKILL.md`，清单与实测格式写 `references/`，产出物模板写 `templates/` —— 主文件不臃肿，资产可被其他流程复用。
- **触发词面向意图**：描述用中性意图表述（「按教程复现」而非某次对话的原话），换个人、换个项目依然能命中。
- **结论必须可复核**：审查条目带 `文件:行`，复现步骤带命令与实际输出，API 断言带端点与错误码，报告结论能被第三方直接验证。
- **修复要固化**：只解决本次问题的临时命令不算交付，改动必须落进文件本身。
- **坑位只收通用经验**：条目须在他人环境下也成立；环境/团队特有条目不进技能。
- **凭据不进仓库**：应用密钥、token、内部标识一律走环境变量，仓库里只留占位符。
- **版本语义化**：每个技能自带 `version`，破坏性流程变更升 major。

<a id="license"></a>

## 许可（License）

本项目采用 [MIT License](LICENSE)。

<div align="center"><sub>Built for Hermes Agent · 技能随工作流一起演进</sub></div>
