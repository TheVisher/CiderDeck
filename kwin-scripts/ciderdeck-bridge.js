// CiderDeck KWin bridge script
// Monitors window changes and pushes updates to CiderDeck via D-Bus

function pushWindowList() {
    var windows = workspace.windowList()
        .filter(function(w) {
            return w && !w.desktopWindow && !w.dock;
        })
        .map(function(w) {
            var activeWin = workspace.activeWindow;
            return {
                id: String(w.internalId),
                caption: String(w.caption || ""),
                resourceClass: String(w.resourceClass || ""),
                desktopFile: String(w.desktopFileName || ""),
                pid: Number(w.pid || 0),
                outputName: String(w.output ? w.output.name : ""),
                minimized: Boolean(w.minimized),
                active: Boolean(activeWin && String(w.internalId) === String(activeWin.internalId))
            };
        });

    callDBus("org.ciderdeck.App", "/CiderDeck", "org.ciderdeck.KWinBridge",
             "pushWindows", JSON.stringify({ windows: windows }));
}

// Push on window events
workspace.windowAdded.connect(function() {
    pushWindowList();
});

workspace.windowRemoved.connect(function() {
    pushWindowList();
});

workspace.activeWindowChanged.connect(function() {
    pushWindowList();
});

// Initial push
pushWindowList();
