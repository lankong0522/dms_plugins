# skeyboardMonitor

## 基础介绍

`skeyboardMonitor` 是一个用于 Dank Material Shell（DMS）的桌面键盘显示插件。它会监听键盘输入，并在桌面上以可配置的悬浮卡片形式显示最近按下的按键，适合录屏演示、操作教学、快捷键展示和日常键盘输入可视化。

插件基于 `showmethekey-cli` 获取 Wayland 环境下的键盘事件，并通过 DMS desktop widget 显示按键历史。插件采用事件驱动方式更新显示内容，不依赖 Desktop Command 的定时轮询机制。

## 主要功能

- 显示最近按下的键盘按键。
- 支持组合键显示，例如 `Ctrl + T`、`Alt + Tab`、`Super + Enter`。
- 单独按下 `Ctrl`、`Alt`、`Shift`、`Super`、`Compose` 时默认不单独显示，但会参与组合键显示。
- 每个按键提示以独立卡片显示。
- 支持多屏显示：每个显示器可以放置一个组件，只有一个实例负责监听键盘，其他实例同步显示共享状态。
- 支持配置显示位置：左上、右上、左下、右下。
- 支持控制新按键是否靠近所选角落显示。
- 支持设置显示时间、最大显示行数、去重间隔、字体大小、边距、卡片间距和卡片内边距。
- 支持使用 DMS 主题主色作为文字颜色。
- 支持文字描边，提升浅色背景下的可读性。
- 支持卡片背景、卡片边框、边框透明度、边框厚度和圆角设置。

## 依赖

- DMS / DankMaterialShell
- Quickshell
- Python 3
- `showmethekey-cli`
- `pkexec`
- Wayland 会话

## 依赖安装说明

Arch Linux 参考：

```bash
sudo pacman -S python polkit
sudo pacman -S showmethekey
```

如果 `showmethekey` 不在当前软件源中，请使用系统可用的软件包或 AUR 包。

确认命令可用：

```bash
showmethekey-cli --help
python3 --version
```

安装插件：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r skeyboardMonitor ~/.config/DankMaterialShell/plugins/
chmod +x ~/.config/DankMaterialShell/plugins/skeyboardMonitor/showkeyStreamer.py
dms ipc call plugins reload skeyboardMonitor
```

如果热重载无效，重启 DMS：

```bash
dms restart
```

然后在 DMS 的插件或桌面组件管理界面中添加 `skeyboardMonitor`。

## 其他特殊说明

- `showmethekey-cli` 在 Wayland 下需要读取输入设备事件，启动时可能会触发 `pkexec` 权限认证。
- 插件不会保存长期按键历史，也不会主动上传数据。
- 插件只在当前会话运行时目录中维护临时状态，用于多屏同步。
- 多屏使用时可以在每个显示器分别添加一个 `skeyboardMonitor` 组件。
- 正常情况下只有一个插件实例会成为 leader 并启动 `showmethekey-cli`，其他实例作为 follower 读取共享状态。
- 输入密码、密钥、令牌等敏感信息前，建议临时关闭插件或停止相关进程。

多屏同步机制：

```text
每个屏幕放置一个 skeyboardMonitor 组件
        ↓
第一个获得锁的组件成为 leader
        ↓
leader 启动 showmethekey-cli 并监听键盘事件
        ↓
leader 将当前按键状态写入运行时状态文件
        ↓
其他组件作为 follower 读取同一个状态文件并同步显示
```

检查相关进程：

```bash
pgrep -af "showkeyStreamer.py|showmethekey-cli"
```

临时停止监听：

```bash
pkill -f showkeyStreamer.py
pkill -f showmethekey-cli
```

## 文件结构及作用

插件目录建议放在：

```text
~/.config/DankMaterialShell/plugins/skeyboardMonitor/
```

目录结构：

```text
skeyboardMonitor/
├── plugin.json
├── metadata.json
├── Widget.qml
├── Settings.qml
├── showkeyStreamer.py
└── README.md
```

各文件作用：

| 文件 | 作用 |
|---|---|
| `plugin.json` | DMS 插件清单，定义插件 ID、名称、描述、类型、组件入口和设置入口。 |
| `metadata.json` | 插件元数据，通常与 `plugin.json` 保持一致，用于兼容 DMS 插件识别逻辑。 |
| `Widget.qml` | 插件显示层，负责接收按键状态、渲染桌面卡片、处理布局位置和样式。 |
| `Settings.qml` | 插件设置页，提供显示时间、字体、位置、背景、边框等可调参数。 |
| `showkeyStreamer.py` | 事件流脚本，负责调用 `showmethekey-cli`、解析键盘事件、维护按键历史和多屏共享状态。 |
| `README.md` | 插件说明文档。 |

## 运行时中间文件

插件会在 `$XDG_RUNTIME_DIR` 下创建运行时文件。该目录通常是：

```text
/run/user/<uid>
```

如果 `$XDG_RUNTIME_DIR` 不存在，脚本会回退到 `/tmp`。

运行时文件包括：

```text
$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json
$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json.tmp
$XDG_RUNTIME_DIR/showkey-overlay-dms-streamer.lock
```

各文件作用：

| 文件 | 作用 |
|---|---|
| `showkey-overlay-dms-state.json` | 多屏共享状态文件。leader 实例把当前按键显示内容写入该文件，follower 实例读取它并同步显示。 |
| `showkey-overlay-dms-state.json.tmp` | 写入共享状态时使用的临时文件，正常情况下会被替换为正式状态文件。 |
| `showkey-overlay-dms-streamer.lock` | leader 锁文件，用于保证只有一个插件实例真正启动 `showmethekey-cli` 监听键盘。 |

这些文件位于运行时目录中，属于临时文件。正常情况下，注销、重启或关机后会自动清理。

不要删除整个 `$XDG_RUNTIME_DIR` 或 `/run/user/<uid>`，其中还包含 Wayland、D-Bus、PipeWire 等桌面会话正在使用的运行时文件。

## 插件删除（包括临时文件）

删除前建议先在 DMS 的插件或桌面组件管理界面中禁用 `skeyboardMonitor`，或从所有桌面屏幕上移除该组件。

停止相关进程：

```bash
pkill -f showkeyStreamer.py
pkill -f showmethekey-cli
```

删除插件目录：

```bash
rm -rf ~/.config/DankMaterialShell/plugins/skeyboardMonitor
```

删除运行时临时文件：

```bash
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-state.json.tmp"
rm -f "$XDG_RUNTIME_DIR/showkey-overlay-dms-streamer.lock"
rm -f /tmp/showkey-overlay-dms-state.json
rm -f /tmp/showkey-overlay-dms-state.json.tmp
rm -f /tmp/showkey-overlay-dms-streamer.lock
```

重新加载插件或重启 DMS：

```bash
dms ipc call plugins reload skeyboardMonitor
dms restart
```
