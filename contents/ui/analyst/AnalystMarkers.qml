import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "analyst.js" as Analyst

// Analyst price-target markers overlaid on the chart. The component owns the geometry,
// the marker shapes and the details popup; SingleStockView only places it over the
// chart and asks whether a small plot gap should be reserved for it.
Item {
    id: analystRoot
    property var applet
    // The news pane uses the same chart area, so the markers must disappear with it.
    property bool chartVisible: true

    readonly property bool markersShown: applet !== null && applet !== undefined
                                         && applet.showAnalystTargets
                                         && chartVisible
                                         && marks.length > 0
    visible: markersShown
    clip: false

    property var selectedMark: null
    property point popupAnchor: Qt.point(0, 0)

    readonly property color popupBackground: applet && applet.appDrawnSurface
                                             ? (applet.isLightTheme ? "#ffffff" : "#1a1a1a")
                                             : Kirigami.Theme.backgroundColor
    readonly property color popupText: applet && applet.appDrawnSurface
                                       ? (applet.isLightTheme ? "#171a1c" : "#f3f5f6")
                                       : Kirigami.Theme.textColor

    FontMetrics {
        id: axisMetrics
        font.pixelSize: 9
        font.family: "sans-serif"
    }

    onMarkersShownChanged: if (!markersShown && detailsPopup) detailsPopup.close()

    Connections {
        target: analystRoot.applet
        function onSingleTickerChanged() { if (detailsPopup) detailsPopup.close(); }
    }

    // The price range used by the chart, so the width reserved by its price scale can
    // be reproduced here. This mirrors drawReferenceChart()/drawCandleChart().
    function targetRange() {
        if (!applet) return null;
        var data = applet.chartDataPoints;
        if (!Array.isArray(data) || data.length < 2) return null;
        var candles = applet.chartCandles;
        if (applet.chartStyle === 1 && Array.isArray(candles) && candles.length > 1) {
            var cMin = Infinity, cMax = -Infinity;
            for (var ci = 0; ci < candles.length; ci++) {
                if (candles[ci].low < cMin) cMin = candles[ci].low;
                if (candles[ci].high > cMax) cMax = candles[ci].high;
            }
            if (!(cMax > cMin)) return null;
            var cPad = (cMax - cMin) * 0.06;
            return { min: cMin - cPad, max: cMax + cPad };
        }
        var times = applet.chartTimestamps;
        var s = applet.chartSessions;
        if (s && (!Array.isArray(times) || times.length !== data.length)) s = null;
        var allData = data;
        if (s) {
            var pre = Array.isArray(s.preValues) ? s.preValues : [];
            var post = Array.isArray(s.postValues) ? s.postValues : [];
            allData = pre.concat(data, post);
        }
        var minVal = Math.min.apply(null, allData);
        var maxVal = Math.max.apply(null, allData);
        if (!isFinite(minVal) || !isFinite(maxVal)) return null;
        var ref = applet.chartReferencePrice > 0
                  ? applet.chartReferencePrice
                  : (applet.previousClose > 0 ? applet.previousClose : data[0]);
        if (!isFinite(ref)) return null;
        if (ref < minVal) minVal = ref;
        if (ref > maxVal) maxVal = ref;
        var range = maxVal - minVal;
        if (!(range > 0)) range = 1;
        var padding = range * 0.08;
        return { min: minVal - padding, max: maxVal + padding };
    }

    readonly property real plotRight: {
        if (!applet) return 0;
        var w = analystRoot.width;
        if (!(w > 20)) return 0;
        if (!applet.showChartAxis) return w;
        var bounds = targetRange();
        if (!bounds) return w;
        var ticks = axisTicks(bounds.min, bounds.max, 5);
        var labelW = 0;
        for (var i = 0; i < ticks.length; i++) {
            labelW = Math.max(labelW,
                              Math.ceil(axisMetrics.advanceWidth(
                                  applet.formatNumber(ticks[i], false))));
        }
        var right = w - labelW - 10;
        return right < 24 ? w : right;
    }

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

    // Vertical layout around the existing price/volume separator line. This mirrors the
    // time-axis and volume-strip decisions in the chart drawing functions.
    readonly property real timeAxisHeight: {
        if (!applet || !applet.showTimeAxis) return 0;
        var h = analystRoot.height;
        if (!(h > 20)) return 0;
        var candles = applet.chartCandles;
        if (applet.chartStyle === 1 && Array.isArray(candles) && candles.length > 1) {
            return Number(candles[0].time) > 0
                   && Number(candles[candles.length - 1].time) > 0 ? 16 : 0;
        }
        var data = applet.chartDataPoints;
        var times = applet.chartTimestamps;
        return Array.isArray(data) && Array.isArray(times) && data.length > 1
               && times.length === data.length && Number(times[0]) > 0 ? 16 : 0;
    }

    readonly property real volumeTop: {
        if (!applet) return -1;
        var h = analystRoot.height;
        if (!(h > 20) || !applet.showChartVolume || applet.chartPreSession) return -1;
        var candles = applet.chartCandles;
        if (!Array.isArray(candles)) return -1;
        var useCandles = applet.chartStyle === 1 && candles.length > 1;
        var maxVolume = 0;
        var regularCount = 0;
        for (var i = 0; i < candles.length; i++) {
            var candle = candles[i];
            if (!candle || candle.zone === "pre" || candle.zone === "post") continue;
            regularCount++;
            if (candle.volume > maxVolume) maxVolume = candle.volume;
        }
        if (!(maxVolume > 0) || (!useCandles && regularCount < 2)) return -1;
        var volumeBottom = h - timeAxisHeight;
        var volumeHeight = Math.min(54, Math.max(26, h * 0.13));
        var top = volumeBottom - volumeHeight;
        if (top - (markersShown ? 22 : 8) < 36) return -1;
        return top;
    }

    // Top of the 14 px marker item. The chart reserves a gap above the volume separator
    // so the glyphs sit a few pixels above the line; without a volume strip the same gap
    // keeps them above the time axis, not over its labels.
    readonly property real markerTop: {
        var h = analystRoot.height;
        var bottom = h - timeAxisHeight;
        return (volumeTop > 0 ? volumeTop : bottom) - 18;
    }

    function sameCalendarDay(a, b) {
        var da = new Date(a * 1000);
        var db = new Date(b * 1000);
        return da.getFullYear() === db.getFullYear()
               && da.getMonth() === db.getMonth()
               && da.getDate() === db.getDate();
    }

    function nearestTimeIndex(times, time) {
        if (time <= times[0]) return 0;
        if (time >= times[times.length - 1]) return times.length - 1;
        var lo = 0, hi = times.length - 1;
        while (lo + 1 < hi) {
            var mid = Math.floor((lo + hi) / 2);
            if (Number(times[mid]) <= time) lo = mid; else hi = mid;
        }
        return time - Number(times[lo]) <= Number(times[hi]) - time ? lo : hi;
    }

    // Pixel position of one timestamp on the chart's x scale.
    function timeX(time) {
        if (!applet) return -1;
        var plot = plotRight;
        if (!(plot > 20) || !(time > 0)) return -1;
        var data = applet.chartDataPoints;
        var times = applet.chartTimestamps;
        var candles = applet.chartCandles;
        var useCandles = applet.chartStyle === 1
                         && Array.isArray(candles) && candles.length > 1;
        if (useCandles) {
            var cFirst = Number(candles[0].time);
            var cLast = Number(candles[candles.length - 1].time);
            if (!(cFirst > 0) || !(cLast >= cFirst)) return -1;
            if (time < cFirst) return sameCalendarDay(time, cFirst) ? 0 : -1;
            if (time > cLast) return sameCalendarDay(time, cLast) ? plot : -1;
            var ci = 0, cDiff = Infinity;
            for (var i = 0; i < candles.length; i++) {
                var d = Math.abs(Number(candles[i].time) - time);
                if (d < cDiff) { cDiff = d; ci = i; }
            }
            return plot * (ci + 0.5) / candles.length;
        }
        var s = applet.chartSessions;
        if (s && Array.isArray(data) && Array.isArray(times)
                && times.length === data.length) {
            var allTimes = (s.preTimes || []).concat(times, s.postTimes || []);
            if (allTimes.length >= 2 && allTimes[0] > 0
                    && allTimes[allTimes.length - 1] > allTimes[0]) {
                if (time < allTimes[0])
                    return sameCalendarDay(time, allTimes[0]) ? 0 : -1;
                if (time > allTimes[allTimes.length - 1])
                    return sameCalendarDay(time, allTimes[allTimes.length - 1]) ? plot : -1;
                return plot * (time - allTimes[0])
                       / (allTimes[allTimes.length - 1] - allTimes[0]);
            }
        }
        if (!Array.isArray(times) || !Array.isArray(data)
                || times.length !== data.length || data.length < 2
                || !(times[0] > 0) || !(times[times.length - 1] > times[0]))
            return -1;
        if (time < times[0]) return sameCalendarDay(time, times[0]) ? 0 : -1;
        if (time > times[times.length - 1])
            return sameCalendarDay(time, times[times.length - 1]) ? plot : -1;
        var index = nearestTimeIndex(times, time);
        return plot * index / (times.length - 1);
    }

    readonly property var marks: {
        if (!applet || !applet.showAnalystTargets) return [];
        var items = applet.analystItems;
        if (!Array.isArray(items) || items.length === 0) return [];
        var plot = plotRight;
        if (!(plot > 20)) return [];
        var buckets = ({});
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var x = timeX(Number(item.time));
            if (!(x >= 0)) continue;
            var bucket = Math.round(x / 16);
            var group = buckets[bucket];
            if (!group) {
                group = { xSum: 0, entries: [] };
                buckets[bucket] = group;
            }
            group.xSum += x;
            group.entries.push(item);
        }
        var result = [];
        for (var key in buckets) {
            var g = buckets[key];
            if (!g || g.entries.length === 0) continue;
            g.entries.sort(function(a, b) { return b.time - a.time; });
            var counts = Analyst.directions(g.entries);
            var direction = "neutral";
            if (counts.up > 0 && counts.down === 0) direction = "up";
            else if (counts.down > 0 && counts.up === 0) direction = "down";
            else if (counts.up === 0 && counts.down === 0) {
                if (counts.maintain > 0 && counts.announce === 0) direction = "maintain";
                else if (counts.announce > 0 && counts.maintain === 0) direction = "announce";
            }
            result.push({
                x: g.xSum / g.entries.length,
                direction: direction,
                entries: g.entries.slice(0, 6),
                total: g.entries.length,
                newest: g.entries[0]
            });
        }
        result.sort(function(a, b) { return a.x - b.x; });
        return result;
    }

    function money(value) {
        return value > 0 ? applet.currencySym + applet.formatNumber(value, false) : "";
    }

    function targetText(entry) {
        if (!entry) return "";
        var target = money(entry.target);
        var prior = money(entry.prior);
        switch (entry.kind) {
            case "up":
                return prior !== "" ? i18n("Raised target from %1 to %2", prior, target)
                                    : i18n("New target %1", target);
            case "down":
                return prior !== "" ? i18n("Lowered target from %1 to %2", prior, target)
                                    : i18n("New target %1", target);
            case "maintain":
                return i18n("Maintained target at %1", target);
            default:
                return i18n("New target %1", target);
        }
    }

    function ratingText(entry) {
        if (!entry) return "";
        var from = String(entry.fromGrade || "").trim();
        var to = String(entry.toGrade || "").trim();
        if (from !== "" && to !== "" && from !== to)
            return i18n("Rating: %1 → %2", from, to);
        if (to !== "") return i18n("Rating: %1", to);
        if (from !== "") return i18n("Rating: %1", from);
        return "";
    }

    function entryDate(entry) {
        return new Date(entry.time * 1000).toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    function markerTooltip(mark) {
        if (!mark || !mark.newest) return "";
        var latest = mark.newest;
        var prefix = mark.total > 1
                     ? i18np("%1 analyst action", "%1 analyst actions", mark.total) + " · "
                     : "";
        return prefix + latest.firm + " · " + targetText(latest);
    }

    function summaryText() {
        var s = applet ? applet.analystSummary : null;
        if (!s || !(s.mean > 0)) return "";
        var text = i18n("Consensus %1", money(s.mean));
        if (s.low > 0 && s.high > 0)
            text += " · " + i18n("range %1 – %2", money(s.low), money(s.high));
        if (s.count > 0)
            text += " · " + i18np("%1 analyst", "%1 analysts", s.count);
        return text;
    }

    function positionPopup() {
        if (!detailsPopup || !detailsPopup.opened) return;
        var x = popupAnchor.x - detailsPopup.width / 2;
        var y = popupAnchor.y - detailsPopup.height - 8;
        detailsPopup.x = Math.max(8, Math.min(analystRoot.width - detailsPopup.width - 8, x));
        detailsPopup.y = Math.max(8, Math.min(analystRoot.height - detailsPopup.height - 8, y));
    }

    function openPopup(marker, mark) {
        selectedMark = mark;
        popupAnchor = marker.mapToItem(analystRoot, marker.width / 2, 0);
        detailsPopup.open();
        positionPopup();
        Qt.callLater(positionPopup);
    }

    Repeater {
        model: analystRoot.marks
        delegate: Item {
            id: marker
            required property var modelData
            readonly property color accent: modelData.direction === "up"
                                            ? applet.positiveColor
                                            : (modelData.direction === "down"
                                               ? applet.negativeColor
                                               : applet.secondaryTextColor)
            x: Math.max(0, Math.min(analystRoot.plotRight - width,
                                    modelData.x - width / 2))
            y: analystRoot.markerTop
            width: 16
            height: 14

            // Filled triangles mean a real increase/decrease. The neutral actions use
            // shapes rather than text glyphs so all markers have a comparable visual
            // size and the 16x14 item stays easy to click.
            Text {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "up"
                         || marker.modelData.direction === "down"
                text: marker.modelData.direction === "up" ? "▲" : "▼"
                color: marker.accent
                opacity: 0.95
                font.pixelSize: 9
                font.bold: true
            }
            // Maintained target: a short bar, meaning "unchanged".
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "maintain"
                width: 8
                height: 2
                radius: 1
                color: applet.secondaryTextColor
                opacity: 0.85
            }
            // Newly announced target: a hollow circle, with no direction.
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "announce"
                width: 7
                height: 7
                radius: 3.5
                color: "transparent"
                border.width: 1
                border.color: applet.secondaryTextColor
                opacity: 0.9
            }
            // Mixed group: a small neutral dot.
            Rectangle {
                anchors.centerIn: parent
                visible: marker.modelData.direction === "neutral"
                width: 6
                height: 6
                radius: 3
                color: applet.secondaryTextColor
                opacity: 0.7
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: analystRoot.openPopup(marker, marker.modelData)
            }

            HoverHandler { id: markerHover }
            ToolTip.visible: markerHover.hovered
            ToolTip.text: analystRoot.markerTooltip(marker.modelData)
        }
    }

    // Details popup for the selected marker group.
    Popup {
        id: detailsPopup
        parent: analystRoot
        width: Math.min(340, Math.max(180, analystRoot.width - 16))
        padding: 10
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        readonly property var mark: analystRoot.selectedMark

        onOpened: analystRoot.positionPopup()
        onHeightChanged: if (opened) analystRoot.positionPopup()
        onClosed: analystRoot.selectedMark = null

        background: Rectangle {
            color: analystRoot.popupBackground
            radius: 6
            border.width: 1
            border.color: Qt.rgba(analystRoot.applet.secondaryTextColor.r,
                                  analystRoot.applet.secondaryTextColor.g,
                                  analystRoot.applet.secondaryTextColor.b, 0.35)
        }

        contentItem: ColumnLayout {
            width: detailsPopup.availableWidth
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: i18n("Analyst price targets")
                    color: analystRoot.popupText
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    text: detailsPopup.mark && detailsPopup.mark.total > 1
                          ? i18np("%1 action", "%1 actions", detailsPopup.mark.total) : ""
                    color: analystRoot.applet.secondaryTextColor
                    font.pixelSize: 9
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: analystRoot.summaryText()
                color: analystRoot.applet.secondaryTextColor
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: detailsPopup.mark ? detailsPopup.mark.entries : []

                delegate: ColumnLayout {
                    id: popupEntry
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 1

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: popupEntry.index > 0 ? 4 : 0
                        height: popupEntry.index > 0 ? 1 : 0
                        color: analystRoot.applet.chartBaseColor
                        opacity: 0.6
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: popupEntry.modelData.firm
                            color: analystRoot.popupText
                            font.pixelSize: 10
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: analystRoot.entryDate(popupEntry.modelData)
                            color: analystRoot.applet.secondaryTextColor
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: analystRoot.targetText(popupEntry.modelData)
                        color: analystRoot.applet.secondaryTextColor
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: analystRoot.ratingText(popupEntry.modelData)
                        color: analystRoot.applet.secondaryTextColor
                        font.pixelSize: 9
                        opacity: 0.8
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: detailsPopup.mark
                      && detailsPopup.mark.total > detailsPopup.mark.entries.length
                      ? i18n("… and %1 more",
                             detailsPopup.mark.total - detailsPopup.mark.entries.length)
                      : ""
                color: analystRoot.applet.secondaryTextColor
                font.pixelSize: 9
            }
        }
    }
}
