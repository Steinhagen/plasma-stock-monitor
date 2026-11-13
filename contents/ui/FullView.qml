import QtQuick
import QtQuick.Layouts

Item {
    id: fullRoot
    property var applet
    property var stockList

    // Never paint card contents outside the applet background when a host gives
    // the view less than its minimum (for example a hand-resized preview window).
    clip: true

    // Desktop only: the panel uses compactRepresentation, whose size is unchanged.
    // Two columns only in multi mode with the side-by-side list.
    readonly property bool twoColumns: applet.isMultiMode && applet.showTwoList
    // Width of the drag zone between the two columns, including its visual line.
    readonly property int dividerWidth: applet.usesPlasmaSurface ? 8 : 10
    // A stored width of 0 keeps the automatic layout: both columns share the card.
    readonly property bool manualSplit: twoColumns && applet.twoColumnLeftWidth > 0
    // The stored width can be too large for the current widget width; clamp it so the
    // list keeps its own minimum.
    readonly property real maxLeftColumnWidth: Math.max(singleColumn.minimumContentWidth,
        fullRow.width - dividerWidth - listColumn.minimumContentWidth)
    readonly property real leftColumnWidth: Math.max(singleColumn.minimumContentWidth,
        Math.min(applet.twoColumnLeftWidth, maxLeftColumnWidth))

    // The minimum depends on applet.isMultiMode, so compute it from the new
    // mode directly. Using a separate property here would still hold the old
    // mode's value while the mode-change handler runs.
    function modeMinimumWidth() {
        return applet.isMultiMode && applet.showTwoList
            ? singleColumn.minimumContentWidth + dividerWidth + listColumn.minimumContentWidth
            : (applet.isMultiMode ? listColumn.minimumContentWidth
                                : singleColumn.minimumContentWidth);
    }
    function modeMinimumHeight() {
        return applet.isMultiMode && applet.showTwoList
            ? Math.max(singleColumn.minimumContentHeight, listColumn.minimumContentHeight)
            : (applet.isMultiMode ? listColumn.minimumContentHeight
                                : singleColumn.minimumContentHeight);
    }

    Layout.minimumWidth: fullRoot.modeMinimumWidth()
    Layout.minimumHeight: fullRoot.modeMinimumHeight()
    // Stable defaults for Plasma when there is no saved geometry yet (a new
    // activity or an empty virtual desktop). Without these, the preferred size
    // falls back to the minimum and the widget opens at its smallest size.
    //
    // Plasma re-applies the preferred size when the mode changes, which made a
    // single-stock widget jump to the wide/tall multi-list size. Keep the width
    // and height the widget already has; the root item's minimum below makes the
    // applet grow when the new mode genuinely needs more room (a graph minimum is
    // larger than a list minimum), while two-column mode needs both columns.
    // 600x520 (960 wide for two columns) is only the starting point for a new widget.
    property real preferredWidth: 600
    property real preferredHeight: 520
    property bool sizeReady: false
    Layout.preferredWidth: preferredWidth
    Layout.preferredHeight: preferredHeight

    // The applet container sizes the PlasmoidItem from its own Layout hints;
    // fullRoot's hints only reach the full representation. Mirror them on root
    // so a mode change can actually grow the applet to the new minimum.
    function syncRootSizeHints() {
        applet.fullViewMinimumWidth = fullRoot.modeMinimumWidth();
        applet.fullViewMinimumHeight = fullRoot.modeMinimumHeight();
        applet.fullViewPreferredWidth = preferredWidth;
        applet.fullViewPreferredHeight = preferredHeight;
    }

    function keepCurrentSize() {
        if (!sizeReady) return;
        if (width > 0) preferredWidth = width;
        if (height > 0) preferredHeight = height;
        syncRootSizeHints();
    }

    Component.onCompleted: {
        sizeReady = true;
        preferredWidth = width > 0 ? width : (twoColumns ? 960 : 600);
        preferredHeight = height > 0 ? height : 520;
        syncRootSizeHints();
        // The first layout may not have assigned the saved size yet; adopt it
        // once it has, so a later mode switch keeps that size.
        Qt.callLater(function() { fullRoot.keepCurrentSize(); });
    }
    onTwoColumnsChanged: fullRoot.keepCurrentSize()
    // isMultiMode belongs to the applet root, not to fullRoot, so it needs a
    // Connections handler rather than an onIsMultiModeChanged property handler.
    Connections {
        target: applet
        function onIsMultiModeChanged() { fullRoot.keepCurrentSize(); }
    }

    RowLayout {
        id: fullRow
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        SingleStockView {
            id: singleColumn
            visible: !applet.isMultiMode || applet.showTwoList
            Layout.fillWidth: !fullRoot.manualSplit
            Layout.preferredWidth: fullRoot.manualSplit ? fullRoot.leftColumnWidth : 0
            Layout.fillHeight: true
            Layout.minimumWidth: singleColumn.minimumContentWidth
            Layout.minimumHeight: singleColumn.minimumContentHeight
            rootItem: applet
        }

        Item {
            id: divider
            objectName: "columnDivider"
            visible: fullRoot.twoColumns
            Layout.preferredWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
            Layout.minimumWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
            Layout.maximumWidth: fullRoot.twoColumns ? fullRoot.dividerWidth : 0
            Layout.fillHeight: true
            z: 1

            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: Math.min(parent.height, 40)
                radius: 1
                color: applet.tickerColor
                // The divider is invisible until the pointer enters its (wider) hit area.
                opacity: dividerMouse.containsMouse || dividerMouse.pressed ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: dividerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                preventStealing: true

                property real pressX: 0
                property real pressWidth: 0

                onPressed: {
                    pressX = mapToItem(fullRow, mouse.x, mouse.y).x;
                    pressWidth = singleColumn.width;
                }
                onPositionChanged: {
                    if (!pressed) return;
                    var dx = mapToItem(fullRow, mouse.x, mouse.y).x - pressX;
                    var minLeft = singleColumn.minimumContentWidth;
                    var maxLeft = Math.max(minLeft,
                        fullRow.width - fullRoot.dividerWidth - listColumn.minimumContentWidth);
                    applet.setTwoColumnLeftWidth(Math.max(minLeft,
                        Math.min(maxLeft, pressWidth + dx)));
                }
                onReleased: applet.saveTwoColumnLeftWidth()
                onCanceled: applet.saveTwoColumnLeftWidth()
            }
        }

        MultiStockView {
            id: listColumn
            visible: applet.isMultiMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: listColumn.minimumContentWidth
            Layout.minimumHeight: listColumn.minimumContentHeight
            rootItem: applet
            listModel: stockList
        }
    }
}
