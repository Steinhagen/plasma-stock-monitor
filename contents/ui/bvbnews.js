.pragma library
// Issuer news for symbols traded on the Bucharest Stock Exchange (Yahoo symbols
// ending in .RO). The instrument page server-renders the five newest announcements;
// its "Stiri" tab is an ASP.NET postback that returns the last 60 announcements in one
// HTML table (the page's DataTables only paginates them client-side). Replaying that
// postback gives us the full list, which the caller slices to the configured count.
//
// There is no JSON endpoint for these headlines; the page is parsed as HTML. If the
// postback cannot be built or fails, the five entries from the first GET are used.

var SOURCE = "BVB";
var PAGE = "https://www.bvb.ro/FinancialInstruments/Details/FinancialInstrumentsDetails.aspx?s=";

// EL.RO -> EL. Only the simple BVB tickers are accepted; symbols with other exchange
// suffixes are not Bucharest listings and have no page on this site.
function baseSymbol(symbol) {
    var sym = String(symbol === undefined || symbol === null ? "" : symbol).trim().toUpperCase();
    if (!/\.RO$/.test(sym)) return "";
    var base = sym.substring(0, sym.length - 3).trim();
    return /^[A-Z0-9]{1,12}$/.test(base) ? base : "";
}

function detailUrl(symbol) {
    var base = baseSymbol(symbol);
    return base === "" ? "" : PAGE + encodeURIComponent(base);
}

// HTML entities in titles are shown as text, so decode them once.
function decodeEntities(s) {
    var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'" };
    return String(s === undefined || s === null ? "" : s).replace(/&(#[xX][0-9a-fA-F]+|#[0-9]+|amp|lt|gt|quot|apos);/g,
        function (match, entity) {
            if (entity.charAt(0) !== "#") return named[entity];
            var hex = entity.charAt(1) === "x" || entity.charAt(1) === "X";
            var code = parseInt(entity.substring(hex ? 2 : 1), hex ? 16 : 10);
            if (!isFinite(code) || code <= 0 || code > 0x10FFFF) return match;
            return String.fromCodePoint(code);
        });
}

// BVB prints dd.MM.yyyy HH:mm:ss in Romanian local time. The widget runs on the
// user's clock, so this is parsed in the local time zone like the rest of the UI.
function parseTime(text) {
    var m = /^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})$/.exec(String(text).trim());
    if (!m) return 0;
    var d = new Date(Number(m[3]), Number(m[2]) - 1, Number(m[1]),
                     Number(m[4]), Number(m[5]), Number(m[6]));
    var t = Math.floor(d.getTime() / 1000);
    return isFinite(t) ? t : 0;
}

function absoluteLink(href) {
    var link = String(href === undefined || href === null ? "" : href).trim();
    if (link === "") return "";
    if (/^https?:\/\//i.test(link)) return link;
    if (link.indexOf("//") === 0) return "https:" + link;
    if (link.charAt(0) === "/") return "https://www.bvb.ro" + link;
    return "https://www.bvb.ro/" + link;
}

// Read an attribute from one input tag, whichever order the attributes use.
function inputValue(tag, name) {
    if (!new RegExp('\\bname="' + name + '"').test(tag)) return null;
    var m = new RegExp('\\bvalue="([^"]*)"').exec(tag);
    return m ? m[1] : "";
}

function hiddenValue(html, name) {
    var tags = String(html).match(/<input[^>]*>/gi) || [];
    for (var i = 0; i < tags.length; i++) {
        var value = inputValue(tags[i], name);
        if (value !== null) return value;
    }
    return "";
}

// The "Stiri" tab is a submit input named ctl00$body$IFTC$<guid>. Its GUID changes
// between page builds, so locate it by its visible label and the IFTC prefix.
function tabButtonName(html) {
    var tags = String(html).match(/<input[^>]*>/gi) || [];
    for (var i = 0; i < tags.length; i++) {
        var tag = tags[i];
        if (!new RegExp('\\bvalue="Stiri"', "i").test(tag)
                || !new RegExp('\\bname="[^"]*IFTC[^"]*"', "i").test(tag)) continue;
        var m = new RegExp('\\bname="([^"]+)"').exec(tag);
        if (m) return m[1];
    }
    return "";
}

// POST body that selects the "Stiri" tab. Returns "" when the page did not expose
// the ASP.NET state needed for the postback, in which case the top five are used.
function postBody(html) {
    var viewState = hiddenValue(html, "__VIEWSTATE");
    var validation = hiddenValue(html, "__EVENTVALIDATION");
    var generator = hiddenValue(html, "__VIEWSTATEGENERATOR");
    var button = tabButtonName(html);
    if (viewState === "" || validation === "" || button === "") return "";
    return "__VIEWSTATE=" + encodeURIComponent(viewState)
        + "&__VIEWSTATEGENERATOR=" + encodeURIComponent(generator)
        + "&__EVENTVALIDATION=" + encodeURIComponent(validation)
        + "&__EVENTTARGET="
        + "&" + encodeURIComponent(button) + "=" + encodeURIComponent("Stiri");
}

// Rows are: title (input.mLnkbttS), date (p.date), one or two PDF links (the first
// one is the Romanian document). The table is already newest-first; sorting by the
// parsed time keeps it correct and drops rows without a title.
function parseTable(html, tableId, symbol, limit) {
    var table = new RegExp('<table[^>]*\\bid="' + tableId + '"[\\s\\S]*?</table>', "i").exec(String(html));
    if (!table) return [];
    var rows = table[0].match(/<tr\b[\s\S]*?<\/tr>/gi) || [];
    var base = baseSymbol(symbol);
    var items = [];
    var seen = {};
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var input = new RegExp('<input[^>]*\\bclass="[^"]*mLnkbttS[^"]*"[^>]*>', "i").exec(row);
        if (!input) continue;
        var titleMatch = new RegExp('\\bvalue="([^"]*)"', "i").exec(input[0]);
        if (!titleMatch) continue;
        var title = decodeEntities(titleMatch[1]).trim();
        if (title === "") continue;
        var dateMatch = new RegExp('<p[^>]*\\bclass="date[^"]*"[^>]*>([^<]*)<\\/p>', "i").exec(row);
        var time = dateMatch ? parseTime(dateMatch[1]) : 0;
        var linkMatch = new RegExp("<a[^>]*\\bhref='([^']+)'", "i").exec(row);
        var link = linkMatch ? absoluteLink(linkMatch[1]) : detailUrl(symbol);
        var key = String(link || title).toLowerCase();
        if (seen[key]) continue;
        seen[key] = true;
        items.push({
            id: "bvb:" + base + ":" + (link || title),
            title: title,
            publisher: SOURCE,
            source: SOURCE,
            link: link,
            time: time
        });
    }
    items.sort(function (a, b) { return (b.time || 0) - (a.time || 0); });
    var max = Number(limit);
    return max >= 0 ? items.slice(0, max) : items;
}

// The five announcements embedded in the instrument page.
function parseTop(html, symbol, limit) {
    var items = parseTable(html, "gv5News", symbol, limit);
    return items.length > 0 ? items : parseTable(html, "gv", symbol, limit);
}

// The full list returned by the "Stiri" postback (up to 60 announcements).
function parseFull(html, symbol, limit) {
    var items = parseTable(html, "gv", symbol, limit);
    return items.length > 0 ? items : parseTable(html, "gv5News", symbol, limit);
}
