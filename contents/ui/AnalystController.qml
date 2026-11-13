import QtQuick
import "analyst.js" as Analyst

// Analyst price-target history for the shown stock. Yahoo's quoteSummary endpoint is
// crumb-protected, so a successful call needs the cookie set by fc.yahoo.com and the
// crumb token returned by /v1/test/getcrumb. Both are kept for the session. Each symbol
// is cached with its own fetch time; the data lives in memory only, like the headlines.
Item {
    id: analystController
    property var applet
    property var cache: ({})
    property string crumb: ""
    property bool crumbLoading: false
    property var crumbQueue: []

    readonly property string symbol: applet ? String(applet.singleTicker || "").trim() : ""
    readonly property var entry: cache[newsKey(symbol)] || null
    readonly property var items: entry ? entry.items : []
    readonly property var summary: entry ? entry.summary : null
    readonly property bool pending: entry ? entry.pending === true : false
    readonly property bool error: entry ? entry.error === true : false

    // Analyst actions move slowly; a fresh copy is enough for hours. A failed request
    // is retried only after a minute, so opening the pane or changing options cannot
    // hammer Yahoo.
    readonly property int cacheMinutes: 6 * 60
    readonly property int retryMilliseconds: 60 * 1000

    function newsKey(symbol) {
        return String(symbol || "").trim().toUpperCase();
    }

    // Copy-on-write, so the QML bindings on `entry`, `items` and `summary` update.
    function setEntry(key, changes) {
        var old = cache[key];
        var entry = old ? Object.assign({}, old)
                        : { items: [], summary: null, time: 0, attempt: 0,
                            loaded: false, error: false, pending: false };
        Object.assign(entry, changes);
        var copy = Object.assign({}, cache);
        copy[key] = entry;
        cache = copy;
    }

    function invalidate() {
        cache = ({});
    }

    // Fetches the price-target history for `symbol` unless a fresh copy is cached.
    function request(symbol, force) {
        if (!applet || !applet.showAnalystTargets) return;
        var sym = String(symbol || "").trim();
        if (sym === "") return;
        var key = newsKey(sym);
        var entry = cache[key];
        var now = Date.now();
        if (entry && entry.pending) return;
        if (!force && entry && entry.loaded
                && now - (entry.time || 0) < cacheMinutes * 60000)
            return;
        if (!force && entry && entry.attempt
                && now - entry.attempt < retryMilliseconds)
            return;
        setEntry(key, { pending: true, attempt: now, error: false });
        ensureCrumb(function(token) {
            fetchSummary(key, sym, token, false);
        }, function(error) {
            finish(key, null, null, error);
        });
    }

    // One crumb request at a time; callers wait until it succeeds or fails.
    function ensureCrumb(onSuccess, onFailure) {
        if (crumb !== "") {
            onSuccess(crumb);
            return;
        }
        crumbQueue.push({ success: onSuccess, failure: onFailure });
        if (crumbLoading) return;
        crumbLoading = true;

        var fc = new XMLHttpRequest();
        var fcDone = false;
        var next = function() {
            if (fcDone) return;
            fcDone = true;
            requestCrumb();
        };
        fc.onreadystatechange = function() {
            if (fc.readyState === XMLHttpRequest.DONE) next();
        };
        fc.ontimeout = next;
        fc.onerror = next;
        fc.open("GET", "https://fc.yahoo.com");
        fc.timeout = 15000;
        fc.send();
    }

    function requestCrumb() {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                var token = String(xhr.responseText || "").trim();
                if (token !== "") {
                    crumb = token;
                    finishCrumb("");
                    return;
                }
            }
            finishCrumb("crumb request failed (HTTP " + xhr.status + ")");
        };
        xhr.ontimeout = function() { finishCrumb("crumb request timed out"); };
        xhr.onerror = function() { finishCrumb("crumb request failed"); };
        xhr.open("GET", "https://query1.finance.yahoo.com/v1/test/getcrumb");
        xhr.timeout = 15000;
        xhr.send();
    }

    function finishCrumb(error) {
        var queue = crumbQueue;
        crumbQueue = [];
        crumbLoading = false;
        for (var i = 0; i < queue.length; i++) {
            if (error === "") queue[i].success(crumb);
            else queue[i].failure(error);
        }
        if (error !== "") console.log("Analyst price targets: " + error);
    }

    function summaryUrl(symbol, token) {
        return "https://query1.finance.yahoo.com/v10/finance/quoteSummary/"
             + encodeURIComponent(symbol)
             + "?modules=upgradeDowngradeHistory,financialData&crumb="
             + encodeURIComponent(token);
    }

    function fetchSummary(key, symbol, token, retried) {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 401 && !retried) {
                // The crumb has expired (or was issued for another cookie). Get a new one
                // once and retry the same symbol.
                crumb = "";
                ensureCrumb(function(nextToken) {
                    fetchSummary(key, symbol, nextToken, true);
                }, function(error) {
                    finish(key, null, null, error);
                });
                return;
            }
            if (xhr.status !== 200) {
                finish(key, null, null, "request failed (HTTP " + xhr.status + ")");
                return;
            }
            var parsed;
            try {
                parsed = Analyst.parse(JSON.parse(xhr.responseText));
            } catch (e) {
                finish(key, null, null, "could not parse the reply: " + e);
                return;
            }
            finish(key, parsed.items, parsed.summary, "");
        };
        xhr.ontimeout = function() { finish(key, null, null, "request timed out"); };
        xhr.onerror = function() { finish(key, null, null, "request failed"); };
        xhr.open("GET", summaryUrl(symbol, token));
        xhr.timeout = 20000;
        xhr.send();
    }

    function finish(key, items, summary, error) {
        var old = cache[key];
        var failed = error !== "";
        var changes = {
            loaded: true,
            pending: false,
            error: failed,
            attempt: old ? (old.attempt || 0) : 0
        };
        if (failed) {
            // Keep the previous successful data; a temporary outage must not erase it.
            changes.items = old ? (old.items || []) : [];
            changes.summary = old ? (old.summary || null) : null;
            changes.time = old ? (old.time || 0) : 0;
            console.log("Analyst price targets: " + error);
        } else {
            changes.items = Array.isArray(items) ? items : [];
            changes.summary = summary || null;
            changes.time = Date.now();
        }
        setEntry(key, changes);
    }
}
