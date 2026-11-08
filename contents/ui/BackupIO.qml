import QtQuick
import org.kde.plasma.plasma5support 2.0

// Small wrapper around the Plasma5Support "executable" data engine. It is loaded
// through a Loader so the Import / Export page still opens (with an explanation) on
// systems where that compatibility module is not installed.
Item {
    id: root

    // True while a file is being read or written. The page disables its buttons so
    // two requests cannot overlap.
    property bool busy: false

    // "read" or "write", used to report a useful error.
    property string operation: ""

    // The command that is currently running, so a stale timeout cannot clear a newer
    // request.
    property string pendingSource: ""

    signal readFinished(string text)
    signal writeFinished()
    signal failed(string operationName, string detail)

    DataSource {
        id: executor
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            if (!root.busy || source !== root.pendingSource) return;

            const doneOperation = root.operation;
            const exitCode = Number(data["exit code"]);
            const stdout = data["stdout"] !== undefined ? String(data["stdout"]) : "";
            const stderr = data["stderr"] !== undefined ? String(data["stderr"]) : "";

            root.finish();
            executor.disconnectSource(source);

            if (!isFinite(exitCode) || exitCode !== 0) {
                root.failed(doneOperation, stderr.trim());
                return;
            }
            if (doneOperation === "read") root.readFinished(stdout);
            else root.writeFinished();
        }
    }

    Timer {
        id: timeoutTimer
        interval: 15000
        repeat: false
        onTriggered: {
            if (!root.busy) return;
            const timedOutOperation = root.operation;
            const source = root.pendingSource;
            root.finish();
            if (source !== "") executor.disconnectSource(source);
            root.failed(timedOutOperation, "timeout");
        }
    }

    function finish() {
        root.busy = false;
        root.operation = "";
        root.pendingSource = "";
        timeoutTimer.stop();
    }

    // Quotes one argument for the shell-like parser used by the executable engine.
    // The quote character is built with fromCharCode so xgettext does not mistake the
    // JavaScript string for an unterminated C character constant.
    function quoteArgument(value) {
        const quote = String.fromCharCode(39);
        const escapedQuote = quote + "\\" + quote + quote;
        return quote + String(value).split(quote).join(escapedQuote) + quote;
    }

    function localPath(url) {
        var path = String(url);
        if (path.indexOf("file://") === 0) path = path.substring(7);
        try {
            return decodeURIComponent(path);
        } catch (e) {
            // A literal "%" that is not a valid escape: keep the path as it is.
            return path;
        }
    }

    function helperPath() {
        return localPath(Qt.resolvedUrl("../code/backup-io.sh"));
    }

    function start(operationName, command) {
        if (root.busy) return;
        root.busy = true;
        root.operation = operationName;
        root.pendingSource = command;
        timeoutTimer.restart();
        executor.connectSource(command);
    }

    function readFile(url) {
        const path = quoteArgument(localPath(url));
        start("read", "sh " + quoteArgument(helperPath()) + " read " + path);
    }

    function writeFile(url, text) {
        // Qt.btoa() encodes the string as UTF-8, which is exactly what the JSON file
        // needs. (The usual JavaScript btoa(unescape(encodeURIComponent(...))) dance
        // would encode it twice here.)
        const encoded = Qt.btoa(text);
        const path = quoteArgument(localPath(url));
        start("write", "sh " + quoteArgument(helperPath()) + " write " + path + " " + quoteArgument(encoded));
    }
}
