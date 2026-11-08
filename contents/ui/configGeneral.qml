import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_ticker: tickerField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_isMultiMode: modeSwitch.checked
    property alias cfg_showTwoList: showTwoListSwitch.checked
    property alias cfg_multiTickers: multiListField.text
    property alias cfg_sortAlphabetically: sortSwitch.checked
    property alias cfg_swapNameAndTicker: swapNameSwitch.checked
    property alias cfg_showNameAndTicker: nameAndTickerSwitch.checked
    
    property alias cfg_limitHours: limitHoursSwitch.checked
    property alias cfg_skipWeekendRefresh: skipWeekendRefreshSwitch.checked
    property alias cfg_hideTimestamps: hideTimestampsSwitch.checked
    property alias cfg_formatPrices: formatPricesSwitch.checked
    property alias cfg_hideDecimals: hideDecimalsSwitch.checked
    property alias cfg_showExtendedHours: extendedHoursSwitch.checked
    property alias cfg_keepExtendedAfterClose: keepExtendedAfterCloseSwitch.checked
    property alias cfg_startHour: startHourSpin.value
    property alias cfg_startMinute: startMinuteSpin.value
    property alias cfg_endHour: endHourSpin.value
    property alias cfg_endMinute: endMinuteSpin.value

    property string cfg_chartRange
    property alias cfg_showChartRangeButtons: chartRangeButtonsSwitch.checked

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

            CheckBox {
                id: modeSwitch
                Kirigami.FormData.label: i18n("Display Mode:")
                text: i18n("Show Multi-Stock List")
            }
            CheckBox {
                visible: modeSwitch.checked
                id: showTwoListSwitch
                Kirigami.FormData.label: i18n("Two List:")
                text: i18n("single-stock on left side and multi-stock on right side")
            }
            TextField {
                id: tickerField
                visible: !modeSwitch.checked
                Kirigami.FormData.label: i18n("Single Ticker:")
                placeholderText: i18n("e.g., AAPL")
            }

            ScrollView {
                visible: modeSwitch.checked
                Kirigami.FormData.label: i18n("Ticker List:")
                Layout.fillWidth: true
                Layout.minimumHeight: 60
                Layout.maximumHeight: 500
                
                TextArea {
                    id: multiListField
                    // Ticker symbols are the same in every language, so the example is not translated.
                    placeholderText: "AAPL, TSLA"
                    wrapMode: TextEdit.Wrap
                }
            }

            CheckBox {
                id: sortSwitch
                visible: modeSwitch.checked
                Kirigami.FormData.label: i18n("Sorting:")
                text: i18n("Sort stocks alphabetically")
            }

            CheckBox {
                id: nameAndTickerSwitch
                Kirigami.FormData.label: i18n("Names:")
                text: i18n("Show company name and ticker together, e.g. Apple Inc. (AAPL)")
            }

            CheckBox {
                id: swapNameSwitch
                text: nameAndTickerSwitch.checked
                      ? i18n("Swap the order: ticker symbol first, e.g. AAPL (Apple Inc.)")
                      : i18n("Swap company name and ticker symbol")
            }

            CheckBox {
                id: chartRangeButtonsSwitch
                Kirigami.FormData.label: i18n("Range Selection:")
                text: i18n("Show the range buttons in the chart")
            }

            ComboBox {
                id: rangeCombo
                // With the in-chart selector enabled, this preset is redundant wherever the
                // chart is visible; keep it for multi-stock mode without the chart column.
                visible: !chartRangeButtonsSwitch.checked
                         || (modeSwitch.checked && !showTwoListSwitch.checked)
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

            SpinBox {
                id: intervalSpin
                Kirigami.FormData.label: i18n("Refresh Interval (minutes):")
                from: 1
                to: 360
            }

            CheckBox {
                id: limitHoursSwitch
                Kirigami.FormData.label: i18n("Active Hours:")
                text: i18n("Only refresh data during market hours")
            }

            CheckBox {
                id: skipWeekendRefreshSwitch
                Kirigami.FormData.label: i18n("Weekend Refresh:")
                text: i18n("Do not refresh data on weekends (Sat,Sun)")
            }

            RowLayout {
                visible: limitHoursSwitch.checked
                Kirigami.FormData.label: i18n("Market Open:")
                SpinBox { id: startHourSpin; from: 0; to: 23; }
                Label { text: ":" }
                SpinBox { id: startMinuteSpin; from: 0; to: 59; }
            }

            RowLayout {
                visible: limitHoursSwitch.checked
                Kirigami.FormData.label: i18n("Market Close:")
                SpinBox { id: endHourSpin; from: 0; to: 23; }
                Label { text: ":" }
                SpinBox { id: endMinuteSpin; from: 0; to: 59; }
            }

            CheckBox {
                id: hideTimestampsSwitch
                Kirigami.FormData.label: i18n("Update Timestamps:")
                text: i18n("Hide update timestamps")
            }
            
            CheckBox {
                id: formatPricesSwitch
                Kirigami.FormData.label: i18n("Value Formatting:")
                text: i18n("Format stock price with commas (e.g. 1,000.00)")
            }

            CheckBox {
                id: hideDecimalsSwitch
                text: i18n("Remove decimals from stock price")
            }

            CheckBox {
                id: extendedHoursSwitch
                Kirigami.FormData.label: i18n("Extended Hours:")
                text: i18n("Show pre-market and after-hours values and market-closed status")
            }

            CheckBox {
                id: keepExtendedAfterCloseSwitch
                Kirigami.FormData.label: i18n("When Closed:")
                text: i18n("Keep showing the last pre-market/after-hours quote")
                enabled: extendedHoursSwitch.checked
            }
            
        }
    }
}
