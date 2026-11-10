# Changelog

All notable changes to Plasma Stock Monitor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- An option in **Panel view** to show the expanded panel widget without Plasma's popup
  background, leaving only the widget's cards visible.

### Changed

- All chart options (style, range, in-chart buttons, hover and axes) now live together
  on a dedicated **Chart** settings page instead of being split between General and
  Appearance.

### Fixed

- Create the optional custom panel popup only when the no-background option is used,
  so the default configuration does not instantiate it at startup.
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

[Unreleased]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.1...HEAD
[1.1]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.0...v1.1
[1.0]: https://github.com/Steinhagen/plasma-stock-monitor/releases/tag/v1.0
