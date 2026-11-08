import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_hideChangePercentage: hidePercentSwitch.checked
    property alias cfg_autoCycle: autoCycleSwitch.checked
    property alias cfg_autoCycleInterval: autoCycleSpin.value

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            CheckBox {
                id: hidePercentSwitch
                Kirigami.FormData.label: "Stock Change Percentage:"
                text: "Hide stock change percentage"
            }

            CheckBox {
                id: autoCycleSwitch
                Kirigami.FormData.label: "Cycle panel stock:"
                text: "Automatically cycle through the stocks"
            }

            SpinBox {
                id: autoCycleSpin
                Kirigami.FormData.label: "Cycle every (seconds):"
                enabled: autoCycleSwitch.checked
                from: 3
                to: 3600
                stepSize: 1
            }
        }
    }
}
