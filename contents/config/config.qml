import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Find ticker symbol")
        icon: "search"
        source: "configSearch.qml"
    }
    ConfigCategory {
        name: i18n("Panel view")
        icon: "view-list-details"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: i18n("Portfolio Tracking")
        icon: "office-chart-line"
        source: "configPortfolio.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Import / Export")
        icon: "document-save-as"
        source: "configBackup.qml"
    }
}
