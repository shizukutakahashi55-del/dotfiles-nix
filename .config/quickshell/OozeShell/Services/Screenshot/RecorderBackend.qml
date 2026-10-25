// RecorderBackend — SCREENSHOT

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../COMMON"
import "../Lang"

QtObject {
  id: root

  property string phase: "idle"
  property string mode: ""
  property string geo: ""
  property string monitor: ""
  property string finalPath: ""
  property string tmpDir: ""
  property string segPath: ""
  property var segments: []
  property int segIndex: 0
  property string pending: ""
  property string queued: ""
  property int countdown: 0
  property real accum: 0
  property real runStart: 0
  property real elapsed: 0

  readonly property bool active: root.phase !== "idle"
  readonly property bool recording: root.phase === "recording"
  readonly property bool paused: root.phase === "paused"
  readonly property bool counting: root.phase === "countdown"

  readonly property string gRecord: String.fromCodePoint(0xF044A)
  readonly property string gPause: String.fromCodePoint(0xF03E4)
  readonly property string gPlay: String.fromCodePoint(0xF040A)
  readonly property string gStop: String.fromCodePoint(0xF04DB)
  readonly property string gTrash: String.fromCodePoint(0xF01B4)
  readonly property string gArea: String.fromCodePoint(0xF0001)
  readonly property string gScreen: "󰍹"
  readonly property string gFolder: "󰉋"
  readonly property string gVideo: String.fromCodePoint(0xF0567)

  readonly property string elapsedText: {
    const t = Math.floor(root.elapsed)
    const h = Math.floor(t / 3600)
    const m = Math.floor((t % 3600) / 60)
    const s = t % 60
    const two = n => (n < 10 ? "0" : "") + n
    return (h > 0 ? h + ":" + two(m) : m) + ":" + two(s)
  }

  readonly property string tip: {
    if (root.counting) return Translations.t("recStartingIn") + " " + root.countdown
    return Translations.t(root.paused ? "recMenuPaused" : "recMenuRecording") + " · " + root.elapsedText +
      "\n" + Translations.t("recTipHint")
  }

  function tr(k) { return Translations.t(k) }

  function item(text, glyph, fn) {
    return { isSeparator: false, hasChildren: false, enabled: true, icon: "", text: text, glyph: glyph, triggered: fn }
  }
  function separator() {
    return { isSeparator: true, hasChildren: false, enabled: false, icon: "", text: "", glyph: "", triggered: () => {} }
  }

  function menuItems() {
    const live = root.phase === "recording" || root.phase === "paused"
    const out = []
    if (live) {
      out.push(root.item(root.tr(root.paused ? "recResume" : "recPause"),
                         root.paused ? root.gPlay : root.gPause, () => root.togglePause()))
      out.push(root.item(root.tr("recStop"), root.gStop, () => root.stop()))
      out.push(root.item(root.tr("recDiscard"), root.gTrash, () => root.cancel()))
    } else {
      out.push(root.item(root.tr("recCancelStart"), root.gStop, () => root.cancel()))
    }
    out.push(root.separator())
    out.push(root.item(root.tr("recNewArea"), root.gArea, () => root.startNew("area")))
    out.push(root.item(root.tr("recNewScreen"), root.gScreen, () => root.startNew("screen")))
    out.push(root.separator())
    out.push(root.item(root.tr("recOpenFolder"), root.gFolder, () => CaptureConfig.openFolder("rec")))
    return out
  }

  readonly property var menuEntry: QtObject {
    readonly property bool custom: true
    readonly property string title: root.counting
      ? root.tr("recStartingIn") + " " + root.countdown
      : root.tr(root.paused ? "recMenuPaused" : "recMenuRecording") + " · " + root.elapsedText
    readonly property string glyph: root.paused ? root.gPause : root.gRecord
    readonly property var items: root.menuItems()
  }

  function startScreen() {
    if (root.phase !== "idle") return
    root.mode = "screen"
    root.geo = ""
    const n = WM.focusedMonitorName
    root.monitor = n !== "" ? n : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
    root.begin()
  }

  function startArea() {
    if (root.phase !== "idle" || ScreenshotBackend.pickerOpen) return
    ScreenshotBackend.openPicker("record")
  }

  function pickerDone(g) {
    root.mode = "area"
    root.geo = g
    root.monitor = ""
    root.phase = "preparing"
    settle.restart()
  }

  function launch(kind) {
    if (kind === "area") root.startArea()
    else root.startScreen()
  }

  property string laterKind: ""
  function launchLater(kind) {
    root.laterKind = kind
    later.restart()
  }

  function toggle(kind) {
    if (root.phase === "idle") root.launch(kind)
    else root.stop()
  }

  function startNew(kind) {
    root.queued = kind
    if (root.phase === "idle") {
      root.queued = ""
      root.launch(kind)
    } else {
      root.stop()
    }
  }

  function begin() {
    root.phase = "preparing"
    root.segments = []
    root.segIndex = 0
    root.accum = 0
    root.elapsed = 0
    prep.lines = []
    prep.command = CaptureConfig.cmd("recpath", {
      CAP_DIR: CaptureConfig.recDir,
      CAP_PATTERN: CaptureConfig.recPattern,
      CAP_EXT: CaptureConfig.recExt
    })
    prep.running = true
  }

  function afterPrep() {
    if (CaptureConfig.recDelay > 0) {
      root.countdown = CaptureConfig.recDelay
      root.phase = "countdown"
      countTimer.restart()
    } else {
      root.startSegment()
    }
  }

  function startSegment() {
    root.segIndex += 1
    root.segPath = root.tmpDir + "/seg_" + root.segIndex + "." + CaptureConfig.recExt
    rec.command = CaptureConfig.cmd("recseg", {
      CAP_OUT: root.segPath,
      CAP_GEO: root.geo,
      CAP_MON: root.monitor,
      CAP_CODEC: CaptureConfig.recCodec,
      CAP_FPS: String(CaptureConfig.recFps),
      CAP_AUDIO: CaptureConfig.recAudio,
      CAP_CRF: String(CaptureConfig.recCrf),
      CAP_PRESET: CaptureConfig.recPreset,
      CAP_EXT: CaptureConfig.recExt
    })
    root.pending = ""
    root.phase = "recording"
    root.runStart = Date.now()
    rec.running = true
    tick.restart()
  }

  function interrupt(kind) {
    root.accum += (Date.now() - root.runStart) / 1000
    root.elapsed = root.accum
    root.pending = kind
    if (rec.processId > 0) Quickshell.execDetached(["kill", "-INT", String(rec.processId)])
    else rec.running = false
  }

  function pause() {
    if (root.phase === "recording") root.interrupt("pause")
  }

  function resume() {
    if (root.phase === "paused") root.startSegment()
  }

  function togglePause() {
    if (root.phase === "recording") root.pause()
    else if (root.phase === "paused") root.resume()
  }

  function stop() {
    if (root.phase === "recording") root.interrupt("stop")
    else if (root.phase === "paused") root.finish()
    else if (root.phase === "countdown" || root.phase === "preparing") root.cancel()
  }

  function cancel() {
    if (root.phase === "recording") root.interrupt("cancel")
    else if (root.phase !== "idle") root.discard()
  }

  function segmentEnded(code) {
    tick.stop()
    if (root.pending === "") {
      root.fail(code)
      return
    }
    root.segments = root.segments.concat([root.segPath])
    const kind = root.pending
    root.pending = ""
    if (kind === "pause") root.phase = "paused"
    else if (kind === "cancel") root.discard()
    else root.finish()
  }

  function finish() {
    if (root.segments.length === 0) {
      root.discard()
      return
    }
    root.phase = "finishing"
    join.command = CaptureConfig.cmd("recjoin", { CAP_FINAL: root.finalPath }, root.segments)
    join.running = true
  }

  function discard() {
    countTimer.stop()
    tick.stop()
    if (root.tmpDir !== "") Quickshell.execDetached(["rm", "-rf", root.tmpDir])
    root.reset()
  }

  function fail(code) {
    const missing = code === 127
    Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "OozeShell",
      root.tr("recTitle"), root.tr(missing ? "recMissing" : "recFailed")])
    root.discard()
  }

  function reset() {
    root.phase = "idle"
    root.pending = ""
    root.segments = []
    root.tmpDir = ""
    root.elapsed = 0
    root.accum = 0
    const q = root.queued
    root.queued = ""
    if (q !== "") root.launch(q)
  }

  property Timer laterTimer: Timer {
    id: later
    interval: 450
    onTriggered: { const k = root.laterKind; root.laterKind = ""; root.launch(k) }
  }

  property Timer settleTimer: Timer {
    id: settle
    interval: 250
    onTriggered: root.begin()
  }

  property Timer countdownTimer: Timer {
    id: countTimer
    interval: 1000
    repeat: true
    onTriggered: {
      root.countdown -= 1
      if (root.countdown <= 0) {
        countTimer.stop()
        root.startSegment()
      }
    }
  }

  property Timer tickTimer: Timer {
    id: tick
    interval: 500
    repeat: true
    onTriggered: {
      if (root.phase === "recording") root.elapsed = root.accum + (Date.now() - root.runStart) / 1000
    }
  }

  property Process prepProc: Process {
    id: prep
    property var lines: []
    stdout: SplitParser { onRead: line => prep.lines.push(line) }
    onExited: (code, status) => {
      if (code === 0 && prep.lines.length >= 2) {
        root.finalPath = prep.lines[0]
        root.tmpDir = prep.lines[1]
        root.afterPrep()
      } else {
        root.fail(code)
      }
    }
  }

  property Process recProc: Process {
    id: rec
    onExited: (code, status) => root.segmentEnded(code)
  }

  property Process joinProc: Process {
    id: join
    onExited: (code, status) => {
      if (code === 0) {
        if (CaptureConfig.notify)
          Quickshell.execDetached(["notify-send", "-a", "OozeShell", root.tr("recTitle"), root.finalPath])
        root.reset()
      } else {
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "OozeShell",
          root.tr("recTitle"), root.tr("recJoinFailed") + "\n" + root.tmpDir])
        root.tmpDir = ""
        root.reset()
      }
    }
  }
}
