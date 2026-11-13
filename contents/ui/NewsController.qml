import QtQuick
import "news.js" as News
import "bvbnews.js" as BvbNews

Item {
    id: newsController
    property var applet
    property var newsCache: ({})
    // Bumped when the cache is dropped, so a reply that was already on its way is ignored.
    property int newsGeneration: 0
    property int newsClock: 0

    readonly property var entry: newsCache[newsKey(applet.singleTicker)] || null
    readonly property var items: entry ? entry.items : []

    function newsKey(symbol) {
        return String(symbol || "").trim().toUpperCase();
    }

    // Copy-on-write, so bindings on newsCache (and newsEntry) re-evaluate.
    function setNewsEntry(key, changes) {
        var old = newsCache[key];
        var entry = old ? Object.assign({}, old)
                        : { items: [], yahooItems: [], bvbItems: [], time: 0, attempt: 0,
                            loaded: false, error: false, pending: false, nameTried: true,
                            remaining: 0 };
        Object.assign(entry, changes);
        var copy = Object.assign({}, newsCache);
        copy[key] = entry;
        newsCache = copy;
    }

    // Company name for the fallback query, only when it is known to belong to `symbol`.
    // In single mode the name keeps the previous ticker's value until the new quote
    // arrives, so it is trusted only once singleDataTicker matches. In multi mode it is
    // taken from the selected list row. Returns null while it is still unknown, and ""
    // when there is no name other than the ticker.
    function newsCompanyName(symbol) {
        var sym = String(symbol || "").trim();
        if (sym === "" || newsKey(applet.singleTicker) !== newsKey(sym)) return null;
        if (!applet.isMultiMode && applet.singleDataTicker !== applet.singleTicker) return null;
        var name = String(applet.singleCompanyName || "").trim();
        if (name === applet.loadingText) return null;
        if (name === "" || name.toUpperCase() === sym.toUpperCase()) return "";
        return name;
    }

    // Headlines from both providers, newest first. A link or title can appear in both
    // feeds (Yahoo sometimes carries the same BVB report), so either key removes it.
    // Each provider is already sliced to newsCount.
    function mergeNews(yahoo, bvb) {
        var merged = [];
        var seen = {};
        var add = function(items) {
            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                var linkKey = String(item.link || "").trim().toLowerCase();
                var titleKey = String(item.title || "").trim().toLowerCase();
                var lk = linkKey === "" ? "" : "l:" + linkKey;
                var tk = titleKey === "" ? "" : "t:" + titleKey;
                if ((lk !== "" && seen[lk]) || (tk !== "" && seen[tk])) continue;
                if (lk !== "") seen[lk] = true;
                if (tk !== "") seen[tk] = true;
                merged.push(item);
            }
        };
        add(yahoo || []);
        add(bvb || []);
        merged.sort(function(a, b) { return (Number(b.time) || 0) - (Number(a.time) || 0); });
        return merged;
    }

    // Called once for each provider. It keeps that provider's previous items when the
    // request failed, so a temporary error does not clear the list; `error` still drives
    // the "Could not update headlines" note.
    function finishNewsSource(key, source, items, error, nameTried) {
        var entry = newsCache[key];
        if (!entry || !entry.pending) return;
        var failed = error !== "";
        var changes = {};
        if (source === "yahoo") {
            changes.yahooItems = failed ? (entry.yahooItems || []) : (items || []);
            if (nameTried !== undefined) changes.nameTried = nameTried;
        } else if (source === "bvb") {
            changes.bvbItems = failed ? (entry.bvbItems || []) : (items || []);
        } else {
            return;
        }
        changes.items = mergeNews(
            changes.yahooItems !== undefined ? changes.yahooItems : entry.yahooItems,
            changes.bvbItems !== undefined ? changes.bvbItems : entry.bvbItems);
        changes.loaded = true;
        changes.error = entry.error || failed;
        if (!failed) changes.time = Date.now();
        changes.remaining = Math.max(0, (entry.remaining || 0) - 1);
        changes.pending = changes.remaining > 0;
        setNewsEntry(key, changes);
        if (failed) console.log("News headlines (" + source + "): " + error);
    }

    // Yahoo search request. The ticker query (allowBase false) falls back to a query with
    // the company name when Yahoo tags none of its headlines with the symbol, which is
    // common for non-US listings (LHA.DE); that query also accepts the base symbol.
    // The reply is stored under its own symbol even if the user has moved on.
    function fetchYahooNews(key, symbol, query, allowBase) {
        var generation = newsGeneration;
        var done = false;
        var finish = function(items, error, nameTried) {
            if (done) return;
            done = true;
            if (generation !== newsGeneration) return;
            finishNewsSource(key, "yahoo", items, error, nameTried);
        };
        var search = function(text, acceptBase) {
            var settled = false;
            var xhr = new XMLHttpRequest();
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE || settled) return;
                settled = true;
                if (xhr.status !== 200) {
                    finish([], "request failed (HTTP " + xhr.status + ")", true);
                    return;
                }
                var items;
                try {
                    items = News.parse(JSON.parse(xhr.responseText), symbol, acceptBase, applet.newsCount);
                } catch (e) {
                    finish([], "could not parse the reply: " + e, true);
                    return;
                }
                if (items.length === 0 && !acceptBase) {
                    var name = newsCompanyName(symbol);
                    if (name) {
                        search(name, true);
                        return;
                    }
                    // null: the name is not known yet; retryNewsWithName() runs it later.
                    finish([], "", name === "");
                    return;
                }
                finish(items, "", true);
            };
            xhr.ontimeout = function() {
                if (settled) return;
                settled = true;
                finish([], "request timed out", true);
            };
            xhr.onerror = function() {
                if (settled) return;
                settled = true;
                finish([], "request failed", true);
            };
            // No setRequestHeader: Yahoo answers 429 to non-browser User-Agents, and Qt
            // already sends "Mozilla/5.0".
            xhr.open("GET", News.searchUrl(text, applet.newsCount));
            xhr.timeout = 20000;
            xhr.send();
        };
        search(query || symbol, allowBase === true);
    }

    // BVB renders the latest five announcements in the instrument page, while the
    // "Stiri" tab postback returns the last 60. Replay the postback for the full list;
    // if its ASP.NET state cannot be found or the POST fails, keep the five from the GET.
    function fetchBvbNews(key, symbol) {
        var generation = newsGeneration;
        var done = false;
        var topItems = [];
        var finish = function(items, error) {
            if (done) return;
            done = true;
            if (generation !== newsGeneration) return;
            finishNewsSource(key, "bvb", items, error, true);
        };
        var url = BvbNews.detailUrl(symbol);
        if (url === "") {
            finish([], "");
            return;
        }
        var first = new XMLHttpRequest();
        var firstSettled = false;
        first.onreadystatechange = function() {
            if (first.readyState !== XMLHttpRequest.DONE || firstSettled) return;
            firstSettled = true;
            if (first.status !== 200) {
                finish([], "request failed (HTTP " + first.status + ")");
                return;
            }
            var html = first.responseText;
            topItems = BvbNews.parseTop(html, symbol, applet.newsCount);
            // The page already has five; for a five-headline request that is enough.
            if (topItems.length >= applet.newsCount) {
                finish(topItems, "");
                return;
            }
            var body = BvbNews.postBody(html);
            if (body === "") {
                finish(topItems, "");
                return;
            }
            var second = new XMLHttpRequest();
            var secondSettled = false;
            second.onreadystatechange = function() {
                if (second.readyState !== XMLHttpRequest.DONE || secondSettled) return;
                secondSettled = true;
                var items = [];
                if (second.status === 200)
                    items = BvbNews.parseFull(second.responseText, symbol, applet.newsCount);
                if (items.length === 0) items = topItems;
                finish(items, "");
            };
            second.ontimeout = function() { finish(topItems, ""); };
            second.onerror = function() { finish(topItems, ""); };
            second.open("POST", url);
            second.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            second.timeout = 20000;
            second.send(body);
        };
        first.ontimeout = function() { finish([], "request timed out"); };
        first.onerror = function() { finish([], "request failed"); };
        first.open("GET", url);
        first.timeout = 20000;
        first.send();
    }

    // Fetches the headlines for `symbol` unless they are fresh. `force` (the refresh
    // button and menu) skips the freshness and retry checks.
    function requestNews(symbol, force) {
        if (!applet.newsAvailable) return;
        var sym = String(symbol || "").trim();
        if (sym === "") return;
        var key = newsKey(sym);
        var entry = newsCache[key];
        var now = Date.now();
        if (entry && entry.pending) return;
        if (!force && entry) {
            if (entry.loaded && !entry.error && now - entry.time < applet.newsRefreshMinutes * 60000) {
                if (entry.nameTried === false) retryNewsWithName();
                return;
            }
            // Do not hammer the feeds after a failure; the next try comes with the
            // interval, the next time the pane opens, or the refresh button.
            if (now - entry.attempt < 60000) return;
        }
        var wantsYahoo = applet.newsSourceYahoo;
        var wantsBvb = applet.newsSourceBvb && BvbNews.baseSymbol(sym) !== "";
        var remaining = (wantsYahoo ? 1 : 0) + (wantsBvb ? 1 : 0);
        if (remaining === 0) return;
        setNewsEntry(key, { pending: true, remaining: remaining,
                                 attempt: now, error: false });
        if (wantsYahoo) fetchYahooNews(key, sym, sym, false);
        if (wantsBvb) fetchBvbNews(key, sym);
    }

    // Runs the company-name query for the shown symbol when its ticker query found
    // nothing before the name was known.
    function retryNewsWithName() {
        if (!applet.newsPaneShown || !applet.newsSourceYahoo) return;
        var sym = applet.singleTicker.trim();
        var key = newsKey(sym);
        var entry = newsCache[key];
        if (!entry || !entry.loaded || entry.pending || entry.nameTried !== false
                || (entry.yahooItems || []).length > 0) return;
        var name = newsCompanyName(sym);
        if (name === null) return;
        if (name === "") {
            setNewsEntry(key, { nameTried: true });
            return;
        }
        setNewsEntry(key, { pending: true, remaining: 1, attempt: Date.now() });
        fetchYahooNews(key, sym, name, true);
    }

    function openNewsLink(url) {
        Qt.openUrlExternally(News.safeLink(url, applet.singleTicker));
    }

    function openYahooNews(symbol) {
        var clean = symbol ? String(symbol).trim() : "";
        if (clean === "") return;
        Qt.openUrlExternally(News.newsPageUrl(clean));
    }

    function openBvbNews(symbol) {
        var url = BvbNews.detailUrl(symbol);
        if (url !== "") Qt.openUrlExternally(url);
    }

    // Bumped once a minute while the headlines are shown, so their ages re-evaluate.
    Timer {
        interval: 60000
        running: applet.newsPaneShown
        repeat: true
        // The binding is not evaluated while the pane is hidden, and the age timer only
        // ticks after a minute. Bump the clock as soon as the pane comes back, so the
        // "Updated ..." label does not keep the age from the previous visit until the
        // first tick (or until another change forces a re-evaluation).
        triggeredOnStart: true
        onTriggered: newsClock++
    }

    // "just now", "5 min ago", "2 h ago", "3 d ago", or the date after a week.
    function newsAge(timeSec) {
        // Read the clock so QML re-evaluates callers every minute.
        if (newsClock < 0) return "";
        if (!(timeSec > 0)) return "";
        var age = News.age(timeSec, Date.now());
        switch (age.unit) {
            case "now": return i18nc("@item:news age", "just now");
            case "min": return i18ncp("@item:news age", "%1 min ago", "%1 min ago", age.n);
            case "h": return i18ncp("@item:news age", "%1 h ago", "%1 h ago", age.n);
            case "d": return i18ncp("@item:news age", "%1 d ago", "%1 d ago", age.n);
            default: return new Date(timeSec * 1000).toLocaleDateString(Qt.locale(), "d MMM");
        }
    }

    // Starts (and fires at once) every time the pane comes on screen, then refreshes on
    // the interval. requestNews() skips the request while the cache is fresh.
    Timer {
        interval: Math.max(10, applet.newsRefreshMinutes) * 60000
        running: applet.newsPaneShown
        repeat: true
        triggeredOnStart: true
        onTriggered: requestNews(applet.singleTicker, false)
    }


    // The source selection changes what a cached entry can contain, so drop it. If the
    // current symbol has no remaining source, close the News pane and hide its icons.
    function refreshNewsSources() {
        newsGeneration++;
        newsCache = ({});
        if (!applet.newsAvailable) {
            applet.singleViewPane = "chart";
            return;
        }
        if (applet.newsPaneShown) requestNews(applet.singleTicker, true);
    }

    function invalidate() {
        newsGeneration++;
        newsCache = ({});
    }
}
