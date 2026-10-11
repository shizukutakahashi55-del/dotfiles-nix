// ImageFrameWidget — marco de imagen / presentación de fotos.

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import ".."
import "../../COMMON"
import "../../LANG"

WidgetBase {
  id: w

  readonly property string sty: w.widgetStyle
  readonly property string src: String(w.opt("source", "")).trim()
  readonly property int intervalSec: Math.max(0, Math.round(Number(w.opt("intervalSec", 60))))
  readonly property bool shuffle: w.opt("shuffle", true)
  readonly property real rad: Math.max(0, Number(w.opt("radius", 14)))
  readonly property bool caption: w.opt("caption", false)

  readonly property bool circ: w.sty === "circle"
  readonly property bool poly: w.sty === "polaroid"
  readonly property real side: Math.min(w.width, w.height)
  readonly property real pad: w.poly ? 10 : 0
  readonly property real polyFoot: w.poly ? (w.caption ? 38 : 26) : 0


  function expand(p) {
    let t = String(p).trim()
    if ((t[0] === '"' && t[t.length - 1] === '"') || (t[0] === "'" && t[t.length - 1] === "'")) t = t.slice(1, -1).trim()
    if (t.indexOf("file://") === 0) { try { t = decodeURIComponent(t.slice(7)) } catch (e) { t = t.slice(7) } }
    const home = Quickshell.env("HOME")
    if (t === "~") return home
    if (t.indexOf("~/") === 0) return home + t.slice(1)
    if (t.indexOf("$HOME") === 0) return home + t.slice(5)
    if (t.length > 1) t = t.replace(/\/+$/, "")
    return t
  }

  // ── lista de archivos ──
  property var files: []
  property var acc: []
  property bool scanned: false
  property bool pendingReload: false
  property int idx: -1
  property int failStreak: 0

  function shuffled(a) {
    const r = a.slice()
    for (let i = r.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const t = r[i]; r[i] = r[j]; r[j] = t
    }
    return r
  }


  readonly property string listScript:
    'p="$1"; ' +
    'if [ -d "$p" ]; then ' +
    '  find -L "$p" -maxdepth 4 -mindepth 1 \\( -type d -name ".*" -prune \\) -o -type f ' +
    '    \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \\) -print 2>/dev/null; ' +
    'elif [ -f "$p" ]; then printf "%s\\n" "$p"; ' +
    'else echo "#MISSING"; fi'

  property bool missing: false

  Process {
    id: lister
    running: false
    stdout: SplitParser {
      onRead: line => {
        if (line === "#MISSING") w.missing = true
        else if (line !== "") w.acc.push(line)
      }
    }
    stderr: SplitParser { onRead: line => console.log("[imageframe]", line) }
    onExited: {
      if (w.pendingReload) { w.pendingReload = false; w.reload(); return }
      const list = w.acc.slice().sort((x, y) => x.localeCompare(y, undefined, { numeric: true }))
      w.files = w.shuffle ? w.shuffled(list) : list
      w.scanned = true
      w.idx = -1
      w.failStreak = 0
      w.advance()
    }
  }

  function reload() {
    if (w.src === "") {
      w.files = []; w.scanned = false; w.missing = false; w.idx = -1
      w.pending = -1
      slotA.url = ""; slotB.url = ""; slotA.shown = false; slotB.shown = false; w.front = -1
      return
    }
    if (lister.running) { w.pendingReload = true; return }
    w.acc = []
    w.missing = false
    w.scanned = false
    lister.command = ["bash", "-c", w.listScript, "ooze-imageframe", w.expand(w.src)]
    lister.running = true
  }
  onSrcChanged: w.reload()
  onShuffleChanged: if (w.scanned) w.reload()
  Component.onCompleted: w.reload()

  // ── dos "ranuras" con fundido cruzado ──
  property int front: -1
  property int pending: -1
  readonly property var slots: [slotA, slotB]

  function advance() {
    if (w.files.length === 0) return
    w.idx = (w.idx + 1) % w.files.length
    w.show(w.files[w.idx])
  }
  function show(path) {
    const url = UserProfile.fileUrl(path)
    const b = w.front === 0 ? 1 : 0
    const s = w.slots[b]
    w.pending = b
    if (s.url === url && s.ready) { w.swap(); return }
    s.url = url
  }
  function swap() {
    const b = w.pending
    if (b < 0) return
    w.pending = -1
    const old = w.front
    w.slots[b].shown = true
    if (old >= 0) w.slots[old].shown = false
    w.front = b
    w.failStreak = 0
    freeTimer.restart()
  }
  function failed(b) {
    if (w.pending !== b) return
    w.pending = -1
    w.slots[b].url = ""
    w.failStreak++

    if (w.failStreak < w.files.length) Qt.callLater(w.advance)
  }

  Timer {
    id: freeTimer
    interval: 900
    onTriggered: {
      const o = w.front === 0 ? 1 : 0
      if (w.pending !== o) w.slots[o].url = ""
    }
  }
  Timer {
    interval: Math.max(1000, w.intervalSec * 1000)
    running: w.files.length > 1 && w.intervalSec > 0
    repeat: true
    onTriggered: w.advance()
  }

  function baseName(p) {
    const s = String(p).split("/").pop()
    const i = s.lastIndexOf(".")
    return i > 0 ? s.slice(0, i) : s
  }

  component Slot: Item {
    id: s
    property string url: ""
    property bool shown: false
    property string mode: "fit"
    property real box: 400
    readonly property bool ready: main.status === Image.Ready
    signal loaded()
    signal failed()

    anchors.fill: parent
    opacity: s.shown ? 1 : 0
    visible: opacity > 0.001
    Behavior on opacity { NumberAnimation { duration: Theme.animDuration(600); easing.type: Easing.InOutSine } }


    Image {
      anchors.fill: parent
      visible: s.mode === "blur" && s.url !== ""
      source: visible ? s.url : ""
      sourceSize: Qt.size(32, 32)
      fillMode: Image.PreserveAspectCrop
      smooth: true
      asynchronous: true
      cache: false
      opacity: 0.6
    }
    Image {
      id: main
      anchors.fill: parent
      source: s.url

      sourceSize: Qt.size(Math.min(3840, Math.max(64, Math.ceil(s.box * 1.5))),
                          Math.min(3840, Math.max(64, Math.ceil(s.box * 1.5))))
      fillMode: (s.mode === "fit" || s.mode === "blur") ? Image.PreserveAspectFit : Image.PreserveAspectCrop
      smooth: true
      asynchronous: true
      cache: false
      onStatusChanged: {
        if (status === Image.Ready) s.loaded()
        else if (status === Image.Error) s.failed()
      }
    }
  }

  // ── polaroid: la tarjeta ──
  Rectangle {
    visible: w.poly
    anchors.fill: parent
    radius: Theme.cozy ? Theme.cardRadius : 4
    color: "#f3efe6"
  }

  // ── ventana de la imagen ──
  ClippingRectangle {
    id: view
    x: w.circ ? (w.width - w.side) / 2 : w.pad
    y: w.circ ? (w.height - w.side) / 2 : w.pad
    width: w.circ ? w.side : Math.max(10, w.width - 2 * w.pad)
    height: w.circ ? w.side : Math.max(10, w.height - 2 * w.pad - w.polyFoot)
    radius: w.circ ? w.side / 2 : (w.poly ? 3 : w.rad)
    color: "transparent"

    Slot {
      id: slotA
      mode: w.sty; box: Math.max(view.width, view.height)
      onLoaded: if (w.pending === 0) w.swap()
      onFailed: w.failed(0)
    }
    Slot {
      id: slotB
      mode: w.sty; box: Math.max(view.width, view.height)
      onLoaded: if (w.pending === 1) w.swap()
      onFailed: w.failed(1)
    }
  }

  Text {
    visible: w.poly && w.caption && w.front >= 0 && w.idx >= 0 && w.idx < w.files.length
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10; bottomMargin: 9 }
    horizontalAlignment: Text.AlignHCenter
    text: (w.idx >= 0 && w.idx < w.files.length) ? w.baseName(w.files[w.idx]) : ""
    color: "#3a3a3a"
    elide: Text.ElideRight
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fs(12)
  }

  // ── estados vacíos ──
  WidgetCard {
    visible: w.front < 0
    anchors.fill: parent
    alpha: 0.5
    scaleRadius: w.circ ? 20 : 1
    Text {
      anchors.centerIn: parent
      width: parent.width - 24
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Theme.subtext
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fs(11)
      text: w.src === "" ? Translations.t("wgImgEmpty")
          : (w.scanned && w.missing) ? Translations.t("wgImgMissing") + "\n" + w.expand(w.src)
          : (w.scanned && w.files.length === 0) ? Translations.t("wgImgNone")
          : "…"
    }
  }
}
