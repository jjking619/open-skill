# Windows Shell 工具链坑（Windows + git-bash / MSYS）

在 Windows 的 git-bash（MSYS2）里跑命令、写脚本、混调原生工具（git / node / python / rg）时的实测坑与对策。
目标是：**同一条命令换台机器也能跑**。

## 何时使用（When to Use）

- git-bash 里调用原生 Windows 程序报「找不到文件 / cannot change to / no such file」
- 脚本生成或修改后出现诡异行为：多出回车、反斜杠消失、中文乱码
- 不确定该用 POSIX 还是 Windows 路径、要不要加引号
- 交互式 CLI 在 Windows 上喂输入没反应
- 不适用：WSL2（里面是真 Linux）、纯 PowerShell 环境

## 六条核心规则（Core Rules）

**① 路径转换默认关闭**
给原生程序传路径用 `C:/Users/x/file`（正斜杠）或 `C:\Users\x\file`；**不要**用 `/c/Users/x`。
`cd` 是 bash 内建，`/c/...` 对它有效 —— 所以「`cd` 能进、后面的原生工具说找不到」是典型症状。

**② 不要用 PowerShell 语法**
`$env:FOO`、`Get-ChildItem`、`Select-String`、`$PROFILE` 在 git-bash 里不生效；对应写成 `$FOO`、`ls`、`grep`。

**③ 含空格或中文的路径必须整体加引号**
例如 `"/d/项目 空间/目录"`；`cd` 后面也一样。

**④ 行尾统一 LF**
仓库放 `.gitattributes`：`* text=auto eol=lf`。脚本本身用 LF；Windows 编辑器产出的 CRLF 文件别直接入库或参与 diff。

**⑤ 输出编码显式设 UTF-8**
控制台常是 GBK —— 打印中文的 Python 先
`import sys; sys.stdout.reconfigure(encoding='utf-8')`，或先 `export PYTHONIOENCODING=utf-8`；
**别用 `python -c` 传中文路径或长中文串**（转义与编码双重风险）。

**⑥ 交互输入按「回车」提交**
Windows 上 Enter 是 CR，只发 `\n` 往往不生效 → 用提交式写入（文本 + Enter），或优先选非交互参数（`--yes`、`--with-token`、配置文件）。

## 落盘与转义（File Writes）

- **heredoc**：用带引号的 `<<'EOF'` 防变量展开。
- **反斜杠保真**：多层转义下不保证可靠。要判断文件里是否有字面反斜杠，用**字节检查**（`od -c`、`grep -c $'\x5c'`），别写 `count("\\n")` 这类双反斜杠代码下结论。
- **长文与路径多的文件**：整文件写入，不要用 heredoc 逐字符调试；怀疑坏了就整份重写。
- **写完回读**：对比字节长度与开头几个字节（`od -c`），确认没截断、没多 `\r`。

## 排查顺序（命令行为不对时）

1. 这条命令是 bash 内建还是原生程序？→ 原生程序先把路径换成 `C:/...`
2. 路径含空格 / 中文 / 反斜杠？→ 先整体加引号再试
3. 乱码或多出回车？→ 查编码（GBK vs UTF-8）与行尾（CRLF vs LF）
4. 交互卡住？→ 换非交互参数，或改成提交式输入
5. 上面都不解释？→ 用 `od -c` / `--version` / `pwd` 打印实际环境，别靠猜

## 坑（Pitfalls）

- **只改一半路径**：`cd /c/x` 成功不代表传给 git/python 的 `/c/x` 也能用。
- **`\n` 当换行发**：交互程序不认，表现为「命令发出去了但没执行」。
- **中文 print 崩在编码上**：报 `UnicodeEncodeError` 或输出问号 —— 先设 UTF-8 再排查别的。
- **CRLF 混入 diff**：整文件显示被改（其实只差行尾）→ 检查编辑器与 `.gitattributes`。

## 验收（Verification）

- [ ] 脚本里没有 `$env:` / PowerShell 内建；路径参数是 `C:/` 形式或已加引号
- [ ] 生成的文件 `od -c` 头部正常：无多余 `\r`、无截断、中文可读
- [ ] 显式设置了 UTF-8（脚本内或环境变量）
- [ ] 在干净 shell 里重跑一遍仍然通过
