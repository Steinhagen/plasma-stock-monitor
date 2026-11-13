.pragma library

// Portfolio lot aggregation. The caller supplies the portfolio currency and the
// currency converter so this module stays independent of the applet state.


function getPortfolioSummary(ticker, dataStr, rawPrice, prevClose, quoteCurrency, portfolioCurrency, convert, currency) {
    if (!ticker || !dataStr || !rawPrice) return null;
    try {
        var portfolio = JSON.parse(dataStr);
        var upperTicker = ticker.trim().toUpperCase();
        var lots = [], lotCurrencies = {};
        for (var i = 0; i < portfolio.length; i++) {
            if (portfolio[i].ticker !== upperTicker) continue;
            var s = Number(portfolio[i].shares) || 0;
            if (s <= 0) continue;
            // Lots saved before this feature existed have no currency and are USD.
            var lotCurrency = currency.major(portfolio[i].currency) || "USD";
            lots.push({
                shares: s,
                averageCost: Number(portfolio[i].averageCost) || 0,
                currency: lotCurrency
            });
            lotCurrencies[lotCurrency] = true;
        }
        if (lots.length === 0) return null;

        var codes = Object.keys(lotCurrencies);
        var target = codes.length === 1 ? codes[0] : portfolioCurrency;
        // Mixed positions are always converted to a catalog currency; a single-currency
        // position keeps its own code even if the feed has no rate for it, so a quote
        // already in that currency can still be shown without a conversion.
        if (codes.length > 1 && !currency.isKnown(target)) target = "USD";

        var quoteCode = currency.major(quoteCurrency);
        var quoteFactor = currency.minorFactor(quoteCurrency);
        var price = rawPrice * quoteFactor;
        // Without a quote currency (old cache / unexpected response) assume the price
        // is already expressed in the currency the position is shown in.
        var priceInTarget = quoteCode === "" ? price : convert(price, quoteCode, target);
        if (priceInTarget === null) return null;
        var prevInTarget = null;
        if (prevClose > 0) {
            var prev = prevClose * quoteFactor;
            prevInTarget = quoteCode === "" ? prev : convert(prev, quoteCode, target);
        }

        var shares = 0, cost = 0, value = 0, day = 0;
        var dayKnown = prevInTarget !== null;
        for (var j = 0; j < lots.length; j++) {
            var costInTarget = convert(lots[j].averageCost, lots[j].currency, target);
            if (costInTarget === null) return null;
            shares += lots[j].shares;
            cost += lots[j].shares * costInTarget;
            value += lots[j].shares * priceInTarget;
            if (dayKnown) day += lots[j].shares * (priceInTarget - prevInTarget);
        }
        if (shares <= 0) return null;
        var plValue = value - cost;
        return {
            lots: lots.length, shares: shares, avgCost: cost / shares, cost: cost, value: value,
            plValue: plValue, plPercent: cost > 0 ? (plValue / cost) * 100 : 0, plIsPos: plValue >= 0,
            dayValue: dayKnown ? day : null, dayIsPos: !dayKnown || day >= 0, currency: target
        };
    } catch (e) {
        console.log("Error parsing portfolio data: " + e);
    }
    return null;
}

function getPortfolioTickers(dataStr) {
    if (!dataStr) return [];
    try {
        var portfolio = JSON.parse(dataStr), seen = {}, out = [];
        for (var i = 0; i < portfolio.length; i++) {
            var t = String(portfolio[i].ticker || "").trim().toUpperCase();
            if (t === "" || seen[t] || !(Number(portfolio[i].shares) > 0)) continue;
            seen[t] = true;
            out.push(t);
        }
        return out;
    } catch (e) {
        return [];
    }
}
