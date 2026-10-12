<div align="center">

# open-skill

**面向日常工作流的 Hermes Agent 技能集**

代码编写 · 代码审查 · 项目复现 · 云文档 API · Shell 工具链 · 脚本健壮化 · 设备联调 · 文档审计 · 交付物包 · 发布门禁

[![Skills](https://img.shields.io/badge/skills-10-2f81f7?style=flat-square)](#skills)
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
| 💻 | [研发主链（Build Chain）](#build-chain) |
| ✍️ | [代码编写 · code-authoring](#authoring) |
| 🔍 | [代码审查 · github-repo-review-and-design](#code-review) |
| 🧪 | [项目复现 · project-reproduction](#reproduction) |
| 🚀 | [发布前审计 · prepublish-repo-audit](#prepublish) |
| 🧰 | [环境与脚本（Environment & Scripts）](#environment) |
| 🪟 | [Windows Shell 工具链 · windows-shell-tooling](#win-shell) |
| 🔒 | [脚本健壮化 · shell-script-hardening](#script-hardening) |
| 📱 | [设备联调 · adb-device-toolkit](#adb) |
| 📋 | [交付与文档（Delivery & Docs）](#delivery-docs) |
| 📄 | [云文档 API · feishu-docs-api](#feishu-api) |
| 📐 | [文档一致性审计 · doc-consistency-audit](#doc-audit) |
| 🗃️ | [交付物包 · deliverable-pack](#deliverable) |
| 🚀 | [快速开始（Quick Start）](#quickstart) |
| 🗂️ | [仓库结构（Repository Layout）](#layout) |
| 📜 | [设计约定（Conventions）](#conventions) |
| 📄 | [许可（License）](#license) |

---

<a id="skills"></a>

## 技能一览（Skills Overview）

| 技能 | 包名 / 版本 | 解决什么问题 | 典型触发语 |
|:--|:--|:--|:--|
| ✍️ **代码编写** | `code-authoring`<br>`v0.2.0` | 写新代码 / 改他人代码的**注释规范 + 最小充分改动**纪律 | 写新功能、改他人代码之前 |
| 🔍 **代码审查** | `github-repo-review-and-design`<br>`v1.1.2` | 整仓**分级审查**；为新项目**设计仓库文件结构** | 「看下这个仓库值不值得用」 |
| 🧪 **项目复现** | `project-reproduction`<br>`v0.1.1` | 按 README / 教程 / `install.sh` **逐步复现跑通**并把修复固化 | 「按这份教程复现、部署、跑通」 |
| 🚀 **发布前审计** | `prepublish-repo-audit`<br>`v0.1.0` | 开源/交付前的**门禁**：可见性、密钥、内部标识、仓库卫生 | 「这个仓能公开吗」「开源前查一遍」 |
| 🪟 **Windows Shell** | `windows-shell-tooling`<br>`v0.1.0` | Windows + git-bash 的**路径 / 换行 / 编码 / 落盘**坑 | 命令在 git-bash 里行为不对 |
| 🔒 **脚本健壮化** | `shell-script-hardening`<br>`v0.1.0` | `install.sh` / 部署脚本**幂等、可诊断、不假成功** | 写或改一键安装脚本 |
| 📱 **设备联调** | `adb-device-toolkit`<br>`v0.1.0` | **adb** 认设备、执行身份、传文件校验、长任务脱离会话 | 连板子 / Android 设备调试 |
| 📄 **云文档 API** | `feishu-docs-api`<br>`v0.1.0` | REST 直写/同步/归档飞书云文档（docx / wiki / bitable） | 「改这篇飞书文档」「把 md 同步上云」 |
| 📐 **文档一致性审计** | `doc-consistency-audit`<br>`v0.1.0` | 一批文档 / 多语言镜像的**一致性检查 + 分级报告** | 「这批文档审一遍」 |
| 🗃️ **交付物包** | `deliverable-pack`<br>`v0.1.0` | 把一次性工作沉淀成**可复核的交付物包**（五件套） | 复现/迁移/调研做完要交接 |

---

<a id="build-chain"></a>

## 研发主链（Build Chain）

```text
写代码 ─► 审整仓 ─► 复现验收 ─► 发布门禁 ─► 交付留痕
code-authoring → github-repo-review-and-design → project-reproduction → prepublish-repo-audit → deliverable-pack
```

---

<a id="details"></a>

## 技能详解（Skill Details）

<a id="authoring"></a>

### ✍️ 1. 代码编写 —— `code-authoring`

**定位**：只管「产码阶段」的两件事 —— **注释该写什么**、**改动该有多大**。

**六条规则**：独立成篇；触发面覆盖任何生产代码的写或改；注释跟随文件既有语言（新文件默认英文）、只写 **why**；最小充分改动；改他人代码前先建**现状快照**；交付前自检范围、注释、是否真跑过。

**最小充分改动**：

| | 内容 |
|:--|:--|
| ✅ 白名单（必须做） | 输入校验、错误与异常处理、资源释放、被改函数的调用点同步更新、必要测试、格式化工具强制的改动 |
| ⛔ 黑名单（禁止顺手做） | 重新格式化 / 调换行、重命名、调整 import 顺序、加未被要求的日志与开关与抽象层、引入新依赖、改公共接口签名、跨文件大范围重排 |
| 🚫 底线 | 禁止为让测试通过而加特判 / hardcode / 注释掉断言 / 绕过校验 —— 要修根因，根因超范围先说明再动 |

**流程**：建现状快照 → 界定范围（一句话需求 + 验收判据）→ 写代码 → 注释规范 → 自检验证 → 汇报（只给结论与证据）。

**资产**：`SKILL.md`（含注释违规自检命令与完成度自查清单）。

---

<a id="code-review"></a>

### 🔍 2. 代码审查 —— `github-repo-review-and-design`

**定位**：**一个技能、两条工作流**，共享「定位仓库 + 模式判定」前置。

| 工作流 | 做什么 | 模式 |
|:--|:--|:--|
| **A 整仓代码审查** | 克隆全量分析，输出分级报告（🔴 阻断 / 🟡 警告 / 💡 建议 / ✅ 亮点，条目带 `文件:行`） | **评估档**（第三方仓库，只读给建议）／ **发布档**（自家仓库，整改到可发布） |
| **B 仓库文件设计** | 为新项目设计目录树 + 文件职责 + 标准文件要点；杂乱旧仓库给重组方案 | 四类基座：开源 demo / 应用服务 / 库 SDK / 内部工具 |

```text
owner/repo | URL | 本地路径 | 一句话任务
   │
   ▼  Step 0  定位仓库 + 模式判定 ← 决定一切行为的岔路口
   ├── Workflow A  整仓审查 ─► 分级报告（评估档结论卡 / 发布档就绪检查表）
   └── Workflow B  文件设计 ─► 设计文档（目录树 + 职责表 + 标准文件要点）
```

**A 线扫描内容**：元数据与活跃度 → 结构与架构（宣称 vs 实际核对）→ 分层审查（L1 入口 / L2 核心逻辑 / L3 配置接口 / L4 工具脚本 / L5 测试 CI，六维清单）→ 自动化扫描（敏感信息、密钥、个人路径痕迹、残留标记、大文件误入库、依赖漏洞、死代码）→ 报告与整改闭环。

**资产**：`SKILL.md` + `references/`（`review-checklist.md`、`report-template.md`、`layout-templates.md`、`design-output-template.md`）。

---

<a id="reproduction"></a>

### 🧪 3. 项目复现 —— `project-reproduction`

**定位**：把「按教程装一遍」做成**过程可预测、结果可复用**的交付 —— 下一次照着「报告 + 修改后文件」能一次通过。

```text
P0 准备 ─► P1 按原文逐步执行（忠实原文，偏差记「文档偏差」）
        ─► P2 报错 → 最优路径（环境差异 → 配置 → 代码/文档不符 → 平台特有坑）
        ─► P3 收尾（全量重跑 + diff + 报告 + 归档）
```

**核心纪律**：忠实原文；归因按成本从低到高、一次只试一个分支（同分支重试 ≤ 2 次无进展必须换或上报）；修复必须固化进文件；验收在目标身份下完成。

**产出目录**：`先读我_通俗总结.md` / `00_复现报告.md` / `01_执行日志.md` / `02_问题与修复记录.md` / `03_修改后文件/` / `04_原始快照/`（结构详见 `deliverable-pack`）。

**精选坑**：脚本打印「All done」不等于成功（子进程可能根本没启动，要验证副作用）；非交互 shell 里用户 `PATH` 常不生效，会把环境问题误判成项目问题；`adb` 传二进制必须 `adb push` 并 md5 双边核对；目标设备根分区小，报错先 `df`。

**资产**：`SKILL.md` + `templates/reproduction-report.md`。

---

<a id="prepublish"></a>

### 🚀 4. 发布前审计 —— `prepublish-repo-audit`

**定位**：**公开不可逆** —— 门禁必须排在 push 之前。

```text
① 可见性判定（匿名 HTTP + cache-buster 复测）
      ─► ② 内容扫描（密钥 / 内部标识 / 内部路径 / 内网 IP / 大文件 / 历史残留）
            ─► ③ 处置（命中内部内容 → 停下问用户；脱敏另稿；改私有并复测）
```

**要点**：仓库里只留环境变量名不留密钥值；已暴露的凭据必须**轮换**；「删文件再提交」不等于清除历史（要重写历史）；raw 走 CDN 缓存，判定私有必须加 cache-buster；脱敏稿在**副本**上做，改完**回读线上再扫一次**。

**资产**：`SKILL.md`（含可直接复制的扫描命令、仓库卫生清单、验收清单）。

---

<a id="environment"></a>

## 环境与脚本（Environment & Scripts）

<a id="win-shell"></a>

### 🪟 5. Windows Shell 工具链 —— `windows-shell-tooling`

**定位**：Windows 上用 git-bash（MSYS）跑命令、写脚本时的实测坑 —— 目标是**同一条命令换台机器也能跑**。

**六条规则**：① 路径转换默认关闭（给原生程序传 `C:/...`，别传 `/c/...`；`cd` 是内建所以能进）；② 不用 PowerShell 语法；③ 含空格/中文路径整体加引号；④ 行尾统一 LF（`.gitattributes`）；⑤ 输出显式设 UTF-8（GBK 控制台会崩）；⑥ 交互输入按「回车」提交（只发 `\n` 不生效）。

**落盘**：heredoc 用 `<<'EOF'`；反斜杠保真不可靠 → 用字节检查（`od -c`）；长文整文件写入；写完回读校验头字节。

**资产**：`SKILL.md`（含排查顺序表）。

---

<a id="script-hardening"></a>

### 🔒 脚本健壮化 —— `shell-script-hardening`

**定位**：`install.sh` / 部署脚本的三条底线 —— **重复执行不坏、失败能说清、成功不自欺**。

**六条纪律**：幂等（先探测再装，已满足打印 `[SKIP]`）；引号与数组；`mktemp` + `trap` 清理；每步打印且错误走 stderr 非零退出；不做危险默认（不 `curl|sh`、`rm -rf` 先判空）；结尾**验证副作用**而不是 echo "All done"。

**自检两条**：脚本自述不可信（重定向到不存在目录会让子进程根本不启动，却仍打印成功）；非交互 shell 的 `PATH` 陷阱（`~/.bashrc` early-return 导致解释器落到别的版本）。

**资产**：`SKILL.md`（含骨架、`set -euo pipefail` 陷阱、验收清单）。

---

<a id="adb"></a>

### 📱 设备联调 —— `adb-device-toolkit`

**定位**：把「连板子 / Android 设备干活」做成可复现流程。

```text
认设备（devices -l，多设备固定 -s / -t）─► 认清执行身份（root vs 普通用户是两套环境）
   ─► 传文件（push/pull + 双边 md5）─► 长任务脱离会话（setsid + 轮询日志）
   ─► 端口方向（forward = PC→设备，reverse = 设备→PC，部分 adbd 不支持）
```

**常见报错对照**：`unauthorized` / `offline` / `error: closed`（reverse、exec-out 不支持）/ 磁盘满（先 `df`）/ 外设枚举不到（adb 与 USB-host 互斥）。

**资产**：`SKILL.md`。

---

<a id="delivery-docs"></a>

## 交付与文档（Delivery & Docs）

<a id="feishu-api"></a>

### 📄 6. 云文档 API —— `feishu-docs-api`

**定位**：把「改飞书文档 / 把 md 同步上云 / 建知识库节点归档」从一次性手工调试变成可复现流程 —— 纯 REST + `tenant_access_token`，无 CLI 依赖。

```text
取 token ─► 解析目标（wiki token ≠ doc id）─► 读现状 ─► 写内容 ─► md 上云 ─► 归档节点 ─► 写后核对
```

| 场景 | 关键端点 / 机制 |
|:--|:--|
| 改文档内容 | `PATCH /docx/v1/documents/{doc}/blocks/{block_id}` + `update_text_elements`（保留样式需整组 elements 回写） |
| 插入 / 删除块 | `blocks/{parent}/children`（删块区间放 JSON body） |
| md 上云 | 本地解析 md → 块数组 → 批量 children 写入（每批 ≤40，`index:-1`） |
| 知识库归档 | 按天目录 `YYYY-MMDD`；`POST /wiki/v2/spaces/{space_id}/nodes`（`obj_type` 传字符串） |
| 多维表格 | 字段改造、批量写记录、跨库搬迁（数字字段读回是字符串） |
| 写后核对 | 回读云端块数 vs 本地解析块数，表格块（`block_type == 31`）数必须相等 |

**实测坑精选**：`obj_type` 传数字报 field validation failed；分享面板默认搜不到机器人应用；单表上限 9 行、列宽要按内容算；md 里嵌套代码围栏会提前闭合；git-bash 裸调 API 需 `MSYS_NO_PATHCONV=1`；回读必须翻页。

**资产**：`SKILL.md` + `references/`（8 篇）。

---

<a id="doc-audit"></a>

### 📐 7. 文档一致性审计 —— `doc-consistency-audit`

**定位**：把「一批文档 / 多语言镜像到底有没有对齐」变成**机械层扫描 + 语义层抽查 + 分级报告**。

```text
定范围与镜像对 ─► 机械层扫描（链接 / 代码块 / 占位残留 / 术语变体 / 版式）
   ─► 语义层抽查（漏章、数字与配置、镜像内容指纹、图文对应）
   ─► findings（文件 | 位置 | 类型 | 证据 | 严重级）
   ─► 报告（🔴 阻断 / 🟡 需修 / 💡 建议）+ 已修正清单
```

**修复纪律**：确定性（错别字、链接编码、占位行、命令粘连）直接改；改一侧必须同步它的镜像版；语义/需业务判断的进「待确认」不擅改。

**资产**：`SKILL.md` + `references/audit-checklist.md`（六类检查项 + 问题类型归一化枚举）+ `templates/audit-report.md`。

---

<a id="deliverable"></a>

### 🗃️ 8. 交付物包 —— `deliverable-pack`

**定位**：同一件事有**三类读者**（决策者 / 执行者 / 复核者），用固定五件套一次满足。

```text
<产物类型>_<对象>_<YYYYMMDD_HHMM>/
├─ 先读我_通俗总结.md      # 必出：1-2 屏，一句话结论 + 怎么用 + 文件地图
├─ 00_主报告.md            # 结构化结论 + 证据（命令 + 输出/位置）
├─ 01_执行日志.md          # 边做边写，禁止事后补
├─ 02_问题与修复记录.md    # 原文 → 归因 → 修复位置 → 验证
├─ 03_产物/                # 最终可用文件，保留原相对路径
└─ 04_原始快照/            # 改动前原文 / commit，供 diff
```

**纪律**：结论先行；日志与总结分开；每条结论可复核；包内引用用相对路径；目录名带时间戳。

**资产**：`SKILL.md`。

---

<a id="quickstart"></a>

## 快速开始（Quick Start）

```bash
# 方式一：作为 Hermes Agent 的 tap 订阅（可随时更新）
hermes skills tap add jjking619/open-skill
hermes skills search 复现 --source github
hermes skills install jjking619/open-skill/skills/doc-consistency-audit

# 方式二：装到其他支持 Agent Skills 格式的客户端
npx skills add jjking619/open-skill

# 方式三：整树复制进 Hermes Agent 技能目录
git clone git@github.com:jjking619/open-skill.git
cp -r open-skill/skills/*  ~/AppData/Local/hermes/skills/     # Windows (git-bash)
cp -r open-skill/skills/*  ~/.hermes/skills/                  # Linux / macOS
```

- **无需安装依赖**：技能是纯 Markdown 资产，命令按需在运行时执行。
- **如何被加载**：Agent 依据每个 `SKILL.md` frontmatter 里的 `description`（含触发词）判断是否加载；也可手动 `skill_view(name='code-authoring')`。
- **改回自己的环境**：技能里出现的产出目录（如复现报告、审计报告的落盘路径）按自己习惯改 `SKILL.md` 里的路径常量即可。

<a id="layout"></a>

## 仓库结构（Repository Layout）

```text
open-skill/
├── README.md                                   # 本文件：技能门面与使用说明
├── LICENSE                                     # MIT
├── .gitignore
├── .gitattributes
└── skills/                                     # 每个技能一个目录，目录名 = SKILL.md 的 name（tap 规范）
    ├── code-authoring/                         # ✍️ 代码编写
    ├── github-repo-review-and-design/          # 🔍 代码审查 + 仓库文件设计（references ×4）
    ├── project-reproduction/                   # 🧪 项目复现（templates ×1）
    ├── prepublish-repo-audit/                  # 🚀 发布前审计
    ├── windows-shell-tooling/                  # 🪟 Windows Shell 工具链
    ├── shell-script-hardening/                 # 🔒 脚本健壮化
    ├── adb-device-toolkit/                     # 📱 设备联调
    ├── feishu-docs-api/                        # 📄 云文档 API（references ×8）
    ├── doc-consistency-audit/                  # 📐 文档一致性审计（references ×1 + templates ×1）
    └── deliverable-pack/                       # 🗃️ 交付物包
```

目录层级与 Hermes Agent 技能库一致（`skills/<分类>/<技能名>/`），技能目录名等于 `SKILL.md` frontmatter 的 `name`，因此可以**整树复制**，无需改名或调整结构。

<a id="conventions"></a>

## 设计约定（Conventions）

- **分层组织**：流程写 `SKILL.md`，清单与实测格式写 `references/`，产出物模板写 `templates/`。
- **触发词面向意图**：描述用中性意图表述，换个人、换个项目依然能命中。
- **结论必须可复核**：审查条目带 `文件:行`，复现步骤带命令与输出，API 断言带端点与错误码。
- **修复要固化**：临时命令不算交付，改动必须落进文件本身。
- **坑位只收通用经验**：条目须在他人环境下也成立；环境/团队特有条目不进技能。
- **凭据不进仓库**：密钥、token、内部标识走环境变量，仓库里只留占位符。
- **版本语义化**：每个技能自带 `version`，破坏性流程变更升 major。

<a id="license"></a>

## 许可（License）

本项目采用 [MIT License](LICENSE)。

<div align="center"><sub>Built for Hermes Agent · 技能随工作流一起演进</sub></div>
