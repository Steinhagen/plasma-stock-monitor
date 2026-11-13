.pragma library

// Display helpers for Yahoo Finance tickers. The stored ticker always keeps its full
// Yahoo symbol: it is the key used by the quote requests, the portfolio lots and the
// selection. These functions only derive what the widget shows.

// Exchange suffixes used by Yahoo Finance, mapped to a short, readable exchange name.
// They are the fallback before a quote has supplied exchangeName / fullExchangeName.
var SUFFIX_LABELS = {
    ".RO": "BVB",
    ".DE": "XETRA",
    ".F": "FRA",
    ".SG": "STU",
    ".MU": "MUN",
    ".DU": "DUS",
    ".BE": "BER",
    ".HM": "HAM",
    ".HA": "HAN",
    ".LU": "LUX",
    ".L": "LSE",
    ".IL": "LSE",
    ".PA": "EPA",
    ".AS": "AMS",
    ".BR": "EBR",
    ".LS": "ELI",
    ".MC": "BME",
    ".MI": "BIT",
    ".SW": "SIX",
    ".VX": "SIX",
    ".VI": "VIE",
    ".PR": "PRG",
    ".WA": "WSE",
    ".BD": "BUD",
    ".AT": "ATH",
    ".IS": "IST",
    ".TA": "TLV",
    ".ST": "STO",
    ".OL": "OSL",
    ".CO": "CPH",
    ".HE": "HEL",
    ".IC": "ICE",
    ".TO": "TSX",
    ".V": "TSXV",
    ".CN": "CSE",
    ".NE": "NEO",
    ".HK": "HKEX",
    ".T": "TSE",
    ".AX": "ASX",
    ".NZ": "NZX",
    ".SI": "SGX",
    ".BK": "SET",
    ".JK": "IDX",
    ".KL": "KLSE",
    ".NS": "NSE",
    ".BO": "BSE",
    ".KS": "KRX",
    ".KQ": "KOSDAQ",
    ".TW": "TWSE",
    ".TWO": "TPEX",
    ".SA": "B3",
    ".MX": "BMV",
    ".BA": "BCBA",
    ".CL": "BCS",
    ".SN": "BCS",
    ".JO": "JSE",
    ".SR": "TADAWUL",
    ".QA": "QSE",
    ".AE": "ADX",
    ".CA": "EGX",
    ".NG": "NGX"
};

// Yahoo's exchangeName codes. Full names are included where Yahoo sometimes returns
// them instead of the code, so both spellings resolve to the same short label.
var LABELS = {
    "NMS": "NASDAQ", "NGM": "NASDAQ", "NCM": "NASDAQ",
    "NYQ": "NYSE", "NYS": "NYSE",
    "ASE": "AMEX", "AMX": "AMEX", "PCX": "ARCA", "BTS": "BATS",
    "PNK": "OTC", "OQB": "OTC", "OQX": "OTC",
    "GER": "XETRA", "FRA": "FRA", "BER": "BER", "STU": "STU",
    "MUN": "MUN", "HAM": "HAM", "DUS": "DUS", "HAN": "HAN",
    "BVB": "BVB",
    "LSE": "LSE", "LON": "LSE",
    "PAR": "EPA", "AMS": "AMS", "BRU": "EBR", "LIS": "ELI",
    "MIL": "BIT", "MCE": "BME", "SWX": "SIX", "EBS": "SIX",
    "VIE": "VIE", "PRG": "PRG", "WSE": "WSE", "BUD": "BUD",
    "ATH": "ATH", "IST": "IST", "TLV": "TLV",
    "STO": "STO", "OSL": "OSL", "CPH": "CPH", "HEL": "HEL", "ICE": "ICE",
    "TOR": "TSX", "CVE": "TSXV", "NEO": "NEO", "CNQ": "CSE",
    "HKG": "HKEX", "TYO": "TSE", "OSA": "OSE", "ASX": "ASX", "NZX": "NZX",
    "SGX": "SGX", "SET": "SET", "JKT": "IDX", "KLS": "KLSE",
    "NSI": "NSE", "BSE": "BSE", "KSC": "KRX", "KSE": "KRX",
    "TAI": "TWSE", "TWO": "TPEX", "SHH": "SSE", "SHZ": "SZSE",
    "SAO": "B3", "MEX": "BMV", "BUE": "BCBA", "SCL": "BCS", "BOG": "BVC",
    "JNB": "JSE", "CAI": "EGX", "LOS": "NGX", "NAI": "NSE",
    "SAU": "TADAWUL", "DOH": "QSE", "ADX": "ADX", "DFM": "DFM",
    "LUX": "LUX",

    "BUCHAREST STOCK EXCHANGE": "BVB",
    "XETRA": "XETRA",
    "FRANKFURT STOCK EXCHANGE": "FRA",
    "LONDON STOCK EXCHANGE": "LSE",
    "EURONEXT PARIS": "EPA",
    "EURONEXT AMSTERDAM": "AMS",
    "EURONEXT BRUSSELS": "EBR",
    "EURONEXT LISBON": "ELI",
    "BORSA ITALIANA": "BIT",
    "BME SPANISH EXCHANGES": "BME",
    "SIX SWISS EXCHANGE": "SIX",
    "WIENER BÖRSE": "VIE",
    "PRAGUE STOCK EXCHANGE": "PRG",
    "WARSAW STOCK EXCHANGE": "WSE",
    "BUDAPEST STOCK EXCHANGE": "BUD",
    "ATHENS EXCHANGE": "ATH",
    "BORSA ISTANBUL": "IST",
    "TEL AVIV STOCK EXCHANGE": "TLV"
};

function upper(ticker) {
    return String(ticker === undefined || ticker === null ? "" : ticker).trim().toUpperCase();
}

// The exchange suffix of a Yahoo symbol, including the dot (".RO"), or "" for a plain
// symbol such as AAPL. A dot followed by one to four letters is treated as a suffix;
// class shares use a dash on Yahoo (BRK-B), so they are not affected.
function suffix(ticker) {
    var text = upper(ticker);
    var dot = text.lastIndexOf(".");
    if (dot <= 0) return "";
    var candidate = text.substring(dot);
    return /^\.[A-Z]{1,4}$/.test(candidate) ? candidate : "";
}

function hasSuffix(ticker) {
    return suffix(ticker) !== "";
}

function baseSymbol(ticker) {
    var text = upper(ticker);
    var sfx = suffix(text);
    return sfx === "" ? text : text.substring(0, text.length - sfx.length);
}

// Short exchange label for a quote. Prefer the exchange Yahoo reported, then the
// suffix, which keeps the badge useful before the first quote arrives.
function shortLabel(ticker, exchangeName, fullExchangeName) {
    var code = upper(exchangeName);
    if (code !== "" && LABELS[code]) return LABELS[code];

    var sfx = suffix(ticker);
    if (sfx !== "" && SUFFIX_LABELS[sfx]) return SUFFIX_LABELS[sfx];

    if (code !== "") return code;

    var full = String(fullExchangeName === undefined || fullExchangeName === null
                      ? "" : fullExchangeName).trim().toUpperCase();
    if (full !== "" && LABELS[full]) return LABELS[full];
    return "";
}

function fullLabel(ticker, exchangeName, fullExchangeName) {
    var full = String(fullExchangeName === undefined || fullExchangeName === null
                      ? "" : fullExchangeName).trim();
    return full !== "" ? full : shortLabel(ticker, exchangeName, "");
}
