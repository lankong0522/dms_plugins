# dmsPlugins

这个仓库用于集中管理本地编写的 Dank Material Shell（DMS）插件。每个插件以独立文件夹存放，文件夹名就是本仓库中使用的插件名称。

插件可以复制到 DMS 插件目录中使用：

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r <插件文件夹名> ~/.config/DankMaterialShell/plugins/
dms restart
```

也可以在 DMS 支持热重载时执行：

```bash
dms ipc call plugins reload <插件文件夹名>
```

## 文件夹说明

| 文件夹 | 作用 |
|---|---|
| `skeyboardMonitor` | 键盘输入监视插件。用于监听键盘事件，并在桌面上以悬浮卡片形式显示最近按下的按键，适合录屏、教学和快捷键展示。 |
| `mihomoManager` | mihomo 管理插件。用于在 DMS 中查看和控制 `mihomo.service`，显示 TUN 状态、代理节点、延迟、订阅流量和外网连接流量等信息。 |
| `.agents` | 本仓库的本地辅助配置目录，目前不属于 DMS 插件内容。 |
| `.codex` | Codex 相关的本地辅助配置目录，目前不属于 DMS 插件内容。 |

## 插件目录约定

每个插件目录通常包含以下文件：

| 文件 | 作用 |
|---|---|
| `plugin.json` | DMS 插件清单，定义插件 ID、名称、入口组件、设置页、权限和兼容版本等信息。 |
| `README.md` | 单个插件的使用说明、依赖、配置项和故障排查。 |
| `*.qml` | 插件界面、组件逻辑或设置页面。 |
| `*.py` | 插件运行时需要的辅助脚本。 |
| `metadata.json` | 部分插件用于兼容或补充识别信息的元数据文件。 |

插件 README 的统一写法见 [`PLUGIN_README_GUIDE.md`](PLUGIN_README_GUIDE.md)。

## 当前插件

### skeyboardMonitor

桌面键盘显示插件。它通过 `showmethekey-cli` 获取键盘输入事件，并在 DMS 桌面组件中显示按键历史。

详细说明见 [`skeyboardMonitor/README.md`](skeyboardMonitor/README.md)。

### mihomoManager

DankBar / Control Center 代理管理插件。它面向本机用户级 `mihomo.service`，提供服务控制、节点切换、延迟测试和状态展示等功能。

详细说明见 [`mihomoManager/README.md`](mihomoManager/README.md)。
