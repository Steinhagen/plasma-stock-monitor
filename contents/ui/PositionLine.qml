import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// One line summarising a position: all the lots of a ticker, or the whole portfolio.
//
//   17 (3 lots) @ $207.38   Value $7,628.58   P/L [+$4,103.08 (+116.38%)]   Today +$753.78
//
// What is held is plain muted text, the captions are muted and the figures stand out; the total
// gain is a tinted badge, like the other badges in the widget. When the line is too narrow it
// gives up parts from the left, so the total gain is the last thing to go.
Item {
    id: line

    property var rootItem
    // The position, as returned by getPortfolioSummary() (or the same fields for a total).
    property var summary: null
    // Fallback symbol when the summary does not carry its own currency.
    property string sym: ""
    // Replaces the "17 (3 lots) @ $207.38" part, e.g. for a portfolio total.
    property string heldOverride: ""
    // Caption for the period gain. Empty means the widget's configured/list range.
    property string periodLabel: ""
    property bool centered: false

    visible: summary !== null && summary !== undefined
    implicitHeight: row.implicitHeight
    // Never paint outside the space the line was given.
    clip: true

    // The summary knows the currency its value and cost are expressed in (a lot currency,
    // or the portfolio currency for mixed positions and totals), so use that symbol first.
    // `sym` is already a symbol, so it is used as-is when the summary has no currency.
    readonly property string moneySymbol: {
        if (!rootItem) return "";
        if (summary && summary.currency) return rootItem.getCurrencySymbol(summary.currency);
        return sym;
    }

    readonly property int gap: 10
    readonly property int captionGap: 4
    readonly property int badgePadding: Kirigami.Units.smallSpacing * 2
    readonly property int fontSize: 10

    readonly property bool dayAvailable: summary !== null && summary !== undefined
                                         && summary.dayValue !== null && summary.dayValue !== undefined
    readonly property color plColor: summary && summary.plIsPos ? rootItem.positiveColor : rootItem.negativeColor
    readonly property color dayColor: summary && summary.dayIsPos ? rootItem.positiveColor : rootItem.negativeColor

    readonly property string heldString: {
        if (heldOverride !== "") return heldOverride;
        if (!summary || summary.shares === undefined) return "";
        var shares = Number(summary.shares.toFixed(4));
        // "17 (3 lots)", or just "17" when the position is a single purchase.
        var withLots = summary.lots > 1
                       ? i18n("%1 (%2)", shares, i18np("%1 lot", "%1 lots", summary.lots))
                       : String(shares);
        return i18n("%1 @ %2", withLots, rootItem.formatMoney(moneySymbol, summary.avgCost, false));
    }
    readonly property string plPercentString: summary ? rootItem.formatNumber(summary.plPercent, true) + "%" : ""

    // Width of each part. They come from the texts' own implicit widths, which do not depend on
    // what is shown, so choosing the parts by width cannot loop.
    readonly property real heldWidth: heldString !== "" ? heldText.implicitWidth : 0
    readonly property real valueWidth: valueCaption.implicitWidth + captionGap + valueText.implicitWidth
    readonly property real plWidth: plCaption.implicitWidth + captionGap + plFullText.implicitWidth + badgePadding
    readonly property real plPercentWidth: plPercentText.implicitWidth + badgePadding
    readonly property real dayWidth: dayCaption.implicitWidth + captionGap + dayText.implicitWidth

    // What is shown, from the most to the least, by the width available:
    //   0: everything. 1: no held part. 2: also no period gain.
    //   3: the value and only the percentage of the total gain. 4: only that percentage.
    // The value and the total gain stay longest: what the position is worth and how it is doing
    // matter more than the number of shares or the movement of the day.
    readonly property int level: {
        var avail = width;
        var held = heldWidth > 0 ? heldWidth + gap : 0;
        var day = dayAvailable ? gap + dayWidth : 0;
        if (held + valueWidth + gap + plWidth + day <= avail) return 0;
        if (valueWidth + gap + plWidth + day <= avail) return 1;
        if (valueWidth + gap + plWidth <= avail) return 2;
        if (valueWidth + gap + plPercentWidth <= avail) return 3;
        return 4;
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: line.centered ? undefined : parent.right
        anchors.horizontalCenter: line.centered ? parent.horizontalCenter : undefined
        spacing: line.gap

        // What is held.
        Text {
            id: heldText
            visible: line.level === 0 && line.heldString !== ""
            text: line.heldString
            color: rootItem.secondaryTextColor
            font.pixelSize: line.fontSize
        }

        // Current value.
        RowLayout {
            visible: line.level <= 3 && line.summary !== null
            spacing: line.captionGap
            Text {
                id: valueCaption
                text: i18n("Value")
                color: rootItem.secondaryTextColor
                font.pixelSize: line.fontSize
            }
            Text {
                id: valueText
                text: line.summary ? rootItem.formatMoney(line.moneySymbol, line.summary.value, false) : ""
                color: rootItem.priceColor
                font.pixelSize: line.fontSize
                font.bold: true
            }
        }

        // Total gain, against the cost of all the lots, as a badge.
        RowLayout {
            spacing: line.captionGap
            Text {
                id: plCaption
                visible: line.level <= 2
                text: i18n("P/L")
                color: rootItem.secondaryTextColor
                font.pixelSize: line.fontSize
            }
            Rectangle {
                radius: 4
                color: Qt.rgba(line.plColor.r, line.plColor.g, line.plColor.b, 0.15)
                border.color: line.plColor
                border.width: 1
                Layout.preferredWidth: (line.level >= 3 ? plPercentText : plFullText).implicitWidth + line.badgePadding
                Layout.preferredHeight: plFullText.implicitHeight + (Kirigami.Units.smallSpacing / 2)

                Text {
                    id: plFullText
                    anchors.centerIn: parent
                    visible: line.level <= 2
                    text: line.summary ? rootItem.formatMoney(line.moneySymbol, line.summary.plValue, true) + " (" + line.plPercentString + ")" : ""
                    color: line.plColor
                    font.pixelSize: line.fontSize
                    font.weight: Font.Bold
                }
                Text {
                    id: plPercentText
                    anchors.centerIn: parent
                    visible: line.level >= 3
                    text: line.plPercentString
                    color: line.plColor
                    font.pixelSize: line.fontSize
                    font.weight: Font.Bold
                }
            }
        }

        // Gain over the period the widget shows (today for the 1D chart).
        RowLayout {
            visible: line.dayAvailable && line.level <= 1
            spacing: line.captionGap
            Text {
                id: dayCaption
                text: line.periodLabel !== "" ? line.periodLabel : rootItem.portfolioChangeLabel
                color: rootItem.secondaryTextColor
                font.pixelSize: line.fontSize
            }
            Text {
                id: dayText
                text: line.dayAvailable ? rootItem.formatMoney(line.moneySymbol, line.summary.dayValue, true) : ""
                color: line.dayColor
                font.pixelSize: line.fontSize
                font.bold: true
            }
        }
    }
}
