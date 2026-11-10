import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Rectangle {
    id: singleStockRoot

    property var rootItem

    // Hover crosshair state for the chart. Coordinates are local to the chart canvas.
    property bool chartHoverActive: false
    property real chartHoverX: 0

    // Extended quote and market session for the compact quote block. `extendedQuote`
    // is undefined while the regular session is running or when extended data is off.
    readonly property var extendedQuote: rootItem.extendedQuote(rootItem.singleTicker)
    readonly property bool hasExtendedQuote: extendedQuote !== undefined && extendedQuote !== null
    readonly property string marketSession: rootItem.marketStatusFor(rootItem.singleTicker)
    readonly property string marketSessionText: {
        switch (marketSession) {
            case "pre":    return i18nc("@item:market session status", "Pre-market");
            case "open":   return i18nc("@item:market session status", "Open");
            case "post":
            case "closed": return i18nc("@item:market session status", "Closed");
            default:       return "";
        }
    }
    readonly property color marketSessionColor: marketSession === "pre"
        ? (rootItem.isLightTheme ? "#b47a12" : "#d9a441")
        : (marketSession === "open" ? rootItem.positiveColor : rootItem.secondaryTextColor)
    readonly property string extendedQuoteLabel: {
        if (!hasExtendedQuote) return "";
        return (extendedQuote.kind === "pre"
                ? i18nc("@item:compact quote", "Pre-market")
                : i18nc("@item:compact quote", "After-hours")).toUpperCase();
    }
    readonly property string noExtendedNote: {
        if (hasExtendedQuote || !rootItem.showExtendedHours || marketSession === "") return "";
        if (marketSession === "open") return "";
        if (marketSession === "pre") return i18n("No pre-market");
        return i18n("No after-hours");
    }

    // Tooltip of the market status in the header. Yahoo Finance does not expose the feed
    // delay per exchange through the chart API, so the quote timestamp is shown instead of
    // a hard-coded "15 minutes" that would be wrong for exchanges with real-time data.
    readonly property string marketDataNote: {
        if (!(rootItem.quoteTimestamp > 0)) return "";
        var quoteTime = new Date(rootItem.quoteTimestamp * 1000)
            .toLocaleTimeString(Qt.locale(), "HH:mm");
        return i18np("Refreshes every minute. Latest Yahoo Finance quote: %2. Quotes may be delayed.",
                     "Refreshes every %1 minutes. Latest Yahoo Finance quote: %2. Quotes may be delayed.",
                     rootItem.refreshIntervalMinutes, quoteTime);
    }

    // Minimum width of the card. It deliberately comes from the chart controls and a fixed
    // floor, not from contentColumn.implicitWidth: prices, percentages, company names and
    // positions change with the selected ticker and range, and using them made the minimum
    // (and therefore the split between the two desktop columns) move by a few pixels. Text
    // that grows with data no longer widens the card; it keeps its own elision/clipping.
    readonly property real chartControlsWidth: (rootItem.showChartRangeButtons || rootItem.showChartStyleButtons)
                                                ? chartHeaderRow.implicitWidth : 0
    readonly property real minimumContentWidth: Math.max(300, Math.ceil(chartControlsWidth) + 32)
    readonly property real minimumContentHeight: Math.max(240, Math.ceil(contentColumn.implicitHeight) + 26)

    color: rootItem.bgColor
    radius: rootItem.isPlasmaTheme ? 0 : 22
    clip: true

    Text {
        anchors.centerIn: parent
        text: i18n("Loading...")
        color: rootItem.secondaryTextColor
        font.pixelSize: 14
        visible: rootItem.isMultiMode && singleStockRoot.visible && (!rootItem.chartDataPoints || rootItem.chartDataPoints.length === 0)
    }

    Item {
        id: singleView
        visible: rootItem.showTwoList || rootItem.singleTicker.trim() !== ""
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 10

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    // Take the space left of the status, so a long "Name (TICK)"
                    // is elided instead of pushing the status out of the card.
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: rootItem.isPositive ? "▲" : "▼"
                            color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            id: singleNameText
                            FontMetrics { id: singleNameMetrics; font: singleNameText.font }
                            text: rootItem.showNameAndTicker
                                  ? rootItem.fitNameAndTicker(rootItem.singleCompanyName, rootItem.singleTicker, width, singleNameMetrics)
                                  : (rootItem.swapNameAndTicker ? rootItem.singleCompanyName : rootItem.singleTicker)
                            // Width comes only from the space left in the row, never from the text,
                            // so choosing the wording by width cannot loop.
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            color: rootItem.tickerColor
                            opacity: rootItem.tickerOpacity / 100.0
                            font.bold: true
                            font.pixelSize: 15
                            font.family: "Arial"
                            Layout.alignment: Qt.AlignVCenter
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        // The first line already carries the company name when name and ticker are shown together.
                        visible: !rootItem.showNameAndTicker
                        text: rootItem.swapNameAndTicker ? rootItem.singleTicker : rootItem.singleCompanyName
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: (rootItem.lastUpdated && rootItem.nextUpdate)
                              ? i18n("Updated: %1 • Next: %2", rootItem.lastUpdated, rootItem.nextUpdate) : ""
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 9
                        visible: rootItem.lastUpdated !== "" && !rootItem.isMultiMode && !rootItem.hideTimestamps
                    }
                }

                // The status (open/closed) doubles as the data-freshness affordance: its
                // tooltip says how often the widget polls and when Yahoo last quoted this
                // instrument, so delayed exchange data is visible without extra chrome.
                PlasmaCore.ToolTipArea {
                    id: marketStatusTip
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    Layout.leftMargin: 8
                    implicitWidth: marketStatusRow.implicitWidth
                    implicitHeight: marketStatusRow.implicitHeight
                    visible: singleStockRoot.marketSessionText !== ""
                    active: singleStockRoot.marketDataNote !== ""
                    mainText: i18n("Market data")
                    subText: singleStockRoot.marketDataNote

                    RowLayout {
                        id: marketStatusRow
                        anchors.fill: parent
                        spacing: 4

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: singleStockRoot.marketSessionColor
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: singleStockRoot.marketSessionText
                            color: rootItem.secondaryTextColor
                            font.pixelSize: 9
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }

            // Two quote columns: the regular session and the extended session that is
            // relevant now (pre-market or after-hours). When there is no extended quote,
            // the single row below takes over instead of leaving an empty column.
            RowLayout {
                id: extendedQuoteRow
                readonly property color accent: singleStockRoot.hasExtendedQuote && singleStockRoot.extendedQuote.isPos
                                                ? rootItem.positiveColor : rootItem.negativeColor
                visible: singleStockRoot.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.topMargin: 4
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        text: i18nc("@item:compact quote", "Regular").toUpperCase()
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                    }

                    Text {
                        id: priceText
                        text: rootItem.currentPrice
                        color: rootItem.priceColor
                        opacity: rootItem.priceOpacity / 100.0
                        font.pixelSize: 25
                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        text: rootItem.priceChange !== ""
                              ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : ""
                        color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 46
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.alignment: Qt.AlignVCenter
                    color: rootItem.isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.075)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 1

                    Text {
                        text: singleStockRoot.extendedQuoteLabel
                        color: singleStockRoot.hasExtendedQuote && singleStockRoot.extendedQuote.kind === "pre"
                               ? singleStockRoot.marketSessionColor : rootItem.secondaryTextColor
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: singleStockRoot.hasExtendedQuote ? singleStockRoot.extendedQuote.price : ""
                        color: rootItem.priceColor
                        opacity: rootItem.priceOpacity / 100.0
                        font.pixelSize: 18
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        readonly property color accent: extendedQuoteRow.accent
                        Layout.preferredWidth: extendedChange.implicitWidth + 8
                        Layout.preferredHeight: extendedChange.implicitHeight + 4
                        radius: 4
                        color: Qt.rgba(accent.r, accent.g, accent.b, 0.13)
                        border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.4)
                        border.width: 1

                        Text {
                            id: extendedChange
                            anchors.centerIn: parent
                            text: singleStockRoot.hasExtendedQuote
                                  ? singleStockRoot.extendedQuote.change + " (" + singleStockRoot.extendedQuote.pct + ")" : ""
                            color: parent.accent
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
                }
            }

            RowLayout {
                visible: !singleStockRoot.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                Layout.topMargin: 4
                spacing: 10

                Text {
                    text: i18nc("@item:compact quote", "Regular").toUpperCase()
                    color: rootItem.secondaryTextColor
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    id: priceTextCompact
                    text: rootItem.currentPrice
                    color: rootItem.priceColor
                    opacity: rootItem.priceOpacity / 100.0
                    font.pixelSize: 25
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    text: rootItem.priceChange !== ""
                          ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : ""
                    color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                    font.pixelSize: 10
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: singleStockRoot.noExtendedNote
                    visible: text !== ""
                    color: rootItem.secondaryTextColor
                    opacity: 0.72
                    font.pixelSize: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
            }

            // Data-range selector shown in the chart when enabled in the settings. It uses
            // the same range values as the configuration page, but lets the range be changed
            // without opening the configuration dialog.
            RowLayout {
                id: chartHeaderRow
                // Bind to the settings, not to the children's visible: a child reads as
                // invisible while this row is hidden, which would keep the row hidden for good.
                visible: singleStockRoot.rootItem.showChartRangeButtons || singleStockRoot.rootItem.showChartStyleButtons
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                Layout.preferredHeight: Math.max(singleStockRoot.rootItem.showChartRangeButtons ? chartRangeButtons.implicitHeight : 0, singleStockRoot.rootItem.showChartStyleButtons ? 18 : 0)
                spacing: 6
                // A Row, not a Flow: the buttons stay on one row and its implicitWidth (the
                // one-row width) feeds the card's minimum width.
                Row {
                    id: chartRangeButtons
                    objectName: "chartRangeButtons"
                    Layout.minimumWidth: implicitWidth
                    Layout.alignment: Qt.AlignTop
                    spacing: 3
                    visible: rootItem.showChartRangeButtons

                    Repeater {
                        model: ["1D", "5D", "1M", "6M", "YTD", "1Y", "5Y", "Max"]
                        delegate: Rectangle {
                            id: rangeButton
                            objectName: "chartRangeButton_" + modelData
                            required property string modelData
                            readonly property bool selected: rangeButton.modelData === rootItem.effectiveChartRange
                            // Same weight in both states, so the selected range changes only the
                            // colors. A bold selected label would change this row's implicit width,
                            // and with it the content-derived minimum width of the card, shifting
                            // the two desktop columns by a pixel whenever another range is picked.
                            width: rangeButtonLabel.implicitWidth + 8
                            height: 18
                            radius: 4
                            color: selected
                                   ? Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
                                   : "transparent"

                            Text {
                                id: rangeButtonLabel
                                anchors.centerIn: parent
                                text: rootItem.chartRangeButtonLabel(rangeButton.modelData)
                                color: rangeButton.selected ? rootItem.tickerColor : rootItem.secondaryTextColor
                                font.pixelSize: 9
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootItem.setChartViewRange(rangeButton.modelData)
                            }
                        }
                    }
                }

                // Pushes the chart type selector to the right edge.
                Item {
                    Layout.fillWidth: true
                }
                // Chart type selector, same look as the range buttons. It writes the same
                // setting as the Appearance page.
                Row {
                    id: chartStyleButtons
                    objectName: "chartStyleButtons"
                    visible: rootItem.showChartStyleButtons
                    Layout.minimumWidth: implicitWidth
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: 3
                    Repeater {
                        model: [
                            { style: 0, label: i18nc("@item:chart style", "Line") },
                            { style: 1, label: i18nc("@item:chart style", "Candles") }
                        ]
                        delegate: Rectangle {
                            id: styleButton
                            objectName: "chartStyleButton_" + modelData.style
                            required property var modelData
                            readonly property bool selected: styleButton.modelData.style === rootItem.chartStyle
                            // Same as the range buttons: same weight in both states, so switching
                            // between Line and Candles cannot resize the card either.
                            width: styleButtonLabel.implicitWidth + 8
                            height: 18
                            radius: 4
                            color: selected
                                   ? Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
                                   : "transparent"
                            Text {
                                id: styleButtonLabel
                                anchors.centerIn: parent
                                text: styleButton.modelData.label
                                color: styleButton.selected ? rootItem.tickerColor : rootItem.secondaryTextColor
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootItem.setChartStyle(styleButton.modelData.style)
                            }
                        }
                    }
                }
            }
            Item {
                id: chartArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Room for the price scale, the time axis and, with candles, the volume bars.
                Layout.minimumHeight: 130
                Layout.preferredHeight: 130
                Layout.topMargin: 8
                Layout.bottomMargin: 4

                Canvas {
                    id: singleCanvas
                    anchors.fill: parent
                    visible: Array.isArray(rootItem.chartDataPoints) && rootItem.chartDataPoints.length > 0
                    renderStrategy: Canvas.Threaded
                    renderTarget: Canvas.Image
                    onPaint: { drawChart(getContext("2d"), width, height, rootItem.chartDataPoints, rootItem.chartTimestamps, rootItem.previousClose, rootItem.isPositive, true, rootItem.showChartAxis, rootItem.showTimeAxis); }
                    Connections {
                        target: rootItem
                        function onChartDataPointsChanged() { singleCanvas.requestPaint(); }
                        function onChartTimestampsChanged() { singleCanvas.requestPaint(); }
                        function onChartRangeChanged() { singleCanvas.requestPaint(); }
                        function onShowChartAxisChanged() { singleCanvas.requestPaint(); }
                        function onShowTimeAxisChanged() { singleCanvas.requestPaint(); }
                        function onChartStyleChanged() { singleCanvas.requestPaint(); }
                        function onChartCandlesChanged() { singleCanvas.requestPaint(); }
                        function onChartReferencePriceChanged() { singleCanvas.requestPaint(); }
                        function onChartSessionsChanged() { singleCanvas.requestPaint(); }
                        function onShowChartHoverChanged() {
                            if (!rootItem.showChartHover) singleStockRoot.chartHoverActive = false;
                            singleCanvas.requestPaint();
                        }
                    }
                    Connections {
                        target: singleStockRoot
                        function onChartHoverActiveChanged() { singleCanvas.requestPaint(); }
                        function onChartHoverXChanged() { singleCanvas.requestPaint(); }
                        function onExtendedQuoteChanged() { singleCanvas.requestPaint(); }
                    }
                }

                // The hover/click area lives inside the chart now. It must not cover the
                // range buttons above the plot.
                MouseArea {
                    id: chartMouseArea
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    cursorShape: singleStockRoot.chartHoverActive ? Qt.CrossCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    onPositionChanged: (mouse) => {
                        singleStockRoot.chartHoverActive = true;
                        singleStockRoot.chartHoverX = mouse.x;
                    }
                    onExited: singleStockRoot.chartHoverActive = false

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (priceText) priceText.opacity = 0.3;
                            if (priceTextCompact) priceTextCompact.opacity = 0.3;
                            rootItem.refreshData();
                            timerFullFlicker.restart();
                        } else {
                            console.log("Opening URL: " + rootItem.singleTicker);
                            Qt.openUrlExternally("https://finance.yahoo.com/quote/" + rootItem.singleTicker);
                        }
                    }

                    Timer {
                        id: timerFullFlicker
                        interval: 300
                        onTriggered: {
                            if (priceText) priceText.opacity = Qt.binding(function() { return rootItem.priceOpacity / 100.0; });
                            if (priceTextCompact) priceTextCompact.opacity = Qt.binding(function() { return rootItem.priceOpacity / 100.0; });
                        }
                    }
                }
            }

            // One line for the whole position: all the lots of this ticker added up (shares,
            // average cost, value, total gain, gain over the shown period).
            PositionLine {
                Layout.fillWidth: true
                Layout.topMargin: 3
                // The width comes only from the space in the card, never from the line itself,
                // so choosing the parts by width cannot loop.
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                rootItem: singleStockRoot.rootItem
                summary: singleStockRoot.rootItem.showPortfolioMode ? singleStockRoot.rootItem.portfolioSummary : null
                sym: singleStockRoot.rootItem.currencySym
                periodLabel: singleStockRoot.rootItem.chartPeriodLabel
                centered: true
            }
        }
    }

    // ── Chart drawing ────────────────────────────────────────────
    // Settings → Appearance → Chart selects between:
    //   0 = reference line split at yesterday's close
    //   1 = candlesticks with volume
    // Both use the same right-hand price scale and the same time scale below.

    // Round tick values for a price scale, roughly `targetCount` of them.
    function axisTicks(minVal, maxVal, targetCount) {
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var rawStep = range / Math.max(2, targetCount || 5);
        var mag = Math.pow(10, Math.floor(Math.log(rawStep) / Math.LN10));
        var norm = rawStep / mag;
        var step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag;
        var ticks = [];
        for (var v = Math.ceil(minVal / step) * step; v <= maxVal + step * 1e-6; v += step)
            ticks.push(v);
        return ticks;
    }

    // Price scale on the right. Returns the x coordinate where the plot ends, so the
    // caller can draw the series to the left of the labels. The labels are measured with
    // the same font that is used to draw them, so a six-figure price cannot run off the
    // card.
    function drawRightAxis(ctx, w, minVal, maxVal, getY, showGrid) {
        var ticks = axisTicks(minVal, maxVal, 5);
        var labels = [];
        var labelW = 0;
        ctx.font = "9px sans-serif";
        for (var i = 0; i < ticks.length; i++) {
            var text = rootItem.formatNumber(ticks[i], false);
            labels.push(text);
            labelW = Math.max(labelW, ctx.measureText(text).width);
        }

        var plotRight = w - Math.ceil(labelW) - 10;
        if (plotRight < 24) {
            plotRight = w;
            return plotRight;
        }

        if (showGrid) {
            ctx.save();
            ctx.strokeStyle = rootItem.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 4]);
            for (var j = 0; j < ticks.length; j++) {
                var gy = Math.round(getY(ticks[j])) + 0.5;
                ctx.beginPath();
                ctx.moveTo(0, gy);
                ctx.lineTo(plotRight, gy);
                ctx.stroke();
            }
            ctx.restore();
        }

        ctx.fillStyle = rootItem.secondaryTextColor;
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";
        for (var k = 0; k < ticks.length; k++)
            ctx.fillText(labels[k], plotRight + 7, getY(ticks[k]));
        return plotRight;
    }

    // A smooth line through the closes. The original YQL series is noisy; a small
    // Catmull-Rom-style smoothing keeps the shape without hiding the moves.
    // `xs` (optional) gives the pixel x of every point; without it the points are spread
    // evenly over 0..right.
    function traceSmooth(ctx, data, right, getY, xs) {
        var n = data.length;
        if (n < 2) return;
        var stepX = right / (n - 1);
        function px(i) { return xs ? xs[i] : i * stepX; }
        ctx.beginPath();
        ctx.moveTo(px(0), getY(data[0]));

        for (var i = 0; i < n - 1; i++) {
            var x1 = px(i);
            var y1 = getY(data[i]);
            var x2 = px(i + 1);
            var y2 = getY(data[i + 1]);
            var x0 = i > 0 ? px(i - 1) : x1;
            var y0 = i > 0 ? getY(data[i - 1]) : y1;
            var x3 = i + 2 < n ? px(i + 2) : x2;
            var y3 = i + 2 < n ? getY(data[i + 2]) : y2;
            var tension = 0.85 / 6;
            ctx.bezierCurveTo(
                x1 + (x2 - x0) * tension, y1 + (y2 - y0) * tension,
                x2 - (x3 - x1) * tension, y2 - (y3 - y1) * tension,
                x2, y2
            );
        }
    }

    function drawEndDot(ctx, x, y, color) {
        ctx.save();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.12);
        ctx.beginPath();
        ctx.arc(x, y, 8, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, 0.22);
        ctx.beginPath();
        ctx.arc(x, y, 4.8, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(x, y, 2.7, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }

    // Label for one timestamp, at the detail that fits the selected range: hours for a
    // day, days for a week, months for up to a year and years for long ranges.
    function timeAxisLabel(timestamp, span) {
        var date = new Date(timestamp * 1000);
        var locale = Qt.locale();
        switch (rootItem.effectiveChartRange) {
            case "1D":  return locale.toString(date, "HH:mm");
            case "5D":  return locale.toString(date, "ddd");
            case "1M":  return locale.toString(date, "d MMM");
            case "6M":
            case "1Y":  return locale.toString(date, "MMM");
            case "YTD":
                // Early in the year YTD covers only a few days, where month names would
                // all be the same; fall back to dates or times for those short spans.
                if (span > 60 * 86400) return locale.toString(date, "MMM");
                if (span > 2 * 86400) return locale.toString(date, "d MMM");
                return locale.toString(date, "HH:mm");
            case "5Y":  return locale.toString(date, "yyyy");
            case "Max":
                // Max can span anything from a few days to decades, so pick the detail
                // from the data rather than from the range name.
                if (span > 2 * 365 * 86400) return locale.toString(date, "yyyy");
                if (span > 90 * 86400) return locale.toString(date, "MMM yyyy");
                if (span > 2 * 86400) return locale.toString(date, "d MMM");
                return locale.toString(date, "HH:mm");
            default:
                return locale.toString(date, "d MMM");
        }
    }

    // Time scale under the plot. A handful of evenly spaced labels is enough for the
    // narrow chart; the label format follows the selected range and the available width
    // decides how many labels fit without overlapping.
    function drawTimeAxis(ctx, w, plotX, plotH, data, times) {
        if (!times || times.length !== data.length || data.length < 2) return;
        var plotW = w - plotX;
        if (plotW < 24) return;

        var span = times[times.length - 1] - times[0];
        var count = Math.max(2, Math.min(4, Math.floor(plotW / 45)));
        var lastRight = -1;
        var seen = {};

        ctx.save();
        ctx.font = "9px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillStyle = rootItem.secondaryTextColor;
        ctx.strokeStyle = rootItem.chartBaseColor;
        ctx.lineWidth = 1;

        for (var i = 0; i < count; i++) {
            var index = Math.round(i * (data.length - 1) / (count - 1));
            var timestamp = times[index];
            if (!timestamp) continue;

            var label = timeAxisLabel(timestamp, span);
            if (Object.prototype.hasOwnProperty.call(seen, label)) continue;
            var textW = ctx.measureText(label).width;
            var x = plotX + index * plotW / (data.length - 1);
            // Keep the first and last labels inside the plot instead of letting them run
            // into the price scale or off the card.
            var center = Math.max(plotX + textW / 2, Math.min(w - textW / 2, x));
            var left = center - textW / 2;
            if (lastRight >= 0 && left < lastRight + 8) continue;

            ctx.beginPath();
            ctx.moveTo(Math.round(x) + 0.5, plotH);
            ctx.lineTo(Math.round(x) + 0.5, plotH + 3);
            ctx.stroke();
            ctx.fillText(label, center, plotH + 3);

            seen[label] = true;
            lastRight = center + textW / 2;
        }
        ctx.restore();
    }

    // Time scale for the full-day chart. The session boundaries come first, then the
    // first and last points; a label that would touch one already placed is skipped.
    function drawSessionTimeAxis(ctx, plotRight, plotH, allTimes, xAt, s, nPre, nPost) {
        if (plotRight < 24) return;
        var span = allTimes[allTimes.length - 1] - allTimes[0];
        var candidates = [];
        if (nPre > 0) candidates.push(s.regStart);
        if (nPost > 0) candidates.push(s.regEnd);
        candidates.push(allTimes[0]);
        candidates.push(allTimes[allTimes.length - 1]);
        var placed = [];
        ctx.save();
        ctx.font = "9px sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "top";
        ctx.fillStyle = rootItem.secondaryTextColor;
        ctx.strokeStyle = rootItem.chartBaseColor;
        ctx.lineWidth = 1;
        for (var i = 0; i < candidates.length; i++) {
            var label = timeAxisLabel(candidates[i], span);
            var textW = ctx.measureText(label).width;
            var x = xAt(candidates[i]);
            var center = Math.max(textW / 2, Math.min(plotRight - textW / 2, x));
            var left = center - textW / 2, right = center + textW / 2;
            var clash = false;
            for (var j = 0; j < placed.length; j++) {
                if (left < placed[j][1] + 8 && right > placed[j][0] - 8) { clash = true; break; }
            }
            if (clash) continue;
            ctx.beginPath();
            ctx.moveTo(Math.round(x) + 0.5, plotH);
            ctx.lineTo(Math.round(x) + 0.5, plotH + 3);
            ctx.stroke();
            ctx.fillText(label, center, plotH + 3);
            placed.push([left, right]);
        }
        ctx.restore();
    }
    // Diagonal hatch over an extended-hours zone.
    function drawHatch(ctx, x0, x1, plotH) {
        if (x1 <= x0) return;
        ctx.save();
        ctx.beginPath();
        ctx.rect(x0, 0, x1 - x0, plotH);
        ctx.clip();
        ctx.strokeStyle = rootItem.isLightTheme ? "rgba(0,0,0,0.08)" : "rgba(255,255,255,0.08)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (var k = x0 - plotH; k < x1; k += 6) {
            ctx.moveTo(k, plotH);
            ctx.lineTo(k + plotH, 0);
        }
        ctx.stroke();
        ctx.restore();
    }
    // Direction colour of an extended-hours zone ("pre" or "post"). While the extended
    // quote of that zone is shown in the header, its own flag decides, so the line never
    // contradicts the badge. Otherwise the zone's last close is compared with `base`
    // (previous close before the open, regular close after it). Pre-market falls back to
    // the line's normal colour when there is no base.
    function sessionLineColor(zone, s, base, lastValue) {
        var pos = rootItem.positiveColor;
        var neg = rootItem.negativeColor;
        if (singleStockRoot.hasExtendedQuote) {
            var q = singleStockRoot.extendedQuote;
            var inZone = zone === "pre"
                ? (q.time >= s.preStart && q.time < s.regStart)
                : (q.time >= s.regEnd && q.time < s.postEnd);
            if (q.kind === zone && inZone) return q.isPos ? pos : neg;
        }
        if (base > 0) return lastValue >= base ? pos : neg;
        return rootItem.isPositive ? pos : neg;
    }
    // Date/time shown in the hover tooltip. Longer ranges use a coarser label because
    // one point covers a day/week/month rather than a minute.
    function hoverTimeLabel(timestamp) {
        var date = new Date(timestamp * 1000);
        var locale = Qt.locale();
        switch (rootItem.effectiveChartRange) {
            case "1D":  return locale.toString(date, "HH:mm");
            case "5D":  return locale.toString(date, "ddd HH:mm");
            case "1M":  return locale.toString(date, "d MMM HH:mm");
            case "6M":
            case "YTD":
            case "1Y":  return locale.toString(date, "d MMM yyyy");
            case "5Y":
            case "Max": return locale.toString(date, "MMM yyyy");
            default:    return locale.toString(date, "d MMM yyyy");
        }
    }

    function compactVolume(value) {
        if (!(value > 0)) return "0";
        if (value >= 1e9) return (value / 1e9).toFixed(2) + " B";
        if (value >= 1e6) return (value / 1e6).toFixed(2) + " M";
        if (value >= 1e3) return (value / 1e3).toFixed(1) + " K";
        return Math.round(value).toString();
    }

    function roundRectPath(ctx, x, y, w, h, r) {
        var rr = Math.min(r, w / 2, h / 2);
        ctx.beginPath();
        ctx.moveTo(x + rr, y);
        ctx.lineTo(x + w - rr, y);
        ctx.quadraticCurveTo(x + w, y, x + w, y + rr);
        ctx.lineTo(x + w, y + h - rr);
        ctx.quadraticCurveTo(x + w, y + h, x + w - rr, y + h);
        ctx.lineTo(x + rr, y + h);
        ctx.quadraticCurveTo(x, y + h, x, y + h - rr);
        ctx.lineTo(x, y + rr);
        ctx.quadraticCurveTo(x, y, x + rr, y);
        ctx.closePath();
    }

    // Crosshair plus a small tooltip. `plotBottom` is where the tooltip must stay,
    // `crossBottom` is where the vertical hairline ends (the volume strip makes these
    // different in the candlestick chart).
    function drawHover(ctx, plotRight, plotBottom, crossBottom, x, y, accent, title, price, detail1, detail1Color, detail2) {
        if (plotRight < 20 || plotBottom < 20) return;

        var light = rootItem.isLightTheme;
        var bg = light ? "#ffffff" : "#101417";
        var border = light ? "rgba(0, 0, 0, 0.14)" : "rgba(255, 255, 255, 0.16)";
        var text = light ? "#171a1c" : "#f3f5f6";
        var muted = light ? "#5d656c" : "#9aa2a9";

        ctx.save();
        ctx.strokeStyle = Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g, rootItem.secondaryTextColor.b, light ? 0.38 : 0.42);
        ctx.lineWidth = 1;
        ctx.setLineDash([3, 3]);
        ctx.beginPath();
        ctx.moveTo(Math.round(x) + 0.5, 0);
        ctx.lineTo(Math.round(x) + 0.5, crossBottom);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, Math.round(y) + 0.5);
        ctx.lineTo(plotRight, Math.round(y) + 0.5);
        ctx.stroke();
        ctx.restore();

        ctx.save();
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(x, y, 3.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = bg;
        ctx.beginPath();
        ctx.arc(x, y, 1.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();

        ctx.font = "9px sans-serif";
        var titleWidth = ctx.measureText(title).width;
        ctx.font = "bold 12px sans-serif";
        var priceWidth = ctx.measureText(price).width;
        ctx.font = "9px sans-serif";
        var detail1Width = detail1 ? ctx.measureText(detail1).width : 0;
        var detail2Width = detail2 ? ctx.measureText(detail2).width : 0;
        var tipW = Math.max(titleWidth, priceWidth, detail1Width, detail2Width) + 16;
        var tipH = 7 + 12 + 16 + (detail1 ? 12 : 0) + (detail2 ? 12 : 0) + 5;

        var tipX = x + 12;
        if (tipX + tipW > plotRight - 2) tipX = x - 12 - tipW;
        if (tipX < 2) tipX = 2;
        var tipY = y - tipH / 2;
        if (tipY < 2) tipY = 2;
        if (tipY + tipH > plotBottom - 2) tipY = Math.max(2, plotBottom - tipH - 2);

        ctx.save();
        roundRectPath(ctx, tipX, tipY, tipW, tipH, 5);
        ctx.fillStyle = bg;
        ctx.fill();
        ctx.strokeStyle = border;
        ctx.lineWidth = 1;
        ctx.stroke();

        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        ctx.font = "9px sans-serif";
        ctx.fillStyle = muted;
        ctx.fillText(title, tipX + 8, tipY + 7);
        ctx.font = "bold 12px sans-serif";
        ctx.fillStyle = text;
        ctx.fillText(price, tipX + 8, tipY + 19);

        var lineY = tipY + 36;
        if (detail1) {
            ctx.font = "9px sans-serif";
            ctx.fillStyle = detail1Color;
            ctx.fillText(detail1, tipX + 8, lineY);
            lineY += 12;
        }
        if (detail2) {
            ctx.font = "9px sans-serif";
            ctx.fillStyle = muted;
            ctx.fillText(detail2, tipX + 8, lineY);
        }
        ctx.restore();
    }

    // Reference chart: the area above yesterday's close is green and the area below it is
    // red; the line changes colour when it crosses the reference. The right-hand scale is
    // optional through the existing "Price scale" setting, but is on by default.
    function drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis) {
        var ref = rootItem.chartReferencePrice > 0 ? rootItem.chartReferencePrice
                                                   : (prevClose > 0 ? prevClose : data[0]);
        if (!(ref > 0)) ref = data[0];
        if (!isFinite(ref)) return;
        // Full-day layout (regular session plus pre-market / after-hours). Line style only.
        var s = (rootItem.chartStyle !== 1) ? rootItem.chartSessions : null;
        var nReg = data.length;
        var nPre = s ? s.preValues.length : 0;
        var nPost = s ? s.postValues.length : 0;
        var allData = s ? s.preValues.concat(data, s.postValues) : data;
        var allTimes = s ? s.preTimes.concat(times, s.postTimes) : times;
        if (s && (!times || times.length !== nReg || !(allTimes[allTimes.length - 1] > allTimes[0]))) {
            s = null;
            nPre = 0;
            nPost = 0;
            allData = data;
            allTimes = times;
        }
        var minVal = Math.min.apply(null, allData);
        var maxVal = Math.max.apply(null, allData);
        if (!isFinite(minVal) || !isFinite(maxVal)) {
            // A malformed cache or a bad quote must not take the whole chart down.
            minVal = ref - 1;
            maxVal = ref + 1;
        }
        if (ref < minVal) minVal = ref;
        if (ref > maxVal) maxVal = ref;
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var padding = range * 0.08;
        minVal -= padding;
        maxVal += padding;
        range = maxVal - minVal;

        var timeAxisHeight = (showTimeAxis && times && times.length === nReg && times[0] > 0) ? 16 : 0;
        var plotH = h - timeAxisHeight;
        if (plotH < 10) {
            timeAxisHeight = 0;
            plotH = h;
        }
        function getY(val) { return plotH - ((val - minVal) / range * plotH); }

        var plotRight = showPriceAxis ? drawRightAxis(ctx, w, minVal, maxVal, getY, false) : w;
        if (plotRight < 24) plotRight = w;
        var refY = getY(ref);
        // createLinearGradient() aborts the whole paint if given a non-finite value.
        if (!isFinite(refY)) refY = plotH / 2;
        refY = Math.max(0, Math.min(plotH, refY));
        var pos = rootItem.positiveColor;
        var neg = rootItem.negativeColor;
        // Pixel x of every point. Without extended hours the points are evenly spaced.
        var t0 = s ? allTimes[0] : 0;
        var tSpan = s ? allTimes[allTimes.length - 1] - allTimes[0] : 1;
        function xAt(t) { return plotRight * (t - t0) / tSpan; }
        var xsAll = null, xsReg = null;
        if (s) {
            xsAll = [];
            for (var xi = 0; xi < allTimes.length; xi++) xsAll.push(xAt(allTimes[xi]));
            xsReg = xsAll.slice(nPre, nPre + nReg);
        }
        var xFirst = xsReg ? xsReg[0] : 0;
        var xLast = xsReg ? xsReg[nReg - 1] : plotRight;
        // Fill above the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, plotRight, refY);
        ctx.clip();
        var above = ctx.createLinearGradient(0, 0, 0, Math.max(1, refY));
        above.addColorStop(0.0, Qt.rgba(pos.r, pos.g, pos.b, 0.30));
        above.addColorStop(0.55, Qt.rgba(pos.r, pos.g, pos.b, 0.10));
        above.addColorStop(1.0, Qt.rgba(pos.r, pos.g, pos.b, 0.012));
        traceSmooth(ctx, data, plotRight, getY, xsReg);
        ctx.lineTo(xLast, refY);
        ctx.lineTo(xFirst, refY);
        ctx.closePath();
        ctx.fillStyle = above;
        ctx.fill();
        ctx.restore();

        // Fill below the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
        ctx.clip();
        var below = ctx.createLinearGradient(0, refY, 0, plotH);
        below.addColorStop(0.0, Qt.rgba(neg.r, neg.g, neg.b, 0.012));
        below.addColorStop(0.5, Qt.rgba(neg.r, neg.g, neg.b, 0.11));
        below.addColorStop(1.0, Qt.rgba(neg.r, neg.g, neg.b, 0.30));
        traceSmooth(ctx, data, plotRight, getY, xsReg);
        ctx.lineTo(xLast, refY);
        ctx.lineTo(xFirst, refY);
        ctx.closePath();
        ctx.fillStyle = below;
        ctx.fill();
        ctx.restore();

        if (s) {
            var xOpen = xAt(s.regStart);
            var xClose = xAt(s.regEnd);
            if (nPre > 0) drawHatch(ctx, 0, xOpen, plotH);
            if (nPost > 0) drawHatch(ctx, xClose, plotRight, plotH);
            var sec = rootItem.secondaryTextColor;
            ctx.save();
            ctx.strokeStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.5);
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 3]);
            ctx.beginPath();
            if (nPre > 0) { ctx.moveTo(Math.round(xOpen) + 0.5, 0); ctx.lineTo(Math.round(xOpen) + 0.5, plotH); }
            if (nPost > 0) { ctx.moveTo(Math.round(xClose) + 0.5, 0); ctx.lineTo(Math.round(xClose) + 0.5, plotH); }
            ctx.stroke();
            ctx.restore();
            ctx.save();
            ctx.font = "8px sans-serif";
            ctx.fillStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.8);
            ctx.textAlign = "left";
            ctx.textBaseline = "middle";
            if (nPre > 0 && xOpen >= ctx.measureText(rootItem.tagPreMarket).width + 8)
                ctx.fillText(rootItem.tagPreMarket, 4, 22);
            if (nPost > 0 && plotRight - xClose >= ctx.measureText(rootItem.tagAfterHours).width + 8)
                ctx.fillText(rootItem.tagAfterHours, xClose + 4, 22);
            ctx.restore();
        }
        // Reference line.
        ctx.save();
        ctx.strokeStyle = Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g, rootItem.secondaryTextColor.b, 0.48);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, Math.round(refY) + 0.5);
        ctx.lineTo(plotRight, Math.round(refY) + 0.5);
        ctx.stroke();
        ctx.restore();

        // Draw a polyline split at the reference: green above it, red below it.
        function strokeSplit(values, xs) {
            ctx.save();
            ctx.beginPath();
            ctx.rect(0, 0, plotRight, refY);
            ctx.clip();
            ctx.strokeStyle = pos;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs);
            ctx.stroke();
            ctx.restore();

            ctx.save();
            ctx.beginPath();
            ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
            ctx.clip();
            ctx.strokeStyle = neg;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs);
            ctx.stroke();
            ctx.restore();
        }

        // The line changes colour exactly at the reference.
        strokeSplit(data, xsReg);

        // Extended-hours parts of the line: same reference split, no fill. Each segment
        // starts or ends on the neighbouring regular point so the line stays continuous.
        var regularClose = rootItem.currentRawPrice > 0 ? rootItem.currentRawPrice : data[nReg - 1];
        var preColor = pos, postColor = pos;
        if (nPre > 0) {
            preColor = sessionLineColor("pre", s, prevClose, s.preValues[nPre - 1]);
            strokeSplit(allData.slice(0, nPre + 1), xsAll.slice(0, nPre + 1));
        }
        if (nPost > 0) {
            postColor = sessionLineColor("post", s, regularClose, s.postValues[nPost - 1]);
            strokeSplit(allData.slice(nPre + nReg - 1), xsAll.slice(nPre + nReg - 1));
        }
        // End dot.
        var lastValue = allData[allData.length - 1];
        var dotColor = lastValue >= ref ? pos : neg;
        drawEndDot(ctx, xsAll ? xsAll[xsAll.length - 1] : plotRight, getY(lastValue), dotColor);

        // Legend in the empty top-left corner.
        var legend = rootItem.chartReferenceLabel + " " + rootItem.formatNumber(ref, false);
        ctx.save();
        ctx.strokeStyle = Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g, rootItem.secondaryTextColor.b, 0.55);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, 9.5);
        ctx.lineTo(10, 9.5);
        ctx.stroke();
        ctx.fillStyle = rootItem.secondaryTextColor;
        ctx.font = "9px sans-serif";
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";
        ctx.fillText(legend, 14, 10);
        ctx.restore();

        // Hover crosshair: snap to the nearest close and show its time and value.
        if (singleStockRoot.chartHoverActive && times && times.length === data.length) {
            var hx = Math.max(0, Math.min(plotRight, singleStockRoot.chartHoverX));
            var index, hoverX, hoverPrice, hoverTime, hoverBase = ref, hoverZoneColor = null;
            if (s) {
                index = 0;
                for (var hi = 1; hi < xsAll.length; hi++) {
                    if (Math.abs(xsAll[hi] - hx) < Math.abs(xsAll[index] - hx)) index = hi;
                }
                hoverX = xsAll[index];
                hoverPrice = allData[index];
                hoverTime = hoverTimeLabel(allTimes[index]);
                if (index < nPre) {
                    hoverTime += " " + rootItem.tagPreMarket;
                    if (prevClose > 0) hoverBase = prevClose;
                    hoverZoneColor = preColor;
                } else if (index >= nPre + nReg) {
                    hoverTime += " " + rootItem.tagAfterHours;
                    hoverBase = regularClose;
                    hoverZoneColor = postColor;
                }
            } else {
                index = Math.round((data.length - 1) * hx / plotRight);
                index = Math.max(0, Math.min(data.length - 1, index));
                hoverX = plotRight * index / (data.length - 1);
                hoverPrice = data[index];
                hoverTime = times[index] ? hoverTimeLabel(times[index]) : "";
            }
            var hoverY = getY(hoverPrice);
            var hoverChange = hoverPrice - hoverBase;
            var hoverPct = hoverBase > 0 ? (hoverChange / hoverBase) * 100 : 0;
            var hoverAccent = hoverZoneColor ? hoverZoneColor
                              : (hoverChange > 0 ? pos : (hoverChange < 0 ? neg : rootItem.secondaryTextColor));
            var hoverDetail = rootItem.formatNumber(hoverChange, true) + " (" + rootItem.formatNumber(hoverPct, true) + "%)";
            drawHover(ctx, plotRight, plotH, plotH, hoverX, hoverY, hoverAccent, hoverTime,
                      rootItem.currencySym + rootItem.formatNumber(hoverPrice, false),
                      hoverDetail, hoverAccent, "");
        }

        if (timeAxisHeight > 0) {
            if (s) drawSessionTimeAxis(ctx, plotRight, plotH, allTimes, xAt, s, nPre, nPost);
            else drawTimeAxis(ctx, plotRight, 0, plotH, data, times);
        }
    }

    // Candlestick chart with a volume strip. The candles are already aggregated in
    // main.qml, so this function only maps them to pixels. The price scale on the right
    // and the time scale below are shared with the reference chart.
    function drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis) {
        var candles = rootItem.chartCandles;
        if (!candles || !Array.isArray(candles) || candles.length < 2) return;

        var minVal = Infinity;
        var maxVal = -Infinity;
        var maxVolume = 0;
        for (var i = 0; i < candles.length; i++) {
            if (candles[i].low < minVal) minVal = candles[i].low;
            if (candles[i].high > maxVal) maxVal = candles[i].high;
            if (candles[i].volume > maxVolume) maxVolume = candles[i].volume;
        }
        if (!(maxVal > minVal)) maxVal = minVal + 1;
        var padding = (maxVal - minVal) * 0.06;
        minVal -= padding;
        maxVal += padding;
        var range = maxVal - minVal;

        var hasTimes = candles.length > 1 && candles[0].time > 0 && candles[candles.length - 1].time > 0;
        var timeAxisHeight = (showTimeAxis && hasTimes) ? 16 : 0;
        var volumeHeight = maxVolume > 0 ? Math.min(54, Math.max(26, h * 0.13)) : 0;
        var volumeBottom = h - timeAxisHeight;
        var volumeTop = volumeBottom - volumeHeight;
        var plotBottom = volumeTop - 8;
        if (plotBottom < 36) {
            volumeHeight = 0;
            volumeTop = volumeBottom;
            plotBottom = volumeBottom;
        }
        function getY(val) { return plotBottom - ((val - minVal) / range * plotBottom); }

        var plotRight = showPriceAxis ? drawRightAxis(ctx, w, minVal, maxVal, getY, true) : w;
        if (plotRight < 24) plotRight = w;

        var candleW = Math.max(2, Math.min(6, (plotRight / candles.length) * 0.62));
        for (var c = 0; c < candles.length; c++) {
            var candle = candles[c];
            var x = ((c + 0.5) * plotRight) / candles.length;
            var up = candle.close >= candle.open;
            var color = up ? rootItem.positiveColor : rootItem.negativeColor;

            ctx.save();
            ctx.globalAlpha = 0.55;
            ctx.strokeStyle = color;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(x, getY(candle.high));
            ctx.lineTo(x, getY(candle.low));
            ctx.stroke();
            ctx.restore();

            var top = Math.min(getY(candle.open), getY(candle.close));
            var bodyH = Math.max(1, Math.abs(getY(candle.close) - getY(candle.open)));
            ctx.save();
            ctx.globalAlpha = 0.9;
            ctx.fillStyle = color;
            ctx.fillRect(x - candleW / 2, top, candleW, bodyH);
            ctx.restore();
        }

        // Volume strip.
        if (volumeHeight > 0) {
            ctx.save();
            ctx.strokeStyle = rootItem.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(0, Math.round(volumeTop) + 0.5);
            ctx.lineTo(plotRight, Math.round(volumeTop) + 0.5);
            ctx.stroke();
            ctx.restore();

            if (maxVolume > 0) {
                for (var b = 0; b < candles.length; b++) {
                    var bx = ((b + 0.5) * plotRight) / candles.length;
                    var bh = Math.max(1, (candles[b].volume / maxVolume) * (volumeHeight - 4));
                    ctx.save();
                    ctx.globalAlpha = 0.20;
                    ctx.fillStyle = candles[b].close >= candles[b].open ? rootItem.positiveColor : rootItem.negativeColor;
                    ctx.fillRect(bx - candleW / 2, volumeBottom - bh, candleW, bh);
                    ctx.restore();
                }
            }
        }

        // Last close marker.
        var last = candles[candles.length - 1];
        var lastUp = last.close >= last.open;
        drawEndDot(ctx, ((candles.length - 0.5) * plotRight) / candles.length, getY(last.close),
                   lastUp ? rootItem.positiveColor : rootItem.negativeColor);

        // Hover crosshair: snap to the nearest candle and show its OHLC and volume.
        if (singleStockRoot.chartHoverActive) {
            var hx = Math.max(0, Math.min(plotRight, singleStockRoot.chartHoverX));
            var index = Math.floor((hx / plotRight) * candles.length);
            index = Math.max(0, Math.min(candles.length - 1, index));
            var hoverCandle = candles[index];
            var hoverX = ((index + 0.5) * plotRight) / candles.length;
            var hoverY = getY(hoverCandle.close);
            var candleAccent = hoverCandle.close >= hoverCandle.open ? rootItem.positiveColor : rootItem.negativeColor;
            var hoverTime = hoverCandle.time ? hoverTimeLabel(hoverCandle.time) : "";
            var hoverOHL = "O " + rootItem.formatNumber(hoverCandle.open, false)
                         + "  H " + rootItem.formatNumber(hoverCandle.high, false)
                         + "  L " + rootItem.formatNumber(hoverCandle.low, false);
            var hoverVolume = "Vol " + compactVolume(hoverCandle.volume);
            drawHover(ctx, plotRight, plotBottom, volumeBottom, hoverX, hoverY, candleAccent,
                      hoverTime, rootItem.currencySym + rootItem.formatNumber(hoverCandle.close, false),
                      hoverOHL, rootItem.secondaryTextColor, hoverVolume);
        }

        if (timeAxisHeight > 0) {
            var closes = [];
            var ctimes = [];
            for (var t = 0; t < candles.length; t++) {
                closes.push(candles[t].close);
                ctimes.push(candles[t].time);
            }
            drawTimeAxis(ctx, plotRight, 0, volumeBottom, closes, ctimes);
        }
    }

    function drawChart(ctx, w, h, data, times, prevClose, isPos, drawBackground, showPriceAxis, showTimeAxis) {
        ctx.clearRect(0, 0, w, h);
        if (!data || !Array.isArray(data) || data.length < 2
                || !isFinite(w) || !isFinite(h) || w < 20 || h < 20) return;

        if (rootItem.chartStyle === 1 && Array.isArray(rootItem.chartCandles) && rootItem.chartCandles.length > 1)
            drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis);
        else
            drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis);
    }
}
