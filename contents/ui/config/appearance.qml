import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "window.js" as ConfigWindow

Item {
    id: page

    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    // 0 = Application, 1 = Plasma.
    property alias cfg_themePreset: presetCombo.currentIndex
    // 0 = Light, 1 = Dark, 2 = System. Kept as a normal property because the combo
    // displays System while Plasma is selected without overwriting the Application color.
    property int cfg_themeColors
    property alias cfg_positiveColor: posColorButton.text
    property alias cfg_negativeColor: negColorButton.text
    property alias cfg_bgOpacity: bgOpacitySlider.value
    property alias cfg_tickerColor: tickerColorButton.text
    property alias cfg_tickerOpacity: tickerOpacitySlider.value
    property alias cfg_priceColor: priceColorButton.text
    property alias cfg_priceOpacity: priceOpacitySlider.value

    // Only the Application preset paints its own background, so only then do the
    // opacity and color controls apply. Plasma follows the system colors.
    readonly property bool appBackgroundUsed: cfg_themePreset === 0

    signal configurationChanged()

    function presetHint() {
        if (page.cfg_themePreset === 1) {
            return i18n("The widget follows the system Plasma theme, including its background and colors.");
        }
        return i18n("The widget draws its own background and rounded cards. Choose its colors below.");
    }

    function applyPreset(index) {
        // The color choice is kept when switching presets, so it is still there when
        // going back to Application.
        page.cfg_themePreset = index === 1 ? 1 : 0;
        page.syncColorsCombo();
        page.configurationChanged();
    }

    // Plasma always uses the system colors. The combo shows System while it is selected,
    // but the stored Application color is kept for when the user switches back.
    function syncColorsCombo() {
        if (!colorsCombo) return;
        colorsCombo.currentIndex = page.cfg_themePreset === 1 ? 2 : page.cfg_themeColors;
    }

    onCfg_themePresetChanged: page.syncColorsCombo()
    onCfg_themeColorsChanged: page.syncColorsCombo()

    // The applet migrates these before the dialog opens; this only keeps the page
    // usable if it is ever shown before that migration wrote its values.
    function ensureThemeDefaults() {
        if (page.cfg_themePreset !== 0 && page.cfg_themePreset !== 1) page.cfg_themePreset = 1;
        if (page.cfg_themeColors < 0) page.cfg_themeColors = 2;
    }

    Component.onCompleted: {
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
        page.ensureThemeDefaults();
        page.syncColorsCombo();
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Theme")
            }

            ComboBox {
                id: presetCombo

                Kirigami.FormData.label: i18n("Preset:")
                model: [
                    i18n("Application"),
                    i18n("Plasma")
                ]
                onActivated: page.applyPreset(currentIndex)
            }

            ComboBox {
                id: colorsCombo

                Kirigami.FormData.label: i18n("Colors:")
                enabled: page.cfg_themePreset === 0
                model: [
                    i18n("Light"),
                    i18n("Dark"),
                    i18n("System")
                ]
                onActivated: {
                    page.cfg_themeColors = currentIndex;
                    page.configurationChanged();
                }
            }

            Label {
                Layout.fillWidth: true
                text: page.presetHint()
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Colors apply only to the Application preset. Plasma always uses the system colors.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            Label {
                Layout.fillWidth: true
                text: i18n("The panel indicator stays transparent and uses the panel colors, whichever theme is selected.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
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
                visible: page.appBackgroundUsed

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

        }

    }

}
