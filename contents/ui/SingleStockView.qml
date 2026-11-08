import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: singleStockRoot

    property var rootItem

    color: rootItem.bgColor
    radius: rootItem.isPlasmaTheme ? 0 : 22
    clip: true

    Text {
        anchors.centerIn: parent
        text: "Loading..."
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
            anchors.fill: parent
            z: 100 // Ensure it's on top of everything
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
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
                        text: (rootItem.lastUpdated && rootItem.nextUpdate) ? "Updated: " + rootItem.lastUpdated + " • Next: " + rootItem.nextUpdate : ""
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
            Item {
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
                    onPaint: { drawChart(getContext("2d"), width, height, rootItem.chartDataPoints, rootItem.previousClose, rootItem.isPositive, true, rootItem.showChartAxis); }
                    Connections {
                        target: rootItem
                        function onChartDataPointsChanged() { singleCanvas.requestPaint(); }
                        function onShowChartAxisChanged() { singleCanvas.requestPaint(); }
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
            // Pre-market / after-market quote, when enabled and the symbol has one:
            // a muted caption, the price, and the change in the same tinted badge style
            // the list and the panel use.
            RowLayout {
                id: extendedRow
                readonly property var ext: rootItem.showExtendedHours ? rootItem.extendedData[rootItem.singleTicker] : undefined
                readonly property color accent: ext && ext.isPos ? rootItem.positiveColor : rootItem.negativeColor

                // Caption fitting: "After-Market" if it fits next to the price and the change,
                // else just "After" / "Pre", else nothing. Measured with the same font as the
                // caption so the row never needs more width than the card provides.
                readonly property real chipWidth: extendedChange.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                readonly property real baseWidth: extendedPrice.implicitWidth + chipWidth + spacing
                readonly property string shortLabel: ext ? (ext.label === "Pre-Market" ? "Pre" : "After") : ""
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
                spacing: 8

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
            // One line per purchased lot: each lot's own (fixed) purchase price compared
            // against the live current price, independently of the others.
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 1
                visible: rootItem.showPortfolioMode && rootItem.hasPortfolioEntry

                Repeater {
                    model: rootItem.portfolioLots
                    delegate: Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.shares + " @ " + rootItem.currencySym + modelData.avgCost.toFixed(2)
                              + "  →  " + rootItem.formatNumber(modelData.plValue, true)
                              + " (" + rootItem.formatNumber(modelData.plPercent, true) + "%)"
                        color: modelData.plIsPos ? rootItem.positiveColor : rootItem.negativeColor
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }

    // Draws a price scale on the left: faint horizontal grid lines at round
    // values with their labels. Returns the width reserved for the labels, so
    // the caller can start the plot to the right of it.
    function drawAxis(ctx, w, h, minVal, maxVal, getY) {
        var range = maxVal - minVal;
        var rawStep = range / 4;
        var mag = Math.pow(10, Math.floor(Math.log(rawStep) / Math.LN10));
        var norm = rawStep / mag;
        var step = (norm < 1.5 ? 1 : norm < 3 ? 2 : norm < 7 ? 5 : 10) * mag;

        var ticks = [];
        for (var v = Math.ceil(minVal / step) * step; v <= maxVal; v += step) {
            ticks.push(v);
        }

        ctx.font = "10px sans-serif";
        ctx.textBaseline = "middle";
        var labelW = 0;
        var labels = [];
        for (var i = 0; i < ticks.length; i++) {
            var text = rootItem.formatNumber(ticks[i], false);
            labels.push(text);
            labelW = Math.max(labelW, ctx.measureText(text).width);
        }
        var plotX = Math.ceil(labelW) + 8;

        ctx.lineWidth = 1;
        ctx.strokeStyle = rootItem.chartBaseColor;
        ctx.fillStyle = rootItem.secondaryTextColor;
        for (var j = 0; j < ticks.length; j++) {
            var y = Math.round(getY(ticks[j])) + 0.5;
            ctx.beginPath();
            ctx.moveTo(plotX, y);
            ctx.lineTo(w, y);
            ctx.stroke();
            ctx.fillText(labels[j], 0, y);
        }
        return plotX;
    }

    function drawChart(ctx, w, h, data, prevClose, isPos, drawBackground, showAxis) {
        ctx.clearRect(0, 0, w, h);
        if (!data || data.length < 2) return;
        var minVal = Math.min(...data);
        var maxVal = Math.max(...data);
        var range = maxVal - minVal;
        if (range === 0) range = 1;
        var padding = range * (drawBackground ? 0.1 : 0.05);
        minVal -= padding;
        maxVal += padding;
        range = maxVal - minVal;
        function getY(val) { return h - ((val - minVal) / range * h); }

        // Left edge of the plot; moves right when the price scale is shown.
        var plotX = 0;
        if (drawBackground && showAxis) plotX = drawAxis(ctx, w, h, minVal, maxVal, getY);

        if (drawBackground) {
            var prevY = getY(prevClose);
            ctx.beginPath();
            ctx.strokeStyle = rootItem.chartBaseColor;
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);
            ctx.moveTo(plotX, prevY);
            ctx.lineTo(w, prevY);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        ctx.beginPath();
        var stepX = (w - plotX) / (data.length - 1);
        ctx.moveTo(plotX, getY(data[0]));
        for (var i = 1; i < data.length; i++) {
            ctx.lineTo(plotX + i * stepX, getY(data[i]));
        }

        ctx.lineJoin = "round";
        ctx.lineWidth = 2;
        ctx.strokeStyle = isPos ? rootItem.positiveColor : rootItem.negativeColor;
        ctx.stroke();

        if (drawBackground) {
            ctx.lineTo(w, h);
            ctx.lineTo(plotX, h);
            ctx.closePath();
            var gradient = ctx.createLinearGradient(0, 0, 0, h);
            var baseColor = isPos ? rootItem.positiveColor : rootItem.negativeColor;
            gradient.addColorStop(0.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.3));
            gradient.addColorStop(1.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.0));
            ctx.fillStyle = gradient;
            ctx.fill();
        }
    }
}
