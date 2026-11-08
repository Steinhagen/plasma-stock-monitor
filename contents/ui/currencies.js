.pragma library

// Currency data for the portfolio. The list is the set of ISO 4217 currencies for
// which the free daily feed (https://open.er-api.com) publishes a rate; the ISO
// names come from iso-codes. The currencies used most for shares come first, then
// the rest by code, so the picker is easy to scan.
var LIST = [
    { code: "USD", name: "US Dollar" },
    { code: "EUR", name: "Euro" },
    { code: "GBP", name: "Pound Sterling" },
    { code: "JPY", name: "Yen" },
    { code: "CHF", name: "Swiss Franc" },
    { code: "CAD", name: "Canadian Dollar" },
    { code: "AUD", name: "Australian Dollar" },
    { code: "CNY", name: "Yuan Renminbi" },
    { code: "INR", name: "Indian Rupee" },
    { code: "NZD", name: "New Zealand Dollar" },
    { code: "SEK", name: "Swedish Krona" },
    { code: "NOK", name: "Norwegian Krone" },
    { code: "DKK", name: "Danish Krone" },
    { code: "PLN", name: "Zloty" },
    { code: "CZK", name: "Czech Koruna" },
    { code: "HUF", name: "Forint" },
    { code: "HKD", name: "Hong Kong Dollar" },
    { code: "SGD", name: "Singapore Dollar" },
    { code: "KRW", name: "Won" },
    { code: "BRL", name: "Brazilian Real" },
    { code: "MXN", name: "Mexican Peso" },
    { code: "ZAR", name: "Rand" },
    { code: "TRY", name: "Turkish Lira" },
    { code: "ILS", name: "New Israeli Sheqel" },
    { code: "AED", name: "UAE Dirham" },
    { code: "SAR", name: "Saudi Riyal" },
    { code: "THB", name: "Baht" },
    { code: "IDR", name: "Rupiah" },
    { code: "MYR", name: "Malaysian Ringgit" },
    { code: "PHP", name: "Philippine Peso" },
    { code: "TWD", name: "New Taiwan Dollar" },
    { code: "VND", name: "Dong" },
    { code: "AFN", name: "Afghani" },
    { code: "ALL", name: "Lek" },
    { code: "AMD", name: "Armenian Dram" },
    { code: "ANG", name: "Netherlands Antillean Guilder" },
    { code: "AOA", name: "Kwanza" },
    { code: "ARS", name: "Argentine Peso" },
    { code: "AWG", name: "Aruban Florin" },
    { code: "AZN", name: "Azerbaijan Manat" },
    { code: "BAM", name: "Convertible Mark" },
    { code: "BBD", name: "Barbados Dollar" },
    { code: "BDT", name: "Taka" },
    { code: "BGN", name: "Bulgarian Lev" },
    { code: "BHD", name: "Bahraini Dinar" },
    { code: "BIF", name: "Burundi Franc" },
    { code: "BMD", name: "Bermudian Dollar" },
    { code: "BND", name: "Brunei Dollar" },
    { code: "BOB", name: "Boliviano" },
    { code: "BSD", name: "Bahamian Dollar" },
    { code: "BTN", name: "Ngultrum" },
    { code: "BWP", name: "Pula" },
    { code: "BYN", name: "Belarusian Ruble" },
    { code: "BZD", name: "Belize Dollar" },
    { code: "CDF", name: "Congolese Franc" },
    { code: "CLF", name: "Unidad de Fomento" },
    { code: "CLP", name: "Chilean Peso" },
    { code: "CNH", name: "Chinese Yuan (Offshore)" },
    { code: "COP", name: "Colombian Peso" },
    { code: "CRC", name: "Costa Rican Colon" },
    { code: "CUP", name: "Cuban Peso" },
    { code: "CVE", name: "Cabo Verde Escudo" },
    { code: "DJF", name: "Djibouti Franc" },
    { code: "DOP", name: "Dominican Peso" },
    { code: "DZD", name: "Algerian Dinar" },
    { code: "EGP", name: "Egyptian Pound" },
    { code: "ERN", name: "Nakfa" },
    { code: "ETB", name: "Ethiopian Birr" },
    { code: "FJD", name: "Fiji Dollar" },
    { code: "FKP", name: "Falkland Islands Pound" },
    { code: "FOK", name: "Faroese Króna" },
    { code: "GEL", name: "Lari" },
    { code: "GGP", name: "Guernsey Pound" },
    { code: "GHS", name: "Ghana Cedi" },
    { code: "GIP", name: "Gibraltar Pound" },
    { code: "GMD", name: "Dalasi" },
    { code: "GNF", name: "Guinean Franc" },
    { code: "GTQ", name: "Quetzal" },
    { code: "GYD", name: "Guyana Dollar" },
    { code: "HNL", name: "Lempira" },
    { code: "HRK", name: "Croatian Kuna" },
    { code: "HTG", name: "Gourde" },
    { code: "IMP", name: "Isle of Man Pound" },
    { code: "IQD", name: "Iraqi Dinar" },
    { code: "IRR", name: "Iranian Rial" },
    { code: "ISK", name: "Iceland Krona" },
    { code: "JEP", name: "Jersey Pound" },
    { code: "JMD", name: "Jamaican Dollar" },
    { code: "JOD", name: "Jordanian Dinar" },
    { code: "KES", name: "Kenyan Shilling" },
    { code: "KGS", name: "Som" },
    { code: "KHR", name: "Riel" },
    { code: "KID", name: "Kiribati Dollar" },
    { code: "KMF", name: "Comorian Franc" },
    { code: "KWD", name: "Kuwaiti Dinar" },
    { code: "KYD", name: "Cayman Islands Dollar" },
    { code: "KZT", name: "Tenge" },
    { code: "LAK", name: "Lao Kip" },
    { code: "LBP", name: "Lebanese Pound" },
    { code: "LKR", name: "Sri Lanka Rupee" },
    { code: "LRD", name: "Liberian Dollar" },
    { code: "LSL", name: "Loti" },
    { code: "LYD", name: "Libyan Dinar" },
    { code: "MAD", name: "Moroccan Dirham" },
    { code: "MDL", name: "Moldovan Leu" },
    { code: "MGA", name: "Malagasy Ariary" },
    { code: "MKD", name: "Denar" },
    { code: "MMK", name: "Kyat" },
    { code: "MNT", name: "Tugrik" },
    { code: "MOP", name: "Pataca" },
    { code: "MRU", name: "Ouguiya" },
    { code: "MUR", name: "Mauritius Rupee" },
    { code: "MVR", name: "Rufiyaa" },
    { code: "MWK", name: "Malawi Kwacha" },
    { code: "MZN", name: "Mozambique Metical" },
    { code: "NAD", name: "Namibia Dollar" },
    { code: "NGN", name: "Naira" },
    { code: "NIO", name: "Cordoba Oro" },
    { code: "NPR", name: "Nepalese Rupee" },
    { code: "OMR", name: "Rial Omani" },
    { code: "PAB", name: "Balboa" },
    { code: "PEN", name: "Sol" },
    { code: "PGK", name: "Kina" },
    { code: "PKR", name: "Pakistan Rupee" },
    { code: "PYG", name: "Guarani" },
    { code: "QAR", name: "Qatari Rial" },
    { code: "RON", name: "Romanian Leu" },
    { code: "RSD", name: "Serbian Dinar" },
    { code: "RUB", name: "Russian Ruble" },
    { code: "RWF", name: "Rwanda Franc" },
    { code: "SBD", name: "Solomon Islands Dollar" },
    { code: "SCR", name: "Seychelles Rupee" },
    { code: "SDG", name: "Sudanese Pound" },
    { code: "SHP", name: "Saint Helena Pound" },
    { code: "SLE", name: "Leone" },
    { code: "SLL", name: "Sierra Leonean Leone" },
    { code: "SOS", name: "Somali Shilling" },
    { code: "SRD", name: "Surinam Dollar" },
    { code: "SSP", name: "South Sudanese Pound" },
    { code: "STN", name: "Dobra" },
    { code: "SYP", name: "Syrian Pound" },
    { code: "SZL", name: "Lilangeni" },
    { code: "TJS", name: "Somoni" },
    { code: "TMT", name: "Turkmenistan New Manat" },
    { code: "TND", name: "Tunisian Dinar" },
    { code: "TOP", name: "Pa’anga" },
    { code: "TTD", name: "Trinidad and Tobago Dollar" },
    { code: "TVD", name: "Tuvaluan Dollar" },
    { code: "TZS", name: "Tanzanian Shilling" },
    { code: "UAH", name: "Hryvnia" },
    { code: "UGX", name: "Uganda Shilling" },
    { code: "UYU", name: "Peso Uruguayo" },
    { code: "UZS", name: "Uzbekistan Sum" },
    { code: "VES", name: "Bolívar Soberano" },
    { code: "VUV", name: "Vatu" },
    { code: "WST", name: "Tala" },
    { code: "XAF", name: "CFA Franc BEAC" },
    { code: "XCD", name: "East Caribbean Dollar" },
    { code: "XCG", name: "Caribbean Guilder" },
    { code: "XDR", name: "SDR (Special Drawing Right)" },
    { code: "XOF", name: "CFA Franc BCEAO" },
    { code: "XPF", name: "CFP Franc" },
    { code: "YER", name: "Yemeni Rial" },
    { code: "ZMW", name: "Zambian Kwacha" },
    { code: "ZWG", name: "Zimbabwe Gold" },
    { code: "ZWL", name: "Zimbabwean Dollar" }
];

