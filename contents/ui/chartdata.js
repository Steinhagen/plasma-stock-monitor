.pragma library

function inExtendedSession(period, time, kind) {
    if (!period) return false;
    return time >= period.start && (kind === "post" ? time <= period.end : time < period.end);
}

// Parsing and aggregation for the Yahoo Finance chart response. Kept separate
// from main.qml so the quote/fetch workflow stays readable.

function tradingDays(meta) {
    function period(p) {
        if (p && p.length) p = p[0];
        return (p && p.start < p.end) ? p : null;
    }
    var days = [];
    var tp = meta ? meta.tradingPeriods : null;
    if (tp && tp.regular && tp.regular.length) {
        for (var i = 0; i < tp.regular.length; i++) {
            days.push({
                pre: tp.pre ? period(tp.pre[i]) : null,
                regular: period(tp.regular[i]),
                post: tp.post ? period(tp.post[i]) : null
            });
        }
    } else if (tp && tp.length) {
        for (var j = 0; j < tp.length; j++) days.push({ pre: null, regular: period(tp[j]), post: null });
    } else if (meta && meta.currentTradingPeriod) {
        var c = meta.currentTradingPeriod;
        days.push({ pre: period(c.pre), regular: period(c.regular), post: period(c.post) });
    }
    return days;
}
// Latest trading day whose regular session has at least one data point, or null.
function displayedDay(meta, timestamps) {
    if (!timestamps) return null;
    var days = tradingDays(meta);
    for (var d = days.length - 1; d >= 0; d--) {
        var reg = days[d].regular;
        if (!reg) continue;
        for (var i = 0; i < timestamps.length; i++) {
            if (timestamps[i] >= reg.start && timestamps[i] < reg.end) return days[d];
        }
    }
    return null;
}
// The session a 1D chart plots. Normally the latest completed regular session, but
// while the current pre-market is running (or before the first regular candle of the
// day arrives) its points are plotted instead, so the chart follows today's quote the
// same way a regular session does on exchanges without extended hours. Falls back to
// the regular session until the pre-market has a close, so the chart is never empty.
function chartDayFor(meta, timestamps, quotes) {
    var day = displayedDay(meta, timestamps);
    var periods = meta ? meta.currentTradingPeriod : null;
    if (!periods || !timestamps || !quotes) return day;
    // The current regular session is already on screen; keep the full-day chart.
    if (day && day.regular && periods.regular && day.regular.start === periods.regular.start)
        return day;
    var pre = periods.pre;
    if (!pre || !(pre.start < pre.end)) return day;
    for (var i = 0; i < timestamps.length; i++) {
        if (timestamps[i] >= pre.start && timestamps[i] < pre.end
                && quotes[i] !== null && quotes[i] !== undefined)
            return { pre: null, regular: pre, post: null };
    }
    return day;
}
// True when `day` is the running pre-market, i.e. the session chartDayFor substituted
// for the regular one. The pre period must be non-empty: exchanges without extended
// hours (BVB, for example) report an empty pre period that starts at the regular open,
// and that must not turn the regular session into a pre-market one.
function isPreSessionDay(meta, day) {
    var periods = meta ? meta.currentTradingPeriod : null;
    var pre = periods ? periods.pre : null;
    return !!(day && day.regular && pre && pre.start < pre.end
              && day.regular.start === pre.start
              && day.regular.end === pre.end);
}
// Pre-market and after-hours closes of `day`, or null when neither has any point.
function extendedSessionSeries(quotes, timestamps, day) {
    var preTimes = [], preValues = [], postTimes = [], postValues = [];
    for (var i = 0; i < quotes.length; i++) {
        var v = quotes[i], t = timestamps[i];
        if (v === null || v === undefined) continue;
        if (day.pre && inExtendedSession(day.pre, t, "pre")) { preTimes.push(t); preValues.push(v); }
        else if (day.post && inExtendedSession(day.post, t, "post")) { postTimes.push(t); postValues.push(v); }
    }
    if (preValues.length === 0 && postValues.length === 0) return null;
    return {
        preTimes: preTimes, preValues: preValues,
        postTimes: postTimes, postValues: postValues,
        regStart: day.regular.start, regEnd: day.regular.end,
        preStart: day.pre ? day.pre.start : 0,
        postEnd: day.post ? day.post.end : 0
    };
}
function cleanChartData(quotes, timestamps, startTime, range, quote, day) {
    var chartRange = range;
    var q = quote || {};
    var opens = q.open || null;
    var highs = q.high || null;
    var lows = q.low || null;
    var volumes = q.volume || null;
    var values = [], times = [], outOpens = [], outHighs = [], outLows = [], outVolumes = [];
    if (!quotes) return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };

    function addPoint(i) {
        var close = quotes[i];
        if (close === null || close === undefined) return;
        values.push(close);
        times.push(timestamps ? timestamps[i] : 0);
        outOpens.push(opens && opens[i] !== null && opens[i] !== undefined ? opens[i] : close);
        outHighs.push(highs && highs[i] !== null && highs[i] !== undefined ? highs[i] : close);
        outLows.push(lows && lows[i] !== null && lows[i] !== undefined ? lows[i] : close);
        outVolumes.push(volumes && volumes[i] !== null && volumes[i] !== undefined ? volumes[i] : 0);
    }

    var bounded = chartRange === "1D" && day && day.regular && timestamps;
    for (var i = 0; i < quotes.length; i++) {
        if (bounded) {
            // Extended-hours points are requested but belong to chartSessions, not here.
            if (timestamps[i] < day.regular.start || timestamps[i] >= day.regular.end) continue;
        } else if (chartRange === "1D" && startTime > 0 && timestamps && timestamps[i] < startTime)
            continue;
        addPoint(i);
    }

    if (!bounded && chartRange === "1D" && values.length === 0 && timestamps && timestamps.length > 0) {
        var dayStartIndex = 0;
        for (var j = timestamps.length - 1; j > 0; j--) {
            if (timestamps[j] - timestamps[j-1] > 4 * 3600) {
                dayStartIndex = j;
                break;
            }
        }
        for (var k = dayStartIndex; k < quotes.length; k++) addPoint(k);
    }
    return { values: values, times: times, opens: outOpens, highs: outHighs, lows: outLows, volumes: outVolumes };
}

