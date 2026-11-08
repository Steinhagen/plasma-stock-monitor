# Plasma Stock Monitor for KDE Plasma 6

Plasma Stock Monitor is a clean, modern stock market widget for KDE Plasma 6. It pulls data directly from Yahoo Finance, covering stocks, crypto, and currencies worldwide.

> **Fork notice:** Plasma Stock Monitor is a fork of [Stock Monitor](https://github.com/vpsone/stock-monitor-widget) by [vps (vpsone)](https://github.com/vpsone), with UI contributions by [Cenk Tekin](https://github.com/cenktekin). See [Credits](#credits) for full attribution.

<p align="center">
    <a href="https://www.pling.com/p/2332661/">
        <img src="https://img.shields.io/badge/KDE_Store-Original_listing-blue?style=for-the-badge&logo=kde" alt="Original KDE Store listing">
    </a>
    <a href="https://ko-fi.com/vsh07">
        <img src="https://img.shields.io/badge/Buy_me_a_Kofi-donate-blue?style=for-the-badge&logo=kofi&color=%23FF6433" alt="Support on Ko-fi">
    </a>
</p>

![Widget Preview](screenshots/main.png)

## ✨ Latest Enhancements

- **Modern Badge UI:** Redesigned compact panel view with sleek, semi-transparent percentage badges for better readability.
- **Custom Gain/Loss Colors:** Added a built-in **Color Picker** in settings to customize gain and loss colors.
- **Improved Data Precision:** Enhanced price display with 2-decimal accuracy and integrated change percentages.
- **High Visibility:** Forced theme-independent colors to ensure visibility on all desktop backgrounds.

## 🚀 Features

- **Two Display Modes:** Single View and Multi-Stock List.
- **Beautiful Charts:** Smooth, gradient-filled charts that change color (Green/Red) based on performance.
- **Data Ranges:** View history from 1 Day (1D) up to 5 Years (5Y) or Max.
- **Smart & Efficient:**
  - Automatic "Previous Close" dashed line.
  - **Market status:** Shows when a market is closed, including indices and symbols without pre-/after-market quotes.
  - **Closed-market quotes:** Keeps the last pre-/after-market quote visible after the session ends (on by default).
  - **Battery Saver:** Option to stop updating when the market is closed.
  - Weekend detection logic.

<br>

## 🔍 How to Find Ticker Symbols

This widget pulls data directly from **Yahoo Finance**, so you need to use the exact ticker symbol listed on their website.

1.  Go to **[finance.yahoo.com](https://finance.yahoo.com)**.
2.  Search for the company, crypto, or index you want (e.g., "Bitcoin", "Apple").
3.  Copy the symbol shown in parentheses next to the name.

**Examples:**

- **US Stocks:** `AAPL`, `TSLA`, `MSFT`
- **Cryptocurrency:** `BTC-USD`, `ETH-USD`, `DOGE-USD`
- **Indices:** `^NSEI` (Nifty 50), `^GSPC` (S&P 500)
- **Currencies:** `INR=X` (USD/INR), `EURUSD=X`

<br>

## ⚙️ Configuration Options

You can right-click the widget and hit **"Configure..."** to tweak almost everything. Here is what you can change:

### 1\. General Settings

- **Display Mode:** Toggle between showing one big stock or a list of many.
- **Single Ticker:** If you are in Single Mode, type the symbol here (e.g., `AAPL`, `BTC-USD`, `GOOG`).
- **Ticker List:** If you are in Multi-Mode, enter a comma-separated list here (e.g., `TSLA, MSFT, GOOG`).
- **Data Range:** Choose the data range for stocks (`1D`, `5D`, `1M`, `6M`, `YTD`, `1Y`, `5Y`, `Max`).

### 2\. Updates & Interval

- **Refresh Interval:** How often the data updates (in Minutes). Default is 5 minutes.

### 3\. Active Hours (Battery Saver)

- **Only update during market hours:** Check this to prevent the widget from waking up your network when the stock market is closed.
- **Market Open/Close:** Set the start and end time (e.g., 09:15 to 15:30) matching your local stock exchange time.

![Config 1](screenshots/config1.png)
![Config 2](screenshots/config2.png)

## 📦 How to Install

This fork is not published on the KDE Store yet. Install it from source:

```bash
git clone https://github.com/Steinhagen/plasma-stock-monitor.git
cd plasma-stock-monitor
kpackagetool6 --type Plasma/Applet --install .
```

Then right-click the desktop or panel, choose **Add Widgets**, and search for **Plasma Stock Monitor**.

When updating an existing installation, use `--upgrade` instead of `--install`.

## Credits

Plasma Stock Monitor is a fork of [Stock Monitor](https://github.com/vpsone/stock-monitor-widget).

- **Original project:** [Stock Monitor](https://github.com/vpsone/stock-monitor-widget) by [vps (vpsone)](https://github.com/vpsone).
- **UI contributions:** [Cenk Tekin](https://github.com/cenktekin) — modern badge UI, custom gain/loss color picker, and improved price precision.
- **Original KDE Store listing:** [Stock Monitor on the KDE Store](https://store.kde.org/p/2332661/).
- **Upstream contributors:** [contributors to the original project](https://github.com/vpsone/stock-monitor-widget/graphs/contributors).
- **License:** GPL-3.0-or-later, inherited from the original project. Copyright remains with the original authors and contributors.
- **Fork:** [Steinhagen/plasma-stock-monitor](https://github.com/Steinhagen/plasma-stock-monitor), maintained by [Viorel-Cătălin Răpițeanu (Steinhagen)](https://github.com/Steinhagen).

This fork is independent and is not affiliated with or endorsed by the original authors. The KDE Store listing above belongs to the original project; this fork has no KDE Store release yet. Please report fork-specific issues in this repository rather than upstream.
