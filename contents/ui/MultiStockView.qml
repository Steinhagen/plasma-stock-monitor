import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: multiStockRoot

    property var rootItem
    property var listModel

    color: rootItem.bgColor
    radius: rootItem.isPlasmaTheme ? 0 : 22
    clip: true

    // --- Portfolio total ---
    // The value, total gain and period gain of all the positions together, shown as the last
    // line of the list. null when it does not apply: the feature is off, fewer than two tickers
    // have lots, or the positions are in different currencies (those cannot be added up).
    property var totals: null
    property string totalsSym: ""
    property string totalsLabel: ""

    function recomputeTotals() {
        multiStockRoot.totals = null;
        if (!rootItem || !listModel || !rootItem.showPortfolioMode) return;
        var held = rootItem.getPortfolioTickers(rootItem.portfolioData);
        if (held.length < 2) return;
        var value = 0, cost = 0, day = 0, dayKnown = true, priced = 0, currencies = {};
        for (var i = 0; i < listModel.count; i++) {
            var row = listModel.get(i);
            if (!(row.currentRaw > 0)) continue;
            var s = rootItem.getPortfolioSummary(row.ticker, rootItem.portfolioData, row.currentRaw, row.prevClose);
            if (!s) continue;
            priced++;
            value += s.value;
            cost += s.cost;
            currencies[row.currencySym] = true;
            if (s.dayValue === null) dayKnown = false;
            else day += s.dayValue;
        }
        var symbols = Object.keys(currencies);
        if (priced === 0 || symbols.length !== 1) return;
        var pl = value - cost;
        multiStockRoot.totalsSym = symbols[0];
        // Say so when some positions have no price yet (still loading, or not in the list).
        multiStockRoot.totalsLabel = priced === held.length ? held.length + " positions"
                                                            : priced + " of " + held.length + " positions";
        multiStockRoot.totals = {
            value: value, cost: cost, plValue: pl, plPercent: cost > 0 ? (pl / cost) * 100 : 0, plIsPos: pl >= 0,
            dayValue: dayKnown ? day : null, dayIsPos: !dayKnown || day >= 0
        };
    }

    // Prices arrive one ticker at a time, so recompute once they settle.
    Timer { id: totalsTimer; interval: 100; onTriggered: multiStockRoot.recomputeTotals() }
    Component.onCompleted: multiStockRoot.recomputeTotals()
    Connections {
        target: multiStockRoot.listModel
        function onDataChanged() { totalsTimer.restart(); }
        function onRowsInserted() { totalsTimer.restart(); }
        function onRowsRemoved() { totalsTimer.restart(); }
        function onModelReset() { totalsTimer.restart(); }
    }
    Connections {
        target: multiStockRoot.rootItem
        function onPortfolioDataChanged() { totalsTimer.restart(); }
        function onShowPortfolioModeChanged() { totalsTimer.restart(); }
    }

    Text {
        anchors.centerIn: parent
        text: "Loading..."
        color: rootItem.secondaryTextColor
        font.pixelSize: 14
        visible: rootItem.isMultiMode && listModel.count === 0
    }
    ListView {
        id: multiView
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 16
        anchors.topMargin: 0

        clip: true
        model: listModel
        spacing: 0

        // The portfolio total, after the last row.
        footer: Component {
            Item {
                width: multiView.width
                height: multiStockRoot.totals !== null ? 40 : 0
                visible: multiStockRoot.totals !== null

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: multiStockRoot.rootItem.chartBaseColor
                }
                PositionLine {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    rootItem: multiStockRoot.rootItem
                    summary: multiStockRoot.totals
                    sym: multiStockRoot.totalsSym
                    heldOverride: multiStockRoot.totalsLabel
                }
            }
        }

        delegate: Item {
            id: rowRoot
            width: multiView.width
            // The position for this ticker: all its lots added up, or null when there are none (or
            // the feature is off). Computed here, not stored as a model role, so it stays reactive
            // to rootItem.portfolioData and the live price.
            property var rowSummary: (rootItem.showPortfolioMode && model.currentRaw > 0)
                                     ? rootItem.getPortfolioSummary(model.ticker, rootItem.portfolioData, model.currentRaw, model.prevClose)
                                     : null
            // Base row, plus one summary line when the ticker has a position.
            height: 60 + (rowRoot.rowSummary !== null ? 20 : 0)
            property string rowCurrencySym: model.currencySym
            // Pre-market / after-market quote for this ticker. Only present while that session is
            // the latest one, i.e. when the regular market is closed (undefined otherwise).
            property var rowExt: rootItem.showExtendedHours ? rootItem.extendedData[model.ticker] : undefined

            MouseArea {
                anchors.fill: parent
                z: 100 // Above the row layout
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        parent.opacity = 0.4;
                        rootItem.refreshData();
                        timerListFlicker.restart();
                    } else if (mouse.button === Qt.LeftButton) {
                        console.log("Opening URL: " + model.ticker);
                        Qt.openUrlExternally("https://finance.yahoo.com/quote/" + model.ticker);
                    } else if (mouse.button === Qt.RightButton) {
                        rootItem.manualPanelTickerOverride = model.ticker;
                        rootItem.singleTicker = model.ticker; // Also update singleTicker to keep singleView in sync
                        rootItem.refreshData();
                    }
                }
                Timer {
                    id: timerListFlicker
                    interval: 300
                    onTriggered: parent.opacity = 1.0;
                }
            }

            // Outer ColumnLayout so the per-lot lines stack *below* the name/price row instead
            // of inside it — keeping them inside the row's own ColumnLayout would grow that
            // column's content height and, since it's independently vertically-centered, pull
            // the price up out of line with the ticker name whenever a ticker had lots.
            ColumnLayout {
                anchors.fill: parent
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    spacing: 10
                    // The two lines are separate RowLayouts, so each one sizes on its own:
                    // the wide change badge on the second line must not take width away from
                    // the name on the first line (they used to share two columns).
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        // Line 1: arrow, name (elided when too long), price.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: model.isPos ? "▲" : "▼"
                                color: model.isPos ? rootItem.positiveColor : rootItem.negativeColor
                                font.pixelSize: 10
                            }
                            Text {
                                id: listNameText
                                FontMetrics { id: listNameMetrics; font: listNameText.font }
                                text: rootItem.showNameAndTicker
                                      ? rootItem.fitNameAndTicker(model.name, model.ticker, width, listNameMetrics)
                                      : (rootItem.swapNameAndTicker ? model.name : model.ticker)
                                // Width comes only from the space left beside the price, never
                                // from the text, so choosing the wording by width cannot loop.
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                color: rootItem.tickerColor
                                opacity: rootItem.tickerOpacity / 100.0
                                font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                // Keep a small gap so the name elides just before touching the price.
                                Layout.rightMargin: 6
                            }
                            Text {
                                text: model.price
                                color: rootItem.priceColor
                                opacity: rootItem.priceOpacity / 100.0
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignRight
                                Layout.minimumWidth: implicitWidth
                            }
                        }

                        // Line 2: secondary text (elided when too long), change badge.
                        // While the market is closed and the ticker has a pre-market / after-market
                        // quote, that quote takes the place of the secondary text, so the row keeps
                        // its two lines.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                id: secondLine
                                readonly property var ext: rowRoot.rowExt

                                FontMetrics { id: secondLineMetrics; font.pixelSize: 10; font.bold: true }

                                // Longest wording that fits in `avail` pixels, richest first:
                                // "After-Market $342.65 -0.28 (-0.08%)" ... down to just the price.
                                function extText(avail) {
                                    var e = secondLine.ext;
                                    if (!e) return "";
                                    var shortLabel = e.label === "Pre-Market" ? "Pre" : "After";
                                    var tiers = [
                                        [e.label, e.price, e.change + " (" + e.pct + ")"],
                                        [shortLabel, e.price, e.pct],
                                        [null, e.price, e.pct],
                                        [null, e.price, null]
                                    ];
                                    var pick = tiers[tiers.length - 1];
                                    for (var i = 0; i < tiers.length; i++) {
                                        var plain = tiers[i].filter(function(p) { return p !== null; }).join(" ");
                                        if (secondLineMetrics.advanceWidth(plain) <= avail) { pick = tiers[i]; break; }
                                    }
                                    var accent = e.isPos ? rootItem.positiveColor : rootItem.negativeColor;
                                    var out = "";
                                    if (pick[0] !== null) out += '<font color="' + rootItem.secondaryTextColor + '">' + pick[0] + '</font> ';
                                    // With no change shown, colour the price itself so the direction is still visible.
                                    out += '<font color="' + (pick[2] === null ? accent : rootItem.priceColor) + '"><b>' + pick[1] + '</b></font>';
                                    if (pick[2] !== null) out += ' <font color="' + accent + '"><b>' + pick[2] + '</b></font>';
                                    return out;
                                }

                                textFormat: ext ? Text.StyledText : Text.PlainText
                                // Line 1 already carries the company name when name and ticker are shown together.
                                text: ext ? extText(width)
                                          : (rootItem.showNameAndTicker ? ""
                                             : (rootItem.swapNameAndTicker ? model.ticker : model.name))
                                color: rootItem.secondaryTextColor
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                // Width comes only from the space the badge leaves, never from the
                                // text, so choosing the wording by width cannot loop.
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                            }
                            Rectangle {
                                radius: 4
                                // Background: translucent tint of the color for theme independence
                                color: model.isPos
                                    ? Qt.rgba(rootItem.positiveColor.r, rootItem.positiveColor.g, rootItem.positiveColor.b, 0.15)
                                    : Qt.rgba(rootItem.negativeColor.r, rootItem.negativeColor.g, rootItem.negativeColor.b, 0.15)
                                border.color: model.isPos ? rootItem.positiveColor : rootItem.negativeColor
                                border.width: 1
                                Layout.preferredWidth: pctTextL.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                                Layout.minimumWidth: Layout.preferredWidth
                                Layout.preferredHeight: pctTextL.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                                Layout.alignment: Qt.AlignRight

                                Text {
                                    id: pctTextL
                                    anchors.centerIn: parent
                                    text: model.change + " (" + model.pct + ")"
                                    color: model.isPos ? rootItem.positiveColor : rootItem.negativeColor
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                }
                            }
                        }
                    }
                }

                // One line for the whole position of this ticker, below the core row so it never
                // affects that row's own alignment.
                PositionLine {
                    Layout.fillWidth: true
                    // The core row above is vertically centred in 60 px, so pull this line up
                    // towards its content and leave room before the separator.
                    Layout.topMargin: -4
                    // The width comes only from the row, never from the line itself, so choosing
                    // the parts by width cannot loop.
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    rootItem: multiStockRoot.rootItem
                    summary: rowRoot.rowSummary
                    sym: rowRoot.rowCurrencySym
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: rootItem.chartBaseColor
                visible: index < multiView.count - 1
            }
        }
    }
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        text: (rootItem.lastUpdated && rootItem.nextUpdate) ? "Updated: " + rootItem.lastUpdated + " • Next: " + rootItem.nextUpdate : ""
        color: rootItem.secondaryTextColor
        font.pixelSize: 10
        visible: rootItem.lastUpdated !== "" && rootItem.isMultiMode && !rootItem.hideTimestamps
    }
}
