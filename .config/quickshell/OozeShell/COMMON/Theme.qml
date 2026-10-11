// Theme — UNA sola fuente de verdad para colores y medidas de todo el shell.
// Antes cada componente (Bar, CenterModules, Menu, Notify, Mpris) tenía su propio Process + Timer leyendo la paleta de matugen cada 3 s, y cada uno elegía colores distintos (la barra usaba "surface", Menu/Mpris usaban

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // ─── Escala de la interfaz (Ajustes → Interfaz) ───────────────


  property int fontLevel: 2
  property int barLevel: 2
  property int windowLevel: 2


  property string uiAnimationMode: "normal"


  property bool performanceMode: false
  signal performanceToggled(bool on)
  readonly property bool uiAnimationsEnabled: uiAnimationMode !== "off" && !performanceMode
  function animDuration(ms) {
    const base = Math.max(0, Number(ms) || 0)


    if (root.nativeAnim) return Math.round(base * root.nativeAnim.scale)

    if (root.performanceMode || root.uiAnimationMode === "off") return 0
    if (root.uiAnimationMode === "minimal") return Math.round(base * 0.4)
    return base
  }

  // ─── Núcleo nativo OPCIONAL (native/AnimationController → OozeShell.Native) ───


  property var nativeAnim: null
  property var nativeFonts: null
  readonly property bool nativeActive: root.nativeAnim !== null

  function loadNative() {
    try {
      const probe = Qt.createQmlObject(
        'import QtQml\nimport OozeShell.Native 1.0\n' +
        'QtObject { readonly property var ctl: AnimationController }',
        root, "OozeNativeProbe")
      root.nativeAnim = probe.ctl
      root.syncNative()
      console.log("[theme] núcleo nativo: activo")


      try {
        const fp = Qt.createQmlObject(
          'import QtQml\nimport OozeShell.Native 1.0\n' +
          'QtObject { readonly property var fp: FontProbe }', root, "OozeFontProbe")
        root.nativeFonts = fp.fp
      } catch (e2) { root.nativeFonts = null }
    } catch (e) {
      root.nativeAnim = null

      const why = (e.qmlErrors && e.qmlErrors.length)
        ? e.qmlErrors.map(x => x.message).join(" | ")
        : String(e).replace(/\s*\n\s*/g, " | ")
      console.log("[theme] núcleo nativo: no disponible (QML puro) —", why)
    }
  }
  function syncNative() {
    if (!root.nativeAnim) return
    root.nativeAnim.mode = root.uiAnimationMode
    root.nativeAnim.performance = root.performanceMode
  }
  onUiAnimationModeChanged: root.syncNative()
  onPerformanceModeChanged: root.syncNative()
  Component.onCompleted: { root.loadNative(); root.fontRescueRun() }
  function setUiAnimationMode(mode) {
    const valid = ["normal", "minimal", "off"]
    const next = valid.indexOf(mode) >= 0 ? mode : "normal"
    if (root.uiAnimationMode === next) return
    root.uiAnimationMode = next
    root.savePrefs()
  }

  readonly property var geometryScales: [0.85, 0.92, 1.0, 1.15, 1.35]
  readonly property var fontScales:     [0.85, 0.92, 1.0, 1.15, 1.30]


  readonly property int fontPercentMin: 50
  readonly property int fontPercentMax: 250
  property int fontPercent: 0
  readonly property bool fontCustom: fontPercent > 0
  readonly property real fontScale: fontPercent > 0 ? fontPercent / 100 : fontScales[fontLevel]

  readonly property int fontPercentEffective: Math.round(root.fontScale * 100)
  function clampFontPercent(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.fontPercent
    return Math.max(root.fontPercentMin, Math.min(root.fontPercentMax, n))
  }
  function setFontPercent(v) {
    const n = (v === 0 || v === "0") ? 0 : root.clampFontPercent(v)
    if (n === root.fontPercent) return
    root.fontPercent = n
    root.savePrefs()
  }
  readonly property real barScale:    geometryScales[barLevel]
  readonly property real windowScale: geometryScales[windowLevel]


  function fs(px) { return Math.max(6, Math.round(px * root.fontScale)) }


  function bs(px)  { return Math.round(px * root.barScale) }
  function bfs(px) { return Math.max(6, Math.round(px * root.fontScale * root.barScale)) }

  // ─── Medidas compartidas ───────────────────────────────────────


  readonly property int barHeight: Math.round(32 * barScale)
  // ─── Posición y modo de la barra (Ajustes → Interfaz) ──────────


  property string barPosition: "top"
  property bool barFloatingPref: false
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property bool barAtBottom: barPosition === "bottom"
  readonly property bool barAtRight: barPosition === "right"


  readonly property bool barFloating: (barFloatingPref || glassFloat) && !barVertical


  readonly property int verticalBarWidth: Math.round(44 * barScale)


  readonly property int barThickness: barVertical ? verticalBarWidth : barHeight

  readonly property int floatGap: Math.round(3 * barScale)
  // ─── Modo Islas (Ajustes → General → Barra) ───────────────────


  property bool islandsPref: false
  readonly property bool islandsMode: islandsPref && !barVertical


  property string barBackend: "ooze"


  readonly property bool usingWaybar: barBackend === "waybar" && !pillMode && !barVertical

  readonly property int waybarFace: 36
  readonly property int barFace: root.usingWaybar ? root.waybarFace : root.barOffset
  function setBarBackend(v) {
    const next = v === "waybar" ? "waybar" : "ooze"
    if (next === root.barBackend) return
    root.barBackend = next
    root.savePrefs()
  }

  // ─── Modo Píldora (Ajustes → Interfaz → Barra) ──────────────────


  property bool pillModePref: false
  readonly property bool pillMode: pillModePref && !barVertical


  property bool pillAutoHidePref: false
  property bool pillTraySyncPref: false


  readonly property bool barSeparated: barFloating || islandsMode

  readonly property int barEdge: barSeparated ? floatGap : 0


  readonly property int barOffset: barThickness + barEdge

  readonly property int barRadius: barFloating ? (root.cozy ? 4 : 14) : 0


  readonly property int flare: root.cozy ? 12 : 16


  readonly property int screenCorner: 16

  // ─── Estilo del "marco" de pantalla (Ajustes → Avanzado → Interfaz) ──


  property string frameStyle: "corners"
  readonly property bool frameCurved: frameStyle === "curved"

  property int frameCurveRadius: 28

  property int frameThickness: 3


  property real frameThicknessVis: frameThickness
  property bool frameAnimReady: false
  Timer {
    interval: 1500; running: true; repeat: false
    onTriggered: root.frameAnimReady = true
  }
  Behavior on frameThicknessVis {
    enabled: root.frameAnimReady
    NumberAnimation { duration: root.animDuration(180); easing.type: Easing.OutCubic }
  }


  readonly property bool frameThicknessSettling: Math.abs(frameThicknessVis - frameThickness) > 0.01

  property bool frameFuse: true
  function setFrameFuse(on) {
    if (!!on === root.frameFuse) return
    root.frameFuse = !!on
    root.savePrefs()
  }


  readonly property int frameCornerRadius: frameCurved ? frameCurveRadius : screenCorner

  function clampFrameCurveRadius(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.frameCurveRadius
    return Math.max(10, Math.min(60, n))
  }
  function clampFrameThickness(v) {
    const n = parseInt(v)
    if (isNaN(n)) return root.frameThickness


    return Math.max(0, Math.min(150, n))
  }


  property bool screenCorners: false


  readonly property bool frameOn: screenCorners && !cozy && !glassMode


  readonly property bool frameArmsActive: frameOn && frameCurved


  readonly property bool frameBorderActive:
    frameOn && frameCurved && !barSeparated && !pillMode


  readonly property bool dockUsable: dockEnabled && !frameBorderActive

  readonly property real frameSideArm: (frameArmsActive && frameThicknessVis > 0.01) ? frameThicknessVis : 0

  function setFrameStyle(style) {
    const next = (style === "curved") ? "curved" : "corners"
    if (next === root.frameStyle) return
    root.frameStyle = next
    root.savePrefs()
  }
  function setFrameCurveRadius(v) {
    const n = root.clampFrameCurveRadius(v)
    if (n === root.frameCurveRadius) return
    root.frameCurveRadius = n
    root.savePrefs()
  }
  function setFrameThickness(v) {
    const n = root.clampFrameThickness(v)
    if (n === root.frameThickness) return
    root.frameThickness = n
    root.savePrefs()
  }


  readonly property int animMs: 300

  // ─── Tooltips (FusedTip) ───────────────────────────────────────


  readonly property int tipFlare: root.cozy ? 8 : 10
  readonly property int tipRadius: root.cozy ? 8 : 14
  readonly property int tipMs: 200

  // ─── Estilo visual (Ajustes → Apariencia → Automático) ─────────


  property string uiStyle: "soft"
  readonly property bool cozy: uiStyle === "cozy"

  function setUiStyle(style) {
    const next = style === "cozy" ? "cozy" : "soft"
    if (next === root.uiStyle) return

    if (root.glassModePref) root.rebuildBar()
    root.uiStyle = next
    root.savePrefs()
  }


  onUiStyleChanged: {
    if (root.paletteMode) root.applyManualPalette(root.manualPaletteIndex)
    else if (root.lastRaw !== "") root.applyPalette(root.lastRaw)
  }

  // ─── Tipografía ─────────────────────────────────────────────────


  // comparaba con ===: una fuente instalada después (o con otra capitalización /


  property var systemFonts: Qt.fontFamilies()
  function normFont(s) { return String(s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "") }
  readonly property var fontIndex: {
    const m = ({})
    const have = root.systemFonts
    for (let i = 0; i < have.length; i++) {
      const k = root.normFont(have[i])
      if (k !== "" && m[k] === undefined) m[k] = have[i]
    }
    return m
  }

  function resolveFont(name) {
    const k = root.normFont(name)
    return k === "" ? "" : (root.fontIndex[k] ?? "")
  }
  function hasFont(name) { return root.resolveFont(name) !== "" }
  function pickInstalled(list, fallback) {
    for (let i = 0; i < list.length; i++) {
      const r = root.resolveFont(list[i])
      if (r !== "") return r
    }
    return fallback
  }
  function refreshFonts() {
    root.systemFonts = Qt.fontFamilies()
    root.fontRescueRun()
  }

  readonly property string monoFamily: root.pickInstalled(
    [ "JetBrainsMono Nerd Font", "JetBrainsMono NF", "JetBrainsMono Nerd Font Mono",
      "Symbols Nerd Font Mono", "Symbols Nerd Font" ], "JetBrainsMono Nerd Font")
  readonly property string iconFamily: root.monoFamily


  readonly property var pixelCandidates: [
    "Pixelify Sans", "Jersey 10", "Jersey 15", "Silkscreen", "VT323",
    "Tiny5", "Micro 5", "DotGothic16", "Press Start 2P", "Departure Mono",
    "Monocraft", "Cozette", "ProggyClean Nerd Font"
  ]
  property string pixelFontPref: ""

  FontLoader { id: pixelBundled; source: Qt.resolvedUrl("../assets/fonts/PixelFont.ttf") }
  FontLoader { id: cozyFont; source: Qt.resolvedUrl("../assets/fonts/VarelaRound-Regular.ttf") }
  readonly property string softRoundFamily:
    cozyFont.status === FontLoader.Ready ? cozyFont.name : root.monoFamily

  readonly property string pixelFamily: {
    if (root.pixelFontPref !== "" && root.hasFont(root.pixelFontPref))
      return root.resolveFont(root.pixelFontPref)
    if (pixelBundled.status === FontLoader.Ready) return pixelBundled.name
    return root.pickInstalled(root.pixelCandidates, root.softRoundFamily)
  }

  readonly property bool pixelFontFound:
    root.pixelFamily !== root.softRoundFamily && root.pixelFamily !== root.monoFamily

  readonly property string cozyFamily: root.pixelFamily

  // ─── Fuente de texto de OozeSoft ───────────────────────────────


  readonly property var softCandidates: [
    "Nunito", "Outfit", "Lexend", "Plus Jakarta Sans", "Manrope",
    "DM Sans", "Quicksand", "Figtree", "Inter"
  ]
  property string softFontPref: ""
  FontLoader { id: softBundled; source: Qt.resolvedUrl("../assets/fonts/SoftFont.ttf") }

  readonly property string softFamily: {
    if (root.softFontPref === "mono") return root.monoFamily
    if (root.softFontPref !== "" && root.hasFont(root.softFontPref))
      return root.resolveFont(root.softFontPref)
    if (softBundled.status === FontLoader.Ready) return softBundled.name
    return root.pickInstalled(root.softCandidates, root.softRoundFamily)
  }

  // ─── Fuente elegida ─────────────────────────────────────────────


  readonly property string fontFamily: root.cozy ? root.pixelFamily : root.softFamily


  readonly property string titleFamily: root.fontFamily

  readonly property string fontPref: root.cozy ? root.pixelFontPref : root.softFontPref
  function setFontPref(name) {
    if (root.cozy) root.setPixelFont(name)
    else root.setSoftFont(name)
  }


  readonly property var fontSuggestions: [
    "Nunito", "Nunito Sans", "M PLUS Rounded 1c", "Zen Maru Gothic", "Quicksand",
    "Fredoka", "Kosugi Maru", "Outfit", "Lexend", "Plus Jakarta Sans", "Manrope",
    "DM Sans", "Figtree", "Inter", "Varela Round"
  ]


  readonly property var fontChoices: {
    const out = [], seen = ({})
    const have = root.systemFonts
    for (let i = 0; i < have.length; i++) {
      const f = String(have[i])
      const k = root.normFont(f)
      if (k === "" || seen[k] || f.charAt(0) === ".") continue
      if (/symbols|emoji|dingbat|icons?$|awesome|webdings|wingdings/i.test(f)) continue
      seen[k] = true
      out.push(f)
    }
    out.sort((a, b) => a.localeCompare(b))
    return out
  }

  // ─── Rescate de fuentes (fc-list → FontLoader) ─────────────────────


  readonly property var fontWanted: [].concat(
    root.fontSuggestions, root.softCandidates, root.pixelCandidates)
  property var rescuedFiles: ({})
  property int rescuedCount: 0
  property string fontReport: ""

  function fontRescueRun() {

    if (root.nativeFonts) {
      try {
        const n = root.nativeFonts.rescan(root.fontWanted)
        root.rescuedCount += n
        console.log("[theme] fuentes (nativo):", root.nativeFonts.lastReport)
        if (n > 0) root.systemFonts = Qt.fontFamilies()
      } catch (e) { console.log("[theme] FontProbe falló:", e) }
    }

    if (!fontRescueProc.running) { fontRescueProc.buffer = ""; fontRescueProc.running = true }
  }
  function fontRescueApply(text) {
    const want = ({})
    for (const n of root.fontWanted) want[root.normFont(n)] = n
    const lines = text.split("\n")
    let loaded = 0, seen = 0
    for (const ln of lines) {
      const tab = ln.indexOf("\t")
      if (tab < 0) continue
      const fams = ln.slice(0, tab).split(",")
      const file = ln.slice(tab + 1).trim()
      if (file === "" || root.rescuedFiles[file]) continue
      let hit = ""
      for (const fm of fams) if (want[root.normFont(fm)] !== undefined) { hit = fm.trim(); break }
      if (hit === "") continue
      seen++
      if (root.hasFont(hit)) continue
      try {
        Qt.createQmlObject('import QtQuick\nFontLoader { source: "' +
          encodeURI("file://" + file).replace(/"/g, "%22") + '" }', root, "OozeFontRescue")
        root.rescuedFiles[file] = true
        loaded++
      } catch (e) { console.log("[theme] no pude cargar la fuente", file, e) }
    }
    root.rescuedCount += loaded
    if (loaded > 0) {

      fontRefreshTimer.restart()
    }
    root.fontReport = seen + " fuentes del tema vistas por fontconfig, " + loaded + " rescatadas"
    console.log("[theme] fuentes:", root.fontReport)
  }

  Process {
    id: fontRescueProc
    property string buffer: ""
    command: ["sh", "-c",
      "FC=$(command -v fc-list || ls /run/current-system/sw/bin/fc-list /etc/profiles/per-user/$USER/bin/fc-list $HOME/.nix-profile/bin/fc-list 2>/dev/null | head -n1); " +
      "[ -n \"$FC\" ] && \"$FC\" -f '%{family}\\t%{file}\\n' 2>/dev/null || true"]
    stdout: SplitParser { onRead: line => fontRescueProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const t = fontRescueProc.buffer
      fontRescueProc.buffer = ""
      if (t !== "") root.fontRescueApply(t)
    }
  }
  Timer {
    id: fontRefreshTimer
    interval: 250
    repeat: false
    onTriggered: root.systemFonts = Qt.fontFamilies()
  }
  function setSoftFont(name) {
    const v = String(name ?? "").trim()
    if (v === root.softFontPref) return
    root.softFontPref = v
    root.savePrefs()
  }

  function setPixelFont(name) {
    const v = String(name ?? "").trim()
    if (v === root.pixelFontPref) return
    root.pixelFontPref = v
    root.savePrefs()
  }


  readonly property int cardRadius:  root.cozy ? 4 : 12
  readonly property int panelRadius: root.cozy ? 12 : 20
  readonly property int islandRadius: root.cozy ? 8 : 13


  readonly property int inkWidth:  root.cozy ? 2 : 0
  readonly property int bw1: root.cozy ? 2 : 1

  readonly property int shadowY: root.cozy ? 3 : 0


  readonly property bool bgIsDark: root.bg.hslLightness < 0.5
  property color ink: root.bgIsDark ? Qt.darker(root.bg, 2.4)
                                    : Qt.tint(root.bg, Qt.rgba(root.text.r, root.text.g, root.text.b, 0.82))

  readonly property color edge: root.cozy ? root.ink : root.divider

  readonly property color shadowInk: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, root.bgIsDark ? 0.55 : 0.35)

  readonly property color paperShine: Qt.rgba(1, 1, 1, root.bgIsDark ? 0.07 : 0.35)
  Behavior on ink { ColorAnimation { duration: 300 } }


  function mix(a, b, t) {
    const x = (typeof a === "string") ? Qt.color(a) : a
    const y = (typeof b === "string") ? Qt.color(b) : b
    return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
  }


  function cozyAccent(c, dark) {
    const q = (typeof c === "string") ? Qt.color(c) : c
    const s = Math.min(1, q.hslSaturation * 1.08 + 0.04)
    const l = dark ? Math.max(0.62, Math.min(0.74, q.hslLightness))
                   : Math.max(0.38, Math.min(0.50, q.hslLightness))
    return Qt.hsla(q.hslHue, s, l, 1)
  }


  function hueLerp(a, b, t) {
    const d = ((b - a + 1.5) % 1) - 0.5
    return ((a + d * t) % 1 + 1) % 1
  }


  function cozify(p, dark) { return root.cozyTune(p, dark) }

  // ─── Paleta (defaults = tu paleta actual) ──────────────────────
  property color bg:          "#0d0e11"


  property color surfaceBase:     "#1e2030"
  property color surfaceHighBase: "#292b3d"
  readonly property color surface:     root.glassCtl ? root.withAlpha(root.surfaceBase, root.glassCtlAlpha)
                                                     : root.surfaceBase
  readonly property color surfaceHigh: root.glassCtl ? root.withAlpha(root.surfaceHighBase, root.glassCtlHiAlpha)
                                                     : root.surfaceHighBase
  property color primary:     "#4a90d9"
  property color textOnPrimary:   "#ffffff"
  property color text:        "#e1e2e8"
  property color subtext:     "#8e9ab0"
  property color error:       "#e05a5a"
  property color textOnError:     "#ffffff"


  property color primaryContainer:   "#1f3a5f"
  property color textOnPrimaryContainer: "#d6e6ff"
  property color outline:            "#8e9ab0"


  function tint(a) { return Qt.rgba(root.text.r, root.text.g, root.text.b, a) }


  readonly property color divider: root.tint(root.colorfulMode ? 0.17 : 0.10)

  // ─── Modo claro / oscuro ────────────────────────────────────────


  property string themeMode: "dark"
  readonly property bool lightMode: root.themeMode === "light"
  readonly property bool colorfulMode: root.themeMode === "colorful"


  property real lightSoftness: 0.92

  function soften(c) {
    const q = (typeof c === "string") ? Qt.color(c) : c
    const k = root.lightSoftness
    return Qt.rgba(q.r * k, q.g * k, q.b * k, 1)
  }

  readonly property string schemeMode: root.themeMode

  function setThemeMode(m) {
    const v = ["dark", "light", "colorful"].indexOf(m) >= 0 ? m : "dark"
    if (v === root.themeMode) return
    root.themeMode = v
    root.savePrefs()
  }

  function setLightMode(on) { root.setThemeMode(on === true ? "light" : "dark") }

  // ─── Modo Colorido ──────────────────────────────────────────────


  property int colorfulDepth: 50
  function setColorfulDepth(v) {
    const n = Math.max(0, Math.min(100, parseInt(v) || 0))
    if (n === root.colorfulDepth) return
    root.colorfulDepth = n
    if (root.colorfulMode && !root.paletteMode && root.lastRaw !== "") root.applyPalette(root.lastRaw)
    root.savePrefs()
  }


  function relLum(c) {
    const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
  }
  function contrastOf(a, b) {
    const la = root.relLum(a), lb = root.relLum(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
  }


  function colorForLum(h, s, target) {
    let lo = 0, hi = 1
    for (let i = 0; i < 14; i++) {
      const mid = (lo + hi) / 2
      if (root.relLum(Qt.hsla(h, s, mid, 1)) < target) lo = mid
      else hi = mid
    }
    return Qt.hsla(h, s, (lo + hi) / 2, 1)
  }

  function ensureContrast(fg, bgs, want) {
    let c = fg
    for (let i = 0; i < 10; i++) {
      if (bgs.every(b => root.contrastOf(c, b) >= want)) return c
      c = root.mix(c, "#ffffff", 0.12)
    }
    return c
  }

  function readableOn(bg, preferred) {
    if (preferred && root.contrastOf(preferred, bg) >= 4.5) return preferred
    const light = Qt.color("#f5f5f7"), dark = Qt.color("#101114")
    return root.contrastOf(light, bg) >= root.contrastOf(dark, bg) ? light : dark
  }


  function colorfulPalette(c) {
    const V = (k, m) => { const v = c[k]?.[m]?.color; return v ? Qt.color(v) : null }
    const pcD = V("primary_container", "dark") ?? root.primaryContainer
    const prD = V("primary", "dark") ?? root.primary
    let h = pcD.hslHue
    let grey = false
    if (pcD.hslSaturation < 0.04) {
      h = prD.hslHue
      if (prD.hslSaturation < 0.04) grey = true
    }
    if (h < 0) { h = 0; grey = true }
    const s = grey ? 0 : Math.max(0.35, Math.min(0.60, pcD.hslSaturation * 1.1))


    const lb = 0.020 + 0.030 * (root.colorfulDepth / 100)
    const lumS = (lb + 0.05) * 1.45 - 0.05
    const lumH = (lumS + 0.05) * 1.31 - 0.05


    const sS = grey ? 0 : Math.min(0.70, s * 1.04)
    const sH = grey ? 0 : Math.min(0.72, s * 1.08)
    const bg   = root.colorForLum(h, s,  lb)
    const surf = root.colorForLum(h, sS, lumS)
    const high = root.colorForLum(h, sH, lumH)
    const text = Qt.hsla(h, grey ? 0 : 0.30, 0.97, 1)


    const pcand = ["dark", "light"].map(m => V("primary", m)).filter(x => x)
    let primary = pcand.length > 0
      ? pcand.reduce((best, x) => Math.min(root.contrastOf(x, bg), root.contrastOf(x, high))
                                > Math.min(root.contrastOf(best, bg), root.contrastOf(best, high)) ? x : best)
      : root.primary
    primary = root.ensureContrast(primary, [bg, surf, high], 4.0)
    const errc = root.ensureContrast(V("error", "dark") ?? root.error, [bg, surf, high], 3.4)

    return {
      bg: bg, surface: surf, surfaceHigh: high,
      primary: primary,
      textOnPrimary: root.readableOn(primary, V("on_primary", "dark")),
      text: text,

      subtext: root.ensureContrast(root.mix(text, bg, 0.30), [surf, high], 4.2),
      error: errc,
      textOnError: root.readableOn(errc, V("on_error", "dark")),
      primaryContainer: root.colorForLum(h, Math.min(0.72, s * 1.1), (lumH + 0.05) * 1.12 - 0.05),
      textOnPrimaryContainer: text,
      outline: root.mix(text, bg, 0.50)
    }
  }


  onThemeModeChanged: { if (!root.paletteMode && root.lastRaw !== "") root.applyPalette(root.lastRaw) }

  Behavior on bg          { ColorAnimation { duration: 300 } }
  Behavior on surfaceBase     { ColorAnimation { duration: 300 } }
  Behavior on surfaceHighBase { ColorAnimation { duration: 300 } }
  Behavior on primary     { ColorAnimation { duration: 300 } }
  Behavior on textOnPrimary   { ColorAnimation { duration: 300 } }
  Behavior on text        { ColorAnimation { duration: 300 } }
  Behavior on subtext     { ColorAnimation { duration: 300 } }
  Behavior on error       { ColorAnimation { duration: 300 } }
  Behavior on primaryContainer   { ColorAnimation { duration: 300 } }
  Behavior on textOnPrimaryContainer { ColorAnimation { duration: 300 } }
  Behavior on outline            { ColorAnimation { duration: 300 } }


  function repaintPalette() {
    if (root.paletteMode) root.applyManualPalette(root.manualPaletteIndex)
    else if (root.lastRaw !== "") root.applyPalette(root.lastRaw)
  }

  // ─── CoOzey: intensidad de sus tonos en Automático ─────────────


  property int cozyWarm: 30
  function setCozyWarm(v) {
    const n = Math.max(0, Math.min(100, parseInt(v)))
    if (isNaN(n) || n === root.cozyWarm) return
    root.cozyWarm = n
    root.savePrefs()
  }
  onCozyWarmChanged: { if (root.cozy && !root.paletteMode) root.repaintPalette() }

  function cozyTune(p, dark) {
    const k = root.cozyWarm / 100
    if (k <= 0) return p
    const T = dark
      ? { bg: "#231A14", surface: "#2F241C", high: "#3B2E24", primary: "#F0B070",
          text: "#F6E9D6", sub: "#C7B199", pc: "#5C3D22", outline: "#8A7058" }
      : { bg: "#FBF3E4", surface: "#F3E7D0", high: "#E9D8B9", primary: "#A94B33",
          text: "#45301F", sub: "#6B5240", pc: "#F2CDB4", outline: "#B79C76" }
    const m = (a, b, t) => root.mix(a, b, Math.min(1, t))
    const bg   = m(p.bg, T.bg, 0.8 * k)
    const surf = m(p.surface, T.surface, 0.8 * k)
    const high = m(p.surfaceHigh, T.high, 0.8 * k)

    let primary = m(p.primary, T.primary, Math.max(0, k - 0.5))
    if (dark) primary = root.ensureContrast(primary, [bg], 3.0)
    else if (root.contrastOf(primary, bg) < 3.0) primary = m(primary, T.primary, 0.85)
    const text = m(p.text, T.text, 0.4 * k)
    const errc = root.ensureContrast(p.error, [bg, surf, high], 3.4)
    return {
      bg: bg, surface: surf, surfaceHigh: high,
      primary: primary,
      textOnPrimary: root.readableOn(primary, p.textOnPrimary),
      text: root.contrastOf(text, high) >= 4.5 ? text : p.text,
      subtext: m(p.subtext, T.sub, 0.4 * k),
      error: errc,
      textOnError: root.readableOn(errc, p.textOnError),
      primaryContainer: m(p.primaryContainer, T.pc, 0.6 * k),
      textOnPrimaryContainer: p.textOnPrimaryContainer,
      outline: m(p.outline, T.outline, 0.5 * k)
    }
  }


  readonly property var paletteOrder: {
    const cozyOwn = [], pastel = [], rest = []
    for (let i = 0; i < root.manualPalettes.length; i++) {
      const fam = root.manualPalettes[i].family
      if (fam === "cozy") {
        if (root.cozy || i === root.manualPaletteIndex) cozyOwn.push(i)
      } else if (fam === "pastel") pastel.push(i)
      else rest.push(i)
    }
    return root.cozy ? cozyOwn.concat(pastel, rest) : rest.concat(pastel, cozyOwn)
  }
  function paletteIndexByName(name) {
    for (let i = 0; i < root.manualPalettes.length; i++)
      if (root.manualPalettes[i].name === name) return i
    return -1
  }

  function enableCozy(dark) {
    const d = (dark === null || dark === undefined) ? root.bgIsDark : !!dark
    root.setUiStyle("cozy")
    const idx = root.paletteIndexByName(d ? "cocoa-night" : "parchment-day")
    if (idx >= 0) root.setManualPaletteIndex(idx)
    root.setPaletteMode(true)
  }

  function setPaletteByName(name) {
    const idx = root.paletteIndexByName(String(name))
    if (idx < 0) return false
    root.setManualPaletteIndex(idx)
    root.setPaletteMode(true)
    return true
  }

  // ─── Módulos plegables de la barra ─────────────────────────────


  property bool mprisCompact: false
  property bool taskbarCompact: false

  function setMprisCompact(on) {
    if (!!on === root.mprisCompact) return
    root.mprisCompact = !!on
    root.savePrefs()
  }

  function setTaskbarCompact(on) {
    if (!!on === root.taskbarCompact) return
    root.taskbarCompact = !!on
    root.savePrefs()
  }

  // ─── Dock (Ajustes → Interfaz) ──────────────────────────────────


  property bool dockEnabled: false

  function setDockEnabled(on) {
    if (!!on === root.dockEnabled) return
    root.dockEnabled = !!on
    root.savePrefs()
  }


  property string dockPosition: "bottom"


  property bool dockAutoHide: false

  // ─── Tamaño PROPIO de Píldora y Dock (Ajustes → Interfaz) ───────


  readonly property int ownScaleMin: 50
  readonly property int ownScaleMax: 150
  readonly property int pillScaleDefault: 100
  readonly property int dockScaleDefault: 80
  property int pillScalePercent: 100
  property int dockScalePercent: 80
  readonly property real pillScale: root.pillScalePercent / 100

  // ─── Tamaño del Dashboard (modo Píldora) ────────────────────────


  property int dashboardLevel: 0
  readonly property var dashScales: [1.0, 1.15, 1.3, 1.45, 1.6]
  readonly property real dashScale: root.dashScales[root.dashboardLevel] ?? 1.0
  readonly property real dashFontFollow: 0.75
  readonly property real dashGeomScale: root.dashScale * (1 + (root.fontScale - 1) * root.dashFontFollow)
  function ds(px)  { return Math.round(px * root.dashGeomScale) }
  function dfs(px) { return Math.max(6, Math.round(px * root.dashScale * root.fontScale)) }
  function setDashboardLevel(v) {
    const n = Math.max(0, Math.min(4, parseInt(v) || 0))
    if (n === root.dashboardLevel) return
    root.dashboardLevel = n
    root.savePrefs()
  }
  readonly property real dockScale: root.dockScalePercent / 100


  readonly property int pillEdgeGap: 4
  readonly property int dockEdgeGap: 4

  readonly property int pillHeight: Math.round(38 * root.pillScale)

  function clampOwnScale(v, fallback) {
    const n = parseInt(v)
    if (isNaN(n)) return fallback
    return Math.max(root.ownScaleMin, Math.min(root.ownScaleMax, n))
  }
  function setPillScalePercent(v) {
    const n = root.clampOwnScale(v, root.pillScalePercent)
    if (n === root.pillScalePercent) return
    root.pillScalePercent = n
    root.savePrefs()
  }
  function setDockScalePercent(v) {
    const n = root.clampOwnScale(v, root.dockScalePercent)
    if (n === root.dockScalePercent) return
    root.dockScalePercent = n
    root.savePrefs()
  }

  // ─── Ventana de Ajustes avanzados (tamaño propio) ───────────────

  readonly property int settingsWinMin: 80
  readonly property int settingsWinMax: 180
  readonly property int settingsWinDefault: 120
  property int settingsWinW: 120
  property int settingsWinH: 120
  function clampSettingsWin(v, fallback) {
    const n = parseInt(v)
    if (isNaN(n)) return fallback
    return Math.max(root.settingsWinMin, Math.min(root.settingsWinMax, n))
  }
  function setSettingsWinW(v) {
    const n = root.clampSettingsWin(v, root.settingsWinW)
    if (n === root.settingsWinW) return
    root.settingsWinW = n
    root.savePrefs()
  }
  function setSettingsWinH(v) {
    const n = root.clampSettingsWin(v, root.settingsWinH)
    if (n === root.settingsWinH) return
    root.settingsWinH = n
    root.savePrefs()
  }
  function resetSettingsWin() {
    root.settingsWinW = root.settingsWinDefault
    root.settingsWinH = root.settingsWinDefault
    root.savePrefs()
  }

  readonly property string dockEffectivePosition:
    root.barVertical ? root.dockPosition : (root.barPosition === "bottom" ? "top" : "bottom")

  function setDockPosition(pos) {
    const valid = ["top", "bottom"]
    const next = valid.indexOf(pos) >= 0 ? pos : "bottom"
    if (next === root.dockPosition) return
    root.rebuildBar()
    root.dockPosition = next
    root.savePrefs()
  }

  function setDockAutoHide(on) {
    if (!!on === root.dockAutoHide) return
    root.dockAutoHide = !!on
    root.savePrefs()
  }

  // ─── Indicador de batería (Ajustes → General → Barra) ──────────

  // (BatteryBackend.available === false) no se muestra aunque esté en ON.
  property bool batteryEnabled: true

  function setBatteryEnabled(on) {
    if (!!on === root.batteryEnabled) return
    root.batteryEnabled = !!on
    root.savePrefs()
  }

  // ─── Audio (Ajustes Avanzado → Audio) ──────────────────────────


  property bool audioMonitorsCardEnabled: true

  function setAudioMonitorsCardEnabled(on) {
    if (!!on === root.audioMonitorsCardEnabled) return
    root.audioMonitorsCardEnabled = !!on
    root.savePrefs()
  }

  // ─── Launcher y terminal (Ajustes → General) ───────────────────


  property bool effectsOn: true

  readonly property bool effectsActive: effectsOn && !performanceMode

  property bool launcherAttached: true


  property string launcherBackend: "quickshell"
  property string powermenuBackend: "quickshell"
  function setLauncherBackend(v) {
    const next = v === "rofi" ? "rofi" : "quickshell"
    if (next === root.launcherBackend) return
    root.launcherBackend = next
    root.savePrefs()
  }
  function setPowermenuBackend(v) {
    const next = v === "rofi" ? "rofi" : "quickshell"
    if (next === root.powermenuBackend) return
    root.powermenuBackend = next
    root.savePrefs()
  }


  property bool launcherShowImage: true

  property int launcherSize: 1


  property bool launcherParticlesEnabled: true


  property bool launcherWallpaperLiveEnabled: true


  property bool launcherCommandMode: true

  // ─── Pantalla de bloqueo (LOCK/LockScreen.qml) ─────────────────


  property string lockWallpaperMode: "auto"
  property string lockWallpaperPath: ""

  // ─── Carpetas del selector de wallpapers (WALLS/Walls.qml) ──────


  property string wallpaperDir: ""
  property string liveWallpaperDir: ""

  // ─── Wallpapers en línea y en vivo (Ajustes → Wallpapers) ───────


  property string onlineSource: "wallhaven"
  property string onlineQuery: ""
  property string onlineSorting: "toplist"
  property string onlineCategories: "110"
  property string onlineMinRes: "1920x1080"
  property string onlineApiKey: ""
  property string onlinePurity: "100"
  property string onlineSaveDir: ""
  property bool liveOptimize: true
  property bool liveOptSwap: true
  property int liveOptMaxHeight: 1080
  property int liveOptMaxFps: 30
  property bool liveStopWhenHidden: true
  property int liveRamLimitMB: 900
  property string liveLayer: "bottom"
  property string liveHwdec: "auto-safe"
  property string liveFit: "fill"


  property string wallFit: "crop"
  property string wallFillColor: "000000"


  property int wallSourceIndex: 0
  property int wallRev: 0

  property int liveOptRev: 0
  property int liveRunRev: 0


  readonly property var terminals: [
    { id: "foot",           name: "foot",           exec: ["foot", "-e"] },
    { id: "kitty",          name: "kitty",          exec: ["kitty"] },
    { id: "alacritty",      name: "Alacritty",      exec: ["alacritty", "-e"] },
    { id: "wezterm",        name: "WezTerm",        exec: ["wezterm", "start", "--"] },
    { id: "ghostty",        name: "Ghostty",        exec: ["ghostty", "-e"] },
    { id: "konsole",        name: "Konsole",        exec: ["konsole", "-e"] },
    { id: "gnome-terminal", name: "GNOME Terminal", exec: ["gnome-terminal", "--"] },
    { id: "xfce4-terminal", name: "Xfce Terminal",  exec: ["xfce4-terminal", "-x"] },
    { id: "xterm",          name: "xterm",          exec: ["xterm", "-e"] }
  ]
  property string terminalId: "foot"


  readonly property var terminalCmd: {
    const t = root.terminals.find(x => x.id === root.terminalId)
    return t ? t.exec : [root.terminalId, "-e"]
  }


  property var installedTerminals: []

  Process {
    id: detectTermProc
    property string buffer: ""
    command: ["sh", "-c",
      'for t in "$@"; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done',
      "sh"].concat(root.terminals.map(t => t.exec[0]))
    running: true
    stdout: SplitParser { onRead: line => detectTermProc.buffer += line + "\n" }
    onRunningChanged: {
      if (running) return
      const bins = detectTermProc.buffer.split("\n").filter(l => l !== "")
      detectTermProc.buffer = ""

      root.installedTerminals = root.terminals
        .filter(t => bins.indexOf(t.exec[0]) >= 0)
        .map(t => t.id)
    }
  }

  function setPerformanceMode(on) {
    if (!!on === root.performanceMode) return
    root.performanceMode = !!on
    root.savePrefs()
    root.performanceToggled(root.performanceMode)
  }

  function setEffects(on) {
    if (!!on === root.effectsOn) return
    root.effectsOn = !!on
    root.savePrefs()
  }

  function setLauncherAttached(on) {
    if (!!on === root.launcherAttached) return
    root.launcherAttached = !!on
    root.savePrefs()
  }

  function setLauncherShowImage(on) {
    if (!!on === root.launcherShowImage) return
    root.launcherShowImage = !!on
    root.savePrefs()
  }

  function setLauncherSize(n) {
    const v = Math.max(0, Math.min(2, parseInt(n)))
    if (isNaN(v) || v === root.launcherSize) return
    root.launcherSize = v
    root.savePrefs()
  }

  function setLauncherParticlesEnabled(on) {
    if (!!on === root.launcherParticlesEnabled) return
    root.launcherParticlesEnabled = !!on
    root.savePrefs()
  }

  function setLauncherWallpaperLiveEnabled(on) {
    if (!!on === root.launcherWallpaperLiveEnabled) return
    root.launcherWallpaperLiveEnabled = !!on
    root.savePrefs()
  }

  function setLauncherCommandMode(on) {
    if (!!on === root.launcherCommandMode) return
    root.launcherCommandMode = !!on
    root.savePrefs()
  }

  function setLockWallpaperMode(mode) {
    const m = mode === "custom" ? "custom" : "auto"
    if (m === root.lockWallpaperMode) return
    root.lockWallpaperMode = m
    root.savePrefs()
  }

  function setLockWallpaperPath(path) {
    const v = String(path ?? "").trim()
    if (v === root.lockWallpaperPath) return
    root.lockWallpaperPath = v
    root.savePrefs()
  }


  function cleanDirPref(path) {
    let v = String(path ?? "").trim()
    if (v.indexOf("file://") === 0) { try { v = decodeURIComponent(v.slice(7)) } catch (e) { v = v.slice(7) } }
    while (v.length > 1 && v.charAt(v.length - 1) === "/") v = v.slice(0, -1)
    return v
  }

  function setWallpaperDir(path) {
    const v = root.cleanDirPref(path)
    if (v === root.wallpaperDir) return
    root.wallpaperDir = v
    root.savePrefs()
  }

  function setLiveWallpaperDir(path) {
    const v = root.cleanDirPref(path)
    if (v === root.liveWallpaperDir) return
    root.liveWallpaperDir = v
    root.savePrefs()
  }

  function wallsPrefs() {
    return {
      onlineSource: root.onlineSource, onlineQuery: root.onlineQuery,
      onlineSorting: root.onlineSorting, onlineCategories: root.onlineCategories,
      onlineMinRes: root.onlineMinRes, onlineApiKey: root.onlineApiKey, onlinePurity: root.onlinePurity,
      onlineSaveDir: root.onlineSaveDir,
      liveOptimize: root.liveOptimize, liveOptSwap: root.liveOptSwap,
      liveOptMaxHeight: root.liveOptMaxHeight, liveOptMaxFps: root.liveOptMaxFps,
      liveStopWhenHidden: root.liveStopWhenHidden, liveRamLimitMB: root.liveRamLimitMB,
      liveLayer: root.liveLayer, liveHwdec: root.liveHwdec, liveFit: root.liveFit,
      wallFit: root.wallFit, wallFillColor: root.wallFillColor,
      wallSourceIndex: root.wallSourceIndex
    }
  }


  function cleanWallsOpt(name, value) {
    const ni = (x, d, lo, hi) => { const n = parseInt(x); return isNaN(n) ? d : Math.max(lo, Math.min(hi, n)) }
    const oneOf = (list) => list.indexOf(value) >= 0 ? value : undefined
    switch (name) {
      case "onlineSource":     return oneOf(["wallhaven", "bing"])
      case "onlineQuery":      return String(value ?? "").trim().slice(0, 80)
      case "onlineSorting":    return oneOf(["toplist", "hot", "random", "date_added", "views", "relevance"])
      case "onlineCategories": return (/^[01]{3}$/.test(String(value)) && String(value) !== "000") ? String(value) : undefined
      case "onlineMinRes":     return /^\d{3,5}x\d{3,5}$/.test(String(value)) ? String(value) : undefined
      case "onlinePurity":     return (/^[01]{3}$/.test(String(value)) && String(value) !== "000") ? String(value) : undefined
      case "onlineApiKey":     return String(value ?? "").replace(/[^A-Za-z0-9]/g, "").slice(0, 64)
      case "onlineSaveDir":    return root.cleanDirPref(value)
      case "liveOptimize":
      case "liveOptSwap":
      case "liveStopWhenHidden": return !!value
      case "liveOptMaxHeight": return ni(value, 1080, 360, 2160)
      case "liveOptMaxFps":    return ni(value, 30, 10, 60)
      case "liveRamLimitMB":   return ni(value, 900, 0, 8192)
      case "liveLayer":        return oneOf(["bottom", "background"])
      case "liveHwdec":        return oneOf(["auto-safe", "vaapi", "nvdec", "no"])
      case "liveFit":          return oneOf(["fill", "fit"])
      case "wallFit":          return oneOf(["crop", "fit", "stretch", "no"])
      case "wallSourceIndex":  return ni(value, 0, 0, 9)
      case "wallFillColor": {
        const c = String(value ?? "").trim().replace(/^#/, "").toUpperCase()
        return /^[0-9A-F]{6}$/.test(c) ? c : undefined
      }
    }
    return undefined
  }

  function loadWallsPrefs(w) {
    if (!w || typeof w !== "object") return
    const names = ["onlineSource", "onlineQuery", "onlineSorting", "onlineCategories", "onlineMinRes",
                   "onlineApiKey", "onlinePurity", "onlineSaveDir", "liveOptimize", "liveOptSwap", "liveOptMaxHeight",
                   "liveOptMaxFps", "liveStopWhenHidden", "liveRamLimitMB", "liveLayer", "liveHwdec", "liveFit", "wallFit", "wallFillColor", "wallSourceIndex"]
    for (const n of names) {
      if (!(n in w)) continue
      const v = root.cleanWallsOpt(n, w[n])
      if (v !== undefined) root[n] = v
    }
  }

  function setWallsOpt(name, value) {
    const v = root.cleanWallsOpt(name, value)
    if (v === undefined || root[name] === v) return
    root[name] = v
    if (name === "liveOptimize" || name === "liveOptMaxHeight" || name === "liveOptMaxFps") root.liveOptRev++
    else if (name.indexOf("live") === 0) root.liveRunRev++
    else if (name === "wallFit" || name === "wallFillColor") root.wallRev++
    root.savePrefs()
  }

  function setTerminal(id) {
    if (typeof id !== "string" || id === "" || id === root.terminalId) return
    root.terminalId = id
    root.savePrefs()
  }

  // ─── Paleta de matugen preferida (Ajustes → Configuración avanzada) ──


  readonly property var schemes: [
    { name: "vibrant",     label: "vibrant"  },
    { name: "tonal-spot",  label: "tonal"    },
    { name: "neutral",     label: "neutral"  },
    { name: "fruit-salad", label: "fruit"    },
    { name: "rainbow",     label: "rainbow"  },
    { name: "fidelity",    label: "fidelity" },
    { name: "content",     label: "content"  },
    { name: "monochrome",  label: "mono"     }
  ]
  property int defaultSchemeIndex: 0

  function setDefaultSchemeIndex(idx) {
    const n = Math.max(0, Math.min(root.schemes.length - 1, parseInt(idx) || 0))
    if (n === root.defaultSchemeIndex) return
    root.defaultSchemeIndex = n
    root.savePrefs()
  }

  // ─── Modo Paletas (Ajustes → Configuración avanzada → Apariencia) ────


  readonly property var manualPalettes: [
    { name: "nord", label: "Nord",
      bg: "#2e3440", surface: "#3b4252", surfaceHigh: "#434c5e",
      primary: "#88c0d0", textOnPrimary: "#2e3440",
      text: "#eceff4", subtext: "#d8dee9",
      error: "#bf616a", textOnError: "#2e3440",
      primaryContainer: "#4c566a", textOnPrimaryContainer: "#eceff4",
      outline: "#81a1c1",
      tertiary: "#a3be8c" },
    { name: "dracula", label: "Dracula",
      bg: "#282a36", surface: "#343746", surfaceHigh: "#44475a",
      primary: "#bd93f9", textOnPrimary: "#282a36",
      text: "#f8f8f2", subtext: "#6272a4",
      error: "#ff5555", textOnError: "#282a36",
      primaryContainer: "#6272a4", textOnPrimaryContainer: "#f8f8f2",
      outline: "#ff79c6",
      tertiary: "#50fa7b" },
    { name: "gruvbox", label: "Gruvbox",
      bg: "#282828", surface: "#3c3836", surfaceHigh: "#504945",
      primary: "#d79921", textOnPrimary: "#282828",
      text: "#ebdbb2", subtext: "#a89984",
      error: "#cc241d", textOnError: "#ebdbb2",
      primaryContainer: "#7c6f64", textOnPrimaryContainer: "#ebdbb2",
      outline: "#b8bb26",
      tertiary: "#83a598" },
    { name: "catppuccin", label: "Catppuccin",
      bg: "#1e1e2e", surface: "#313244", surfaceHigh: "#45475a",
      primary: "#cba6f7", textOnPrimary: "#1e1e2e",
      text: "#cdd6f4", subtext: "#a6adc8",
      error: "#f38ba8", textOnError: "#1e1e2e",
      primaryContainer: "#585b70", textOnPrimaryContainer: "#cdd6f4",
      outline: "#89b4fa",
      tertiary: "#a6e3a1" },
    { name: "solarized", label: "Solarized",
      bg: "#002b36", surface: "#073642", surfaceHigh: "#0a4552",
      primary: "#268bd2", textOnPrimary: "#002b36",
      text: "#eee8d5", subtext: "#93a1a1",
      error: "#dc322f", textOnError: "#eee8d5",
      primaryContainer: "#2aa198", textOnPrimaryContainer: "#002b36",
      outline: "#586e75",
      tertiary: "#859900" },
    { name: "tokyo-night", label: "Tokyo Night",
      bg: "#1a1b26", surface: "#24283b", surfaceHigh: "#2f3549",
      primary: "#7aa2f7", textOnPrimary: "#1a1b26",
      text: "#c0caf5", subtext: "#565f89",
      error: "#f7768e", textOnError: "#1a1b26",
      primaryContainer: "#3d59a1", textOnPrimaryContainer: "#c0caf5",
      outline: "#bb9af7",
      tertiary: "#9ece6a" },
    { name: "rose-pine", label: "Rosé Pine",
      bg: "#191724", surface: "#1f1d2e", surfaceHigh: "#26233a",
      primary: "#c4a7e7", textOnPrimary: "#191724",
      text: "#e0def4", subtext: "#908caa",
      error: "#eb6f92", textOnError: "#191724",
      primaryContainer: "#31748f", textOnPrimaryContainer: "#e0def4",
      outline: "#9ccfd8",
      tertiary: "#f6c177" },
    { name: "gruvbox-material", label: "Gruvbox Material",
      bg: "#282828", surface: "#32302f", surfaceHigh: "#3c3836",
      primary: "#d8a657", textOnPrimary: "#1d2021",
      text: "#d4be98", subtext: "#928374",
      error: "#ea6962", textOnError: "#1d2021",
      primaryContainer: "#504945", textOnPrimaryContainer: "#d4be98",
      outline: "#a9b665",
      tertiary: "#7daea3" },
    { name: "neon-punk", label: "Neon Punk",
      bg: "#050209", surface: "#120a1f", surfaceHigh: "#1e1233",
      primary: "#ff007f", textOnPrimary: "#ffffff",
      text: "#ffffff", subtext: "#a78bca",
      error: "#ff003c", textOnError: "#ffffff",
      primaryContainer: "#3a0f5c", textOnPrimaryContainer: "#e9c7ff",
      outline: "#00fcfc",
      tertiary: "#fcee0a" },
    { name: "pastel-dream", label: "Pastel Dream",
      bg: "#2e2a3d", surface: "#3b354d", surfaceHigh: "#463f5a",
      primary: "#ffb3c6", textOnPrimary: "#2e2a3d",
      text: "#ffffff", subtext: "#c9c2dd",
      error: "#ff5c8a", textOnError: "#2e2a3d",
      primaryContainer: "#5d5280", textOnPrimaryContainer: "#ffffff",
      outline: "#94e2d5",
      tertiary: "#94e2d5" },
    { name: "retro-terminal", label: "Retro Terminal",
      bg: "#0a0f0a", surface: "#111a11", surfaceHigh: "#1a2a1a",
      primary: "#33ff33", textOnPrimary: "#0a0f0a",
      text: "#a0e8a0", subtext: "#009900",
      error: "#ff3333", textOnError: "#0a0f0a",
      primaryContainer: "#009900", textOnPrimaryContainer: "#0a0f0a",
      outline: "#00cc00",
      tertiary: "#ffb000" },
    { name: "scarlett", label: "Scarlett",
      bg: "#0d0305", surface: "#1e0a0d", surfaceHigh: "#2a0f13",
      primary: "#cc1a2a", textOnPrimary: "#ffffff",
      text: "#e8c4c4", subtext: "#a87878",
      error: "#ff6b35", textOnError: "#0d0305",
      primaryContainer: "#8b0015", textOnPrimaryContainer: "#e8c4c4",
      outline: "#ff2d3f",
      tertiary: "#d4a373" },
    { name: "void-minimal", label: "Void Minimal",
      bg: "#050505", surface: "#111111", surfaceHigh: "#1c1c1c",
      primary: "#ffffff", textOnPrimary: "#050505",
      text: "#e6e6e6", subtext: "#888888",
      error: "#cf6a4c", textOnError: "#050505",
      primaryContainer: "#333333", textOnPrimaryContainer: "#ffffff",
      outline: "#7587a6",
      tertiary: "#8fa6c7" },
    { name: "manga", label: "Manga",
      bg: "#f0ece4", surface: "#e8e3d8", surfaceHigh: "#d4cfc4",
      primary: "#1a1714", textOnPrimary: "#f0ece4",
      text: "#1a1714", subtext: "#6e6860",
      error: "#cc2222", textOnError: "#f0ece4",
      primaryContainer: "#2d2926", textOnPrimaryContainer: "#f0ece4",
      outline: "#4a4540",
      tertiary: "#8a8478" },

    // ─── Paletas pastel (family: "pastel"; antes Mewberry Dreamscape) ─────


    { name: "strawberry-milk", label: "Strawberry Milk", family: "pastel",
      bg: "#FFF7FB", surface: "#F9EAF2", surfaceHigh: "#F3D9E6",
      primary: "#C23A82", textOnPrimary: "#FFF7FB",
      text: "#493342", subtext: "#725668",
      error: "#C62F3F", textOnError: "#FFF7FB",
      primaryContainer: "#F4C9DD", textOnPrimaryContainer: "#5E1740",
      outline: "#C79BB4",
      tertiary: "#A995E8" },
    { name: "berry-night", label: "Berry Night", family: "pastel",
      bg: "#211722", surface: "#302032", surfaceHigh: "#3B283D",
      primary: "#F2A4CE", textOnPrimary: "#3A1730",
      text: "#FFF0F7", subtext: "#CDB8C9",
      error: "#FF7B7B", textOnError: "#2A0F12",
      primaryContainer: "#5A2F52", textOnPrimaryContainer: "#FFD9EC",
      outline: "#8A6485",
      tertiary: "#C9B7FF" },
    { name: "sakura-soda", label: "Sakura Soda", family: "pastel",
      bg: "#F4FAFE", surface: "#E6F1FA", surfaceHigh: "#D5E8F6",
      primary: "#C8447F", textOnPrimary: "#FFFFFF",
      text: "#33415C", subtext: "#52617D",
      error: "#C62F3F", textOnError: "#FFFFFF",
      primaryContainer: "#F8CBE0", textOnPrimaryContainer: "#5E1740",
      outline: "#8FB5D6",
      tertiary: "#7DBFE8" },
    { name: "black-cherry-ribbon", label: "Black Cherry Ribbon", family: "pastel",
      bg: "#1A0E15", surface: "#2A1621", surfaceHigh: "#3A1E2D",
      primary: "#FF6AA8", textOnPrimary: "#2A0A18",
      text: "#FFE6EF", subtext: "#D2A6BA",
      error: "#FF8A5C", textOnError: "#2A0F0A",
      primaryContainer: "#7A1F4A", textOnPrimaryContainer: "#FFD6E7",
      outline: "#8A405F",
      tertiary: "#C9A7FF" },
    { name: "matcha-macaron", label: "Matcha Macaron", family: "pastel",
      bg: "#F3FCF7", surface: "#E3F4EB", surfaceHigh: "#D0EBDD",
      primary: "#C23A82", textOnPrimary: "#FFF7FB",
      text: "#2E4A3F", subtext: "#4A675A",
      error: "#C62F3F", textOnError: "#FFFFFF",
      primaryContainer: "#F6C9DE", textOnPrimaryContainer: "#5E1740",
      outline: "#8DBBA3",
      tertiary: "#7CCBA9" },

    // ─── CoOzey (family: "cozy") ─────────────────────────────────────────


    { name: "parchment-day", label: "Parchment Day", family: "cozy",
      bg: "#FBF3E4", surface: "#F3E7D0", surfaceHigh: "#E9D8B9",
      primary: "#A94B33", textOnPrimary: "#FFF8EC",
      text: "#45301F", subtext: "#6B5240",
      error: "#B3302F", textOnError: "#FFF8EC",
      primaryContainer: "#F2CDB4", textOnPrimaryContainer: "#55200F",
      outline: "#B79C76",
      tertiary: "#6F8F4E" },
    { name: "meadow-morning", label: "Meadow Morning", family: "cozy",
      bg: "#F4F7E8", surface: "#E9EFD4", surfaceHigh: "#DAE4BC",
      primary: "#46712F", textOnPrimary: "#F7FBEA",
      text: "#2C3822", subtext: "#4F5F3F",
      error: "#B3302F", textOnError: "#FFF8EC",
      primaryContainer: "#CFE3B0", textOnPrimaryContainer: "#203512",
      outline: "#9DB07E",
      tertiary: "#B9803F" },
    { name: "cocoa-night", label: "Cocoa Night", family: "cozy",
      bg: "#231A14", surface: "#2F241C", surfaceHigh: "#3B2E24",
      primary: "#F0B070", textOnPrimary: "#3A2108",
      text: "#F6E9D6", subtext: "#C7B199",
      error: "#FF8A7A", textOnError: "#3A0E08",
      primaryContainer: "#5C3D22", textOnPrimaryContainer: "#FFDDB8",
      outline: "#8A7058",
      tertiary: "#A8C98B" },
    { name: "moss-lantern", label: "Moss & Lantern", family: "cozy",
      bg: "#1B221A", surface: "#252E22", surfaceHigh: "#2F3A2B",
      primary: "#E8C56A", textOnPrimary: "#33270A",
      text: "#EDF1DD", subtext: "#B5C1A0",
      error: "#FF8F7E", textOnError: "#3A0E08",
      primaryContainer: "#4D4220", textOnPrimaryContainer: "#FBE6A6",
      outline: "#6F8260",
      tertiary: "#9CC9A8" },
    { name: "pumpkin-dusk", label: "Pumpkin Dusk", family: "cozy",
      bg: "#2A1C18", surface: "#382620", surfaceHigh: "#45302A",
      primary: "#FF9B54", textOnPrimary: "#351400",
      text: "#FBE8DA", subtext: "#D1B4A3",
      error: "#FF8C86", textOnError: "#3A0E08",
      primaryContainer: "#6B3318", textOnPrimaryContainer: "#FFD9BF",
      outline: "#94705F",
      tertiary: "#E7B96A" }
  ]


  property bool paletteMode: false
  property int manualPaletteIndex: 0


  property bool paletteSystemSync: true


  function applyManualPalette(idx) {
    const n = Math.max(0, Math.min(root.manualPalettes.length - 1, parseInt(idx) || 0))
    const p = root.manualPalettes[n]
    root.bg                     = p.bg
    root.surfaceBase            = p.surface
    root.surfaceHighBase        = p.surfaceHigh
    root.primary                = p.primary
    root.textOnPrimary          = p.textOnPrimary
    root.text                   = p.text
    root.subtext                = p.subtext
    root.error                  = p.error
    root.textOnError            = p.textOnError
    root.primaryContainer       = p.primaryContainer
    root.textOnPrimaryContainer = p.textOnPrimaryContainer
    root.outline                = p.outline
    root.queuePaletteSync()
  }

  function setManualPaletteIndex(idx) {
    const n = Math.max(0, Math.min(root.manualPalettes.length - 1, parseInt(idx) || 0))
    if (n === root.manualPaletteIndex) return
    root.manualPaletteIndex = n
    if (root.paletteMode) root.applyManualPalette(n)
    root.savePrefs()
  }


  function setPaletteMode(on) {
    const v = !!on
    if (v === root.paletteMode) return
    root.paletteMode = v
    if (v) root.applyManualPalette(root.manualPaletteIndex)
    else if (root.lastRaw !== "") root.applyPalette(root.lastRaw)
    root.savePrefs()
  }

  // ─── Paleta fija → resto del sistema (tools/palette-apply.py) ────────
  readonly property string paletteApplyScript:
    decodeURIComponent(Qt.resolvedUrl("../tools/palette-apply.py").toString().replace("file://", ""))
  property bool paletteSyncAgain: false

  function setPaletteSystemSync(on) {
    const v = !!on
    if (v === root.paletteSystemSync) return
    root.paletteSystemSync = v
    if (v) root.queuePaletteSync()
    root.savePrefs()
  }


  function queuePaletteSync() {
    if (!root.paletteMode || !root.paletteSystemSync) return
    paletteSyncTimer.restart()
  }

  function runPaletteSync() {
    if (!root.paletteMode || !root.paletteSystemSync) return
    if (paletteSyncProc.running) { root.paletteSyncAgain = true; return }
    const n = Math.max(0, Math.min(root.manualPalettes.length - 1, root.manualPaletteIndex))
    paletteSyncProc.command = ["python3", root.paletteApplyScript,
                               JSON.stringify(root.manualPalettes[n])]
    paletteSyncProc.running = true
  }

  Timer {
    id: paletteSyncTimer
    interval: 400; repeat: false; running: false
    onTriggered: root.runPaletteSync()
  }

  Process {
    id: paletteSyncProc
    running: false
    stdout: SplitParser { onRead: line => console.log(line) }
    stderr: SplitParser { onRead: line => console.log("[palette]", line) }
    onRunningChanged: {
      if (running || !root.paletteSyncAgain) return
      root.paletteSyncAgain = false
      Qt.callLater(() => root.runPaletteSync())
    }
  }

  // ─── Apariencia del Dock (Ajustes → Configuración avanzada → Interfaz) ──


  readonly property int dockOpacityDefault: 100
  readonly property int dockBlurDefault: 0
  readonly property int dockFloatGap: 8
  property string dockMode: "panel"
  property int dockOpacity: 100
  property int dockBlur: 0
  readonly property bool dockFloating: root.dockMode === "pill"

  readonly property color dockBg: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, root.dockOpacity / 100)

  function clampPercent(v, fallback) {
    const n = parseInt(v)
    if (isNaN(n)) return fallback
    return Math.max(0, Math.min(100, n))
  }
  function setDockMode(m) {
    const v = (m === "pill") ? "pill" : "panel"
    if (v === root.dockMode) return
    root.dockMode = v
    root.savePrefs()
  }
  function setDockOpacity(v) {
    const n = root.clampPercent(v, root.dockOpacity)
    if (n === root.dockOpacity) return
    root.dockOpacity = n
    root.savePrefs()
  }
  function setDockBlur(v) {
    const n = root.clampPercent(v, root.dockBlur)
    if (n === root.dockBlur) return
    root.dockBlur = n
    root.savePrefs()
  }

  // ─── Modo Cristal (Ajustes → Barra) ─────────────────────────────


  readonly property int glassOpacityDefault: 70
  property bool glassModePref: false
  property int glassOpacity: 70
  property bool glassBlurPref: true


  readonly property int glassSeamDefault: 8
  property int glassSeamInset: 8


  readonly property bool glassAllowed: root.uiStyle === "soft" && !root.pillMode
  readonly property bool glassMode: root.glassModePref && root.glassAllowed
  readonly property bool glassBlurOn: root.glassMode && root.glassBlurPref && !root.performanceMode
  readonly property color glassBg: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, root.glassOpacity / 100)
  // ── Controles "iOS" ──────────────────────────────────────────────


  // ── Popups flotantes en Modo Cristal ─────────────────────────────


  readonly property bool glassFloat: root.glassMode && !root.islandsMode && !root.pillMode
  readonly property int glassPanelGap: 6
  readonly property bool glassCtl: root.glassMode
  readonly property real glassCtlAlpha:   root.glassOpacity / 100 + (1 - root.glassOpacity / 100) * 0.45
  readonly property real glassCtlHiAlpha: root.glassOpacity / 100 + (1 - root.glassOpacity / 100) * 0.65

  readonly property color glassCtlBg: root.glassCtl ? root.withAlpha(root.bg, root.glassCtlAlpha) : root.bg

  readonly property color glassEdge:  Qt.rgba(1, 1, 1, root.bgIsDark ? 0.16 : 0.55)
  function withAlpha(c, a) {
    const x = (typeof c === "string") ? Qt.color(c) : c
    return Qt.rgba(x.r, x.g, x.b, Math.max(0, Math.min(1, a)))
  }

  readonly property color panelBg: root.glassMode ? root.glassBg : root.bg


  readonly property color islandBg: !root.glassMode ? root.bg
                                   : (root.islandsMode ? root.glassBg : "transparent")

  function setGlassMode(on) {
    if (!!on === root.glassModePref) return

    root.rebuildBar()
    root.glassModePref = !!on
    root.savePrefs()
  }
  function setGlassOpacity(v) {
    const n = Math.max(10, root.clampPercent(v, root.glassOpacity))
    if (n === root.glassOpacity) return
    root.glassOpacity = n
    root.savePrefs()
  }
  function setGlassSeamInset(v) {
    const n = Math.max(0, Math.min(24, parseInt(v)))
    if (isNaN(n) || n === root.glassSeamInset) return
    root.glassSeamInset = n
    root.savePrefs()
  }
  function setGlassBlur(on) {
    if (!!on === root.glassBlurPref) return
    root.glassBlurPref = !!on
    root.savePrefs()
  }

  // ─── Persistencia de los niveles de UI ─────────────────────────
  readonly property string prefsDir: Quickshell.env("HOME") + "/.config/oozeshell"
  readonly property string prefsFile: prefsDir + "/ui.json"

  function clampLevel(v) {
    const n = parseInt(v)
    return isNaN(n) ? 2 : Math.max(0, Math.min(4, n))
  }

  function savePrefs() {
    savePrefsProc.json = JSON.stringify({
      fontLevel: root.fontLevel, fontPercent: root.fontPercent, barLevel: root.barLevel, windowLevel: root.windowLevel,
      uiAnimationMode: root.uiAnimationMode,
      performance: root.performanceMode,
      barPosition: root.barPosition, barFloating: root.barFloatingPref,
      islands: root.islandsPref,
      barBackend: root.barBackend,
      pillMode: root.pillModePref, pillAutoHide: root.pillAutoHidePref,
      pillTraySync: root.pillTraySyncPref,
      lightMode: root.lightMode, themeMode: root.themeMode, colorfulDepth: root.colorfulDepth, uiStyle: root.uiStyle, pixelFont: root.pixelFontPref, softFont: root.softFontPref,
      cozyWarm: root.cozyWarm,
      launcherAttached: root.launcherAttached, terminal: root.terminalId,
      launcherBackend: root.launcherBackend, powermenuBackend: root.powermenuBackend,
      launcherImage: root.launcherShowImage, launcherSize: root.launcherSize,
      launcherParticles: root.launcherParticlesEnabled,
      launcherWallpaperLive: root.launcherWallpaperLiveEnabled,
      launcherCommandMode: root.launcherCommandMode,
      lockWallpaper: root.lockWallpaperMode, lockWallpaperPath: root.lockWallpaperPath,
      wallpaperDir: root.wallpaperDir, liveWallpaperDir: root.liveWallpaperDir,
      walls: root.wallsPrefs(),
      effects: root.effectsOn,
      mprisCompact: root.mprisCompact, taskbarCompact: root.taskbarCompact,
      dockEnabled: root.dockEnabled, batteryEnabled: root.batteryEnabled,
      dockPosition: root.dockPosition, dockAutoHide: root.dockAutoHide,
      pillScale: root.pillScalePercent, dockScale: root.dockScalePercent,
      settingsWinW: root.settingsWinW, settingsWinH: root.settingsWinH,
      dashboardLevel: root.dashboardLevel,
      defaultSchemeIndex: root.defaultSchemeIndex,
      dockMode: root.dockMode, dockOpacity: root.dockOpacity, dockBlur: root.dockBlur,
      glassMode: root.glassModePref, glassOpacity: root.glassOpacity, glassBlur: root.glassBlurPref,
      glassSeam: root.glassSeamInset,
      audioMonitorsCardEnabled: root.audioMonitorsCardEnabled,
      paletteMode: root.paletteMode, manualPaletteIndex: root.manualPaletteIndex,
      paletteSystemSync: root.paletteSystemSync,
      frameStyle: root.frameStyle, frameCurveRadius: root.frameCurveRadius,
      frameThickness: root.frameThickness, frameFuse: root.frameFuse
    })


    if (savePrefsProc.running) root.saveAgain = true
    else savePrefsProc.running = true
  }
  property bool saveAgain: false


  function setLevel(kind, v) {
    const n = root.clampLevel(v)
    if (kind === "font") { root.fontLevel = n; root.fontPercent = 0 }
    else if (kind === "bar") root.barLevel = n
    else if (kind === "window") root.windowLevel = n
    else return
    root.savePrefs()
  }


  function setInterfaceLevel(v) {
    const n = root.clampLevel(v)
    root.barLevel = n
    root.windowLevel = n
    root.savePrefs()
  }


  property bool barRebuilding: false

  Timer {
    id: rebuildTimer
    interval: 180
    repeat: false
    onTriggered: {
      root.barRebuilding = false


      Qt.callLater(function() { IslandState.refreshRequested() })
    }
  }

  function rebuildBar() {
    root.barRebuilding = true
    rebuildTimer.restart()
  }


  property bool wallpaperChanging: false

  function setBarPosition(pos) {
    const valid = ["top", "bottom", "left", "right"]
    const next = valid.indexOf(pos) >= 0 ? pos : "top"
    if (next === root.barPosition) return
    root.rebuildBar()
    root.barPosition = next
    root.savePrefs()
  }

  function setIslandsEnabled(on) {
    if (!!on === root.islandsPref) return
    root.rebuildBar()
    root.islandsPref = !!on

    if (on && root.pillModePref) root.pillModePref = false
    root.savePrefs()
  }

  function setPillModeEnabled(on) {
    if (!!on === root.pillModePref) return
    root.rebuildBar()
    root.pillModePref = !!on

    if (on && root.islandsPref) root.islandsPref = false
    if (!on) AppState.closeDashboard()
    root.savePrefs()
  }

  function setPillAutoHide(on) {
    if (!!on === root.pillAutoHidePref) return
    root.pillAutoHidePref = !!on
    AppState.pillAutoHide = root.pillAutoHidePref
    root.savePrefs()
  }

  function setPillTraySync(on) {
    if (!!on === root.pillTraySyncPref) return
    root.pillTraySyncPref = !!on
    AppState.pillTraySync = root.pillTraySyncPref
    root.savePrefs()
  }

  function setBarFloating(on) {
    if (!!on === root.barFloatingPref) return
    root.rebuildBar()
    root.barFloatingPref = !!on
    root.savePrefs()
  }

  function resetLevels() {
    root.fontPercent = 0
    root.fontLevel = 2
    root.barLevel = 2
    root.windowLevel = 2
    root.savePrefs()
  }

  Process {
    id: loadPrefsProc
    command: ["bash", "-c", "cat '" + root.prefsFile + "' 2>/dev/null"]
    running: true
    property string buffer: ""
    stdout: SplitParser { onRead: line => loadPrefsProc.buffer += line }
    onRunningChanged: {
      if (running) return
      const raw = loadPrefsProc.buffer.trim()
      loadPrefsProc.buffer = ""
      if (raw === "") return
      try {
        const j = JSON.parse(raw)
        root.fontLevel   = root.clampLevel(j.fontLevel ?? 2)
        root.fontPercent = (j.fontPercent ?? 0) > 0 ? root.clampFontPercent(j.fontPercent) : 0
        root.barLevel    = root.clampLevel(j.barLevel ?? 2)
        root.windowLevel = root.clampLevel(j.windowLevel ?? 2)
        root.uiAnimationMode = ["normal", "minimal", "off"].indexOf(j.uiAnimationMode) >= 0 ? j.uiAnimationMode : "normal"
        root.performanceMode = j.performance === true
        root.barPosition = ["top", "bottom", "left", "right"].indexOf(j.barPosition) >= 0
                           ? j.barPosition : "top"
        root.barFloatingPref = j.barFloating === true
        root.islandsPref = j.islands === true
        root.barBackend = j.barBackend === "waybar" ? "waybar" : "ooze"
        root.pillModePref = j.pillMode === true
        root.pillAutoHidePref = j.pillAutoHide === true
        root.pillTraySyncPref = j.pillTraySync === true
        AppState.pillAutoHide = root.pillAutoHidePref
        AppState.pillTraySync = root.pillTraySyncPref

        root.uiStyle = j.uiStyle === "cozy" ? "cozy" : "soft"
        root.cozyWarm = Math.max(0, Math.min(100, parseInt(j.cozyWarm ?? 30) || 0))
        root.pixelFontPref = typeof j.pixelFont === "string" ? j.pixelFont : ""
        root.softFontPref = typeof j.softFont === "string" ? j.softFont : ""
        root.themeMode = ["dark", "light", "colorful"].indexOf(j.themeMode) >= 0
          ? j.themeMode : (j.lightMode === true ? "light" : "dark")
        root.colorfulDepth = Math.max(0, Math.min(100, parseInt(j.colorfulDepth ?? 50) || 0))
        root.launcherAttached = j.launcherAttached !== false
        root.launcherBackend = j.launcherBackend === "rofi" ? "rofi" : "quickshell"
        root.powermenuBackend = j.powermenuBackend === "rofi" ? "rofi" : "quickshell"
        root.effectsOn = j.effects !== false
        root.mprisCompact = j.mprisCompact === true
        root.taskbarCompact = j.taskbarCompact === true
        root.launcherShowImage = j.launcherImage !== false
        root.launcherSize = Math.max(0, Math.min(2, parseInt(j.launcherSize ?? 1) || 0))
        root.launcherParticlesEnabled = j.launcherParticles !== false
        root.launcherWallpaperLiveEnabled = j.launcherWallpaperLive !== false
        root.launcherCommandMode = j.launcherCommandMode !== false
        root.lockWallpaperMode = j.lockWallpaper === "custom" ? "custom" : "auto"
        root.lockWallpaperPath = typeof j.lockWallpaperPath === "string" ? j.lockWallpaperPath : ""
        root.wallpaperDir = typeof j.wallpaperDir === "string" ? root.cleanDirPref(j.wallpaperDir) : ""
        root.liveWallpaperDir = typeof j.liveWallpaperDir === "string" ? root.cleanDirPref(j.liveWallpaperDir) : ""
        root.loadWallsPrefs(j.walls)
        root.terminalId = (typeof j.terminal === "string" && j.terminal !== "") ? j.terminal : "foot"
        root.dockEnabled = j.dockEnabled === true
        root.batteryEnabled = j.batteryEnabled !== false
        root.dockPosition = ["top", "bottom"].indexOf(j.dockPosition) >= 0 ? j.dockPosition : "bottom"
        root.dockAutoHide = j.dockAutoHide === true
        root.pillScalePercent = root.clampOwnScale(j.pillScale ?? root.pillScaleDefault, root.pillScaleDefault)
        root.dockScalePercent = root.clampOwnScale(j.dockScale ?? root.dockScaleDefault, root.dockScaleDefault)
        root.settingsWinW = root.clampSettingsWin(j.settingsWinW ?? root.settingsWinDefault, root.settingsWinDefault)
        root.settingsWinH = root.clampSettingsWin(j.settingsWinH ?? root.settingsWinDefault, root.settingsWinDefault)
        root.dashboardLevel = Math.max(0, Math.min(4, parseInt(j.dashboardLevel ?? 0) || 0))
        root.defaultSchemeIndex = Math.max(0, Math.min(root.schemes.length - 1,
          parseInt(j.defaultSchemeIndex ?? 0) || 0))
        root.audioMonitorsCardEnabled = j.audioMonitorsCardEnabled !== false
        root.manualPaletteIndex = Math.max(0, Math.min(root.manualPalettes.length - 1,
          parseInt(j.manualPaletteIndex ?? 0) || 0))
        root.paletteSystemSync = j.paletteSystemSync !== false
        root.paletteMode = j.paletteMode === true
        root.frameStyle = (j.frameStyle === "curved") ? "curved" : "corners"
        root.frameCurveRadius = root.clampFrameCurveRadius(j.frameCurveRadius ?? 28)
        root.frameThickness = root.clampFrameThickness(j.frameThickness ?? 3)
        root.frameFuse = j.frameFuse !== false


        if (root.paletteMode) root.applyManualPalette(root.manualPaletteIndex)
        root.dockMode    = j.dockMode === "pill" ? "pill" : "panel"
        root.dockOpacity = root.clampPercent(j.dockOpacity ?? root.dockOpacityDefault, root.dockOpacityDefault)
        root.dockBlur    = root.clampPercent(j.dockBlur    ?? root.dockBlurDefault,    root.dockBlurDefault)
        root.glassModePref = j.glassMode === true
        root.glassOpacity  = Math.max(10, root.clampPercent(j.glassOpacity ?? root.glassOpacityDefault, root.glassOpacityDefault))
        root.glassBlurPref = j.glassBlur !== false
        { const sv = parseInt(j.glassSeam); root.glassSeamInset = isNaN(sv) ? root.glassSeamDefault : Math.max(0, Math.min(24, sv)) }
      } catch (e) {
        console.log("Theme: error leyendo ui.json:", e)
      }
    }
  }

  Process {
    id: savePrefsProc
    property string json: ""


    command: ["bash", "-c",
      "mkdir -p '" + root.prefsDir + "' && cat > '" + root.prefsFile + ".tmp' << 'OOZE_EOF'\n" + json + "\nOOZE_EOF\n" +
      "mv -f '" + root.prefsFile + ".tmp' '" + root.prefsFile + "'"]
    running: false
    onRunningChanged: {
      if (running || !root.saveAgain) return
      root.saveAgain = false
      Qt.callLater(() => { savePrefsProc.running = true })
    }
  }

  // ─── Caché de colores (la paleta de matugen) ───────────────────


  readonly property string colorsFile: Quickshell.env("HOME") + "/.cache/oozeshell/colors.json"
  property string lastRaw: ""


  signal colorsLoaded()


  function reload() { colorsView.reload() }

  FileView {
    id: colorsView
    path: root.colorsFile

    watchChanges: true
    onFileChanged: colorsView.reload()
    onLoaded: root.readColors(colorsView.text())
    onLoadFailed: root.colorsLoaded()
  }

  function readColors(text) {
    const raw = (text || "").trim()


    if (raw !== "" && raw !== root.lastRaw) {
      if (root.paletteMode) root.lastRaw = raw
      else root.applyPalette(raw)
    }
    root.colorsLoaded()
  }


  function applyPalette(raw) {
    try {
      const c = JSON.parse(raw).colors


      const isLight = root.themeMode === "light"
      const isColorful = root.themeMode === "colorful"
      const m = isLight ? "light" : "dark"
      const p = k => c[k]?.[m]?.color
      const sf = col => isLight ? root.soften(col) : col
      const pal = isColorful ? root.colorfulPalette(c) : {
        bg:          sf(p("surface") ?? p("background") ?? root.bg),
        surface:     sf(p("surface_container") ?? root.surfaceBase),
        surfaceHigh: sf(p("surface_container_high") ?? root.surfaceHighBase),
        primary:     p("primary") ?? root.primary,
        textOnPrimary: p("on_primary") ?? root.textOnPrimary,
        text:        p("on_surface") ?? p("on_background") ?? root.text,
        subtext:     p("secondary") ?? root.subtext,
        error:       p("error") ?? root.error,
        textOnError: p("on_error") ?? root.textOnError,
        primaryContainer:       p("primary_container") ?? root.primaryContainer,
        textOnPrimaryContainer: p("on_primary_container") ?? root.textOnPrimaryContainer,
        outline:     p("outline") ?? root.outline
      }

      const f = root.cozy ? root.cozify(pal, !isLight) : pal
      root.bg                     = f.bg
      root.surfaceBase            = f.surface
      root.surfaceHighBase        = f.surfaceHigh
      root.primary                = f.primary
      root.textOnPrimary          = f.textOnPrimary
      root.text                   = f.text
      root.subtext                = f.subtext
      root.error                  = f.error
      root.textOnError            = f.textOnError
      root.primaryContainer       = f.primaryContainer
      root.textOnPrimaryContainer = f.textOnPrimaryContainer
      root.outline                = f.outline
      root.lastRaw = raw
    } catch (e) {
      console.log("Theme: error leyendo matugen:", e)
    }
  }

}