// A session starts with a single tick before the next candle arrives. A one-point
// series cannot be drawn (the canvas needs two points), so the chart went blank
// between the first quote of the day and the second candle. Start the day's line at
// the previous close instead: the card then shows the move since yesterday from the
// first tick, and draws itself normally once the next candle arrives.
function seedFirstSessionPoint(chart, dayStart, meta) {
    if (!chart || !chart.values || chart.values.length !== 1) return;
    if (!chart.times || chart.times.length !== 1 || !(chart.times[0] > 0)) return;
    var dayTime = (dayStart > 0 && dayStart < chart.times[0]) ? dayStart : chart.times[0];
    var seed = dailyPreviousClose(meta, chart.values[0]);
    if (!(seed > 0)) seed = chart.values[0];
    chart.values.unshift(seed);
    chart.times.unshift(dayTime);
    chart.opens.unshift(seed);
    chart.highs.unshift(seed);
    chart.lows.unshift(seed);
    chart.volumes.unshift(0);
}

// Target number of candles for each range. The API intervals differ per range, so a
// fixed count keeps the candle width (and the visual density) comparable everywhere.
function candleTarget(range) {
    switch (range) {
        case "1D":  return 56;
        case "5D":  return 56;
        case "1M":  return 24;
        case "6M":  return 30;
        case "YTD": return 45;
        case "1Y":  return 52;
        case "5Y":  return 60;
        case "Max": return 60;
        default:    return 60;
    }
}

// Yesterday's close, independent of the chart range. Yahoo sends `previousClose` only
// for the 1D range; longer ranges still carry the day's change, so derive it from
// regularMarketPrice - fulldayChange (or from the change percentage).
function dailyPreviousClose(meta, fallback) {
    if (meta) {
        var prev = meta.regularMarketPreviousClose || meta.previousClose || 0;
        if (prev > 0) return prev;
        // `fulldayChange` is the most precise day change, but it can follow an
        // after-hours price; only use it while it still refers to the regular price.
        var regular = meta.regularMarketPrice;
        var fullDay = meta.fulldayPrice;
        if (regular > 0 && typeof meta.fulldayChange === "number"
                && (!(fullDay > 0) || Math.abs(fullDay - regular) < 0.005))
            return regular - meta.fulldayChange;
        if (regular > 0 && typeof meta.regularMarketChangePercent === "number"
                && meta.regularMarketChangePercent > -100)
            return regular / (1 + meta.regularMarketChangePercent / 100);
    }
    return fallback > 0 ? fallback : 0;
}

