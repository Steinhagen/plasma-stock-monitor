.pragma library

// Analyst price-target history from Yahoo's quoteSummary endpoint. The endpoint is
// crumb-protected (see AnalystController.qml), so unlike the chart and news APIs it
// needs the Yahoo cookie plus the crumb token. The reply carries:
//   upgradeDowngradeHistory.history[] - firm, date, rating and price-target changes
//   financialData                      - the current consensus target and its range
//
// The reply is large (hundreds of entries for a liquid US stock), so keep only the
// price-target changes that can be drawn on the chart.

// Yahoo returns numbers either directly or as { raw, fmt } in quoteSummary modules.
function numeric(value) {
    if (value === undefined || value === null) return 0;
    if (typeof value === "object") value = value.raw;
    var n = Number(value);
    return isFinite(n) ? n : 0;
}

function trimmed(value) {
    return String(value === undefined || value === null ? "" : value).trim();
}

// Direction of a price-target action. `priceTargetAction` is the primary source;
// deriving from the two targets covers newer spellings and "Adjusts" entries.
function targetKind(entry) {
    var target = numeric(entry.currentPriceTarget);
    var prior = numeric(entry.priorPriceTarget);
    if (!(target > 0)) return "";
    var action = trimmed(entry.priceTargetAction).toLowerCase();
    if (action === "raises" || action === "raised") return "up";
    if (action === "lowers" || action === "lowered") return "down";
    if (action === "maintains" || action === "maintained") return "maintain";
    if (action === "announces" || action === "announced"
            || action === "sets" || action === "set") return "announce";
    // Unknown or empty action: fall back to the targets themselves.
    if (prior > 0 && target > prior) return "up";
    if (prior > 0 && target < prior) return "down";
    if (prior > 0 && target === prior) return "maintain";
    return "announce";
}

// [up, down, maintain, announce] counts for a group of entries. Used both for the
// marker direction and for the popup caption.
function directions(entries) {
    var counts = { up: 0, down: 0, maintain: 0, announce: 0 };
    for (var i = 0; i < entries.length; i++) {
        var kind = entries[i].kind;
        if (counts[kind] !== undefined) counts[kind]++;
    }
    return counts;
}

function parseSummary(financialData) {
    var fd = financialData || {};
    var count = numeric(fd.numberOfAnalystOpinions);
    return {
        mean: numeric(fd.targetMeanPrice),
        high: numeric(fd.targetHighPrice),
        low: numeric(fd.targetLowPrice),
        current: numeric(fd.currentPrice),
        count: count
    };
}

// Headline number for the marker tooltip: "N actions", or "N actions · last: ...".
function parse(reply) {
    var items = [];
    var result = reply && reply.quoteSummary && reply.quoteSummary.result;
    var data = result && result[0];
    if (!data) return { items: items, summary: parseSummary(null) };
    var history = data.upgradeDowngradeHistory
                  && data.upgradeDowngradeHistory.history;
    if (Array.isArray(history)) {
        for (var i = 0; i < history.length; i++) {
            var entry = history[i];
            if (!entry) continue;
            var time = numeric(entry.epochGradeDate);
            var firm = trimmed(entry.firm);
            if (!(time > 0) || firm === "") continue;
            var kind = targetKind(entry);
            if (kind === "") continue;
            var target = numeric(entry.currentPriceTarget);
            var prior = numeric(entry.priorPriceTarget);
            // Ignore malformed rows such as a negative or zero target.
            if (!(target > 0)) continue;
            items.push({
                kind: kind,
                time: time,
                firm: firm,
                target: target,
                prior: prior,
                ratingAction: trimmed(entry.action),
                fromGrade: trimmed(entry.fromGrade),
                toGrade: trimmed(entry.toGrade)
            });
        }
    }
    // Newest first: the popup and the "latest action" tooltip both read from the top.
    items.sort(function(a, b) { return b.time - a.time; });
    return { items: items, summary: parseSummary(data.financialData) };
}
