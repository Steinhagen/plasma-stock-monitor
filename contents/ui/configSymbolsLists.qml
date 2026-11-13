import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property alias cfg_ticker: tickerField.text
    property alias cfg_multiTickers: multiListField.text
    property alias cfg_isMultiMode: modeSwitch.checked
    property alias cfg_showTwoList: showTwoListSwitch.checked
    property alias cfg_sortAlphabetically: sortSwitch.checked
    property alias cfg_showNameAndTicker: nameAndTickerSwitch.checked
    property alias cfg_swapNameAndTicker: swapNameSwitch.checked
    property alias cfg_symbolDisplayMode: symbolDisplayCombo.currentIndex

    ListModel {
        id: resultsModel
    }

    function searchSymbols(query) {
        if (query.trim().length < 1) {
            resultsModel.clear();
            searchHelpText.text = i18n("Enter a search term.");
            return;
        }
        searchHelpText.text = i18n("Searching...");
        resultsModel.clear();
        
        var xhr = new XMLHttpRequest();
        var url = "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        var results = res.quotes || [];
                        if (results.length === 0) {
                            searchHelpText.text = i18n("No symbols found.");
                            return;
                        }
                        searchHelpText.text = i18n("Suggestions:");
                        for (var i = 0; i < Math.min(results.length, 10); i++) {
                            var item = results[i];
                            if (item.symbol) {
                                resultsModel.append({
                                    "symbol": item.symbol,
                                    "name": item.shortname || item.longname || item.symbol
                                });
                            }
                        }
                    } catch (e) {
                        searchHelpText.text = i18n("Error parsing search results.");
                    }
                } else {
                    searchHelpText.text = i18n("Search failed (HTTP %1).", xhr.status);
                }
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 20
        contentWidth: availableWidth
        clip: true

        Kirigami.FormLayout {
            width: parent.availableWidth

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Lists")
            }

            CheckBox {
                id: modeSwitch
                Kirigami.FormData.label: i18n("Display Mode:")
                text: i18n("Show Multi-Stock List")
            }

            CheckBox {
                id: showTwoListSwitch
                visible: modeSwitch.checked
                Kirigami.FormData.label: i18n("Two List:")
                text: i18n("single-stock on left side and multi-stock on right side")
            }

            TextField {
                id: tickerField
                visible: !modeSwitch.checked
                Kirigami.FormData.label: i18n("Single Ticker:")
                placeholderText: i18n("e.g., AAPL")
            }

            ScrollView {
                visible: modeSwitch.checked
                Kirigami.FormData.label: i18n("Ticker List:")
                Layout.fillWidth: true
                Layout.minimumHeight: 60
                Layout.maximumHeight: 500

                TextArea {
                    id: multiListField
                    // Ticker symbols are the same in every language, so the example is not translated.
                    placeholderText: "AAPL, TSLA"
                    wrapMode: TextEdit.Wrap
                }
            }

            CheckBox {
                id: sortSwitch
                visible: modeSwitch.checked
                Kirigami.FormData.label: i18n("Sorting:")
                text: i18n("Sort stocks alphabetically")
            }

            CheckBox {
                id: nameAndTickerSwitch
                Kirigami.FormData.label: i18n("Names:")
                text: i18n("Show company name and ticker together, e.g. Apple Inc. (AAPL)")
            }

            CheckBox {
                id: swapNameSwitch
                text: nameAndTickerSwitch.checked
                      ? i18n("Swap the order: ticker symbol first, e.g. AAPL (Apple Inc.)")
                      : i18n("Swap company name and ticker symbol")
            }

            ComboBox {
                id: symbolDisplayCombo
                Kirigami.FormData.label: i18n("Symbol display:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                model: [
                    i18n("Yahoo Finance symbol, e.g. BRD.RO"),
                    i18n("Symbol only, e.g. BRD"),
                    i18n("Symbol and exchange, e.g. BRD · BVB")
                ]
            }

            Label {
                Layout.fillWidth: true
                text: i18n("The exchange badge is shown only where the Yahoo symbol has an exchange suffix, such as .RO or .DE. The full symbol and the exchange name stay visible in the tooltip.")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Item {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Find symbols")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Search:")
                Layout.fillWidth: true

                TextField {
                    id: searchField
                    placeholderText: i18n("e.g. Tesla, AAPL...")
                    Layout.fillWidth: true
                    onAccepted: page.searchSymbols(searchField.text)
                    Keys.onReturnPressed: {
                        event.accepted = true;
                        page.searchSymbols(searchField.text);
                    }
                    Keys.onEnterPressed: {
                        event.accepted = true;
                        page.searchSymbols(searchField.text);
                    }
                }
                
                Button {
                    text: i18n("Search")
                    icon.name: "search"
                    onClicked: page.searchSymbols(searchField.text)
                }
            }

            Label {
                id: searchHelpText
                text: i18n("Type to find symbols and click Search.")
                font.pixelSize: 11
                color: Kirigami.Theme.neutralTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: resultsModel
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        
                        Label {
                            text: "<b>" + model.symbol + "</b> - " + model.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Button {
                            text: i18nc("@action:button abbreviation for single stock", "SS")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Add to Single Stock")
                            onClicked: {
                                page.cfg_ticker = model.symbol;
                                page.cfg_isMultiMode = false;
                                searchHelpText.text = i18n("Set %1 as Single Stock.", model.symbol);
                            }
                        }

                        Button {
                            text: i18nc("@action:button abbreviation for multi stock list", "MSL")
                            ToolTip.visible: hovered
                            ToolTip.text: i18n("Add to Multi Stock List")
                            onClicked: {
                                var currentList = page.cfg_multiTickers ? page.cfg_multiTickers.trim() : "";
                                if (currentList === "") {
                                    page.cfg_multiTickers = model.symbol;
                                } else {
                                    var arr = currentList.split(",").map(function(s) { return s.trim(); });
                                    if (arr.indexOf(model.symbol) === -1) {
                                        page.cfg_multiTickers = currentList + ", " + model.symbol;
                                    }
                                }
                                page.cfg_isMultiMode = true;
                                searchHelpText.text = i18n("Added %1 to Multi Stock List.", model.symbol);
                            }
                        }
                    }
                }
            }
        }
    }
}
