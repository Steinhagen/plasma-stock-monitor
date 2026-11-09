# Plasma Stock Monitor

A clean stock, crypto and currency widget for **KDE Plasma 6**, powered by Yahoo Finance.

> This is a fork of [Stock Monitor](https://github.com/vpsone/stock-monitor-widget) by [vps (vpsone)](https://github.com/vpsone), with UI contributions by [Cenk Tekin](https://github.com/cenktekin). See [Credits](#credits).

![Plasma Stock Monitor](screenshots/main.png)

## Features

- **Two display modes:** a single-stock view or a multi-stock list, including a side-by-side layout.
- **Charts:** reference-line or candlestick + volume, with ranges from 1D to Max and optional in-chart range buttons.
- **Live context:** pre-market and after-hours quotes, market status, and the last extended quote kept after close.
- **Portfolio:** track purchase lots, profit/loss and multiple currencies.
- **Appearance:** light, dark and Plasma themes; custom gain/loss colors, opacity and panel options.
- **Smart updates:** configurable refresh interval, market-hours-only updates and weekend skipping.
- **Backup:** export and import the portfolio, watchlist and settings as JSON.
- **Localized:** gettext/Ki18n support with a complete Romanian translation included.

## Installation

This fork is not published on the KDE Store yet, so install it from source:

```bash
git clone https://github.com/Steinhagen/plasma-stock-monitor.git
cd plasma-stock-monitor
kpackagetool6 --type Plasma/Applet --install .
```

Then right-click the desktop or panel, choose **Add Widgets**, and search for **Plasma Stock Monitor**.

To update an existing installation, use `--upgrade` instead of `--install`.

## Configuration

Right-click the widget and choose **Configure...** to change the display mode, tickers, chart style, refresh interval, colors and portfolio holdings. The same dialog can export or import a JSON backup of your data and settings.

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

- **Original project:** [Stock Monitor](https://github.com/vpsone/stock-monitor-widget) by [vps (vpsone)](https://github.com/vpsone)
- **UI contributions:** [Cenk Tekin](https://github.com/cenktekin) — badge UI, gain/loss color picker and price precision
- **Fork maintained by:** [Viorel-Cătălin Răpițeanu (Steinhagen)](https://github.com/Steinhagen)
- **License:** GPL-3.0-or-later. Copyright remains with the original authors and contributors.

This fork is independent and is not affiliated with or endorsed by the original authors. Please report fork-specific issues in this repository.
