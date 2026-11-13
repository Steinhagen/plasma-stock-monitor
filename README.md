# Plasma Stock Monitor

A clean stock, crypto and currency widget for **KDE Plasma 6**, powered by Yahoo Finance.

[![KDE Store](https://img.shields.io/badge/KDE%20Store-Install-blue)](https://store.kde.org/p/2381512/)

![Plasma Stock Monitor](screenshots/main.png)

## Features

- **Two display modes:** a single-stock view or a multi-stock list, including a side-by-side layout.
- **Symbol display:** show the full Yahoo Finance symbol, the base symbol, or the base symbol with a short exchange badge (`BRD · BVB`) in the list, single-stock header, panel and tooltip.
- **Charts:** reference-line or candlestick, with an optional trading-volume strip for either style, ranges from 1D to Max and optional in-chart range buttons.
- **News (optional):** the latest headlines from the selected sources — Yahoo Finance and BVB (the latter for symbols ending in `.RO`), both on by default — switched with the chart/news icons next to the market status in the single-stock view. The sources, the number of headlines per source and the update interval are configured on the **Chart & News** page; source buttons filter the list by provider when more than one is available.
- **Live context:** pre-market and after-hours quotes, market status, and the last extended quote kept after close.
- **Portfolio:** track purchase lots, profit/loss and multiple currencies.
- **Appearance:** Application and Plasma presets; Application supports Light/Dark/System colors, while Plasma follows the system theme, plus a transparent panel indicator, custom gain/loss colors and opacity.
- **Smart updates:** configurable refresh interval, market-hours-only updates and weekend skipping, plus a quick retry after a failed request at startup.
- **Stale fallback:** the last successful quotes are shown at launch (marked as cached, with their timestamp) while the first request is in flight, so a missing network does not leave the widget empty.
- **Backup:** export and import the portfolio, watchlist and settings as JSON.
- **Localized:** gettext/Ki18n support with a complete Romanian translation included.

## Installation

### KDE Store

Install **Plasma Stock Monitor** from the [KDE Store](https://store.kde.org/p/2381512/).

You can also open **Add Widgets → Get New Widgets → Download New Plasma Widgets** on your desktop or panel and search for **Plasma Stock Monitor**.

### From source

```bash
git clone https://github.com/Steinhagen/plasma-stock-monitor.git
cd plasma-stock-monitor
kpackagetool6 --type Plasma/Applet --install .
```

Then right-click the desktop or panel, choose **Add Widgets**, and search for **Plasma Stock Monitor**.

To update an existing source installation, use `--upgrade` instead of `--install`.

## Configuration

Right-click the widget and choose **Configure...** to change the display mode, tickers, chart style, refresh interval, theme, colors and portfolio holdings. New widgets start with the **Plasma** preset, which follows the system theme; the Appearance page lets you switch to the widget's own Application cards and choose their Light/Dark/System colors. The same dialog can export or import a JSON backup of your data and settings.

Ticker symbols must match [Yahoo Finance](https://finance.yahoo.com). For example:

| Type | Examples |
| --- | --- |
| US stocks | `AAPL`, `TSLA`, `MSFT` |
| Crypto | `BTC-USD`, `ETH-USD` |
| Indices | `^GSPC`, `^NSEI` |
| Currencies | `EURUSD=X`, `INR=X` |

## Localization

All user-visible text is translatable through Ki18n, and a Romanian translation ships with the widget. To add another language, see [translate/README.md](translate/README.md).

## Credits

Plasma Stock Monitor is a fork of [Stock Monitor](https://github.com/vpsone/stock-monitor-widget) by [vps (vpsone)](https://github.com/vpsone), with UI contributions by [Cenk Tekin](https://github.com/cenktekin) (badge UI, gain/loss color picker and price precision). The fork is maintained by [Viorel-Cătălin Răpițeanu (Steinhagen)](https://github.com/Steinhagen).

Parts of this fork were developed with the assistance of AI coding tools.

This fork is independent and is not affiliated with or endorsed by the original authors.

**License:** GPL-3.0-or-later. Copyright remains with the original authors and contributors.
