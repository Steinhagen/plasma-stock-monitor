import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "window.js" as ConfigWindow

Item {
    id: page

    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    property string cfg_mouseRowLeftAction: "select"
    property string cfg_mouseMiddleAction: "refresh"
    property string cfg_mouseDoubleClickAction: "open"

    // Selecting "Custom" is sticky until a preset is chosen again; otherwise the page
    // would immediately move the selector back to the preset matching the values.
    property bool customPreset: false

    signal configurationChanged()

    function syncRowLeftCombo() {
        if (!rowLeftCombo) return;
        var index = rowLeftCombo.indexOfValue(page.cfg_mouseRowLeftAction);
        if (index >= 0) rowLeftCombo.currentIndex = index;
    }

    function syncMiddleCombo() {
        if (!middleCombo) return;
        var index = middleCombo.indexOfValue(page.cfg_mouseMiddleAction);
        if (index >= 0) middleCombo.currentIndex = index;
    }

    function syncDoubleCombo() {
        if (!doubleCombo) return;
        var index = doubleCombo.indexOfValue(page.cfg_mouseDoubleClickAction);
        if (index >= 0) doubleCombo.currentIndex = index;
    }

    function syncPreset() {
        if (!presetCombo) return;
        if (page.customPreset) {
            presetCombo.currentIndex = 2;
            return;
        }
        var index = 2;
        if (page.cfg_mouseRowLeftAction === "select"
            && page.cfg_mouseMiddleAction === "refresh"
            && page.cfg_mouseDoubleClickAction === "open") {
            index = 0;
        } else if (page.cfg_mouseRowLeftAction === "select"
                   && page.cfg_mouseMiddleAction === "refresh"
                   && page.cfg_mouseDoubleClickAction === "none") {
            index = 1;
        }
        presetCombo.currentIndex = index;
    }

    function applyPreset(index) {
        if (index === 2) {
            page.customPreset = true;
            page.syncPreset();
            return;
        }
        page.customPreset = false;
        if (index === 0) {
            page.cfg_mouseRowLeftAction = "select";
            page.cfg_mouseMiddleAction = "refresh";
            page.cfg_mouseDoubleClickAction = "open";
        } else if (index === 1) {
            page.cfg_mouseRowLeftAction = "select";
            page.cfg_mouseMiddleAction = "refresh";
            page.cfg_mouseDoubleClickAction = "none";
        }
        page.syncPreset();
        page.configurationChanged();
    }

    onCfg_mouseRowLeftActionChanged: {
        page.syncRowLeftCombo();
        page.syncPreset();
    }
    onCfg_mouseMiddleActionChanged: {
        page.syncMiddleCombo();
        page.syncPreset();
    }
    onCfg_mouseDoubleClickActionChanged: {
        page.syncDoubleCombo();
        page.syncPreset();
    }

    Component.onCompleted: {
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
        page.syncRowLeftCombo();
        page.syncMiddleCombo();
        page.syncDoubleCombo();
        page.syncPreset();
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            ComboBox {
                id: presetCombo
                Kirigami.FormData.label: i18n("Preset:")
                model: [
                    i18n("Standard"),
                    i18n("Minimal"),
                    i18n("Custom")
                ]
                onActivated: page.applyPreset(currentIndex)
            }

            ComboBox {
                id: rowLeftCombo
                Kirigami.FormData.label: i18n("List row, left click:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { value: "select", text: i18n("Select for panel and chart") },
                    { value: "open", text: i18n("Open on Yahoo Finance") }
                ]
                onActivated: {
                    page.cfg_mouseRowLeftAction = currentValue;
                    page.customPreset = true;
                    page.syncPreset();
                    page.configurationChanged();
                }
            }

            ComboBox {
                id: middleCombo
                Kirigami.FormData.label: i18n("Middle click:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { value: "refresh", text: i18n("Refresh") },
                    { value: "open", text: i18n("Open on Yahoo Finance") },
                    { value: "none", text: i18n("Do nothing") }
                ]
                onActivated: {
                    page.cfg_mouseMiddleAction = currentValue;
                    page.customPreset = true;
                    page.syncPreset();
                    page.configurationChanged();
                }
            }

            ComboBox {
                id: doubleCombo
                Kirigami.FormData.label: i18n("Double click:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { value: "open", text: i18n("Open on Yahoo Finance") },
                    { value: "none", text: i18n("Do nothing") }
                ]
                onActivated: {
                    page.cfg_mouseDoubleClickAction = currentValue;
                    page.customPreset = true;
                    page.syncPreset();
                    page.configurationChanged();
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Middle click applies to the panel indicator, watchlist rows and the chart.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Right click always opens the context menu. Wheel behaviour is unchanged.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }
}
