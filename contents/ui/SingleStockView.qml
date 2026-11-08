import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: singleStockRoot

    property var rootItem

    // Hover crosshair state for the chart. Coordinates are local to the chart canvas.
    property bool chartHoverActive: false
    property real chartHoverX: 0

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

        MouseArea {
            id: chartMouseArea
            // Cover the chart and the values below it, but not the header or the range
            // buttons: those have their own click handling.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: chartArea.top
            anchors.bottom: parent.bottom
            z: 100 // Ensure it is on top of everything
            hoverEnabled: true
            cursorShape: singleStockRoot.chartHoverActive ? Qt.CrossCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            // The chart is a Canvas, so hover has to be tracked by the MouseArea that
            // already covers it. Only the chart rectangle activates the crosshair; the
            // price and after-hours rows below keep their normal pointer cursor.
            function updateHover(mx, my) {
                var p = chartArea.mapFromItem(chartMouseArea, mx, my);
                var inside = p.x >= 0 && p.x <= chartArea.width && p.y >= 0 && p.y <= chartArea.height;
                singleStockRoot.chartHoverActive = inside;
                if (inside) singleStockRoot.chartHoverX = p.x;
            }
            onPositionChanged: (mouse) => updateHover(mouse.x, mouse.y)
            onExited: singleStockRoot.chartHoverActive = false

            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton) {
                    if (priceText) priceText.opacity = 0.3;
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
                onTriggered: if (priceText) priceText.opacity = Qt.binding(function() { return rootItem.priceOpacity / 100.0; });
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                ColumnLayout {
                    spacing: 2
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    // Take the space left of the change column, so a long "Name (TICK)"
                    // is elided instead of pushing the percentage out of the card.
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
                        color: rootItem.secondaryTextColor // Slightly brighter
                        font.pixelSize: 9
                        visible: rootItem.lastUpdated !== "" && !rootItem.isMultiMode && !rootItem.hideTimestamps
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Layout.leftMargin: 8
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    Text {
                        text: rootItem.percentChange
                        color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignRight
                        font.bold: true
                    }
                    Text {
                        text: rootItem.priceChange
                        color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignRight
                        font.bold: true
                    }
                }
            }
            // Data-range selector shown in the chart when enabled in the settings. It uses
            // the same range values as the configuration page, but lets the range be changed
            // without opening the configuration dialog.
            Flow {
                id: chartRangeButtons
                objectName: "chartRangeButtons"
                Layout.fillWidth: true
                Layout.preferredHeight: chartRangeButtons.implicitHeight
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                spacing: 3
                visible: rootItem.showChartRangeButtons

                Repeater {
                    model: ["1D", "5D", "1M", "6M", "YTD", "1Y", "5Y", "Max"]
                    delegate: Rectangle {
                        id: rangeButton
                        objectName: "chartRangeButton_" + modelData
                        required property string modelData
                        readonly property bool selected: rangeButton.modelData === rootItem.effectiveChartRange
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
                            font.bold: rangeButton.selected
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootItem.setChartViewRange(rangeButton.modelData)
                        }
                    }
                }
            }
            Item {
                id: chartArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 10
                Layout.bottomMargin: 5
                Canvas {
                    id: singleCanvas
                    anchors.fill: parent
                    visible: rootItem.chartDataPoints && rootItem.chartDataPoints.length > 0
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
                        function onChartOpenPriceChanged() { singleCanvas.requestPaint(); }
                    }
                    Connections {
                        target: singleStockRoot
                        function onChartHoverActiveChanged() { singleCanvas.requestPaint(); }
                        function onChartHoverXChanged() { singleCanvas.requestPaint(); }
                    }
                }
            }
            Text {
                id: priceText
                Layout.alignment: Qt.AlignHCenter
                text: rootItem.currentPrice
                color: rootItem.priceColor
                opacity: rootItem.priceOpacity / 100.0
                font.pixelSize: 26

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            // Pre-market / after-hours quote, when enabled and the symbol has one:
            // a muted caption, the price, and the change in the same tinted badge style
            // the list and the panel use.
            RowLayout {
                id: extendedRow
                readonly property var ext: rootItem.extendedQuote(rootItem.singleTicker)
                readonly property color accent: ext && ext.isPos ? rootItem.positiveColor : rootItem.negativeColor

                // Caption fitting: "After-Hours" if it fits next to the price and the change,
                // else just "After" / "Pre", else nothing. Measured with the same font as the
                // caption so the row never needs more width than the card provides.
                readonly property real chipWidth: extendedChange.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                readonly property real baseWidth: extendedPrice.implicitWidth + chipWidth + spacing
                readonly property string shortLabel: ext
                    ? (ext.kind === "pre" ? i18nc("@item:short stock market session", "Pre")
                                          : i18nc("@item:short stock market session", "After"))
                    : ""
                readonly property string captionText: {
                    if (!ext) return "";
                    if (width >= baseWidth + spacing + fullMetrics.width) return ext.label;
                    if (width >= baseWidth + spacing + shortMetrics.width) return shortLabel;
                    return "";
                }
                TextMetrics { id: fullMetrics; font.pixelSize: 11; text: extendedRow.ext ? extendedRow.ext.label : "" }
                TextMetrics { id: shortMetrics; font.pixelSize: 11; text: extendedRow.shortLabel }

                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 2
                visible: ext !== undefined
                spacing: 10

                // The two spacers centre the content while there is room. The caption is
                // chosen by the width available (see captionText), so the row never asks
                // for more width than the card has.
                Item { Layout.fillWidth: true }
                Text {
                    visible: text !== ""
                    text: extendedRow.captionText
                    color: rootItem.secondaryTextColor
                    font.pixelSize: 11
                }
                Text {
                    id: extendedPrice
                    text: extendedRow.ext ? extendedRow.ext.price : ""
                    color: rootItem.priceColor
                    opacity: rootItem.priceOpacity / 100.0
                    font.pixelSize: 14
                    font.bold: true
                }
                Rectangle {
                    radius: 4
                    color: Qt.rgba(extendedRow.accent.r, extendedRow.accent.g, extendedRow.accent.b, 0.15)
                    border.color: extendedRow.accent
                    border.width: 1
                    Layout.preferredWidth: extendedRow.chipWidth
                    Layout.preferredHeight: extendedChange.implicitHeight + (Kirigami.Units.smallSpacing / 2)

                    Text {
                        id: extendedChange
                        anchors.centerIn: parent
                        text: extendedRow.ext ? extendedRow.ext.change + " (" + extendedRow.ext.pct + ")" : ""
                        color: extendedRow.accent
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                }
                Item { Layout.fillWidth: true }
            }
            // Shown when the symbol has no extended-hours quote (indices, for
            // example) and its exchange is not trading, so the card still says why
            // the price is not moving.
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: rootItem.showExtendedHours
                         && rootItem.isMarketClosedFor(rootItem.singleTicker)
                text: i18n("Market closed")
                color: rootItem.secondaryTextColor
                font.pixelSize: 11
            }
            // One line for the whole position: all the lots of this ticker added up (shares,
            // average cost, value, total gain, gain over the shown period).
            PositionLine {
                Layout.fillWidth: true
                Layout.topMargin: 4
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
    //   0 = reference line split at the open of the latest session
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
    function traceSmooth(ctx, data, right, getY) {
        var n = data.length;
        if (n < 2) return;
        var stepX = right / (n - 1);
        ctx.beginPath();
        ctx.moveTo(0, getY(data[0]));

        for (var i = 0; i < n - 1; i++) {
            var x1 = i * stepX;
            var y1 = getY(data[i]);
            var x2 = (i + 1) * stepX;
            var y2 = getY(data[i + 1]);
            var x0 = i > 0 ? (i - 1) * stepX : x1;
            var y0 = i > 0 ? getY(data[i - 1]) : y1;
            var x3 = i + 2 < n ? (i + 2) * stepX : x2;
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

    // Reference chart: the area above the open is green and the area below it is red; the
    // line changes colour when it crosses the reference. The right-hand scale is optional
    // through the existing "Price scale" setting, but is on by default.
    function drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis) {
        var ref = rootItem.chartOpenPrice > 0 ? rootItem.chartOpenPrice : (prevClose > 0 ? prevClose : data[0]);
        if (!(ref > 0)) ref = data[0];

        var minVal = Math.min.apply(null, data);
        var maxVal = Math.max.apply(null, data);
        if (ref < minVal) minVal = ref;
        if (ref > maxVal) maxVal = ref;
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var padding = range * 0.08;
        minVal -= padding;
        maxVal += padding;
        range = maxVal - minVal;

        var timeAxisHeight = (showTimeAxis && times && times.length === data.length && times[0] > 0) ? 16 : 0;
        var plotH = h - timeAxisHeight;
        if (plotH < 10) {
            timeAxisHeight = 0;
            plotH = h;
        }
        function getY(val) { return plotH - ((val - minVal) / range * plotH); }

        var plotRight = showPriceAxis ? drawRightAxis(ctx, w, minVal, maxVal, getY, false) : w;
        if (plotRight < 24) plotRight = w;
        var refY = getY(ref);

        var pos = rootItem.positiveColor;
        var neg = rootItem.negativeColor;

        // Fill above the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, plotRight, refY);
        ctx.clip();
        var above = ctx.createLinearGradient(0, 0, 0, Math.max(1, refY));
        above.addColorStop(0.0, Qt.rgba(pos.r, pos.g, pos.b, 0.30));
        above.addColorStop(0.55, Qt.rgba(pos.r, pos.g, pos.b, 0.10));
        above.addColorStop(1.0, Qt.rgba(pos.r, pos.g, pos.b, 0.012));
        traceSmooth(ctx, data, plotRight, getY);
        ctx.lineTo(plotRight, refY);
        ctx.lineTo(0, refY);
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
        traceSmooth(ctx, data, plotRight, getY);
        ctx.lineTo(plotRight, refY);
        ctx.lineTo(0, refY);
        ctx.closePath();
        ctx.fillStyle = below;
        ctx.fill();
        ctx.restore();

        // Reference line.
        ctx.save();
        ctx.strokeStyle = Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g, rootItem.secondaryTextColor.b, 0.48);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, Math.round(refY) + 0.5);
        ctx.lineTo(plotRight, Math.round(refY) + 0.5);
        ctx.stroke();
        ctx.restore();

        // The line changes colour exactly at the reference.
        ctx.save();
        ctx.beginPath();
        ctx.rect(0, 0, plotRight, refY);
        ctx.clip();
        ctx.strokeStyle = pos;
        ctx.lineWidth = 2;
        traceSmooth(ctx, data, plotRight, getY);
        ctx.stroke();
        ctx.restore();

        ctx.save();
        ctx.beginPath();
        ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
        ctx.clip();
        ctx.strokeStyle = neg;
        ctx.lineWidth = 2;
        traceSmooth(ctx, data, plotRight, getY);
        ctx.stroke();
        ctx.restore();

        // End dot.
        var lastValue = data[data.length - 1];
        drawEndDot(ctx, plotRight, getY(lastValue), lastValue >= ref ? pos : neg);

        // Legend in the empty top-left corner.
        var legend = rootItem.chartOpenLabel + " " + rootItem.formatNumber(ref, false);
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
            var index = Math.round((data.length - 1) * hx / plotRight);
            index = Math.max(0, Math.min(data.length - 1, index));
            var hoverX = plotRight * index / (data.length - 1);
            var hoverY = getY(data[index]);
            var hoverPrice = data[index];
            var hoverTime = times[index] ? hoverTimeLabel(times[index]) : "";
            var hoverChange = hoverPrice - ref;
            var hoverPct = ref > 0 ? (hoverChange / ref) * 100 : 0;
            var hoverAccent = hoverChange > 0 ? pos : (hoverChange < 0 ? neg : rootItem.secondaryTextColor);
            var hoverDetail = rootItem.formatNumber(hoverChange, true) + " (" + rootItem.formatNumber(hoverPct, true) + "%)";
            drawHover(ctx, plotRight, plotH, plotH, hoverX, hoverY, hoverAccent, hoverTime,
                      rootItem.currencySym + rootItem.formatNumber(hoverPrice, false),
                      hoverDetail, hoverAccent, "");
        }

        if (timeAxisHeight > 0) drawTimeAxis(ctx, plotRight, 0, plotH, data, times);
    }

    // Candlestick chart with a volume strip. The candles are already aggregated in
    // main.qml, so this function only maps them to pixels. The price scale on the right
    // and the time scale below are shared with the reference chart.
    function drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis) {
        var candles = rootItem.chartCandles;
        if (!candles || candles.length < 2) return;

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
        if (!data || data.length < 2 || w < 20 || h < 20) return;

        if (rootItem.chartStyle === 1 && rootItem.chartCandles && rootItem.chartCandles.length > 1)
            drawCandleChart(ctx, w, h, showPriceAxis, showTimeAxis);
        else
            drawReferenceChart(ctx, w, h, data, times, prevClose, showPriceAxis, showTimeAxis);
    }
}
