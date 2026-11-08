import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: page

    property string cfg_ticker
    property string cfg_multiTickers
    property bool cfg_isMultiMode

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
