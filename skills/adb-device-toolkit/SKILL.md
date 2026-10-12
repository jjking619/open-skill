---
name: adb-device-toolkit
description: "Practical adb workflows for Android and embedded boards: identifying devices and choosing among several, execution identity (root vs regular user), file transfer with checksums, detaching long tasks from the adb session, forward vs reverse, and a troubleshooting table. Use when debugging a board or Android device over adb."
version: 0.1.0
author: "kane.ji"
license: MIT
platforms: [windows, linux, macos]
---

# adb Device Toolkit

Make "connect to the board / Android device and get work done" repeatable:
**identify the device → know the execution identity → transfer with verification → detach long tasks → look up the error**.

## When to Use

- Running commands, installing dependencies, or reproducing issues on a board or Android device over USB or network adb
- Several devices attached, or the device serial isn't identifiable
- Long-running tasks, reboots, or letting the device reach a service on the host
- Not for: reading logs only (a serial console or SSH is often better); regular Android app development

## Prerequisites

- adb on the host; USB debugging enabled on the device (or network adb paired)
- `adb devices` shows the device in state `device` (not `unauthorized` / `offline`)

## Procedure

**① Identify the device — read `-l`, then pin the selection**

```bash
adb devices -l                  # includes model and transport_id
adb -s <serial> shell ...       # select by serial
adb -t <transport_id> shell ... # select by transport_id when the serial is unusable
```

The model appears in the `-l` output (`model:` / `device:` fields). With multiple devices, identify by model first, then pin `-s` / `-t` on every command — never rely on the default target.

**② Establish the execution identity (the most common source of false conclusions)**

```bash
adb shell whoami            # often root
adb shell 'ls /home'        # the real regular user on the board
```

Root and the regular user are **two separate environments**: `~`, `python3`, and installed packages differ (root defaults to `HOME=/root`; packages root installed are invisible to the regular user).
Documentation is usually written from the regular user's perspective, so "works as root" is **not** the same as "works for the user". Run commands, install dependencies, and accept results as the target user (e.g. force `HOME=/home/<user>` and `chown` back afterwards, or switch users).

**③ Transfer files with push/pull, not shell redirection**

```bash
adb push ./pkg.tar.xz /data/local/tmp/ && adb shell md5sum /data/local/tmp/pkg.tar.xz
md5sum ./pkg.tar.xz      # compare both sides
```

`adb shell "cat > file"` goes through a pty and corrupts binaries with echo/rewriting; small text files can use a base64 pipe, binaries always use `adb push`.

**④ Long tasks and reboots: detach from the session, then poll**

```bash
adb shell 'setsid bash -c "your-long-command > /tmp/run.log 2>&1" < /dev/null &'
adb shell 'tail -n 40 /tmp/run.log'      # poll
adb shell 'systemctl --no-block reboot'  # prefer this over (sleep 2; reboot) &
```

Background children started inside an adb session are reaped when the session exits — `setsid` plus `< /dev/null` is what keeps them alive.

**⑤ Port directions: forward and reverse are not the same**

- `adb forward tcp:8000 tcp:8000` — host port → **device** (host reaches a device service)
- `adb reverse tcp:8000 tcp:8000` — device port → **host** (device reaches a host service, e.g. a proxy for temporary connectivity)
- **reverse is not supported by every adbd**: `error: closed` means it isn't → plan an alternative instead of retrying

**⑥ Retrieving large output**

`adb exec-out cat bigfile` occasionally returns `error: closed` → use `adb pull <remote> <local>` and read it from disk instead of retrying exec-out.

## Troubleshooting

| Symptom | Diagnosis / action |
|---|---|
| `adb devices` empty | Cable / driver / debugging toggle; for network adb check `adb connect <ip>:5555` |
| `unauthorized` | Accept the prompt on the device; `adb kill-server && adb devices` |
| Command lands on the wrong device | Always pass `-s` / `-t`; never trust the default |
| `error: closed` (reverse, exec-out) | That adbd doesn't support it → use another method, don't retry blindly |
| Dependency install fails: disk full | `df -h` first; embedded root filesystems ship nearly full — install to `/data` or a configurable path |
| Peripherals (camera, serial) not enumerated | USB-host and adb can be mutually exclusive on the board — a property, not a fault |

## Pitfalls

- **Don't hardcode a username**: read it from `ls /home` instead of assuming `pi` or similar.
- **Don't transfer binaries through a pty**: see ③.
- **Don't declare success from a root run**: re-verify as the target user.
- **Don't background children inside an adb session**: they die with the session — use `setsid` plus `< /dev/null`.
- **Don't skip the second checksum**: a one-sided md5 is no verification at all.

## Verification

- [ ] `adb devices -l` uniquely identifies the target, and commands carry `-s` / `-t`
- [ ] Execution identity matches the documentation's perspective (or was handled equivalently); acceptance ran as the target user
- [ ] Transferred files have matching md5 on both sides
- [ ] Long tasks run detached via `setsid`, with a pollable log
- [ ] Free disk space checked with `df` before installing
