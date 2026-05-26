# ShowKey Overlay

ShowKey Overlay 由AI生成，是一个用于 Dank Material Shell（DMS）的桌面按键显示插件。它通过 `showmethekey-cli` 读取 Wayland 环境下的键盘事件，并把最近按下的按键以卡片形式显示在 DMS 桌面组件中。

## 功能特性
- 事件驱动显示按键，避免 Desktop Command 高频刷新导致的 CPU 占用。
- 支持多显示器：每个屏幕可以添加一个 ShowKey Overlay 组件。
- 多屏幕下只会有一个实例真正监听键盘，其他组件从共享运行时状态同步显示。
- 新按键显示在底部，旧按键向上堆叠。
- 每条按键提示独立计时，到达设定时间后自动消失。
- 单独按下 `Ctrl`、`Alt`、`Shift`、`Super`、`Compose` 时默认不显示；组合键会显示为 `Ctrl + T`、`Super + Enter` 等形式。
- 每条按键提示使用独立卡片样式，可配置背景、边框、圆角、文字描边和主题色。

## 文件结构

插件安装目录：

```text
~/.config/DankMaterialShell/plugins/showkeyOverlay/
```

目录内主要文件：

```text
plugin.json            DMS 插件清单
metadata.json          插件清单副本，用于兼容不同插件加载方式
Widget.qml             桌面显示组件
Settings.qml           插件设置界面
showkeyStreamer.py     键盘事件监听与多实例同步脚本
README.md              插件说明文档
```

## 工作流程

单屏幕情况下：

```text
ShowKey Overlay Widget
        ↓
启动 showkeyStreamer.py
        ↓
pkexec showmethekey-cli
        ↓
读取键盘事件 JSON
        ↓
输出当前按键列表给 Widget.qml
        ↓
DMS 桌面组件显示按键卡片
```

多屏幕情况下：

```text
第一个 ShowKey Overlay 组件
        ↓
获得运行时锁，成为 leader
        ↓
启动 showmethekey-cli 监听键盘
        ↓
写入共享状态文件

其他 ShowKey Overlay 组件
        ↓
未获得锁，成为 follower
        ↓
监听共享状态文件变化
        ↓
同步显示相同按键
```

这样可以避免每个屏幕都启动一个键盘监听进程。

## 运行时文件

插件会在当前用户的运行时目录下创建中间文件。该目录一般由 `$XDG_RUNTIME_DIR` 指定。

查看当前路径：

```bash
echo "$XDG_RUNTIME_DIR"
```

通常为：

```text
/run/user/1000
```

本插件使用的运行时文件如下：

```text
$XDG_RUNTIME_DIR/showkey-overlay-dms-streamer.lock
$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json
$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json.tmp
```

含义：

| 文件 | 作用 |
|---|---|
| `showkey-overlay-dms-streamer.lock` | 多实例锁文件，用于保证只有一个组件实例真正监听键盘。 |
| `showkey-overlay-dms-state.json` | 多屏幕共享状态文件，保存当前仍在显示的按键文本。 |
| `showkey-overlay-dms-state.json.tmp` | 原子写入时的临时文件，正常情况下只会短暂出现。 |

状态文件内容类似：

```json
{"text": "A\nCtrl + T\nEnter"}
```

该文件只保存当前还未过期的显示内容，不会长期记录完整键盘历史。

## 临时文件清理

`$XDG_RUNTIME_DIR` 通常位于 `/run/user/<UID>`，属于运行时临时目录。关机或重启后会自动清理。

如果需要手动清理，可以执行：

```bash
pkill -f showkeyStreamer.py
pkill -f showmethekey-cli

rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-streamer.lock"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json.tmp"
```

不要删除整个 `$XDG_RUNTIME_DIR`，其中还包含 Wayland、D-Bus、PipeWire 等当前桌面会话正在使用的 socket。

## 依赖

需要以下组件：

- DMS / Dank Material Shell
- Python 3
- `showmethekey-cli`
- `pkexec` / polkit

Arch Linux 上通常需要：

```bash
sudo pacman -S python python-gobject polkit
```

`showmethekey-cli` 由 `showmethekey` 软件包提供。若系统中没有该命令，请先安装 `showmethekey`。

检查命令是否存在：

```bash
command -v showmethekey-cli
command -v pkexec
```

## 安装

将插件目录放入：

```text
~/.config/DankMaterialShell/plugins/showkeyOverlay
```

确认脚本可执行：

```bash
chmod +x ~/.config/DankMaterialShell/plugins/showkeyOverlay/showkeyStreamer.py
```

重启 DMS：

```bash
dms restart
```

## 安全说明

插件运行期间会监听全局键盘事件，用于显示最近按下的按键。插件不会保存完整键盘历史，也不会写入长期日志文件。

输入密码、token 或其他敏感信息前，建议临时关闭该组件，或停止相关进程：

```bash
pkill -f showkeyStreamer.py
pkill -f showmethekey-cli
```

## 卸载

```bash
pkill -f showkeyStreamer.py
pkill -f showmethekey-cli

rm -rf ~/.config/DankMaterialShell/plugins/showkeyOverlay
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-streamer.lock"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json.tmp"

dms restart
```
