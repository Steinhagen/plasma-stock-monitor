# Changelog

All notable changes to Plasma Stock Monitor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Reworked **Portfolio Tracking** into a responsive, table-first page: a clearly scoped
  single-row whole-portfolio settings area, a summary with the invested amount, current
  value, total gain and today's change, and an add/edit dialog. The duplicate Import
  button and the extra empty-state Add Lot button are gone.
- The lots table now shows each lot's current value and gain using live Yahoo quotes
  and the cached exchange rates, with a manual quote refresh. It is searchable and
  sortable, keeps lot details under the symbol, and keeps every column visible on
  narrow windows without horizontal scrolling. The symbol column takes the remaining
  width, the Date column is wide enough for full dates, every row has its own Options
  column, and the single-row toolbar keeps Add Lot visible. Long lot details are
  elided under the symbol so they cannot spill into the next columns.
- Clarified that **Show gain/loss in the widget** only controls the summary on the
  widget's main panel; the portfolio table always shows values and gains.
- Standardized mouse actions: left click selects a watchlist row, double click opens
  Yahoo Finance, right click opens a context menu, and middle click refreshes.
- Added a **Mouse actions** settings page with Standard, Minimal and Custom
  presets, plus separate left-row, middle-click and double-click actions. Right click
  remains the context menu.

## [1.2] - 2026-11-10

### Added

- An option in **Appearance → Panel popup** to show the expanded panel widget without
  Plasma's popup background, leaving only the widget's cards visible. The custom popup
  is created only when this option is used and can be resized like the standard Plasma
  popup. The option only applies when the widget is expanded from a panel, not on the
  desktop.

### Changed

- All chart options (style, range, in-chart buttons, hover and axes) now live together
  on a dedicated **Chart** settings page instead of being split between General and
  Appearance.
- Moved the symbol-list settings (display mode, two-list layout, ticker list, sorting
  and naming) from **General** to the renamed **Symbols & lists** page.
- The Romanian translation now uses consistent session terminology: **Înaintea
  deschiderii** for pre-market and **După închidere** for after-hours, with matching
  compact labels and panel tags.
- The market-data tooltip now separates the widget's last update from the next refresh,
  shows the Yahoo quote time, and marks delayed quotes with a compact badge.

### Fixed

- Remember the ticker selected in the multi-stock list across restarts, instead of
  falling back to the first ticker.
- Remove the empty strip below the portfolio total when update timestamps are hidden.
- At the regular market open, keep showing the last pre-market quote until the first
  regular quote arrives, instead of presenting the previous close as current data.
- Stabilize the widget size when it is opened without saved geometry: use a fixed
  minimum height and a preferred size instead of falling back to the content minimum.
- Fix a QML `priceText` reference error when refreshing the panel widget with the
  middle mouse button.

## [1.1] - 2026-11-10

### Added

- A tooltip on the market status in the chart header, showing how often the widget
  refreshes and the timestamp of the latest Yahoo Finance quote.
- The 1D chart plots the current pre-market once Yahoo has a quote for it, instead of
  keeping yesterday's chart until the regular open.
- When there is no current data to plot (weekend, holiday, or before the pre-market's
  first quote), the 1D chart keeps the last completed session and labels it, so it is
  not mistaken for today's data.
- The candlestick chart shows the pre-market and after-hours candles, with the same
  hatched zones and session tags as the line chart.

### Fixed

- Keep the last pre-market/after-hours quote when the trading day rolls over, so the
  "keep extended quote" option also works after a restart between sessions.
- The 1D chart no longer goes blank when a session starts with a single tick: the line
  now starts at the previous close until the next candle arrives.

### Documentation

- Added [`ROADMAP.md`](ROADMAP.md) with the issues planned for the next release.

## [1.0] - 2026-11-10

First public release.

### Added

- Single-stock and multi-stock views, including a side-by-side two-column layout with a
  draggable splitter.
- Reference-line and candlestick charts with volume, ranges from 1D to Max, optional
  in-chart range and style buttons, hover details, price scale and time axis.
- Pre-market and after-hours quotes, market open/closed status, and the last extended
  quote kept after the close.
- Portfolio tracking per purchase lot: shares, average cost, purchase date, notes,
  optional per-lot currency, profit/loss and totals in the portfolio currency.
- Panel view with price and change, optional alternating price/percentage, auto-cycling
  through the watchlist and middle-click refresh.
- Light, dark and Plasma themes, custom gain/loss and text colors, opacity, number
  formatting and decimal precision.
- Configurable refresh interval, active-hours-only updates, weekend skipping and a
  next-update indicator.
- Import and export of the watchlist, portfolio and settings as JSON.
- Ki18n localization with a complete Romanian translation.
- KDE Store release and automatic `.plasmoid` packaging for version tags.

[Unreleased]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.2...HEAD
[1.2]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.1...v1.2
[1.1]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.0...v1.1
[1.0]: https://github.com/Steinhagen/plasma-stock-monitor/releases/tag/v1.0
