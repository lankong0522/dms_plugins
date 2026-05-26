import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "showkeyOverlay"

    property int defaultFontSize: 34
    property string fontSize: String(root.loadValue("fontSize", defaultFontSize))
    property string maxRows: String(root.loadValue("maxRows", "6"))
    property string entryLifetime: String(root.loadValue("entryLifetime", "1.8"))
    property string minInterval: String(root.loadValue("minInterval", "0.05"))
    property bool useThemePrimary: root.loadValue("useThemePrimary", true)
    property string customTextColor: String(root.loadValue("customTextColor", "#ffffff"))
    property bool enableOutline: root.loadValue("enableOutline", true)
    property int outlineOpacity: root.loadValue("outlineOpacity", 80)
    property bool enableBox: root.loadValue("enableBox", true)
    property int boxOpacity: root.loadValue("boxOpacity", 32)
    property bool enableBoxBorder: root.loadValue("enableBoxBorder", true)
    property int boxBorderOpacity: root.loadValue("boxBorderOpacity", 80)
    property int boxBorderWidth: root.loadValue("boxBorderWidth", 2)
    property int boxRadius: root.loadValue("boxRadius", 12)

    function sanitizeIntInput(textValue, fallback) {
        const cleaned = String(textValue ?? "").replace(/[^0-9]/g, "")
        return cleaned.length > 0 ? cleaned : String(fallback)
    }

    function sanitizeDecimalInput(textValue, fallback) {
        let cleaned = String(textValue ?? "").replace(/[^0-9.]/g, "")
        const dot = cleaned.indexOf(".")
        if (dot !== -1) {
            cleaned = cleaned.slice(0, dot + 1) + cleaned.slice(dot + 1).replace(/\./g, "")
        }
        return cleaned.length > 0 ? cleaned : String(fallback)
    }

    StyledText {
        text: I18n.tr("ShowKey Overlay")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Column {
        id: content
        spacing: Theme.spacingM
        anchors.left: parent.left
        anchors.right: parent.right

        StyledText {
            text: I18n.tr("Runtime")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Column {
            spacing: Theme.spacingXS
            width: parent.width

            StyledText {
                text: I18n.tr("Entry lifetime (seconds)")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankTextField {
                id: entryLifetimeField
                width: parent.width
                height: 40
                text: entryLifetime
                placeholderText: "1.8"
                backgroundColor: Theme.surfaceContainer
                textColor: Theme.surfaceText
                onEditingFinished: {
                    entryLifetime = sanitizeDecimalInput(text, "1.8")
                    text = entryLifetime
                }
            }
        }

        Column {
            spacing: Theme.spacingXS
            width: parent.width

            StyledText {
                text: I18n.tr("Maximum rows")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankTextField {
                id: maxRowsField
                width: parent.width
                height: 40
                text: maxRows
                placeholderText: "6"
                backgroundColor: Theme.surfaceContainer
                textColor: Theme.surfaceText
                onEditingFinished: {
                    maxRows = sanitizeIntInput(text, "6")
                    text = maxRows
                }
            }
        }

        Column {
            spacing: Theme.spacingXS
            width: parent.width

            StyledText {
                text: I18n.tr("Deduplicate interval (seconds)")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            DankTextField {
                id: minIntervalField
                width: parent.width
                height: 40
                text: minInterval
                placeholderText: "0.05"
                backgroundColor: Theme.surfaceContainer
                textColor: Theme.surfaceText
                onEditingFinished: {
                    minInterval = sanitizeDecimalInput(text, "0.05")
                    text = minInterval
                }
            }
        }

        StyledText {
            text: I18n.tr("Appearance")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Column {
            spacing: Theme.spacingS
            width: parent.width

            CheckBox {
                id: themePrimaryToggle
                checked: useThemePrimary
                anchors.left: parent.left
                leftPadding: Theme.spacingS
                Material.accent: Theme.primary

                Component.onCompleted: {
                    this.indicator.anchors.left = this.left
                    this.indicator.anchors.leftMargin = Theme.spacingM
                }

                contentItem: StyledText {
                    text: I18n.tr("Use DMS primary color for text")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    leftPadding: themePrimaryToggle.indicator.width + Theme.spacingM + Theme.spacingS
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Column {
            spacing: Theme.spacingXS
            width: parent.width

            StyledText {
                text: I18n.tr("Custom text color")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                opacity: themePrimaryToggle.checked ? 0.3 : 1.0
            }

            DankTextField {
                id: customTextColorField
                width: parent.width
                height: 40
                text: customTextColor
                placeholderText: "#ffffff"
                backgroundColor: Theme.surfaceContainer
                textColor: Theme.surfaceText
                enabled: !themePrimaryToggle.checked
                opacity: themePrimaryToggle.checked ? 0.3 : 1.0
            }
        }

        SliderSetting {
            settingKey: "fontSize"
            label: I18n.tr("Font size (px)")
            defaultValue: parseInt(fontSize, 10)
            minimum: 12
            maximum: 100
            unit: "px"
        }

        Column {
            spacing: Theme.spacingS
            width: parent.width

            CheckBox {
                id: outlineToggle
                checked: enableOutline
                anchors.left: parent.left
                leftPadding: Theme.spacingS
                Material.accent: Theme.primary

                Component.onCompleted: {
                    this.indicator.anchors.left = this.left
                    this.indicator.anchors.leftMargin = Theme.spacingM
                }

                contentItem: StyledText {
                    text: I18n.tr("Enable text outline")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    leftPadding: outlineToggle.indicator.width + Theme.spacingM + Theme.spacingS
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        SliderSetting {
            settingKey: "outlineOpacity"
            label: I18n.tr("Text outline opacity")
            defaultValue: outlineOpacity
            minimum: 0
            maximum: 100
            unit: "%"
        }

        Column {
            spacing: Theme.spacingS
            width: parent.width

            CheckBox {
                id: boxToggle
                checked: enableBox
                anchors.left: parent.left
                leftPadding: Theme.spacingS
                Material.accent: Theme.primary

                Component.onCompleted: {
                    this.indicator.anchors.left = this.left
                    this.indicator.anchors.leftMargin = Theme.spacingM
                }

                contentItem: StyledText {
                    text: I18n.tr("Enable key box background")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    leftPadding: boxToggle.indicator.width + Theme.spacingM + Theme.spacingS
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        SliderSetting {
            settingKey: "boxOpacity"
            label: I18n.tr("Key box opacity")
            defaultValue: boxOpacity
            minimum: 0
            maximum: 100
            unit: "%"
        }

        Column {
            spacing: Theme.spacingS
            width: parent.width

            CheckBox {
                id: boxBorderToggle
                checked: enableBoxBorder
                anchors.left: parent.left
                leftPadding: Theme.spacingS
                Material.accent: Theme.primary

                Component.onCompleted: {
                    this.indicator.anchors.left = this.left
                    this.indicator.anchors.leftMargin = Theme.spacingM
                }

                contentItem: StyledText {
                    text: I18n.tr("Enable key box border")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    leftPadding: boxBorderToggle.indicator.width + Theme.spacingM + Theme.spacingS
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        SliderSetting {
            settingKey: "boxBorderOpacity"
            label: I18n.tr("Key box border opacity")
            defaultValue: boxBorderOpacity
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SliderSetting {
            settingKey: "boxBorderWidth"
            label: I18n.tr("Key box border thickness")
            defaultValue: boxBorderWidth
            minimum: 0
            maximum: 8
            unit: "px"
        }

        SliderSetting {
            settingKey: "boxRadius"
            label: I18n.tr("Key box corner radius")
            defaultValue: boxRadius
            minimum: 0
            maximum: 40
            unit: "px"
        }

        DankButton {
            text: I18n.tr("Save ShowKey settings")
            width: parent.width
            onClicked: {
                entryLifetime = sanitizeDecimalInput(entryLifetimeField.text, "1.8")
                maxRows = sanitizeIntInput(maxRowsField.text, "6")
                minInterval = sanitizeDecimalInput(minIntervalField.text, "0.05")
                customTextColor = customTextColorField.text.trim().length > 0 ? customTextColorField.text.trim() : "#ffffff"

                root.saveValue("entryLifetime", entryLifetime)
                root.saveValue("maxRows", maxRows)
                root.saveValue("minInterval", minInterval)
                root.saveValue("useThemePrimary", themePrimaryToggle.checked)
                root.saveValue("customTextColor", customTextColor)
                root.saveValue("enableOutline", outlineToggle.checked)
                root.saveValue("enableBox", boxToggle.checked)
                root.saveValue("enableBoxBorder", boxBorderToggle.checked)

                entryLifetimeField.text = entryLifetime
                maxRowsField.text = maxRows
                minIntervalField.text = minInterval
                customTextColorField.text = customTextColor
            }
        }
    }
}
