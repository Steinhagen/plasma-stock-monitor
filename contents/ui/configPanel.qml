import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_alternatePricePercent: alternateSwitch.checked
    property alias cfg_alternateInterval: alternateSpin.value
    property alias cfg_hideChangePercentage: hidePercentSwitch.checked
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
                Kirigami.FormData.label: "Price and percentage:"
                text: "Alternate them in the same spot"
                enabled: !hidePercentSwitch.checked
            }

            SpinBox {
                id: alternateSpin
                Kirigami.FormData.label: "Switch every (seconds):"
                enabled: alternateSwitch.checked && !hidePercentSwitch.checked
                from: 3
                to: 3600
                stepSize: 1
            }

            CheckBox {
                id: hidePercentSwitch
                Kirigami.FormData.label: "Stock Change Percentage:"
                text: "Hide stock change percentage"
            }

            CheckBox {
                id: fixedWidthSwitch
                Kirigami.FormData.label: "Panel width:"
                text: "Keep the panel indicator at a fixed width"
            }

            SpinBox {
                id: panelWidthSpin
                Kirigami.FormData.label: "Width (pixels):"
                enabled: fixedWidthSwitch.checked
                from: 0
                to: 1000
                stepSize: 5
                // 0 sizes the indicator for the widest value of any configured ticker.
                textFromValue: (v) => v === 0 ? "Fit the widest value" : String(v)
                valueFromText: (t) => parseInt(t) || 0
                editable: true
            }
        }
    }
}
