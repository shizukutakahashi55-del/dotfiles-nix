// Launcher — lanzador de apps, ventanas, comandos y archivos (reemplaza a rofi).

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../../COMMON"
import "../../COMMON/SafeModel.js" as SafeModel
import "../Lang"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  signal closeRequested()


  signal commandRequested(string cmd, string arg)


  property string startMode: "apps"

  property string mode: "apps"


  readonly property var terminal: Theme.terminalCmd


  readonly property bool attached: Theme.launcherAttached


  readonly property bool fancyFxActive: Theme.effectsActive && Theme.launcherParticlesEnabled

  // ─── Medidas (lógicas: FusedPanel las escala según Ajustes → Ventanas) ──


  readonly property var sizes: [
    { imageW: 440, listW: 400, cardH: 420, rowH: 48 },
    { imageW: 540, listW: 460, cardH: 504, rowH: 54 },
    { imageW: 640, listW: 540, cardH: 600, rowH: 58 }
  ]
  readonly property var sz: root.sizes[Theme.launcherSize] ?? root.sizes[1]


  readonly property bool showImage: Theme.launcherShowImage
  readonly property int imageW: root.showImage ? root.sz.imageW : 0
  readonly property int listW: root.showImage ? root.sz.listW : root.sz.listW + 100
  readonly property int cardW: root.imageW + root.listW
  readonly property int cardH: root.sz.cardH
  readonly property int pad: 16
  readonly property int rowH: root.sz.rowH
  readonly property int rowGap: 4


  readonly property real flareSize: 30
  readonly property real cornerSize: 26


  property bool entering: false
  Timer {
    id: enterTimer
    interval: 500
    repeat: false
    onTriggered: root.entering = false
  }
  function beginEnter() {

    if (!Theme.effectsActive) { root.entering = false; return }
    root.entering = true
    enterTimer.restart()
  }

  readonly property var modes: [
    { id: "apps",    icon: "󰀻",  label: "launcherModeApps" },
    { id: "run",     icon: "󰆍",   label: "launcherModeRun" },
    { id: "files",   icon: "󰉋", label: "launcherModeFiles" }
  ]
  readonly property var modeInfo: modes.find(m => m.id === root.mode) ?? modes[0]


  readonly property bool prefixesOn: Theme.launcherCommandMode && root.mode === "apps"
  readonly property var themeSubRe: /^>\s*(theme|tema|color)\s/i
  readonly property string prefix: {
    if (!root.prefixesOn) return ""
    if (root.themeSubRe.test(root.query)) return "theme"
    const c = root.query.charAt(0)
    return c === ">" ? "cmd" : c === "!" ? "tmux" : ""
  }

  readonly property string prefixArg:
      root.prefix === "theme" ? root.query.replace(root.themeSubRe, "")
    : root.prefix !== ""      ? root.query.slice(1)
    :                           ""

  function capMode() { return root.mode.charAt(0).toUpperCase() + root.mode.slice(1) }


  readonly property string viewIcon:
      root.prefix === "cmd"   ? "󰅂"
    : root.prefix === "theme" ? "󰏘"
    : root.prefix === "tmux"  ? "󰆍"
    :                           root.modeInfo.icon
  readonly property string viewTitle:
      root.prefix === "cmd"   ? Translations.t("launcherTitleCmd")
    : root.prefix === "theme" ? Translations.t("launcherTitleTheme")
    : root.prefix === "tmux"  ? Translations.t("launcherTitleTmux")
    :                           Translations.t("launcherTitle" + root.capMode())
  readonly property string viewPlaceholder:
      root.prefix === "cmd"   ? Translations.t("launcherPhCmd")
    : root.prefix === "theme" ? Translations.t("launcherPhTheme")
    : root.prefix === "tmux"  ? Translations.t("launcherPhTmux")
    : root.mode === "files"   ? Translations.t("launcherPhFiles") + " " + root.prettyDir(root.browseDir)
    : (root.mode === "apps" && Theme.launcherCommandMode) ? Translations.t("launcherPhAppsCmd")
    :                           Translations.t("launcherPh" + root.capMode())

  LauncherCommands { id: cmds }
  TmuxSessions { id: tmux }


  readonly property var tmuxItems: tmux.sessions.map(n => ({
    id: "tmux:" + n, kind: "tmux", name: n,
    sub: Translations.t("launcherTmuxSession"), glyph: "󰆍",
    hay: [{ text: n.toLowerCase(), w: 1.0 }]
  }))
  readonly property var tmuxCreateRow: {
    if (root.prefix !== "tmux") return null
    const n = root.prefixArg.trim()
    if (n === "" || tmux.sessions.indexOf(n) >= 0) return null
    return { id: "tmux-new:" + n, kind: "tmuxNew", sessionName: n,
             name: Translations.t("launcherTmuxCreate") + ": " + n,
             sub: Translations.t("launcherTmuxNew"), glyph: "󰐕", hay: [] }
  }


  onPrefixChanged: { if (root.prefix === "tmux" && root.open) tmux.refresh() }

  // ─── Lo escrito y la selección ──────────────────────────────────
  readonly property string query: input.text
  property int selected: 0
  onQueryChanged: root.selected = 0


  // ─── Apps ───────────────────────────────────────────────────────
  readonly property var appItems: {
    const list = DesktopEntries.applications.values
    const out = []
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (!e || e.noDisplay) continue
      const name = e.name || e.id || ""
      if (name === "") continue
      const generic = e.genericName || ""
      out.push({
        id: e.id || name,
        name: name,
        sub: generic || e.comment || "",
        icon: e.icon || "",
        hay: [
          { text: name.toLowerCase(),                            w: 1.0  },
          { text: generic.toLowerCase(),                         w: 0.6  },
          { text: (e.keywords ? e.keywords.join(" ") : "").toLowerCase(), w: 0.5 },
          { text: (e.id || "").toLowerCase(),                    w: 0.4  },
          { text: (e.comment || "").toLowerCase(),               w: 0.25 }
        ]
      })
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    return out
  }


  // ─── Ejecutar (ejecutables del $PATH) ───────────────────────────
  property var runNames: []
  property int runGen: 0

  readonly property var runItems: root.runNames.map(n => ({
    id: n, name: n, sub: "",
    hay: [{ text: n.toLowerCase(), w: 1.0 }]
  }))

  function loadRun() {
    runProc.buf = []
    runProc.gotGen = false
    runProc.valid = false
    root.runGen++
    runProc.running = false
    runProc.running = true
  }


  Process {
    id: runProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false
    command: ["sh", "-c",
      'echo "$1"; IFS=:; for d in $PATH; do ' +
      '[ -d "$d" ] && find -L "$d" -maxdepth 1 -type f -executable -printf "%f\\n" 2>/dev/null; ' +
      'done | LC_ALL=C sort -u',
      "sh", String(root.runGen)]
    stdout: SplitParser {
      onRead: line => {
        if (!runProc.gotGen) {
          runProc.gotGen = true
          runProc.valid = (line === String(root.runGen))
          return
        }
        if (runProc.valid && line !== "") runProc.buf.push(line)
      }
    }
    onRunningChanged: {
      if (running || !runProc.valid) return
      root.runNames = runProc.buf.slice()
    }
  }

  // ─── Archivos ───────────────────────────────────────────────────
  property string browseDir: Quickshell.env("HOME")
  property bool showHidden: false
  property var fileLines: []
  property bool fileError: false
  property int fileGen: 0

  function parentOf(dir) {
    const i = dir.lastIndexOf("/")
    return i <= 0 ? "/" : dir.slice(0, i)
  }


  function prettyDir(dir) {
    const home = Quickshell.env("HOME")
    if (home && dir === home) return "~"
    if (home && dir.indexOf(home + "/") === 0) return "~" + dir.slice(home.length)
    return dir
  }

  readonly property var fileItems: {
    const dir = root.browseDir
    const out = []
    if (dir !== "/") {
      const up = root.parentOf(dir)
      out.push({ id: "..", name: "..", sub: root.prettyDir(up), isDir: true,
                 path: up, hay: [{ text: "..", w: 1.0 }] })
    }
    const lines = root.fileLines
    for (let i = 0; i < lines.length; i++) {
      const l = lines[i]
      const isDir = l.charAt(l.length - 1) === "/"
      const name = isDir ? l.slice(0, -1) : l
      if (name === "") continue
      const path = (dir === "/" ? "" : dir) + "/" + name
      out.push({ id: path, name: name, sub: "", isDir: isDir, path: path,
                 hay: [{ text: name.toLowerCase(), w: 1.0 }] })
    }
    return out
  }

  function loadDir() {
    fileProc.buf = []
    fileProc.gotGen = false
    fileProc.valid = false
    root.fileGen++
    fileProc.running = false
    fileProc.running = true
  }

  function browse(dir) {
    root.browseDir = dir


    root.fileLines = []
    root.fileError = false
    input.text = ""
    root.selected = 0
    root.loadDir()
  }

  Process {
    id: fileProc
    property var buf: []
    property bool gotGen: false
    property bool valid: false


    command: ["sh", "-c",
      'echo "$1"; cd -- "$2" 2>/dev/null || { echo __ERR__; exit 0; }; ' +
      'ls -1pL $3 --group-directories-first 2>/dev/null',
      "sh", String(root.fileGen), root.browseDir, root.showHidden ? "-A" : ""]
    stdout: SplitParser {
      onRead: line => {
        if (!fileProc.gotGen) {
          fileProc.gotGen = true
          fileProc.valid = (line === String(root.fileGen))
          return
        }
        if (fileProc.valid && line !== "") fileProc.buf.push(line)
      }
    }
    onRunningChanged: {
      if (running || !fileProc.valid) return
      const lines = fileProc.buf.slice()
      const bad = lines.length === 1 && lines[0] === "__ERR__"
      root.fileError = bad
      root.fileLines = bad ? [] : lines
    }
  }


  readonly property var calcFuncs: ({
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, floor: Math.floor,
    ceil: Math.ceil, round: Math.round, exp: Math.exp, ln: Math.log,
    log: Math.log10, log2: Math.log2, sin: Math.sin, cos: Math.cos,
    tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan
  })
  readonly property var calcConsts: ({ pi: Math.PI, e: Math.E })


  function calcEval(text) {
    let src = (text ?? "").trim().toLowerCase()
    if (src === "") return null
    src = src.replace(/×/g, "*").replace(/÷/g, "/").replace(/\*\*/g, "^")
             .replace(/,/g, ".").replace(/π/g, "pi")

    // ── Tokens ──
    const toks = []
    let i = 0
    while (i < src.length) {
      const rest = src.slice(i)
      let m
      if (/^\s/.test(rest)) { i++; continue }
      if ((m = /^(\d+\.?\d*|\.\d+)/.exec(rest))) { toks.push({ t: "n", v: parseFloat(m[1]) }); i += m[1].length; continue }
      if ((m = /^[a-z_][a-z0-9_]*/.exec(rest))) { toks.push({ t: "id", v: m[0] }); i += m[0].length; continue }
      if ("+-*/%^()".indexOf(rest[0]) >= 0) { toks.push({ t: "op", v: rest[0] }); i++; continue }
      return null
    }
    if (toks.length === 0) return null

    // ── Parser ──
    let pos = 0
    let used = false
    const peek = () => toks[pos]
    const isOp = v => pos < toks.length && toks[pos].t === "op" && toks[pos].v === v
    const fail = () => { throw new Error("calc") }

    function expr() {
      let v = term()
      while (isOp("+") || isOp("-")) {
        const op = toks[pos++].v
        const r = term()
        used = true
        v = op === "+" ? v + r : v - r
      }
      return v
    }
    function term() {
      let v = unary()
      while (isOp("*") || isOp("/") || isOp("%")) {
        const op = toks[pos++].v
        const r = unary()
        used = true
        v = op === "*" ? v * r : op === "/" ? v / r : v % r
      }
      return v
    }
    function unary() {
      if (isOp("-")) { pos++; return -unary() }
      if (isOp("+")) { pos++; return unary() }
      return power()
    }
    function power() {
      const b = primary()
      if (isOp("^")) { pos++; used = true; return Math.pow(b, unary()) }
      return b
    }
    function primary() {
      const tk = peek()
      if (!tk) fail()
      if (tk.t === "n") { pos++; return tk.v }
      if (tk.t === "op" && tk.v === "(") {
        pos++
        const v = expr()
        if (!isOp(")")) fail()
        pos++
        return v
      }
      if (tk.t === "id") {
        pos++
        const has = Object.prototype.hasOwnProperty
        const fn = has.call(root.calcFuncs, tk.v) ? root.calcFuncs[tk.v] : null
        if (fn && isOp("(")) {
          pos++
          const v = expr()
          if (!isOp(")")) fail()
          pos++
          used = true
          return fn(v)
        }
        if (!fn && has.call(root.calcConsts, tk.v)) return root.calcConsts[tk.v]
      }
      fail()
    }

    let result
    try {
      result = expr()
      if (pos !== toks.length) return null
    } catch (e) {
      return null
    }
    if (!used || typeof result !== "number" || !isFinite(result)) return null


    let out = String(Number(result.toPrecision(12)))
    if (out === "-0") out = "0"
    return { value: out, expr: (text ?? "").trim() }
  }

  readonly property var calcResult: (root.mode === "apps" && root.prefix === "") ? root.calcEval(root.query) : null

  readonly property var items:
      root.prefix === "cmd"   ? cmds.items
    : root.prefix === "theme" ? cmds.themeItems
    : root.prefix === "tmux"  ? root.tmuxItems
    : root.mode === "apps"    ? root.appItems
    : root.mode === "run"     ? root.runItems
    :                           root.fileItems


  readonly property string filterText:
      root.prefix !== "" ? root.prefixArg
    : root.mode === "run" ? (root.query.trim().split(/\s+/)[0] ?? "")
    :                       root.query


  readonly property var baseResults: {
    const src = root.items
    const terms = Fuzzy.terms(root.filterText)
    if (terms.length === 0) return src.length > 400 ? src.slice(0, 400) : src

    const scored = []
    for (let i = 0; i < src.length; i++) {
      const s = Fuzzy.match(terms, src[i].hay)
      if (s >= 0) scored.push({ it: src[i], s: s, i: i })
    }

    scored.sort((a, b) => (b.s - a.s) || (a.i - b.i))
    const out = []
    const n = Math.min(scored.length, 400)
    for (let i = 0; i < n; i++) out.push(scored[i].it)
    return out
  }


  readonly property var results: {
    const c = root.calcResult
    const base = root.tmuxCreateRow ? root.baseResults.concat([root.tmuxCreateRow]) : root.baseResults
    if (!c) return base
    return [{
      id: "__calc__" + c.expr + "=" + c.value,
      name: c.value,
      sub: c.expr + "  ·  " + Translations.t("launcherCalcCopy"),
      isCalc: true,
      value: c.value,
      hay: []
    }].concat(base)
  }

  readonly property var current: root.results[root.selected] ?? null


  property var displayResults: root.results
  onResultsChanged: Qt.callLater(root.syncDisplayResults)
  function syncDisplayResults() {
    const next = root.results
    // Un move en ScriptModel puede crashear Qt 6.11.2: si el orden cambia, reiniciar el modelo.
    if (SafeModel.wouldMove(root.displayResults, next, r => r.id)) root.displayResults = []
    root.displayResults = next
  }

  function move(delta) {
    const n = root.results.length
    if (n === 0) return
    root.selected = Math.max(0, Math.min(n - 1, root.selected + delta))
  }

  function setMode(id) {
    if (id === root.mode) {

      if (root.prefix !== "") input.text = ""
      return
    }
    root.mode = id
  }


  function baseModeOf(m) { return root.modes.some(x => x.id === m) ? m : "apps" }
  function startPrefix(m) {
    if (!Theme.launcherCommandMode) return ""
    return m === "commands" ? ">" : m === "tmux" ? "!" : ""
  }

  function cycleMode(delta) {
    const i = root.modes.findIndex(m => m.id === root.mode)
    const n = root.modes.length
    root.setMode(root.modes[(i + delta + n) % n].id)
  }


  onModeChanged: {
    input.text = ""
    root.selected = 0
    root.beginEnter()
    root.ensureData()
  }

  function ensureData() {
    if (!root.open) return
    if (root.mode === "run") root.loadRun()
    else if (root.mode === "files") root.loadDir()
  }


  function findEntry(id) {
    const list = DesktopEntries.applications.values
    for (let i = 0; i < list.length; i++) {
      const e = list[i]
      if (e && e.id === id) return e
    }
    return null
  }

  function launchApp(item) {
    if (!item) return
    const e = root.findEntry(item.id)
    if (!e) return
    if (e.runInTerminal) {

      const cmd = (e.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a))
      Quickshell.execDetached(root.terminal.concat(cmd))
    } else {
      e.execute()
    }
    root.closeRequested()
  }


  function runCommand(cmd, inTerminal) {
    if (cmd === "") return
    if (inTerminal) Quickshell.execDetached(root.terminal.concat(["sh", "-c", cmd]))
    else Quickshell.execDetached(["sh", "-c", cmd])
    root.closeRequested()
  }

  function activate(inTerminal) {
    const item = root.current
    const typed = root.query.trim()

    if (root.mode === "run") {

      if (typed !== "" && (/\s/.test(typed) || !item)) root.runCommand(typed, inTerminal)
      else if (item) root.runCommand(item.name, inTerminal)
      return
    }
    if (!item) return

    if (item.isCalc) {

      Quickshell.execDetached(["wl-copy", item.value])
      root.closeRequested()
      return
    }

    if (item.kind === "command") {

      if (item.submode) { input.text = item.submode; input.forceActiveFocus(); return }
      root.commandRequested(item.cmd, item.arg ?? "")
      return
    }
    if (item.kind === "tmux" || item.kind === "tmuxNew") {
      tmux.launch(item.kind === "tmux" ? item.name : item.sessionName, item.kind === "tmuxNew")
      root.closeRequested()
      return
    }
    if (root.mode === "apps") {
      root.launchApp(item)
    } else {
      if (item.isDir) root.browse(item.path)
      else {
        Quickshell.execDetached(["xdg-open", item.path])
        root.closeRequested()
      }
    }
  }

  property string wallPath: ""

  property string wallClipPath: ""


  Process {
    id: wallProc
    property string img: ""
    property string clip: ""
    command: ["sh", "-c",
      'wp=$(cat "$HOME/.cache/awww/last" 2>/dev/null); ' +
      '[ -f "$wp" ] || wp=$(awww query 2>/dev/null | grep -oP "(?<=image: ).*" | head -n1); ' +
      '[ -f "$wp" ] || { [ -f "$HOME/.config/rofi/fallback.jpg" ] && wp="$HOME/.config/rofi/fallback.jpg"; }; ' +
      'clip=""; v=$(cat "$HOME/.cache/oozeshell/live-active" 2>/dev/null); ' +
      'if [ -n "$v" ]; then c="$HOME/.cache/oozeshell/live/$(printf %s "$v" | md5sum | cut -d" " -f1)-preview.gif"; ' +
      '[ -f "$c" ] && clip="$c"; fi; ' +
      'printf "W:%s\\nC:%s\\n" "$wp" "$clip"']
    stdout: SplitParser {
      onRead: line => {
        if (line.startsWith("W:")) wallProc.img = line.slice(2)
        else if (line.startsWith("C:")) wallProc.clip = line.slice(2)
      }
    }
    onRunningChanged: {
      if (running) return
      root.wallPath = wallProc.img.trim()
      root.wallClipPath = wallProc.clip.trim()
      wallProc.img = ""
      wallProc.clip = ""
    }
  }


  function toUrl(path) {
    return path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")
  }
  readonly property url wallUrl: root.toUrl(root.wallPath)
  readonly property url wallClipUrl: root.toUrl(root.wallClipPath)

  onOpenChanged: {
    if (!root.open) return


    root.beginEnter()
    root.showHidden = false
    root.browseDir = Quickshell.env("HOME")
    root.fileLines = []
    root.fileError = false
    const base = root.baseModeOf(root.startMode)
    const modeChanged = root.mode !== base
    root.mode = base

    input.text = root.startPrefix(root.startMode)
    root.selected = 0
    if (!modeChanged) root.ensureData()
    if (root.prefix === "tmux") tmux.refresh()
    if (!wallProc.running) wallProc.running = true


    Qt.callLater(() => input.forceActiveFocus())
    focusTimer.restart()
  }

  Timer {
    id: focusTimer
    interval: 120
    repeat: false
    onTriggered: if (root.open && !input.activeFocus) input.forceActiveFocus()
  }

  FusedWindow {
    id: fw
    active: root.open || panel.shown
    targetScreen: root.targetScreen
    namespace: "oozeshell-launcher"

    exclusiveKeys: true
    onCloseRequested: root.closeRequested()


    onKeyPressed: (key, modifiers, text) => {
      input.forceActiveFocus()
      if (text.length === 1 && text.charCodeAt(0) >= 32 && (modifiers & Qt.ControlModifier) === 0)
        input.text += text
    }

    // ── Partículas ambiente ("polvo mágico") ──────────────────────

    LauncherParticles {
      anchors.fill: parent
      active: root.open && root.fancyFxActive
    }

    FusedPanel {
      id: panel

      open: root.open
      panelWidth: root.cardW
      contentHeight: root.cardH
      align: "center"

      // ── Ubicación: conectado a la barra o centrado ─────────────


      flare: root.flareSize
      bodyRadius: root.cornerSize


      floatWin: root.attached && Theme.floatWindows
      detached: !root.attached || fw.detached || panel.floatWin
      flareStart: root.attached
      flareEnd: root.attached
      x: root.attached ? (panel.vertical ? panel.placedDepth : panel.placedAlong)
                       : Math.round((panel.hostWidth - panel.width) / 2)
      y: root.attached ? (panel.vertical ? panel.placedAlong : panel.placedDepth)
                       : Math.round((panel.hostHeight - panel.height) / 2)

      // ── Wallpaper, a la izquierda, recortado con la silueta del panel ──

      backdrop: [
        Item {
          id: wall


          width: Math.round(root.imageW * panel.scaleFactor)
          height: parent.height
          visible: root.showImage

          clip: true


          readonly property bool live: root.open && root.showImage


          readonly property bool fx: wall.live && Theme.effectsActive


          readonly property bool liveGif: wall.fx && Theme.launcherWallpaperLiveEnabled
          onFxChanged: { if (!wall.fx) wallMotion.drift = 0 }

          Rectangle { anchors.fill: parent; color: Theme.surface }


          Item {
            id: wallMotion
            anchors.fill: parent
            transformOrigin: Item.Center

            property real drift: 0
            scale: 1.0 + 0.07 * drift
            transform: Translate { x: -12 * wallMotion.drift * panel.scaleFactor
                                   y: -8 * wallMotion.drift * panel.scaleFactor }

            SequentialAnimation on drift {
              running: wall.fx && Theme.uiAnimationsEnabled
              loops: Animation.Infinite
              NumberAnimation { from: 0; to: 1; duration: Theme.animDuration(16000); easing.type: Easing.InOutSine }
              NumberAnimation { from: 1; to: 0; duration: Theme.animDuration(16000); easing.type: Easing.InOutSine }
            }

            Image {
              id: wallImg
              anchors.fill: parent
              source: root.showImage ? root.wallUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              sourceSize.height: 1200
              opacity: status === Image.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(400) } }
            }


            AnimatedImage {
              id: wallClip
              anchors.fill: parent
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              cache: true
              source: (wall.liveGif && root.wallClipPath !== "") ? root.wallClipUrl : ""
              playing: wall.liveGif && status === AnimatedImage.Ready && Theme.uiAnimationsEnabled
              opacity: status === AnimatedImage.Ready ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: Theme.animDuration(500) } }
            }
          }


          Shape {
            id: orb
            readonly property real d: 420 * panel.scaleFactor
            width: orb.d
            height: orb.d
            x: wall.width * 0.05 + wall.width * 0.35 * orbMove.t
            y: wall.height * 0.10 + wall.height * 0.30 * (1 - orbMove.t)
            visible: opacity > 0.01
            opacity: wall.fx ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(600) } }

            QtObject {
              id: orbMove
              property real t: 0
              SequentialAnimation on t {
                running: wall.fx && Theme.uiAnimationsEnabled
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: Theme.animDuration(11000); easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: Theme.animDuration(11000); easing.type: Easing.InOutSine }
              }
            }

            ShapePath {
              strokeWidth: -1
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                centerX: orb.d / 2; centerY: orb.d / 2; centerRadius: orb.d / 2
                focalX: orb.d / 2; focalY: orb.d / 2
                GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.32) }
                GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.0) }
              }
              PathSvg { path: "M 0 0 L " + orb.d + " 0 L " + orb.d + " " + orb.d + " L 0 " + orb.d + " Z" }
            }
          }


          Rectangle {
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0.45; color: "transparent" }
              GradientStop { position: 1.0;  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92) }
            }
          }

          // ── Difuminado "hacia la barra" ─────────────────────────


          Rectangle {
            id: barFade
            readonly property bool wanted: root.attached && !fw.detached && !panel.floatWin && panel.edge !== "right"
            visible: opacity > 0.01
            opacity: barFade.wanted ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(250) } }

            x: 0
            y: panel.edge === "bottom" ? parent.height - height : 0
            width: panel.vertical ? parent.width * 0.5 : parent.width
            height: panel.vertical ? parent.height : parent.height * 0.5


            rotation: panel.edge === "bottom" ? 180 : 0
            gradient: Gradient {
              orientation: panel.vertical ? Gradient.Horizontal : Gradient.Vertical
              GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85) }
              GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.0) }
            }
          }

          // ── Difuminado "tocando la barra" ───────────────────────


          Rectangle {
            id: edgeFade
            readonly property real thick: 34 * panel.scaleFactor
            readonly property bool wanted: root.attached && panel.edge !== "right"
            visible: opacity > 0.01
            opacity: edgeFade.wanted ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animDuration(250) } }

            x: 0
            y: panel.edge === "bottom" ? parent.height - height : 0
            width: panel.vertical ? edgeFade.thick : parent.width
            height: panel.vertical ? parent.height : edgeFade.thick
            rotation: panel.edge === "bottom" ? 180 : 0
            gradient: Gradient {
              orientation: panel.vertical ? Gradient.Horizontal : Gradient.Vertical
              GradientStop { position: 0.0; color: Theme.bg }
              GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.0) }
            }
          }


          Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            width: 90 * panel.scaleFactor
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 1.0; color: Theme.bg }
            }
          }
        },


        Rectangle {
          x: wall.width
          width: 2
          height: parent.height
          visible: root.showImage
          color: Theme.bg
        }
      ]

      // ── Título sobre el wallpaper ──────────────────────────────
      Item {
        x: 0
        y: 0
        width: root.imageW
        height: root.cardH
        visible: root.showImage

        Column {
          id: titleCol
          anchors { left: parent.left; bottom: parent.bottom; leftMargin: 28; bottomMargin: 26 }
          spacing: 4


          transform: Translate { id: titleShift }
          Connections {
            target: root
            function onModeChanged() { if (Theme.effectsActive) titleIn.restart() }
          }
          ParallelAnimation {
            id: titleIn
            NumberAnimation { target: titleCol;   property: "opacity"; from: 0;   to: 1; duration: Theme.animDuration(260) }
            NumberAnimation { target: titleShift; property: "x";       from: -16; to: 0; duration: Theme.animDuration(320); easing.type: Easing.OutCubic }
          }


          Rectangle {
            width: 34
            height: 3
            radius: 2
            color: Theme.primary
          }

          Text {
            text: root.viewTitle
            color: Theme.text
            font.pixelSize: Theme.fs(26)
            font.family: Theme.titleFamily
            font.bold: true
          }
          Text {
            text: root.mode === "files"
              ? root.prettyDir(root.browseDir)
              : root.results.length + " / " + root.items.length
            color: Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.fontFamily
          }
        }
      }

      // ── Columna derecha: buscador, lista, modos ────────────────
      ColumnLayout {
        x: root.imageW
        y: 0
        width: root.listW
        height: root.cardH
        spacing: 0

        Item { Layout.preferredHeight: root.pad }

        // ─── Título (solo sin imagen: con imagen va sobre ella) ─
        RowLayout {
          visible: !root.showImage
          Layout.fillWidth: true
          Layout.leftMargin: root.pad + 6
          Layout.rightMargin: root.pad + 6
          Layout.bottomMargin: 10
          spacing: 10

          Text {
            text: root.viewIcon
            color: Theme.primary
            font.pixelSize: Theme.fs(22)
            font.family: Theme.monoFamily
          }
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: root.viewTitle
            color: Theme.text
            font.pixelSize: Theme.fs(20)
            font.family: Theme.titleFamily
            font.bold: true
          }
          Text {
            text: root.mode === "files"
              ? root.prettyDir(root.browseDir)
              : root.results.length + " / " + root.items.length
            color: Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
        }

        // ─── Buscador ─────────────────────────────────────────
        Rectangle {
          Layout.fillWidth: true
          Layout.leftMargin: root.pad
          Layout.rightMargin: root.pad
          Layout.preferredHeight: 50
          radius: Theme.cardRadius
          color: Theme.surface

          border.width: input.activeFocus ? 1 : 0
          border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
          Behavior on border.width { NumberAnimation { duration: Theme.animDuration(150) } }


          Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
            visible: input.activeFocus && root.fancyFxActive
            opacity: 0
            SequentialAnimation on opacity {
              running: (input.activeFocus && root.fancyFxActive) && Theme.uiAnimationsEnabled
              loops: Animation.Infinite
              NumberAnimation { from: 0.15; to: 0.6; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.6; to: 0.15; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
            }
          }

          RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 10

            Text {
              text: root.viewIcon
              color: Theme.primary
              font.pixelSize: Theme.fs(20)
              font.family: Theme.monoFamily
            }

            Item {
              Layout.fillWidth: true
              Layout.fillHeight: true

              TextInput {
                id: input
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(16)
                font.family: Theme.fontFamily
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText

                Keys.onPressed: event => {
                  const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
                  const alt  = (event.modifiers & Qt.AltModifier) !== 0

                  switch (event.key) {
                    case Qt.Key_Escape:
                      root.closeRequested()
                      event.accepted = true
                      return

                    case Qt.Key_Down:
                      root.move(1); event.accepted = true; return
                    case Qt.Key_Up:
                      root.move(-1); event.accepted = true; return
                    case Qt.Key_PageDown:
                      root.move(7); event.accepted = true; return
                    case Qt.Key_PageUp:
                      root.move(-7); event.accepted = true; return

                    case Qt.Key_Tab:
                      root.cycleMode(1); event.accepted = true; return
                    case Qt.Key_Backtab:
                      root.cycleMode(-1); event.accepted = true; return

                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                      root.activate(ctrl)
                      event.accepted = true
                      return

                    case Qt.Key_Backspace:

                      if (root.mode === "files" && input.text === "" && root.browseDir !== "/") {
                        root.browse(root.parentOf(root.browseDir))
                        event.accepted = true
                      }
                      return
                  }


                  if (ctrl) {
                    switch (event.key) {
                      case Qt.Key_N:
                      case Qt.Key_J:
                        root.move(1); event.accepted = true; return
                      case Qt.Key_P:
                      case Qt.Key_K:
                        root.move(-1); event.accepted = true; return
                      case Qt.Key_U:
                        input.text = ""; event.accepted = true; return
                      case Qt.Key_H:
                        if (root.mode === "files") {
                          root.showHidden = !root.showHidden
                          root.loadDir()
                          event.accepted = true
                        }
                        return
                    }
                  }


                  if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                    const m = root.modes[event.key - Qt.Key_1]
                    if (m) root.setMode(m.id)
                    event.accepted = true
                  }
                }
              }


              Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                visible: input.text === ""
                elide: Text.ElideRight
                text: root.viewPlaceholder
                color: Theme.subtext
                font.pixelSize: Theme.fs(16)
                font.family: Theme.fontFamily
              }
            }

            Text {
              text: root.results.length
              color: Theme.subtext
              font.pixelSize: Theme.fs(12)
              font.family: Theme.fontFamily
            }
          }
        }

        Item { Layout.preferredHeight: 10 }

        // ─── Lista ────────────────────────────────────────────
        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.leftMargin: root.pad - 6
          Layout.rightMargin: root.pad - 6

          ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: parent.top }
            readonly property int rowStep: root.rowH + root.rowGap
            readonly property int fitRows: Math.max(1, Math.floor((parent.height + root.rowGap + 4) / list.rowStep))
            height: list.fitRows * list.rowStep - root.rowGap
            clip: true
            spacing: root.rowGap
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            model: ScriptModel {
              values: root.displayResults
              objectProp: "id"
            }


            Connections {
              target: root
              function onSelectedChanged() {
                list.positionViewAtIndex(root.selected, ListView.Contain)
              }
            }

            delegate: Item {
              id: row
              required property var modelData
              required property int index

              readonly property bool isCurrent: row.index === root.selected
              readonly property bool isFile: root.mode === "files"

              width: ListView.view.width
              height: root.rowH


              property bool revealed: false
              property bool instant: false
              opacity: row.revealed ? 1 : 0
              Behavior on opacity {
                enabled: !row.instant
                NumberAnimation { duration: Theme.animDuration(220) }
              }
              transform: Translate {
                y: row.revealed ? 0 : 10
                Behavior on y {
                  enabled: !row.instant
                  NumberAnimation { duration: Theme.animDuration(260); easing.type: Easing.OutCubic }
                }
              }
              Timer {
                id: revealTimer
                interval: 1 + Math.min(row.index, 9) * 26
                repeat: false
                onTriggered: row.revealed = true
              }
              Component.onCompleted: {
                if (root.entering) revealTimer.start()
                else { row.instant = true; row.revealed = true }
              }

              Rectangle {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                radius: Theme.cardRadius - 2
                color: row.isCurrent ? Theme.surfaceHigh
                     : rowArea.containsMouse ? Theme.surface
                     : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
              }


              Rectangle {
                visible: row.isCurrent && root.fancyFxActive
                width: 10
                height: 28
                radius: 5
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 5; verticalCenter: parent.verticalCenter }
                opacity: 0.15
                SequentialAnimation on opacity {
                  running: (row.isCurrent && root.fancyFxActive) && Theme.uiAnimationsEnabled
                  loops: Animation.Infinite
                  NumberAnimation { from: 0.15; to: 0.45; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                  NumberAnimation { from: 0.45; to: 0.15; duration: Theme.animDuration(900); easing.type: Easing.InOutSine }
                }
              }

              Rectangle {
                visible: row.isCurrent
                width: 3
                height: 22
                radius: 2
                color: Theme.primary
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
              }

              RowLayout {
                anchors { fill: parent; leftMargin: 22; rightMargin: 16 }
                spacing: 12


                Item {
                  Layout.preferredWidth: 28
                  Layout.preferredHeight: 28

                  AppIcon {
                    anchors.fill: parent
                    visible: root.mode === "apps" && !row.modelData.isCalc && !row.modelData.glyph
                    size: 28
                    icon: row.modelData.icon ?? ""
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: root.mode === "run" || root.mode === "files" || !!row.modelData.isCalc || !!row.modelData.glyph
                    text: row.modelData.isCalc ? "󰃬"
                        : row.modelData.glyph ? row.modelData.glyph
                        : root.mode === "run" ? "󰆍"
                        : (row.modelData.isDir ? "󰉋" : "󰈔")
                    color: (row.modelData.isCalc || !!row.modelData.glyph) ? Theme.primary
                         : (row.isFile && row.modelData.isDir) ? Theme.primary : Theme.subtext
                    font.pixelSize: Theme.fs(22)
                    font.family: Theme.monoFamily
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0

                  Text {
                    Layout.fillWidth: true
                    text: row.modelData.isCalc ? "= " + row.modelData.name : row.modelData.name
                    elide: Text.ElideRight
                    color: Theme.text
                    font.pixelSize: Theme.fs(15)
                    font.family: Theme.fontFamily
                    font.bold: row.isCurrent || !!row.modelData.isCalc
                  }
                  Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.modelData.sub ?? ""
                    elide: Text.ElideRight
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                Text {
                  visible: row.isCurrent
                  text: "󰌑"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(14)
                  font.family: Theme.monoFamily
                }
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selected = row.index
                  root.activate(false)
                }
              }
            }
          }

          // ─── Estados vacíos ──────────────────────────────────
          Text {
            anchors.centerIn: parent
            width: parent.width - 48
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.results.length === 0
            color: Theme.subtext
            font.pixelSize: Theme.fs(14)
            font.family: Theme.fontFamily
            text: root.mode === "run" && root.query.trim() !== ""
                    ? Translations.t("launcherRunHint") + "  " + root.query.trim()
                : root.prefix === "tmux" ? Translations.t("launcherTmuxEmpty")
                : root.mode === "files"
                    ? (root.fileError ? Translations.t("launcherFolderError")
                       : root.query !== "" ? Translations.t("launcherEmpty")
                       : Translations.t("launcherFolderEmpty"))
                : Translations.t("launcherEmpty")
          }
        }

        Item { Layout.preferredHeight: 10 }

        // ─── Modos ────────────────────────────────────────────


        RowLayout {
          id: modeBar
          Layout.fillWidth: true
          Layout.leftMargin: root.pad
          Layout.rightMargin: root.pad
          Layout.preferredHeight: 40
          Layout.minimumHeight: 40
          Layout.maximumHeight: 40
          spacing: 6

          Repeater {
            model: root.modes

            delegate: Rectangle {
              id: modeBtn
              required property var modelData
              required property int index
              readonly property bool isCurrent: root.mode === modeBtn.modelData.id && root.prefix === ""

              readonly property real fullW: tabIcon.implicitWidth + tabLabelMetrics.advanceWidth + 6 + 28
              readonly property bool showLabel: modeBtn.isCurrent || modeBtn.width >= modeBtn.fullW - 1

              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.preferredWidth: modeBtn.fullW
              Layout.minimumWidth: modeBtn.isCurrent ? modeBtn.fullW : 40
              radius: Theme.cardRadius - 2
              color: modeBtn.isCurrent ? Theme.surface
                   : modeArea.containsMouse ? Theme.surface
                   : "transparent"
              border.width: modeBtn.isCurrent ? 1 : 0
              border.color: Theme.primary
              clip: true
              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }


              TextMetrics {
                id: tabLabelMetrics
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(13)
                font.bold: true
                text: Translations.t(modeBtn.modelData.label)
              }

              Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                  id: tabIcon
                  anchors.verticalCenter: parent.verticalCenter
                  text: modeBtn.modelData.icon
                  color: modeBtn.isCurrent ? Theme.primary : Theme.subtext
                  font.pixelSize: Theme.fs(16)
                  font.family: Theme.monoFamily
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modeBtn.showLabel
                  text: Translations.t(modeBtn.modelData.label)
                  color: modeBtn.isCurrent ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.fs(13)
                  font.family: Theme.fontFamily
                  font.bold: modeBtn.isCurrent
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: modeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.setMode(modeBtn.modelData.id)
                  input.forceActiveFocus()
                }
              }
            }
          }
        }

        Item { Layout.preferredHeight: 8 }

        // ─── Atajos ───────────────────────────────────────────
        Text {
          Layout.fillWidth: true
          Layout.leftMargin: root.pad + 4
          Layout.rightMargin: root.pad
          elide: Text.ElideRight
          text: Translations.t("launcherHint")
                + (root.mode === "files" ? "  ·  " + Translations.t("launcherHintFiles") : "")
                + (root.mode === "run"   ? "  ·  " + Translations.t("launcherHintRun")   : "")
                + (root.mode === "apps" && Theme.launcherCommandMode ? "  ·  " + Translations.t("launcherHintPrefix") : "")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }

        Item { Layout.preferredHeight: root.pad - 2 }
      }
    }
  }
}
