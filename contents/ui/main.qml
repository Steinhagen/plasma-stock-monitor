import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "currencies.js" as Currency

PlasmoidItem {
    id: root

    // --- CONFIGURATION ---
    Plasmoid.backgroundHints: root.isPlasmaTheme ? PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground : PlasmaCore.Types.NoBackground
    // Detect where we are (Panel vs Desktop) to switch views
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical) ? root.compactRepresentation : root.fullRepresentation

    property string singleTicker: Plasmoid.configuration.ticker
    property bool isMultiMode: Plasmoid.configuration.isMultiMode
    property bool showTwoList: Plasmoid.configuration.showTwoList
    // Left column width in the side-by-side desktop view, in pixels. 0 means automatic
    // (both columns share the available width).
    property int twoColumnLeftWidth: Plasmoid.configuration.twoColumnLeftWidth
    property string panelTicker: ""
    // Remember the row selected in the multi-stock list, so it is still the default
    // selection after Plasma or the host restarts.
    property string manualPanelTickerOverride: Plasmoid.configuration.selectedTicker
    property string multiTickers: Plasmoid.configuration.multiTickers
    // Mouse actions: right click is always the context menu; these three are configurable.
    property string mouseRowLeftAction: Plasmoid.configuration.mouseRowLeftAction || "select"
    property string mouseMiddleAction: Plasmoid.configuration.mouseMiddleAction || "refresh"
    property string mouseDoubleClickAction: Plasmoid.configuration.mouseDoubleClickAction || "open"
    property bool sortAlphabetically: Plasmoid.configuration.sortAlphabetically
    property bool swapNameAndTicker: Plasmoid.configuration.swapNameAndTicker
    property bool showNameAndTicker: Plasmoid.configuration.showNameAndTicker
    // Polling interval, shown by the market-status tooltip so the refresh rate is visible.
    readonly property int refreshIntervalMinutes: Plasmoid.configuration.refreshInterval

    // Yahoo returns some non-US short names from a fixed-width vendor field: the company
    // name is padded with spaces and followed by a share-class letter, e.g.
    // "DEUTSCHE LUFTHANSA AG         V". That padding is not part of the name, so use the
    // long name for those quotes and collapse any whitespace that is left over.
    function companyName(meta, fallback) {
        var shortName = meta.shortName ? String(meta.shortName).trim() : "";
        var longName = meta.longName ? String(meta.longName).trim() : "";
        var name = /\s{2,}/.test(shortName) && longName !== "" ? longName : (shortName || longName);
        return name.replace(/\s+/g, " ").trim() || fallback;
    }

    // Name and ticker together: "Company Name (TICK)", or "TICK (Company Name)" when
    // "swap names" is on. Falls back to just the ticker while the name is not known yet
    // or when Yahoo only returned the ticker as the name.
    function nameAndTicker(name, ticker) {
        var t = (ticker || "").trim().toUpperCase();
        if (!name || name === root.loadingText || name.trim().toUpperCase() === t) return t;
        return root.swapNameAndTicker ? t + " (" + name + ")" : name + " (" + t + ")";
    }

    // Same text, but when it does not fit in `avail` pixels only the company name is shortened
    // ("Advanced Micro… (AMD)" / "AMD (Advanced Micro…)"), so the ticker always stays visible.
    // When there is hardly any room for the name, only the ticker is shown.
    // `metrics` is a FontMetrics of the Text.
    function fitNameAndTicker(name, ticker, avail, metrics) {
        var full = nameAndTicker(name, ticker);
        if (avail <= 0 || metrics.advanceWidth(full) <= avail) return full;
        var t = (ticker || "").trim().toUpperCase();
        if (full === t) return full;
        var before = root.swapNameAndTicker ? t + " (" : "";
        var after = root.swapNameAndTicker ? ")" : " (" + t + ")";
        var room = avail - metrics.advanceWidth(before + after);
        if (room < metrics.advanceWidth("MMM…")) return t;
        return before + metrics.elidedText(name, Qt.ElideRight, room) + after;
    }
    property string chartRange: Plasmoid.configuration.chartRange
    // Range selected with the buttons in the chart. It only affects the chart; the
    // multi-stock list keeps using `chartRange` from the settings.
    property string chartViewRange: Plasmoid.configuration.chartViewRange
    // The value actually used by the chart. Keeping it apart from the config binding means
    // a button click takes effect immediately, even if the config write is delivered later.
    property string chartViewRangeActive: root.chartViewRange
    readonly property string effectiveChartRange: root.showChartRangeButtons && root.chartViewRangeActive
                                                 ? root.chartViewRangeActive : root.chartRange
    // Show the range selector in the chart instead of using the preset from the settings.
    property bool showChartRangeButtons: Plasmoid.configuration.showChartRangeButtons
    // Time Limits Config
    property bool limitHours: Plasmoid.configuration.limitHours
    property bool skipWeekendRefresh: Plasmoid.configuration.skipWeekendRefresh
    property int startHour: Plasmoid.configuration.startHour
    property int startMinute: Plasmoid.configuration.startMinute
    property int endHour: Plasmoid.configuration.endHour
    property int endMinute: Plasmoid.configuration.endMinute
    // Placeholders shown while a quote is still being fetched. They are kept in
    // properties so the text that is displayed is the same one the code compares against.
    readonly property string loadingText: i18n("Loading...")
    // Short session tags in the panel. Properties, because the width reserved for the
    // widest tag is measured from the same strings that are displayed.
    readonly property string tagPreMarket: i18nc("@item:panel stock market session tag", "PRE")
    readonly property string tagAfterHours: i18nc("@item:panel stock market session tag", "AH")
    readonly property string tagClosed: i18nc("@item:panel stock market session tag", "CLOSED")
    // Internal Properties for Single View
    property string singleCompanyName: root.loadingText
    property string currentPrice: "---"
    property double currentRawPrice: 0
    // Timestamp of the quote (seconds since epoch), shown by the market-status tooltip so
    // it is clear how fresh the Yahoo Finance data is.
    property double quoteTimestamp: 0
    property string priceChange: "+0.00"
    property string percentChange: "+0.00%"
    property var chartDataPoints: []
    // Unix timestamps (seconds) parallel to chartDataPoints, used for the chart's time scale.
    property var chartTimestamps: []
    // Pre-market / after-hours points around the displayed 1D session (see
    // extendedSessionSeries), or null when the chart shows the regular session only.
    property var chartSessions: null
    // Candle aggregates (open/high/low/close/volume/time) for the candlestick chart, and
    // yesterday's close, used as the reference line of the reference-line chart.
    property var chartCandles: []
    property double chartReferencePrice: 0
    // Start of the session a 1D chart is showing, and whether it is today's session (the
    // running pre-market or the regular one). When it is not, the chart still shows a
    // previous session and the view labels it so it is not mistaken for today's.
    property double chartSessionStart: 0
    property bool chartSessionCurrent: true
    // True when the 1D chart plots the running pre-market; the canvas hatches it like the
    // pre-market zone of a full-day chart.
    property bool chartPreSession: false
    // Evaluated here rather than in the threaded Canvas paint, so the legend text is
    // translated on the main thread.
    readonly property string chartReferenceLabel: i18nc("@item:chart previous close", "Previous close")
    property double previousClose: 0
    property bool isPositive: true
    property string currencySym: ""
    // The currency Yahoo quotes the shown instrument in (e.g. "USD", "GBp"). Used to
    // convert the live price to the currency a portfolio lot was bought in.
    property string quoteCurrency: ""
    // Values for the compact panel indicator. They always follow the configured data
    // range; the range picked only for the chart must not change them.
    property string panelCurrentPrice: "---"
    property string panelCurrentPercent: "+0.00%"
    property bool panelCurrentIsPositive: true
    readonly property string panelSymbol: root.isMultiMode ? root.panelTicker : root.singleTicker
    property bool isLightTheme: Plasmoid.configuration.selectedTheme === 0
    property bool isDarkTheme: Plasmoid.configuration.selectedTheme === 1
    property bool isPlasmaTheme: Plasmoid.configuration.selectedTheme === 2
    // A vertical panel constrains the applet to the panel thickness, so the compact
    // view has to fit (and elide) inside that width instead of using the content width.
    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Colour the gain/loss text is measured against. In a panel that is the Plasma
    // theme background, in the widget it is the background of the selected theme.
    property color contrastBackground: {
        if (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
            return Kirigami.Theme.backgroundColor;
        if (isLightTheme)
            return "#ffffff";
        if (isDarkTheme)
            return "#1a1a1a";
        return Kirigami.Theme.backgroundColor;
    }
    // The configured gain/loss colours, adjusted only as far as needed to stay readable
    // (WCAG AA, 4.5:1) on that background. The default green is bright enough for the
    // dark theme but washes out on white, so it is darkened in the light theme.
    property color positiveColor: root.withContrast(Plasmoid.configuration.positiveColor, root.contrastBackground)
    property color negativeColor: root.withContrast(Plasmoid.configuration.negativeColor, root.contrastBackground)

    // WCAG relative luminance of a colour and the contrast ratio between two colours.
    function luminance(c) {
        function channel(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
    }
    function contrastRatio(a, b) {
        var la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Returns the colour unchanged when it already reads well on bg. Otherwise keeps the hue
    // and saturation and moves only the lightness (darker on light backgrounds, lighter on dark
    // ones) until the contrast is enough.
    function withContrast(color, bg) {
        var c = Qt.color(color);
        var b = Qt.color(bg);
        if (contrastRatio(c, b) >= 4.5) return c;
        var darken = luminance(b) > 0.18;
        var hue = c.hslHue < 0 ? 0 : c.hslHue;
        var l = c.hslLightness;
        var out = c;
        for (var i = 0; i < 100; i++) {
            l += darken ? -0.01 : 0.01;
            if (l < 0 || l > 1) break;
            out = Qt.hsla(hue, c.hslSaturation, l, 1);
            if (contrastRatio(out, b) >= 4.5) break;
        }
        return out;
    }
    property color tickerColor: getThemeColor("ticker")
    property int tickerOpacity: Plasmoid.configuration.tickerOpacity
    property color priceColor: getThemeColor("price")
    property int priceOpacity: Plasmoid.configuration.priceOpacity
    property int bgOpacity: Plasmoid.configuration.bgOpacity
    property bool hideChangePercentage: Plasmoid.configuration.hideChangePercentage
    property bool hideTimestamps: Plasmoid.configuration.hideTimestamps
    property bool formatPrices: Plasmoid.configuration.formatPrices
    property bool hideDecimals: Plasmoid.configuration.hideDecimals
    property bool showChartAxis: Plasmoid.configuration.showChartAxis
    property bool showTimeAxis: Plasmoid.configuration.showTimeAxis
    // 0 = reference line split at the session open, 1 = candles + volume.
    property int chartStyle: Plasmoid.configuration.chartStyle === 1 ? 1 : 0
    // 0 = smooth line, 1 = straight segments.
    property int chartLineStyle: Plasmoid.configuration.chartLineStyle === 1 ? 1 : 0
    // Show the Line/Candles toggle in the chart.
    property bool showChartStyleButtons: Plasmoid.configuration.showChartStyleButtons
    property bool showChartHover: Plasmoid.configuration.showChartHover
    // Portfolio Tracking (purchase price vs current price). Each purchase is its own lot
    // (same ticker can have several, bought at different prices); the lots of a ticker are
    // added up into one position, summarised on a single line.
    property bool showPortfolioMode: Plasmoid.configuration.showPortfolioMode
    property string portfolioData: Plasmoid.configuration.portfolioData
    // Currency the portfolio totals are shown in. Lots keep their own currency; this is
    // only the common currency they are converted to when they have to be added up.
    property string portfolioCurrency: Currency.isKnown(Plasmoid.configuration.portfolioCurrency)
                                        ? Currency.major(Plasmoid.configuration.portfolioCurrency)
                                        : "USD"
    property var portfolioSummary: root.getPortfolioSummary(root.singleTicker, root.portfolioData, root.currentRawPrice, root.previousClose, root.quoteCurrency)
    property bool hasPortfolioEntry: root.portfolioSummary !== null
    // What the change in the summary covers: today for the 1D chart, otherwise the chart range.
    property string portfolioChangeLabel: root.chartRange === "1D" ? i18n("Today") : root.rangeLabel(root.chartRange)
    // Same label for the chart/single view, which can use a range of its own.
    readonly property string chartPeriodLabel: root.effectiveChartRange === "1D" ? i18n("Today") : root.rangeLabel(root.effectiveChartRange)
    property string lastUpdated: ""
    property string nextUpdate: ""
    property color bgColor: getThemeColor("background")
    property color chartBaseColor: getThemeColor("chart")
    property color secondaryTextColor: getThemeColor("text")

    function getThemeColor(what) {
        if (what === "ticker") {
            if (isPlasmaTheme)
                return Kirigami.Theme.textColor;

            return Qt.colorEqual(Plasmoid.configuration.tickerColor, "#ffffff") && isLightTheme ? "#000000" : Plasmoid.configuration.tickerColor;
        } else if (what === "price") {
            if (isPlasmaTheme)
                return Kirigami.Theme.textColor;

            return Qt.colorEqual(Plasmoid.configuration.priceColor, "#ffffff") && isLightTheme ? "#000000" : Plasmoid.configuration.priceColor;
        } else if (what === "background") {
            let color = undefined;
            if (isLightTheme)
                color = "#ffffff";
            else if (isDarkTheme)
                color = "#1a1a1a";
            if (isLightTheme || isDarkTheme) {
                const c = Qt.color(color);
                return Qt.rgba(c.r, c.g, c.b, bgOpacity / 100);
            }
            return "transparent";
        } else if (what === "chart") {
            if (isLightTheme)
                return "#e0e0e0";
            else if (isDarkTheme)
                return "#333333";
            return Kirigami.Theme.disabledTextColor;
        } else if (what === "text") {
            if (isLightTheme)
                return "#555555";
            else if (isDarkTheme)
                return "#888888";
            return Kirigami.Theme.disabledTextColor;
        }
        return "";
    }

    function getColor(color) {
        if (isLightTheme) {
            return "#ffffff";
        } else if (isDarkTheme) {
        }
    }

    function getCurrencySymbol(code) {
        // Yahoo occasionally reports the literal text "null" for a missing currency.
        if (!code || code === "null") return "";
        return Currency.symbol(code);
    }

    // --- EXCHANGE RATES ---
    // Lots can be bought in different currencies, so positions and the portfolio total
    // sometimes have to be converted. The rates for all currencies come from a free daily
    // feed and are cached in the applet configuration; a timer checks once an hour and
    // downloads them only when the feed's next daily update is due (or after 24 hours).
    property string exchangeRatesJson: Plasmoid.configuration.exchangeRates
    property var exchangeRates: {
        try {
            var cached = JSON.parse(root.exchangeRatesJson || "{}");
            return (cached && cached.rates) ? cached.rates : ({});
        } catch (e) {
            return ({});
        }
    }
    property double exchangeRatesUpdated: Number(Plasmoid.configuration.exchangeRatesUpdated) || 0
    property double exchangeRatesNext: Number(Plasmoid.configuration.exchangeRatesNext) || 0
    property bool exchangeRatesFetching: false
    property bool exchangeRatesTryingFallback: false

    // Converts an amount between currencies through the cached daily rates. Returns null
    // when a rate is not known yet, so callers can tell "no rate" apart from a real zero.
    function convertMoney(amount, from, to) {
        return Currency.convert(amount, from, to, root.exchangeRates);
    }

    function exchangeRatesDue() {
        // A missing or unreadable cache is due even if its timestamp looks fresh.
        if (!root.exchangeRates || Object.keys(root.exchangeRates).length < 2) return true;
        if (root.exchangeRatesUpdated <= 0) return true;
        var now = Math.floor(Date.now() / 1000);
        if (root.exchangeRatesNext > 0) return now >= root.exchangeRatesNext;
        return now - root.exchangeRatesUpdated >= 24 * 60 * 60;
    }

    function finishExchangeRates(error) {
        root.exchangeRatesFetching = false;
        root.exchangeRatesTryingFallback = false;
        if (error) console.log("Exchange rates: " + error);
    }

    // Stores the feed's rates. `rates` maps a currency code to units of that currency per
    // one unit of `base`; the cross-rate conversion in currencies.js works with any base.
    function saveExchangeRates(base, rates, updated, next) {
        if (!rates) return false;
        var clean = {};
        var count = 0;
        for (var code in rates) {
            var value = Number(rates[code]);
            if (!(value > 0)) continue;
            clean[String(code).toUpperCase()] = value;
            count++;
        }
        if (count < 2) return false;
        var b = String(base || "USD").toUpperCase();
        if (!(clean[b] > 0)) clean[b] = 1;
        try {
            Plasmoid.configuration.exchangeRates = JSON.stringify({ base: b, rates: clean });
            Plasmoid.configuration.exchangeRatesUpdated = String(updated);
            Plasmoid.configuration.exchangeRatesNext = String(next);
        } catch (e) {
            console.log("Error saving exchange rates: " + e);
            return false;
        }
        root.exchangeRatesFetching = false;
        root.exchangeRatesTryingFallback = false;
        return true;
    }

    // Secondary feed, used when open.er-api.com cannot be reached. It returns the same
    // shape of data (all currencies, relative to USD) under a lowercase "usd" object.
    function fetchExchangeRatesFallback() {
        if (!root.exchangeRatesFetching || root.exchangeRatesTryingFallback) return;
        root.exchangeRatesTryingFallback = true;
        var now = Math.floor(Date.now() / 1000);
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            var ok = false;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    if (data && data.usd && root.saveExchangeRates("USD", data.usd, now, now + 86400))
                        ok = true;
                } catch (e) {
                    console.log("Error parsing fallback exchange rates: " + e);
                }
            }
            if (!ok) root.finishExchangeRates("no exchange-rate feed available");
        };
        xhr.ontimeout = function() { root.finishExchangeRates("exchange-rate request timed out"); };
        xhr.onerror = function() { root.finishExchangeRates("exchange-rate request failed"); };
        xhr.open("GET", "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json");
        xhr.timeout = 20000;
        xhr.send();
    }

    function fetchExchangeRates() {
        if (root.exchangeRatesFetching) return;
        root.exchangeRatesFetching = true;
        root.exchangeRatesTryingFallback = false;
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText);
                    var now = Math.floor(Date.now() / 1000);
                    if (data && data.result === "success" && data.rates) {
                        var updated = Number(data.time_last_update_unix) || now;
                        var next = Number(data.time_next_update_unix) || (updated + 86400);
                        if (root.saveExchangeRates(data.base_code || "USD", data.rates, updated, next))
                            return;
                    }
                } catch (e) {
                    console.log("Error parsing exchange rates: " + e);
                }
            }
            root.fetchExchangeRatesFallback();
        };
        xhr.ontimeout = function() { root.fetchExchangeRatesFallback(); };
        xhr.onerror = function() { root.fetchExchangeRatesFallback(); };
        xhr.open("GET", "https://open.er-api.com/v6/latest/USD");
        xhr.timeout = 20000;
        xhr.send();
    }

    function maybeRefreshExchangeRates() {
        if (root.exchangeRatesFetching) return;
        if (root.exchangeRatesDue()) root.fetchExchangeRates();
    }

    // --- PORTFOLIO TRACKING HELPERS ---
    // A ticker can have several saved lots (bought at different times/prices). They are added up
    // into one position with the figures a portfolio view leads with: shares, average cost,
    // market value, total gain (against the cost of all the lots) and the gain over the period
    // the widget shows (today for the 1D chart). Returns null when the ticker has no lots.
    //
    // Every lot's average cost is in that lot's own currency. The live quote is in the
    // instrument's Yahoo currency, so it is converted before it is compared with the cost.
    // A position whose lots all share a currency is shown in that currency; mixed lots are
    // converted to the configured portfolio currency so they can be added up.
    function getPortfolioSummary(ticker, dataStr, rawPrice, prevClose, quoteCurrency) {
        if (!ticker || !dataStr || !rawPrice) return null;
        try {
            var portfolio = JSON.parse(dataStr);
            var upperTicker = ticker.trim().toUpperCase();
            var lots = [], lotCurrencies = {};
            for (var i = 0; i < portfolio.length; i++) {
                if (portfolio[i].ticker !== upperTicker) continue;
                var s = Number(portfolio[i].shares) || 0;
                if (s <= 0) continue;
                // Lots saved before this feature existed have no currency and are USD.
                var lotCurrency = Currency.major(portfolio[i].currency) || "USD";
                lots.push({
                    shares: s,
                    averageCost: Number(portfolio[i].averageCost) || 0,
                    currency: lotCurrency
                });
                lotCurrencies[lotCurrency] = true;
            }
            if (lots.length === 0) return null;

            var codes = Object.keys(lotCurrencies);
            var target = codes.length === 1 ? codes[0] : root.portfolioCurrency;
            // Mixed positions are always converted to a catalog currency; a single-currency
            // position keeps its own code even if the feed has no rate for it, so a quote
            // already in that currency can still be shown without a conversion.
            if (codes.length > 1 && !Currency.isKnown(target)) target = "USD";

            var quoteCode = Currency.major(quoteCurrency);
            var quoteFactor = Currency.minorFactor(quoteCurrency);
            var price = rawPrice * quoteFactor;
            // Without a quote currency (old cache / unexpected response) assume the price
            // is already expressed in the currency the position is shown in.
            var priceInTarget = quoteCode === "" ? price : root.convertMoney(price, quoteCode, target);
            if (priceInTarget === null) return null;
            var prevInTarget = null;
            if (prevClose > 0) {
                var prev = prevClose * quoteFactor;
                prevInTarget = quoteCode === "" ? prev : root.convertMoney(prev, quoteCode, target);
            }

            var shares = 0, cost = 0, value = 0, day = 0;
            var dayKnown = prevInTarget !== null;
            for (var j = 0; j < lots.length; j++) {
                var costInTarget = root.convertMoney(lots[j].averageCost, lots[j].currency, target);
                if (costInTarget === null) return null;
                shares += lots[j].shares;
                cost += lots[j].shares * costInTarget;
                value += lots[j].shares * priceInTarget;
                if (dayKnown) day += lots[j].shares * (priceInTarget - prevInTarget);
            }
            if (shares <= 0) return null;
            var plValue = value - cost;
            return {
                lots: lots.length, shares: shares, avgCost: cost / shares, cost: cost, value: value,
                plValue: plValue, plPercent: cost > 0 ? (plValue / cost) * 100 : 0, plIsPos: plValue >= 0,
                dayValue: dayKnown ? day : null, dayIsPos: !dayKnown || day >= 0, currency: target
            };
        } catch (e) {
            console.log("Error parsing portfolio data: " + e);
        }
        return null;
    }

    // "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
    function formatMoney(sym, v, signed) {
        var sign = v < 0 ? "-" : (signed && v > 0 ? "+" : "");
        return sign + sym + root.formatNumber(Math.abs(v), false);
    }

    // The tickers that have at least one lot with shares, upper-cased, each once.
    function getPortfolioTickers(dataStr) {
        if (!dataStr) return [];
        try {
            var portfolio = JSON.parse(dataStr), seen = {}, out = [];
            for (var i = 0; i < portfolio.length; i++) {
                var t = String(portfolio[i].ticker || "").trim().toUpperCase();
                if (t === "" || seen[t] || !(Number(portfolio[i].shares) > 0)) continue;
                seen[t] = true;
                out.push(t);
            }
            return out;
        } catch (e) {
            return [];
        }
    }

    // The stored data-range codes ("1D", "5D", …) are what the API and the config use;
    // this is the (translated) label shown for them in the views and the tooltip.
    function rangeLabel(range) {
        switch (range) {
            case "1D":  return i18n("1D");
            case "5D":  return i18n("5D");
            case "1M":  return i18n("1M");
            case "6M":  return i18n("6M");
            case "YTD": return i18n("YTD");
            case "1Y":  return i18n("1Y");
            case "5Y":  return i18n("5Y");
            case "Max": return i18n("Max");
            default:    return range;
        }
    }

    // Label for the range buttons in the chart. The whole history is called "All" there,
    // as in Yahoo Finance, while the stored/configured value stays "Max".
    function chartRangeButtonLabel(range) {
        return range === "Max" ? i18nc("@item:chart range", "All") : root.rangeLabel(range);
    }

    // Range selected from the chart buttons. It is stored separately from the list's
    // configured range, so switching the chart range does not reload the whole list.
    function setChartViewRange(range) {
        if (range === root.effectiveChartRange) return;
        // Apply and fetch it right away; the config change is for persistence only.
        root.chartViewRangeActive = range;
        if (root.singleTicker.trim() !== "")
            root.fetchSingleStock(root.singleTicker, range);
        try {
            Plasmoid.configuration.chartViewRange = range;
        } catch (e) {
            console.log("Error saving chart range: " + e);
        }
    }

    // Chart type selected from the chart buttons. It writes the same setting as the
    // Chart page, so both stay in sync.
    function setChartStyle(style) {
        if (style === root.chartStyle) return;
        try {
            Plasmoid.configuration.chartStyle = style;
        } catch (e) {
            console.log("Error saving chart style: " + e);
        }
    }

    // Side-by-side layout: the divider applies the width live and the configuration is
    // written only when the drag ends, so moving it does not hammer the config file.
    function setTwoColumnLeftWidth(width) {
        var value = Math.round(width);
        if (value < 0) value = 0;
        if (value !== root.twoColumnLeftWidth) root.twoColumnLeftWidth = value;
    }
    function saveTwoColumnLeftWidth() {
        try {
            Plasmoid.configuration.twoColumnLeftWidth = root.twoColumnLeftWidth;
        } catch (e) {
            console.log("Error saving two-column width: " + e);
        }
    }

    // Copy the list row's values (configured data range) into the panel indicator.
    function updatePanelFromRow(ticker) {
        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            if (row.ticker !== ticker) continue;
            root.panelCurrentPrice = row.price;
            root.panelCurrentPercent = row.pct;
            root.panelCurrentIsPositive = row.isPos;
            return;
        }
    }

    // ListModel turns a top-level array role into a nested ListModel, so the chart
    // arrays are cached as JSON strings and decoded here. Without this, selecting a
    // list row handed a ListModel to the Canvas, which blanked the chart.
    function chartArray(value) {
        if (Array.isArray(value)) return value;
        if (typeof value === "string") {
            try {
                var parsed = JSON.parse(value);
                return Array.isArray(parsed) ? parsed : [];
            } catch (e) { return []; }
        }
        return [];
    }

    // Select a watchlist row. The list already has the row's quote, so only the chart
    // needs a request; refreshing the whole list here made all rows update in chunks
    // before the selected ticker's chart arrived.
    function selectTicker(ticker, persist) {
        var clean = ticker ? String(ticker).trim() : "";
        if (clean === "") return;
        root.manualPanelTickerOverride = clean;
        root.panelTicker = clean;
        // Auto-cycle changes the panel stock every few seconds; persisting those would
        // rewrite the config constantly. Only explicit user selections are remembered.
        if (persist !== false) {
            try {
                Plasmoid.configuration.selectedTicker = clean;
            } catch (e) {
                console.log("Error saving selected ticker: " + e);
            }
        }
        root.updatePanelFromRow(clean);

        // Use the row that is already in the list so the title, quote, portfolio and
        // graph switch together, then refresh the chart in the background. Without
        // this, the header changed immediately while the chart waited for the reply.
        var row = null;
        for (var i = 0; i < stockModel.count; i++) {
            if (stockModel.get(i).ticker === clean) {
                row = stockModel.get(i);
                break;
            }
        }
        var chartFromCache = false;
        if (row) {
            root.singleCompanyName = row.name;
            root.currentRawPrice = row.currentRaw;
            root.currentPrice = row.price;
            root.currencySym = row.currencySym;
            root.quoteCurrency = row.currency;
            root.previousClose = row.prevClose;
            // The change and the chart itself depend on the selected range. They can only
            // be reused when the list and the chart share the range.
            if (root.effectiveChartRange === root.chartRange) {
                root.isPositive = row.isPos;
                root.priceChange = row.change;
                root.percentChange = row.pct;
                root.chartDataPoints = root.chartArray(row.chartPoints);
                root.chartTimestamps = root.chartArray(row.chartTimes);
                var sessions = row.chartSessions;
                root.chartSessions = (sessions && sessions.preValues !== undefined)
                                     ? sessions : null;
                root.chartCandles = root.chartArray(row.chartCandles);
                root.chartReferencePrice = row.chartRef;
                root.chartPreSession = row.chartPre === true;
                root.chartSessionStart = row.chartSessionStart || 0;
                root.chartSessionCurrent = row.chartSessionCurrent !== false;
                root.quoteTimestamp = row.quoteTime || 0;
                chartFromCache = root.chartDataPoints.length > 0;
            }
        }

        // Switching to a row uses what was already fetched for it; the list refresh (and
        // middle-click) keep that data current. Ask for a chart only when the row has no
        // cached chart yet, or when the chart range differs from the list's (the cache
        // holds the list range).
        var needsChart = !chartFromCache || root.effectiveChartRange !== root.chartRange;
        if (root.singleTicker !== clean) {
            root.singleTicker = clean;
            if (needsChart) root.fetchSingleStock(clean, root.effectiveChartRange);
        } else if (needsChart) {
            root.fetchSingleStock(clean, root.effectiveChartRange);
        }
    }

    // --- MOUSE ACTIONS ---
    // Open the Yahoo Finance quote page for a symbol. Used by the configurable mouse
    // actions and by the context menus, so all paths behave the same.
    function openYahooQuote(symbol) {
        var clean = symbol ? String(symbol).trim() : "";
        if (clean === "") return;
        Qt.openUrlExternally("https://finance.yahoo.com/quote/" + clean);
    }

    // Left click on a watchlist row: select it (recommended) or open its quote page.
    function performRowLeftClick(symbol) {
        if (root.mouseRowLeftAction === "open") root.openYahooQuote(symbol);
        else root.selectTicker(symbol);
    }

    // Middle click on a row, the chart or the panel indicator. Returns true when the
    // action was a refresh, so the caller can show the existing opacity flicker.
    function performMiddleClick(symbol) {
        if (root.mouseMiddleAction === "refresh") {
            root.refreshData();
            return true;
        }
        if (root.mouseMiddleAction === "open") root.openYahooQuote(symbol);
        return false;
    }

    function performDoubleClick(symbol) {
        if (root.mouseDoubleClickAction === "open") root.openYahooQuote(symbol);
    }

    // --- NEW HELPER: GET API PARAMETERS BASED ON CONFIG ---
    function getApiParams(range) {
        // Yahoo Finance requires specific intervals for specific ranges
        // to return valid data and look good.
        switch (range) {
            case "1D":  return "range=2d&interval=2m" + (root.showExtendedHours ? "&includePrePost=true" : ""); // Use 2d to get reliable previous close for indices
            case "5D":  return "range=5d&interval=15m";
            case "1M":  return "range=1mo&interval=60m"; // '1mo' is Yahoo syntax
            case "6M":  return "range=6mo&interval=1d";
            case "YTD": return "range=ytd&interval=1d";
            case "1Y":  return "range=1y&interval=1d";
            case "5Y":  return "range=5y&interval=1wk";
            case "Max": return "range=max&interval=1mo";
            default:    return "range=1d&interval=2m";
        }
    }

    // --- PRE-MARKET / AFTER-MARKET ---
    // Latest pre-market or after-hours quote per requested symbol, as
    // { label, time, price, change, pct, isPos }. Only the quote from the session
    // running now is surfaced (see extendedQuote()).
    property bool showExtendedHours: Plasmoid.configuration.showExtendedHours
    // Keep the last pre-market/after-hours quote visible after its session ends, marked
    // as closed, instead of falling back to the regular close only.
    property bool keepExtendedAfterClose: Plasmoid.configuration.keepExtendedAfterClose
    property var extendedData: ({})
    // Last extended-hours quote seen per symbol, kept separately so it can still be
    // shown (marked closed) after its session ends.
    property var lastExtendedData: ({})

    // Trading sessions from the latest quote metadata, per symbol. Keeping them
    // lets the open/closed state be evaluated at display time instead of only
    // when a quote was fetched.
    property var marketSessions: ({})
    // Bumped once a minute so bindings that call marketStatusFor() re-evaluate
    // when a session starts or ends, even if no new quote arrived in between.
    property int marketClock: 0
    Timer {
        interval: 60000
        running: root.showExtendedHours
        repeat: true
        onTriggered: root.marketClock++
    }

    function setExtendedData(symbol, entry) {
        var copy = Object.assign({}, root.extendedData);
        if (entry) copy[symbol] = entry;
        else delete copy[symbol];
        root.extendedData = copy;
    }

    function setLastExtendedData(symbol, entry) {
        var copy = Object.assign({}, root.lastExtendedData);
        if (entry) copy[symbol] = entry;
        else delete copy[symbol];
        root.lastExtendedData = copy;
    }

    function setMarketSession(symbol, meta) {
        var periods = meta.currentTradingPeriod || ({});
        var previous = root.marketSessions[symbol] || ({});
        var copy = Object.assign({}, root.marketSessions);
        copy[symbol] = {
            "pre": periods.pre || null,
            "regular": periods.regular || null,
            "post": periods.post || null,
            "hasPrePost": meta.hasPrePostMarketData !== 0 && meta.hasPrePostMarketData !== false,
            "crypto": meta.instrumentType === "CRYPTOCURRENCY",
            // Time of the latest regular quote, used to tell a fresh open quote from
            // the previous close that Yahoo still returns during the first seconds.
            // Extended-hours responses can repeat an older time; never go backwards.
            "quoteTime": Math.max(meta.regularMarketTime || 0, previous.quoteTime || 0)
        };
        root.marketSessions = copy;
    }

    // "open", "pre", "post" or "closed" for the exchange the symbol trades on,
    // from the trading periods in the latest quote. Crypto has no closing time.
    function marketStatusFor(symbol) {
        var s = root.marketSessions[symbol];
        if (!s) return "";
        // Read the clock so QML re-evaluates callers when a session boundary passes.
        if (root.marketClock < 0) return "";
        var now = Math.floor(Date.now() / 1000);
        if (s.crypto) return "open";
        if (s.regular && now >= s.regular.start && now < s.regular.end) return "open";
        if (s.pre && now >= s.pre.start && now < s.pre.end) return "pre";
        if (s.post && now >= s.post.start && now < s.post.end) return "post";
        return "closed";
    }

    function hasPrePostDataFor(symbol) {
        var s = root.marketSessions[symbol];
        return s ? s.hasPrePost : true;
    }

    // True when the instrument's market is closed: outside every session, or in a
    // pre/post window for an instrument that has no extended-hours trading at all
    // (indices, for example). Unknown symbols are not marked closed.
    function isMarketClosedFor(symbol) {
        var s = root.marketSessions[symbol];
        if (!s) return false;
        var status = root.marketStatusFor(symbol);
        if (status === "closed") return true;
        return !s.hasPrePost && (status === "pre" || status === "post");
    }

    // True while the regular session has started but its first quote has not arrived.
    // Yahoo keeps returning the previous close, with its old timestamp, until the first
    // trade of the new session reaches the feed.
    function awaitingFirstRegularQuote(symbol) {
        var s = root.marketSessions[symbol];
        if (!s || !s.regular) return false;
        // Read the clock so the waiting state re-evaluates at the session boundary.
        if (root.marketClock < 0) return false;
        var now = Math.floor(Date.now() / 1000);
        if (now < s.regular.start || now >= s.regular.end) return false;
        return !(s.quoteTime > 0) || s.quoteTime < s.regular.start;
    }

    // The extended quote to show for a symbol: the live one while its session runs,
    // or — when the option is enabled — the last one after the market closes. The
    // session checks keep a Friday after-hours quote from being shown as current
    // during a later pre-market session.
    function extendedQuote(symbol) {
        if (!root.showExtendedHours) return undefined;
        var status = root.marketStatusFor(symbol);
        var s = root.marketSessions[symbol];
        if (status === "open" && root.awaitingFirstRegularQuote(symbol)) {
            // The market is open, but Yahoo has not published the first regular trade yet.
            // Keep showing the last pre-market quote instead of the previous close.
            if (!s || !s.regular) return undefined;
            var last = root.lastExtendedData[symbol];
            var preStart = s.pre && s.pre.start < s.regular.start
                           ? s.pre.start : (s.regular.start - 12 * 3600);
            if (last && last.kind === "pre" && last.time >= preStart && last.time < s.regular.start)
                return last;
            return undefined;
        }
        if (status === "closed") {
            if (!root.keepExtendedAfterClose) return undefined;
            // The last extended quote of the most recent session, kept so it can
            // still be shown once the market closes.
            return root.lastExtendedData[symbol];
        }
        var e = root.extendedData[symbol];
        if (!e || !s || !e.time) return undefined;
        var period = status === "pre" ? s.pre : (status === "post" ? s.post : null);
        if (!period) return undefined;
        if (e.time < period.start || e.time >= period.end) return undefined;
        if ((status === "pre" && e.kind !== "pre")
            || (status === "post" && e.kind !== "post")) return undefined;
        return e;
    }

    // The chart API returns pre/post candles when asked for them. The current
    // session comes from the metadata, not from the last candle alone: Yahoo keeps
    // serving the last session's candles after it has ended.
    function processExtendedData(symbol, json) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            root.setMarketSession(symbol, meta);
            var status = root.marketStatusFor(symbol);
            if (status === "open") { root.setExtendedData(symbol, null); return; }
            if (status === "closed" && !root.keepExtendedAfterClose) {
                root.setExtendedData(symbol, null);
                return;
            }
            if (!root.hasPrePostDataFor(symbol)) { root.setExtendedData(symbol, null); return; }

            var closes = result.indicators.quote[0].close;
            var stamps = result.timestamp;
            if (!stamps || !closes) { root.setExtendedData(symbol, null); return; }

            var last = -1;
            for (var i = closes.length - 1; i >= 0; i--) {
                if (closes[i] !== null) { last = i; break; }
            }
            if (last < 0) { root.setExtendedData(symbol, null); return; }

            var session = root.marketSessions[symbol];
            var period = null;
            // The session is kept as an untranslated kind as well, so the checks further down
            // never depend on the wording of the (translated) label.
            var kind = "";
            var label = "";
            if (status === "pre" || status === "post") {
                period = status === "pre" ? session.pre : session.post;
                kind = status;
                label = status === "pre" ? i18n("Pre-Market") : i18n("After-Hours");
            } else {
                // Closed: keep the last session's quote if the option asks for it. The
                // session comes from meta.tradingPeriods, not currentTradingPeriod: the
                // latter already describes the next trading day before its pre-market
                // starts, while the last candle still belongs to the previous day's
                // after-hours. Looking only at today's periods dropped that quote and
                // left "No after-hours" on screen after a restart.
                var days = root.tradingDays(meta);
                for (var d = days.length - 1; d >= 0 && !period; d--) {
                    if (days[d].post && stamps[last] >= days[d].post.start && stamps[last] < days[d].post.end) {
                        period = days[d].post;
                        kind = "post";
                        label = i18n("After-Hours");
                    } else if (days[d].pre && stamps[last] >= days[d].pre.start && stamps[last] < days[d].pre.end) {
                        period = days[d].pre;
                        kind = "pre";
                        label = i18n("Pre-Market");
                    }
                }
            }
            if (!period || stamps[last] < period.start || stamps[last] >= period.end) {
                root.setExtendedData(symbol, null);
                return;
            }

            var base = meta.regularMarketPrice;
            if (!base) { root.setExtendedData(symbol, null); return; }

            var price = closes[last];
            var change = price - base;
            var entry = {
                "kind": kind,
                "label": label,
                "time": stamps[last],
                "price": getCurrencySymbol(meta.currency) + formatNumber(price, false),
                "change": formatNumber(change, true),
                "pct": formatNumber((change / base) * 100, true) + "%",
                "isPos": change >= 0
            };
            root.setExtendedData(symbol, entry);
            root.setLastExtendedData(symbol, entry);
        } catch (e) { console.log("Error parsing extended hours: " + e); }
    }

    function fetchExtendedHours(symbol) {
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?range=1d&interval=5m&includePrePost=true";
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                processExtendedData(symbol, JSON.parse(xhr.responseText));
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    function refreshExtendedHours() {
        if (!root.showExtendedHours) return;
        if (root.isMultiMode) {
            root.multiTickers.split(",").forEach(function(t) {
                var clean = t.trim();
                if (clean !== "") root.fetchExtendedHours(clean);
            });
        } else if (root.singleTicker.trim() !== "") {
            root.fetchExtendedHours(root.singleTicker);
        }
    }

    onShowExtendedHoursChanged: {
        if (!showExtendedHours) { extendedData = ({}); lastExtendedData = ({}); }
        // The 1D chart request includes pre/post data only while this is on.
        refreshData();
    }

    onKeepExtendedAfterCloseChanged: {
        if (keepExtendedAfterClose) {
            if (showExtendedHours) refreshExtendedHours();
        } else {
            lastExtendedData = ({});
        }
    }

    function refreshData() {
        if (root.isMultiMode) {
            fetchMultiStocks();
            // The list request above covers the chart only when both use the same range.
            if (root.effectiveChartRange !== root.chartRange && root.singleTicker.trim() !== "")
                fetchSingleStock(root.singleTicker);
        } 
        else {
            fetchSingleStock(root.singleTicker);
            // The chart can use a range of its own; the panel must keep the configured one.
            if (root.effectiveChartRange !== root.chartRange)
                fetchPanelStock(root.singleTicker);
        }
        refreshExtendedHours();
    }

    // --- NEW CHECK: IS MARKET OPEN? ---
    function checkTimeAndRefresh() {
        // 1. Always check weekend first (optional, but saves battery)
        var d = new Date();
        var day = d.getDay();
        // 0=Sun, 6=Sat. Crypto (BTC) runs 24/7, so you might want to skip this check for crypto.
        // Assuming stocks for now:
        if (root.skipWeekendRefresh && (day === 0 || day === 6)) {
            return;
        }

        // 2. Check Time Window if enabled
        if (root.limitHours) {
            var nowHour = d.getHours();
            var nowMin = d.getMinutes();
            var currentTimeVal = nowHour * 60 + nowMin;

            var startTimeVal = root.startHour * 60 + root.startMinute;
            var endTimeVal = root.endHour * 60 + root.endMinute;

            // If we are BEFORE start OR AFTER end, stop.
            if (currentTimeVal < startTimeVal || currentTimeVal >= endTimeVal) {
                return; // Do not fetch
            }
        }

        // 3. If passed, refresh
        refreshData();
    }

    function fetchSingleStock(symbol, range) {
        var chartRange = range || root.effectiveChartRange;
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?" + getApiParams(chartRange);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                // Ignore a reply for a range or symbol the user has already switched away from.
                if (chartRange !== root.effectiveChartRange || symbol !== root.singleTicker) return;
                var response = JSON.parse(xhr.responseText);
                processSingleData(response, symbol, chartRange);
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    // Quote for the compact panel indicator, fetched separately when the chart uses a
    // range of its own. The panel always follows the configured data range.
    function fetchPanelStock(symbol) {
        var range = root.chartRange;
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?" + getApiParams(range);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                if (range !== root.chartRange || symbol !== root.panelSymbol) return;
                processPanelData(JSON.parse(xhr.responseText), symbol, range);
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    function fetchMultiStocks() {
        var range = root.chartRange;
        var tickers = root.multiTickers.split(",");
        var targetTickers = [];
        tickers.forEach(function(t) {
            var clean = t.trim();
            if (clean !== "") targetTickers.push(clean);
        });

        if (root.sortAlphabetically) {
            targetTickers.sort(function(a, b) {
                return a.localeCompare(b);
            });
        }
        
        var defaultPanelTicker = targetTickers.length > 0 ? targetTickers[0] : "";
        root.panelTicker = root.manualPanelTickerOverride !== "" && targetTickers.indexOf(root.manualPanelTickerOverride) !== -1 ? root.manualPanelTickerOverride : defaultPanelTicker;
        root.singleTicker = root.panelTicker;

        // Initialize placeholders to maintain display order before async completion
        if (stockModel.count !== targetTickers.length) {
            stockModel.clear();
            targetTickers.forEach(function(cleanSymbol) {
                stockModel.append({
                    "ticker": cleanSymbol,
                    "name": root.loadingText,
                    "price": "---",
                    "change": "",
                    "pct": "",
                    "isPos": true,
                    "chartPoints": "[]",
                    "chartTimes": "[]",
                    // ListModel does not create a role from a null value; use an empty
                    // object as the placeholder and treat it as "no sessions" on read.
                    "chartSessions": ({}),
                    "chartCandles": "[]",
                    "chartRef": 0.0,
                    "chartPre": false,
                    "chartSessionStart": 0.0,
                    "chartSessionCurrent": true,
                    "quoteTime": 0.0,
                    "prevClose": 0.0,
                    "currentRaw": 0.0,
                    "currencySym": "",
                    "currency": ""
                });
            });
        }

        targetTickers.forEach(function(cleanSymbol) {
            var xhr = new XMLHttpRequest();
            var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + cleanSymbol + "?" + getApiParams(range);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    // Ignore a reply for a range the user has already switched away from.
                    if (range !== root.chartRange) return;
                    var response = JSON.parse(xhr.responseText);
                    processListRow(cleanSymbol, response, range);
                }
            }
            xhr.open("GET", url);
            xhr.send();
        });
    }

    // The candles that make up the chart, with null entries dropped. The timestamps are
    // kept in a parallel array so the time scale can position its labels on the exact
    // data points; both arrays must stay the same length. For 1D the request asks for two
    // days (so the previous close is available) but only the current session is plotted.
    // When `quote` is supplied, the open/high/low/volume series are filtered in lockstep
    // with the closes, so the candlestick chart can aggregate them without re-fetching.
    // Trading days described by meta.tradingPeriods (oldest to newest) as
    // { pre, regular, post }, each a { start, end } or null. Zero-length periods count as absent.
    function tradingDays(meta) {
        function period(p) {
            if (p && p.length) p = p[0];
            return (p && p.start < p.end) ? p : null;
        }
        var days = [];
        var tp = meta ? meta.tradingPeriods : null;
        if (tp && tp.regular && tp.regular.length) {
            for (var i = 0; i < tp.regular.length; i++) {
                days.push({
                    pre: tp.pre ? period(tp.pre[i]) : null,
                    regular: period(tp.regular[i]),
                    post: tp.post ? period(tp.post[i]) : null
                });
            }
        } else if (tp && tp.length) {
            for (var j = 0; j < tp.length; j++) days.push({ pre: null, regular: period(tp[j]), post: null });
        } else if (meta && meta.currentTradingPeriod) {
            var c = meta.currentTradingPeriod;
            days.push({ pre: period(c.pre), regular: period(c.regular), post: period(c.post) });
        }
        return days;
    }
    // Latest trading day whose regular session has at least one data point, or null.
    function displayedDay(meta, timestamps) {
        if (!timestamps) return null;
        var days = root.tradingDays(meta);
        for (var d = days.length - 1; d >= 0; d--) {
            var reg = days[d].regular;
            if (!reg) continue;
            for (var i = 0; i < timestamps.length; i++) {
                if (timestamps[i] >= reg.start && timestamps[i] < reg.end) return days[d];
            }
        }
        return null;
    }
    // The session a 1D chart plots. Normally the latest completed regular session, but
    // while the current pre-market is running (or before the first regular candle of the
    // day arrives) its points are plotted instead, so the chart follows today's quote the
    // same way a regular session does on exchanges without extended hours. Falls back to
    // the regular session until the pre-market has a close, so the chart is never empty.
    function chartDayFor(meta, timestamps, quotes) {
        var day = root.displayedDay(meta, timestamps);
        var periods = meta ? meta.currentTradingPeriod : null;
        if (!periods || !timestamps || !quotes) return day;
        // The current regular session is already on screen; keep the full-day chart.
        if (day && day.regular && periods.regular && day.regular.start === periods.regular.start)
            return day;
        var pre = periods.pre;
        if (!pre || !(pre.start < pre.end)) return day;
        for (var i = 0; i < timestamps.length; i++) {
            if (timestamps[i] >= pre.start && timestamps[i] < pre.end
                    && quotes[i] !== null && quotes[i] !== undefined)
                return { pre: null, regular: pre, post: null };
        }
        return day;
    }
    // True when `day` is the running pre-market, i.e. the session chartDayFor substituted
    // for the regular one. The pre period must be non-empty: exchanges without extended
    // hours (BVB, for example) report an empty pre period that starts at the regular open,
    // and that must not turn the regular session into a pre-market one.
    function isPreSessionDay(meta, day) {
        var periods = meta ? meta.currentTradingPeriod : null;
        var pre = periods ? periods.pre : null;
        return !!(day && day.regular && pre && pre.start < pre.end
                  && day.regular.start === pre.start
                  && day.regular.end === pre.end);
    }
    // Pre-market and after-hours closes of `day`, or null when neither has any point.
    function extendedSessionSeries(quotes, timestamps, day) {
        var preTimes = [], preValues = [], postTimes = [], postValues = [];
        for (var i = 0; i < quotes.length; i++) {
            var v = quotes[i], t = timestamps[i];
            if (v === null || v === undefined) continue;
            if (day.pre && t >= day.pre.start && t < day.pre.end) { preTimes.push(t); preValues.push(v); }
            else if (day.post && t >= day.post.start && t < day.post.end) { postTimes.push(t); postValues.push(v); }
        }
        if (preValues.length === 0 && postValues.length === 0) return null;
        return {
            preTimes: preTimes, preValues: preValues,
            postTimes: postTimes, postValues: postValues,
            regStart: day.regular.start, regEnd: day.regular.end,
            preStart: day.pre ? day.pre.start : 0,
            postEnd: day.post ? day.post.end : 0
        };
    }
    function cleanChartData(quotes, timestamps, startTime, range, quote, day) {
        var chartRange = range || root.effectiveChartRange;
        var q = quote || {};
        var opens = q.open || null;
        var highs = q.high || null;
        var lows = q.low || null;
        var volumes = q.volume || null;
        var values = [], times = [], outOpens = [], outHighs = [], outLows = [], outVolumes = [];
        if (!quotes) return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };

        function addPoint(i) {
            var close = quotes[i];
            if (close === null || close === undefined) return;
            values.push(close);
            times.push(timestamps ? timestamps[i] : 0);
            outOpens.push(opens && opens[i] !== null && opens[i] !== undefined ? opens[i] : close);
            outHighs.push(highs && highs[i] !== null && highs[i] !== undefined ? highs[i] : close);
            outLows.push(lows && lows[i] !== null && lows[i] !== undefined ? lows[i] : close);
            outVolumes.push(volumes && volumes[i] !== null && volumes[i] !== undefined ? volumes[i] : 0);
        }

        var bounded = chartRange === "1D" && day && day.regular && timestamps;
        for (var i = 0; i < quotes.length; i++) {
            if (bounded) {
                // Extended-hours points are requested but belong to chartSessions, not here.
                if (timestamps[i] < day.regular.start || timestamps[i] >= day.regular.end) continue;
            } else if (chartRange === "1D" && startTime > 0 && timestamps && timestamps[i] < startTime)
                continue;
            addPoint(i);
        }

        if (!bounded && chartRange === "1D" && values.length === 0 && timestamps && timestamps.length > 0) {
            var dayStartIndex = 0;
            for (var j = timestamps.length - 1; j > 0; j--) {
                if (timestamps[j] - timestamps[j-1] > 4 * 3600) {
                    dayStartIndex = j;
                    break;
                }
            }
            for (var k = dayStartIndex; k < quotes.length; k++) addPoint(k);
        }
        return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };
    }

    // A session starts with a single tick before the next candle arrives. A one-point
    // series cannot be drawn (the canvas needs two points), so the chart went blank
    // between the first quote of the day and the second candle. Start the day's line at
    // the previous close instead: the card then shows the move since yesterday from the
    // first tick, and draws itself normally once the next candle arrives.
    function seedFirstSessionPoint(chart, dayStart, meta) {
        if (!chart || !chart.values || chart.values.length !== 1) return;
        if (!chart.times || chart.times.length !== 1 || !(chart.times[0] > 0)) return;
        var dayTime = (dayStart > 0 && dayStart < chart.times[0]) ? dayStart : chart.times[0];
        var seed = root.dailyPreviousClose(meta, chart.values[0]);
        if (!(seed > 0)) seed = chart.values[0];
        chart.values.unshift(seed);
        chart.times.unshift(dayTime);
        chart.opens.unshift(seed);
        chart.highs.unshift(seed);
        chart.lows.unshift(seed);
        chart.volumes.unshift(0);
    }

    // Target number of candles for each range. The API intervals differ per range, so a
    // fixed count keeps the candle width (and the visual density) comparable everywhere.
    function candleTarget(range) {
        switch (range) {
            case "1D":  return 56;
            case "5D":  return 56;
            case "1M":  return 24;
            case "6M":  return 30;
            case "YTD": return 45;
            case "1Y":  return 52;
            case "5Y":  return 60;
            case "Max": return 60;
            default:    return 60;
        }
    }

    // Yesterday's close, independent of the chart range. Yahoo sends `previousClose` only
    // for the 1D range; longer ranges still carry the day's change, so derive it from
    // regularMarketPrice - fulldayChange (or from the change percentage).
    function dailyPreviousClose(meta, fallback) {
        if (meta) {
            var prev = meta.regularMarketPreviousClose || meta.previousClose || 0;
            if (prev > 0) return prev;
            // `fulldayChange` is the most precise day change, but it can follow an
            // after-hours price; only use it while it still refers to the regular price.
            var regular = meta.regularMarketPrice;
            var fullDay = meta.fulldayPrice;
            if (regular > 0 && typeof meta.fulldayChange === "number"
                    && (!(fullDay > 0) || Math.abs(fullDay - regular) < 0.005))
                return regular - meta.fulldayChange;
            if (regular > 0 && typeof meta.regularMarketChangePercent === "number"
                    && meta.regularMarketChangePercent > -100)
                return regular / (1 + meta.regularMarketChangePercent / 100);
        }
        return fallback > 0 ? fallback : 0;
    }

    // Aggregate the aligned OHLCV series into `target` candles. Aggregating by count
    // rather than by clock time keeps the same candle width across ranges and collapses
    // weekends/holidays the way a trading chart does.
    function buildCandles(chart, range, asked) {
        var n = chart && chart.values ? chart.values.length : 0;
        if (n < 2) return [];
        var target = Math.min(n, asked > 0 ? Math.round(asked) : candleTarget(range));
        var candles = [];
        for (var i = 0; i < target; i++) {
            var start = Math.floor(i * n / target);
            var end = Math.floor((i + 1) * n / target);
            if (end <= start) end = start + 1;
            if (start >= n) break;

            var open = chart.opens[start] !== undefined ? chart.opens[start] : chart.values[start];
            var close = chart.values[end - 1];
            var high = open;
            var low = open;
            var volume = 0;
            for (var j = start; j < end; j++) {
                var h = chart.highs[j] !== undefined ? chart.highs[j] : chart.values[j];
                var l = chart.lows[j] !== undefined ? chart.lows[j] : chart.values[j];
                if (h > high) high = h;
                if (l < low) low = l;
                volume += chart.volumes[j] || 0;
            }
            if (close > high) high = close;
            if (close < low) low = close;
            candles.push({
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                time: chart.times[start] || 0
            });
        }
        return candles;
    }

    // Candles for one extended session (pre or post) of the displayed day, so the
    // candlestick chart can draw them around the regular session like the line chart.
    // The target count follows the session length, keeping the zone widths proportional
    // to time even though the candles are laid out by index.
    function sessionCandles(quote, timestamps, period, day, zone) {
        if (!period || !quote || !timestamps) return [];
        var opens = [], highs = [], lows = [], closes = [], volumes = [], times = [];
        for (var i = 0; i < timestamps.length; i++) {
            var t = timestamps[i];
            if (t < period.start || t >= period.end) continue;
            var c = quote.close ? quote.close[i] : null;
            if (c === null || c === undefined) continue;
            closes.push(c);
            opens.push(quote.open && quote.open[i] !== null && quote.open[i] !== undefined ? quote.open[i] : c);
            highs.push(quote.high && quote.high[i] !== null && quote.high[i] !== undefined ? quote.high[i] : c);
            lows.push(quote.low && quote.low[i] !== null && quote.low[i] !== undefined ? quote.low[i] : c);
            volumes.push(quote.volume && quote.volume[i] !== null && quote.volume[i] !== undefined ? quote.volume[i] : 0);
            times.push(t);
        }
        if (closes.length < 2) return [];
        var target = candleTarget("1D");
        if (day && day.regular && day.regular.end > day.regular.start)
            target = Math.max(4, Math.round(target * (period.end - period.start)
                                               / (day.regular.end - day.regular.start)));
        var candles = buildCandles({ values: closes, times: times, opens: opens,
                                     highs: highs, lows: lows, volumes: volumes }, "1D", target);
        for (var c2 = 0; c2 < candles.length; c2++) candles[c2].zone = zone;
        return candles;
    }

    // The candle series for a 1D chart: the regular session plus the pre-market and
    // after-hours sessions around it, each candle tagged with its zone.
    function chartCandlesFor(chart, range, quote, timestamps, day) {
        var regular = buildCandles(chart, range);
        for (var i = 0; i < regular.length; i++) regular[i].zone = "regular";
        if (range !== "1D" || !day || !quote || !timestamps) return regular;
        var pre = day.pre ? sessionCandles(quote, timestamps, day.pre, day, "pre") : [];
        var post = day.post ? sessionCandles(quote, timestamps, day.post, day, "post") : [];
        if (pre.length === 0 && post.length === 0) return regular;
        return pre.concat(regular, post);
    }

    function processPanelData(json, symbol, range) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            root.setMarketSession(symbol, meta);
            var current = meta.regularMarketPrice;
            var curSym = getCurrencySymbol(meta.currency);
            var prev;
            if (range === "1D") {
                prev = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                prev = meta.chartPreviousClose;
                if (!prev || prev === 0) {
                    var quotes = result.indicators.quote[0].close;
                    var timestamps = result.timestamp;
                    var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
                    var cleanData = root.cleanChartData(quotes, timestamps, startTime, range).values;
                    prev = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }
            var change = current - prev;
            root.panelCurrentPrice = curSym + root.formatNumber(current, false);
            root.panelCurrentPercent = root.formatNumber(prev > 0 ? (change / prev) * 100 : 0, true) + "%";
            root.panelCurrentIsPositive = change >= 0;
        } catch (e) { console.log("Error parsing panel quote: " + e); }
    }

    function processSingleData(json, fallbackSymbol, range) {
        try {
            var chartRange = range || root.effectiveChartRange;
            var result = json.chart.result[0];
            var meta = result.meta;
            var symbol = fallbackSymbol || root.singleTicker;
            root.setMarketSession(symbol, meta);
            var quote = result.indicators.quote[0] || {};
            var quotes = quote.close || [];
            var timestamps = result.timestamp;

            root.singleCompanyName = root.companyName(meta, fallbackSymbol || root.singleTicker);
            root.currencySym = getCurrencySymbol(meta.currency);
            root.quoteCurrency = meta.currency || "";
            root.currentRawPrice = meta.regularMarketPrice;
            root.quoteTimestamp = meta.regularMarketTime || 0;
            root.currentPrice = root.currencySym + formatNumber(meta.regularMarketPrice, false);

            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            // The 1D chart plots the running pre-market, or the last completed regular
            // session when there is nothing current to show (see chartDayFor).
            var chartDay = chartRange === "1D" ? root.chartDayFor(meta, timestamps, quotes) : null;
            var preChart = chartRange === "1D" && root.isPreSessionDay(meta, chartDay);
            var day = (chartRange === "1D" && root.showExtendedHours) ? chartDay : null;
            root.chartSessionStart = (chartDay && chartDay.regular) ? chartDay.regular.start : 0;
            // The chart is "current" when it shows today's pre-market or regular session;
            // otherwise it still shows a previous session and the view labels it.
            root.chartSessionCurrent = !(root.chartSessionStart > 0)
                || !(meta.currentTradingPeriod)
                || (meta.currentTradingPeriod.regular && root.chartSessionStart === meta.currentTradingPeriod.regular.start)
                || (meta.currentTradingPeriod.pre && root.chartSessionStart === meta.currentTradingPeriod.pre.start);
            root.chartPreSession = preChart;
            var chart = root.cleanChartData(quotes, timestamps, startTime, chartRange, quote, day);
            if (chartRange === "1D")
                root.seedFirstSessionPoint(chart, (day && day.regular) ? day.regular.start : startTime, meta);
            var cleanData = chart.values;
            root.chartSessions = (day && cleanData.length >= 2) ? root.extendedSessionSeries(quotes, timestamps, day) : null;
            root.chartDataPoints = cleanData;
            root.chartTimestamps = chart.times;

            // The candlestick chart can be drawn from the same response; the reference
            // chart marks yesterday's close, so it reads the same way as the daily change.
            root.chartCandles = root.chartCandlesFor(chart, chartRange, quote, timestamps, day);
            // The pre-market is measured against the last regular close (the official
            // close, as shown in the regular quote); the regular chart uses the close
            // before the session it shows.
            var reference = preChart ? (meta.regularMarketPrice || 0) : 0;
            root.chartReferencePrice = reference > 0 ? reference
                : root.dailyPreviousClose(meta, cleanData.length > 0 ? cleanData[0] : 0);

            // Keep the row's cached chart in sync with every fresh chart, so choosing that
            // row again does not briefly show the older snapshot from the list refresh.
            if (root.isMultiMode && chartRange === root.chartRange) {
                for (var ci = 0; ci < stockModel.count; ci++) {
                    if (stockModel.get(ci).ticker === symbol) {
                        stockModel.set(ci, {
                            "chartPoints": JSON.stringify(cleanData),
                            "chartTimes": JSON.stringify(chart.times),
                            "chartSessions": root.chartSessions,
                            "chartCandles": JSON.stringify(root.chartCandles),
                            "chartRef": root.chartReferencePrice,
                            "chartPre": root.chartPreSession,
                            "chartSessionStart": root.chartSessionStart,
                            "chartSessionCurrent": root.chartSessionCurrent,
                            "quoteTime": root.quoteTimestamp
                        });
                        break;
                    }
                }
            }

            if (chartRange === "1D") {
                root.previousClose = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                root.previousClose = meta.chartPreviousClose;
                if (!root.previousClose || root.previousClose === 0) {
                    root.previousClose = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }

            var change = meta.regularMarketPrice - root.previousClose;
            root.isPositive = change >= 0;
            root.priceChange = formatNumber(change, true);
            root.percentChange = formatNumber((change / root.previousClose) * 100, true) + "%";

            // In single mode this response can also serve the panel when the chart is
            // showing the configured range. When the chart has its own range, a separate
            // panel request supplies these values instead.
            if (!root.isMultiMode && chartRange === root.chartRange) {
                root.panelCurrentPrice = root.currentPrice;
                root.panelCurrentPercent = root.percentChange;
                root.panelCurrentIsPositive = root.isPositive;
            }

            var now = new Date();
            root.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (Plasmoid.configuration.refreshInterval * 60000));
            root.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
        } catch (e) { console.log("Error parsing single: " + e); }
    }

    function processListRow(symbol, json, range) {
        var listRange = range || root.chartRange;
        // When both views use the same range, the chart can reuse this response. With a
        // chart-only range, the chart is refreshed by its own request instead.
        if (root.isMultiMode && symbol === root.panelTicker && listRange === root.effectiveChartRange) {
            processSingleData(json, symbol, listRange);
        }
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            root.setMarketSession(symbol, meta);
            var quote = result.indicators.quote[0] || {};
            var quotes = quote.close || [];
            var timestamps = result.timestamp;

            var current = meta.regularMarketPrice;
            var curSym = getCurrencySymbol(meta.currency);

            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            var chartDay = listRange === "1D" ? root.chartDayFor(meta, timestamps, quotes) : null;
            var preChart = listRange === "1D" && root.isPreSessionDay(meta, chartDay);
            var listDay = (listRange === "1D" && root.showExtendedHours) ? chartDay : null;
            var cleanChart = root.cleanChartData(quotes, timestamps, startTime, listRange, quote, listDay);
            if (listRange === "1D")
                root.seedFirstSessionPoint(cleanChart, (listDay && listDay.regular) ? listDay.regular.start : startTime, meta);
            var cleanData = cleanChart.values;
            var prev;
            if (listRange === "1D") {
                prev = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;
            } else {
                prev = meta.chartPreviousClose;
                if (!prev || prev === 0) {
                    prev = cleanData.length > 0 ? cleanData[0] : meta.regularMarketPreviousClose;
                }
            }
            
            var change = current - prev;
            var pct = prev > 0 ? (change / prev) * 100 : 0;

            // Keep the chart state of the list range with the row, so selecting it can
            // show its graph immediately instead of waiting for another request.
            var chartSessions = (listDay && cleanData.length >= 2)
                                ? root.extendedSessionSeries(quotes, timestamps, listDay) : null;
            var chartCandles = root.chartCandlesFor(cleanChart, listRange, quote, timestamps, listDay);
            var chartRef = preChart ? (meta.regularMarketPrice || 0) : 0;
            if (!(chartRef > 0))
                chartRef = root.dailyPreviousClose(meta, cleanData.length > 0 ? cleanData[0] : 0);
            // The session label shown above the chart travels with the cached chart, so a
            // selection that reuses it does not keep the previous ticker's label.
            var sessionStart = (chartDay && chartDay.regular) ? chartDay.regular.start : 0;
            var sessionCurrent = !(sessionStart > 0)
                || !(meta.currentTradingPeriod)
                || (meta.currentTradingPeriod.regular && sessionStart === meta.currentTradingPeriod.regular.start)
                || (meta.currentTradingPeriod.pre && sessionStart === meta.currentTradingPeriod.pre.start);

            var itemData = {
                "ticker": symbol,
                "name": root.companyName(meta, symbol),
                "price": curSym + formatNumber(current, false),
                "change": formatNumber(change, true),
                "pct": formatNumber(pct, true) + "%",
                "isPos": change >= 0,
                "chartPoints": JSON.stringify(cleanData),
                "chartTimes": JSON.stringify(cleanChart.times),
                "chartSessions": chartSessions,
                "chartCandles": JSON.stringify(chartCandles),
                "chartRef": chartRef,
                "chartPre": preChart,
                "chartSessionStart": sessionStart,
                "chartSessionCurrent": sessionCurrent,
                "quoteTime": meta.regularMarketTime || 0,
                "prevClose": prev,
                "currentRaw": current,
                "currencySym": curSym,
                "currency": meta.currency || ""
            };

            if (root.isMultiMode && symbol === root.panelTicker) {
                root.panelCurrentPrice = itemData.price;
                root.panelCurrentPercent = itemData.pct;
                root.panelCurrentIsPositive = itemData.isPos;
            }

            var found = false;
            for(var k=0; k<stockModel.count; k++) {
                if(stockModel.get(k).ticker === symbol) {
                    stockModel.set(k, itemData);
                    found = true;
                    break;
                }
            }
            if(!found) stockModel.append(itemData);

            var now = new Date();
            root.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (Plasmoid.configuration.refreshInterval * 60000));
            root.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");

        } catch (e) { console.log("Error parsing multi: " + e); }
    }

    function formatNumber(amount, isChange) {
        var num = parseFloat(amount);
        if (isNaN(num)) return amount;
        
        var isPositive = num >= 0;
        var absNum = Math.abs(num);
        
        var hideDecs = root.hideDecimals && !isChange;
        var formatted = hideDecs ? Math.round(absNum).toString() : absNum.toFixed(2);
        
        if (root.formatPrices) {
            var parts = formatted.split(".");
            parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            formatted = parts.join(".");
        }
        
        var sign = "";
        if (isChange && isPositive && num > 0) sign = "+";
        else if (!isPositive) sign = "-";
        
        return sign + formatted;
    }

    onSingleTickerChanged: {
        // In multi mode selecting a row reuses its cached chart; the periodic list
        // refresh keeps that cache current, so no request is needed here. Only the
        // single view needs a refresh when its configured ticker changes.
        if (!root.isMultiMode) root.refreshData();
    }
    onIsMultiModeChanged: {
        stockModel.clear();
        if (!isMultiMode) {
            root.singleTicker = Qt.binding(function() { return Plasmoid.configuration.ticker; });
            root.singleCompanyName = root.loadingText;
            root.currentPrice = "---";
            root.priceChange = "";
            root.percentChange = "";
            root.chartDataPoints = [];
            root.chartTimestamps = [];
            root.chartSessions = null;
            root.chartCandles = [];
            root.chartReferencePrice = 0;
        }
        refreshData();
    }
    onMultiTickersChanged: { stockModel.clear(); refreshData(); }
    onSortAlphabeticallyChanged: { stockModel.clear(); refreshData(); }
    onFormatPricesChanged: refreshData()
    onHideDecimalsChanged: refreshData()
    // CHANGED: Update when the list's configured range changes
    onChartRangeChanged: { stockModel.clear(); refreshData(); }
    // The chart's own range only refreshes the chart, never the list.
    onChartViewRangeChanged: {
        // A value changed outside the chart buttons (backup import, for example).
        if (root.chartViewRangeActive === root.chartViewRange) return;
        root.chartViewRangeActive = root.chartViewRange;
        if (root.showChartRangeButtons && root.singleTicker.trim() !== "")
            root.fetchSingleStock(root.singleTicker, root.effectiveChartRange);
    }
    onShowChartRangeButtonsChanged: {
        if (root.singleTicker.trim() !== "")
            root.fetchSingleStock(root.singleTicker, root.effectiveChartRange);
    }
    // Note: no explicit handler needed when portfolioData changes — both the single-ticker
    // view and the multi-stock list compute their lot P/L directly from root.portfolioData
    // in their bindings, so QML re-evaluates them automatically.

    // --- TOOLTIP ---
    // Plasma's fallback tooltip for an applet is the name and the description from
    // metadata.json ("Plasma Stock Monitor" / "Modernized stock monitor for KDE…"), which says
    // nothing about the stocks. Put the quotes in it instead: the heading names the stock
    // (or the number of stocks) and the body lists the prices and changes, in the
    // same gain/loss colours as the rest of the widget.
    toolTipMainText: root.tooltipTitle
    toolTipSubText: root.tooltipBody
    toolTipTextFormat: Text.RichText

    // ListModel rows do not notify property reads through get(), so the body is bound to
    // this counter and the connections below bump it whenever the model changes.
    property int tooltipRevision: 0

    Connections {
        target: stockModel
        function onDataChanged() { root.tooltipRevision++ }
        function onRowsInserted() { root.tooltipRevision++ }
        function onRowsRemoved() { root.tooltipRevision++ }
        function onModelReset() { root.tooltipRevision++ }
    }

    readonly property string tooltipTitle: {
        if (!root.isMultiMode) {
            var title = root.nameAndTicker(root.singleCompanyName, root.singleTicker);
            return title !== "" ? title : i18n("Plasma Stock Monitor");
        }
        var n = stockModel.count;
        if (n === 0)
            return i18n("Plasma Stock Monitor");
        var count = i18np("%1 stock", "%1 stocks", n);
        return root.lastUpdated !== ""
               ? i18nc("@info:tooltip", "%1 · %2 · updated %3", count, root.rangeLabel(root.chartRange), root.lastUpdated)
               : i18nc("@info:tooltip", "%1 · %2", count, root.rangeLabel(root.chartRange));
    }

    function htmlEscape(value) {
        return String(value === undefined || value === null ? "" : value)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }

    function htmlColor(color) {
        var c = Qt.color(color);
        var channel = function(v) {
            var hex = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16);
            return hex.length < 2 ? "0" + hex : hex;
        };
        return "#" + channel(c.r) + channel(c.g) + channel(c.b);
    }

    // "+1.23 (+0.98%)" in the configured gain/loss colour. No triangle: it looked
    // like the "^" that index tickers start with, and the sign already says which
    // way the value moved.
    function htmlColored(isPos, text) {
        return "<span style=\"color:" + root.htmlColor(isPos ? root.positiveColor : root.negativeColor) + ";\">"
             + root.htmlEscape(text) + "</span>";
    }

    function tooltipChange(isPos, change, pct) {
        return root.htmlColored(isPos, change + " (" + pct + ")");
    }

    // The slice of the stock list the tooltip shows: at most `maxRows` consecutive rows,
    // always including the selected one (the row with the marker) and centred on it when
    // there is room. Returns a half-open [start, end) range.
    function tooltipWindow(count, active, maxRows) {
        var start = 0;
        if (count > maxRows) {
            var focus = active >= 0 ? active : 0;
            start = Math.max(0, Math.min(focus - Math.floor(maxRows / 2), count - maxRows));
        }
        return { start: start, end: Math.min(count, start + maxRows) };
    }

    function buildTooltipBody() {
        // Reading the revision makes the body re-evaluate when the list changes.
        var revision = root.tooltipRevision;
        // The body is a table so the label, price and change columns line up on
        // every row instead of drifting with the length of the values.
        var cell = "padding-left:14px; padding-top:2px; padding-bottom:2px;";
        var labelCell = "padding-top:2px; padding-bottom:2px;";
        var muted = function(text) {
            return "<span style=\"color:" + root.htmlColor(root.secondaryTextColor) + ";\">"
                 + root.htmlEscape(text) + "</span>";
        };

        if (root.isMultiMode) {
            var rows = [];
            // Keep the tooltip compact: a long list would make it taller than the screen.
            // Within that limit the window follows the stock selected in the panel, so its
            // marker stays visible; the rows hidden above and below are counted instead.
            var maxRows = 7;
            var activeRow = -1;
            for (var a = 0; a < stockModel.count; a++) {
                if (stockModel.get(a).ticker === root.panelTicker) { activeRow = a; break; }
            }
            var visible = root.tooltipWindow(stockModel.count, activeRow, maxRows);
            var moreRow = function(hidden, atTop) {
                return "<tr><td></td><td colspan=\"3\" style=\""
                       + (atTop ? "padding-bottom:2px;" : "padding-top:2px;") + "\">"
                       + muted(i18n("… and %1 more", hidden)) + "</td></tr>";
            };
            if (visible.start > 0) rows.push(moreRow(visible.start, true));

            var tickerStyle = "padding-right:16px; padding-top:1px; padding-bottom:1px;";
            for (var i = visible.start; i < visible.end; i++) {
                var row = stockModel.get(i);
                var ext = root.extendedQuote(row.ticker);
                var marker = "<td style=\"padding-right:6px; padding-top:1px; padding-bottom:1px;\">"
                             + (row.ticker === root.panelTicker ? "•" : "") + "</td>";
                var closedMark = (root.showExtendedHours && root.isMarketClosedFor(row.ticker))
                                 ? " " + muted(i18nc("@item:market status", "closed")) : "";
                var tickerCell = "<td style=\"" + tickerStyle + "\"><b>"
                                 + root.htmlEscape(row.ticker) + "</b>" + closedMark + "</td>";
                if (row.price === "---" && !ext) {
                    rows.push("<tr>" + marker + tickerCell
                              + "<td colspan=\"2\" align=\"right\" style=\"padding-top:1px; padding-bottom:1px;\">"
                              + muted(i18n("loading…")) + "</td></tr>");
                    continue;
                }
                rows.push("<tr>" + marker + tickerCell
                          + "<td align=\"right\" style=\"" + tickerStyle + "\">"
                          + root.htmlEscape(ext ? ext.price : row.price) + "</td>"
                          + "<td align=\"right\" style=\"padding-top:1px; padding-bottom:1px;\">"
                          + root.tooltipChange(ext ? ext.isPos : row.isPos,
                                               ext ? ext.change : row.change,
                                               ext ? ext.pct : row.pct) + "</td></tr>");
            }
            if (visible.end < stockModel.count) rows.push(moreRow(stockModel.count - visible.end, false));
            return rows.length > 0
                   ? "<table cellspacing=\"0\" cellpadding=\"0\">" + rows.join("") + "</table>"
                   : i18n("Loading…");
        }

        if (root.currentPrice === "" || root.currentPrice === "---")
            return i18n("Loading…");

        var singleRows = [];
        var period = root.chartPeriodLabel;
        singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(period) + "</td>"
                        + "<td align=\"right\" style=\"" + cell + "\"><b>"
                        + root.htmlEscape(root.currentPrice) + "</b></td>"
                        + "<td align=\"right\" style=\"" + cell + "\">"
                        + root.tooltipChange(root.isPositive, root.priceChange, root.percentChange) + "</td></tr>");

        var ext = root.extendedQuote(root.singleTicker);
        if (ext) {
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(ext.label) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\"><b>"
                            + root.htmlEscape(ext.price) + "</b></td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + root.tooltipChange(ext.isPos, ext.change, ext.pct) + "</td></tr>");
        }
        if (root.showExtendedHours && root.isMarketClosedFor(root.singleTicker)) {
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Session")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + muted(i18n("Market closed")) + "</td></tr>");
        }

        // When the shown ticker is in the portfolio, add the summed position: shares,
        // average cost and the gain against the cost of all its lots.
        if (root.showPortfolioMode && root.hasPortfolioEntry) {
            var p = root.portfolioSummary;
            var pSym = root.getCurrencySymbol(p.currency);
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Position")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + root.htmlEscape(i18np("%1 share · avg %2", "%1 shares · avg %2",
                                                    p.shares,
                                                    root.formatMoney(pSym, p.avgCost, false))) + "</td></tr>");
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("P/L")) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + root.htmlColored(p.plIsPos, root.formatMoney(pSym, p.plValue, true)) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + root.htmlColored(p.plIsPos, root.formatNumber(p.plPercent, true) + "%") + "</td></tr>");
        }

        if (root.lastUpdated !== "")
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Updated")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + root.htmlEscape(root.lastUpdated) + "</td></tr>");

        return "<table cellspacing=\"0\" cellpadding=\"0\">" + singleRows.join("") + "</table>";
    }

    readonly property string tooltipBody: root.buildTooltipBody()

    ListModel { id: stockModel }

    // Optionally show the price and the change percentage in the same spot of
    // the panel indicator, switching between them every N seconds, instead of
    // showing both side by side.
    readonly property bool panelAlternate: Plasmoid.configuration.alternatePricePercent
                                           && !root.hideChangePercentage
                                           && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    // The expanded panel view normally lives in Plasma's popup, whose background is drawn
    // by the shell. Turning the option off uses a popup of our own with no background, so
    // only the widget cards remain visible.
    readonly property bool expandedViewBackground: Plasmoid.configuration.expandedViewBackground
    // Our own panel popup has no Plasma background behind the cards, so in Plasma-theme
    // mode the views must paint a card background themselves instead of staying transparent.
    readonly property bool customExpandedCard: !expandedViewBackground
                                            && (Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                                || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
    readonly property color customExpandedCardColor: root.isPlasmaTheme
        ? Qt.rgba(Kirigami.Theme.backgroundColor.r,
                  Kirigami.Theme.backgroundColor.g,
                  Kirigami.Theme.backgroundColor.b,
                  root.bgOpacity / 100)
        : root.bgColor
    property bool panelShowPercent: false

    Timer {
        interval: Math.max(3, Plasmoid.configuration.alternateInterval) * 1000
        running: root.panelAlternate
        repeat: true
        onTriggered: root.panelShowPercent = !root.panelShowPercent
        onRunningChanged: if (!running) root.panelShowPercent = false
    }

    Timer {
        interval: Plasmoid.configuration.refreshInterval * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        // CHANGED: Call checkTimeAndRefresh instead of refreshData directly
        onTriggered: root.checkTimeAndRefresh()
    }

    // Exchange rates change once a day. Checking hourly keeps the download close to the
    // feed's own daily update without polling it repeatedly; the cached rates are only
    // replaced when a complete response arrives.
    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.maybeRefreshExchangeRates()
    }

    // Optionally rotate the panel stock every N seconds (multi-stock mode).
    // The panel text is filled from the already-fetched list data; a single
    // request then refreshes the chart for the newly selected stock.
    Timer {
        interval: Math.max(3, Plasmoid.configuration.autoCycleInterval) * 1000
        // Pause while the full view is open, so the stock does not change under the user.
        running: Plasmoid.configuration.autoCycle && root.isMultiMode && stockModel.count > 1
                 && !root.expanded
        repeat: true
        onTriggered: {
            var current = 0;
            for (var i = 0; i < stockModel.count; i++) {
                if (stockModel.get(i).ticker === root.panelTicker) { current = i; break; }
            }
            var row = stockModel.get((current + 1) % stockModel.count);
            // The panel takes the cached list row; only the chart is fetched.
            // Auto-cycling is not a user selection, so do not persist it.
            root.selectTicker(row.ticker, false);
        }
    }

    // Open the expanded panel view in Plasma's popup (with its background) or in our own
    // popup, which draws no background and therefore shows only the widget's cards.
    function togglePanelPopup() {
        if (root.expandedViewBackground) {
            root.expanded = !root.expanded;
            return;
        }

        if (!panelPopupWindowLoader.item)
            panelPopupWindowLoader.active = true;

        var popup = panelPopupWindowLoader.item;
        if (!popup)
            return;

        if (popup.visible)
            popup.visible = false;
        else if (!root.panelPopupRecentlyClosed)
            popup.visible = true;
    }

    // The dialog hides itself when it loses focus. That is what a click on the panel
    // widget does, so ignore that same click briefly instead of reopening the popup.
    property bool panelPopupRecentlyClosed: false
    Timer {
        id: panelPopupCloseGuard
        interval: 250
        onTriggered: root.panelPopupRecentlyClosed = false
    }

    onExpandedViewBackgroundChanged: {
        // Close the mode that is no longer selected, so changing the option takes effect
        // immediately instead of leaving the old popup on screen.
        if (root.expandedViewBackground) {
            if (panelPopupWindowLoader.item)
                panelPopupWindowLoader.item.visible = false;
            panelPopupWindowLoader.active = false;
        } else {
            root.expanded = false;
        }
    }

    // --- PANEL VIEW (Compact Representation) ---
    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: {
            // An explicit width from the settings wins. Otherwise reserve room for the widest value.
            if (compactRoot.useFixedWidth && Plasmoid.configuration.panelWidth > 0)
                return Plasmoid.configuration.panelWidth;
            var content = compactRoot.useFixedWidth
                          ? Math.max(compactRoot.widestContent, panelRow.implicitWidth)
                          : panelRow.implicitWidth;
            return content + (Kirigami.Units.smallSpacing * 4);
        }
        // Never paint outside the rectangle the panel gives the applet. In a vertical
        // panel that rectangle is only as wide as the panel, so the content has to fit
        // (or elide) rather than spill over the neighbouring applets.
        clip: true
        implicitHeight: panelRow.implicitHeight
        width: implicitWidth
        height: implicitHeight
        
        // Essential for Plasma to allocate space and prevent overlap
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        // Scroll wheel / touchpad scroll cycles the stock shown in the panel.
        // Scroll up = previous stock, scroll down = next stock. Deltas are
        // accumulated so smooth-scrolling touchpads advance one step per 120 units.
        property real wheelAccum: 0
        onWheel: (wheel) => {
            if (!root.isMultiMode || stockModel.count < 2) {
                wheel.accepted = false;
                return;
            }
            wheelAccum += wheel.angleDelta.y;
            var steps = 0;
            while (wheelAccum >= 120) { steps -= 1; wheelAccum -= 120; }
            while (wheelAccum <= -120) { steps += 1; wheelAccum += 120; }
            if (steps === 0) return;

            var current = 0;
            for (var i = 0; i < stockModel.count; i++) {
                if (stockModel.get(i).ticker === root.panelTicker) { current = i; break; }
            }
            var n = stockModel.count;
            var next = (((current + steps) % n) + n) % n;
            var row = stockModel.get(next);
            root.selectTicker(row.ticker);
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.performMiddleClick(root.panelSymbol)) {
                    // Visual feedback for a refresh; open/none need no flicker.
                    if (panelPrice) panelPrice.opacity = 0.3;
                    timerFlicker.restart();
                }
            } else {
                root.togglePanelPopup();
            }
        }

        Timer {
            id: timerFlicker
            interval: 300
            onTriggered: if (panelPrice) panelPrice.opacity = 1.0;
        }

        // While an extended-hours session is running, the ticker has a pre-market /
        // after-hours quote (see extendedQuote()). The panel then shows that quote
        // instead of the regular price and change, and a small tag next to the ticker
        // says which session it is. Without an extended quote, the tag says CLOSED
        // while the market is closed.
        readonly property var ext: root.extendedQuote(root.panelSymbol)
        readonly property bool marketClosed: root.showExtendedHours
                                             && root.isMarketClosedFor(root.panelSymbol)
        readonly property string shownPrice: ext ? ext.price : root.panelCurrentPrice
        readonly property string shownPercent: ext ? ext.pct : root.panelCurrentPercent
        readonly property bool shownPositive: ext ? ext.isPos : root.panelCurrentIsPositive

        // --- Fixed width ---
        // Cycling through the stocks, or swapping price and percentage, changes the length of the
        // text. That used to resize the indicator and push every other applet in the panel around.
        // With a fixed width the indicator reserves room for the widest value that can appear in
        // it: the longest ticker, price and change of any configured stock, in the regular and
        // in the extended-hours session. The width then stays the same while values change.
        readonly property bool useFixedWidth: Plasmoid.configuration.fixedPanelWidth
                                              && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        property real widestContent: 0
        property real widestPrice: 0

        // Invisible texts with exactly the fonts and rendering of the visible ones. Measuring with
        // these instead of with font metrics gives the real width, hinting included.
        property real widestBadge: 0
        Text { id: probeTicker; visible: false; font.pixelSize: 9; font.weight: Font.Bold; renderType: Text.NativeRendering }
        Text { id: probeTag; visible: false; font.pixelSize: 8; font.weight: Font.Bold; renderType: Text.NativeRendering }
        Text { id: probePrice; visible: false; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.NativeRendering }
        Text { id: probeBadge; visible: false; font.pixelSize: 10; font.weight: Font.Black; renderType: Text.NativeRendering }

        function measureWidest() {
            var tickers = [], prices = [], pcts = [];
            var collect = function(ticker, price, pct) {
                tickers.push(String(ticker || "").toUpperCase());
                prices.push(String(price || ""));
                pcts.push(String(pct || ""));
                var e = root.extendedQuote(ticker);
                if (e) { prices.push(e.price); pcts.push(e.pct); }
            };
            if (root.isMultiMode) {
                for (var i = 0; i < stockModel.count; i++) {
                    var row = stockModel.get(i);
                    collect(row.ticker, row.price, row.pct);
                }
            } else {
                collect(root.panelSymbol, root.panelCurrentPrice, root.panelCurrentPercent);
            }
            // Width of the widest of `list` when drawn by `probe`.
            // Each piece is rounded up to whole pixels, as the layout does for every item;
            // adding unrounded widths would come out a pixel short.
            var widest = function(list, probe) {
                var w = 0;
                for (var j = 0; j < list.length; j++) {
                    probe.text = list[j];
                    w = Math.max(w, Math.ceil(probe.implicitWidth));
                }
                return w;
            };
            var widthOf = function(probe, text) { probe.text = text; return Math.ceil(probe.implicitWidth); };

            // First line: ticker, arrow and, if extended hours are shown, the session tag.
            var arrowW = Math.max(widthOf(probeTag, "▲"), widthOf(probeTag, "▼"));
            // Measured from the same (translated) tags the panel shows, so a longer
            // translation still fits in the reserved width.
            var tagW = root.showExtendedHours
                       ? Math.max(widthOf(probeTag, root.tagAfterHours),
                                  widthOf(probeTag, root.tagPreMarket),
                                  widthOf(probeTag, root.tagClosed))
                       : 0;
            var line1 = widest(tickers, probeTicker) + 4 + arrowW + (tagW > 0 ? 4 + tagW : 0);

            // Second line: price and change badge (or the wider of the two when they alternate).
            var priceW = widest(prices, probePrice);
            var showBadge = !root.hideChangePercentage;
            var badgeW = showBadge ? widest(pcts, probeBadge) + (Kirigami.Units.smallSpacing * 2) : 0;
            var line2 = (root.panelAlternate && showBadge) ? Math.max(priceW, badgeW)
                                                          : priceW + (showBadge ? 6 + badgeW : 0);
            return { "content": Math.ceil(Math.max(line1, line2)),
                     "price": Math.ceil(priceW),
                     "badge": Math.ceil(badgeW) };
        }

        function remeasure() {
            var m = measureWidest();
            compactRoot.widestContent = m.content;
            compactRoot.widestPrice = m.price;
            compactRoot.widestBadge = m.badge;
        }

        // Values arrive in bursts (one reply per ticker), so measure once they settle.
        Timer { id: remeasureTimer; interval: 100; onTriggered: compactRoot.remeasure() }
        Component.onCompleted: compactRoot.remeasure()
        Connections {
            target: stockModel
            function onDataChanged() { remeasureTimer.restart(); }
            function onRowsInserted() { remeasureTimer.restart(); }
            function onRowsRemoved() { remeasureTimer.restart(); }
            function onModelReset() { remeasureTimer.restart(); }
        }
        Connections {
            target: root
            function onExtendedDataChanged() { remeasureTimer.restart(); }
            function onPanelCurrentPriceChanged() { remeasureTimer.restart(); }
            function onPanelCurrentPercentChanged() { remeasureTimer.restart(); }
            function onSingleTickerChanged() { remeasureTimer.restart(); }
            function onIsMultiModeChanged() { remeasureTimer.restart(); }
            function onShowExtendedHoursChanged() { remeasureTimer.restart(); }
            function onHideChangePercentageChanged() { remeasureTimer.restart(); }
            function onPanelAlternateChanged() { remeasureTimer.restart(); }
        }

        RowLayout {
            id: panelRow
            // Fixed width: start at the left edge so the ticker stays where it is while the
            // values change. In a vertical panel the row fills the panel thickness and the
            // labels are centred/elided inside it. Otherwise centre the content, as before.
            anchors.centerIn: (!compactRoot.useFixedWidth && !root.isVerticalPanel) ? parent : undefined
            anchors.verticalCenter: (compactRoot.useFixedWidth || root.isVerticalPanel) ? parent.verticalCenter : undefined
            anchors.left: (compactRoot.useFixedWidth || root.isVerticalPanel) ? parent.left : undefined
            anchors.right: root.isVerticalPanel ? parent.right : undefined
            anchors.leftMargin: root.isVerticalPanel ? 0 : Kirigami.Units.smallSpacing * 2
            anchors.rightMargin: 0
            spacing: 8
            
            ColumnLayout {
                spacing: -2
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: root.isVerticalPanel

                RowLayout {
                    spacing: 4
                    Layout.fillWidth: root.isVerticalPanel
                    Text {
                        text: (root.isMultiMode ? root.panelTicker : root.singleTicker).toUpperCase()
                        color:  Kirigami.Theme.textColor
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                        opacity: 0.6
                        Layout.alignment: Qt.AlignBottom
                        Layout.fillWidth: root.isVerticalPanel
                        horizontalAlignment: root.isVerticalPanel ? Text.AlignHCenter : Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    // In a vertical panel only the ticker and the price fit in the panel
                    // thickness; the colour already shows the direction and the tooltip
                    // carries the session tag.
                    Text {
                        visible: !root.isVerticalPanel
                        text: compactRoot.shownPositive ? "▲" : "▼"
                        color: compactRoot.shownPositive ? root.positiveColor : root.negativeColor
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                    // Session tag: AH = after-hours, PRE = pre-market, CLOSED = the
                    // exchange is not trading and there is no extended quote to show.
                    Text {
                        visible: (compactRoot.ext !== undefined || compactRoot.marketClosed) && !root.isVerticalPanel
                        text: compactRoot.marketClosed
                              ? root.tagClosed
                              : (compactRoot.ext
                                 ? (compactRoot.ext.kind === "pre" ? root.tagPreMarket : root.tagAfterHours)
                                 : "")
                        color: Kirigami.Theme.textColor
                        opacity: 0.6
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                    }
                }

                RowLayout {
                    spacing: 6
                    Layout.alignment: root.isVerticalPanel ? Qt.AlignHCenter : Qt.AlignLeft
                    Layout.fillWidth: root.isVerticalPanel
                    
                    Text {
                        id: panelPrice
                        // The currency symbol does not fit in the panel thickness together
                        // with a five-digit price, and the ticker already identifies the
                        // instrument; the tooltip shows the full value.
                        text: {
                            var price = compactRoot.shownPrice;
                            return root.isVerticalPanel && root.currencySym !== ""
                                   ? price.replace(root.currencySym, "")
                                   : price;
                        }
                        // When alternating, the price and the percentage badge share one spot:
                        // this item is hidden while the percentage is shown, and both keep the
                        // width of the wider one so the panel does not resize on every switch.
                        visible: !root.panelAlternate || !root.panelShowPercent
                        horizontalAlignment: root.isVerticalPanel
                                             ? Text.AlignHCenter
                                             : (root.panelAlternate ? Text.AlignHCenter : Text.AlignLeft)
                        // Fixed width: give the price the width of the widest price, so the badge
                        // next to it stays put while the price changes.
                        Layout.minimumWidth: root.panelAlternate
                                             ? Math.max(panelPrice.implicitWidth, pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2))
                                             : (compactRoot.useFixedWidth ? compactRoot.widestPrice : 0)
                        Layout.fillWidth: root.isVerticalPanel
                        elide: Text.ElideRight
                        color: compactRoot.shownPositive ? root.positiveColor : root.negativeColor
                        font.pixelSize: root.isVerticalPanel
                                         ? (compactRoot.shownPrice.length > 7 ? 8 : 9)
                                         : 11
                        font.weight: Font.Bold
                        renderType: Text.NativeRendering
                        // Ensure the price text is fully opaque; color is controlled by the line above
                        opacity: 1.0
                    }

                    Rectangle {
                        radius: 4
                        // Vertical Panel Support: Hide badge in vertical panels to avoid overlap
                        visible: Plasmoid.formFactor !== PlasmaCore.Types.Vertical && !root.hideChangePercentage
                                 && (!root.panelAlternate || root.panelShowPercent)
                        // Background: translucent tint of the positive/negative color for theme independence
                        color: compactRoot.shownPositive
                               ? Qt.rgba(root.positiveColor.r, root.positiveColor.g, root.positiveColor.b, 0.18)
                               : Qt.rgba(root.negativeColor.r, root.negativeColor.g, root.negativeColor.b, 0.18)
                        border.color: compactRoot.shownPositive ? root.positiveColor : root.negativeColor
                        border.width: 1
                        Layout.preferredWidth: pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                        // Fixed width: every value gets the same badge width (the text stays centred),
                        // so the panel has no spare room on the right of a short value.
                        Layout.minimumWidth: root.panelAlternate
                                             ? Math.max(panelPrice.implicitWidth, pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2))
                                             : (compactRoot.useFixedWidth ? compactRoot.widestBadge : 0)
                        Layout.preferredHeight: pctText2.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                        
                        Text {
                            id: pctText2
                            anchors.centerIn: parent
                            text: compactRoot.shownPercent
                            color: compactRoot.shownPositive ? root.positiveColor : root.negativeColor
                            font.pixelSize: 10
                            font.weight: Font.Black
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }

    // --- FULL VIEW (desktop widget and the panel expanded popup) ---

    Component {
        id: fullViewComponent

        Item {
            id: fullRoot

            // Desktop only: the panel uses compactRepresentation, whose size is unchanged.
            // Two columns only in multi mode with the side-by-side list.
            readonly property bool twoColumns: root.isMultiMode && root.showTwoList
            // Width of the drag zone between the two columns, including its visual line.
            readonly property int dividerWidth: root.isPlasmaTheme ? 8 : 10
            // A stored width of 0 keeps the automatic layout: both columns share the card.
            readonly property bool manualSplit: twoColumns && root.twoColumnLeftWidth > 0
            // The stored width can be too large for the current widget width; clamp it so the
            // list keeps its own minimum.
            readonly property real maxLeftColumnWidth: Math.max(singleColumn.minimumContentWidth,
                fullRow.width - dividerWidth - listColumn.minimumContentWidth)
            readonly property real leftColumnWidth: Math.max(singleColumn.minimumContentWidth,
                Math.min(root.twoColumnLeftWidth, maxLeftColumnWidth))

            Layout.minimumWidth: twoColumns
                ? singleColumn.minimumContentWidth + dividerWidth + listColumn.minimumContentWidth
                : (root.isMultiMode ? listColumn.minimumContentWidth : singleColumn.minimumContentWidth)
            Layout.minimumHeight: twoColumns
                ? Math.max(singleColumn.minimumContentHeight, listColumn.minimumContentHeight)
                : (root.isMultiMode ? listColumn.minimumContentHeight : singleColumn.minimumContentHeight)
            // Stable defaults for Plasma when there is no saved geometry yet (a new
            // activity or an empty virtual desktop). Without these, the preferred size
            // falls back to the minimum and the widget opens at its smallest size.
            Layout.preferredWidth: twoColumns ? 960 : 600
            Layout.preferredHeight: 520

            RowLayout {
                id: fullRow
                anchors.fill: parent
                anchors.margins: 0
                spacing: 0

                SingleStockView {
                    id: singleColumn
                    visible: !root.isMultiMode || root.showTwoList
                    Layout.fillWidth: !fullRoot.manualSplit
                    Layout.preferredWidth: fullRoot.manualSplit ? fullRoot.leftColumnWidth : 0
                    Layout.fillHeight: true
                    Layout.minimumWidth: singleColumn.minimumContentWidth
                    Layout.minimumHeight: singleColumn.minimumContentHeight
                    rootItem: root
                }

                Item {
                    id: divider
                    objectName: "columnDivider"
                    visible: fullRoot.twoColumns
                    Layout.preferredWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
                    Layout.minimumWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
                    Layout.maximumWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
                    Layout.fillHeight: true
                    z: 1

                    Rectangle {
                        anchors.centerIn: parent
                        width: 2
                        height: Math.min(parent.height, 40)
                        radius: 1
                        color: root.tickerColor
                        // The divider is invisible until the pointer enters its (wider) hit area.
                        opacity: dividerMouse.containsMouse || dividerMouse.pressed ? 0.9 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: dividerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SplitHCursor
                        preventStealing: true

                        property real pressX: 0
                        property real pressWidth: 0

                        onPressed: {
                            pressX = mapToItem(fullRow, mouse.x, mouse.y).x;
                            pressWidth = singleColumn.width;
                        }
                        onPositionChanged: {
                            if (!pressed) return;
                            var dx = mapToItem(fullRow, mouse.x, mouse.y).x - pressX;
                            var minLeft = singleColumn.minimumContentWidth;
                            var maxLeft = Math.max(minLeft,
                                fullRow.width - fullRoot.dividerWidth - listColumn.minimumContentWidth);
                            root.setTwoColumnLeftWidth(Math.max(minLeft,
                                Math.min(maxLeft, pressWidth + dx)));
                        }
                        onReleased: root.saveTwoColumnLeftWidth()
                        onCanceled: root.saveTwoColumnLeftWidth()
                    }
                }

                MultiStockView {
                    id: listColumn
                    visible: root.isMultiMode
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: listColumn.minimumContentWidth
                    Layout.minimumHeight: listColumn.minimumContentHeight
                    rootItem: root
                    listModel: stockModel
                }
            }
        }
    }

    // Assign after the component has been declared, so Plasma never sees a null full
    // representation during initialisation on older Plasma versions.
    fullRepresentation: fullViewComponent

    // Plasma always draws the frame of the popup it creates for an expanded panel applet.
    // When the user disables that background, show the same full view in our own popup
    // with no background instead, so only the two widget cards remain visible.
    //
    // The dialog is created on demand: with the default setting the applet never
    // instantiates it, which also keeps older Plasma versions safe at startup.
    Loader {
        id: panelPopupWindowLoader
        active: false
        sourceComponent: panelPopupComponent
    }

    Component {
        id: panelPopupComponent

        PlasmaCore.Dialog {
            id: panelPopup
            objectName: "panelPopup"

            type: PlasmaCore.Dialog.AppletPopup
            location: Plasmoid.location
            visible: false
            visualParent: root.compactRepresentationItem
            appletInterface: root
            backgroundHints: PlasmaCore.Dialog.NoBackground
            hideOnWindowDeactivate: true

            onVisibleChanged: {
                if (visible) {
                    Qt.callLater(function() { panelPopupFocus.forceActiveFocus(); });
                } else {
                    root.panelPopupRecentlyClosed = true;
                    panelPopupCloseGuard.restart();
                }
            }

            mainItem: FocusScope {
                id: panelPopupFocus
                focus: true

                Keys.onEscapePressed: panelPopup.visible = false

                // Mirror the full view's size hints so the dialog sizes itself exactly like
                // Plasma's standard expanded representation does.
                Layout.minimumWidth: panelPopupLoader.item ? panelPopupLoader.item.Layout.minimumWidth : 0
                Layout.minimumHeight: panelPopupLoader.item ? panelPopupLoader.item.Layout.minimumHeight : 0
                Layout.preferredWidth: panelPopupLoader.item ? Math.max(panelPopupLoader.item.Layout.preferredWidth,
                                                                         panelPopupLoader.item.Layout.minimumWidth) : 0
                Layout.preferredHeight: panelPopupLoader.item ? Math.max(panelPopupLoader.item.Layout.preferredHeight,
                                                                          panelPopupLoader.item.Layout.minimumHeight) : 0

                Loader {
                    id: panelPopupLoader
                    anchors.fill: parent
                    // Do not instantiate a second copy of the full view unless the custom
                    // panel popup is actually in use.
                    active: root.customExpandedCard
                    sourceComponent: fullViewComponent
                }

                // The no-background dialog has no theme frame, so Dialog's own resize
                // margins are zero. These invisible handles start the same system resize
                // that the standard Plasma popup uses.
                MouseArea {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 6
                    cursorShape: Qt.SizeVerCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 6
                    cursorShape: Qt.SizeVerCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge)
                }

                MouseArea {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: panelPopup.startSystemResize(Qt.LeftEdge)
                }

                MouseArea {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 6
                    cursorShape: Qt.SizeHorCursor
                    onPressed: panelPopup.startSystemResize(Qt.RightEdge)
                }

                MouseArea {
                    anchors { top: parent.top; left: parent.left }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
                }

                MouseArea {
                    anchors { top: parent.top; right: parent.right }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.TopEdge | Qt.RightEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; left: parent.left }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeBDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
                }

                MouseArea {
                    anchors { bottom: parent.bottom; right: parent.right }
                    width: 8
                    height: 8
                    cursorShape: Qt.SizeFDiagCursor
                    onPressed: panelPopup.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
                }
            }
        }
    }
}
