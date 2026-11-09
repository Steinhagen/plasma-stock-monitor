import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_selectedTheme: themeCombo.currentIndex
    property alias cfg_positiveColor: posColorButton.text
    property alias cfg_negativeColor: negColorButton.text
    property alias cfg_bgOpacity: bgOpacitySlider.value
    property alias cfg_tickerColor: tickerColorButton.text
    property alias cfg_tickerOpacity: tickerOpacitySlider.value
    property alias cfg_priceColor: priceColorButton.text
    property alias cfg_priceOpacity: priceOpacitySlider.value
    property alias cfg_showChartAxis: showAxisSwitch.checked
    property alias cfg_showTimeAxis: showTimeAxisSwitch.checked
    property alias cfg_chartStyle: chartStyleCombo.currentIndex
    property alias cfg_showChartStyleButtons: chartStyleButtonsSwitch.checked
    property alias cfg_showChartHover: hoverSwitch.checked

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            ComboBox {
                id: themeCombo

                Kirigami.FormData.label: i18n("Theme:")
                // The theme is stored by index, so the labels can be translated freely.
                model: [i18n("Light"), i18n("Dark"), i18n("Plasma")]
            }

            TextField {
                id: posColorButton
                Kirigami.FormData.label: i18n("Positive Color (Hex):")
                placeholderText: "#00ff00"
            }

            TextField {
                id: negColorButton
                Kirigami.FormData.label: i18n("Negative Color (Hex):")
                placeholderText: "#ff3b30"
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Background Opacity:")
                visible: themeCombo.currentIndex !== 2

                Slider {
                    id: bgOpacitySlider

                    from: 0
                    to: 100
                    stepSize: 1
                    Layout.fillWidth: true
                }

                Label {
                    text: bgOpacitySlider.value + "%"
                }

            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Ticker Symbol Text")
            }

            TextField {
                id: tickerColorButton

                Kirigami.FormData.label: i18n("Color (Hex):")
                placeholderText: "#FFFFFF"
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Opacity:")

                Slider {
                    id: tickerOpacitySlider

                    from: 0
                    to: 100
                    stepSize: 1
                    Layout.fillWidth: true
                }

                Label {
                    text: tickerOpacitySlider.value + "%"
                }

            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Stock Price Text")
            }

            TextField {
                id: priceColorButton

                Kirigami.FormData.label: i18n("Color (Hex):")
                placeholderText: "#FFFFFF"
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Opacity:")

                Slider {
                    id: priceOpacitySlider

                    from: 0
                    to: 100
                    stepSize: 1
                    Layout.fillWidth: true
                }

                Label {
                    text: priceOpacitySlider.value + "%"
                }

            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Chart")
            }

            ComboBox {
                id: chartStyleCombo

                Kirigami.FormData.label: i18n("Chart style:")
                model: [i18n("Reference line (open)"), i18n("Candles + volume")]
            }

            CheckBox {
                id: chartStyleButtonsSwitch

                text: i18n("Show chart style buttons")
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
