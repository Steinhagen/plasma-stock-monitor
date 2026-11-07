import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_alternatePricePercent: alternateSwitch.checked
    property alias cfg_alternateInterval: alternateSpin.value
    property alias cfg_hideChangePercentage: hidePercentSwitch.checked

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
        }
    }
}
