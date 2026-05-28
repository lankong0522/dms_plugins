# 插件 README 书写规范

本文档用于统一本仓库中每个 DMS 插件目录下 `README.md` 的写法。新增或修改插件说明时，优先按照本文档的章节顺序和表达方式编写。

## 基本原则

- 全文使用中文。
- 插件名称使用当前插件文件夹名称，例如 `skeyboardMonitor`、`mihomoManager`。
- 插件 README 只说明当前插件，不混写其他插件内容。
- 命令示例默认面向当前仓库复制到 DMS 插件目录的使用方式。
- 涉及路径、命令、文件名、配置项、服务名时使用反引号。
- 说明要以可执行、可排查、可删除为目标，避免只写概念。
- 如果插件不会创建运行时临时文件，也要明确写出“不创建独立的运行时临时文件”。

## 固定章节顺序

每个插件 README 必须按以下顺序组织：

```markdown
# 插件文件夹名称

## 基础介绍

## 主要功能

## 依赖

## 依赖安装说明

## 其他特殊说明

## 文件结构及作用

## 运行时中间文件

## 插件删除（包括临时文件）
```

## 各章节写法

### 基础介绍

说明插件是什么、用于什么场景、在 DMS 中以什么形式运行。

必须包含：

- 插件名称。
- 插件用途。
- 插件面向的 DMS 位置或类型，例如 desktop widget、DankBar、Control Center。
- 是否会修改外部配置文件。如果不会，明确写出不会修改。

示例：

```markdown
`插件名称` 是一个用于 Dank Material Shell（DMS）的某某插件。它用于……。

插件默认读取……。插件不会修改……。
```

### 主要功能

使用列表列出插件能力。每条功能尽量只写一个点。

建议包含：

- 显示类功能。
- 控制类功能。
- 配置类功能。
- 多屏、状态同步、测速、外部 API 等特殊能力。

### 依赖

列出运行插件需要的环境、命令、服务和外部程序。

依赖应包含：

- DMS / DankMaterialShell。
- Quickshell。
- 插件实际调用的命令，例如 `curl`、`python3`、`systemctl --user`。
- 插件依赖的外部服务或配置。

### 依赖安装说明

给出至少一种安装参考。当前仓库优先使用 Arch Linux 示例。

建议包含：

- 依赖安装命令。
- 依赖检查命令。
- 插件安装命令。
- 插件重载命令。
- 热重载失败时的 `dms restart`。

插件安装命令统一写法：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r 插件文件夹名称 ~/.config/DankMaterialShell/plugins/
dms ipc call plugins reload 插件文件夹名称
```

如果插件包含需要执行权限的脚本，需要额外写出：

```bash
chmod +x ~/.config/DankMaterialShell/plugins/插件文件夹名称/脚本名称
```

### 其他特殊说明

写插件运行时需要用户特别知道的内容。

可以包含：

- 权限说明。
- 安全说明。
- 外部配置要求。
- 多屏机制。
- API 地址、服务名、代理组等默认假设。
- 订阅流量、延迟测试、临时状态等容易误解的内容。

不要把基础安装步骤重复写在这里。

### 文件结构及作用

先说明建议安装目录，再给出目录结构，最后用表格解释每个文件作用。

目录结构示例：

```text
插件文件夹名称/
├── plugin.json
├── Widget.qml
├── Settings.qml
└── README.md
```

文件作用表格示例：

| 文件 | 作用 |
|---|---|
| `plugin.json` | DMS 插件清单，定义插件 ID、名称、类型、入口组件、设置页、权限和兼容版本等信息。 |
| `README.md` | 插件说明文档。 |

### 运行时中间文件

说明插件运行期间是否会创建临时文件、状态文件、锁文件或缓存文件。

如果有运行时文件，必须写出：

- 文件所在目录。
- 文件完整名称。
- 每个文件的作用。
- 是否可以删除。
- 删除时的注意事项。

如果没有运行时文件，明确写：

```markdown
`插件名称` 不创建独立的运行时临时文件。
```

如果插件调用外部命令但不落盘，可以列出命令和用途。

### 插件删除（包括临时文件）

说明如何彻底删除插件。

必须包含：

- 删除前先在 DMS 中禁用或移除插件。
- 停止相关进程。如果插件没有长期进程，可说明无需停止。
- 删除插件目录。
- 删除运行时临时文件。
- 重载插件或重启 DMS。
- 明确不会删除哪些外部配置或服务。

删除插件目录示例：

```bash
rm -rf ~/.config/DankMaterialShell/plugins/插件文件夹名称
```

删除临时文件示例：

```bash
rm -f "$XDG_RUNTIME_DIR/临时文件名"
rm -f /tmp/临时文件名
```

## 模板

复制下面模板到插件目录的 `README.md` 后，再替换占位内容。

````markdown
# 插件文件夹名称

## 基础介绍

`插件文件夹名称` 是一个用于 Dank Material Shell（DMS）的……插件。它用于……。

插件……。插件不会修改……。

## 主要功能

- ……
- ……
- ……

## 依赖

- DMS / DankMaterialShell
- Quickshell
- `命令或服务`

## 依赖安装说明

Arch Linux 参考：

```bash
sudo pacman -S 依赖包
```

确认依赖可用：

```bash
命令 --version
```

安装插件：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r 插件文件夹名称 ~/.config/DankMaterialShell/plugins/
dms ipc call plugins reload 插件文件夹名称
```

如果热重载无效，重启 DMS：

```bash
dms restart
```

然后在 DMS 的插件管理界面中启用 `插件文件夹名称`。

## 其他特殊说明

- ……
- ……

## 文件结构及作用

插件目录建议放在：

```text
~/.config/DankMaterialShell/plugins/插件文件夹名称/
```

目录结构：

```text
插件文件夹名称/
├── plugin.json
└── README.md
```

各文件作用：

| 文件 | 作用 |
|---|---|
| `plugin.json` | DMS 插件清单，定义插件 ID、名称、类型、入口组件、设置页、权限和兼容版本等信息。 |
| `README.md` | 插件说明文档。 |

## 运行时中间文件

`插件文件夹名称` 不创建独立的运行时临时文件。

## 插件删除（包括临时文件）

删除前建议先在 DMS 中禁用 `插件文件夹名称`，或从相关位置移除该插件。

删除插件目录：

```bash
rm -rf ~/.config/DankMaterialShell/plugins/插件文件夹名称
```

删除运行时临时文件：

```bash
rm -f "$XDG_RUNTIME_DIR/临时文件名"
rm -f /tmp/临时文件名
```

重新加载插件或重启 DMS：

```bash
dms ipc call plugins reload 插件文件夹名称
dms restart
```
````
