.pragma library

// Reading, validating and writing the JSON backup files used by the Import / Export
// configuration page. Keeping this in a small library (instead of in the page) makes
// the format easy to test and keeps the QML side focused on the UI.

var APPLICATION_ID = "io.github.steinhagen.plasmastockmonitor";
var FORMAT_VERSION = 1;

// "Portfolio and watchlist" data. These settings are exported together with the lots
// because a portfolio total is meaningless without its currency and display mode.
var DATA_KEYS = [
    "ticker",
    "isMultiMode",
    "showTwoList",
    "multiTickers",
    "portfolioData",
    "showPortfolioMode",
    "portfolioCurrency"
];

// Everything else the user can configure. The exchange-rate cache is deliberately not
// part of a backup: it is downloaded again and is not a user preference.
var SETTINGS_KEYS = [
    "selectedTheme",
    "sortAlphabetically",
    "swapNameAndTicker",
    "showNameAndTicker",
    "refreshInterval",
    "chartRange",
    "limitHours",
    "skipWeekendRefresh",
    "startHour",
    "startMinute",
    "endHour",
    "endMinute",
    "tickerColor",
    "tickerOpacity",
    "priceColor",
    "priceOpacity",
    "positiveColor",
    "negativeColor",
    "bgOpacity",
    "hideChangePercentage",
    "autoCycle",
    "autoCycleInterval",
    "hideTimestamps",
    "alternatePricePercent",
    "alternateInterval",
    "fixedPanelWidth",
    "panelWidth",
    "formatPrices",
    "showExtendedHours",
    "keepExtendedAfterClose",
    "hideDecimals",
    "showChartAxis"
];

var BOOL_KEYS = {
    isMultiMode: true,
    showTwoList: true,
    showPortfolioMode: true,
    sortAlphabetically: true,
    swapNameAndTicker: true,
    showNameAndTicker: true,
    limitHours: true,
    skipWeekendRefresh: true,
    hideTimestamps: true,
    hideChangePercentage: true,
    autoCycle: true,
    alternatePricePercent: true,
    fixedPanelWidth: true,
    formatPrices: true,
    showExtendedHours: true,
    keepExtendedAfterClose: true,
    hideDecimals: true,
    showChartAxis: true
};

// [minimum, maximum] for every integer setting. The ranges mirror the SpinBoxes and
// Sliders in the configuration pages, so an imported value cannot put the UI in a state
// it would not let the user create.
var INT_RANGES = {
    selectedTheme: [0, 2],
    refreshInterval: [1, 360],
    startHour: [0, 23],
    startMinute: [0, 59],
    endHour: [0, 23],
    endMinute: [0, 59],
    tickerOpacity: [0, 100],
    priceOpacity: [0, 100],
    bgOpacity: [0, 100],
    autoCycleInterval: [3, 3600],
    alternateInterval: [3, 3600],
    panelWidth: [0, 1000]
};

var COLOR_KEYS = {
    tickerColor: true,
    priceColor: true,
    positiveColor: true,
    negativeColor: true
};

var CHART_RANGES = ["1D", "5D", "1M", "6M", "YTD", "1Y", "5Y", "Max"];

function has(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
}

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isNumber(value) {
    return typeof value === "number" && isFinite(value);
}

function failure(code, key, detail) {
    return { ok: false, code: code, key: key || "", detail: detail || "" };
}

function copyObject(object) {
    var copy = {};
    for (var key in object) {
        if (has(object, key)) copy[key] = object[key];
    }
    return copy;
}

