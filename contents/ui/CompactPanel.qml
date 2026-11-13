import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: compactRoot
    property var applet
    property var stockList

    implicitWidth: {
        // An explicit width from the settings wins. Otherwise reserve room for the
        // current values, with the widest configured value as a floor in fixed mode.
        if (compactRoot.useFixedWidth && Plasmoid.configuration.panelWidth > 0)
            return Plasmoid.configuration.panelWidth;
        var content = Math.max(compactRoot.currentContent, panelRow.implicitWidth);
        if (compactRoot.useFixedWidth)
            content = Math.max(content, compactRoot.widestContent);
        return content + (Kirigami.Units.smallSpacing * 4);
    }
    // Never paint outside the rectangle the panel gives the applet. In a vertical
    // panel that rectangle is only as wide as the panel, so the content has to fit
    // (or elide) rather than spill over the neighbouring applets.
    clip: true
    implicitHeight: panelRow.implicitHeight

    // Let the panel decide the cross-axis size: height in a horizontal panel, width
    // in a vertical one. Requesting a minimum there made the applet keep its old
    // horizontal width after an orientation change and overlap its neighbour.
    Layout.fillWidth: applet.isVerticalPanel
    Layout.fillHeight: !applet.isVerticalPanel
    Layout.minimumWidth: applet.isVerticalPanel ? 0 : implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.minimumHeight: applet.isVerticalPanel ? implicitHeight : 0
    Layout.preferredHeight: implicitHeight

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

    // Scroll wheel / touchpad scroll cycles the stock shown in the panel.
    // Scroll up = previous stock, scroll down = next stock. Deltas are
    // accumulated so smooth-scrolling touchpads advance one step per 120 units.
    property real wheelAccum: 0
    onWheel: (wheel) => {
        if (!applet.isMultiMode || stockList.count < 2) {
            wheel.accepted = false;
            return;
        }
        wheelAccum += wheel.angleDelta.y;
        var steps = 0;
        while (wheelAccum >= 120) { steps -= 1; wheelAccum -= 120; }
        while (wheelAccum <= -120) { steps += 1; wheelAccum += 120; }
        if (steps === 0) return;

        var current = 0;
        for (var i = 0; i < stockList.count; i++) {
            if (stockList.get(i).ticker === applet.panelTicker) { current = i; break; }
        }
        var n = stockList.count;
        var next = (((current + steps) % n) + n) % n;
        var row = stockList.get(next);
        applet.selectTicker(row.ticker);
    }

    onClicked: (mouse) => {
        if (mouse.button === Qt.MiddleButton) {
            if (applet.performMiddleClick(applet.panelSymbol)) {
                // Visual feedback for a refresh; open/none need no flicker.
                compactRoot.priceFlicker = 0.3;
                timerFlicker.restart();
            }
        } else {
            applet.togglePanelPopup();
        }
    }

    Timer {
        id: timerFlicker
        interval: 300
        onTriggered: compactRoot.priceFlicker = 1.0;
    }

    // While an extended-hours session is running, the ticker has a pre-market /
    // after-hours quote (see extendedQuote()). The panel then shows that quote
    // instead of the regular price and change, and a small tag next to the ticker
    // says which session it is. Without an extended quote, the tag says CLOSED
    // while the market is closed.
    readonly property var ext: applet.extendedQuote(applet.panelSymbol)
    readonly property bool marketClosed: applet.showExtendedHours
                                         && applet.isMarketClosedFor(applet.panelSymbol)
    readonly property string shownPrice: ext ? ext.price : applet.panelCurrentPrice
    readonly property string shownPercent: ext ? ext.pct : applet.panelCurrentPercent
    readonly property bool shownPositive: ext ? ext.isPos : applet.panelCurrentIsPositive

    // --- Fixed width ---
    // Cycling through the stocks, or swapping price and percentage, changes the length of the
    // text. That used to resize the indicator and push every other applet in the panel around.
    // With a fixed width the indicator reserves room for the widest value that can appear in
    // it: the longest ticker, price and change of any configured stock, in the regular and
    // in the extended-hours session. The width then stays the same while values change.
    readonly property bool useFixedWidth: Plasmoid.configuration.fixedPanelWidth
                                          && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
    // 1 normally; 0.3 for the brief refresh feedback. Kept as a property so the
    // cached-data dimming below stays bound instead of being overwritten.
    property real priceFlicker: 1.0
    property real widestContent: 0
    property real widestPrice: 0
    // Width of the values currently shown. Used as a floor so a stale layout from
    // before an orientation change cannot clip the ticker or the badge.
    property real currentContent: 0

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
            tickers.push(applet.displayTicker(ticker));
            prices.push(String(price || ""));
            pcts.push(String(pct || ""));
            var e = applet.extendedQuote(ticker);
            if (e) { prices.push(e.price); pcts.push(e.pct); }
        };
        if (applet.isMultiMode) {
            for (var i = 0; i < stockList.count; i++) {
                var row = stockList.get(i);
                collect(row.ticker, row.price, row.pct);
            }
        } else {
            collect(applet.panelSymbol, applet.panelCurrentPrice, applet.panelCurrentPercent);
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
        var tagW = applet.showExtendedHours
                   ? Math.max(widthOf(probeTag, applet.tagAfterHours),
                              widthOf(probeTag, applet.tagPreMarket),
                              widthOf(probeTag, applet.tagClosed))
                   : 0;
        var line1 = widest(tickers, probeTicker) + 4 + arrowW
                    + (tagW > 0 ? 4 + tagW : 0);

        // Second line: price and change badge (or the wider of the two when they alternate).
        var priceW = widest(prices, probePrice);
        var showBadge = !applet.hideChangePercentage;
        var badgeW = showBadge ? widest(pcts, probeBadge) + (Kirigami.Units.smallSpacing * 2) : 0;
        var line2 = (applet.panelAlternate && showBadge) ? Math.max(priceW, badgeW)
                                                      : priceW + (showBadge ? 6 + badgeW : 0);

        // Width of the values on screen right now, so an orientation change cannot
        // leave the indicator narrower than its own content.
        var currentTicker = applet.displayTicker(applet.isMultiMode ? applet.panelTicker : applet.singleTicker);
        var showCurrentTag = applet.showExtendedHours
                             && (compactRoot.marketClosed || compactRoot.ext !== undefined);
        var currentTagW = showCurrentTag ? tagW : 0;
        var currentLine1 = widthOf(probeTicker, currentTicker) + 4 + arrowW
                           + (currentTagW > 0 ? 4 + currentTagW : 0);
        var currentPriceW = widthOf(probePrice, compactRoot.shownPrice);
        var currentBadgeW = showBadge
                            ? widthOf(probeBadge, compactRoot.shownPercent) + (Kirigami.Units.smallSpacing * 2)
                            : 0;
        var currentLine2 = (applet.panelAlternate && showBadge)
                           ? Math.max(currentPriceW, currentBadgeW)
                           : currentPriceW + (showBadge ? 6 + currentBadgeW : 0);

        return { "content": Math.ceil(Math.max(line1, line2)),
                 "price": Math.ceil(priceW),
                 "badge": Math.ceil(badgeW),
                 "current": Math.ceil(Math.max(currentLine1, currentLine2)) };
    }

    function remeasure() {
        var m = measureWidest();
        compactRoot.widestContent = m.content;
        compactRoot.widestPrice = m.price;
        compactRoot.widestBadge = m.badge;
        compactRoot.currentContent = m.current;
    }

    // Values arrive in bursts (one reply per ticker), so measure once they settle.
    Timer { id: remeasureTimer; interval: 100; onTriggered: compactRoot.remeasure() }
    Component.onCompleted: compactRoot.remeasure()
    Connections {
        target: stockList
        function onDataChanged() { remeasureTimer.restart(); }
        function onRowsInserted() { remeasureTimer.restart(); }
        function onRowsRemoved() { remeasureTimer.restart(); }
        function onModelReset() { remeasureTimer.restart(); }
    }
    Connections {
        target: applet
        function onExtendedDataChanged() { remeasureTimer.restart(); }
        function onPanelCurrentPriceChanged() { remeasureTimer.restart(); }
        function onPanelCurrentPercentChanged() { remeasureTimer.restart(); }
        function onSingleTickerChanged() { remeasureTimer.restart(); }
        function onIsMultiModeChanged() { remeasureTimer.restart(); }
        function onShowExtendedHoursChanged() { remeasureTimer.restart(); }
        function onHideChangePercentageChanged() { remeasureTimer.restart(); }
        function onPanelAlternateChanged() { remeasureTimer.restart(); }
        function onIsVerticalPanelChanged() { remeasureTimer.restart(); }
        function onSymbolDisplayModeChanged() { remeasureTimer.restart(); }
        function onPanelExchangeChanged() { remeasureTimer.restart(); }
        function onSingleExchangeChanged() { remeasureTimer.restart(); }
    }

    RowLayout {
        id: panelRow
        // Fill the rectangle the panel gives the applet, with a small side margin in
        // a horizontal panel. In a vertical panel the row fills the panel thickness
        // and the labels are centred/elided inside it. Filling also keeps the content
        // inside the applet instead of letting it spill over the neighbour.
        anchors.fill: parent
        anchors.leftMargin: applet.isVerticalPanel ? 0 : Kirigami.Units.smallSpacing * 2
        anchors.rightMargin: applet.isVerticalPanel ? 0 : Kirigami.Units.smallSpacing * 2
        spacing: 8

        ColumnLayout {
            // The status tag and the percentage badge share the right edge of the
            // indicator. Negative spacing made the bottom of the tag/arrow overlap
            // the top of the badge, so keep a small positive gap between the rows.
            spacing: 3
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: applet.isVerticalPanel

            RowLayout {
                spacing: 4
                Layout.fillWidth: applet.isVerticalPanel
                Text {
                    text: applet.displayTicker(applet.isMultiMode ? applet.panelTicker : applet.singleTicker)
                    color: applet.panelTextColor
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    opacity: 0.6
                    Layout.alignment: Qt.AlignBottom
                    Layout.fillWidth: applet.isVerticalPanel
                    horizontalAlignment: applet.isVerticalPanel ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight
                }
                // In a vertical panel only the ticker and the price fit in the panel
                // thickness; the colour already shows the direction and the tooltip
                // carries the session tag.
                Text {
                    visible: !applet.isVerticalPanel
                    text: compactRoot.shownPositive ? "▲" : "▼"
                    color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
                // Session tag: AH = after-hours, PRE = pre-market, CLOSED = the
                // exchange is not trading and there is no extended quote to show.
                Text {
                    visible: (compactRoot.ext !== undefined || compactRoot.marketClosed
                              || applet.panelCurrentIsCached) && !applet.isVerticalPanel
                    // While the values come from the config snapshot, mark them as
                    // stale instead of showing a session tag computed from live data.
                    text: applet.panelCurrentIsCached
                          ? i18nc("@item:panel stock data state", "OFF")
                          : (compactRoot.marketClosed
                             ? applet.tagClosed
                             : (compactRoot.ext
                                ? (compactRoot.ext.kind === "pre" ? applet.tagPreMarket : applet.tagAfterHours)
                                : ""))
                    color: applet.panelCurrentIsCached ? applet.warningTextColor : applet.panelTextColor
                    opacity: applet.panelCurrentIsCached ? 1.0 : 0.6
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
            }

            RowLayout {
                spacing: 6
                Layout.alignment: applet.isVerticalPanel ? Qt.AlignHCenter : Qt.AlignLeft
                Layout.fillWidth: applet.isVerticalPanel

                Text {
                    id: panelPrice
                    // The currency symbol does not fit in the panel thickness together
                    // with a five-digit price, and the ticker already identifies the
                    // instrument; the tooltip shows the full value.
                    text: {
                        var price = compactRoot.shownPrice;
                        return applet.isVerticalPanel && applet.currencySym !== ""
                               ? price.replace(applet.currencySym, "")
                               : price;
                    }
                    // When alternating, the price and the percentage badge share one spot:
                    // this item is hidden while the percentage is shown, and both keep the
                    // width of the wider one so the panel does not resize on every switch.
                    visible: !applet.panelAlternate || !applet.panelShowPercent
                    horizontalAlignment: applet.isVerticalPanel
                                         ? Text.AlignHCenter
                                         : (applet.panelAlternate ? Text.AlignHCenter : Text.AlignLeft)
                    // Fixed width: give the price the width of the widest price, so the badge
                    // next to it stays put while the price changes.
                    Layout.minimumWidth: applet.panelAlternate
                                         ? Math.max(panelPrice.implicitWidth, pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2))
                                         : (compactRoot.useFixedWidth ? compactRoot.widestPrice : 0)
                    Layout.fillWidth: applet.isVerticalPanel
                    elide: Text.ElideRight
                    color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    font.pixelSize: applet.isVerticalPanel
                                     ? (compactRoot.shownPrice.length > 7 ? 8 : 9)
                                     : 11
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    // Ensure the price text is fully opaque; color is controlled by the line above
                    // Cached startup values are dimmed, so they never read as live.
                    opacity: compactRoot.priceFlicker * (applet.panelCurrentIsCached ? 0.7 : 1.0)
                }

                Rectangle {
                    radius: 4
                    opacity: applet.panelCurrentIsCached ? 0.7 : 1.0
                    // Vertical Panel Support: Hide badge in vertical panels to avoid overlap
                    visible: Plasmoid.formFactor !== PlasmaCore.Types.Vertical && !applet.hideChangePercentage
                             && (!applet.panelAlternate || applet.panelShowPercent)
                    // Background: translucent tint of the positive/negative color for theme independence
                    color: compactRoot.shownPositive
                           ? Qt.rgba(applet.panelPositiveColor.r, applet.panelPositiveColor.g, applet.panelPositiveColor.b, 0.18)
                           : Qt.rgba(applet.panelNegativeColor.r, applet.panelNegativeColor.g, applet.panelNegativeColor.b, 0.18)
                    border.color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                    border.width: 1
                    Layout.preferredWidth: pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                    // Fixed width: every value gets the same badge width (the text stays centred),
                    // so the panel has no spare room on the right of a short value.
                    Layout.minimumWidth: applet.panelAlternate
                                         ? Math.max(panelPrice.implicitWidth, pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2))
                                         : (compactRoot.useFixedWidth ? compactRoot.widestBadge : 0)
                    Layout.preferredHeight: pctText2.implicitHeight + (Kirigami.Units.smallSpacing / 2)

                    Text {
                        id: pctText2
                        anchors.centerIn: parent
                        text: compactRoot.shownPercent
                        color: compactRoot.shownPositive ? applet.panelPositiveColor : applet.panelNegativeColor
                        font.pixelSize: 10
                        font.weight: Font.Black
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
