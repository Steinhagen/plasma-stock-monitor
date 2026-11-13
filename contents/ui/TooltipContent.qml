import QtQuick

Item {
    id: tooltipContent
    property var applet
    property var stockList

    readonly property string title: {
        if (!applet.isMultiMode) {
            var title = applet.nameAndTicker(applet.singleCompanyName, applet.displayTicker(applet.singleTicker));
            var badge = applet.exchangeBadge(applet.singleTicker, applet.singleExchange);
            if (badge !== "") title += " · " + badge;
            return title !== "" ? title : i18n("Plasma Stock Monitor");
        }
        var n = stockList.count;
        if (n === 0)
            return i18n("Plasma Stock Monitor");
        var count = i18np("%1 stock", "%1 stocks", n);
        if (applet.showingCachedData)
            return i18nc("@info:tooltip", "%1 · %2 · cached data from %3",
                         count, applet.rangeLabel(applet.chartRange), applet.cachedQuotesLabel);
        return applet.lastUpdated !== ""
               ? i18nc("@info:tooltip", "%1 · %2 · updated %3", count, applet.rangeLabel(applet.chartRange), applet.lastUpdated)
               : i18nc("@info:tooltip", "%1 · %2", count, applet.rangeLabel(applet.chartRange));
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
        return "<span style=\"color:" + htmlColor(isPos ? applet.positiveColor : applet.negativeColor) + ";\">"
             + htmlEscape(text) + "</span>";
    }

    function tooltipChange(isPos, change, pct) {
        return htmlColored(isPos, change + " (" + pct + ")");
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
        var revision = applet.tooltipRevision;
        // The body is a table so the label, price and change columns line up on
        // every row instead of drifting with the length of the values.
        var cell = "padding-left:14px; padding-top:2px; padding-bottom:2px;";
        var labelCell = "padding-top:2px; padding-bottom:2px;";
        var muted = function(text) {
            return "<span style=\"color:" + htmlColor(applet.secondaryTextColor) + ";\">"
                 + htmlEscape(text) + "</span>";
        };

        if (applet.isMultiMode) {
            var rows = [];
            // Keep the tooltip compact: a long list would make it taller than the screen.
            // Within that limit the window follows the stock selected in the panel, so its
            // marker stays visible; the rows hidden above and below are counted instead.
            var maxRows = 7;
            var activeRow = -1;
            for (var a = 0; a < stockList.count; a++) {
                if (stockList.get(a).ticker === applet.panelTicker) { activeRow = a; break; }
            }
            var visible = tooltipWindow(stockList.count, activeRow, maxRows);
            var moreRow = function(hidden, atTop) {
                return "<tr><td></td><td colspan=\"3\" style=\""
                       + (atTop ? "padding-bottom:2px;" : "padding-top:2px;") + "\">"
                       + muted(i18n("… and %1 more", hidden)) + "</td></tr>";
            };
            if (visible.start > 0) rows.push(moreRow(visible.start, true));

            var tickerStyle = "padding-right:16px; padding-top:1px; padding-bottom:1px;";
            for (var i = visible.start; i < visible.end; i++) {
                var row = stockList.get(i);
                var ext = applet.extendedQuote(row.ticker);
                var marker = "<td style=\"padding-right:6px; padding-top:1px; padding-bottom:1px;\">"
                             + (row.ticker === applet.panelTicker ? "•" : "") + "</td>";
                var closedMark = (applet.showExtendedHours && applet.isMarketClosedFor(row.ticker))
                                 ? " " + muted(i18nc("@item:market status", "closed")) : "";
                var badge = applet.exchangeBadge(row.ticker, row.exchange);
                var tickerCell = "<td style=\"" + tickerStyle + "\"><b>"
                                 + htmlEscape(applet.displayTicker(row.ticker)) + "</b>"
                                 + (badge !== "" ? " " + muted(badge) : "") + closedMark + "</td>";
                if (row.price === "---" && !ext) {
                    rows.push("<tr>" + marker + tickerCell
                              + "<td colspan=\"2\" align=\"right\" style=\"padding-top:1px; padding-bottom:1px;\">"
                              + muted(i18n("loading…")) + "</td></tr>");
                    continue;
                }
                rows.push("<tr>" + marker + tickerCell
                          + "<td align=\"right\" style=\"" + tickerStyle + "\">"
                          + htmlEscape(ext ? ext.price : row.price) + "</td>"
                          + "<td align=\"right\" style=\"padding-top:1px; padding-bottom:1px;\">"
                          + tooltipChange(ext ? ext.isPos : row.isPos,
                                               ext ? ext.change : row.change,
                                               ext ? ext.pct : row.pct) + "</td></tr>");
            }
            if (visible.end < stockList.count) rows.push(moreRow(stockList.count - visible.end, false));
            return rows.length > 0
                   ? "<table cellspacing=\"0\" cellpadding=\"0\">" + rows.join("") + "</table>"
                   : i18n("Loading…");
        }

        if (applet.currentPrice === "" || applet.currentPrice === "---")
            return i18n("Loading…");

        var singleRows = [];
        var period = applet.chartPeriodLabel;
        singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(period) + "</td>"
                        + "<td align=\"right\" style=\"" + cell + "\"><b>"
                        + htmlEscape(applet.currentPrice) + "</b></td>"
                        + "<td align=\"right\" style=\"" + cell + "\">"
                        + tooltipChange(applet.isPositive, applet.priceChange, applet.percentChange) + "</td></tr>");

        var ext = applet.extendedQuote(applet.singleTicker);
        if (ext) {
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(ext.label) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\"><b>"
                            + htmlEscape(ext.price) + "</b></td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + tooltipChange(ext.isPos, ext.change, ext.pct) + "</td></tr>");
        }
        if (applet.showExtendedHours && applet.isMarketClosedFor(applet.singleTicker)) {
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Session")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + muted(i18n("Market closed")) + "</td></tr>");
        }

        // When the shown ticker is in the portfolio, add the summed position: shares,
        // average cost and the gain against the cost of all its lots.
        if (applet.showPortfolioMode && applet.hasPortfolioEntry) {
            var p = applet.portfolioSummary;
            var pSym = applet.getCurrencySymbol(p.currency);
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Position")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + htmlEscape(i18np("%1 share · avg %2", "%1 shares · avg %2",
                                                    p.shares,
                                                    applet.formatMoney(pSym, p.avgCost, false))) + "</td></tr>");
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("P/L")) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + htmlColored(p.plIsPos, applet.formatMoney(pSym, p.plValue, true)) + "</td>"
                            + "<td align=\"right\" style=\"" + cell + "\">"
                            + htmlColored(p.plIsPos, applet.formatNumber(p.plPercent, true) + "%") + "</td></tr>");
        }

        if (applet.showingCachedData) {
            singleRows.push("<tr><td colspan=\"3\" style=\"" + cell + "\">"
                            + muted(i18n("Cached data from %1", applet.cachedQuotesLabel)) + "</td></tr>");
        } else if (applet.lastUpdated !== "") {
            singleRows.push("<tr><td style=\"" + labelCell + "\">" + muted(i18n("Updated")) + "</td>"
                            + "<td colspan=\"2\" style=\"" + cell + "\">"
                            + htmlEscape(applet.lastUpdated) + "</td></tr>");
        }

        return "<table cellspacing=\"0\" cellpadding=\"0\">" + singleRows.join("") + "</table>";
    }

    readonly property string body: buildTooltipBody()
}
