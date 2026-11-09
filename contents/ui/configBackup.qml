import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import Qt.labs.platform as QLP
import org.kde.kirigami as Kirigami
import "backup.js" as Backup

Item {
    id: page

    // The Plasma configuration dialog passes every entry of the applet configuration in
    // as a cfg_ property and copies the properties back when Apply is pressed. Declaring
    // them here lets Import stage new values in the same way the other pages stage edits,
    // so Cancel really discards an import and Apply really saves it.
    property int cfg_selectedTheme
    property string cfg_ticker
    property bool cfg_isMultiMode
    property bool cfg_showTwoList
    property string cfg_multiTickers
    property string cfg_portfolioData
    property bool cfg_showPortfolioMode
    property string cfg_portfolioCurrency
    property bool cfg_sortAlphabetically
    property bool cfg_swapNameAndTicker
    property bool cfg_showNameAndTicker
    property int cfg_refreshInterval
    property string cfg_chartRange
    property string cfg_chartViewRange
    property bool cfg_showChartRangeButtons
    property int cfg_chartStyle
    property bool cfg_showChartStyleButtons
    property bool cfg_showChartHover
    property bool cfg_limitHours
    property bool cfg_skipWeekendRefresh
    property int cfg_startHour
    property int cfg_startMinute
    property int cfg_endHour
    property int cfg_endMinute
    property string cfg_tickerColor
    property int cfg_tickerOpacity
    property string cfg_priceColor
    property int cfg_priceOpacity
    property string cfg_positiveColor
    property string cfg_negativeColor
    property int cfg_bgOpacity
    property bool cfg_hideChangePercentage
    property bool cfg_autoCycle
    property int cfg_autoCycleInterval
    property bool cfg_hideTimestamps
    property bool cfg_alternatePricePercent
    property int cfg_alternateInterval
    property bool cfg_fixedPanelWidth
    property int cfg_panelWidth
    property bool cfg_formatPrices
    property bool cfg_showExtendedHours
    property bool cfg_keepExtendedAfterClose
    property bool cfg_hideDecimals
    property bool cfg_showChartAxis
    property bool cfg_showTimeAxis

    // The configuration dialog listens for this signal to enable the Apply button when a
    // page changes more than one alias at once.
    signal configurationChanged()

    property string scope: "all"
    property string statusText: ""
    property bool statusIsError: false
    property string pendingFileName: ""

    readonly property bool busy: ioLoader.item ? ioLoader.item.busy : false
    readonly property bool ioAvailable: ioLoader.status === Loader.Ready && ioLoader.item !== null

    readonly property url defaultFolder: {
        var folder = QLP.StandardPaths.writableLocation(QLP.StandardPaths.DownloadLocation);
        if (String(folder) === "") {
            folder = QLP.StandardPaths.writableLocation(QLP.StandardPaths.HomeLocation);
        }
        return folder;
    }

    function pad(number) {
        return number < 10 ? "0" + number : String(number);
    }

    function defaultFileName() {
        var suffix = page.scope === "data" ? "portfolio" : (page.scope === "settings" ? "settings" : "backup");
        var now = new Date();
        return "plasma-stock-monitor-" + suffix + "-"
                + now.getFullYear() + "-" + page.pad(now.getMonth() + 1) + "-" + page.pad(now.getDate())
                + ".json";
    }

    function defaultFileUrl() {
        var folder = String(page.defaultFolder);
        if (folder === "") return page.defaultFileName();
        if (folder.charAt(folder.length - 1) !== "/") folder += "/";
        return folder + page.defaultFileName();
    }

    function fileName(url) {
        var text = String(url);
        var slash = text.lastIndexOf("/");
        var name = slash >= 0 ? text.substring(slash + 1) : text;
        try {
            name = decodeURIComponent(name);
        } catch (e) {
            // Keep the undecoded name; it is only displayed in the status line.
        }
        return name;
    }

    function setScope(value) {
        if (page.scope === value) return;
        page.scope = value;
        page.statusText = "";
        page.statusIsError = false;
    }

    function setStatus(text, isError) {
        page.statusText = text;
        page.statusIsError = isError;
    }

    function collectConfig() {
        var config = {};
        var keys = Backup.DATA_KEYS.concat(Backup.SETTINGS_KEYS);
        for (var i = 0; i < keys.length; i++) {
            config[keys[i]] = page["cfg_" + keys[i]];
        }
        return config;
    }

    function applyValues(values) {
        for (var key in values) {
            if (Object.prototype.hasOwnProperty.call(values, key)) {
                page["cfg_" + key] = values[key];
            }
        }
    }

    function importErrorMessage(result) {
        switch (result.code) {
        case "emptyFile":
            return i18n("The selected file is empty.");
        case "invalidJson":
            return i18n("The selected file is not valid JSON.");
        case "notBackup":
            return i18n("The selected file is not a Plasma Stock Monitor backup.");
        case "newerFormat":
            return i18n("This backup was created by a newer version of the widget.");
        case "invalidPortfolio":
            return i18n("The portfolio data in this backup is invalid.");
        case "invalidLot":
            return i18n("Portfolio entry %1 in this backup is invalid.", result.detail);
        case "invalidValue":
            return i18n("The backup contains an invalid value for \"%1\".", result.key);
        case "outOfRange":
            return i18n("The value for \"%1\" is outside the allowed range.", result.key);
        default:
            return i18n("The backup could not be imported.");
        }
    }

    function exportTo(url) {
        if (!page.ioAvailable || page.busy) return;
        const backup = Backup.buildBackup(page.collectConfig(), page.scope, new Date().toISOString());
        page.pendingFileName = page.fileName(url);
        page.setStatus(i18n("Writing %1...", page.pendingFileName), false);
        ioLoader.item.writeFile(url, Backup.toJson(backup));
    }

    function importFrom(url) {
        if (!page.ioAvailable || page.busy) return;
        page.pendingFileName = page.fileName(url);
        page.setStatus(i18n("Reading %1...", page.pendingFileName), false);
        ioLoader.item.readFile(url);
    }

    function handleImportedText(text) {
        const result = Backup.parseBackup(text);
        if (!result.ok) {
            page.setStatus(page.importErrorMessage(result), true);
            return;
        }

        if (page.scope === "data") {
            if (!result.data) {
                page.setStatus(i18n("This backup does not contain portfolio or watchlist data."), true);
                return;
            }
            page.applyValues(result.data);
        } else if (page.scope === "settings") {
            if (!result.settings) {
                page.setStatus(i18n("This backup does not contain application settings."), true);
                return;
            }
            page.applyValues(result.settings);
        } else {
            if (!result.data && !result.settings) {
                page.setStatus(i18n("This backup does not contain any data or settings."), true);
                return;
            }
            if (result.data) page.applyValues(result.data);
            if (result.settings) page.applyValues(result.settings);
        }

        page.configurationChanged();
        page.setStatus(i18n("Imported from %1. Click Apply or OK to save the changes.", page.pendingFileName), false);
    }

    function handleIoFailure(operation, detail) {
        var message = operation === "read" ? i18n("The file could not be read.") : i18n("The file could not be saved.");
        if (detail === "timeout") {
            message = i18n("The file operation timed out.");
        } else if (detail) {
            message += " " + i18n("Details: %1", detail);
        }
        page.setStatus(message, true);
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.availableWidth
            spacing: Kirigami.Units.largeSpacing

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(0, page.width - 40)
                text: i18n("Save your portfolio, watchlist and settings to a JSON file, or restore them from a backup.")
                wrapMode: Text.WordWrap
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.FormData.label: i18n("Content:")

                    ButtonGroup {
                        id: scopeGroup
                    }

                    RadioButton {
                        text: i18n("Portfolio and watchlist")
                        enabled: !page.busy
                        checked: page.scope === "data"
                        ButtonGroup.group: scopeGroup
                        onToggled: {
                            if (checked) page.setScope("data");
                        }
                    }

                    RadioButton {
                        text: i18n("Application settings")
                        enabled: !page.busy
                        checked: page.scope === "settings"
                        ButtonGroup.group: scopeGroup
                        onToggled: {
                            if (checked) page.setScope("settings");
                        }
                    }

                    RadioButton {
                        text: i18n("Everything (portfolio and settings)")
                        enabled: !page.busy
                        checked: page.scope === "all"
                        ButtonGroup.group: scopeGroup
                        onToggled: {
                            if (checked) page.setScope("all");
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                        text: page.scope === "data"
                              ? i18n("Holdings, purchase lots, portfolio currency and the ticker list.")
                              : page.scope === "settings"
                                ? i18n("Refresh, market hours, appearance, panel and display preferences.")
                                : i18n("A full backup of the portfolio, watchlist and all settings.")
                        font.pixelSize: 10
                        font.italic: true
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.FormData.label: i18n("Backup:")

                    Button {
                        text: i18n("Export to File...")
                        icon.name: "document-save-as"
                        enabled: page.ioAvailable && !page.busy
                        onClicked: {
                            exportDialog.currentFolder = page.defaultFolder;
                            exportDialog.selectedFile = page.defaultFileUrl();
                            exportDialog.open();
                        }
                    }

                    Button {
                        text: i18n("Import from File...")
                        icon.name: "document-open"
                        enabled: page.ioAvailable && !page.busy
                        onClicked: {
                            importDialog.currentFolder = page.defaultFolder;
                            importDialog.open();
                        }
                    }

                    BusyIndicator {
                        running: page.busy
                        visible: page.busy
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
                    }
                }
            }

            Kirigami.InlineMessage {
                visible: page.statusText !== ""
                type: page.statusIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
                text: page.statusText
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(0, page.width - 40)
            }

            Label {
                visible: ioLoader.status === Loader.Error
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(0, page.width - 40)
                text: i18n("File import and export are not available because the Plasma5Support module is missing on this system.")
                font.pixelSize: 10
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(0, page.width - 40)
                text: i18n("Backups are plain JSON files. Cached exchange rates are not included because they are downloaded again automatically.")
                font.pixelSize: 10
                font.italic: true
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
    }

    Loader {
        id: ioLoader
        source: "BackupIO.qml"
        asynchronous: false
    }

    Connections {
        target: ioLoader.item

        function onReadFinished(text) {
            page.handleImportedText(text);
        }

        function onWriteFinished() {
            page.setStatus(i18n("Exported to %1.", page.pendingFileName), false);
        }

        function onFailed(operationName, detail) {
            page.handleIoFailure(operationName, detail);
        }
    }

    QtDialogs.FileDialog {
        id: exportDialog
        title: i18n("Export Settings")
        fileMode: QtDialogs.FileDialog.SaveFile
        nameFilters: [
            i18nc("file filter", "JSON backup files (*.json)"),
            i18nc("file filter", "All files (*)")
        ]
        defaultSuffix: "json"
        onAccepted: page.exportTo(exportDialog.selectedFile)
    }

    QtDialogs.FileDialog {
        id: importDialog
        title: i18n("Import Settings")
        fileMode: QtDialogs.FileDialog.OpenFile
        nameFilters: [
            i18nc("file filter", "JSON backup files (*.json)"),
            i18nc("file filter", "All files (*)")
        ]
        onAccepted: page.importFrom(importDialog.selectedFile)
    }
}