// The widget stores the lots as a JSON string in one config entry. Backups use a real
// array so they stay readable and editable; the string is rebuilt when importing.
function parsePortfolio(raw) {
    if (raw === undefined || raw === null || raw === "") {
        return { ok: true, lots: [] };
    }

    var value = raw;
    if (typeof raw === "string") {
        try {
            value = JSON.parse(raw);
        } catch (e) {
            return failure("invalidPortfolio");
        }
    }
    if (!Array.isArray(value)) {
        return failure("invalidPortfolio");
    }

    var lots = [];
    for (var i = 0; i < value.length; i++) {
        var lot = value[i];
        if (!isObject(lot)) {
            return failure("invalidLot", "", String(i + 1));
        }
        if (typeof lot.ticker !== "string" || lot.ticker.trim() === "") {
            return failure("invalidLot", "", String(i + 1));
        }
        var shares = Number(lot.shares);
        if (!isFinite(shares) || shares <= 0) {
            return failure("invalidLot", "", String(i + 1));
        }
        var averageCost = Number(lot.averageCost);
        if (!isFinite(averageCost) || averageCost < 0) {
            return failure("invalidLot", "", String(i + 1));
        }

        // Keep unknown fields (so a backup from a newer version does not silently lose
        // data) and normalise the fields the widget knows about.
        var clean = copyObject(lot);
        clean.ticker = lot.ticker.trim().toUpperCase();
        clean.shares = shares;
        clean.averageCost = averageCost;
        clean.currency = String(lot.currency || "USD").trim().toUpperCase();
        if (lot.addedDate && !isNaN(Date.parse(String(lot.addedDate)))) {
            clean.addedDate = String(lot.addedDate);
        } else {
            delete clean.addedDate;
        }
        if (lot.details !== undefined && lot.details !== null && String(lot.details).trim() !== "") {
            clean.details = String(lot.details);
        } else {
            delete clean.details;
        }
        lots.push(clean);
    }
    return { ok: true, lots: lots };
}

function validateValue(key, value) {
    if (has(BOOL_KEYS, key)) {
        if (typeof value !== "boolean") return failure("invalidValue", key);
        return { ok: true, value: value };
    }

    if (has(INT_RANGES, key)) {
        if (!isNumber(value)) return failure("invalidValue", key);
        var rounded = Math.round(value);
        var range = INT_RANGES[key];
        if (rounded < range[0] || rounded > range[1]) return failure("outOfRange", key);
        return { ok: true, value: rounded };
    }

    if (has(COLOR_KEYS, key)) {
        // The appearance page accepts a free-text colour. Keep it as it is instead of
        // insisting on #rrggbb, so a backup can restore names like "red" too.
        if (typeof value !== "string") return failure("invalidValue", key);
        return { ok: true, value: value };
    }

    if (key === "chartRange") {
        if (typeof value !== "string" || CHART_RANGES.indexOf(value) < 0) {
            return failure("invalidValue", key);
        }
        return { ok: true, value: value };
    }

    if (key === "ticker") {
        if (typeof value !== "string") return failure("invalidValue", key);
        return { ok: true, value: value.trim().toUpperCase() };
    }

    if (key === "multiTickers") {
        if (typeof value !== "string") return failure("invalidValue", key);
        return { ok: true, value: value.trim() };
    }

    if (key === "portfolioCurrency") {
        if (typeof value !== "string") return failure("invalidValue", key);
        var currency = value.trim().toUpperCase();
        if (!/^[A-Z]{3}$/.test(currency)) return failure("invalidValue", key);
        return { ok: true, value: currency };
    }

    return failure("invalidValue", key);
}

// Builds the object that is written to disk. `config` is a plain object with the values
// of the cfg_ properties of the configuration page.
function buildBackup(config, scope, exportedAt) {
    var backup = {
        application: APPLICATION_ID,
        format: FORMAT_VERSION,
        exportedAt: exportedAt,
        scope: scope
    };

    if (scope === "data" || scope === "all") {
        var data = {};
        for (var i = 0; i < DATA_KEYS.length; i++) {
            var key = DATA_KEYS[i];
            if (key === "portfolioData") continue;
            if (has(config, key) && config[key] !== undefined) data[key] = config[key];
        }

        var portfolio = parsePortfolio(config.portfolioData);
        if (portfolio.ok) {
            data.portfolio = portfolio.lots;
        } else if (config.portfolioData) {
            // Preserve an unparseable value rather than exporting an empty portfolio.
            data.portfolioData = String(config.portfolioData);
        }
        backup.data = data;
    }

    if (scope === "settings" || scope === "all") {
        var settings = {};
        for (var j = 0; j < SETTINGS_KEYS.length; j++) {
            var setting = SETTINGS_KEYS[j];
            if (has(config, setting) && config[setting] !== undefined) {
                settings[setting] = config[setting];
            }
        }
        backup.settings = settings;
    }

    return backup;
}

