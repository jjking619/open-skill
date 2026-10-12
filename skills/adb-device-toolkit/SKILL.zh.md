# adb 设备联调套路（adb Device Toolkit）

把「连上板子 / Android 设备干活」这件事做得可复现：**先认设备 → 认清执行身份 → 传文件要校验 → 长任务脱离会话 → 报错有对照表**。

## 何时使用（When to Use）

- 通过 USB 或网络连板子 / Android 设备跑命令、装依赖、复现问题
- 多台设备同时连着，或设备序列号认不出来
- 需要在设备上跑长任务、重启、或让设备访问 PC 上的服务
- 不适用：只读日志用串口/SSH 更合适；纯 Android 应用开发用 `adb logcat` 之外的 IDE 工具

## 前置（Prerequisites）

- PC 有 adb；设备已开 USB 调试（或网络 adb 已配对）
- `adb devices` 能看到设备且状态为 `device`（不是 `unauthorized` / `offline`）

## 流程（Procedure）

**① 认设备：先看 `-l`，再决定选择方式**
```bash
adb devices -l        # 输出含型号、transport_id
adb -s <serial> shell ...     # 用序列号选设备
adb -t <transport_id> shell ...   # 序列号认不出/为空的设备用 transport_id
```
型号能从 `-l` 的 `model:` / `device:` 字段看出来 —— 多设备时先按型号认，再固定用 `-t` / `-s`，避免命令落到别的设备上。

**② 认清执行身份（最常见的误判来源）**
```bash
adb shell whoami            # 常是 root
adb shell 'ls /home'        # 板上真正的普通用户名
```
root 与普通用户是**两套环境**：`~`、`python3`、`pip` 装的包都不同（root 默认 `HOME=/root`，普通用户看不到 root 装的包）。
文档通常按普通用户视角写 → 以 root「跑通」**不等于**用户侧能跑。执行、装依赖、验收都要带上目标用户身份（必要时 `HOME=/home/<user>` + 事后 `chown` 回属主）。

**③ 传文件：用 push/pull，别用 shell 重定向**
```bash
adb push ./pkg.tar.xz /data/local/tmp/ && adb shell md5sum /data/local/tmp/pkg.tar.xz
md5sum ./pkg.tar.xz      # 双边核对
```
`adb shell "cat > file"` 走 pty，二进制会被回显/转义污染；小程序文本可走 base64 管道，二进制一律 `adb push`。

**④ 长任务与重启：脱离会话再轮询**
```bash
adb shell 'setsid bash -c "你的长命令 > /tmp/run.log 2>&1" < /dev/null &'
adb shell 'tail -n 40 /tmp/run.log'      # 轮询
adb shell 'systemctl --no-block reboot'  # 重启（别用 (sleep 2; reboot) & —— 会随会话被回收）
```

**⑤ 端口方向：forward 与 reverse 不一样**
- `adb forward tcp:8000 tcp:8000`：PC 的端口转发到**设备**（PC 访问设备服务）
- `adb reverse tcp:8000 tcp:8000`：设备的端口转发到 **PC**（设备访问 PC 服务，如给板子临时借网/代理）
- **reverse 不是所有 adbd 都支持**：报 `error: closed` 就是不支持 → 准备替代方案（设备侧直连、或改走 forward 反向拉）

**⑥ 大输出取回**
`adb exec-out cat bigfile` 偶发 `error: closed` → 改成 `adb pull <远端> <本地>` 落盘再读，别反复重试 exec-out。

## 常见报错对照（Troubleshooting）

| 现象 | 判据 / 处置 |
|---|---|
| `adb devices` 空 | 线/驱动/调试开关；网络 adb 检查 `adb connect <ip>:5555` |
| `unauthorized` | 设备上确认授权弹窗；`adb kill-server && adb devices` 重来 |
| 多设备时命令落到错的设备 | 一律带 `-s` / `-t`，不要依赖默认 |
| `error: closed`（reverse / exec-out） | 该 adbd 不支持该功能 → 换手段，不要反复重试 |
| 装依赖报磁盘满 | 先 `df -h`，嵌入式设备根分区常出厂即满；装到 `/data` 或可配置路径 |
| 外设（摄像头/串口）枚举不到 | 板子在 adb/USB-host 之间可能互斥，属正常特性而非故障 |

## 坑（Pitfalls）

- **不要硬编码用户名**：实际用户名取自 `ls /home`，别写死 `pi`。
- **不要用 pty 传二进制**：见 §③。
- **不要以 root 跑通就宣布通过**：必须目标用户身份复验。
- **不要在 adb 会话里挂后台子进程**：会话退出即收走，用 `setsid` + `< /dev/null`。
- **别忘双边校验**：传完文件只做单边 md5 等于没校验。

## 验收（Verification）

- [ ] `adb devices -l` 能唯一确定目标设备，命令都带 `-s` / `-t`
- [ ] 执行身份与文档视角一致（或已等价处理），验收在目标用户身份下完成
- [ ] 传入/取出的文件双边 md5 一致
- [ ] 长任务用 `setsid` 脱离会话，日志可轮询到
- [ ] 磁盘空间在装之前 `df` 确认过
