import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_chartStyle: chartStyleCombo.currentIndex
    property alias cfg_chartLineStyle: lineStyleCombo.currentIndex
    property alias cfg_showChartStyleButtons: chartStyleButtonsSwitch.checked
    property alias cfg_showChartRangeButtons: chartRangeButtonsSwitch.checked
    property alias cfg_showChartHover: hoverSwitch.checked
    property alias cfg_showChartAxis: showAxisSwitch.checked
    property alias cfg_showTimeAxis: showTimeAxisSwitch.checked
    property string cfg_chartRange

    onCfg_chartRangeChanged: {
        var idx = rangeCombo.indexOfValue(cfg_chartRange)
        if (idx >= 0) rangeCombo.currentIndex = idx
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            ComboBox {
                id: chartStyleCombo
                Kirigami.FormData.label: i18n("Chart style:")
                // The style is stored by index, so the labels can be translated freely.
                model: [i18n("Reference line (open)"), i18n("Candles + volume")]
            }

            ComboBox {
                id: lineStyleCombo
                Kirigami.FormData.label: i18n("Line style:")
                // The style is stored by index, so the labels can be translated freely.
                model: [i18n("Smooth"), i18n("Straight")]
            }
            CheckBox {
                id: chartStyleButtonsSwitch
                text: i18n("Show chart style buttons")
            }

            CheckBox {
                id: chartRangeButtonsSwitch
                Kirigami.FormData.label: i18n("Range Selection:")
                text: i18n("Show the range buttons in the chart")
            }

            ComboBox {
                id: rangeCombo
                // This preset drives the multi-stock list and is also the chart's fallback
                // range while the in-chart range buttons have no selection of their own.
                Kirigami.FormData.label: i18n("Data Range:")
                // `value` is what gets stored in the config, `text` is only the label, so
                // translating the labels never changes the saved range.
                model: [
                    { value: "1D", text: i18n("1D") },
                    { value: "5D", text: i18n("5D") },
                    { value: "1M", text: i18n("1M") },
                    { value: "6M", text: i18n("6M") },
                    { value: "YTD", text: i18n("YTD") },
                    { value: "1Y", text: i18n("1Y") },
                    { value: "5Y", text: i18n("5Y") },
                    { value: "Max", text: i18n("Max") }
                ]
                textRole: "text"
                valueRole: "value"
                onActivated: page.cfg_chartRange = currentValue
                Component.onCompleted: {
                    var idx = indexOfValue(page.cfg_chartRange)
                    if (idx >= 0) currentIndex = idx
                }
            }

            CheckBox {
                id: hoverSwitch
                Kirigami.FormData.label: i18n("Hover:")
                text: i18n("Show values when hovering over the chart")
            }

            CheckBox {
                id: showAxisSwitch
                Kirigami.FormData.label: i18n("Price scale:")
                text: i18n("Show price values on the right of the chart")
            }

            CheckBox {
                id: showTimeAxisSwitch
                Kirigami.FormData.label: i18n("Time scale:")
                text: i18n("Show dates and times under the chart")
            }
        }
    }
}
