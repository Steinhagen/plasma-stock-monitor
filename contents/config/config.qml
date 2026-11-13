import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "config/general.qml"
    }
    ConfigCategory {
        name: i18n("Symbols & Lists")
        icon: "view-list-text"
        source: "config/symbolsLists.qml"
    }
    ConfigCategory {
        name: i18n("Panel view")
        icon: "panel-fit-width"
        source: "config/panelView.qml"
    }
    ConfigCategory {
        name: i18n("Mouse actions")
        icon: "input-mouse"
        source: "config/mouseActions.qml"
    }
    ConfigCategory {
        name: i18n("Chart & News")
        icon: "office-chart-line"
        source: "config/chartNews.qml"
    }
    ConfigCategory {
        name: i18n("Portfolio Tracking")
        icon: "view-financial-account-investment"
        source: "config/portfolio.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "preferences-desktop-color"
        source: "config/appearance.qml"
    }
    ConfigCategory {
        name: i18n("Import / Export")
        icon: "document-swap"
        source: "config/importExport.qml"
    }
}
