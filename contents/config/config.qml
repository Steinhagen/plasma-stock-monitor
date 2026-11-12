import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Symbols & lists")
        icon: "view-list-text"
        source: "configSearch.qml"
    }
    ConfigCategory {
        name: i18n("Panel view")
        icon: "panel-fit-width"
        source: "configPanel.qml"
    }
    ConfigCategory {
        name: i18n("Mouse actions")
        icon: "input-mouse"
        source: "configMouse.qml"
    }
    ConfigCategory {
        name: i18n("Chart & News")
        icon: "office-chart-line"
        source: "configChart.qml"
    }
    ConfigCategory {
        name: i18n("Portfolio Tracking")
        icon: "view-financial-account-investment"
        source: "configPortfolio.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "configAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Import / Export")
        icon: "document-swap"
        source: "configBackup.qml"
    }
}
