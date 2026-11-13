import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../currencies.js" as Currency
import "window.js" as ConfigWindow

Item {
    id: page

    Window.onWindowChanged: ConfigWindow.apply(page, Window.window)

    property alias cfg_showPortfolioMode: portfolioModeSwitch.checked
    property string cfg_portfolioData
    // Currency the whole portfolio is summarised in. Each lot keeps its own currency; this
    // is the common currency used when positions in different currencies are added up.
    property string cfg_portfolioCurrency: "USD"
    // Follows the widget's "Format stock price with commas" setting so amounts read the
    // same here as they do in the widget. Defaults to on when no value is supplied.
    property bool cfg_formatPrices: true

    // Every purchase is kept as its own lot (same ticker can appear more than once, e.g.
    // bought at different prices on different dates). The widget shows each lot's own
    // profit/loss separately rather than blending them into one average.
    property var portfolioList: []
    // Lots after applying the search field. `_index` points back into portfolioList so
    // Edit/Remove still address the original lot.
    property var filteredLots: []
    property string lotSearch: ""
    property string formError: ""
    property var quoteData: ({})
    property bool quotesLoading: false
    property int quoteRequestsPending: 0
    property int quoteRequestId: 0
    property string quotesError: ""
    property string lotSortKey: ""
    property bool lotSortAscending: true

    readonly property var totals: page.portfolioTotals()
    readonly property bool compactLayout: page.width < 1000

    // The Value and Gain columns grow with their contents. Four-digit amounts in a
    // currency with a code symbol (for example "RON 13,234.78") are wider than the
    // fixed 70 px Value column, so its left-elide hid the currency symbol. The
    // minimums keep the header labels readable while quotes are still loading.
    readonly property real widestValueWidth: {
        var widest = 0;
        var lots = page.filteredLots || [];
        for (var i = 0; i < lots.length; i++)
            widest = Math.max(widest, valueFontMetrics.advanceWidth(page.lotValueText(lots[i])));
        return widest;
    }
    readonly property real widestGainWidth: {
        var widest = 0;
        var lots = page.filteredLots || [];
        for (var i = 0; i < lots.length; i++) {
            widest = Math.max(widest, gainFontMetrics.advanceWidth(page.lotGainText(lots[i])));
            widest = Math.max(widest, gainFontMetrics.advanceWidth(page.lotGainPercentText(lots[i])));
        }
        return widest;
    }
    readonly property real desiredValueWidth: Math.max(70, Math.ceil(page.widestValueWidth)
                                                       + Kirigami.Units.smallSpacing * 2)
    readonly property real desiredGainWidth: Math.max(100, Math.ceil(page.widestGainWidth)
                                                      + Kirigami.Units.smallSpacing * 2)
    // Everything in the row except the flexible symbol column and the two money
    // columns: shares, average cost, currency, date and the options button.
    readonly property real tableBaseWidth: 45 + 65 + 45 + 100 + 45
    // The money columns may take the room the symbol column leaves above its own
    // 80 px minimum. In a very narrow window they fall back to eliding instead of
    // pushing the options button out of the table.
    readonly property real moneyColumnsBudget: Math.max(170, pageScroll.availableWidth
        - page.tableBaseWidth - 80 - Kirigami.Units.smallSpacing * 9 - Kirigami.Units.gridUnit * 3)
    readonly property real tableValueWidth: Math.min(page.desiredValueWidth,
                                                     Math.max(70, page.moneyColumnsBudget - 100))
    readonly property real tableGainWidth: Math.min(page.desiredGainWidth,
                                                    Math.max(100, page.moneyColumnsBudget - page.tableValueWidth))
    readonly property real tableFixedWidth: page.tableBaseWidth + page.tableValueWidth + page.tableGainWidth
    readonly property real tableSymbolWidth: Math.max(80, pageScroll.availableWidth
        - tableFixedWidth - Kirigami.Units.smallSpacing * 9 - Kirigami.Units.gridUnit * 3)

    // Metrics matching the amount labels, so the columns can be sized from the
    // actual formatted strings rather than from a guess at their length.
    FontMetrics {
        id: valueFontMetrics
        font: Kirigami.Theme.defaultFont
    }
    FontMetrics {
        id: gainFontMetrics
        font: Kirigami.Theme.defaultFont
    }

    readonly property int totalShares: {
        var total = 0;
        for (var i = 0; i < page.portfolioList.length; i++)
            total += Number(page.portfolioList[i].shares) || 0;
        return total;
    }

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
        ConfigWindow.apply(page, Window.window);
        Qt.callLater(function() { ConfigWindow.apply(page, Window.window); });
        page.refreshPortfolioList();
        portfolioCurrencyCombo.currentIndex = page.currencyIndex(page.cfg_portfolioCurrency);
        page.currencyPickerReady = true;
        page.refreshQuotes();
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

    onCfg_portfolioDataChanged: {
        page.refreshPortfolioList();
        page.refreshQuotes();
    }

    onQuoteDataChanged: page.updateFilteredLots()

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

    function refreshPortfolioList() {
        page.portfolioList = page.safeParsePortfolio(page.cfg_portfolioData);
        page.updateFilteredLots();
    }

    function updateFilteredLots() {
        var query = page.lotSearch.trim().toLowerCase();
        var result = [];
        for (var i = 0; i < page.portfolioList.length; i++) {
            var lot = page.portfolioList[i];
            if (query !== "") {
                var haystack = (String(lot.ticker || "") + " " + String(lot.details || "")
                                + " " + String(lot.currency || "")).toLowerCase();
                if (haystack.indexOf(query) < 0) continue;
            }
            var copy = Object.assign({}, lot);
            copy._index = i;
            result.push(copy);
        }
        if (page.lotSortKey !== "") result.sort(page.compareLots);
        page.filteredLots = result;
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
        page.formError = "";
    }

    // Opens the empty add-lot dialog.
    function openAddLot() {
        page.clearForm();
        page.formError = "";
        lotDialog.open();
    }

    function addLot() {
        if (portfolioTickerField.text.trim() === "" || portfolioSharesSpin.value <= 0) {
            page.formError = i18n("Enter a ticker and a number of shares greater than zero.");
            return;
        }
        page.formError = "";
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
        lotDialog.close();
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
        page.formError = "";
        lotDialog.open();
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

    // Quotes for the lots. The configuration page is not the applet's data model, so it
    // fetches the current price for each unique ticker to show the value and the gain.
    function refreshQuotes() {
        var seen = {};
        var tickers = [];
        for (var i = 0; i < page.portfolioList.length; i++) {
            var ticker = String(page.portfolioList[i].ticker || "").trim().toUpperCase();
            if (ticker !== "" && !seen[ticker]) {
                seen[ticker] = true;
                tickers.push(ticker);
            }
        }

        page.quoteRequestId++;
        page.quotesError = "";
        page.quoteRequestsPending = tickers.length;
        page.quotesLoading = tickers.length > 0;
        if (tickers.length === 0) return;

        for (var j = 0; j < tickers.length; j++)
            page.fetchQuote(tickers[j], page.quoteRequestId);
    }

    function fetchQuote(ticker, requestId) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (requestId !== page.quoteRequestId) return;

            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText).chart.result[0];
                    var meta = result.meta;
                    var price = Number(meta.regularMarketPrice);
                    if (!(price > 0)) throw new Error("no price");
                    var copy = Object.assign({}, page.quoteData);
                    copy[ticker] = {
                        price: price,
                        currency: meta.currency || "",
                        previousClose: Number(meta.chartPreviousClose) || Number(meta.previousClose) || 0,
                        time: Number(meta.regularMarketTime) || 0
                    };
                    page.quoteData = copy;
                } catch (e) {
                    page.quotesError = i18n("Some quotes are unavailable.");
                }
            } else {
                page.quotesError = i18n("Some quotes are unavailable.");
            }

            page.quoteRequestsPending--;
            if (page.quoteRequestsPending <= 0) page.quotesLoading = false;
        };

        try {
            xhr.open("GET", "https://query1.finance.yahoo.com/v8/finance/chart/"
                     + encodeURIComponent(ticker) + "?range=1d&interval=1d");
            xhr.send();
        } catch (e) {
            page.quotesError = i18n("Some quotes are unavailable.");
            page.quoteRequestsPending--;
            if (page.quoteRequestsPending <= 0) page.quotesLoading = false;
        }
    }

    function quoteFor(ticker) {
        return page.quoteData[String(ticker || "").trim().toUpperCase()] || null;
    }

    function convertMoney(amount, from, to) {
        if (typeof plasmoid === "undefined" || !plasmoid.configuration) return null;
        try {
            var cached = JSON.parse(plasmoid.configuration.exchangeRates || "{}");
            return Currency.convert(amount, from, to, (cached && cached.rates) ? cached.rates : ({}));
        } catch (e) {
            return null;
        }
    }

    // Returns the current value and gain for one lot in that lot's own currency.
    function lotMarketData(lot) {
        var quote = page.quoteFor(lot.ticker);
        if (!quote || !(quote.price > 0)) return null;

        var lotCurrency = Currency.major(lot.currency) || "USD";
        var quoteCurrency = Currency.major(quote.currency);
        var price = quote.price * Currency.minorFactor(quote.currency);
        if (quoteCurrency !== "" && quoteCurrency !== lotCurrency) {
            price = page.convertMoney(price, quoteCurrency, lotCurrency);
            if (price === null) return null;
        }

        var shares = Number(lot.shares) || 0;
        var average = Number(lot.averageCost) || 0;
        var cost = average * shares;
        var value = price * shares;
        var gain = (price - average) * shares;

        var previousClose = Number(quote.previousClose) || 0;
        var previousPrice = previousClose > 0 ? previousClose * Currency.minorFactor(quote.currency) : null;
        if (previousPrice !== null && quoteCurrency !== "" && quoteCurrency !== lotCurrency)
            previousPrice = page.convertMoney(previousPrice, quoteCurrency, lotCurrency);
        var dayGain = (previousPrice !== null && previousPrice > 0)
                      ? (price - previousPrice) * shares : null;
        var dayPercent = (dayGain !== null && previousPrice > 0)
                         ? (dayGain / (previousPrice * shares)) * 100 : 0;

        return {
            price: price,
            value: value,
            gain: gain,
            percent: cost > 0 ? (gain / cost) * 100 : 0,
            perShare: price - average,
            dayGain: dayGain,
            dayPercent: dayPercent,
            currency: lotCurrency
        };
    }

    // Formats an amount with two decimals and, when the widget's "format prices with
    // commas" setting is on, groups the thousands: 325183.75 -> "325,183.75".
    function formatNumber(amount) {
        var num = Number(amount);
        if (isNaN(num)) return String(amount);
        var formatted = Math.abs(num).toFixed(2);
        if (page.cfg_formatPrices) {
            var parts = formatted.split(".");
            parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            formatted = parts.join(".");
        }
        return (num < 0 ? "-" : "") + formatted;
    }

    function moneyText(currency, amount) {
        var num = Number(amount);
        if (isNaN(num)) return Currency.symbol(currency) + String(amount);
        // Keep the sign in front of the currency symbol, like the widget's formatMoney.
        return (num < 0 ? "-" : "") + Currency.symbol(currency) + page.formatNumber(Math.abs(num));
    }

    function lotValueText(lot) {
        var market = page.lotMarketData(lot);
        return market ? page.moneyText(market.currency, market.value) : "—";
    }

    function lotGainText(lot) {
        var market = page.lotMarketData(lot);
        if (!market) return "—";
        return (market.gain >= 0 ? "+" : "-")
               + page.moneyText(market.currency, Math.abs(market.gain));
    }

    function lotGainPercentText(lot) {
        var market = page.lotMarketData(lot);
        if (!market) return "";
        return (market.percent >= 0 ? "+" : "") + Number(market.percent).toFixed(2) + "%";
    }



    function sortIndicator(key) {
        return page.lotSortKey === key ? (page.lotSortAscending ? " ▲" : " ▼") : "";
    }

    function sortValue(lot, key) {
        if (key === "symbol") return String(lot.ticker || "").toLowerCase();
        if (key === "shares") return Number(lot.shares) || 0;
        if (key === "averageCost") return Number(lot.averageCost) || 0;
        if (key === "currency") return String(lot.currency || "USD");
        if (key === "date") {
            var time = Date.parse(String(lot.addedDate || ""));
            return isNaN(time) ? null : time;
        }
        var market = page.lotMarketData(lot);
        if (!market) return null;
        return key === "value" ? market.value : market.gain;
    }

    function compareLots(a, b) {
        var av = page.sortValue(a, page.lotSortKey);
        var bv = page.sortValue(b, page.lotSortKey);
        if (av === null && bv === null) return 0;
        if (av === null) return 1;
        if (bv === null) return -1;
        var result = (typeof av === "string") ? av.localeCompare(bv) : av - bv;
        return page.lotSortAscending ? result : -result;
    }

    function toggleSort(key) {
        if (page.lotSortKey === key) page.lotSortAscending = !page.lotSortAscending;
        else {
            page.lotSortKey = key;
            page.lotSortAscending = true;
        }
        page.updateFilteredLots();
    }

    // Totals for the summary line, in the configured portfolio currency.
    function portfolioTotals() {
        var target = Currency.major(page.cfg_portfolioCurrency) || "USD";
        var result = {
            currency: target,
            cost: 0,
            value: 0,
            gain: 0,
            gainPercent: 0,
            day: 0,
            dayPercent: 0
        };
        if (page.portfolioList.length === 0) return result;

        var cost = 0, value = 0, day = 0;
        var costKnown = true, valueKnown = true, dayKnown = true;
        for (var i = 0; i < page.portfolioList.length; i++) {
            var lot = page.portfolioList[i];
            var lotCurrency = Currency.major(lot.currency) || "USD";
            var shares = Number(lot.shares) || 0;
            var average = Number(lot.averageCost) || 0;

            var convertedCost = page.convertMoney(average * shares, lotCurrency, target);
            if (convertedCost === null) costKnown = false;
            else cost += convertedCost;

            var market = page.lotMarketData(lot);
            if (!market) {
                valueKnown = false;
                dayKnown = false;
                continue;
            }

            var convertedValue = page.convertMoney(market.value, market.currency, target);
            if (convertedValue === null) valueKnown = false;
            else value += convertedValue;

            if (market.dayGain === null) {
                dayKnown = false;
            } else {
                var convertedDay = page.convertMoney(market.dayGain, market.currency, target);
                if (convertedDay === null) dayKnown = false;
                else day += convertedDay;
            }
        }

        result.cost = costKnown ? cost : null;
        result.value = valueKnown ? value : null;
        result.gain = (costKnown && valueKnown) ? value - cost : null;
        result.gainPercent = (result.gain !== null && cost > 0) ? ((value - cost) / cost) * 100 : 0;
        result.day = dayKnown ? day : null;
        result.dayPercent = (result.day !== null && valueKnown && (value - day) > 0)
                            ? (day / (value - day)) * 100 : 0;
        return result;
    }

    function summaryMoney(value) {
        return value === null ? "—" : page.moneyText(page.totals.currency, value);
    }

    function summaryPercent(value) {
        if (value === null) return "";
        return (value >= 0 ? "+" : "") + Number(value).toFixed(2) + "%";
    }
    function lotSubline(lot) {
        var parts = [];
        if (lot.details) parts.push(String(lot.details));
        var date = page.formatLotDate(lot.addedDate);
        if (date !== "") parts.push(date);
        return parts.join(" · ");
    }

    function formatLotDate(value) {
        if (!value) return "";
        var d = new Date(value);
        if (isNaN(d.getTime())) return "";
        return Qt.formatDate(d, "dd MMM yyyy");
    }

    ScrollView {
        id: pageScroll
        anchors.fill: parent
        anchors.margins: 20
        // Follow the width left after the vertical scrollbar, so the page never grows
        // past the viewport and a horizontal scrollbar never appears. Binding to the
        // ScrollView's own width would leave the content wider by the scrollbar width
        // as soon as the list is long enough to scroll.
        contentWidth: pageScroll.availableWidth
        clip: true

        ColumnLayout {
            width: pageScroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            // ------------------------------------------------------------------
            // Portfolio-wide settings. Kept inline so changing the base currency
            // or the profit/loss mode takes one click, with the scope spelled out.
            // ------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: scopeRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.smallSpacing
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.16)

                GridLayout {
                    id: scopeRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    columns: page.compactLayout ? 1 : 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        Label {
                            text: i18n("Settings for the whole portfolio")
                            font.bold: true
                            font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.1)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            text: i18n("Applies to every symbol and lot; it does not depend on the selected lot.")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.alignment: page.compactLayout
                                          ? (Qt.AlignLeft | Qt.AlignVCenter)
                                          : (Qt.AlignRight | Qt.AlignVCenter)

                        CheckBox {
                            id: portfolioModeSwitch
                            text: i18n("Show gain/loss in the widget")
                            Layout.alignment: Qt.AlignVCenter
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Shows the gain/loss summary on the widget's main panel. The lot table always shows values and gains.")
                        }

                        Label {
                            text: i18n("Base currency")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 10
                        }

                        ComboBox {
                            id: portfolioCurrencyCombo
                            model: Currency.LABELS
                            Layout.preferredWidth: Kirigami.Units.gridUnit * (page.compactLayout ? 12 : 18)
                            onCurrentIndexChanged: {
                                if (page.currencyPickerReady && currentIndex >= 0)
                                    page.cfg_portfolioCurrency = page.currencyCodeAt(currentIndex);
                            }
                        }

                        ToolButton {
                            icon.name: "help-about"
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: helpDialog.open()
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("About portfolio tracking")
                        }
                    }
                }
            }
            // Overall portfolio summary: the same figures the widget leads with, in the
            // configured base currency, including today's move.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: totalsRow.implicitHeight + Kirigami.Units.largeSpacing * 2
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.smallSpacing
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.16)

                GridLayout {
                    id: totalsRow
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    columns: page.compactLayout ? 2 : 4
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: i18n("Invested")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 9
                        }
                        Label {
                            text: page.summaryMoney(page.totals.cost)
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: i18n("Current value")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 9
                        }
                        Label {
                            text: page.summaryMoney(page.totals.value)
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            text: i18n("Total gain")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 9
                        }
                        Label {
                            text: page.summaryMoney(page.totals.gain)
                            color: page.totals.gain === null
                                   ? Kirigami.Theme.disabledTextColor
                                   : (page.totals.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                                            : Kirigami.Theme.negativeTextColor)
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Label {
                            text: page.summaryPercent(page.totals.gainPercent)
                            visible: page.totals.gain !== null
                            color: page.totals.gain !== null && page.totals.gain >= 0
                                   ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                            font.pixelSize: 9
                            opacity: 0.8
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            text: i18n("Today")
                            color: Kirigami.Theme.disabledTextColor
                            font.pixelSize: 9
                        }
                        Label {
                            text: page.summaryMoney(page.totals.day)
                            color: page.totals.day === null
                                   ? Kirigami.Theme.disabledTextColor
                                   : (page.totals.day >= 0 ? Kirigami.Theme.positiveTextColor
                                                           : Kirigami.Theme.negativeTextColor)
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Label {
                            text: page.summaryPercent(page.totals.dayPercent)
                            visible: page.totals.day !== null
                            color: page.totals.day !== null && page.totals.day >= 0
                                   ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                            font.pixelSize: 9
                            opacity: 0.8
                        }
                    }
                }
            }

            // Lots: title, Add, refresh and search on one row. The search field takes
            // the remaining width, so it cannot push the primary action out.
            RowLayout {
                Layout.fillWidth: true
                Layout.maximumWidth: pageScroll.availableWidth
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    Layout.minimumWidth: 0
                    spacing: 1

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: i18n("Lots")
                        font.bold: true
                        font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.1)
                    }

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: i18np("%1 lot", "%1 lots", page.portfolioList.length)
                              + " · " + i18np("%1 share", "%1 shares", page.totalShares)
                        color: Kirigami.Theme.disabledTextColor
                        font.pixelSize: 10
                    }
                }

                Button {
                    text: i18n("Add Lot")
                    icon.name: "list-add"
                    highlighted: true
                    onClicked: page.openAddLot()
                }

                ToolButton {
                    icon.name: "view-refresh"
                    enabled: !page.quotesLoading
                    onClicked: page.refreshQuotes()
                    ToolTip.visible: hovered
                    ToolTip.text: i18n("Refresh quotes")
                }

                TextField {
                    id: lotSearchField
                    Layout.fillWidth: true
                    Layout.minimumWidth: 80
                    placeholderText: i18n("Search symbol or details…")
                    onTextChanged: {
                        page.lotSearch = text;
                        page.updateFilteredLots();
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: pageScroll.availableWidth
                clip: true
                implicitHeight: tableColumn.implicitHeight
                color: Kirigami.Theme.alternateBackgroundColor
                radius: Kirigami.Units.smallSpacing
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.16)

                ColumnLayout {
                    id: tableColumn
                    width: parent.width
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Item {
                            Layout.preferredWidth: page.tableSymbolWidth
                            Layout.minimumWidth: page.tableSymbolWidth
                            Layout.maximumWidth: page.tableSymbolWidth
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Symbol") + page.sortIndicator("symbol")
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("symbol")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: 45
                            Layout.minimumWidth: 45
                            Layout.maximumWidth: 45
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Shares") + page.sortIndicator("shares")
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("shares")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: 65
                            Layout.minimumWidth: 65
                            Layout.maximumWidth: 65
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Average cost") + page.sortIndicator("averageCost")
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("averageCost")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: 45
                            Layout.minimumWidth: 45
                            Layout.maximumWidth: 45
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Currency") + page.sortIndicator("currency")
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("currency")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: 100
                            Layout.minimumWidth: 100
                            Layout.maximumWidth: 100
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Date") + page.sortIndicator("date")
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("date")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: page.tableValueWidth
                            Layout.minimumWidth: page.tableValueWidth
                            Layout.maximumWidth: page.tableValueWidth
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Value") + page.sortIndicator("value")
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("value")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: page.tableGainWidth
                            Layout.minimumWidth: page.tableGainWidth
                            Layout.maximumWidth: page.tableGainWidth
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Gain") + page.sortIndicator("gain")
                                horizontalAlignment: Text.AlignRight
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.toggleSort("gain")
                                ToolTip.visible: containsMouse
                                ToolTip.text: i18n("Click to sort")
                            }
                        }
                        Item {
                            Layout.preferredWidth: 45
                            Layout.minimumWidth: 45
                            Layout.maximumWidth: 45
                            Layout.preferredHeight: 18
                            Label {
                                anchors.fill: parent
                                text: i18n("Options")
                                horizontalAlignment: Text.AlignHCenter
                                font.pixelSize: 9
                                font.bold: true
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                       Kirigami.Theme.textColor.b, 0.14)
                    }

                    Repeater {
                        model: page.filteredLots

                        delegate: ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            property var market: page.lotMarketData(modelData)

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.smallSpacing
                                Layout.rightMargin: Kirigami.Units.smallSpacing
                                Layout.topMargin: Kirigami.Units.smallSpacing
                                Layout.bottomMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                ColumnLayout {
                                    Layout.preferredWidth: page.tableSymbolWidth
                                    Layout.minimumWidth: page.tableSymbolWidth
                                    Layout.maximumWidth: page.tableSymbolWidth
                                    clip: true
                                    spacing: 0

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.ticker || ""
                                        font.bold: true
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: modelData.details || ""
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                }
                                Label {
                                    text: String(Number(modelData.shares) || 0)
                                    Layout.preferredWidth: 45
                                    Layout.minimumWidth: 45
                                    Layout.maximumWidth: 45
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }
                                Label {
                                    text: page.formatNumber(modelData.averageCost || 0)
                                    Layout.preferredWidth: 65
                                    Layout.minimumWidth: 65
                                    Layout.maximumWidth: 65
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                }
                                Label {
                                    text: modelData.currency || "USD"
                                    Layout.preferredWidth: 45
                                    Layout.minimumWidth: 45
                                    Layout.maximumWidth: 45
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: page.formatLotDate(modelData.addedDate)
                                    Layout.preferredWidth: 100
                                    Layout.minimumWidth: 100
                                    Layout.maximumWidth: 100
                                    elide: Text.ElideRight
                                }
                                Label {
                                    text: page.lotValueText(modelData)
                                    Layout.preferredWidth: page.tableValueWidth
                                    Layout.minimumWidth: page.tableValueWidth
                                    Layout.maximumWidth: page.tableValueWidth
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideLeft
                                    color: market ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                                }
                                ColumnLayout {
                                    Layout.preferredWidth: page.tableGainWidth
                                    Layout.minimumWidth: page.tableGainWidth
                                    Layout.maximumWidth: page.tableGainWidth
                                    spacing: 0

                                    HoverHandler { id: gainHover }
                                    ToolTip.visible: gainHover.hovered
                                    ToolTip.text: market
                                                  ? i18n("Gain per share: %1",
                                                         page.moneyText(market.currency, market.perShare))
                                                  : i18n("Quote unavailable.")

                                    Label {
                                        Layout.fillWidth: true
                                        text: page.lotGainText(modelData)
                                        color: market
                                               ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                                                   : Kirigami.Theme.negativeTextColor)
                                               : Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignRight
                                        font.bold: true
                                        elide: Text.ElideLeft
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        visible: market !== null
                                        text: page.lotGainPercentText(modelData)
                                        color: market
                                               ? (market.gain >= 0 ? Kirigami.Theme.positiveTextColor
                                                                   : Kirigami.Theme.negativeTextColor)
                                               : Kirigami.Theme.disabledTextColor
                                        horizontalAlignment: Text.AlignRight
                                        font.pixelSize: 9
                                        opacity: 0.8
                                        elide: Text.ElideLeft
                                    }
                                }
                                ToolButton {
                                    id: rowActionButton
                                    text: "⋮"
                                    Layout.preferredWidth: 45
                                    Layout.minimumWidth: 45
                                    Layout.maximumWidth: 45
                                    onClicked: rowMenu.popup()
                                    ToolTip.visible: hovered
                                    ToolTip.text: i18n("Lot actions")

                                    Menu {
                                        id: rowMenu
                                        MenuItem {
                                            text: i18n("Edit")
                                            onTriggered: page.editLot(modelData._index)
                                        }
                                        MenuItem {
                                            text: i18n("Remove")
                                            onTriggered: page.removeLot(modelData._index)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                                               Kirigami.Theme.textColor.b, 0.09)
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: page.portfolioList.length === 0
                spacing: Kirigami.Units.smallSpacing

                Label {
                    text: i18n("No holdings added yet.")
                    color: Kirigami.Theme.disabledTextColor
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Label {
                Layout.fillWidth: true
                visible: page.portfolioList.length > 0 && page.filteredLots.length === 0
                text: i18n("No lots match the search.")
                color: Kirigami.Theme.disabledTextColor
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Use the Import / Export page to back up or restore the portfolio and watchlist.")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    // ----------------------------------------------------------------------
    // Add / edit lot dialog. The table stays the primary surface.
    // ----------------------------------------------------------------------
    Dialog {
        id: lotDialog
        title: page.editingIndex >= 0 ? i18n("Edit Lot") : i18n("Add Lot")
        modal: true
        width: Math.max(360, Math.min(540, page.width - Kirigami.Units.largeSpacing * 2))
        closePolicy: Popup.CloseOnEscape
        onClosed: page.clearForm()

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.FormLayout {
                Layout.fillWidth: true

                TextField {
                    id: portfolioTickerField
                    Kirigami.FormData.label: i18n("Ticker:")
                    placeholderText: i18n("e.g., AAPL")
                    Layout.fillWidth: true
                }

                SpinBox {
                    id: portfolioSharesSpin
                    Kirigami.FormData.label: i18n("Shares:")
                    from: 0
                    to: 999999
                    editable: true
                }

                TextField {
                    id: portfolioCostField
                    Kirigami.FormData.label: i18n("Average Cost:")
                    placeholderText: "0.00"
                    validator: RegularExpressionValidator { regularExpression: /^\d*[.,]?\d*$/ }
                    Layout.fillWidth: true
                }

                ComboBox {
                    id: lotCurrencyCombo
                    Kirigami.FormData.label: i18n("Currency:")
                    model: Currency.LABELS
                    currentIndex: 0
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
                }

                Button {
                    id: purchaseDateButton
                    Kirigami.FormData.label: i18n("Purchase Date:")
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

                        onAboutToShow: {
                            shownMonth = page.purchaseDate.getMonth();
                            shownYear = page.purchaseDate.getFullYear();
                            syncHeader();
                        }

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
                                Layout.preferredWidth: datePopup.cellSize * 7
                                Layout.preferredHeight: datePopup.cellSize * 0.8 * 6

                                delegate: Label {
                                    readonly property bool isSelected: model.date.getFullYear() === page.purchaseDate.getFullYear()
                                                                       && model.date.getMonth() === page.purchaseDate.getMonth()
                                                                       && model.date.getDate() === page.purchaseDate.getDate()
                                    text: model.day
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
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
                                text: i18n("Today")
                                onClicked: datePopup.pick(new Date())
                            }
                        }
                    }
                }

                TextField {
                    id: portfolioDetailsField
                    Kirigami.FormData.label: i18n("Details (optional):")
                    placeholderText: i18n("e.g., E*TRADE - 8122")
                    Layout.fillWidth: true
                }
            }

            Label {
                Layout.fillWidth: true
                visible: page.formError !== ""
                text: page.formError
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }

                Button {
                    text: i18n("Cancel")
                    onClicked: {
                        page.clearForm();
                        lotDialog.close();
                    }
                }

                Button {
                    text: page.editingIndex >= 0 ? i18n("Save Lot") : i18n("Add Lot")
                    highlighted: true
                    onClicked: page.addLot()
                }
            }
        }
    }

    // ----------------------------------------------------------------------
    // Help: the longer explanations live here instead of cluttering the page.
    // ----------------------------------------------------------------------
    Dialog {
        id: helpDialog
        title: i18n("About portfolio tracking")
        modal: true
        width: Math.max(360, Math.min(520, page.width - Kirigami.Units.largeSpacing * 2))

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            Label {
                Layout.fillWidth: true
                text: i18n("Each purchase is its own lot — buying more of the same ticker at a different price adds a new lot instead of overwriting the old one.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                opacity: 0.75
            }

            Label {
                Layout.fillWidth: true
                text: i18n("The average cost is in the lot's currency (USD by default). Exchange rates for all currencies are downloaded once a day and used to show portfolio totals in the portfolio currency. For markets quoted in pence or cents (e.g. London), enter the cost in the major currency (GBP, ZAR).")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                opacity: 0.75
            }

            Label {
                Layout.fillWidth: true
                text: {
                    if (typeof plasmoid === "undefined" || !plasmoid.configuration)
                        return i18n("Exchange rates are downloaded once a day.");
                    var ts = Number(plasmoid.configuration.exchangeRatesUpdated);
                    if (!(ts > 0))
                        return i18n("Exchange rates: not downloaded yet.");
                    return i18n("Exchange rates: updated %1",
                                Qt.formatDateTime(new Date(ts * 1000), "dd MMM yyyy HH:mm"));
                }
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                opacity: 0.75
            }

            Label {
                Layout.fillWidth: true
                text: i18n("Use the Import / Export page to back up or restore the portfolio and watchlist.")
                wrapMode: Text.WordWrap
                font.pixelSize: 10
                opacity: 0.75
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true }

                Button {
                    text: i18n("Close")
                    onClicked: helpDialog.close()
                }
            }
        }
    }
}
