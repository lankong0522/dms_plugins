import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "mihomoManager"

    StyledText {
        width: parent.width
        text: "mihomoManager Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "这些设置只影响 DMS 插件读取和控制 mihomo，不会修改 ~/.config/mihomo/config.yaml。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "serviceName"
        label: "Systemd User Service"
        description: "通常保持为 mihomo.service。"
        placeholder: "mihomo.service"
        defaultValue: "mihomo.service"
    }

    StringSetting {
        settingKey: "controllerUrl"
        label: "External Controller URL"
        description: "对应 config.yaml 里的 external-controller: 127.0.0.1:9090。"
        placeholder: "http://127.0.0.1:9090"
        defaultValue: "http://127.0.0.1:9090"
    }

    StringSetting {
        settingKey: "mixedPort"
        label: "Mixed Port"
        description: "对应 config.yaml 里的 mixed-port。"
        placeholder: "7890"
        defaultValue: "7890"
    }

    StringSetting {
        settingKey: "proxyGroup"
        label: "Proxy Group"
        description: "用于节点切换的代理组名称。建议填写 default、自动选择 或你的 select 类型代理组。"
        placeholder: "default"
        defaultValue: "default"
    }

    StringSetting {
        settingKey: "dashboardUrl"
        label: "Dashboard URL"
        description: "点击打开面板时访问的地址。没有本地 UI 时可以改成你使用的 Web 面板地址。"
        placeholder: "http://127.0.0.1:9090/ui"
        defaultValue: "http://127.0.0.1:9090/ui"
    }

    StringSetting {
        settingKey: "nodesPerPage"
        label: "Nodes Per Page"
        description: "节点列表每页显示数量。默认 12；如果 bar/popout 空间足够，可以改成 20 或 30。"
        placeholder: "12"
        defaultValue: "12"
    }

    StringSetting {
        settingKey: "delayTestUrl"
        label: "Delay Test URL"
        description: "用于 mihomo 节点延迟测试的 URL。默认使用 Google 204 测试地址。"
        placeholder: "https://www.gstatic.com/generate_204"
        defaultValue: "https://www.gstatic.com/generate_204"
    }

    StringSetting {
        settingKey: "delayTimeoutMs"
        label: "Delay Timeout Ms"
        description: "节点延迟测试超时时间，单位毫秒。默认 5000。"
        placeholder: "5000"
        defaultValue: "5000"
    }

    StringSetting {
        settingKey: "autoDelayTest"
        label: "Auto Delay Test"
        description: "是否自动测试当前节点延迟。填 true 或 false。"
        placeholder: "true"
        defaultValue: "true"
    }

    StringSetting {
        settingKey: "showDelayInBar"
        label: "Show Delay In Bar"
        description: "是否在 DankBar 上显示当前节点延迟。填 true 或 false。"
        placeholder: "true"
        defaultValue: "true"
    }

    StringSetting {
        settingKey: "showTrafficInBar"
        label: "Show Traffic In Bar"
        description: "是否在 DankBar 上显示订阅剩余流量。填 true 或 false。"
        placeholder: "true"
        defaultValue: "true"
    }

    StringSetting {
        settingKey: "showExternalTrafficInBar"
        label: "Show External Traffic In Bar"
        description: "是否在 DankBar 上显示走外网的活跃连接流量。填 true 或 false；mihomo 关闭时会自动隐藏。"
        placeholder: "true"
        defaultValue: "true"
    }

    StringSetting {
        settingKey: "externalTrafficIntervalMs"
        label: "External Traffic Refresh Ms"
        description: "外网流量刷新间隔，单位毫秒。默认 3000；太小会增加 mihomo API 调用频率。"
        placeholder: "3000"
        defaultValue: "3000"
    }

    StringSetting {
        settingKey: "subscriptionUrl"
        label: "Subscription URL"
        description: "用于读取剩余流量的订阅链接。留空时只会尝试读取 config.yaml 开头的 subscription-userinfo 注释。"
        placeholder: "https://example.com/api/v1/client/subscribe?..."
        defaultValue: ""
    }

    StringSetting {
        settingKey: "subscriptionUserAgent"
        label: "Subscription User-Agent"
        description: "有些服务商只有在 UA 包含 clash 时才返回 subscription-userinfo。"
        placeholder: "clash.meta"
        defaultValue: "clash.meta"
    }


    StringSetting {
        settingKey: "configPath"
        label: "Mihomo Config Path"
        description: "用于从配置文件开头注释读取 subscription-userinfo 的路径。"
        placeholder: "~/.config/mihomo/config.yaml"
        defaultValue: "~/.config/mihomo/config.yaml"
    }

}
