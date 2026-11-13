import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "currencies.js" as Currency
import "chartdata.js" as ChartData
import "portfolio.js" as Portfolio
import "exchanges.js" as Exchanges
import "news.js" as News
import "bvbnews.js" as BvbNews

PlasmoidItem {
    id: root

    // --- CONFIGURATION ---
    // The compact panel indicator is always transparent over the panel. On the desktop,
    // Plasma leaves the background to the system, while Application paints the cards.
    Plasmoid.backgroundHints: !root.inPanel && root.usesPlasmaSurface
        ? PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
        : PlasmaCore.Types.NoBackground
    // Detect where we are (Panel vs Desktop) to switch views
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical) ? root.compactRepresentation : root.fullRepresentation

    // The applet container reads its size constraints from this root item, not from the
    // full-view component. The full view updates these when its mode or minimum changes,
    // so switching from a minimum-sized list to the graph can grow the applet to the
    // graph's minimum instead of leaving the chart clipped inside a smaller card.
    // In a panel the compact representation owns the size: forcing the full-view
    // minimum here widened the panel applet to the graph's minimum and left the compact
    // contents stranded at its left edge. Mirror the compact item's implicit size
    // instead; the full-view hints apply only outside a panel.
    readonly property var panelItem: root.compactRepresentationItem
    readonly property real panelItemWidth: root.panelItem ? root.panelItem.implicitWidth : -1
    readonly property real panelItemHeight: root.panelItem ? root.panelItem.implicitHeight : -1
    property real fullViewMinimumWidth: 322
    property real fullViewMinimumHeight: 360
    property real fullViewPreferredWidth: 600
    property real fullViewPreferredHeight: 520
    Layout.minimumWidth: !root.inPanel ? root.fullViewMinimumWidth
                        : (root.isVerticalPanel ? 0 : root.panelItemWidth)
    Layout.minimumHeight: !root.inPanel ? root.fullViewMinimumHeight
                         : (root.isVerticalPanel ? root.panelItemHeight : 0)
    Layout.preferredWidth: !root.inPanel ? root.fullViewPreferredWidth : root.panelItemWidth
    Layout.preferredHeight: !root.inPanel ? root.fullViewPreferredHeight : root.panelItemHeight

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
    // 0 = the full Yahoo Finance symbol (BRD.RO), 1 = the base symbol (BRD),
    // 2 = the base symbol with a short exchange badge (BRD · BVB).
    readonly property int symbolDisplayMode: {
        var mode = Number(Plasmoid.configuration.symbolDisplayMode);
        return mode >= 0 && mode <= 2 ? mode : 0;
    }
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

    // What the widget shows for a ticker. The stored symbol always stays the full Yahoo
    // one: it is the key for quote requests, portfolio lots and the selected row.
    function displayTicker(ticker) {
        var clean = Exchanges.upper(ticker);
        return root.symbolDisplayMode === 0 ? clean : Exchanges.baseSymbol(clean);
    }

    // Short exchange label for the badge, or "" when badges are off, the symbol has no
    // exchange suffix, or no exchange is known. A plain US ticker has no suffix to
    // replace, so it does not need a badge.
    function exchangeBadge(ticker, exchange) {
        if (root.symbolDisplayMode !== 2 || !Exchanges.hasSuffix(ticker)) return "";
        var label = String(exchange === undefined || exchange === null ? "" : exchange).trim();
        return label !== "" ? label : Exchanges.shortLabel(ticker, "", "");
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
    // Exchange of the single-view symbol: short label (BVB) and Yahoo's full name
    // (Bucharest Stock Exchange). Kept apart from the ticker for display only.
    property string singleExchange: ""
    property string singleExchangeFull: ""
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
    // --- THEME ---
    // The background has two independent choices: a preset that applies to both the
    // desktop and the panel, or a per-context source under Custom. The colors are a
    // separate choice so the cards the widget draws always have a readable palette.
    //
    // Preset: 0 = Application, 1 = Plasma. Fresh placements default to Plasma;
    // -1 is only the "not migrated yet" sentinel.
    readonly property int themePreset: Plasmoid.configuration.themePreset === 0 ? 0 : 1
    // Colors: 0 = Light, 1 = Dark, 2 = System. They apply to the Application preset;
    // Plasma always follows the system colors.
    readonly property int themeColors: Plasmoid.configuration.themeColors === 0 ? 0
                                      : (Plasmoid.configuration.themeColors === 1 ? 1 : 2)
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                    || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Plasma follows the system background and colors; Application draws its own cards.
    readonly property bool usesPlasmaSurface: themePreset === 1
    readonly property bool appDrawnSurface: themePreset === 0
    // Light/dark detection for the Application System color choice. Kirigami follows
    // the Plasma color scheme, so this updates when the system theme changes.
    readonly property bool systemLightColors: Kirigami.Theme.backgroundColor.hslLightness > 0.5
    readonly property bool appLightPalette: themeColors === 0 || (themeColors === 2 && systemLightColors)
    // Effective lightness of the surface currently on screen. The chart and the views
    // use it for their own light/dark details.
    property bool isLightTheme: root.usesPlasmaSurface ? root.systemLightColors : root.appLightPalette
    // The panel indicator always uses the panel's own palette, independent of the
    // widget theme, so it looks the same whichever background/colors are selected.
    readonly property color panelTextColor: Kirigami.Theme.textColor
    readonly property color panelPositiveColor: root.withContrast(Plasmoid.configuration.positiveColor, Kirigami.Theme.backgroundColor)
    readonly property color panelNegativeColor: root.withContrast(Plasmoid.configuration.negativeColor, Kirigami.Theme.backgroundColor)
    // A vertical panel constrains the applet to the panel thickness, so the compact
    // view has to fit (and elide) inside that width instead of using the content width.
    readonly property bool isVerticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Colour the gain/loss text is measured against: the base colour of the widget's
    // own cards, otherwise the Plasma surface.
    property color contrastBackground: root.usesPlasmaSurface
        ? Kirigami.Theme.backgroundColor
        : (root.appLightPalette ? "#ffffff" : "#1a1a1a")
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
    // 0 = reference line split at the session open, 1 = candlesticks.
    property int chartStyle: Plasmoid.configuration.chartStyle === 1 ? 1 : 0
    // 0 = smooth line, 1 = straight segments.
    property int chartLineStyle: Plasmoid.configuration.chartLineStyle === 1 ? 1 : 0
    // Show the Line/Candles toggle in the chart.
    property bool showChartStyleButtons: Plasmoid.configuration.showChartStyleButtons
    // Volume is opt-in and is drawn for both chart styles.
    property bool showChartVolume: Plasmoid.configuration.showChartVolume
    // Analyst price-target markers under the chart, also opt-in.
    property bool showAnalystTargets: Plasmoid.configuration.showAnalystTargets
    property bool showChartHover: Plasmoid.configuration.showChartHover
    // Latest news headlines for the single-stock view (the Chart/News icons in its header).
    property bool showNews: Plasmoid.configuration.showNews
    property bool newsSourceYahoo: Plasmoid.configuration.newsSourceYahoo
    property bool newsSourceBvb: Plasmoid.configuration.newsSourceBvb
    property int newsCount: Plasmoid.configuration.newsCount
    property int newsRefreshMinutes: Plasmoid.configuration.newsRefreshMinutes
    // "chart" or "news": what the single-stock view shows below the quote. Not persisted:
    // the widget always starts on the chart, so a login never fetches news.
    property string singleViewPane: "chart"
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
    // The range and ticker the current single-view numbers were fetched for (empty while
    // they are placeholders). The cache stores change/percentage per range, so a save
    // that races a ticker or range change must not label old values as the new ones.
    property string singleDataRange: ""
    property string singleDataTicker: ""
    // The last successful quote batch, persisted in the applet config. At login Plasma
    // can start the widget before the network (or a VPN) is up; showing the previous
    // values with their real timestamp keeps the widget useful as long as they are
    // never presented as live prices.
    property double cachedQuotesTime: Number(Plasmoid.configuration.cachedQuotesTime) || 0
    // True while the list (or, in single mode, the whole view) still shows cached values.
    property bool showingCachedData: false
    // Whether the values in the panel indicator come from the snapshot. In multi mode one
    // row can still be cached while another is already live, so the panel marks its own
    // ticker instead of trusting the list-wide flag.
    property bool panelCurrentIsCached: false
    property var cachedQuotesSnapshot: null
    readonly property string cachedQuotesLabel: root.cachedQuotesTime > 0
        ? new Date(root.cachedQuotesTime * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
        : ""
    // One status line for the list and the tooltip: the cached state replaces the usual
    // "Updated … Next …" so the age of the data is never hidden.
    readonly property string updateStatusText: root.showingCachedData
        ? i18n("Cached data from %1", root.cachedQuotesLabel)
        : (root.lastUpdated !== "" && root.nextUpdate !== ""
           ? i18n("Updated: %1 • Next: %2", root.lastUpdated, root.nextUpdate) : "")
    // The single view can show a live row while another list row is still cached, so its
    // line follows its own ticker rather than the list-wide state.
    readonly property bool currentShowingCached: !root.showingCachedData ? false
        : (!root.isMultiMode || root.rowIsCached(root.panelSymbol))
    readonly property string currentStatusText: root.currentShowingCached
        ? i18n("Cached data from %1", root.cachedQuotesLabel)
        : (root.lastUpdated !== "" && root.nextUpdate !== ""
           ? i18n("Updated: %1 • Next: %2", root.lastUpdated, root.nextUpdate) : "")
    // Amber that stays readable on light and dark cards, used while data is cached.
    readonly property color warningTextColor: root.isLightTheme ? "#8a5a00" : "#e0b25a"
    property color bgColor: getThemeColor("background")
    property color chartBaseColor: getThemeColor("chart")
    property color secondaryTextColor: getThemeColor("text")

    function getThemeColor(what) {
        if (what === "ticker") {
            if (root.usesPlasmaSurface)
                return Kirigami.Theme.textColor;

            return Qt.colorEqual(Plasmoid.configuration.tickerColor, "#ffffff") && root.appLightPalette ? "#000000" : Plasmoid.configuration.tickerColor;
        } else if (what === "price") {
            if (root.usesPlasmaSurface)
                return Kirigami.Theme.textColor;

            return Qt.colorEqual(Plasmoid.configuration.priceColor, "#ffffff") && root.appLightPalette ? "#000000" : Plasmoid.configuration.priceColor;
        } else if (what === "background") {
            // Plasma paints the surface behind the views, or the full view draws the
            // single forced light/dark Plasma-style surface instead.
            if (root.usesPlasmaSurface)
                return "transparent";

            const c = Qt.color(root.appLightPalette ? "#ffffff" : "#1a1a1a");
            return Qt.rgba(c.r, c.g, c.b, root.bgOpacity / 100);
        } else if (what === "chart") {
            if (root.usesPlasmaSurface)
                return Kirigami.Theme.disabledTextColor;
            return root.appLightPalette ? "#e0e0e0" : "#333333";
        } else if (what === "text") {
            if (root.usesPlasmaSurface)
                return Kirigami.Theme.disabledTextColor;
            return root.appLightPalette ? "#555555" : "#888888";
        }
        return "";
    }

    // Rewrites the old single Light/Dark/Plasma choice as the new preset and colors.
    // Every new entry defaults to -1 ("not migrated yet"), so a real value is what a
    // previous run or the settings dialog wrote. That makes the migration idempotent
    // and keeps a theme picked in the settings page from being overwritten.
    function migrateThemeSettings() {
        var c = Plasmoid.configuration;
        // The Custom preset was removed: keep the background its desktop used.
        if (c.themePreset === 2) {
            c.themePreset = c.desktopThemeSource === 1 ? 1 : 0;
        }
        if (c.themePreset >= 0 && c.themeColors >= 0) return;
        try {
            var legacy = Number(c.selectedTheme);
            var preset = 1;
            var colors = 2;
            if (legacy === 0) {
                preset = 0;
                colors = 0;
            } else if (legacy === 1) {
                preset = 0;
                colors = 1;
            } else if (legacy === 2) {
                preset = 1;
            }
            // legacy === -1 means the old setting was never saved: use the new
            // defaults, Plasma with System colors.
            if (c.themePreset < 0) c.themePreset = preset;
            if (c.themeColors < 0) c.themeColors = colors;
        } catch (e) {
            console.log("Error migrating theme settings: " + e);
        }
    }

    Component.onCompleted: {
        root.migrateThemeSettings();
        // Before the startup timer sends its first request, so the placeholders are
        // replaced by the previous values while the network comes up.
        root.readCachedQuotes();
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

    // --- NEWS HEADLINES ---
    // Fetched only while the News pane is on screen, never by the quote timer. Kept in
    // memory per symbol, so switching rows in the two-column view reuses fresh results;
    // headlines go stale quickly, so they are not saved in the config like the quotes.
    // Yahoo supplies the general headlines; Bucharest symbols (.RO) also get the issuer's
    // announcements from BVB. Both are merged into `items`, each item keeping its
    // `source`, so the news view can filter by provider.
    // Set by our own panel popup; Plasma's popup reports through `expanded`.
    property bool panelPopupShown: false
    readonly property bool fullViewShown: !root.inPanel || root.expanded || root.panelPopupShown
    // The News pane exists only when the feature is on and at least one source can
    // provide something for the shown symbol (BVB only covers Romanian listings).
    readonly property bool newsAvailable: root.showNews
                                          && root.singleTicker.trim() !== ""
                                          && (root.newsSourceYahoo
                                              || (root.newsSourceBvb
                                                  && BvbNews.baseSymbol(root.singleTicker) !== ""))
    // The single-stock view is not shown in the list-only multi-stock view.
    readonly property bool newsPaneShown: root.newsAvailable && root.singleViewPane === "news"
                                          && root.fullViewShown && (!root.isMultiMode || root.showTwoList)
                                          && root.singleTicker.trim() !== ""

    NewsController {
        id: newsController
        applet: root
    }

    readonly property var newsEntry: newsController.entry
    readonly property var newsItems: newsController.items

    function newsKey(symbol) { return newsController.newsKey(symbol); }
    function requestNews(symbol, force) { newsController.requestNews(symbol, force); }
    function refreshNewsSources() { newsController.refreshNewsSources(); }
    function retryNewsWithName() { newsController.retryNewsWithName(); }
    function newsAge(timeSec) { return newsController.newsAge(timeSec); }
    function openNewsLink(url) { newsController.openNewsLink(url); }
    function openYahooNews(symbol) { newsController.openYahooNews(symbol); }
    function openBvbNews(symbol) { newsController.openBvbNews(symbol); }

    // --- ANALYST PRICE TARGETS ---
    // Fetched only when the option is on, for the shown symbol. The controller keeps
    // one cached reply per ticker; the chart reads the items and draws the markers.
    AnalystController {
        id: analystController
        applet: root
    }
    readonly property var analystItems: analystController ? analystController.items : []
    readonly property var analystSummary: analystController ? analystController.summary : null
    function requestAnalystTargets(force) {
        if (analystController) analystController.request(root.singleTicker, force);
    }
    onShowAnalystTargetsChanged: {
        if (root.showAnalystTargets) root.requestAnalystTargets(false);
    }
    Timer {
        interval: 6 * 60 * 60 * 1000
        running: root.showAnalystTargets && root.singleTicker.trim() !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.requestAnalystTargets(false)
    }

    onShowNewsChanged: {
        if (!root.showNews) root.singleViewPane = "chart";
    }
    onNewsSourceYahooChanged: Qt.callLater(root.refreshNewsSources)
    onNewsSourceBvbChanged: Qt.callLater(root.refreshNewsSources)
    // A larger count must not wait for the next interval.
    onNewsCountChanged: {
        newsController.invalidate();
        if (root.newsPaneShown) root.requestNews(root.singleTicker, true);
    }
    onSingleCompanyNameChanged: Qt.callLater(root.retryNewsWithName)
    onSingleDataTickerChanged: Qt.callLater(root.retryNewsWithName)

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
        return Portfolio.getPortfolioSummary(ticker, dataStr, rawPrice, prevClose, quoteCurrency,
                                             root.portfolioCurrency, root.convertMoney, Currency);
    }

    // "-$1,234.50", or "+$1,234.50" when `signed` and the amount is positive.
    function formatMoney(sym, v, signed) {
        var sign = v < 0 ? "-" : (signed && v > 0 ? "+" : "");
        return sign + sym + root.formatNumber(Math.abs(v), false);
    }

    function getPortfolioTickers(dataStr) {
        return Portfolio.getPortfolioTickers(dataStr);
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
    // Chart & News page, so both stay in sync.
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
            root.panelCurrentIsCached = row.cached === true;
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
        // A row that has not been quoted yet has no exchange metadata; fall back to the
        // suffix so the badge appears immediately.
        root.singleExchange = Exchanges.shortLabel(clean, "", "");
        root.singleExchangeFull = root.singleExchange;
        if (row) {
            root.singleCompanyName = row.name;
            root.singleExchange = row.exchange || root.singleExchange;
            root.singleExchangeFull = row.exchangeFull || root.singleExchange;
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

    // True when a quote or candle at `time` belongs to the extended session `period`.
    // The after-hours window is inclusive at its end: Yahoo can timestamp the final
    // print exactly at the session end (20:00:00 ET), and a strict "before the end"
    // check dropped that quote for some symbols. The pre-market end stays exclusive: a
    // trade at 09:30 belongs to the regular session.
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
        if (!root.inExtendedSession(period, e.time, status)) return undefined;
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
                    if (root.inExtendedSession(days[d].post, stamps[last], "post")) {
                        period = days[d].post;
                        kind = "post";
                        label = i18n("After-Hours");
                    } else if (root.inExtendedSession(days[d].pre, stamps[last], "pre")) {
                        period = days[d].pre;
                        kind = "pre";
                        label = i18n("Pre-Market");
                    }
                }
            }
            if (!root.inExtendedSession(period, stamps[last], kind)) {
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

    // --- STARTUP RETRY ---
    // Quote requests are one-shot and the periodic refresh can be minutes away. At login
    // Plasma can start the widget before the network (or a VPN) is ready, so a failed
    // first batch used to leave the placeholders on screen until the regular interval.
    // Retry soon after a failure, backing off to 30 s, and stop as soon as a quote
    // arrives. The attempt cap keeps an offline widget from polling forever; after it,
    // the normal refresh timer takes over.
    property int quoteRetryDelay: 5
    property int quoteRetryAttempts: 0
    property bool quoteRetryScheduled: false
    // Set only by a successful network response, never by cached data. This keeps the
    // fast retry working even if a future cache fills the view before the first fetch.
    property bool quoteDataReceived: false
    Timer {
        id: quoteRetryTimer
        repeat: false
        onTriggered: {
            root.quoteRetryScheduled = false;
            if (root.quoteDataReceived || root.quoteRetryAttempts >= 8) return;
            root.quoteRetryAttempts++;
            root.quoteRetryDelay = Math.min(root.quoteRetryDelay * 2, 30);
            // Respect the active-hours and weekend settings, like the normal timer.
            root.checkTimeAndRefresh();
        }
    }
    function scheduleQuoteRetry() {
        if (root.quoteDataReceived || root.quoteRetryScheduled
                || root.quoteRetryAttempts >= 8) return;
        root.quoteRetryScheduled = true;
        quoteRetryTimer.interval = root.quoteRetryDelay * 1000;
        quoteRetryTimer.start();
    }
    function noteQuoteReceived() {
        root.quoteDataReceived = true;
        root.quoteRetryDelay = 5;
        root.quoteRetryAttempts = 0;
        root.quoteRetryScheduled = false;
        if (quoteRetryTimer.running) quoteRetryTimer.stop();
        // In multi mode the list stays marked as cached until every restored row has its
        // own network reply; one answered ticker must not make the others look live. In
        // single mode the caller that owns the header values clears the flag itself.
        if (root.isMultiMode) root.refreshCachedRowsState();
    }

    // --- CACHED QUOTES ---
    // The last successful batch is stored in the config (like the exchange rates) so a
    // launch without a network still has prices. Only the values needed for display are
    // saved: the chart is fetched fresh, since a stale graph would look live.
    readonly property int cachedQuotesMaxAge: 7 * 24 * 60 * 60
    // A restored row is replaced by its own reply within moments on a working network.
    // If one ticker never answers (delisted, typo) it must not keep its old price while
    // the rest of the list shows live data, so it falls back to a placeholder after this
    // grace period. A total outage never starts the timer, so the cache stays up.
    readonly property int cachedRowGraceMs: 15000
    Timer {
        id: cachedRowGraceTimer
        interval: root.cachedRowGraceMs
        repeat: false
        onTriggered: root.dropUnrefreshedCachedRows()
    }
    function refreshCachedRowsState() {
        var any = false;
        for (var i = 0; i < stockModel.count; i++) {
            if (stockModel.get(i).cached === true) { any = true; break; }
        }
        root.showingCachedData = any;
        if (!any) {
            if (cachedRowGraceTimer.running) cachedRowGraceTimer.stop();
        } else if (root.quoteDataReceived && !cachedRowGraceTimer.running) {
            cachedRowGraceTimer.start();
        }
    }
    // Drops the rows the network never refreshed, after the grace period. Keeping them
    // unmarked would present yesterday's price as live; a placeholder is honest.
    function dropUnrefreshedCachedRows() {
        var dropped = false;
        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            if (row.cached !== true) continue;
            stockModel.set(i, {
                "price": "---", "change": "", "pct": "", "isPos": true,
                "currentRaw": 0.0, "prevClose": 0.0, "quoteTime": 0.0,
                "cached": false
            });
            dropped = true;
            if (row.ticker === root.panelTicker) {
                root.panelCurrentPrice = "---";
                root.panelCurrentPercent = "+0.00%";
                root.panelCurrentIsPositive = true;
                root.panelCurrentIsCached = false;
                root.currentPrice = "---";
                root.priceChange = "";
                root.percentChange = "";
                root.currentRawPrice = 0;
                root.previousClose = 0;
                root.quoteTimestamp = 0;
            }
        }
        root.showingCachedData = false;
        if (dropped) root.queueQuotesCacheSave();
    }

    // Parses the stored snapshot. Kept separate from readCachedQuotes() because the
    // startup refresh timer can fire before Component.onCompleted, and the list still
    // needs the rows on its first pass.
    function parseCachedQuotes() {
        var raw = Plasmoid.configuration.cachedQuotes;
        var saved = Number(Plasmoid.configuration.cachedQuotesTime) || 0;
        if (!raw || !(saved > 0)) return null;
        var data;
        try { data = JSON.parse(raw); } catch (e) { return null; }
        return data || null;
    }

    // Restores the cached snapshot at startup. The single view gets its values here; the
    // multi rows are filled by fetchMultiStocks(), which owns the row order.
    function readCachedQuotes() {
        if (root.quoteDataReceived) return;
        var data = root.parseCachedQuotes();
        if (!data) return;
        var saved = Number(Plasmoid.configuration.cachedQuotesTime) || 0;
        root.cachedQuotesSnapshot = data;
        root.cachedQuotesTime = saved;
        if (root.isMultiMode) {
            // The refresh may be skipped at startup (weekend or outside the configured
            // hours); create the rows anyway so the cached values have somewhere to go.
            root.ensureStockRows(root.configuredTickers());
            root.applyCachedQuotesToRows();
            return;
        }
        var s = data.single;
        // Never show another instrument's values after the configured ticker changed,
        // nor a change/percentage that belongs to a different data range.
        if (!s || s.ticker !== root.singleTicker || s.range !== root.effectiveChartRange
                || !s.price || s.price === "---") return;
        // Each half of the snapshot carries its own timestamp, so refreshing the list
        // never makes an older single-mode value look newer than it is.
        var singleTime = Number(data.singleTime) || saved;
        var now = Math.floor(Date.now() / 1000);
        if (now - singleTime > root.cachedQuotesMaxAge) return;
        root.cachedQuotesTime = singleTime;
        root.showingCachedData = true;
        root.singleCompanyName = s.name || root.singleTicker;
        root.singleExchange = s.exchange || Exchanges.shortLabel(root.singleTicker, "", "");
        root.singleExchangeFull = s.exchangeFull || root.singleExchange;
        root.currentPrice = s.price;
        root.priceChange = s.change || "";
        root.percentChange = s.pct || "";
        root.isPositive = s.isPos !== false;
        root.currentRawPrice = Number(s.currentRaw) || 0;
        root.previousClose = Number(s.prevClose) || 0;
        root.currencySym = s.currencySym || "";
        root.quoteCurrency = s.currency || "";
        root.quoteTimestamp = Number(s.quoteTime) || 0;
        // The panel follows the configured range, while the header may show the chart's
        // own range. Restore the panel values only when the two ranges agree.
        if (root.effectiveChartRange === root.chartRange) {
            root.panelCurrentPrice = root.currentPrice;
            root.panelCurrentPercent = root.percentChange;
            root.panelCurrentIsPositive = root.isPositive;
            root.panelCurrentIsCached = true;
        }
        root.lastUpdated = new Date(singleTime * 1000).toLocaleTimeString(Qt.locale(), "HH:mm");
        root.nextUpdate = "";
        root.singleDataRange = s.range;
        root.singleDataTicker = s.ticker;
    }

    // Fills the list placeholders from the cached snapshot, matching by ticker so the
    // configured order and any newly added symbols are respected. Rows that already have
    // a live value are left alone, which also makes this safe on retries.
    function applyCachedQuotesToRows() {
        if (!root.cachedQuotesSnapshot) root.cachedQuotesSnapshot = root.parseCachedQuotes();
        var data = root.cachedQuotesSnapshot;
        if (!data || !data.rows || root.quoteDataReceived) return;
        // The stored change and percentage belong to the range they were fetched with.
        if ((data.rowsRange || data.range) !== root.chartRange) return;
        var rowsTime = Number(data.rowsTime) || root.cachedQuotesTime;
        var now = Math.floor(Date.now() / 1000);
        if (rowsTime > 0 && now - rowsTime > root.cachedQuotesMaxAge) return;
        var applied = false;
        for (var i = 0; i < data.rows.length; i++) {
            var c = data.rows[i];
            if (!c || !c.ticker || !c.price || c.price === "---") continue;
            for (var k = 0; k < stockModel.count; k++) {
                var row = stockModel.get(k);
                if (row.ticker !== c.ticker || row.price !== "---") continue;
                stockModel.set(k, {
                    "name": c.name || c.ticker,
                    "price": c.price || "---",
                    "change": c.change || "",
                    "pct": c.pct || "",
                    "isPos": c.isPos !== false,
                    "currentRaw": Number(c.currentRaw) || 0,
                    "prevClose": Number(c.prevClose) || 0,
                    "currencySym": c.currencySym || "",
                    "currency": c.currency || "",
                    "exchange": c.exchange || Exchanges.shortLabel(c.ticker, "", ""),
                    "exchangeFull": c.exchangeFull || "",
                    "quoteTime": Number(c.quoteTime) || 0,
                    "cached": true
                });
                applied = true;
                break;
            }
        }
        if (!applied) return;
        root.cachedQuotesTime = rowsTime > 0 ? rowsTime : root.cachedQuotesTime;
        root.showingCachedData = true;
        root.lastUpdated = new Date(root.cachedQuotesTime * 1000).toLocaleTimeString(Qt.locale(), "HH:mm");
        root.nextUpdate = "";
        root.updatePanelFromRow(root.panelTicker);
        // The two-column desktop view also shows the selected row in the single column.
        root.applyCachedSingleFromRow(root.singleTicker);
    }

    // Mirrors selectTicker() for cached rows: price and currency always, the change and
    // the quote time only when the chart shares the list's range (otherwise they belong
    // to a different period and would be labelled incorrectly).
    function applyCachedSingleFromRow(ticker) {
        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            if (row.ticker !== ticker || row.price === "---") continue;
            root.singleCompanyName = row.name || ticker;
            root.singleExchange = row.exchange || Exchanges.shortLabel(ticker, "", "");
            root.singleExchangeFull = row.exchangeFull || root.singleExchange;
            root.currentRawPrice = Number(row.currentRaw) || 0;
            root.currentPrice = row.price;
            root.currencySym = row.currencySym || "";
            root.quoteCurrency = row.currency || "";
            root.previousClose = Number(row.prevClose) || 0;
            if (root.effectiveChartRange === root.chartRange) {
                root.isPositive = row.isPos !== false;
                root.priceChange = row.change || "";
                root.percentChange = row.pct || "";
                root.quoteTimestamp = Number(row.quoteTime) || 0;
            }
            return;
        }
    }

    // Writes are debounced because a refresh answers one ticker at a time.
    Timer {
        id: quotesCacheTimer
        interval: 1500
        repeat: false
        onTriggered: root.writeQuotesCache()
    }
    function queueQuotesCacheSave() {
        if (root.showingCachedData) return;
        quotesCacheTimer.restart();
    }
    function writeQuotesCache() {
        var previous = null;
        try { previous = JSON.parse(Plasmoid.configuration.cachedQuotes || "null"); } catch (e) {}
        var now = Math.floor(Date.now() / 1000);
        var data = { "time": now, "range": root.chartRange, "rowsRange": root.chartRange,
                     "rows": [], "rowsTime": 0, "single": null, "singleTime": 0 };

        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            // Never re-stamp a restored value as if it had just been fetched; a save that
            // runs while some rows are still cached stores only the answered ones.
            if (!row || !row.ticker || row.cached === true || row.price === "---") continue;
            data.rows.push({
                "ticker": row.ticker, "name": row.name,
                "price": row.price, "change": row.change, "pct": row.pct,
                "isPos": row.isPos,
                "currentRaw": row.currentRaw, "prevClose": row.prevClose,
                "currencySym": row.currencySym, "currency": row.currency,
                "exchange": row.exchange, "exchangeFull": row.exchangeFull,
                "quoteTime": row.quoteTime
            });
        }
        if (data.rows.length > 0) {
            data.rowsTime = now;
        } else if (previous && previous.rows && previous.rows.length > 0) {
            // The other view is the live source right now; keep its older snapshot with
            // its own timestamp instead of presenting it as just refreshed.
            data.rows = previous.rows;
            data.rowsRange = previous.rowsRange || previous.range || data.rowsRange;
            data.rowsTime = Number(previous.rowsTime) || Number(previous.time) || 0;
        }

        if (!root.isMultiMode && !root.showingCachedData
                && root.singleTicker !== "" && root.singleDataTicker === root.singleTicker
                && root.currentPrice !== "---") {
            data.single = {
                "ticker": root.singleTicker,
                "name": root.singleCompanyName,
                "price": root.currentPrice,
                "change": root.priceChange,
                "pct": root.percentChange,
                "isPos": root.isPositive,
                "currentRaw": root.currentRawPrice,
                "prevClose": root.previousClose,
                "currencySym": root.currencySym,
                "currency": root.quoteCurrency,
                "exchange": root.singleExchange,
                "exchangeFull": root.singleExchangeFull,
                "quoteTime": root.quoteTimestamp,
                // The change and percentage belong to the range that was fetched; a
                // different range after a restart must not reuse them.
                "range": root.singleDataRange || root.effectiveChartRange
            };
            data.singleTime = now;
        } else if (previous && previous.single) {
            data.single = previous.single;
            data.singleTime = Number(previous.singleTime) || Number(previous.time) || 0;
        }

        if (data.rows.length === 0 && !data.single) return;
        // The top-level time is the newest part; each part is still aged by its own.
        data.time = Math.max(data.rowsTime, data.singleTime) || now;
        try {
            Plasmoid.configuration.cachedQuotes = JSON.stringify(data);
            Plasmoid.configuration.cachedQuotesTime = String(data.time);
            root.cachedQuotesTime = data.time;
            root.cachedQuotesSnapshot = data;
        } catch (e) { console.log("Error saving cached quotes: " + e); }
    }

    function fetchSingleStock(symbol, range) {
        var chartRange = range || root.effectiveChartRange;
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?" + getApiParams(chartRange);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { root.scheduleQuoteRetry(); return; }
            // Ignore a reply for a range or symbol the user has already switched away from.
            if (chartRange !== root.effectiveChartRange || symbol !== root.singleTicker) return;
            var response = JSON.parse(xhr.responseText);
            processSingleData(response, symbol, chartRange);
        };
        xhr.onerror = function() { root.scheduleQuoteRetry(); };
        xhr.ontimeout = function() { root.scheduleQuoteRetry(); };
        xhr.open("GET", url);
        xhr.timeout = 20000;
        xhr.send();
    }

    // Quote for the compact panel indicator, fetched separately when the chart uses a
    // range of its own. The panel always follows the configured data range.
    function fetchPanelStock(symbol) {
        var range = root.chartRange;
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?" + getApiParams(range);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) { root.scheduleQuoteRetry(); return; }
            if (range !== root.chartRange || symbol !== root.panelSymbol) return;
            processPanelData(JSON.parse(xhr.responseText), symbol, range);
        };
        xhr.onerror = function() { root.scheduleQuoteRetry(); };
        xhr.ontimeout = function() { root.scheduleQuoteRetry(); };
        xhr.open("GET", url);
        xhr.timeout = 20000;
        xhr.send();
    }

    // The configured watchlist, cleaned and in display order.
    function configuredTickers() {
        var tickers = root.multiTickers.split(",");
        var list = [];
        tickers.forEach(function(t) {
            var clean = t.trim();
            if (clean !== "") list.push(clean);
        });
        if (root.sortAlphabetically) {
            list.sort(function(a, b) {
                return a.localeCompare(b);
            });
        }
        return list;
    }

    // Creates the list placeholders in display order and keeps the panel selection. Used
    // before fetching, and by the cached values at startup when a refresh is skipped
    // (weekend, or outside the configured hours), so the list is not left empty.
    function ensureStockRows(targetTickers) {
        var defaultPanelTicker = targetTickers.length > 0 ? targetTickers[0] : "";
        root.panelTicker = root.manualPanelTickerOverride !== "" && targetTickers.indexOf(root.manualPanelTickerOverride) !== -1 ? root.manualPanelTickerOverride : defaultPanelTicker;
        root.singleTicker = root.panelTicker;

        if (stockModel.count === targetTickers.length) return;
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
                "currency": "",
                "exchange": Exchanges.shortLabel(cleanSymbol, "", ""),
                "exchangeFull": "",
                "cached": false
            });
        });
    }

    function fetchMultiStocks() {
        var range = root.chartRange;
        var targetTickers = root.configuredTickers();
        root.ensureStockRows(targetTickers);

        // Show the previous values (marked as cached) while the replies are in flight.
        root.applyCachedQuotesToRows();

        targetTickers.forEach(function(cleanSymbol) {
            var xhr = new XMLHttpRequest();
            var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + cleanSymbol + "?" + getApiParams(range);
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return;
                if (xhr.status !== 200) { root.scheduleQuoteRetry(); return; }
                // Ignore a reply for a range the user has already switched away from.
                if (range !== root.chartRange) return;
                var response = JSON.parse(xhr.responseText);
                processListRow(cleanSymbol, response, range);
            };
            xhr.onerror = function() { root.scheduleQuoteRetry(); };
            xhr.ontimeout = function() { root.scheduleQuoteRetry(); };
            xhr.open("GET", url);
            xhr.timeout = 20000;
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
    // Chart response parsing lives in chartdata.js; these wrappers keep the existing
    // root API used by the quote workflow and the views.
    function tradingDays(meta) { return ChartData.tradingDays(meta); }
    function displayedDay(meta, timestamps) { return ChartData.displayedDay(meta, timestamps); }
    function chartDayFor(meta, timestamps, quotes) { return ChartData.chartDayFor(meta, timestamps, quotes); }
    function isPreSessionDay(meta, day) { return ChartData.isPreSessionDay(meta, day); }
    function extendedSessionSeries(quotes, timestamps, day) {
        return ChartData.extendedSessionSeries(quotes, timestamps, day);
    }
    function cleanChartData(quotes, timestamps, startTime, range, quote, day) {
        return ChartData.cleanChartData(quotes, timestamps, startTime,
                                        range || root.effectiveChartRange, quote, day);
    }
    function seedFirstSessionPoint(chart, dayStart, meta) {
        return ChartData.seedFirstSessionPoint(chart, dayStart, meta);
    }
    function candleTarget(range) { return ChartData.candleTarget(range); }
    function dailyPreviousClose(meta, fallback) { return ChartData.dailyPreviousClose(meta, fallback); }
    function buildCandles(chart, range, asked) { return ChartData.buildCandles(chart, range, asked); }
    function sessionCandles(quote, timestamps, period, day, zone) {
        return ChartData.sessionCandles(quote, timestamps, period, day, zone);
    }
    function chartCandlesFor(chart, range, quote, timestamps, day) {
        return ChartData.chartCandlesFor(chart, range, quote, timestamps, day);
    }
    function inExtendedSession(period, time, kind) {
        return ChartData.inExtendedSession(period, time, kind);
    }
    function processPanelData(json, symbol, range) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            root.setMarketSession(symbol, meta);
            if (!root.isMultiMode && symbol === root.singleTicker) {
                root.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
                root.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            }
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
            root.panelCurrentIsCached = false;
            root.noteQuoteReceived();
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
            root.singleExchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            root.singleExchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
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
                root.panelCurrentIsCached = false;
            }

            var now = new Date();
            root.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (Plasmoid.configuration.refreshInterval * 60000));
            root.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
            root.singleDataRange = chartRange;
            root.singleDataTicker = symbol;
            if (!root.isMultiMode) root.showingCachedData = false;
            root.noteQuoteReceived();
            root.queueQuotesCacheSave();
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

            var exchange = Exchanges.shortLabel(symbol, meta.exchangeName, meta.fullExchangeName);
            var exchangeFull = Exchanges.fullLabel(symbol, meta.exchangeName, meta.fullExchangeName);
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
                "currency": meta.currency || "",
                "exchange": exchange,
                "exchangeFull": exchangeFull,
                "cached": false
            };

            if (root.isMultiMode && symbol === root.panelTicker) {
                root.panelCurrentPrice = itemData.price;
                root.panelCurrentPercent = itemData.pct;
                root.panelCurrentIsPositive = itemData.isPos;
                root.panelCurrentIsCached = false;
                root.singleExchange = itemData.exchange;
                root.singleExchangeFull = itemData.exchangeFull;
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
            root.noteQuoteReceived();
            root.queueQuotesCacheSave();

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

    // Empty the list and forget any cached state attached to its rows. The next fetch
    // re-applies the snapshot when it belongs to the new tickers/range.
    function clearStockRows() {
        stockModel.clear();
        // Do not persist the rows that are about to be rebuilt.
        if (quotesCacheTimer.running) quotesCacheTimer.stop();
        root.showingCachedData = false;
        root.panelCurrentIsCached = false;
        if (cachedRowGraceTimer.running) cachedRowGraceTimer.stop();
    }
    onSingleTickerChanged: {
        // In multi mode selecting a row reuses its cached chart; the periodic list
        // refresh keeps that cache current, so no request is needed here. Only the
        // single view needs a refresh when its configured ticker changes.
        if (!root.isMultiMode) {
            // The values on screen (and any save already queued) belong to the previous
            // ticker, not to the one that is about to be fetched.
            quotesCacheTimer.stop();
            root.singleDataRange = "";
            root.singleDataTicker = "";
            // Drop the previous symbol's exchange badge; the suffix fallback is enough
            // until the new quote supplies the real exchange name.
            root.singleExchange = Exchanges.shortLabel(root.singleTicker, "", "");
            root.singleExchangeFull = root.singleExchange;
            // A cached single-view value belongs to the previous ticker; carrying it
            // over would show the old symbol's price under the new one if the network
            // is still down.
            if (root.showingCachedData) {
                root.showingCachedData = false;
                root.panelCurrentIsCached = false;
                root.singleCompanyName = root.loadingText;
                root.currentPrice = "---";
                root.priceChange = "";
                root.percentChange = "";
                root.currentRawPrice = 0;
                root.previousClose = 0;
                root.quoteTimestamp = 0;
                root.panelCurrentPrice = "---";
                root.panelCurrentPercent = "+0.00%";
            }
            root.readCachedQuotes();
            root.refreshData();
        }
        if (root.newsPaneShown) root.requestNews(root.singleTicker, false);
        if (root.showAnalystTargets) Qt.callLater(function() { root.requestAnalystTargets(false); });
    }
    onIsMultiModeChanged: {
        root.clearStockRows();
        if (!isMultiMode) {
            root.singleTicker = Qt.binding(function() { return Plasmoid.configuration.ticker; });
            quotesCacheTimer.stop();
            root.singleDataRange = "";
            root.singleDataTicker = "";
            root.singleCompanyName = root.loadingText;
            root.currentPrice = "---";
            root.priceChange = "";
            root.percentChange = "";
            root.chartDataPoints = [];
            root.chartTimestamps = [];
            root.chartSessions = null;
            root.chartCandles = [];
            root.chartReferencePrice = 0;
            root.readCachedQuotes();
        }
        refreshData();
    }
    onMultiTickersChanged: { root.clearStockRows(); refreshData(); }
    onSortAlphabeticallyChanged: { root.clearStockRows(); refreshData(); }
    onFormatPricesChanged: refreshData()
    onHideDecimalsChanged: refreshData()
    // CHANGED: Update when the list's configured range changes
    onChartRangeChanged: {
        // The values on screen (and any save already queued) belong to the previous
        // range, not to the one that is about to be fetched.
        quotesCacheTimer.stop();
        root.singleDataRange = "";
        root.singleDataTicker = "";
        // A cached change belongs to the range it was fetched with; do not keep it on
        // screen under the new range while the first request is in flight.
        if (!root.isMultiMode && root.showingCachedData) {
            root.showingCachedData = false;
            root.panelCurrentIsCached = false;
            root.currentPrice = "---";
            root.priceChange = "";
            root.percentChange = "";
            root.currentRawPrice = 0;
            root.previousClose = 0;
            root.quoteTimestamp = 0;
            root.panelCurrentPrice = "---";
            root.panelCurrentPercent = "+0.00%";
        }
        root.clearStockRows();
        refreshData();
    }
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
    toolTipMainText: tooltipContent.title
    toolTipSubText: tooltipContent.body
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

    TooltipContent {
        id: tooltipContent
        applet: root
        stockList: stockModel
    }

    ListModel { id: stockModel }

    // Whether a list row still shows its restored value. Reading tooltipRevision makes
    // bindings that call this re-evaluate whenever a row changes.
    function rowIsCached(ticker) {
        var revision = root.tooltipRevision;
        for (var i = 0; i < stockModel.count; i++) {
            var row = stockModel.get(i);
            if (row.ticker === ticker) return row.cached === true;
        }
        return false;
    }

    // Optionally show the price and the change percentage in the same spot of
    // the panel indicator, switching between them every N seconds, instead of
    // showing both side by side.
    readonly property bool panelAlternate: Plasmoid.configuration.alternatePricePercent
                                           && !root.hideChangePercentage
                                           && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    // The expanded panel view uses our transparent popup for Application, which paints
    // its own cards. Plasma keeps the standard Plasma popup and its system background.
    readonly property bool customPanelPopup: !root.usesPlasmaSurface
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
    // popup, which draws no background and therefore shows only the widget's surface.
    function togglePanelPopup() {
        if (!root.customPanelPopup) {
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

    onCustomPanelPopupChanged: {
        // Close the mode that is no longer selected, so changing the theme takes effect
        // immediately instead of leaving the old popup on screen.
        if (!root.customPanelPopup) {
            if (panelPopupWindowLoader.item)
                panelPopupWindowLoader.item.visible = false;
            panelPopupWindowLoader.active = false;
        } else {
            root.expanded = false;
        }
    }

    // --- PANEL VIEW (Compact Representation) ---
    compactRepresentation: CompactPanel {
        applet: root
        stockList: stockModel
    }

    // --- FULL VIEW (desktop widget and the panel expanded popup) ---

    Component {
        id: fullViewComponent

        FullView {
            applet: root
            stockList: stockModel
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
                root.panelPopupShown = visible;
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
                    active: root.customPanelPopup
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
