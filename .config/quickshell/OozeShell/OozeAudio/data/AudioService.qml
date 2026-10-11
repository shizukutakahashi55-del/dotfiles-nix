// AudioService.qml — data

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================================


// ============================================================================

Singleton {
    id: root

    property string scriptPath:
        Quickshell.env("HOME") +
        "/.config/quickshell/OozeShell/OozeAudio/backend/audio.sh"

    property bool busy: false

    property var outputs: []
    property var sinks: []
    property var sources: []
    property var streams: []
    property var links: []

    signal refreshed()
    signal commandFailed(string message)

    // ------------------------------------------------------------------

    // ------------------------------------------------------------------

    function shellQuote(str) {
        return "'" + String(str).replace(/'/g, "'\\''") + "'";
    }

    function parseTsv(text) {
        return text
            .split("\n")
            .filter(function (line) { return line.length > 0; })
            .map(function (line) { return line.split("\t"); });
    }


    function destinationCandidates() {
        return root.sinks.filter(function (s) {
            return s.name.indexOf("ooze_") !== 0;
        });
    }

    function isConnected(srcName, dstName) {
        for (var i = 0; i < root.links.length; i++) {
            if (root.links[i].src === srcName && root.links[i].dst === dstName)
                return true;
        }
        return false;
    }

    // ------------------------------------------------------------------

    // ------------------------------------------------------------------

    function refreshAll() {
        outputsProc.running = true;
        sinksProc.running = true;
        sourcesProc.running = true;
        streamsProc.running = true;
        linksProc.running = true;
    }

    Process {
        id: outputsProc
        command: ["bash", "-c", root.scriptPath + " outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.outputs = root.parseTsv(text).map(function (f) {
                    return {
                        id: f[0], name: f[1] || "", desc: f[2] || f[1] || "",
                        volume: parseInt(f[3] || "0") || 0,
                        muted: f[4] === "1"
                    };
                });
                root.refreshed();
            }
        }
    }

    Process {
        id: sinksProc
        command: ["bash", "-c", root.scriptPath + " sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sinks = root.parseTsv(text).map(function (f) {
                    return {
                        id: f[0], name: f[1] || "", desc: f[2] || f[1] || "",
                        volume: parseInt(f[3] || "0") || 0,
                        muted: f[4] === "1"
                    };
                });
            }
        }
    }

    Process {
        id: sourcesProc
        command: ["bash", "-c", root.scriptPath + " sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.sources = root.parseTsv(text).map(function (f) {
                    return { id: f[0], name: f[1] || "", desc: f[2] || f[1] || "" };
                });
            }
        }
    }

    Process {
        id: streamsProc
        command: ["bash", "-c", root.scriptPath + " streams"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.streams = root.parseTsv(text).map(function (f) {
                    return {
                        id: f[0],
                        mediaClass: f[1] || "",
                        app: f[2] || "",
                        name: f[3] || "",
                        desc: f[4] || f[3] || ""
                    };
                });
            }
        }
    }

    Process {
        id: linksProc
        command: ["bash", "-c", root.scriptPath + " links"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.links = root.parseTsv(text).map(function (f) {
                    return { src: f[0] || "", dst: f[1] || "" };
                });
            }
        }
    }

    // ------------------------------------------------------------------

    // ------------------------------------------------------------------

    function createOutput(displayName) {
        root.busy = true;
        mutateProc.command = [
            "bash", "-c",
            root.scriptPath + " create " + root.shellQuote(displayName)
        ];
        mutateProc.running = true;
    }

    function deleteOutput(displayName) {
        root.busy = true;
        mutateProc.command = [
            "bash", "-c",
            root.scriptPath + " delete " + root.shellQuote(displayName)
        ];
        mutateProc.running = true;
    }

    function setConnection(srcName, dstName, connected) {
        root.busy = true;
        mutateProc.command = [
            "bash", "-c",
            root.scriptPath +
            (connected ? " connect " : " disconnect ") +
            root.shellQuote(srcName) + " " + root.shellQuote(dstName)
        ];
        mutateProc.running = true;
    }

    // ------------------------------------------------------------------

    // ------------------------------------------------------------------


    function updateLocalNode(kind, nodeId, patch) {
        var arr = kind === "outputs" ? root.outputs : root.sinks;
        var next = arr.map(function (n) {
            return n.id === nodeId ? Object.assign({}, n, patch) : n;
        });
        if (kind === "outputs") root.outputs = next; else root.sinks = next;
    }

    function setVolume(kind, nodeId, percent) {
        var pct = Math.max(0, Math.min(150, Math.round(percent)));
        root.updateLocalNode(kind, nodeId, { volume: pct });
        volumeProc.command = [
            "bash", "-c",
            root.scriptPath + " volume-set " + root.shellQuote(nodeId) + " " + pct
        ];
        volumeProc.running = false;
        volumeProc.running = true;
    }

    function setMute(kind, nodeId, muted) {
        root.updateLocalNode(kind, nodeId, { muted: muted });
        volumeProc.command = [
            "bash", "-c",
            root.scriptPath + " mute-set " + root.shellQuote(nodeId) + " " + (muted ? "1" : "0")
        ];
        volumeProc.running = false;
        volumeProc.running = true;
    }

    Process {
        id: volumeProc
        stdout: StdioCollector {}
        stderr: StdioCollector { id: volumeErr }
        onExited: function (exitCode) {
            if (exitCode !== 0) {
                root.commandFailed(volumeErr.text.trim() || "Volume command failed");


                root.refreshAll();
            }
        }
    }

    Process {
        id: mutateProc
        stdout: StdioCollector { id: mutateOut }
        stderr: StdioCollector { id: mutateErr }
        onExited: function (exitCode) {
            root.busy = false;


            root.refreshAll();
            if (exitCode !== 0) {
                var msg = mutateErr.text.trim() || mutateOut.text.trim() || "Command failed";
                root.commandFailed(msg);
            }
        }
    }

    Component.onCompleted: refreshAll()
}