var BY_CODE = {};
var LABELS = [];
for (var i = 0; i < LIST.length; i++) {
    // One string for the settings combo box: "USD — US Dollar". Keeping a plain
    // array of strings also makes the combo box independent of model-role support.
    LABELS.push(LIST[i].code + " — " + LIST[i].name);
    BY_CODE[LIST[i].code] = LIST[i];
}

// Yahoo prices some instruments in a minor unit: London shares in pence (GBp),
// Johannesburg shares in cents (ZAc), Tel Aviv shares in agorot (ILA). The quote
// has to be divided by 100 before it can be compared with a major-unit cost or
// with an exchange rate.
var MINOR = {
    "GBp": ["GBP", 0.01],
    "GBX": ["GBP", 0.01],
    "ZAc": ["ZAR", 0.01],
    "ILA": ["ILS", 0.01],
    "ILs": ["ILS", 0.01]
};

// Symbols for the currencies a portfolio is most likely to use. Anything not in
// the table falls back to the ISO code, which is unambiguous ("CHF 1,234.50").
var SYMBOLS = {
    USD: "$", EUR: "€", GBP: "£", JPY: "¥", CNY: "¥", KRW: "₩", INR: "₹",
    RUB: "₽", TRY: "₺", UAH: "₴", KZT: "₸", GEL: "₾", AMD: "֏", AZN: "₼",
    ILS: "₪", THB: "฿", VND: "₫", PHP: "₱", IDR: "Rp", MYR: "RM",
    SGD: "S$", HKD: "HK$", TWD: "NT$", CAD: "C$", AUD: "A$", NZD: "NZ$",
    BRL: "R$", MXN: "Mex$", ARS: "AR$", CLP: "CLP$", COP: "COL$", PEN: "S/",
    UYU: "$U", PYG: "₲", BOB: "Bs", CRC: "₡", GTQ: "Q", DOP: "RD$",
    ZAR: "R", NGN: "₦", GHS: "₵", KES: "KSh", EGP: "E£",
    SAR: "SAR ", AED: "AED ", QAR: "QAR ", KWD: "KWD ", BHD: "BHD ",
    OMR: "OMR ", JOD: "JOD ",
    PLN: "PLN ", CZK: "CZK ", HUF: "HUF ", RON: "RON ", BGN: "BGN ", HRK: "HRK ",
    RSD: "RSD ", SEK: "kr ", NOK: "kr ", DKK: "kr ", ISK: "kr ", CHF: "CHF "
};

