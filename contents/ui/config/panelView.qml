import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "window.js" as ConfigWindow

Item {
    id: page

    Component.onCompleted: {
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
    }
    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    property alias cfg_alternatePricePercent: alternateSwitch.checked
    property alias cfg_alternateInterval: alternateSpin.value
    property alias cfg_hideChangePercentage: hidePercentSwitch.checked
    property alias cfg_autoCycle: autoCycleSwitch.checked
    property alias cfg_autoCycleInterval: autoCycleSpin.value
    property alias cfg_fixedPanelWidth: fixedWidthSwitch.checked
    property alias cfg_panelWidth: panelWidthSpin.value

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            CheckBox {
                id: alternateSwitch
                Kirigami.FormData.label: i18n("Price and percentage:")
                text: i18n("Alternate them in the same spot")
                enabled: !hidePercentSwitch.checked
            }

            SpinBox {
                id: alternateSpin
                Kirigami.FormData.label: i18n("Switch every (seconds):")
                enabled: alternateSwitch.checked && !hidePercentSwitch.checked
                from: 3
                to: 3600
                stepSize: 1
            }

            CheckBox {
                id: hidePercentSwitch
                Kirigami.FormData.label: i18n("Stock Change Percentage:")
                text: i18n("Hide stock change percentage")
            }

            CheckBox {
                id: autoCycleSwitch
                Kirigami.FormData.label: i18n("Cycle panel stock:")
                text: i18n("Automatically cycle through the stocks")
            }

            SpinBox {
                id: autoCycleSpin
                Kirigami.FormData.label: i18n("Cycle every (seconds):")
                enabled: autoCycleSwitch.checked
                from: 3
                to: 3600
                stepSize: 1
            }

            CheckBox {
                id: fixedWidthSwitch
                Kirigami.FormData.label: i18n("Panel width:")
                text: i18n("Keep the panel indicator at a fixed width")
            }

            SpinBox {
                id: panelWidthSpin
                Kirigami.FormData.label: i18n("Width (pixels):")
                enabled: fixedWidthSwitch.checked
                from: 0
                to: 1000
                stepSize: 5
                // 0 sizes the indicator for the widest value of any configured ticker.
                textFromValue: (v) => v === 0 ? i18n("Fit the widest value") : String(v)
                valueFromText: (t) => parseInt(t) || 0
                editable: true
            }
        }
    }
}
