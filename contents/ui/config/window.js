.pragma library

// Every configuration page uses the same window minimum, so switching pages never
// resizes the dialog. The portfolio page needs the widest layout; the extra height
// covers the longest pages and their scrolling content.
var MIN_WIDTH = 800
var MIN_HEIGHT = 720

// `page` is the page root and `win` is Window.window. Walk up to the item ConfigView
// loaded (the direct child of the window content item) and raise both its layout
// minimum and the window minimum, as the portfolio page used to do on its own.
function apply(page, win) {
    if (!page || !win || !win.contentItem) return;

    var root = page;
    while (root.parent && root.parent !== win.contentItem)
        root = root.parent;

    if (root.parent === win.contentItem && root.Layout) {
        if (root.Layout.minimumWidth < MIN_WIDTH)
            root.Layout.minimumWidth = MIN_WIDTH;
        if (root.Layout.minimumHeight < MIN_HEIGHT)
            root.Layout.minimumHeight = MIN_HEIGHT;
    }

    if (win.minimumWidth < MIN_WIDTH) win.minimumWidth = MIN_WIDTH;
    if (win.minimumHeight < MIN_HEIGHT) win.minimumHeight = MIN_HEIGHT;
    if (win.width < MIN_WIDTH) win.width = MIN_WIDTH;
    if (win.height < MIN_HEIGHT) win.height = MIN_HEIGHT;
}