function toJson(backup) {
    return JSON.stringify(backup, null, 2) + "\n";
}

function collectData(rawData) {
    var data = null;
    var portfolioRaw;
    if (has(rawData, "portfolio")) portfolioRaw = rawData.portfolio;
    else if (has(rawData, "portfolioData")) portfolioRaw = rawData.portfolioData;

    if (portfolioRaw !== undefined) {
        var portfolio = parsePortfolio(portfolioRaw);
        if (!portfolio.ok) return portfolio;
        data = { portfolioData: JSON.stringify(portfolio.lots) };
    }

    for (var i = 0; i < DATA_KEYS.length; i++) {
        var key = DATA_KEYS[i];
        if (key === "portfolioData" || !has(rawData, key)) continue;
        var validated = validateValue(key, rawData[key]);
        if (!validated.ok) return validated;
        if (!data) data = {};
        data[key] = validated.value;
    }
    return data ? { ok: true, data: data } : { ok: true, data: null };
}

// Parses and validates a backup file. Returns either
//   { ok: true, data: {...}|null, settings: {...}|null }
// or
//   { ok: false, code: "...", key: "...", detail: "..." }.
function parseBackup(text) {
    if (typeof text !== "string") return failure("invalidJson");
    if (text.charCodeAt(0) === 0xFEFF) text = text.substring(1);
    text = text.trim();
    if (text === "") return failure("emptyFile");

    var root;
    try {
        root = JSON.parse(text);
    } catch (e) {
        return failure("invalidJson");
    }

    // A bare array is accepted as a portfolio-only file (handy for hand-made backups).
    if (Array.isArray(root)) {
        var legacy = parsePortfolio(root);
        if (!legacy.ok) return legacy;
        return { ok: true, data: { portfolioData: JSON.stringify(legacy.lots) }, settings: null };
    }

    if (!isObject(root)) return failure("notBackup");

    if (root.application !== undefined && root.application !== APPLICATION_ID) {
        return failure("notBackup");
    }
    if (root.format !== undefined) {
        var format = Number(root.format);
        if (!isFinite(format) || format < 1) return failure("notBackup");
        if (format > FORMAT_VERSION) return failure("newerFormat");
    }

    var rawData = isObject(root.data) ? root.data : (Array.isArray(root.data) ? { portfolio: root.data } : null);
    var rawSettings = isObject(root.settings) ? root.settings : null;

    // Also accept a flat file that contains the keys directly. This makes the exported
    // JSON easy to edit by hand and keeps backups from older/manual tools working.
    if (!rawData) {
        var flatData = {};
        for (var i = 0; i < DATA_KEYS.length; i++) {
            if (has(root, DATA_KEYS[i])) flatData[DATA_KEYS[i]] = root[DATA_KEYS[i]];
        }
        if (Object.keys(flatData).length > 0) {
            rawData = flatData;
        } else if (has(root, "portfolio") && Array.isArray(root.portfolio)) {
            rawData = { portfolio: root.portfolio };
        }
    }
    if (!rawSettings) {
        var flatSettings = {};
        for (var j = 0; j < SETTINGS_KEYS.length; j++) {
            if (has(root, SETTINGS_KEYS[j])) flatSettings[SETTINGS_KEYS[j]] = root[SETTINGS_KEYS[j]];
        }
        if (Object.keys(flatSettings).length > 0) rawSettings = flatSettings;
    }

    if (!rawData && !rawSettings) return failure("notBackup");

    var data = null;
    if (rawData) {
        var collected = collectData(rawData);
        if (!collected.ok) return collected;
        data = collected.data;
    }

    var settings = null;
    if (rawSettings) {
        for (var k = 0; k < SETTINGS_KEYS.length; k++) {
            var settingKey = SETTINGS_KEYS[k];
            if (!has(rawSettings, settingKey)) continue;
            var value = validateValue(settingKey, rawSettings[settingKey]);
            if (!value.ok) return value;
            if (!settings) settings = {};
            settings[settingKey] = value.value;
        }
    }

    if (!data && !settings) return failure("notBackup");
    return { ok: true, data: data, settings: settings };
}
