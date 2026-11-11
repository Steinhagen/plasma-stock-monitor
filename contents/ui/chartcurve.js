.pragma library
// Geometry for the smoothed price line: monotone cubic interpolation (Fritsch-Carlson,
// as in d3's curveMonotoneX) with straight segments across large time gaps.
//
// Each segment is drawn as a cubic Bezier whose control points sit at x1 + h/3 and
// x2 - h/3 (h = x2 - x1), so they never leave the segment horizontally and the line
// cannot double back into a loop. The tangents are limited so the curve never goes
// above or below the two points of a segment, and every extremum falls on a data point.

// A segment counts as a gap when its time span is more than GAP_FACTOR times the median
// spacing of the series. 4x ignores normal jitter and a single missing bar, but catches
// the hours-long holes that make a smooth curve overshoot (for example a 2 hour hole in
// 2 minute data). Series with fewer than MIN_DELTAS spacings have no meaningful median.
var GAP_FACTOR = 4;
var MIN_DELTAS = 3;

// One boolean per segment (n - 1): true when the segment spans a large time gap.
function gapFlags(times, factor) {
    var flags = [];
    var n = times ? times.length : 0;
    for (var i = 0; i < n - 1; i++) flags.push(false);
    if (n < MIN_DELTAS + 1) return flags;
    var deltas = [];
    for (var j = 0; j < n - 1; j++) {
        var d = times[j + 1] - times[j];
        if (!isFinite(d)) return flags;
        if (d > 0) deltas.push(d);
    }
    if (deltas.length < MIN_DELTAS) return flags;
    deltas.sort(function (a, b) { return a - b; });
    var mid = deltas.length >> 1;
    var median = (deltas.length % 2) ? deltas[mid] : (deltas[mid - 1] + deltas[mid]) / 2;
    var limit = (factor > 0 ? factor : GAP_FACTOR) * median;
    for (var k = 0; k < n - 1; k++) flags[k] = (times[k + 1] - times[k]) > limit;
    return flags;
}

// Tangent (dy/dx) at every point. `gaps` (optional) marks straight segments; the smoothing
// is split into independent runs between them and each run gets end tangents at its ends,
// so the curve never bends towards a gap line.
function monotoneTangents(xs, ys, gaps) {
    var n = xs.length;
    var m = [];
    for (var i = 0; i < n; i++) m.push(0);
    var start = 0;
    for (var i2 = 0; i2 < n; i2++) {
        var last = (i2 === n - 1) || (gaps && gaps[i2]);
        if (last) {
            runTangents(xs, ys, m, start, i2);
            start = i2 + 1;
        }
    }
    return m;
}

function sign(v) { return v < 0 ? -1 : 1; }

function runTangents(xs, ys, m, a, b) {
    var cnt = b - a + 1;
    if (cnt < 2) { m[a] = 0; return; }
    var h = [], d = [];
    for (var i = a; i < b; i++) {
        var hi = xs[i + 1] - xs[i];
        h.push(hi);
        d.push(hi > 0 ? (ys[i + 1] - ys[i]) / hi : 0);
    }
    if (cnt === 2) {
        m[a] = d[0];
        m[b] = d[0];
        return;
    }
    for (var k = 1; k < cnt - 1; k++) {
        var h0 = h[k - 1], h1 = h[k], d0 = d[k - 1], d1 = d[k];
        if (!(h0 > 0) || !(h1 > 0) || d0 * d1 <= 0) {
            m[a + k] = 0;
        } else {
            var v = 3 * (h0 + h1) / ((2 * h1 + h0) / d0 + (h1 + 2 * h0) / d1);
            var lim = 3 * Math.min(Math.abs(d0), Math.abs(d1));
            m[a + k] = sign(v) * Math.min(Math.abs(v), lim);
        }
    }
    m[a] = endTangent(h[0], d[0], d[1], m[a + 1]);
    m[b] = endTangent(h[cnt - 2], d[cnt - 2], d[cnt - 3], m[b - 1]);
}

// d3's slope2 rule, kept monotone.
function endTangent(h, d, dNext, mNeighbour) {
    if (!(h > 0)) return 0;
    var t = (3 * d - mNeighbour) / 2;
    if (t * d <= 0) return 0;
    return sign(t) * Math.min(Math.abs(t), 3 * Math.abs(d));
}

// Bezier control points of segment i (from point i to point i + 1).
function segmentControls(xs, ys, m, i) {
    var h = xs[i + 1] - xs[i];
    return {
        c1x: xs[i] + h / 3, c1y: ys[i] + m[i] * h / 3,
        c2x: xs[i + 1] - h / 3, c2y: ys[i + 1] - m[i + 1] * h / 3
    };
}
