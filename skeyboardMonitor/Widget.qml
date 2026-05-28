import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    property string output: ""
    property string errorText: ""
    property var outputLines: root.output.length > 0
        ? root.output.split("\n").filter(line => line.length > 0)
        : []

    property int fontSizePx: normalizeInt(pluginData.fontSize, 34)
    property int maxRows: normalizeInt(pluginData.maxRows, 6)
    property real entryLifetime: normalizeReal(pluginData.entryLifetime, 1.8)
    property real minInterval: normalizeReal(pluginData.minInterval, 0.05)

    property bool useThemePrimary: pluginData.useThemePrimary ?? true
    property string customTextColor: pluginData.customTextColor ?? "#ffffff"
    property bool enableOutline: pluginData.enableOutline ?? true
    property real outlineOpacity: normalizeInt(pluginData.outlineOpacity, 80) / 100

    // Background and border are intentionally separated:
    // - enableBox only controls the single card fill.
    // - enableBoxBorder only controls the outline.
    // No additional shadow/background layer is created by the border.
    property bool enableBox: pluginData.enableBox ?? true
    property real boxOpacity: normalizeInt(pluginData.boxOpacity, 28) / 100
    property bool enableBoxBorder: pluginData.enableBoxBorder ?? true
    property real boxBorderOpacity: normalizeInt(pluginData.boxBorderOpacity, 80) / 100
    property int boxBorderWidth: normalizeInt(pluginData.boxBorderWidth, 2)
    property int boxRadius: normalizeInt(pluginData.boxRadius, 12)

    property int cardHorizontalPadding: normalizeInt(pluginData.cardHorizontalPadding, 18)
    property int cardVerticalPadding: normalizeInt(pluginData.cardVerticalPadding, 8)
    property int cardSpacing: normalizeInt(pluginData.cardSpacing, 8)
    // Position/layout settings. Existing rightMarginPx/bottomMarginPx keys are kept
    // for backward compatibility and now mean horizontal/vertical margin.
    property int rightMarginPx: normalizeInt(pluginData.rightMarginPx, 8)
    property int bottomMarginPx: normalizeInt(pluginData.bottomMarginPx, 8)
    property string overlayPosition: String(pluginData.overlayPosition ?? "bottom-right")
    property bool newestNearAnchor: pluginData.newestNearAnchor ?? true
    property bool alignRight: root.overlayPosition.indexOf("right") !== -1
    property bool alignBottom: root.overlayPosition.indexOf("bottom") !== -1
    property bool reverseLines: root.alignBottom ? !root.newestNearAnchor : root.newestNearAnchor
    property var arrangedLines: root.reverseLines ? root.outputLines.slice().reverse() : root.outputLines

    property string pluginUrl: ""
    property string pluginDir: ""
    property string streamerPath: ""
    property var windowRef: null

    function normalizeInt(value, fallback) {
        const parsed = parseInt(value, 10)
        if (!isFinite(parsed) || parsed < 0) {
            return fallback
        }
        return parsed
    }

    function normalizeReal(value, fallback) {
        const parsed = Number(value)
        if (!isFinite(parsed) || parsed <= 0) {
            return fallback
        }
        return parsed
    }

    function textColor() {
        return root.useThemePrimary ? Theme.primary : root.customTextColor
    }

    function isRunnable() {
        const win = root.windowRef
        const winVisible = win === null ? true : !!win.visible
        return root.visible && winVisible && root.streamerPath.length > 0
    }

    function startStreamer() {
        if (!root.isRunnable()) {
            return
        }

        keyProcess.running = false
        keyProcess.command = [
            "python3",
            root.streamerPath,
            "--timeout", String(root.entryLifetime),
            "--max-rows", String(root.maxRows),
            "--min-interval", String(root.minInterval)
        ]
        keyProcess.running = true
    }

    function stopStreamer() {
        keyProcess.running = false
        root.output = ""
        root.errorText = ""
    }

    Component.onCompleted: {
        root.windowRef = Window.window ?? null
        const url = Qt.resolvedUrl("Widget.qml") || (typeof __qmlfile__ !== "undefined" ? __qmlfile__ : "")
        const cleanedUrl = String(url ?? "")
        const cleanedPath = cleanedUrl.startsWith("file://") ? cleanedUrl.slice("file://".length) : cleanedUrl
        const lastSlash = cleanedPath.lastIndexOf("/")
        root.pluginUrl = cleanedUrl
        root.pluginDir = lastSlash !== -1 ? cleanedPath.slice(0, lastSlash) : ""
        const resolvedStreamerUrl = Qt.resolvedUrl("showkeyStreamer.py")
        const resolvedStreamer = String(resolvedStreamerUrl ?? "")
        root.streamerPath = resolvedStreamer
            ? resolvedStreamer.replace(/^file:\/\//, "")
            : (root.pluginDir ? `${root.pluginDir}/showkeyStreamer.py` : "showkeyStreamer.py")
        root.startStreamer()
    }

    onVisibleChanged: {
        if (root.visible) {
            root.startStreamer()
        } else {
            root.stopStreamer()
        }
    }

    onEntryLifetimeChanged: {
        if (keyProcess.running) {
            root.startStreamer()
        }
    }

    onMaxRowsChanged: {
        if (keyProcess.running) {
            root.startStreamer()
        }
    }

    onMinIntervalChanged: {
        if (keyProcess.running) {
            root.startStreamer()
        }
    }

    Component.onDestruction: {
        root.stopStreamer()
    }

    Process {
        id: keyProcess
        running: false

        stdout: SplitParser {
            onRead: line => {
                const trimmed = line.trim()
                if (trimmed.length === 0) {
                    return
                }

                try {
                    const payload = JSON.parse(trimmed)
                    root.output = payload.text ?? ""
                    root.errorText = payload.error ?? ""
                } catch (error) {
                    console.warn("[skeyboardMonitor] invalid json:", trimmed)
                }
            }
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.trim().length > 0) {
                    console.warn("[skeyboardMonitor]", line)
                }
            }
        }

        onExited: exitCode => {
            root.output = ""
            console.warn("[skeyboardMonitor] streamer exited:", exitCode)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 0
        visible: root.visible

        Column {
            id: keyColumn

            // The column is positioned manually instead of using anchors so the
            // user can switch between the four corners at runtime.
            width: Math.max(0, parent.width - root.rightMarginPx * 2)
            x: root.alignRight ? parent.width - width - root.rightMarginPx : root.rightMarginPx
            y: root.alignBottom ? parent.height - height - root.bottomMarginPx : root.bottomMarginPx
            spacing: root.cardSpacing

            Repeater {
                model: root.arrangedLines

                delegate: Item {
                    id: keyItem

                    width: keyColumn.width
                    height: keyCard.height

                    Rectangle {
                        id: keyCard

                        x: root.alignRight ? keyItem.width - width : 0
                        width: keyText.implicitWidth + root.cardHorizontalPadding * 2
                        height: keyText.implicitHeight + root.cardVerticalPadding * 2
                        radius: root.boxRadius

                        color: root.enableBox
                            ? Theme.withAlpha(Theme.surfaceContainer, root.boxOpacity)
                            : "transparent"

                        border.width: root.enableBoxBorder ? root.boxBorderWidth : 0
                        border.color: Theme.withAlpha(Theme.primary, root.boxBorderOpacity)

                        Text {
                            id: keyText

                            anchors.centerIn: parent

                            text: modelData
                            textFormat: Text.PlainText
                            color: root.textColor()

                            font.pixelSize: root.fontSizePx
                            font.family: Theme.monoFontFamily
                            font.weight: Font.Bold

                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter

                            style: root.enableOutline ? Text.Outline : Text.Normal
                            styleColor: Qt.rgba(0, 0, 0, root.outlineOpacity)
                        }
                    }
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 8
            visible: root.errorText.length > 0
            text: root.errorText
            textFormat: Text.PlainText
            color: "#ff5555"
            font.pixelSize: Math.max(12, root.fontSizePx * 0.55)
            font.family: Theme.monoFontFamily
            horizontalAlignment: Text.AlignRight
            style: Text.Outline
            styleColor: "#cc000000"
        }
    }
}