// The major-unit code for a Yahoo quote code ("GBp" -> "GBP", "usd" -> "USD").
function major(code) {
    var c = String(code === undefined || code === null ? "" : code).trim();
    if (c === "" || c === "null") return "";
    return MINOR[c] ? MINOR[c][0] : c.toUpperCase();
}

// 0.01 for a minor-unit quote code, 1 otherwise.
function minorFactor(code) {
    var c = String(code === undefined || code === null ? "" : code).trim();
    return MINOR[c] ? MINOR[c][1] : 1;
}

// The symbol to put in front of a value. Minor-unit quotes keep their code so a
// price in pence is not mislabelled as pounds.
function symbol(code) {
    var c = String(code === undefined || code === null ? "" : code).trim();
    if (c === "") return "";
    if (MINOR[c]) return c + " ";
    var m = major(c);
    return SYMBOLS[m] || m + " ";
}

function isKnown(code) {
    return Object.prototype.hasOwnProperty.call(BY_CODE, major(code));
}

// Converts between currencies through the feed's rates, which are units of each
// currency per one unit of the feed base. Returns null when a rate is missing so
// callers can tell "no rate yet" apart from a real zero.
function convert(amount, from, to, rates) {
    if (amount === undefined || amount === null || isNaN(amount)) return null;
    var f = String(from === undefined || from === null ? "" : from).trim();
    var t = String(to === undefined || to === null ? "" : to).trim();
    if (f === "" || t === "") return null;
    var fc = major(f), tc = major(t);
    var value = Number(amount) * minorFactor(f) / minorFactor(t);
    if (fc === tc) return value;
    if (!rates) return null;
    var rf = Number(rates[fc]), rt = Number(rates[tc]);
    if (!(rf > 0) || !(rt > 0)) return null;
    return value * rt / rf;
}
