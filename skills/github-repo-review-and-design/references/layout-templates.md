# 仓库文件布局模板（四类）

用法：Workflow B1 按项目类型选基座 → B2 裁剪生成目录树与职责表。
原则：**每个文件/目录都必须有一句职责**；模板用不上的删掉；用户没说的不新增。
符号：● 必须 ／ ○ 强烈建议 ／ ◇ 可选（按规模取舍）

---

## 模板 1：开源 demo（嵌入式 / AI 视觉 / 硬件 demo —— 可运行性第一）

```
<repo>/                       # 小写连字符，如 demo-gesture-remote-control
├── README.md                 # ● 中英双语可选；第一屏=是什么+效果图+硬件要求
├── LICENSE                   # ○ 开源必须有
├── install.sh                # ○ 一键部署：依赖+模型下载+权限/udev，幂等
├── main.py                   # ● 唯一入口；出厂默认终端直接 python3 main.py 可跑
├── config.yaml               # ○ 参数化：阈值/时段/模型路径/设备号，演示值只作默认
├── requirements.txt          # ● 依赖清单（锁版本或给下限）
├── modules/                  # ○ 业务模块按功能拆，勿单文件堆 2000 行
│   ├── __init__.py
│   ├── detector.py           #   模型加载与推理封装（与具体板子解耦）
│   ├── controller.py         #   外设/IO/网络控制
│   └── utils.py              #   日志/路径/公共小函数
├── models/                   # ◇ 权重目录：只放 .gitkeep+下载说明，大文件不入库
├── assets/                   # ○ 效果图/截图（README 引用，命名语义化）
├── docs/                     # ◇ quickstart.md（与 README 互补的排障/进阶）
├── tests/                    # ◇ 冒烟测试：无硬件 mock 的可测逻辑
├── scripts/                  # ◇ 开发辅助（烧录/刷机/抓日志）
└── .gitignore                # ● 覆盖模型/日志/虚拟环境/缓存
```

| 路径 | 职责 | 必须/可选 | 说明 |
|------|------|-----------|------|
| README.md | 是什么/能干什么/硬件要求/安装/快速开始/配置表/常见问题 | ● | 中英双语时两版段落对照、同步更新 |
| install.sh | 从零到能跑的全部动作 | ○ | 幂等、无交互或默认值、出错有提示 |
| main.py | 唯一可执行入口 | ● | 名字与 README 教程**完全一致** |
| config.yaml | 可动态调的参数集中地 | ○ | 阈值/时段/路径；代码读不到键=审查红牌 |
| modules/ | 按功能拆分的业务代码 | ○ | 入口薄、逻辑进模块 |
| models/ | 权重文件 | ◇ | 放 .gitkeep + 下载链接/校验和 |
| assets/ | README 配图 | ○ | 别用外链图床，随仓库走 |
| .gitignore | 防误提交 | ● | 见各语言清单 |

demo 要点：clean 环境照 README 能一次跑通；出厂默认终端直跑；
模型来源清晰可下载；无绝对路径/默认 shell 假设；权限随 install.sh 配好。

---

## 模板 2：应用 / 服务（Flask/FastAPI/后端服务）

```
<repo>/
├── README.md                 # ● 是什么/架构图/快速开始/配置说明/API 入口
├── LICENSE                   # ○
├── app/ 或 src/<pkg>/        # ● 包目录
│   ├── __init__.py
│   ├── main.py 或 server.py  #   应用入口/工厂
│   ├── config.py             #   配置加载（环境变量优先 + 默认值）
│   ├── api/ 或 routes/       #   路由层（薄）
│   ├── services/             #   业务逻辑（可测）
│   ├── models/               #   数据模型/ORM
│   └── utils/
├── tests/                    # ○ pytest + fixtures；无网络依赖用 mock
├── requirements.txt / pyproject.toml  # ●
├── .env.example              # ○ 环境变量模板（真 .env 进 gitignore）
├── Dockerfile / docker-compose.yml    # ◇ 有容器化才要
├── .github/workflows/ci.yml  # ◇ lint+test
├── .gitignore                # ●
└── docs/                     # ◇ api.md、deployment.md
```

应用要点：配置三原则（默认值可用、环境变量可覆盖、密钥不进库）；
路由薄/服务厚；.env.example 与代码读取的键一一对应。

---

## 模板 3：库 / SDK（给人 import / 引用的）

```
<repo>/
├── README.md                 # ● 安装/最小示例(3-5 行)/API 速查/变更记录入口
├── LICENSE                   # ● 库必须明确许可
├── pyproject.toml            # ● 打包元数据（或 setup.py/package.json）
├── src/<pkg>/                # ● src 布局，避免 import 歧义
│   ├── __init__.py           #   公开 API 面（__all__）
│   ├── core.py
│   └── ...
├── tests/                    # ● 覆盖公开 API 的 happy+error path
├── examples/                 # ○ 可运行示例（README 最小示例的放大版）
├── docs/                     # ○ API 文档/教程
├── .gitignore                # ●
└── CHANGELOG.md              # ○ 语义化版本配套
```

库要点：公开面最小化；类型标注/文档字符串成体系；示例可运行；
语义化版本 + CHANGELOG；许可与依赖兼容。

---

## 模板 4：内部工具 / 脚本（单脚本或小工具集）

```
<repo>/ 或 <repo>/tools/
├── README.md                 # ● 干什么/怎么跑/依赖/示例（10 行内能懂）
├── <tool>.py 或 <tool>.sh    # ● 每个工具一个文件，名字即功能
├── requirements.txt          # ◇ 有第三方依赖才要
├── tests/                    # ◇ 纯函数部分可测则测
├── config.example.yaml       # ◇ 有配置才要（真配置 gitignore）
└── .gitignore                # ●
```

工具要点：单文件可读（<500 行，超了拆）；argparse 参数化而非改代码；
输出可解析（stdout 干净）；幂等；不依赖个人环境路径。

---

## .gitignore 速查（按运行产物补全）

通用：`*.log` `.DS_Store` `Thumbs.db` `.idea/` `.vscode/`（项目级配置除外）
Python：`__pycache__/` `*.pyc` `.venv/` `venv/` `.pytest_cache/` `.mypy_cache/` `dist/` `build/` `*.egg-info/`
模型/数据：`*.pt` `*.onnx` `*.h5` `*.pth` `*.bin`（若走 release/LFS 下载则整目录忽略）
嵌入式：`*.o` `*.elf` `build/` 编译产物；`*.log` 抓取产物
通用大件：`models/` `weights/` `datasets/` 内容（保留目录用 .gitkeep）
