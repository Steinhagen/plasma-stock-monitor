// Delegates (all with required properties) may use the ids of this file, such as
// singleStockRoot and newsList.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import "chartcurve.js" as ChartCurve

Rectangle {
    id: singleStockRoot

    property var rootItem

    // Widths for the header cap. TextMetrics is available as soon as the view is
    // built, unlike the width of a Text created later in the layout.
    TextMetrics {
        id: singleArrowMetrics
        font.pixelSize: 12
        text: "▲"
    }
    TextMetrics {
        id: singleExchangeMetrics
        font.pixelSize: 9
        font.bold: true
        text: rootItem.exchangeBadge(rootItem.singleTicker, rootItem.singleExchange)
    }

    // Hover crosshair state for the chart. Coordinates are local to the chart canvas.
    property bool chartHoverActive: false
    property real chartHoverX: 0

    // Background of the selected Chart/News icon, the same tint as a selected chart button.
    readonly property color selectedTint: Qt.rgba(rootItem.tickerColor.r, rootItem.tickerColor.g, rootItem.tickerColor.b, 0.14)
    // News pane: the headlines replace the chart; the cache and the fetch live in main.qml.
    readonly property bool newsMode: rootItem.newsAvailable && rootItem.singleViewPane === "news"
    readonly property var newsEntry: rootItem.newsEntry
    // Distinct sources among the shown headlines, in the order their newest item appears.
    // Other providers (BVB, for example) will add their label to the items they return.
    readonly property var newsSources: {
        var seen = {};
        var sources = [];
        var items = rootItem.newsItems;
        for (var i = 0; i < items.length; i++) {
            var source = String(items[i].source || "").trim();
            if (source === "" || seen[source]) continue;
            seen[source] = true;
            sources.push(source);
        }
        // Yahoo is the primary feed, BVB follows; unknown providers are alphabetical.
        var order = ["Yahoo", "BVB"];
        sources.sort(function(a, b) {
            var ia = order.indexOf(a);
            var ib = order.indexOf(b);
            if (ia < 0) ia = order.length;
            if (ib < 0) ib = order.length;
            return ia !== ib ? ia - ib : a.localeCompare(b);
        });
        return sources;
    }
    // "" is All. A selection that is no longer among the sources falls back to All, so a
    // refresh that drops a source never leaves an empty list.
    property string newsSource: ""
    readonly property bool newsFilterRelevant: newsSources.length > 1
    readonly property string newsSourceFilter: newsSources.indexOf(newsSource) >= 0 ? newsSource : ""
    readonly property bool newsMoreIsBvb: newsSourceFilter === "BVB"
                                          || (newsSources.length === 1 && newsSources[0] === "BVB")
    readonly property var newsFilteredItems: {
        var items = rootItem.newsItems;
        if (newsSourceFilter === "") return items;
        var filtered = [];
        for (var i = 0; i < items.length; i++) {
            if (String(items[i].source || "") === newsSourceFilter) filtered.push(items[i]);
        }
        return filtered;
    }
    // One button per source; All is added only when there is something to choose between.
    readonly property var newsSourceButtons: {
        var sources = newsSources;
        var buttons = [];
        if (sources.length > 1) buttons.push({ source: "", label: i18nc("@item:news source", "All") });
        for (var i = 0; i < sources.length; i++) buttons.push({ source: sources[i], label: sources[i] });
        return buttons;
    }
    readonly property bool newsHasItems: newsFilteredItems.length > 0
    // Centered message instead of the list: loading, nothing found, or no reply at all.
    readonly property string newsStateText: {
        if (newsHasItems) return "";
        if (!newsEntry || newsEntry.pending || (!newsEntry.loaded && !newsEntry.error))
            return i18n("Loading headlines…");
        if (newsEntry.error) return i18n("Headlines unavailable");
        return i18n("No recent headlines for %1", rootItem.displayTicker(rootItem.singleTicker));
    }
    // A failed update keeps the headlines that are already shown and says so here.
    readonly property bool newsHeaderWarning: newsEntry !== null && newsEntry.error && newsHasItems
    readonly property string newsHeaderText: {
        if (newsHeaderWarning) return i18n("Could not update headlines");
        if (newsEntry && newsEntry.loaded && newsEntry.time > 0)
            return i18n("Updated %1", rootItem.newsAge(newsEntry.time / 1000));
        return "";
    }

    // Extended quote and market session for the compact quote block. `extendedQuote`
    // is undefined while the regular session is running or when extended data is off.
    readonly property var extendedQuote: rootItem.extendedQuote(rootItem.singleTicker)
    readonly property bool hasExtendedQuote: extendedQuote !== undefined && extendedQuote !== null
    readonly property string marketSession: rootItem.marketStatusFor(rootItem.singleTicker)
    // Instruments without extended-hours trading (indices, for example) still report the
    // exchange's pre/post windows, but they are effectively closed during them. The list
    // already uses isMarketClosedFor() for that; the header must agree with it.
    readonly property bool marketClosed: rootItem.isMarketClosedFor(rootItem.singleTicker)
    readonly property string marketSessionText: {
        switch (marketSession) {
            case "pre":    return marketClosed
                                  ? i18nc("@item:market session status", "Closed")
                                  : i18nc("@item:market session status", "Pre-market");
            case "open":   return i18nc("@item:market session status", "Open");
            case "post":
            case "closed": return i18nc("@item:market session status", "Closed");
            default:       return "";
        }
    }
    readonly property color marketSessionColor: marketSession === "pre" && !marketClosed
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
        // No extended quote can exist for these instruments, so the note would be noise.
        if (!rootItem.hasPrePostDataFor(rootItem.singleTicker)) return "";
        if (marketSession === "pre") return i18n("No pre-market quote");
        return i18n("No after-hours quote");
    }

    // Tooltip of the market status in the header. Yahoo Finance does not expose the feed
    // delay per exchange through the chart API, so the quote timestamp is shown next to
    // the widget's own refresh time instead of a hard-coded "15 minutes" that would be
    // wrong for exchanges with real-time data.
    readonly property bool marketDataAvailable: rootItem.lastUpdated !== ""
                                                 || rootItem.quoteTimestamp > 0
    readonly property bool waitingForFirstQuote: rootItem.awaitingFirstRegularQuote(rootItem.singleTicker)
    readonly property string marketDataQuoteTime: {
        // During the opening seconds the regular quote is still the previous close;
        // show the pre-market quote time that is actually on screen instead.
        var timestamp = singleStockRoot.extendedQuote && singleStockRoot.extendedQuote.time
                        ? singleStockRoot.extendedQuote.time : rootItem.quoteTimestamp;
        if (!(timestamp > 0)) return "";
        return new Date(timestamp * 1000)
            .toLocaleTimeString(Qt.locale(), "HH:mm");
    }
    readonly property string marketDataUpdatedLine: {
        // The cached startup values replace the usual line so their age stays visible.
        if (rootItem.currentShowingCached) return rootItem.currentStatusText;
        if (rootItem.lastUpdated === "") return "";
        return rootItem.nextUpdate !== ""
            ? i18n("Updated %1 · Next %2", rootItem.lastUpdated, rootItem.nextUpdate)
            : i18n("Updated %1", rootItem.lastUpdated);
    }
    readonly property string marketDataRefreshLabel: i18n("Refresh %1 min", rootItem.refreshIntervalMinutes)
    // Amber is too bright on a light tooltip and too dim on a dark one; pick a shade
    // that stays readable on the Plasma tooltip background.
    readonly property color marketDataWarnColor: Kirigami.Theme.backgroundColor.hslLightness > 0.5
                                                 ? "#8a5a00" : "#e0b25a"
    readonly property color marketDataWarnBackground: Qt.rgba(marketDataWarnColor.r,
                                                               marketDataWarnColor.g,
                                                               marketDataWarnColor.b, 0.10)

    // The 1D chart shows a previous trading session when there is nothing current yet
    // (weekend, holiday, or before the pre-market's first quote). Label it so the older
    // session is not read as today's; the previous close in the legend belongs to it too.
    readonly property string chartSessionNote: {
        if (rootItem.effectiveChartRange !== "1D") return "";
        if (rootItem.chartSessionCurrent || !(rootItem.chartSessionStart > 0)) return "";
        var session = new Date(rootItem.chartSessionStart * 1000);
        var now = new Date();
        var yesterday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        if (session.getFullYear() === yesterday.getFullYear()
                && session.getMonth() === yesterday.getMonth()
                && session.getDate() === yesterday.getDate())
            return i18n("Yesterday's session");
        return i18n("Session of %1", session.toLocaleDateString(Qt.locale(), "d MMM"));
    }

    // Minimum width of the card. It deliberately comes from the chart controls and a fixed
    // floor, not from contentColumn.implicitWidth: prices, percentages, company names and
    // positions change with the selected ticker and range, and using them made the minimum
    // (and therefore the split between the two desktop columns) move by a few pixels. Text
    // that grows with data no longer widens the card; it keeps its own elision/clipping.
    // Measure both control groups even when one is hidden: the range row alone stays under
    // the floor, while range + style crosses it, so deriving this from the visible row made
    // enabling the style buttons resize the whole applet. The reserved width never moves
    // when an option is toggled.
    readonly property real chartControlsWidth: chartRangeButtons.implicitWidth
                                                + chartStyleButtons.implicitWidth
                                                + 2 * chartHeaderRow.spacing
    readonly property real minimumContentWidth: Math.max(300, Math.ceil(chartControlsWidth) + 32)
    // Fixed floor, not content-derived: the extended-hours quote row appears and
    // disappears with the session. A moving minimum made Plasma resize the widget
    // when the row changed or when the widget was opened on an empty virtual desktop.
    readonly property real minimumContentHeight: 360

    // The Application preset paints its own rounded card; with Plasma the system
    // background shows through and this view stays transparent.
    color: rootItem.bgColor
    radius: rootItem.appDrawnSurface ? 22 : 0
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
                    id: headerNameColumn
                    spacing: 2
                    // Never let a stale or too-wide name paint over the status and the
                    // Chart/News icons; the elision keeps it inside in normal use.
                    clip: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                    // Take the space left of the status, so a long "Name (TICK)"
                    // is elided instead of pushing the status out of the card.
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    RowLayout {
                        id: singleHeaderNameRow
                        Layout.fillWidth: true
                        spacing: 5

                        readonly property real badgeWidth: singleExchangeBadge.visible
                            ? Math.ceil(singleExchangeMetrics.advanceWidth)
                              + Kirigami.Units.smallSpacing * 2 : 0
                        // Derive the room from the card, not from this row's own width. A
                        // width read back from the layout feeds the elided text into the
                        // row's implicit width; when the status line appears the row can
                        // then no longer shrink, so the full name is painted over the
                        // status and the Chart/News icons. Reserving the status row here
                        // keeps the calculation one-way.
                        readonly property real nameMaxWidth: Math.max(0, contentColumn.width
                            - (headerStatusRow.visible ? headerStatusRow.implicitWidth
                               + headerStatusRow.Layout.leftMargin : 0)
                            - Math.max(10, Math.ceil(singleArrowMetrics.advanceWidth))
                            - (singleExchangeBadge.visible ? badgeWidth + 4 : 0)
                            - spacing * 2)

                        Text {
                            text: rootItem.isPositive ? "▲" : "▼"
                            color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Row {
                            id: singleNameGroup
                            // The name already carries its own elided width; let the
                            // layout shrink the group to it instead of treating the full
                            // company name as an unbreakable minimum.
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Text {
                                id: singleNameText
                                FontMetrics { id: singleNameMetrics; font: singleNameText.font }
                                // Use the header width available to the name, not this Text.width:
                                // width depends on implicitWidth, which depends on the text.
                                text: rootItem.showNameAndTicker
                                      ? rootItem.fitNameAndTicker(rootItem.singleCompanyName, rootItem.displayTicker(rootItem.singleTicker), singleHeaderNameRow.nameMaxWidth, singleNameMetrics)
                                      : (rootItem.swapNameAndTicker ? rootItem.singleCompanyName : rootItem.displayTicker(rootItem.singleTicker))
                                // The name keeps its natural width so the badge follows
                                // it, but never takes room from the status on the right.
                                width: Math.min(implicitWidth, singleHeaderNameRow.nameMaxWidth)
                                color: rootItem.tickerColor
                                opacity: rootItem.tickerOpacity / 100.0
                                font.bold: true
                                font.pixelSize: 15
                                font.family: "Arial"
                                elide: Text.ElideRight
                            }
                            // Short exchange label, e.g. BVB for BRD.RO, in the same mode as
                            // the watchlist. The full exchange name is in the tooltip.
                            Rectangle {
                                id: singleExchangeBadge
                                readonly property string label: rootItem.exchangeBadge(rootItem.singleTicker, rootItem.singleExchange)
                                visible: label !== ""
                                width: singleHeaderNameRow.badgeWidth
                                height: singleExchangeText.implicitHeight + Kirigami.Units.smallSpacing / 2
                                y: (singleNameGroup.height - height) / 2
                                radius: 3
                                color: Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g,
                                               rootItem.secondaryTextColor.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(rootItem.secondaryTextColor.r, rootItem.secondaryTextColor.g,
                                                      rootItem.secondaryTextColor.b, 0.35)

                                Text {
                                    id: singleExchangeText
                                    anchors.centerIn: parent
                                    text: singleExchangeBadge.label
                                    color: rootItem.secondaryTextColor
                                    font.pixelSize: 9
                                    font.bold: true
                                    opacity: 0.85
                                }
                                HoverHandler { id: singleExchangeHover }
                                ToolTip.visible: singleExchangeHover.hovered
                                ToolTip.text: rootItem.singleExchangeFull || rootItem.singleExchange
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Text {
                        // The first line already carries the company name when name and ticker are shown together.
                        visible: !rootItem.showNameAndTicker
                        text: rootItem.swapNameAndTicker
                              ? rootItem.displayTicker(rootItem.singleTicker) : rootItem.singleCompanyName
                        color: rootItem.secondaryTextColor
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: rootItem.currentStatusText
                        color: rootItem.currentShowingCached ? rootItem.warningTextColor
                                                              : rootItem.secondaryTextColor
                        font.pixelSize: 9
                        // Cached values keep their age visible even when the user hid
                        // the normal refresh timestamps. The date makes the line longer
                        // than the usual time, so it must elide inside the card.
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: rootItem.lastUpdated !== ""
                                 && (!rootItem.isMultiMode || rootItem.currentShowingCached)
                                 && (!rootItem.hideTimestamps || rootItem.currentShowingCached)
                    }
                }

                // The market status and the Chart/News icons share one row, so both are
                // centered on the icons' 20 px height. With the news off the row holds only
                // the status, at the same place as before.
                RowLayout {
                    id: headerStatusRow
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    Layout.leftMargin: 8
                    // The 20 px icon buttons are taller than a name line alone. They may overhang
                    // the row by a pixel or two, but never make the header taller than before.
                    Layout.maximumHeight: headerNameColumn.implicitHeight
                    spacing: 10
                    // Not bound to marketStatusTip.visible: a child reads as hidden while its
                    // parent is, so the row could never show again. Without this, an empty row
                    // would still keep its margin from the name while the status is hidden.
                    visible: singleStockRoot.marketSessionText !== "" || singleStockRoot.rootItem.newsAvailable

                    // The status (open/closed) doubles as the data-freshness affordance: its
                    // tooltip says how often the widget polls and when Yahoo last quoted this
                    // instrument, so delayed exchange data is visible without extra chrome.
                    PlasmaCore.ToolTipArea {
                        id: marketStatusTip
                        Layout.alignment: singleStockRoot.rootItem.newsAvailable ? Qt.AlignVCenter : Qt.AlignTop
                        implicitWidth: marketStatusRow.implicitWidth
                        implicitHeight: marketStatusRow.implicitHeight
                        visible: singleStockRoot.marketSessionText !== ""
                        active: singleStockRoot.marketDataAvailable
                        mainText: i18n("Market data")
                        mainItem: ColumnLayout {
                            implicitWidth: 340
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: singleStockRoot.marketSessionColor
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: i18n("Market data")
                                    color: Kirigami.Theme.textColor
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: marketTipRefreshLabel.implicitWidth + 12
                                    implicitHeight: marketTipRefreshLabel.implicitHeight + 4
                                    radius: height / 2
                                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                   Kirigami.Theme.textColor.g,
                                                   Kirigami.Theme.textColor.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                                          Kirigami.Theme.textColor.g,
                                                          Kirigami.Theme.textColor.b, 0.12)

                                    Text {
                                        id: marketTipRefreshLabel
                                        anchors.centerIn: parent
                                        text: singleStockRoot.marketDataRefreshLabel
                                        color: Kirigami.Theme.disabledTextColor
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: singleStockRoot.marketDataUpdatedLine
                                color: Kirigami.Theme.textColor
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: singleStockRoot.marketDataQuoteTime !== ""

                                Text {
                                    text: i18n("Yahoo quote %1", singleStockRoot.marketDataQuoteTime)
                                    color: Kirigami.Theme.disabledTextColor
                                    font.pixelSize: 10
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: marketTipDelayLabel.implicitWidth + 12
                                    implicitHeight: marketTipDelayLabel.implicitHeight + 4
                                    radius: height / 2
                                    color: singleStockRoot.marketDataWarnBackground
                                    border.width: 1
                                    border.color: Qt.rgba(singleStockRoot.marketDataWarnColor.r,
                                                          singleStockRoot.marketDataWarnColor.g,
                                                          singleStockRoot.marketDataWarnColor.b, 0.28)

                                    Text {
                                        id: marketTipDelayLabel
                                        anchors.centerIn: parent
                                        text: i18n("may be delayed")
                                        color: singleStockRoot.marketDataWarnColor
                                        font.pixelSize: 9
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: singleStockRoot.waitingForFirstQuote
                                text: i18n("The market is open; waiting for its first regular quote.")
                                color: Kirigami.Theme.disabledTextColor
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }

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
                                // Centering the line box puts the x-height center 1 px below
                                // the dot and the icons; this lifts the text by 1 px (the dot
                                // stays centered on the taller cell).
                                Layout.bottomMargin: singleStockRoot.rootItem.newsAvailable ? 2 : 0
                            }
                        }
                    }

                    // Chart / News view selector, at the right edge of the header so it does
                    // not move with the length of the name. Hidden (not laid out) when the
                    // news is off.
                    Row {
                        id: viewPaneButtons
                        Layout.alignment: Qt.AlignVCenter
                        visible: singleStockRoot.rootItem.newsAvailable
                        spacing: 2

                        Repeater {
                            model: [
                                { pane: "chart", icon: "office-chart-line", tip: i18nc("@info:tooltip", "Chart") },
                                { pane: "news", icon: "news-subscribe", tip: i18nc("@info:tooltip", "News") }
                            ]
                            delegate: PlasmaCore.ToolTipArea {
                                id: paneButton
                                required property var modelData
                                readonly property bool selected: singleStockRoot.rootItem.singleViewPane === modelData.pane
                                width: 22
                                height: 20
                                mainText: modelData.tip

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: paneButton.selected ? singleStockRoot.selectedTint
                                           : (paneMouse.containsMouse
                                              ? Qt.rgba(singleStockRoot.rootItem.tickerColor.r,
                                                        singleStockRoot.rootItem.tickerColor.g,
                                                        singleStockRoot.rootItem.tickerColor.b, 0.07)
                                              : "transparent")
                                }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: paneButton.modelData.icon
                                    isMask: true
                                    color: paneButton.selected ? singleStockRoot.rootItem.tickerColor
                                                               : singleStockRoot.rootItem.secondaryTextColor
                                }

                                MouseArea {
                                    id: paneMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: singleStockRoot.rootItem.singleViewPane = paneButton.modelData.pane
                                }
                            }
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
                // Width shared by the two columns: the row minus the divider and its margins.
                readonly property real avail: width - extendedDivider.Layout.preferredWidth
                                              - extendedDivider.Layout.leftMargin - extendedDivider.Layout.rightMargin
                visible: singleStockRoot.hasExtendedQuote
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                Layout.topMargin: 4
                spacing: 0

                ColumnLayout {
                    // Half of the row, not a share proportional to the text widths: with two
                    // fillWidth columns the divider moved with every price (and jumped while
                    // the price showed "—"). The column grows past half only when its own
                    // content needs it, and gives up room when the extended column needs it.
                    Layout.fillWidth: false
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: Math.max(Math.ceil(implicitWidth),
                                                    Math.min(extendedQuoteRow.avail / 2,
                                                             extendedQuoteRow.avail - Math.ceil(extendedColumn.implicitWidth)))
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
                        text: singleStockRoot.waitingForFirstQuote ? "—" : rootItem.currentPrice
                        color: rootItem.priceColor
                        opacity: rootItem.priceOpacity / 100.0
                        font.pixelSize: 25
                        Layout.fillWidth: true
                        elide: Text.ElideRight

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Text {
                        text: singleStockRoot.waitingForFirstQuote ? ""
                              : (rootItem.priceChange !== ""
                                 ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : "")
                        color: rootItem.isPositive ? rootItem.positiveColor : rootItem.negativeColor
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    id: extendedDivider
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 46
                    Layout.leftMargin: 12
                    Layout.rightMargin: 12
                    Layout.alignment: Qt.AlignVCenter
                    color: rootItem.isLightTheme ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.075)
                }

                ColumnLayout {
                    id: extendedColumn
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
                    text: singleStockRoot.waitingForFirstQuote ? "—" : rootItem.currentPrice
                    color: rootItem.priceColor
                    opacity: rootItem.priceOpacity / 100.0
                    font.pixelSize: 25
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth

                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    text: singleStockRoot.waitingForFirstQuote ? ""
                          : (rootItem.priceChange !== ""
                             ? rootItem.priceChange + " (" + rootItem.percentChange + ")" : "")
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
                // The news pane needs the row for its "Updated…" line and refresh button, but
                // merely enabling the news must not reserve an empty bar over the chart.
                visible: singleStockRoot.rootItem.showChartRangeButtons
                         || singleStockRoot.rootItem.showChartStyleButtons
                         || singleStockRoot.chartSessionNote !== ""
                         || singleStockRoot.newsMode
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 2
                Layout.preferredHeight: Math.max(
                    singleStockRoot.rootItem.showChartRangeButtons ? chartRangeButtons.implicitHeight : 0,
                    singleStockRoot.rootItem.showChartStyleButtons ? 18 : 0,
                    singleStockRoot.chartSessionNote !== "" ? 14 : 0,
                    singleStockRoot.newsMode ? 18 : 0)
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
                    // Stays laid out with the headlines (so the card's minimum width does
                    // not change when switching) but is not shown and takes no clicks.
                    opacity: singleStockRoot.newsMode ? 0 : 1
                    enabled: !singleStockRoot.newsMode

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

                // Pushes the chart type selector to the right edge. The session note is
                // anchored inside this gap, so it never changes the card's minimum width.
                Item {
                    id: chartHeaderGap
                    Layout.fillWidth: true

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: singleStockRoot.chartSessionNote
                        visible: text !== "" && !singleStockRoot.newsMode
                        color: rootItem.secondaryTextColor
                        opacity: 0.8
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    // News header. A plain child of the gap Item, placed over the whole
                    // header row, so it never takes part in the row's layout.
                    Item {
                        visible: singleStockRoot.newsMode
                        x: -chartHeaderGap.x
                        y: -chartHeaderGap.y
                        width: chartHeaderRow.width
                        height: chartHeaderRow.height

                        RowLayout {
                            anchors.fill: parent
                            spacing: 6

                            // Source filters, in the same compact style as the chart
                            // range buttons.
                            Row {
                                id: newsSourceFilters
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 3

                                Repeater {
                                    model: singleStockRoot.newsSourceButtons
                                    delegate: Rectangle {
                                        id: newsSourceButton
                                        required property var modelData
                                        objectName: "newsSourceButton_" + (newsSourceButton.modelData.source === ""
                                                                            ? "all" : newsSourceButton.modelData.source)
                                        readonly property bool selected: !singleStockRoot.newsFilterRelevant
                                                                         || singleStockRoot.newsSourceFilter === newsSourceButton.modelData.source
                                        width: newsSourceButtonLabel.implicitWidth + 8
                                        height: 18
                                        radius: 4
                                        color: newsSourceButton.selected
                                               ? singleStockRoot.selectedTint
                                               : (newsSourceMouse.containsMouse
                                                  ? Qt.rgba(singleStockRoot.rootItem.tickerColor.r,
                                                            singleStockRoot.rootItem.tickerColor.g,
                                                            singleStockRoot.rootItem.tickerColor.b, 0.07)
                                                  : "transparent")

                                        Text {
                                            id: newsSourceButtonLabel
                                            anchors.centerIn: parent
                                            text: newsSourceButton.modelData.label
                                            textFormat: Text.PlainText
                                            color: newsSourceButton.selected ? singleStockRoot.rootItem.tickerColor
                                                                             : singleStockRoot.rootItem.secondaryTextColor
                                            font.pixelSize: 9
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: newsSourceMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                singleStockRoot.newsSource = newsSourceButton.modelData.source;
                                                newsList.positionViewAtBeginning();
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter
                                horizontalAlignment: Text.AlignRight
                                text: singleStockRoot.newsHeaderText
                                textFormat: Text.PlainText
                                color: singleStockRoot.newsHeaderWarning ? singleStockRoot.rootItem.warningTextColor
                                                                         : singleStockRoot.rootItem.secondaryTextColor
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            PlasmaCore.ToolTipArea {
                                id: newsRefreshButton
                                Layout.alignment: Qt.AlignVCenter
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 18
                                mainText: i18n("Refresh news")

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: newsRefreshMouse.containsMouse ? singleStockRoot.selectedTint : "transparent"
                                }
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    source: "view-refresh"
                                    isMask: true
                                    color: singleStockRoot.rootItem.secondaryTextColor
                                    opacity: singleStockRoot.newsEntry && singleStockRoot.newsEntry.pending ? 0.5 : 1
                                }
                                MouseArea {
                                    id: newsRefreshMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: singleStockRoot.rootItem.requestNews(singleStockRoot.rootItem.singleTicker, true)
                                }
                            }
                        }
                    }
                }
                // Chart type selector, same look as the range buttons. It writes the same
                // setting as the Chart & News page.
                Row {
                    id: chartStyleButtons
                    objectName: "chartStyleButtons"
                    visible: rootItem.showChartStyleButtons
                    opacity: singleStockRoot.newsMode ? 0 : 1
                    enabled: !singleStockRoot.newsMode
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
                    visible: !singleStockRoot.newsMode
                             && Array.isArray(rootItem.chartDataPoints) && rootItem.chartDataPoints.length > 0
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
                        function onChartLineStyleChanged() { singleCanvas.requestPaint(); }
                        function onChartCandlesChanged() { singleCanvas.requestPaint(); }
                        function onChartReferencePriceChanged() { singleCanvas.requestPaint(); }
                        function onChartSessionsChanged() { singleCanvas.requestPaint(); }
                        function onChartPreSessionChanged() { singleCanvas.requestPaint(); }
                        // Theme changes alter the colors used while painting (and the
                        // light/dark details), so repaint without waiting for new data.
                        function onIsLightThemeChanged() { singleCanvas.requestPaint(); }
                        function onChartBaseColorChanged() { singleCanvas.requestPaint(); }
                        function onSecondaryTextColorChanged() { singleCanvas.requestPaint(); }
                        function onPositiveColorChanged() { singleCanvas.requestPaint(); }
                        function onNegativeColorChanged() { singleCanvas.requestPaint(); }
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
                    // Do not bring back a stale crosshair when returning to the chart.
                    Connections {
                        target: singleStockRoot.rootItem
                        function onSingleViewPaneChanged() {
                            singleStockRoot.chartHoverActive = false;
                            singleCanvas.requestPaint();
                        }
                    }
                }

                // --- News pane: the headline list replaces the chart. ---
                // Right click on the empty pane (loading or no headlines) opens the menu too.
                MouseArea {
                    anchors.fill: parent
                    visible: singleStockRoot.newsMode
                    acceptedButtons: Qt.RightButton
                    onClicked: newsMenu.popup()
                }

                ListView {
                    id: newsList
                    anchors.fill: parent
                    visible: singleStockRoot.newsMode && singleStockRoot.newsHasItems
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: singleStockRoot.newsFilteredItems
                    // Shown whenever the headlines overflow (not only while scrolling), so
                    // the user can tell there is more below the visible rows.
                    //
                    // Do not bind this to contentHeight: a wrapped headline is taller when
                    // the rows are narrower, so overflow -> rowWidth -> contentHeight ->
                    // overflow is a binding loop. Track it imperatively instead. It settles
                    // because widening the rows can only make the content shorter.
                    property bool overflows: false
                    function refreshOverflow() {
                        if (height <= 0) return;
                        if (!overflows && contentHeight > height + 1) overflows = true;
                        else if (overflows && contentHeight <= height) overflows = false;
                    }
                    onContentHeightChanged: refreshOverflow()
                    onHeightChanged: refreshOverflow()
                    // Rows and footer end left of the scrollbar, so it never covers a
                    // separator, the hover tint or the text.
                    readonly property real rowWidth: width - (overflows ? newsScrollBar.width + 4 : 0)
                    ScrollBar.vertical: ScrollBar {
                        id: newsScrollBar
                        policy: newsList.overflows ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    delegate: PlasmaCore.ToolTipArea {
                        id: newsRow
                        required property var modelData
                        required property int index
                        width: newsList.rowWidth
                        height: newsRowColumn.implicitHeight + 13
                        // The full title, only when the row had to shorten it.
                        mainText: newsRow.modelData.title
                        active: newsTitle.truncated

                        Rectangle {
                            anchors.fill: parent
                            anchors.bottomMargin: 1
                            radius: 4
                            visible: newsRowMouse.containsMouse
                            color: Qt.rgba(singleStockRoot.rootItem.tickerColor.r,
                                           singleStockRoot.rootItem.tickerColor.g,
                                           singleStockRoot.rootItem.tickerColor.b, 0.06)
                        }

                        ColumnLayout {
                            id: newsRowColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -0.5
                            spacing: 3

                            // Plain text: a headline is never rendered as markup.
                            Text {
                                id: newsTitle
                                Layout.fillWidth: true
                                text: newsRow.modelData.title
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                color: singleStockRoot.rootItem.tickerColor
                                font.pixelSize: 11
                            }
                            Text {
                                Layout.fillWidth: true
                                readonly property string age: singleStockRoot.rootItem.newsAge(newsRow.modelData.time)
                                text: newsRow.modelData.publisher !== ""
                                      ? (age !== "" ? newsRow.modelData.publisher + " · " + age : newsRow.modelData.publisher)
                                      : age
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: singleStockRoot.rootItem.secondaryTextColor
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: singleStockRoot.rootItem.chartBaseColor
                        }

                        MouseArea {
                            id: newsRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) newsMenu.popup();
                                else singleStockRoot.rootItem.openNewsLink(newsRow.modelData.link);
                            }
                        }
                    }

                    footer: Item {
                        width: newsList.rowWidth
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: (singleStockRoot.newsMoreIsBvb ? i18n("More on BVB")
                                                                 : i18n("More on Yahoo Finance")) + " ›"
                            textFormat: Text.PlainText
                            color: singleStockRoot.rootItem.secondaryTextColor
                            font.pixelSize: 9
                            font.bold: true

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (singleStockRoot.newsMoreIsBvb)
                                        singleStockRoot.rootItem.openBvbNews(singleStockRoot.rootItem.singleTicker);
                                    else
                                        singleStockRoot.rootItem.openYahooNews(singleStockRoot.rootItem.singleTicker);
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 24
                    visible: singleStockRoot.newsMode && singleStockRoot.newsStateText !== ""
                    text: singleStockRoot.newsStateText
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: singleStockRoot.rootItem.secondaryTextColor
                    font.pixelSize: 10
                }

                Menu {
                    id: newsMenu

                    MenuItem {
                        text: i18n("Open on Yahoo Finance")
                        onTriggered: singleStockRoot.rootItem.openYahooNews(singleStockRoot.rootItem.singleTicker)
                    }
                    MenuItem {
                        text: i18n("Open on BVB")
                        visible: singleStockRoot.newsSources.indexOf("BVB") >= 0
                        onTriggered: singleStockRoot.rootItem.openBvbNews(singleStockRoot.rootItem.singleTicker)
                    }
                    MenuItem {
                        text: i18n("Refresh news")
                        onTriggered: singleStockRoot.rootItem.requestNews(singleStockRoot.rootItem.singleTicker, true)
                    }
                }

                // The hover/click area lives inside the chart now. It must not cover the
                // range buttons above the plot.
                MouseArea {
                    id: chartMouseArea
                    anchors.fill: parent
                    visible: !singleStockRoot.newsMode
                    z: 100
                    hoverEnabled: true
                    cursorShape: singleStockRoot.chartHoverActive ? Qt.CrossCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onPositionChanged: (mouse) => {
                        singleStockRoot.chartHoverActive = true;
                        singleStockRoot.chartHoverX = mouse.x;
                    }
                    onExited: singleStockRoot.chartHoverActive = false

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (rootItem.performMiddleClick(rootItem.singleTicker)) {
                                if (priceText) priceText.opacity = 0.3;
                                if (priceTextCompact) priceTextCompact.opacity = 0.3;
                                timerFullFlicker.restart();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            chartMenu.popup();
                        }
                    }
                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton)
                            rootItem.performDoubleClick(rootItem.singleTicker);
                    }

                    Menu {
                        id: chartMenu

                        MenuItem {
                            text: i18n("Open on Yahoo Finance")
                            onTriggered: rootItem.openYahooQuote(rootItem.singleTicker)
                        }
                        MenuItem {
                            text: i18n("Refresh")
                            onTriggered: rootItem.refreshData()
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
    // Settings → Chart selects between:
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

    // The price line through the closes. "Straight" joins the points with plain segments.
    // "Smooth" uses monotone cubic interpolation (no overshoot, no loops) and keeps
    // segments across large time gaps straight; see chartcurve.js.
    // `xs` (optional) gives the pixel x of every point; without it the points are spread
    // evenly over 0..right. `times` (optional) are the timestamps, used to find gaps.
    function traceSmooth(ctx, data, right, getY, xs, times) {
        var n = data.length;
        if (n < 2) return;
        var stepX = right / (n - 1);
        function px(i) { return xs ? xs[i] : i * stepX; }
        ctx.beginPath();
        ctx.moveTo(px(0), getY(data[0]));
        if (rootItem.chartLineStyle === 1 || n < 3) {
            for (var j = 1; j < n; j++) ctx.lineTo(px(j), getY(data[j]));
            return;
        }
        var px_ = [], py_ = [];
        for (var k = 0; k < n; k++) {
            px_.push(px(k));
            py_.push(getY(data[k]));
        }
        var gaps = ChartCurve.gapFlags(times && times.length === n ? times : null);
        var m = ChartCurve.monotoneTangents(px_, py_, gaps);
        for (var i = 0; i < n - 1; i++) {
            if (gaps[i] || !(px_[i + 1] > px_[i])) {
                ctx.lineTo(px_[i + 1], py_[i + 1]);
                continue;
            }
            var c = ChartCurve.segmentControls(px_, py_, m, i);
            ctx.bezierCurveTo(c.c1x, c.c1y, c.c2x, c.c2y, px_[i + 1], py_[i + 1]);
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
        traceSmooth(ctx, data, plotRight, getY, xsReg, times);
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
        traceSmooth(ctx, data, plotRight, getY, xsReg, times);
        ctx.lineTo(xLast, refY);
        ctx.lineTo(xFirst, refY);
        ctx.closePath();
        ctx.fillStyle = below;
        ctx.fill();
        ctx.restore();

        // A pre-market-only chart is entirely extended-hours data; hatch it like the
        // pre-market zone of a full-day chart.
        if (rootItem.chartPreSession) drawHatch(ctx, 0, plotRight, plotH);

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
        function strokeSplit(values, xs, ts) {
            ctx.save();
            ctx.beginPath();
            ctx.rect(0, 0, plotRight, refY);
            ctx.clip();
            ctx.strokeStyle = pos;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs, ts);
            ctx.stroke();
            ctx.restore();

            ctx.save();
            ctx.beginPath();
            ctx.rect(0, refY, plotRight, Math.max(1, plotH - refY));
            ctx.clip();
            ctx.strokeStyle = neg;
            ctx.lineWidth = 2;
            traceSmooth(ctx, values, plotRight, getY, xs, ts);
            ctx.stroke();
            ctx.restore();
        }

        // The line changes colour exactly at the reference.
        strokeSplit(data, xsReg, times);

        // Extended-hours parts of the line: same reference split, no fill. Each segment
        // starts or ends on the neighbouring regular point so the line stays continuous.
        var regularClose = rootItem.currentRawPrice > 0 ? rootItem.currentRawPrice : data[nReg - 1];
        if (nPre > 0)
            strokeSplit(allData.slice(0, nPre + 1), xsAll.slice(0, nPre + 1), allTimes.slice(0, nPre + 1));
        if (nPost > 0)
            strokeSplit(allData.slice(nPre + nReg - 1), xsAll.slice(nPre + nReg - 1), allTimes.slice(nPre + nReg - 1));
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
            var index, hoverX, hoverPrice, hoverTime, hoverBase = ref;
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
                } else if (index >= nPre + nReg) {
                    hoverTime += " " + rootItem.tagAfterHours;
                    hoverBase = regularClose;
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
            // The dot and the change text follow the sign of the change shown in the tooltip.
            var hoverAccent = hoverChange > 0 ? pos : (hoverChange < 0 ? neg : rootItem.secondaryTextColor);
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

        // Pre-market and after-hours candles are hatched like the line chart's zones.
        var nPre = 0, nPost = 0;
        for (var zi = 0; zi < candles.length; zi++) {
            if (candles[zi].zone === "pre") nPre++;
            else if (candles[zi].zone === "post") nPost++;
        }
        var nReg = candles.length - nPre - nPost;
        var xPreEnd = (nPre / candles.length) * plotRight;
        var xPostStart = ((nPre + nReg) / candles.length) * plotRight;
        if (rootItem.chartPreSession) {
            drawHatch(ctx, 0, plotRight, volumeBottom);
        } else {
            if (nPre > 0) drawHatch(ctx, 0, xPreEnd, volumeBottom);
            if (nPost > 0) drawHatch(ctx, xPostStart, plotRight, volumeBottom);
        }

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

        // Session boundaries and tags, matching the line chart.
        if (!rootItem.chartPreSession && (nPre > 0 || nPost > 0)) {
            var sec = rootItem.secondaryTextColor;
            ctx.save();
            ctx.strokeStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.5);
            ctx.lineWidth = 1;
            ctx.setLineDash([2, 3]);
            ctx.beginPath();
            if (nPre > 0) { ctx.moveTo(Math.round(xPreEnd) + 0.5, 0); ctx.lineTo(Math.round(xPreEnd) + 0.5, plotBottom); }
            if (nPost > 0) { ctx.moveTo(Math.round(xPostStart) + 0.5, 0); ctx.lineTo(Math.round(xPostStart) + 0.5, plotBottom); }
            ctx.stroke();
            ctx.restore();
            ctx.save();
            ctx.font = "8px sans-serif";
            ctx.fillStyle = Qt.rgba(sec.r, sec.g, sec.b, 0.8);
            ctx.textBaseline = "middle";
            if (nPre > 0) {
                ctx.textAlign = "left";
                ctx.fillText(rootItem.tagPreMarket, 4, 22);
            }
            if (nPost > 0) {
                ctx.textAlign = "right";
                ctx.fillText(rootItem.tagAfterHours, plotRight - 4, 22);
            }
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
            var hoverZone = hoverCandle.zone === "pre" ? " " + rootItem.tagPreMarket
                          : (hoverCandle.zone === "post" ? " " + rootItem.tagAfterHours : "");
            var hoverTime = hoverCandle.time ? hoverTimeLabel(hoverCandle.time) + hoverZone : "";
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
