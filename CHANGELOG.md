# Changelog

All notable changes to Plasma Stock Monitor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Optional **News** headlines from Yahoo Finance for the shown stock (Chart & News page,
  off by default). Two small icons next to the market status switch the single-stock
  view between the chart and a scrollable list of the latest headlines, 24 by
  default (5–50). The list is fetched only while it is shown and refreshed at most
  every 30 minutes (10–240); a click opens the article. News is not available in the
  list-only view, and Yahoo has no news for some exchanges (for example Bucharest).
- Bucharest Stock Exchange symbols (ending in `.RO`) also get the issuer's latest
  announcements from BVB. The instrument page exposes the five newest directly; the
  full list (up to 60 entries) is returned by the "Stiri" tab postback and is sliced
  to the configured per-source count, with the five embedded entries as a fallback.
  BVB items are merged with Yahoo's headlines and labelled as the **BVB** source.
- A **News sources** selector on the same page; Yahoo Finance and BVB are both on by
  default. Turning every source off hides the Chart/News icons and closes the News
  pane.
- Source filter buttons in the News header, built from the sources of the shown
  headlines: one button when everything comes from the same source, or **All** plus
  each source when there are several. The buttons are built from the providers
  present in the shown headlines.

### Fixed
- Enabling the News option no longer reserves an empty control bar above the chart
  when the range buttons, the chart style buttons and the session note are all off.
  The bar appears only when it has something to show: those controls, the note, or
  the headlines pane with its "Updated…" line and refresh button.
- Toggling the chart range or style buttons no longer resizes the applet card. The
  minimum width now reserves room for both control groups regardless of which ones
  are shown. Previously the range row alone stayed under the 300 px floor, while
  adding the style buttons pushed the minimum past it and the whole widget resized.

## [1.5] - 2026-11-12

### Added
- The last successful quotes are stored in the applet configuration and shown at
  startup while the first request is in flight, so a launch without a network (or
  before a VPN connects) shows the previous values instead of placeholders. Cached
  values are marked as stale — the timestamp line and the tooltip show when they were
  fetched, and the panel shows an **OFF** tag with dimmed values. Only the list and
  single-view numbers are cached, not the chart, and a snapshot older than seven days
  is ignored.

### Fixed
- The last after-hours quote is no longer dropped when Yahoo timestamps its final
  print exactly at the session end (20:00:00 ET). Such a symbol kept showing only
  "Market closed" and "No after-hours quote" even though the extended session had
  data, while other tickers still showed their kept after-hours value. The same
  inclusive end now applies to the chart's after-hours zone and to the kept quote,
  so the final print is not missing from the chart either.
- A failed first quote request is now retried after 5 seconds and then with a
  backoff up to 30 seconds, instead of waiting for the next scheduled refresh. This
  keeps a network or VPN that is still starting at login from leaving the widget on
  its placeholder values for minutes.
- The divider between the regular and the pre-market/after-hours quote no longer
  moves with the prices. The space was split in proportion to the price widths, so
  the pre-market column sat further right for a wider price (for example NVDA versus
  INTC) and jumped while the price showed "—". The regular column now takes half of
  the row and grows past it only when its price would otherwise be cut off.

## [1.4] - 2026-11-11
### Added
- A **Line style** setting (Chart page): Smooth (default) or Straight segments, like
  Yahoo Finance.
- Theme settings with **Application** and **Plasma** presets. Application draws the
  widget's own cards; Plasma follows the system Plasma background, colors and popup.
- A **Colors** setting for the Application preset: Light, Dark or System, where System
  follows the Plasma color scheme.
- Fresh placements now default to **Plasma** + **System**.

### Changed
- The preset decides who draws the background: **Application** paints the widget's
  own cards, while **Plasma** keeps the system Plasma background and colors.
- With the **Application** background the expanded panel opens in a transparent
  popup so only the cards are visible; the compact panel indicator itself stays
  transparent over the panel.
- The compact panel indicator no longer paints a background in any theme. It stays
  transparent and uses the panel's colors, so it looks the same whichever preset or
  color mode is selected.
- The **Plasma** background is chosen automatically for the desktop and the expanded
  panel view. The separate **Background: Use the Plasma background** option is gone.
- Existing Light, Dark and Plasma choices are migrated to the new preset and colors.
  The removed Custom preset is mapped to Plasma or Application using its old desktop
  source.

### Fixed
- Plasma no longer draws a widget-made light/dark surface: the preset always follows
  the system theme, while Light/Dark/System only affect the Application preset.
- The Appearance page shows **System** for the Plasma preset instead of a stale
  Light/Dark value; the Application color choice is kept for switching back.
- The panel indicator's market-status tag and percentage badge no longer overlap; the
  two rows now keep a small positive gap.
- Moving the panel from horizontal to vertical and back no longer leaves the stock
  indicator clipped or overlapping the neighbouring applet. The compact indicator no
  longer forces its own size, the panel controls its cross-axis size, and its width
  reserves at least the values currently shown.
- The chart repaints immediately when the theme or its colors change, instead of
  keeping the old colors until the next quote update.
- The smoothed price line no longer overshoots or makes loops at sharp dips or across
  large time gaps (monotone cubic interpolation, straight segments across gaps).
- The chart hover dot and change text for pre-market and after-hours points are now red
  for a negative change and green for a positive one, instead of taking the color of the
  session's last value.

## [1.3] - 2026-11-11

### Added

- A **Mouse actions** settings page with Standard, Minimal and Custom presets, plus
  separate left-row, middle-click and double-click actions. Right click remains the
  context menu.

### Changed

- Reworked **Portfolio Tracking** into a responsive, table-first page: a clearly scoped
  single-row whole-portfolio settings area, a summary with the invested amount, current
  value, total gain and today's change, and an add/edit dialog. The duplicate Import
  button and the extra empty-state Add Lot button are gone.
- The lots table now shows each lot's current value and gain using live Yahoo quotes
  and the cached exchange rates, with a manual quote refresh. It is searchable and
  sortable, keeps lot details under the symbol, and gives every row its own Options
  column.
- Clarified that **Show gain/loss in the widget** only controls the summary on the
  widget's main panel; the portfolio table always shows values and gains.
- Standardized mouse actions: left click selects a watchlist row, double click opens
  Yahoo Finance, right click opens a context menu, and middle click refreshes.

### Fixed

- The portfolio page no longer grows a horizontal scrollbar when the holdings list is
  tall enough to scroll vertically.
- Monetary values in the portfolio page are formatted with thousands separators, like
  the widget (for example `RON 325,183.75`), including the portfolio summary, lot
  values and gains, average cost and the gain-per-share tooltip.
- The settings window enforces a minimum width, so the portfolio table, base-currency
  picker and toolbar are no longer clipped on narrow windows.
- Long lot details are elided under the symbol instead of spilling into the adjacent
  columns.

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

[Unreleased]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.5...HEAD
[1.5]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.4...v1.5
[1.4]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.3...v1.4
[1.3]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.2...v1.3
[1.2]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.1...v1.2
[1.1]: https://github.com/Steinhagen/plasma-stock-monitor/compare/v1.0...v1.1
[1.0]: https://github.com/Steinhagen/plasma-stock-monitor/releases/tag/v1.0
