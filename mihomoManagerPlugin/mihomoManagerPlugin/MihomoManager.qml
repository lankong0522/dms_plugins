import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "mihomo-manager"

    property string serviceName: pluginData.serviceName || "mihomo.service"
    property string controllerUrl: pluginData.controllerUrl || "http://127.0.0.1:9090"
    property string mixedPort: pluginData.mixedPort || "7890"
    property string proxyGroup: pluginData.proxyGroup || "default"
    property string dashboardUrl: pluginData.dashboardUrl || "http://127.0.0.1:9090/ui"
    property string subscriptionUrl: pluginData.subscriptionUrl || ""
    property string subscriptionUserAgent: pluginData.subscriptionUserAgent || "clash.meta"
    property string configPath: pluginData.configPath || "~/.config/mihomo/config.yaml"
    property int nodesPerPage: parseInt(pluginData.nodesPerPage || "12")

    property string serviceState: "checking"
    property bool serviceActive: serviceState === "active"
    property bool tunActive: false
    property bool apiOnline: false
    property string currentNode: ""
    property string selectedGroup: proxyGroup
    property var nodeList: []
    property string nodeFilter: ""
    property int nodePage: 0
    property string trafficInfo: "未读取订阅流量。请在设置里填写订阅链接，或点击刷新读取配置文件首部注释。"
    property string trafficShortInfo: ""
    property bool showTrafficInBar: String(pluginData.showTrafficInBar || "true") !== "false"
    property bool showExternalTrafficInBar: String(pluginData.showExternalTrafficInBar || "true") !== "false"
    property int externalTrafficIntervalMs: parseInt(pluginData.externalTrafficIntervalMs || "3000")
    property string externalTrafficInfo: "代理关闭时不显示外网流量。"
    property string externalTrafficShortInfo: ""
    property double externalTrafficLastUpload: 0
    property double externalTrafficLastDownload: 0
    property double externalTrafficLastTimeMs: 0
    property string delayInfo: "未测速"
    property string currentDelayText: "-- ms"
    property string pendingDelayNode: ""
    property string lastDelayNode: ""
    property var nodeDelayMap: ({})
    property string delayTestUrl: pluginData.delayTestUrl || "https://www.gstatic.com/generate_204"
    property int delayTimeoutMs: parseInt(pluginData.delayTimeoutMs || "5000")
    property bool autoDelayTest: String(pluginData.autoDelayTest || "true") !== "false"
    property bool showDelayInBar: String(pluginData.showDelayInBar || "true") !== "false"
    property string lastResult: "Ready"

    popoutWidth: 500
    popoutHeight: 820

    ccWidgetIcon: serviceActive ? "vpn_key" : "vpn_key_off"
    ccWidgetPrimaryText: "Mihomo"
    ccWidgetSecondaryText: serviceActive ? (tunActive ? "Active • TUN" : "Active • Proxy") : "Inactive"
    ccWidgetIsActive: serviceActive

    onCcWidgetToggled: {
        if (serviceActive) {
            stopService()
        } else {
            startService()
        }
    }

    onServiceActiveChanged: {
        if (!serviceActive) {
            clearExternalTraffic("代理关闭，外网流量已隐藏。")
        } else if (showExternalTrafficInBar) {
            refreshExternalTraffic()
        }
    }

    onShowExternalTrafficInBarChanged: {
        if (!showExternalTrafficInBar) {
            clearExternalTraffic("外网流量显示已关闭。")
        } else if (serviceActive) {
            refreshExternalTraffic()
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: root.serviceActive ? "vpn_key" : "vpn_key_off"
                size: Theme.iconSize
                color: root.serviceActive ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.barText()
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: root.serviceActive ? "vpn_key" : "vpn_key_off"
                size: Theme.iconSize
                color: root.serviceActive ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.currentDelayText !== "-- ms" ? root.currentDelayText.replace(" ms", "") : (root.tunActive ? "TUN" : "M")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Mihomo Manager"
            detailsText: root.serviceActive ? "Service active. " + (root.tunActive ? "TUN is enabled." : "Proxy port only.") : "Service inactive."
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledRect {
                    width: parent.width
                    implicitHeight: 118
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "状态：" + root.serviceState + "    TUN：" + (root.tunActive ? "on" : "off")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                        }

                        StyledText {
                            text: "代理端口：127.0.0.1:" + root.mixedPort + "    控制器：" + root.controllerUrl
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        StyledText {
                            text: root.apiOnline ? "代理组：" + root.selectedGroup + "    当前节点：" + root.currentNode : "API：离线或未响应"
                            color: root.apiOnline ? Theme.primary : Theme.error
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        StyledText {
                            text: "当前延迟：" + root.currentDelayText + "    测速地址：" + root.delayTestUrl
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "play_arrow"
                        label: "启动"
                        onClicked: root.startService()
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "restart_alt"
                        label: "重启"
                        onClicked: root.restartService()
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "stop"
                        label: "停止"
                        onClicked: root.stopService()
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "refresh"
                        label: "刷新"
                        onClicked: root.refreshAll()
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "public"
                        label: "代理测试"
                        onClicked: root.testProxy()
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 2) / 3
                        iconName: "route"
                        label: "TUN测试"
                        onClicked: root.testTun()
                    }
                }

                ActionButton {
                    width: parent.width
                    iconName: "dashboard"
                    label: "打开 Mihomo 面板"
                    description: root.dashboardUrl
                    onClicked: root.openDashboard()
                }

                ActionButton {
                    width: parent.width
                    iconName: "data_usage"
                    label: "订阅剩余流量"
                    description: root.trafficInfo
                    onClicked: root.refreshTraffic()
                }

                ActionButton {
                    width: parent.width
                    iconName: "monitoring"
                    label: "走外网实时流量"
                    description: root.externalTrafficInfo
                    onClicked: root.refreshExternalTraffic()
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    SmallButton {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "network_ping"
                        label: "当前延迟"
                        onClicked: root.testCurrentDelay(true)
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS) / 2
                        iconName: "speed"
                        label: "本页测速"
                        onClicked: root.testVisibleDelays()
                    }
                }

                StyledRect {
                    width: parent.width
                    implicitHeight: 58
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    StyledText {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        text: root.lastResult
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                }

                StyledText {
                    width: parent.width
                    text: "节点切换：" + root.selectedGroup
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                }

                StyledText {
                    width: parent.width
                    text: root.nodeList.length > 0 ? root.nodeSummaryText() : "没有读取到节点。请检查 external-controller 或代理组名称。"
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                StyledRect {
                    width: parent.width
                    implicitHeight: 42
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    TextInput {
                        id: nodeSearchInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingM
                        anchors.rightMargin: Theme.spacingM
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.nodeFilter
                        color: Theme.surfaceText
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        clip: true
                        onTextChanged: {
                            root.nodeFilter = text
                            root.nodePage = 0
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        text: "搜索节点，例如 HK / JP / 低倍率"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        visible: nodeSearchInput.text === ""
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 3) / 4
                        iconName: "chevron_left"
                        label: "上一页"
                        onClicked: root.prevNodePage()
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 3) / 4
                        iconName: "clear"
                        label: "清空"
                        onClicked: { root.nodeFilter = ""; root.nodePage = 0 }
                    }

                    StyledText {
                        width: (parent.width - Theme.spacingS * 3) / 4
                        text: root.nodePageText()
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    SmallButton {
                        width: (parent.width - Theme.spacingS * 3) / 4
                        iconName: "chevron_right"
                        label: "下一页"
                        onClicked: root.nextNodePage()
                    }
                }

                Repeater {
                    model: root.visibleNodes()

                    ActionButton {
                        width: parent.width
                        iconName: modelData === root.currentNode ? "radio_button_checked" : "radio_button_unchecked"
                        label: modelData
                        description: root.nodeActionDescription(modelData)
                        onClicked: root.switchNode(modelData)
                    }
                }
            }
        }
    }

    component SmallButton: StyledRect {
        id: button
        property string iconName: "circle"
        property string label: "Button"
        signal clicked()

        implicitHeight: 40
        radius: Theme.cornerRadius
        color: mouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: button.iconName
                size: Theme.iconSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: button.label
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component ActionButton: StyledRect {
        id: action
        property string iconName: "circle"
        property string label: "Action"
        property string description: ""
        signal clicked()

        implicitHeight: 54
        radius: Theme.cornerRadius
        color: actionMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            DankIcon {
                name: action.iconName
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - Theme.iconSize - Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    text: action.label
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: action.description
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    visible: action.description !== ""
                }
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    function filteredNodes() {
        if (!nodeList || nodeList.length === 0) {
            return []
        }
        var filter = String(nodeFilter || "").toLowerCase().trim()
        if (filter === "") {
            return nodeList
        }
        var result = []
        for (var i = 0; i < nodeList.length; i++) {
            var name = String(nodeList[i])
            if (name.toLowerCase().indexOf(filter) !== -1) {
                result.push(name)
            }
        }
        return result
    }

    function totalNodePages() {
        var count = filteredNodes().length
        var perPage = nodesPerPage > 0 ? nodesPerPage : 12
        return Math.max(1, Math.ceil(count / perPage))
    }

    function visibleNodes() {
        var nodes = filteredNodes()
        if (nodes.length === 0) {
            return []
        }
        var pages = totalNodePages()
        if (nodePage >= pages) {
            nodePage = pages - 1
        }
        if (nodePage < 0) {
            nodePage = 0
        }
        var perPage = nodesPerPage > 0 ? nodesPerPage : 12
        var start = nodePage * perPage
        return nodes.slice(start, start + perPage)
    }

    function nodePageText() {
        var pages = totalNodePages()
        return (nodePage + 1) + " / " + pages
    }

    function nodeSummaryText() {
        var count = filteredNodes().length
        if (nodeFilter && nodeFilter.trim() !== "") {
            return "共 " + nodeList.length + " 个节点，筛选到 " + count + " 个；每页 " + nodesPerPage + " 个。"
        }
        return "共 " + nodeList.length + " 个节点；每页 " + nodesPerPage + " 个，可翻页或搜索。"
    }

    function prevNodePage() {
        if (nodePage > 0) {
            nodePage -= 1
        }
    }

    function nextNodePage() {
        if (nodePage + 1 < totalNodePages()) {
            nodePage += 1
        }
    }

    function refreshAll() {
        refreshServiceState()
        refreshTunState()
        refreshApiState()
    }

    function barText() {
        var base = serviceActive ? (tunActive ? "Mihomo TUN" : "Mihomo") : "Mihomo Off"
        var parts = []
        if (showDelayInBar && currentDelayText && currentDelayText !== "-- ms") {
            parts.push(currentDelayText)
        }
        if (serviceActive && showExternalTrafficInBar && externalTrafficShortInfo && externalTrafficShortInfo !== "") {
            parts.push(externalTrafficShortInfo)
        }
        if (showTrafficInBar && trafficShortInfo && trafficShortInfo !== "") {
            parts.push(trafficShortInfo)
        }
        return parts.length > 0 ? base + " · " + parts.join(" · ") : base
    }

    function setNodeDelay(nodeName, delayText) {
        if (!nodeName || nodeName === "") {
            return
        }
        var nextMap = {}
        for (var key in nodeDelayMap) {
            nextMap[key] = nodeDelayMap[key]
        }
        nextMap[nodeName] = delayText
        nodeDelayMap = nextMap
        if (nodeName === currentNode) {
            currentDelayText = delayText
        }
    }

    function nodeDelayText(nodeName) {
        if (nodeDelayMap && nodeDelayMap[nodeName]) {
            return nodeDelayMap[nodeName]
        }
        return "未测速"
    }

    function nodeActionDescription(nodeName) {
        var prefix = nodeName === currentNode ? "当前使用" : "点击切换到该节点"
        return prefix + " · 延迟：" + nodeDelayText(nodeName)
    }

    function cleanTrafficOutput(text) {
        var lines = String(text || "").split("\n")
        var visible = []
        trafficShortInfo = ""
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") {
                continue
            }
            if (line.indexOf("BAR:") === 0) {
                trafficShortInfo = line.substring(4).trim()
            } else {
                visible.push(line)
            }
        }
        return visible.join("\n")
    }

    function refreshServiceState() {
        serviceProcess.command = ["systemctl", "--user", "is-active", serviceName]
        serviceProcess.running = true
    }

    function refreshTunState() {
        tunProcess.command = ["bash", "-lc", "ip link show mihomo >/dev/null 2>&1 && echo on || echo off"]
        tunProcess.running = true
    }

    function refreshApiState() {
        apiProcess.output = ""
        apiProcess.command = ["curl", "-fsS", controllerUrl + "/proxies"]
        apiProcess.running = true
    }

    function startService() {
        runAction(["systemctl", "--user", "start", serviceName], "正在启动 mihomo")
    }

    function restartService() {
        runAction(["systemctl", "--user", "restart", serviceName], "正在重启 mihomo")
    }

    function stopService() {
        runAction(["systemctl", "--user", "stop", serviceName], "正在停止 mihomo")
    }

    function runAction(cmd, message) {
        ToastService.showInfo(message)
        actionProcess.command = cmd
        actionProcess.running = true
    }

    function switchNode(nodeName) {
        if (!nodeName || nodeName === "") {
            return
        }
        switchProcess.output = ""
        switchProcess.command = [
            "curl",
            "-fsS",
            "-X", "PUT",
            controllerUrl + "/proxies/" + encodeURIComponent(selectedGroup),
            "-H", "Content-Type: application/json",
            "-d", JSON.stringify({ "name": nodeName })
        ]
        switchProcess.running = true
        lastResult = "正在切换节点：" + nodeName
    }

    function testProxy() {
        testProcess.output = ""
        testProcess.command = ["bash", "-lc", "curl -I --max-time 10 --proxy http://127.0.0.1:" + mixedPort + " https://www.google.com 2>&1 | head -n 3"]
        testProcess.running = true
        lastResult = "正在测试 mixed-port 代理连接..."
    }

    function testTun() {
        testProcess.output = ""
        testProcess.command = ["bash", "-lc", "curl -I --max-time 10 https://www.google.com 2>&1 | head -n 3"]
        testProcess.running = true
        lastResult = "正在测试 TUN 直连接管..."
    }

    function delayEndpoint(nodeName) {
        return controllerUrl + "/proxies/" + encodeURIComponent(nodeName) + "/delay?url=" + encodeURIComponent(delayTestUrl) + "&timeout=" + delayTimeoutMs
    }

    function testCurrentDelay(showMessage) {
        if (!apiOnline || !currentNode || currentNode === "") {
            delayInfo = "没有可测速的当前节点。"
            lastResult = delayInfo
            return
        }
        if (delayProcess.running) {
            return
        }
        pendingDelayNode = currentNode
        delayProcess.output = ""
        delayProcess.command = ["curl", "-fsS", delayEndpoint(currentNode)]
        delayProcess.running = true
        if (showMessage === undefined || showMessage) {
            delayInfo = "正在测试当前节点延迟：" + currentNode
            lastResult = delayInfo
        }
    }

    function testVisibleDelays() {
        var nodes = visibleNodes()
        if (!nodes || nodes.length === 0) {
            lastResult = "当前页没有可测速节点。"
            return
        }
        if (pageDelayProcess.running) {
            return
        }
        pageDelayProcess.output = ""
        var script = "NODES=" + shQuote(JSON.stringify(nodes))
            + " CONTROLLER=" + shQuote(controllerUrl)
            + " TEST_URL=" + shQuote(delayTestUrl)
            + " TIMEOUT_MS=" + shQuote(String(delayTimeoutMs))
            + " python3 - <<'PY'\n"
            + "import json, os, sys, urllib.parse, urllib.request\n"
            + "nodes = json.loads(os.environ.get('NODES', '[]'))\n"
            + "controller = os.environ.get('CONTROLLER', 'http://127.0.0.1:9090').rstrip('/')\n"
            + "test_url = os.environ.get('TEST_URL', 'https://www.gstatic.com/generate_204')\n"
            + "timeout_ms = int(os.environ.get('TIMEOUT_MS', '5000') or 5000)\n"
            + "result = {}\n"
            + "for node in nodes:\n"
            + "    endpoint = controller + '/proxies/' + urllib.parse.quote(node, safe='') + '/delay?url=' + urllib.parse.quote(test_url, safe='') + '&timeout=' + str(timeout_ms)\n"
            + "    try:\n"
            + "        with urllib.request.urlopen(endpoint, timeout=max(timeout_ms / 1000.0 + 2, 3)) as resp:\n"
            + "            data = json.loads(resp.read().decode('utf-8', 'ignore') or '{}')\n"
            + "        delay = data.get('delay', -1)\n"
            + "        if isinstance(delay, int) and delay >= 0:\n"
            + "            result[node] = str(delay) + ' ms'\n"
            + "        else:\n"
            + "            result[node] = '超时'\n"
            + "    except Exception:\n"
            + "        result[node] = '失败'\n"
            + "print(json.dumps(result, ensure_ascii=False))\n"
            + "PY"
        pageDelayProcess.command = ["bash", "-lc", script]
        pageDelayProcess.running = true
        lastResult = "正在测试本页 " + nodes.length + " 个节点延迟..."
    }

    function openDashboard() {
        Quickshell.execDetached(["xdg-open", dashboardUrl])
        ToastService.showInfo("正在打开 Mihomo 面板")
    }

    function shQuote(value) {
        return "'" + String(value || "").replace(/'/g, "'\"'\"'") + "'"
    }

    function formatTrafficBytes(bytes) {
        var n = Math.max(0, Number(bytes || 0))
        var units = ["B", "KiB", "MiB", "GiB", "TiB"]
        var i = 0
        while (n >= 1024 && i < units.length - 1) {
            n = n / 1024
            i += 1
        }
        if (i === 0) {
            return Math.round(n) + " B"
        }
        return n.toFixed(1) + " " + units[i]
    }

    function clearExternalTraffic(message) {
        externalTrafficShortInfo = ""
        externalTrafficInfo = message || "代理关闭，外网流量已隐藏。"
        externalTrafficLastUpload = 0
        externalTrafficLastDownload = 0
        externalTrafficLastTimeMs = 0
    }

    function refreshExternalTraffic() {
        if (!showExternalTrafficInBar) {
            clearExternalTraffic("外网流量显示已关闭。")
            return
        }
        if (!serviceActive) {
            clearExternalTraffic("代理关闭，外网流量已隐藏。")
            return
        }
        if (externalTrafficProcess.running) {
            return
        }

        externalTrafficProcess.output = ""
        var script = "CONTROLLER=" + shQuote(controllerUrl)
            + " python3 - <<'PY'\n"
            + "import json, os, sys, urllib.request\n"
            + "controller = os.environ.get('CONTROLLER', 'http://127.0.0.1:9090').rstrip('/')\n"
            + "DIRECT_NAMES = {'DIRECT', 'REJECT', 'REJECT-DROP', 'PASS'}\n"
            + "def human(n):\n"
            + "    n = float(max(0, n))\n"
            + "    units = ['B', 'KiB', 'MiB', 'GiB', 'TiB']\n"
            + "    i = 0\n"
            + "    while n >= 1024 and i < len(units) - 1:\n"
            + "        n /= 1024\n"
            + "        i += 1\n"
            + "    return (str(int(n)) + ' B') if i == 0 else (f'{n:.1f} {units[i]}')\n"
            + "req = urllib.request.Request(controller + '/connections', headers={'Accept': 'application/json'})\n"
            + "with urllib.request.urlopen(req, timeout=3.5) as resp:\n"
            + "    data = json.loads(resp.read().decode('utf-8', 'ignore') or '{}')\n"
            + "items = data.get('connections') or []\n"
            + "proxy_upload = 0\n"
            + "proxy_download = 0\n"
            + "proxy_count = 0\n"
            + "direct_count = 0\n"
            + "top = []\n"
            + "for c in items:\n"
            + "    chains = c.get('chains') or []\n"
            + "    norm = {str(x).strip().upper() for x in chains}\n"
            + "    is_direct = (not chains) or bool(norm & DIRECT_NAMES)\n"
            + "    up = int(c.get('upload') or 0)\n"
            + "    down = int(c.get('download') or 0)\n"
            + "    if is_direct:\n"
            + "        direct_count += 1\n"
            + "        continue\n"
            + "    proxy_count += 1\n"
            + "    proxy_upload += up\n"
            + "    proxy_download += down\n"
            + "    meta = c.get('metadata') or {}\n"
            + "    host = meta.get('host') or meta.get('destinationIP') or meta.get('sourceIP') or ''\n"
            + "    chain_text = ' > '.join(str(x) for x in chains[-2:])\n"
            + "    top.append((up + down, host, chain_text))\n"
            + "top.sort(reverse=True)\n"
            + "print('TOTALS:%d,%d,%d,%d' % (proxy_upload, proxy_download, proxy_count, direct_count))\n"
            + "print(f'外网活跃连接：{proxy_count} 条；直连/拒绝：{direct_count} 条')\n"
            + "print(f'外网连接累计：上传 {human(proxy_upload)}，下载 {human(proxy_download)}')\n"
            + "details = []\n"
            + "for _, host, chain_text in top[:3]:\n"
            + "    if host:\n"
            + "        details.append(host + (' · ' + chain_text if chain_text else ''))\n"
            + "if details:\n"
            + "    print('主要外网连接：' + '；'.join(details))\n"
            + "PY"
        externalTrafficInfo = "正在读取走外网流量..."
        externalTrafficProcess.command = ["bash", "-lc", script]
        externalTrafficProcess.running = true
    }

    function cleanExternalTrafficOutput(text) {
        var lines = String(text || "").split("\n")
        var visible = []
        var nowMs = Date.now()
        var gotTotals = false
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") {
                continue
            }
            if (line.indexOf("TOTALS:") === 0) {
                var fields = line.substring(7).split(",")
                var up = Number(fields[0] || 0)
                var down = Number(fields[1] || 0)
                var count = Number(fields[2] || 0)
                gotTotals = true
                var shortText = "外网 " + count + "条"
                if (externalTrafficLastTimeMs > 0 && nowMs > externalTrafficLastTimeMs && up >= externalTrafficLastUpload && down >= externalTrafficLastDownload) {
                    var elapsed = Math.max((nowMs - externalTrafficLastTimeMs) / 1000.0, 0.1)
                    var upRate = (up - externalTrafficLastUpload) / elapsed
                    var downRate = (down - externalTrafficLastDownload) / elapsed
                    shortText = "外网 " + count + "条 ↑" + formatTrafficBytes(upRate) + "/s ↓" + formatTrafficBytes(downRate) + "/s"
                }
                externalTrafficLastUpload = up
                externalTrafficLastDownload = down
                externalTrafficLastTimeMs = nowMs
                externalTrafficShortInfo = serviceActive ? shortText : ""
            } else {
                visible.push(line)
            }
        }
        if (!gotTotals && !serviceActive) {
            externalTrafficShortInfo = ""
        }
        return visible.join("\n")
    }

    function refreshTraffic() {
        trafficProcess.output = ""
        var script = "SUB_URL=" + shQuote(subscriptionUrl)
            + " UA=" + shQuote(subscriptionUserAgent)
            + " CFG=" + shQuote(configPath)
            + " python3 - <<'PY'\n"
            + "import datetime, os, pathlib, re, subprocess, sys\n"
            + "sub_url = os.environ.get('SUB_URL', '').strip()\n"
            + "ua = os.environ.get('UA', 'clash.meta').strip() or 'clash.meta'\n"
            + "cfg = os.path.expanduser(os.environ.get('CFG', '~/.config/mihomo/config.yaml'))\n"
            + "def parse_info(text):\n"
            + "    pattern = r'(?:subscription-userinfo\\s*:\\s*)?upload\\s*=\\s*(\\d*)\\s*;\\s*download\\s*=\\s*(\\d*)\\s*;\\s*total\\s*=\\s*(\\d*)(?:\\s*;\\s*expire\\s*=\\s*(\\d*))?'\n"
            + "    m = re.search(pattern, text or '', re.I)\n"
            + "    if not m:\n"
            + "        return None\n"
            + "    upload = int(m.group(1) or 0)\n"
            + "    download = int(m.group(2) or 0)\n"
            + "    total = int(m.group(3) or 0)\n"
            + "    expire = int(m.group(4) or 0)\n"
            + "    return upload, download, total, expire\n"
            + "def human(n):\n"
            + "    n = float(max(0, n))\n"
            + "    units = ['B', 'KiB', 'MiB', 'GiB', 'TiB']\n"
            + "    i = 0\n"
            + "    while n >= 1024 and i < len(units) - 1:\n"
            + "        n /= 1024\n"
            + "        i += 1\n"
            + "    return f'{n:.2f} {units[i]}' if i else f'{int(n)} B'\n"
            + "def fmt(info, source):\n"
            + "    upload, download, total, expire = info\n"
            + "    used = upload + download\n"
            + "    remain = max(total - used, 0)\n"
            + "    pct = (used / total * 100) if total else 0\n"
            + "    exp = '无到期信息'\n"
            + "    if expire:\n"
            + "        try:\n"
            + "            exp = datetime.datetime.fromtimestamp(expire).strftime('%Y-%m-%d')\n"
            + "        except Exception:\n"
            + "            exp = str(expire)\n"
            + "    return (f'BAR:剩余 {human(remain)}',\n"
            + "            f'{source}：已用 {human(used)} / 总量 {human(total)}，剩余 {human(remain)}，使用率 {pct:.2f}%，到期 {exp}')\n"
            + "texts = []\n"
            + "errors = []\n"
            + "if sub_url:\n"
            + "    commands = [\n"
            + "        ['curl', '-fsSIL', '--max-time', '15', '-A', ua, sub_url],\n"
            + "        ['curl', '-fsSL', '--max-time', '20', '-A', ua, '-D', '-', '-o', '/dev/null', sub_url],\n"
            + "    ]\n"
            + "    for idx, cmd in enumerate(commands):\n"
            + "        try:\n"
            + "            out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)\n"
            + "            texts.append(('订阅响应头', out))\n"
            + "            if parse_info(out):\n"
            + "                break\n"
            + "        except Exception as e:\n"
            + "            errors.append(str(e))\n"
            + "try:\n"
            + "    path = pathlib.Path(cfg)\n"
            + "    if path.exists():\n"
            + "        texts.append(('配置文件注释', '\\n'.join(path.read_text(errors='ignore').splitlines()[:160])))\n"
            + "except Exception:\n"
            + "    pass\n"
            + "for source, text in texts:\n"
            + "    info = parse_info(text)\n"
            + "    if info:\n"
            + "        bar, detail = fmt(info, source)\n"
            + "        print(bar)\n"
            + "        print(detail)\n"
            + "        sys.exit(0)\n"
            + "if not sub_url:\n"
            + "    print('未填写订阅链接。请在插件设置里填写 Subscription URL。')\n"
            + "elif errors:\n"
            + "    print('未读取到 subscription-userinfo。curl 请求失败或服务商未返回流量响应头。最后错误：' + errors[-1].split('\\n')[-1])\n"
            + "else:\n"
            + "    print('未读取到 subscription-userinfo。请确认订阅响应头包含 upload/download/total，或尝试把 User-Agent 改为 ClashforWindows/0.20.39。')\n"
            + "PY"
        trafficInfo = "正在读取订阅流量..."
        trafficProcess.command = ["bash", "-lc", script]
        trafficProcess.running = true
    }

    Process {
        id: serviceProcess
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    root.serviceState = line.trim()
                }
            }
        }
        stderr: SplitParser {}
        onExited: exitCode => {
            if (exitCode !== 0 && root.serviceState === "checking") {
                root.serviceState = "inactive"
            }
        }
    }

    Process {
        id: tunProcess
        stdout: SplitParser {
            onRead: line => root.tunActive = line.trim() === "on"
        }
        stderr: SplitParser {}
    }

    Process {
        id: apiProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => apiProcess.output += line
        }
        stderr: SplitParser {}
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.apiOnline = false
                root.currentNode = ""
                root.nodeList = []
                return
            }

            try {
                var data = JSON.parse(apiProcess.output)
                var proxies = data.proxies || {}
                var group = proxies[root.proxyGroup]

                if (!group || !group.all) {
                    var keys = Object.keys(proxies)
                    for (var i = 0; i < keys.length; i++) {
                        var candidate = proxies[keys[i]]
                        if (candidate && candidate.all && candidate.all.length > 0) {
                            group = candidate
                            root.selectedGroup = keys[i]
                            break
                        }
                    }
                } else {
                    root.selectedGroup = root.proxyGroup
                }

                if (group && group.all) {
                    root.apiOnline = true
                    root.currentNode = group.now || ""
                    root.nodeList = group.all
                    if (root.autoDelayTest && root.currentNode !== "" && root.currentNode !== root.lastDelayNode) {
                        root.currentDelayText = root.nodeDelayText(root.currentNode) === "未测速" ? "-- ms" : root.nodeDelayText(root.currentNode)
                        root.testCurrentDelay(false)
                    }
                    if (root.nodePage >= root.totalNodePages()) {
                        root.nodePage = 0
                    }
                } else {
                    root.apiOnline = false
                    root.currentNode = ""
                    root.nodeList = []
                }
            } catch (err) {
                root.apiOnline = false
                root.currentNode = ""
                root.nodeList = []
            }
        }
    }

    Process {
        id: actionProcess
        stdout: SplitParser {}
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    root.lastResult = line.trim()
                }
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("mihomo 操作完成")
                root.lastResult = "mihomo 操作完成"
            } else {
                ToastService.showError("mihomo 操作失败", "exit code: " + exitCode)
                root.lastResult = "mihomo 操作失败，exit code: " + exitCode
            }
            root.refreshAll()
        }
    }

    Process {
        id: switchProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => switchProcess.output += line
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "") {
                    root.lastResult = line.trim()
                }
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                ToastService.showInfo("节点已切换")
                root.lastResult = "节点切换完成"
            } else {
                ToastService.showError("节点切换失败", "请检查代理组类型是否为 select")
                root.lastResult = "节点切换失败。只有 select 代理组适合手动切换。"
            }
            root.refreshApiState()
        }
    }

    Process {
        id: testProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => testProcess.output += line + "\n"
        }
        stderr: SplitParser {
            onRead: line => testProcess.output += line + "\n"
        }
        onExited: exitCode => {
            root.lastResult = testProcess.output.trim() === "" ? "测试完成，无输出。" : testProcess.output.trim()
            if (exitCode === 0) {
                ToastService.showInfo("连接测试完成")
            } else {
                ToastService.showError("连接测试失败", "exit code: " + exitCode)
            }
        }
    }

    Process {
        id: delayProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => delayProcess.output += line
        }
        stderr: SplitParser {
            onRead: line => delayProcess.output += line + "\n"
        }
        onExited: exitCode => {
            var node = root.pendingDelayNode
            root.pendingDelayNode = ""
            if (exitCode === 0) {
                try {
                    var data = JSON.parse(delayProcess.output)
                    if (data.delay !== undefined && data.delay >= 0) {
                        var text = data.delay + " ms"
                        root.setNodeDelay(node, text)
                        root.delayInfo = node + "：" + text
                        root.lastResult = "当前节点延迟：" + root.delayInfo
                        root.lastDelayNode = node
                        return
                    }
                } catch (err) {
                }
            }
            root.setNodeDelay(node, "超时")
            root.delayInfo = node + "：测速失败或超时"
            root.lastResult = root.delayInfo
        }
    }

    Process {
        id: pageDelayProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => pageDelayProcess.output += line + "\n"
        }
        stderr: SplitParser {
            onRead: line => pageDelayProcess.output += line + "\n"
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    var data = JSON.parse(pageDelayProcess.output)
                    var count = 0
                    for (var node in data) {
                        root.setNodeDelay(node, String(data[node]))
                        count += 1
                    }
                    root.lastResult = "本页测速完成：" + count + " 个节点"
                    ToastService.showInfo("本页节点延迟已更新")
                    return
                } catch (err) {
                }
            }
            root.lastResult = pageDelayProcess.output.trim() === "" ? "本页测速失败。" : pageDelayProcess.output.trim()
            ToastService.showError("本页测速失败", "请检查 mihomo API")
        }
    }

    Process {
        id: externalTrafficProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => externalTrafficProcess.output += line + "\n"
        }
        stderr: SplitParser {
            onRead: line => externalTrafficProcess.output += line + "\n"
        }
        onExited: exitCode => {
            if (!root.serviceActive) {
                root.clearExternalTraffic("代理关闭，外网流量已隐藏。")
                return
            }
            var cleaned = root.cleanExternalTrafficOutput(externalTrafficProcess.output).trim()
            if (cleaned === "") {
                cleaned = exitCode === 0 ? "当前没有走外网的活跃连接。" : "外网流量读取失败，exit code: " + exitCode
            }
            root.externalTrafficInfo = cleaned
            if (exitCode !== 0) {
                root.externalTrafficShortInfo = ""
                ToastService.showError("外网流量读取失败", "请检查 external-controller 和 /connections API")
            }
        }
    }

    Process {
        id: trafficProcess
        property string output: ""
        stdout: SplitParser {
            onRead: line => trafficProcess.output += line + "\n"
        }
        stderr: SplitParser {
            onRead: line => trafficProcess.output += line + "\n"
        }
        onExited: exitCode => {
            var cleaned = root.cleanTrafficOutput(trafficProcess.output).trim()
            if (cleaned === "") {
                cleaned = exitCode === 0 ? "订阅流量读取完成，但没有返回内容。" : "订阅流量读取失败，exit code: " + exitCode
            }
            root.trafficInfo = cleaned
            root.lastResult = cleaned
            if (exitCode === 0 && root.trafficShortInfo !== "") {
                ToastService.showInfo("订阅流量已更新")
            } else if (exitCode !== 0) {
                ToastService.showError("订阅流量读取失败", "请检查订阅链接和 User-Agent")
            }
        }
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshAll()
    }

    Timer {
        interval: 60000
        running: root.autoDelayTest
        repeat: true
        triggeredOnStart: false
        onTriggered: root.testCurrentDelay(false)
    }

    Timer {
        interval: Math.max(1000, root.externalTrafficIntervalMs)
        running: root.showExternalTrafficInBar && root.serviceActive
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshExternalTraffic()
    }

    Timer {
        interval: 1800000
        running: root.subscriptionUrl.trim() !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTraffic()
    }
}