// Aggregate the aligned OHLCV series into `target` candles. Aggregating by count
// rather than by clock time keeps the same candle width across ranges and collapses
// weekends/holidays the way a trading chart does.
function buildCandles(chart, range, asked) {
    var n = chart && chart.values ? chart.values.length : 0;
    if (n < 2) return [];
    var target = Math.min(n, asked > 0 ? Math.round(asked) : candleTarget(range));
    var candles = [];
    for (var i = 0; i < target; i++) {
        var start = Math.floor(i * n / target);
        var end = Math.floor((i + 1) * n / target);
        if (end <= start) end = start + 1;
        if (start >= n) break;

        var open = chart.opens[start] !== undefined ? chart.opens[start] : chart.values[start];
        var close = chart.values[end - 1];
        var high = open;
        var low = open;
        var volume = 0;
        for (var j = start; j < end; j++) {
            var h = chart.highs[j] !== undefined ? chart.highs[j] : chart.values[j];
            var l = chart.lows[j] !== undefined ? chart.lows[j] : chart.values[j];
            if (h > high) high = h;
            if (l < low) low = l;
            volume += chart.volumes[j] || 0;
        }
        if (close > high) high = close;
        if (close < low) low = close;
        candles.push({
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            time: chart.times[start] || 0
        });
    }
    return candles;
}

// Candles for one extended session (pre or post) of the displayed day, so the
// candlestick chart can draw them around the regular session like the line chart.
// The target count follows the session length, keeping the zone widths proportional
// to time even though the candles are laid out by index.
function sessionCandles(quote, timestamps, period, day, zone) {
    if (!period || !quote || !timestamps) return [];
    var opens = [], highs = [], lows = [], closes = [], volumes = [], times = [];
    for (var i = 0; i < timestamps.length; i++) {
        var t = timestamps[i];
        if (!inExtendedSession(period, t, zone)) continue;
        var c = quote.close ? quote.close[i] : null;
        if (c === null || c === undefined) continue;
        closes.push(c);
        opens.push(quote.open && quote.open[i] !== null && quote.open[i] !== undefined ? quote.open[i] : c);
        highs.push(quote.high && quote.high[i] !== null && quote.high[i] !== undefined ? quote.high[i] : c);
        lows.push(quote.low && quote.low[i] !== null && quote.low[i] !== undefined ? quote.low[i] : c);
        volumes.push(quote.volume && quote.volume[i] !== null && quote.volume[i] !== undefined ? quote.volume[i] : 0);
        times.push(t);
    }
    if (closes.length < 2) return [];
    var target = candleTarget("1D");
    if (day && day.regular && day.regular.end > day.regular.start)
        target = Math.max(4, Math.round(target * (period.end - period.start)
                                           / (day.regular.end - day.regular.start)));
    var candles = buildCandles({ values: closes, times: times, opens: opens,
                                 highs: highs, lows: lows, volumes: volumes }, "1D", target);
    for (var c2 = 0; c2 < candles.length; c2++) candles[c2].zone = zone;
    return candles;
}

// The candle series for a 1D chart: the regular session plus the pre-market and
// after-hours sessions around it, each candle tagged with its zone.
function chartCandlesFor(chart, range, quote, timestamps, day) {
    var regular = buildCandles(chart, range);
    for (var i = 0; i < regular.length; i++) regular[i].zone = "regular";
    if (range !== "1D" || !day || !quote || !timestamps) return regular;
    var pre = day.pre ? sessionCandles(quote, timestamps, day.pre, day, "pre") : [];
    var post = day.post ? sessionCandles(quote, timestamps, day.post, day, "post") : [];
    if (pre.length === 0 && post.length === 0) return regular;
    return pre.concat(regular, post);
}
