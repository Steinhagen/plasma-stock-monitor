import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "currencies.js" as Currency

Item {
    id: page

    property alias cfg_showPortfolioMode: portfolioModeSwitch.checked
    property string cfg_portfolioData
    // Currency the whole portfolio is summarised in. Each lot keeps its own currency; this
    // is the common currency used when positions in different currencies are added up.
    property string cfg_portfolioCurrency: "USD"

    // Every purchase is kept as its own lot (same ticker can appear more than once, e.g.
    // bought at different prices on different dates). The widget shows each lot's own
    // profit/loss separately rather than blending them into one average.
    property var portfolioList: []

    // The portfolio-currency picker is filled after the config value is known, so the
    // index changes that happen while it is being initialised must not write the config.
    property bool currencyPickerReady: false

    function currencyIndex(code) {
        var wanted = Currency.major(code) || "USD";
        for (var i = 0; i < Currency.LIST.length; i++) {
            if (Currency.LIST[i].code === wanted) return i;
        }
        return 0; // USD is first
    }

    // The code for a picker position. Deriving it from the index (rather than from
    // currentText) avoids the moment when the text still belongs to the old item.
    function currencyCodeAt(index) {
        if (index < 0 || index >= Currency.LIST.length) return "USD";
        return Currency.LIST[index].code;
    }

    Component.onCompleted: {
        page.refreshPortfolioList();
        portfolioCurrencyCombo.currentIndex = page.currencyIndex(page.cfg_portfolioCurrency);
        page.currencyPickerReady = true;
    }

    // If the setting is changed from outside the picker (for example when the config
    // framework loads the value), keep the picker in step.
    onCfg_portfolioCurrencyChanged: {
        if (page.currencyPickerReady && portfolioCurrencyCombo) {
            var idx = page.currencyIndex(page.cfg_portfolioCurrency);
            if (portfolioCurrencyCombo.currentIndex !== idx)
                portfolioCurrencyCombo.currentIndex = idx;
        }
    }

    function safeParsePortfolio(data) {
        if (!data) return [];
        try {
            return JSON.parse(data);
        } catch (e) {
            console.error("Failed to parse portfolio data:", e);
            return [];
        }
    }

    // Parses a price typed with either "." or "," as the decimal separator, regardless of
    // the system locale (avoids the DoubleValidator/parseFloat locale mismatch where a
    // locale using "," for decimals gets silently truncated by JS's locale-independent parseFloat).
    function parseLocaleNumber(text) {
        if (!text) return NaN;
        var str = String(text).trim();
        var lastComma = str.lastIndexOf(",");
        var lastDot = str.lastIndexOf(".");
        if (lastComma !== -1 && lastDot !== -1) {
            // Both separators present: whichever comes last is the decimal separator,
            // the other one is a thousands grouping separator to strip.
            if (lastComma > lastDot) {
                str = str.replace(/\./g, "").replace(",", ".");
            } else {
                str = str.replace(/,/g, "");
            }
        } else if (lastComma !== -1) {
            // Only a comma: treat it as the decimal separator (e.g. "50,21")
            str = str.replace(",", ".");
        }
        return parseFloat(str);
    }

    function escapeCsvField(val) {
        var str = String(val);
        if (str.indexOf(",") >= 0 || str.indexOf("\"") >= 0 || str.indexOf("\n") >= 0) {
            return "\"" + str.replace(/"/g, "\"\"") + "\"";
        }
        return str;
    }

    function refreshPortfolioList() {
        page.portfolioList = page.safeParsePortfolio(page.cfg_portfolioData);
    }

    // Position in portfolioList of the lot currently loaded into the form for editing,
    // or -1 when the form is adding a new lot.
    property int editingIndex: -1

    // Purchase date of the lot in the form. Today unless another day is picked.
    property var purchaseDate: new Date()

    // Stored at local noon so the calendar day survives the UTC conversion of
    // toISOString() in any time zone.
    function dateToIso(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 12, 0, 0).toISOString();
    }

    function clearForm() {
        portfolioTickerField.text = "";
        portfolioSharesSpin.value = 0;
        portfolioCostField.text = "";
        lotCurrencyCombo.currentIndex = 0; // USD
        portfolioDetailsField.text = "";
        page.purchaseDate = new Date();
        page.editingIndex = -1;
    }

    // Adds a new lot, or, while a lot is being edited, saves the changes to that lot.
    function addLot() {
        if (portfolioTickerField.text.trim() === "" || portfolioSharesSpin.value <= 0) return;
        var portfolio = page.safeParsePortfolio(page.cfg_portfolioData);
        var lot = {
            ticker: portfolioTickerField.text.trim().toUpperCase(),
            shares: portfolioSharesSpin.value,
            averageCost: page.parseLocaleNumber(portfolioCostField.text) || 0,
            currency: page.currencyCodeAt(lotCurrencyCombo.currentIndex),
            addedDate: page.dateToIso(page.purchaseDate)
        };
        // Optional free text, e.g. which broker/account the shares are held at.
        var details = portfolioDetailsField.text.trim();
        if (details !== "") lot.details = details;
        if (page.editingIndex >= 0 && page.editingIndex < portfolio.length) {
            portfolio[page.editingIndex] = lot;
        } else {
            portfolio.push(lot);
        }
        page.cfg_portfolioData = JSON.stringify(portfolio);
        page.refreshPortfolioList();
        page.clearForm();
    }

    // Loads a lot (by its position in portfolioList) into the form so it can be changed.
    function editLot(index) {
        var lot = page.portfolioList[index];
        if (!lot) return;
        portfolioTickerField.text = lot.ticker;
        portfolioSharesSpin.value = Number(lot.shares) || 0;
        portfolioCostField.text = String(Number(lot.averageCost) || 0);
        lotCurrencyCombo.currentIndex = page.currencyIndex(lot.currency || "USD");
        page.purchaseDate = lot.addedDate ? new Date(lot.addedDate) : new Date();
        portfolioDetailsField.text = lot.details || "";
        page.editingIndex = index;
    }

    // Removes a single lot by its position in portfolioList (not by ticker, since a ticker
    // can have several lots).
    function removeLot(index) {
        var portfolio = page.safeParsePortfolio(page.cfg_portfolioData);
        portfolio.splice(index, 1);
        page.cfg_portfolioData = JSON.stringify(portfolio);
        page.refreshPortfolioList();
        // Keep the edit form pointing at the same lot, or drop it if that lot was removed.
        if (page.editingIndex === index) page.clearForm();
        else if (page.editingIndex > index) page.editingIndex--;
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.availableWidth
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                CheckBox {
                    id: portfolioModeSwitch
                    Kirigami.FormData.label: "Portfolio Mode:"
                    text: "Show profit/loss calculations"
                }

                ComboBox {
                    id: portfolioCurrencyCombo
                    Kirigami.FormData.label: "Portfolio Currency:"
                    model: Currency.LABELS
                    onCurrentIndexChanged: {
                        if (page.currencyPickerReady && currentIndex >= 0)
                            page.cfg_portfolioCurrency = page.currencyCodeAt(currentIndex);
                    }
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                }

                TextField {
                    id: portfolioTickerField
                    Kirigami.FormData.label: "Ticker:"
                    placeholderText: "e.g., AAPL"
                    Layout.preferredWidth: 120
                }

                SpinBox {
                    id: portfolioSharesSpin
                    Kirigami.FormData.label: "Shares:"
                    from: 0
                    to: 999999
                    editable: true
                }

                TextField {
                    id: portfolioCostField
                    Kirigami.FormData.label: "Average Cost:"
                    placeholderText: "0.00"
                    // Plain digits + a single "." or "," decimal separator. Deliberately not a
                    // DoubleValidator: on locales where "," is the decimal separator (e.g. es_AR),
                    // DoubleValidator treats "." as a thousands separator and rewrites the field
                    // into locale-formatted scientific notation (e.g. "50.21" -> "5,02E+03") on
                    // focus loss, which then gets mis-parsed. See page.parseLocaleNumber().
                    validator: RegularExpressionValidator { regularExpression: /^\d*[.,]?\d*$/ }
                }

                ComboBox {
                    id: lotCurrencyCombo
                    Kirigami.FormData.label: "Currency:"
                    model: Currency.LABELS
                    currentIndex: 0 // USD, the default for a new lot
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                }

                Button {
                    id: purchaseDateButton
                    Kirigami.FormData.label: "Purchase Date:"
                    icon.name: "view-calendar"
                    text: Qt.formatDate(page.purchaseDate, "dd MMM yyyy")
                    onClicked: datePopup.open()

                    Popup {
                        id: datePopup

                        readonly property real cellSize: Kirigami.Units.gridUnit * 2
                        property int shownMonth: page.purchaseDate.getMonth()
                        property int shownYear: page.purchaseDate.getFullYear()

                        y: purchaseDateButton.height + Kirigami.Units.smallSpacing
                        padding: Kirigami.Units.largeSpacing
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                        // Always open on the month of the currently selected date.
                        onAboutToShow: {
                            shownMonth = page.purchaseDate.getMonth();
                            shownYear = page.purchaseDate.getFullYear();
                            syncHeader();
                        }

                        // Keeps the month list and year field in step with the shown month, since
                        // interacting with them can detach their bindings.
                        function syncHeader() {
                            monthCombo.currentIndex = shownMonth;
                            yearSpin.value = shownYear;
                        }

                        function shiftMonth(delta) {
                            var d = new Date(shownYear, shownMonth + delta, 1);
                            shownMonth = d.getMonth();
                            shownYear = d.getFullYear();
                            syncHeader();
                        }

                        function pick(d) {
                            page.purchaseDate = d;
                            close();
                        }

                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            RowLayout {
                                Layout.fillWidth: true

                                ToolButton {
                                    icon.name: "go-previous"
                                    onClicked: datePopup.shiftMonth(-1)
                                }
                                // Jump straight to any month and year: pick the month from the list and
                                // type (or step) the year instead of paging through every month.
                                ComboBox {
                                    id: monthCombo
                                    Layout.fillWidth: true
                                    model: Array.from({ length: 12 }, (_, i) => Qt.locale().monthName(i, Locale.LongFormat))
                                    currentIndex: datePopup.shownMonth
                                    onActivated: (index) => datePopup.shownMonth = index
                                }
                                SpinBox {
                                    id: yearSpin
                                    from: 1900
                                    to: 2100
                                    editable: true
                                    value: datePopup.shownYear
                                    // Plain digits: the default text would add a locale thousands separator.
                                    textFromValue: (v) => String(v)
                                    valueFromText: (t) => parseInt(t) || datePopup.shownYear
                                    onValueModified: datePopup.shownYear = value
                                }
                                ToolButton {
                                    icon.name: "go-next"
                                    onClicked: datePopup.shiftMonth(1)
                                }
                            }

                            DayOfWeekRow {
                                locale: dateGrid.locale
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: datePopup.cellSize * 7
                                Layout.preferredHeight: datePopup.cellSize * 0.8
                                delegate: Label {
                                    text: model.shortName
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 11
                                    opacity: 0.7
                                }
                            }

                            MonthGrid {
                                id: dateGrid
                                month: datePopup.shownMonth
                                year: datePopup.shownYear
                                locale: Qt.locale()
                                Layout.alignment: Qt.AlignHCenter
                                // A month never needs more than six week rows.
                                Layout.preferredWidth: datePopup.cellSize * 7
                                Layout.preferredHeight: datePopup.cellSize * 0.8 * 6

                                delegate: Label {
                                    readonly property bool isSelected: model.date.getFullYear() === page.purchaseDate.getFullYear()
                                                                       && model.date.getMonth() === page.purchaseDate.getMonth()
                                                                       && model.date.getDate() === page.purchaseDate.getDate()
                                    text: model.day
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    // Days of the previous/next month are dimmed.
                                    opacity: model.month === dateGrid.month ? 1.0 : 0.3
                                    font.bold: isSelected || model.today
                                    color: isSelected ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor

                                    background: Rectangle {
                                        radius: Kirigami.Units.smallSpacing
                                        color: isSelected ? Kirigami.Theme.highlightColor : "transparent"
                                        border.width: model.today && !isSelected ? 1 : 0
                                        border.color: Kirigami.Theme.highlightColor
                                    }
                                }

                                onClicked: (date) => datePopup.pick(date)
                            }

                            Button {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Today"
                                onClicked: datePopup.pick(new Date())
                            }
                        }
                    }
                }

                TextField {
                    id: portfolioDetailsField
                    Kirigami.FormData.label: "Details (optional):"
                    placeholderText: "e.g., E*TRADE - 8122"
                    Layout.fillWidth: true
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 20
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.FormData.label: "Actions:"

                    Button {
                        text: page.editingIndex >= 0 ? "Save Lot" : "Add Lot"
                        onClicked: page.addLot()
                    }

                    Button {
                        text: "Cancel"
                        visible: page.editingIndex >= 0
                        onClicked: page.clearForm()
                    }

                    Button {
                        text: "Export CSV"
                        onClicked: {
                            if (page.portfolioList.length === 0) {
                                csvOutput.text = "No portfolio data to export.";
                                return;
                            }
                            var csv = "Ticker,Shares,Average Cost,Currency,Added Date,Details\n";
                            for (var i = 0; i < page.portfolioList.length; i++) {
                                var lot = page.portfolioList[i];
                                csv += page.escapeCsvField(lot.ticker) + "," + page.escapeCsvField(lot.shares) + "," + page.escapeCsvField(lot.averageCost) + "," + page.escapeCsvField(lot.currency || "USD") + "," + page.escapeCsvField(lot.addedDate) + "," + page.escapeCsvField(lot.details || "") + "\n";
                            }
                            csvOutput.text = csv;
                        }
                    }
                }

                Label {
                    text: "Each purchase is its own lot — buying more of the same ticker at a different price adds a new lot instead of overwriting the old one."
                    font.pixelSize: 10
                    font.italic: true
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                }

                Label {
                    text: "The average cost is in the lot's currency (USD by default). Exchange rates for all currencies are downloaded once a day and used to show portfolio totals in the portfolio currency. For markets quoted in pence or cents (e.g. London), enter the cost in the major currency (GBP, ZAR)."
                    font.pixelSize: 10
                    font.italic: true
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                }

                Label {
                    text: {
                        if (typeof plasmoid === "undefined" || !plasmoid.configuration)
                            return "Exchange rates are downloaded once a day.";
                        var ts = Number(plasmoid.configuration.exchangeRatesUpdated);
                        if (!(ts > 0))
                            return "Exchange rates: not downloaded yet.";
                        return "Exchange rates: updated "
                               + Qt.formatDateTime(new Date(ts * 1000), "dd MMM yyyy HH:mm");
                    }
                    font.pixelSize: 10
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.preferredWidth: 300
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            Label {
                text: "Your Lots"
                font.bold: true
                Layout.fillWidth: true
            }

            Label {
                visible: page.portfolioList.length === 0
                text: "No holdings added yet."
                opacity: 0.7
                font.pixelSize: 11
            }

            Repeater {
                model: page.portfolioList
                delegate: RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            text: modelData.ticker + ":  " + modelData.shares + " shares @ " + (modelData.currency || "USD") + " " + Number(modelData.averageCost).toFixed(2)
                                  + (modelData.addedDate ? "   (" + Qt.formatDateTime(new Date(modelData.addedDate), "dd MMM yyyy") + ")" : "")
                        }
                        // Where the shares are held, if the lot has details.
                        Label {
                            Layout.fillWidth: true
                            visible: !!modelData.details
                            elide: Text.ElideRight
                            font.pixelSize: 10
                            opacity: 0.7
                            text: modelData.details || ""
                        }
                    }
                    Button {
                        text: "Edit"
                        enabled: page.editingIndex !== index
                        onClicked: page.editLot(index)
                    }
                    Button {
                        text: "Remove"
                        onClicked: page.removeLot(index)
                    }
                }
            }

            Label {
                id: csvOutput
                text: ""
                font.pixelSize: 10
                font.family: "monospace"
                color: Kirigami.Theme.neutralTextColor
                wrapMode: Text.WordWrap
                visible: text !== ""
                Layout.fillWidth: true
            }
        }
    }
}
