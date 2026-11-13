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

    property alias cfg_chartStyle: chartStyleCombo.currentIndex
    property alias cfg_chartLineStyle: lineStyleCombo.currentIndex
    property alias cfg_showChartStyleButtons: chartStyleButtonsSwitch.checked
    property alias cfg_showChartRangeButtons: chartRangeButtonsSwitch.checked
    property alias cfg_showChartVolume: volumeSwitch.checked
    property alias cfg_showAnalystTargets: analystTargetsSwitch.checked
    property alias cfg_showChartHover: hoverSwitch.checked
    property alias cfg_showChartAxis: showAxisSwitch.checked
    property alias cfg_showTimeAxis: showTimeAxisSwitch.checked
    property alias cfg_showNews: newsSwitch.checked
    property alias cfg_newsSourceYahoo: newsYahooSwitch.checked
    property alias cfg_newsSourceBvb: newsBvbSwitch.checked
    property alias cfg_newsCount: newsCountSpin.value
    property alias cfg_newsRefreshMinutes: newsRefreshSpin.value
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
                model: [i18n("Reference line (open)"), i18n("Candles")]
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

            CheckBox {
                id: volumeSwitch
                Kirigami.FormData.label: i18n("Volume:")
                text: i18n("Show trading volume under the chart")
            }

            CheckBox {
                id: analystTargetsSwitch
                Kirigami.FormData.label: i18n("Analyst targets:")
                text: i18n("Show analyst price-target changes under the chart")
            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("News")
            }

            CheckBox {
                id: newsSwitch
                text: i18n("Show news headlines in the single-stock view")
            }

            ColumnLayout {
                Kirigami.FormData.label: i18n("News sources:")
                spacing: 0

                CheckBox {
                    id: newsYahooSwitch
                    text: i18n("Yahoo Finance")
                    enabled: newsSwitch.checked
                }
                CheckBox {
                    id: newsBvbSwitch
                    text: i18n("BVB (Romanian symbols)")
                    enabled: newsSwitch.checked
                }
                Label {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                    visible: newsSwitch.checked && !newsYahooSwitch.checked && !newsBvbSwitch.checked
                    text: i18n("Select at least one news source.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            Label {
                Layout.fillWidth: true
                // A wrapping Label still asks for its whole text width; without a cap the
                // form makes the column that wide and the note runs past the page.
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                text: i18n("Headlines from the sources selected above. Yahoo Finance covers general news; BVB provides the issuer's announcements for symbols ending in .RO. Switch with the icons next to the market status. Not available in the list-only view.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            SpinBox {
                id: newsCountSpin
                Kirigami.FormData.label: i18n("Headlines per source (5–50):")
                from: 5
                to: 50
                enabled: newsSwitch.checked && (newsYahooSwitch.checked || newsBvbSwitch.checked)
            }

            SpinBox {
                id: newsRefreshSpin
                Kirigami.FormData.label: i18n("Update every (minutes):")
                from: 10
                to: 240
                enabled: newsSwitch.checked && (newsYahooSwitch.checked || newsBvbSwitch.checked)
            }
        }
    }
}
