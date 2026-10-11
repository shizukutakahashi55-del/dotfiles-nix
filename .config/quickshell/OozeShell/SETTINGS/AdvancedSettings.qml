// AdvancedSettings — ventana grande de ajustes: categorías a la izquierda, detalle a la derecha.
// Las categorías se listan en SettingsRegistry.qml; las migradas viven en SETTINGS/pages/.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import "../COMMON"
import "../LANG"
import "../AGENDA"
import "../APPEARANCE"
import "../OozeAudio/data"
import "../AUDIO"

Item {
  id: root

  property bool open: false
  property string targetScreen: ""
  property string namespace: "oozeshell-advanced-settings"

  signal closeRequested()
  signal backRequested()
  signal requestMonitorEditor()

  // ── Señales de Perfil / General ──
  signal languageChosen(string code)


  property string targetMonitor: "auto"
  property string resolvedMonitor: ""
  signal monitorChosen(string name)

  // ── Marco de pantalla (Interfaz) ──
  property bool screenCorners: true
  signal requestCornersToggle()

  // ── Apariencia de Hyprland (mismo estado que APPEARANCE/Appearance.qml) ──
  property var appearanceValues: ({})
  signal appearancePreviewChanged(string key, real value)
  signal appearanceValueCommitted(string key, real value)
  signal appearanceToggleChanged(string key, bool value)

  signal animProfileChosen(string name)
  property string animProfile: "smooth"


  readonly property var hyprSliderSpecs: [
    { key: "gapsIn",          label: "Gaps in",          min: 0,   max: 30,  step: 1,    dec: 0, def: 3   },
    { key: "gapsOut",         label: "Gaps out",         min: 0,   max: 60,  step: 1,    dec: 0, def: 6   },
    { key: "borderSize",      label: "Border size",      min: 0,   max: 10,  step: 1,    dec: 0, def: 2   },
    { key: "rounding",        label: "Rounding",         min: 0,   max: 30,  step: 1,    dec: 0, def: 10  },
    { key: "activeOpacity",   label: "Active opacity",   min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "inactiveOpacity", label: "Inactive opacity", min: 0.2, max: 1.0, step: 0.01, dec: 2, def: 1.0 },
    { key: "blurSize",        label: "Blur size",        min: 0,   max: 15,  step: 1,    dec: 0, def: 3   },
    { key: "blurPasses",      label: "Blur passes",      min: 0,   max: 5,   step: 1,    dec: 0, def: 1   },
    { key: "shadowRange",     label: "Shadow range",     min: 0,   max: 50,  step: 1,    dec: 0, def: 3   },
    { key: "shadowRenderPower", label: "Shadow power",   min: 1,   max: 4,   step: 1,    dec: 0, def: 1   }
  ]

  readonly property var hyprSliderColors: ({
    accent: Theme.primary,
    text: Theme.text,
    subtext: Theme.subtext,
    track: Theme.surfaceHigh
  })

  readonly property var hyprToggles: [
    { key: "blurEnabled",       label: Translations.t("appearanceBlur"),       def: true  },
    { key: "shadowEnabled",     label: Translations.t("appearanceShadow"),     def: false },
    { key: "animationsEnabled", label: Translations.t("appearanceAnimations"), def: true  }
  ]


  readonly property var animProfiles: [
    { key: "smooth",        label: "animProfileSmooth",       hint: "animProfileSmoothHint" },
    { key: "snappy",        label: "animProfileSnappy",       hint: "animProfileSnappyHint" },
    { key: "playful",       label: "animProfilePlayful",      hint: "animProfilePlayfulHint" },
    { key: "minimal",       label: "animProfileMinimal",      hint: "animProfileMinimalHint" },
    { key: "dramatic",      label: "animProfileDramatic",     hint: "animProfileDramaticHint" },
    { key: "dramatic_side", label: "animProfileDramaticSide", hint: "animProfileDramaticSideHint" }
  ]


  property string category: "profile"
  property string query: ""


  property bool browsing: false

  onOpenChanged: {
    if (!root.open) { root.query = ""; searchInput.text = ""; root.browsing = false; root.pendingAnchor = "" }
  }
  onBrowsingChanged: { if (root.browsing) profileBrowser.go(profileBrowser.home + "/Pictures") }


  readonly property var categories: SettingsRegistry.categories
  function pageOf(id) { return SettingsRegistry.pageOf(id) }

  // ── Tamaño de la interfaz (categoría General) ──
  readonly property var levelNames: [
    Translations.t("sizeSmall"), Translations.t("sizeMedium"), Translations.t("sizeNormal"),
    Translations.t("sizeLarge"), Translations.t("sizeHuge")
  ]
  readonly property int masterLevel: Theme.barLevel === Theme.windowLevel ? Theme.barLevel : -1
  function levelOf(kind) {
    return kind === "font" ? Theme.fontLevel : kind === "bar" ? Theme.barLevel : Theme.windowLevel
  }


  readonly property var terminalChoices: {
    const all = Theme.terminals
    const inst = Theme.installedTerminals
    const list = inst.length === 0
      ? all.slice()
      : all.filter(t => inst.indexOf(t.id) >= 0 || t.id === Theme.terminalId)
    if (!all.some(t => t.id === Theme.terminalId))
      list.unshift({ id: Theme.terminalId, name: Theme.terminalId })
    return list
  }

  // ── HyprMonitors: editor visual de monitores ──
  property var hmMonitors: []
  property string hmSelected: ""
  property string hmStatus: ""

  readonly property var hmCurrent: {
    for (const m of root.hmMonitors) if (m.output === root.hmSelected) return m
    return null
  }

  function hmRefresh() { hmDetect.running = false; hmDetect.running = true }

  Process {
    id: hmDetect
    command: ["hyprctl", "monitors", "-j"]
    running: false
    property string buffer: ""
    stdout: SplitParser { onRead: line => hmDetect.buffer += line }
    onRunningChanged: {
      if (!running) {
        try {
          const list = JSON.parse(hmDetect.buffer)
          root.hmMonitors = list.map(m => ({
            output:    m.name,
            width:     m.width,
            height:    m.height,
            x:         m.x,
            y:         m.y,
            scale:     m.scale,
            transform: m.transform || 0,
            modes:     Array.isArray(m.availableModes) ? m.availableModes : [],
            mode:      "preferred",
            mirrorOf:  ""
          }))
          if (!root.hmMonitors.some(m => m.output === root.hmSelected))
            root.hmSelected = root.hmMonitors.length > 0 ? root.hmMonitors[0].output : ""
        } catch (e) {
          console.log("AdvancedSettings/HyprMonitors: error leyendo hyprctl monitors:", e)
        }
        hmDetect.buffer = ""
      }
    }
  }


  function hmUpdateMonitor(output, patch) {
    root.hmMonitors = root.hmMonitors.map(m => m.output === output ? Object.assign({}, m, patch) : m)
  }

  // ── Mapa: caja que envuelve todos los monitores, con margen ──
  readonly property real hmMapPad: 400
  readonly property var hmBounds: {
    if (root.hmMonitors.length === 0) return { minX: 0, minY: 0, w: 1920, h: 1080 }
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    for (const m of root.hmMonitors) {
      const w = m.width / (m.scale || 1), h = m.height / (m.scale || 1)
      minX = Math.min(minX, m.x); minY = Math.min(minY, m.y)
      maxX = Math.max(maxX, m.x + w); maxY = Math.max(maxY, m.y + h)
    }
    return { minX: minX - root.hmMapPad, minY: minY - root.hmMapPad,
             w: (maxX - minX) + root.hmMapPad * 2, h: (maxY - minY) + root.hmMapPad * 2 }
  }
  property int hmMapHeight: 230
  property real hmMapWidth: 400
  readonly property real hmMapScale: Math.min(
    (root.hmMapWidth - 20 * 2) / Math.max(1, root.hmBounds.w),
    root.hmMapHeight / Math.max(1, root.hmBounds.h)
  )

  function hmToMapX(x) { return (x - root.hmBounds.minX) * root.hmMapScale }
  function hmToMapY(y) { return (y - root.hmBounds.minY) * root.hmMapScale }
  function hmFromMapX(px) { return root.hmBounds.minX + px / root.hmMapScale }
  function hmFromMapY(py) { return root.hmBounds.minY + py / root.hmMapScale }

  function hmSnap(v) { return Math.round(v / 10) * 10 }

  // ── Escritura de monitors.lua + aplicar ──────────────────────────────
  readonly property string hmMonitorsLuaPath:
    Quickshell.env("HOME") + "/.config/hypr/modules/hardware/settings/monitors.lua"


  function hmLuaMonitorBlock(m) {
    const pos = m.mirrorOf !== "" ? "auto" : (m.x + "x" + m.y)
    const lines = []
    lines.push("hl.monitor({")
    lines.push("    output   = \"" + m.output + "\",")
    lines.push("    mode     = \"" + m.mode + "\",")
    lines.push("    position = \"" + pos + "\",")
    lines.push("    scale    = " + (m.scale === "auto" ? "\"auto\"" : m.scale) + ",")
    if (m.transform && m.transform !== 0)
      lines.push("    transform = " + m.transform + ", -- 1 = 90°, 2 = 180°, 3 = 270°")
    if (m.mirrorOf !== "")
      lines.push("    mirror   = \"" + m.mirrorOf + "\",")
    lines.push("})")
    return lines.join("\n")
  }

  function hmBuildLua() {
    const header =
      "-- ============================================================================\n" +
      "--  MODULE: monitors.lua\n" +
      "--  Contains: monitor outputs (mode, position, scale, mirroring).\n" +
      "--  Auto-generado por OozeShell (Ajustes avanzados → HyprMonitor). No editar\n" +
      "--  a mano: se pisa entero cada vez que tocás \"Aplicar\" acá.\n" +
      "--  Wiki: https://wiki.hypr.land/Configuring/Basics/Monitors/\n" +
      "-- ============================================================================\n\n" +
      "------------------\n---- MONITORS ----\n------------------\n\n" +
      "-- See https://wiki.hypr.land/Configuring/Basics/Monitors/\n\n"
    return header + root.hmMonitors.map(m => root.hmLuaMonitorBlock(m)).join("\n\n") + "\n"
  }

  Process {
    id: hmSaveMonitorsLua
    property string content: ""
    command: ["bash", "-c",
      "mkdir -p \"$(dirname '" + root.hmMonitorsLuaPath + "')\" && cat > '" +
      root.hmMonitorsLuaPath + "' << 'OOZE_LUA_EOF'\n" + content + "\nOOZE_LUA_EOF\n"]
    running: false
    onRunningChanged: if (!running) { hmApplyReload.running = false; hmApplyReload.running = true }
  }


  Process {
    id: hmApplyReload
    running: false
    command: ["bash", "-c", "hyprctl reload"]
    property bool failed: false
    stdout: SplitParser { onRead: line => console.log("[hyprmonitor] hyprctl:", line) }
    stderr: SplitParser { onRead: line => { hmApplyReload.failed = true; console.log("[hyprmonitor] hyprctl error:", line) } }
    onRunningChanged: {
      if (!running) {
        root.hmStatus = hmApplyReload.failed ? Translations.t("hyprMonitorsError")
                                              : Translations.t("hyprMonitorsApplied")
        hmApplyReload.failed = false
      }
    }
  }

  function hmApplyAndSave() {
    root.hmStatus = ""
    hmSaveMonitorsLua.content = root.hmBuildLua()
    hmSaveMonitorsLua.running = false
    hmSaveMonitorsLua.running = true
  }


  readonly property real sidebarWidth: Math.max(160, sidebarMeasure.implicitWidth + 78)

  // ══ BUSCADOR ══

  readonly property bool searching: root.query.trim() !== ""

  function norm(s) {
    let t = String(s ?? "").toLowerCase()
    if (t.normalize) t = t.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    return t
  }
  function catKeyOf(id) { return SettingsRegistry.titleKeyOf(id) }
  function catIconOf(id) { return SettingsRegistry.iconOf(id) }
  function catIconByKey(key) {
    for (const c of root.categories) if (c.titleKey === key) return c.icon
    return ""
  }
  function entryLabel(e) { return e.key ? Translations.t(e.key) : (e.text ?? "") }
  function entryHint(e) { return e.hint ? Translations.tw(e.hint, WM.wm) : "" }


  readonly property var hyprSliderKw: ({
    gapsIn: "espacio separacion margen entre ventanas gap",
    gapsOut: "espacio separacion margen pantalla gap",
    borderSize: "borde grosor border",
    rounding: "redondeo esquinas redondeadas radio corners",
    activeOpacity: "opacidad transparencia ventana activa",
    inactiveOpacity: "opacidad transparencia ventana inactiva",
    blurSize: "desenfoque blur difuminado",
    blurPasses: "desenfoque blur difuminado",
    shadowRange: "sombra shadow",
    shadowRenderPower: "sombra shadow"
  })


  readonly property var searchIndex: {
    const E = (cat, key, hint, kw, sec) => ({ cat: cat, key: key, text: "", hint: hint ?? "", kw: kw ?? "", sec: sec ?? "", anchor: "" })
    const list = [

      E("appearance", "advPaletteTitle", "", "palette paleta colores color tema automatico manual estilo style"),
      E("appearance", "advHyprTitle", "advHyprHint", "gaps bordes borders blur sombra shadow opacidad opacity rounding hyprland"),
      E("appearance", "appearanceBlur", "", "desenfoque blur difuminado", "advHyprTitle"),
      E("appearance", "appearanceShadow", "", "sombra shadow", "advHyprTitle"),
      E("appearance", "appearanceAnimations", "", "animaciones animations efectos movimiento", "advHyprTitle"),
      E("appearance", "advAnimStyle", "advAnimStyleHint", "animacion animation estilo style perfil profile smooth snappy playful minimal dramatic animprofile", "advHyprTitle"),
      E("appearance", "themeSection", "", "theme tema oscuro dark claro light"),
      E("appearance", "themeModeLabel", "themeModeHint", "claro light oscuro dark colorido colorful color tema theme modo mode", "themeSection"),
      E("appearance", "themeColorfulDepth", "themeColorfulHint", "colorido colorful intensidad fondo claridad depth", "themeSection"),

      E("interface", "perfTitle", "perfHint", "performance rendimiento rapido fluido patata lento pc lenta blur sombras animaciones ligero"),
      E("interface", "uiSizeTitle", "uiSizeHint", "tamano size escala scale zoom grande pequeno"),
      E("interface", "uiFineTune", "uiFineHint", "ajuste fino fine tune"),
      E("interface", "uiFont", "", "fuente letra font tipografia texto", "uiFineTune"),
      E("interface", "uiBar", "", "barra bar altura", "uiFineTune"),
      E("interface", "uiWindows", "", "ventanas windows paneles", "uiFineTune"),
      E("interface", "uiReset", "", "reiniciar reset normal restablecer", "uiFineTune"),
      E("interface", "settingsWinTitle", "settingsWinHint", "ventana ajustes tamano size ancho alto width height grande ampliar agrandar window"),
      E("interface", "settingsWinWidth", "", "ancho width ventana ajustes", "settingsWinTitle"),
      E("interface", "settingsWinHeight", "", "alto height ventana ajustes", "settingsWinTitle"),
      E("interface", "advFrameTitle", "advFrameEnableHint", "marco frame borde pantalla esquinas corners curvas"),
      E("interface", "advFrameStyleLabel", "advFrameStyleHint", "estilo style marco frame", "advFrameTitle"),
      E("interface", "advFrameStyleCorners", "", "esquinas corners marco frame", "advFrameTitle"),
      E("interface", "advFrameStyleCurved", "", "curvas curved marco frame", "advFrameTitle"),
      E("interface", "advFrameRadiusLabel", "", "radio curva radius redondeo marco frame", "advFrameTitle"),
      E("interface", "advFrameThicknessLabel", "", "grosor thickness ancho marco frame", "advFrameTitle"),

      E("audio", "advAudioOpenQpwgraph", "", "patchbay pipewire conexiones grafo qpwgraph"),
      E("audio", "advAudioMonitorsToggleLabel", "", "monitores monitors oozeaudio mostrar seccion"),
      E("audio", "advAudioOutputsTitle", "advAudioOutputsHint", "salidas virtuales virtual sink discord pipewire"),
      E("audio", "advAudioVirtualWarning", "", "aviso cuidado advertencia warning nota virtual avanzado pavucontrol", "advAudioOutputsTitle"),
      E("audio", "advAudioCreate", "", "crear create nueva salida virtual", "advAudioOutputsTitle"),
      E("audio", "advAudioAppsTitle", "advAudioAppsHint", "aplicaciones apps applications salida monitor output pavucontrol volumen por app mixer"),
      E("audio", "advAudioMonitorsTitle", "advAudioMonitorsHint", "monitores monitors salidas fisicas parlantes auriculares volumen volume"),

      E("profile", "profilePhoto", "profileBrowseHint", "avatar imagen foto picture perfil"),
      E("profile", "profileChange", "", "cambiar imagen foto avatar elegir", "profilePhoto"),
      E("profile", "profileRemove", "", "quitar borrar remove foto avatar", "profilePhoto"),
      E("profile", "profileDisplayName", "profileDisplayNameHint", "nombre usuario username name mostrar"),

      E("general", "settingsMonitor", "monitorAutoSubtitle", "pantalla display screen monitor principal auto"),
      E("general", "monitorAutoOption", "monitorAutoHint", "automatico auto monitor pantalla", "settingsMonitor"),
      E("general", "brightnessTitle", "brightnessHint", "brillo brightness pantalla luz backlight brightnessctl"),
      E("general", "settingsLanguage", "settingsLanguageHint", "idioma language espanol english japones indonesio"),
      E("general", "settingsTerminalSection", "settingsTerminalHint", "terminal consola kitty alacritty foot wezterm comandos"),
      E("general", "lockSection", "", "bloqueo lock pantalla oozelock fondo wallpaper"),
      E("general", "lockModeAuto", "", "automatico auto bloqueo lock fondo wallpaper", "lockSection"),
      E("general", "lockModeCustom", "", "personalizado custom bloqueo lock fondo wallpaper ruta path", "lockSection"),
      E("general", "fontTitle", "fontHint", "fuente font tipografia typeface letra texto nunito inter redonda pixel nerd mono estilo style"),

      E("hypr", "advCatHyprMonitor", "hyprMonitorsHint", "monitores monitors pantallas displays posicion arrastrar editor"),
      E("hypr", "hyprMonitorsRefresh", "", "detectar refrescar redetect actualizar monitores", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsMode", "", "modo resolucion resolution hz refresh frecuencia", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsPreferred", "", "preferido preferred resolucion resolution", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsScale", "", "escala scale zoom", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsRotation", "", "rotacion rotation girar vertical transform", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsMirror", "", "espejo mirror duplicar clonar", "advCatHyprMonitor"),
      E("hypr", "hyprMonitorsApply", "", "aplicar guardar apply save monitors.lua hl.monitor", "advCatHyprMonitor"),
    ]
    const sliders = root.hyprSliderSpecs.map(sp => ({
      cat: "appearance", key: "", text: sp.label, hint: "", kw: root.hyprSliderKw[sp.key] ?? "",
      sec: "advHyprTitle", anchor: sp.label
    }))

    return list.concat(sliders).concat(SettingsRegistry.searchEntries)
                .filter(e => !e.key || Translations.t(e.key) !== e.key)
  }


  readonly property var searchHay: {
    const idxList = root.searchIndex
    const out = new Array(idxList.length)
    for (let i = 0; i < idxList.length; i++) {
      const e = idxList[i]
      const label = root.norm(root.entryLabel(e))
      const hint = root.norm(root.entryHint(e))
      const catName = root.norm(Translations.t(root.catKeyOf(e.cat)))
      const sec = e.sec ? root.norm(Translations.t(e.sec)) : ""
      const kw = root.norm(e.kw)
      out[i] = { label: label, sec: sec, kw: kw,
                 hay: label + " " + sec + " " + catName + " " + hint + " " + kw }
    }
    return out
  }


  readonly property var searchResults: {
    const q = root.norm(root.query.trim())
    if (q === "") return []
    const tokens = q.split(/\s+/).filter(t => t.length > 0)
    const out = []
    const idxList = root.searchIndex
    const cache = root.searchHay
    for (let i = 0; i < idxList.length; i++) {
      const c = cache[i]
      let ok = true
      let score = 0
      for (const t of tokens) {
        if (c.hay.indexOf(t) < 0) { ok = false; break }
        const at = c.label.indexOf(t)
        if (c.label === t) score += 14
        else if (at === 0) score += 8
        else if (at > 0) score += 5
        else if (c.sec.indexOf(t) >= 0) score += 3
        else if (c.kw.indexOf(t) >= 0) score += 2
        else score += 1
      }
      if (ok) out.push({ e: idxList[i], score: score, i: i })
    }
    out.sort((x, y) => (y.score - x.score) || (x.i - y.i))
    return out.map(r => r.e)
  }

  readonly property var searchCounts: {
    const m = ({})
    for (const e of root.searchResults) m[e.cat] = (m[e.cat] ?? 0) + 1
    return m
  }

  readonly property var visibleCategories: root.searching
    ? root.categories.filter(c => (root.searchCounts[c.id] ?? 0) > 0)
    : root.categories


  function hl(text, q) {
    const raw = String(text ?? "")
    const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    const nq = root.norm(String(q ?? "").trim())
    const n = root.norm(raw)
    if (nq === "" || n.length !== raw.length) return esc(raw)
    const mark = []
    for (let i = 0; i < raw.length; i++) mark.push(false)
    for (const t of nq.split(/\s+/)) {
      if (t.length === 0) continue
      let at = n.indexOf(t)
      while (at >= 0) {
        for (let k = at; k < at + t.length; k++) mark[k] = true
        at = n.indexOf(t, at + t.length)
      }
    }
    let outStr = ""
    let open = false
    for (let i = 0; i < raw.length; i++) {
      if (mark[i] && !open) { outStr += '<font color="' + Theme.primary + '"><b>'; open = true }
      if (!mark[i] && open) { outStr += "</b></font>"; open = false }
      outStr += esc(raw[i])
    }
    if (open) outStr += "</b></font>"
    return outStr
  }

  // ── Ir a una opción: abre la categoría, scrollea y resalta ──
  property string pendingAnchor: ""
  function goToEntry(e) {
    root.pendingAnchor = e.anchor !== "" ? e.anchor : (e.key ? Translations.t(e.key) : (e.text ?? ""))
    root.query = ""
    searchInput.text = ""
    root.category = e.cat
    anchorTimer.restart()
  }
  function openCategory(id) {
    root.pendingAnchor = ""
    root.query = ""
    searchInput.text = ""
    root.category = id
  }

  function findByText(item, target) {
    const kids = item.children
    for (let i = 0; i < kids.length; i++) {
      const k = kids[i]
      if (!k.visible) continue
      const t = k.text
      if (typeof t === "string" && t !== "" && root.norm(t) === target) return k
      const r = root.findByText(k, target)
      if (r) return r
    }
    return null
  }
  function scrollToAnchor() {
    const target = root.norm(root.pendingAnchor)
    root.pendingAnchor = ""
    if (target === "") return
    const found = root.findByText(detailCol, target)
    if (!found) return
    const p = found.mapToItem(flick.contentItem, 0, 0)
    const maxY = Math.max(0, flick.contentHeight - flick.height)
    flick.scrollTo(Math.max(0, Math.min(maxY, p.y - 72)))

    let host = found.parent
    while (host && host !== detailCol) {
      if (host.radius === Theme.cardRadius && host.color !== undefined) break
      host = host.parent
    }
    const box = (host && host !== detailCol) ? host : found
    const bp = box.mapToItem(flick.contentItem, 0, 0)
    flashBox.x = bp.x - 4
    flashBox.y = bp.y - 4
    flashBox.width = box.width + 8
    flashBox.height = box.height + 8
    flashAnim.restart()
  }
  // ══════════════════════════════════════════════════════════════════
  // ── Navegación por teclado ──


  // ══════════════════════════════════════════════════════════════════
  property bool kbOn: false
  property string kbZone: "detail"
  property Item kbTarget: null

  onKbOnChanged: root.kbSyncRing()
  onKbTargetChanged: root.kbSyncRing()
  onKbZoneChanged: root.kbSyncRing()


  Timer {
    interval: 80
    repeat: true
    running: root.open && root.kbOn && root.kbTarget !== null
    onTriggered: root.kbSyncRing()
  }

  Connections {
    target: root
    function onOpenChanged() {
      if (root.open) { root.kbOn = false; root.kbTarget = null; root.kbZone = "detail" }
    }
    function onCategoryChanged() { if (root.kbZone === "detail") root.kbTarget = null }
  }


  Connections {
    target: Theme
    function onBarRebuildingChanged() { if (root.open && !Theme.barRebuilding) Qt.callLater(root.kbRegrab) }
    function onPillModeChanged()      { if (root.open) Qt.callLater(root.kbRegrab) }
    function onIslandsModeChanged()   { if (root.open) Qt.callLater(root.kbRegrab) }
    function onUiStyleChanged()       { if (root.open) Qt.callLater(root.kbRegrab) }
  }
  function kbRegrab() {
    if (!root.open) return
    if (root.kbFocusItem() === null) keyCatcher.forceActiveFocus()
  }


  function kbFocusItem() {
    try {
      const w = keyCatcher.Window.window
      return w ? w.activeFocusItem : null
    } catch (e) { return null }
  }
  function kbIsTextField(f) {
    return !!f && typeof f.cursorPosition !== "undefined" && typeof f.selectByMouse !== "undefined"
  }
  function kbEditing() {
    const f = root.kbFocusItem()
    if (f) return root.kbIsTextField(f)
    return searchInput.activeFocus
  }


  function kbLeaveField() {
    const f = root.kbFocusItem()
    if (root.kbIsTextField(f)) f.focus = false
    else if (searchInput.activeFocus) searchInput.focus = false
    keyCatcher.forceActiveFocus()
  }


  function kbIsControl(k) {
    if (!k || !k.visible || !k.enabled || k.opacity < 0.05 || k.width < 4 || k.height < 4) return false
    if (typeof k.cursorShape !== "undefined" && typeof k.acceptedButtons !== "undefined") {
      if (!(k.acceptedButtons & Qt.LeftButton)) return false
      return k.cursorShape === Qt.PointingHandCursor || k.cursorShape === Qt.IBeamCursor
    }
    return root.kbIsTextField(k) && k.readOnly !== true
  }
  function kbCollect(item, out, depth) {
    if (!item || depth > 40) return
    const kids = item.children
    for (let i = 0; i < kids.length; i++) {
      const k = kids[i]
      if (!k || !k.visible) continue
      if (root.kbIsControl(k)) out.push(k)
      root.kbCollect(k, out, depth + 1)
    }
  }

  function kbList(zone) {
    const raw = []
    root.kbCollect(zone === "side" ? sideBar : detailCol, raw, 0)
    const recs = []
    for (let i = 0; i < raw.length; i++) {
      const t = raw[i]
      const p = t.mapToItem(null, 0, 0)
      let dup = false
      for (let j = 0; j < recs.length; j++) {
        const r = recs[j]

        if (Math.abs(r.x - p.x) < 3 && Math.abs(r.y - p.y) < 3 && Math.abs(r.w - t.width) < 3 && Math.abs(r.h - t.height) < 3) { dup = true; break }
      }
      if (!dup) recs.push({ t: t, x: p.x, y: p.y, w: t.width, h: t.height, row: Math.round((p.y + t.height / 2) / 12) })
    }
    recs.sort((a, b) => a.row !== b.row ? a.row - b.row : a.x - b.x)
    return recs.map(r => r.t)
  }
  function kbCenter(t) { return t.mapToItem(null, t.width / 2, t.height / 2) }
  function kbIsSide(t) {
    for (let p = t; p; p = p.parent) { if (p === sideBar) return true; if (p === detailCol) return false }
    return false
  }


  function kbSet(t) {
    if (!t) return
    root.kbTarget = t
    root.kbOn = true
    root.kbZone = root.kbIsSide(t) ? "side" : "detail"
    if (root.kbZone === "side") {
      const row = t.parent
      if (!root.searching && row && row.catIndex !== undefined && row.catIndex !== root.category)
        root.openCategory(row.catIndex)
    } else {
      root.kbReveal(t)
    }
    root.kbSyncRing()
  }
  function kbReveal(t) {
    const p = t.mapToItem(flick.contentItem, 0, 0)
    const maxY = Math.max(0, flick.contentHeight - flick.height)
    let y = flick.contentY
    if (p.y < 110) y = 0
    else if (p.y - 64 < y) y = p.y - 64
    else if (p.y + t.height + 40 > y + flick.height) y = p.y + t.height + 40 - flick.height
    y = Math.max(0, Math.min(maxY, y))
    if (Math.abs(y - flick.contentY) > 1) flick.scrollTo(y)
  }
  function kbSyncRing() {
    const t = root.kbTarget
    if (!root.kbOn || !t || !t.visible) { ringDetail.visible = false; ringSide.visible = false; return }
    if (root.kbZone === "side") {
      const p = t.mapToItem(sideBar, 0, 0)
      ringSide.x = p.x - 2; ringSide.y = p.y - 2
      ringSide.width = t.width + 4; ringSide.height = t.height + 4
      ringSide.visible = true
      ringDetail.visible = false
    } else {
      const p = t.mapToItem(flick.contentItem, 0, 0)
      ringDetail.x = p.x - 3; ringDetail.y = p.y - 3
      ringDetail.width = t.width + 6; ringDetail.height = t.height + 6
      ringDetail.visible = true
      ringSide.visible = false
    }
  }

  function kbGoSide() {
    const l = root.kbList("side")
    if (l.length === 0) return
    let pick = l[0]
    for (let i = 0; i < l.length; i++) { if (l[i].parent && l[i].parent.current) { pick = l[i]; break } }
    root.kbSet(pick)
  }
  function kbGoDetail() {
    const l = root.kbList("detail")
    if (l.length > 0) root.kbSet(l[0])
  }
  function kbFirst() { root.kbGoDetail(); if (root.kbTarget === null || root.kbIsSide(root.kbTarget)) root.kbGoSide() }


  function kbMove(dir) {
    const list = root.kbList(root.kbZone)
    const cur = root.kbTarget
    if (!cur || list.indexOf(cur) < 0) return false
    const c = root.kbCenter(cur)
    let best = null
    let bestScore = 1e18
    for (let i = 0; i < list.length; i++) {
      const k = list[i]
      if (k === cur) continue
      const q = root.kbCenter(k)
      const dx = q.x - c.x
      const dy = q.y - c.y
      let primary, secondary
      if (dir === "down")       { if (dy <= 4) continue; primary = dy; secondary = Math.abs(dx) }
      else if (dir === "up")    { if (dy >= -4) continue; primary = -dy; secondary = Math.abs(dx) }
      else {

        if (Math.abs(dy) > Math.max(cur.height, k.height) * 0.75) continue
        if (dir === "right")    { if (dx <= 4) continue; primary = dx }
        else                    { if (dx >= -4) continue; primary = -dx }
        secondary = Math.abs(dy)
      }
      const score = primary + secondary * 2.5
      if (score < bestScore) { bestScore = score; best = k }
    }
    if (!best) return false
    root.kbSet(best)
    return true
  }

  function kbOwner(t) {
    for (let p = t, n = 0; p && n < 6; p = p.parent, n++) { if (typeof p.keyNudge === "function") return p }
    return null
  }
  function kbArrow(dir) {
    if (!root.kbTarget) { root.kbFirst(); return }
    if (!root.kbOn) { root.kbOn = true; root.kbSyncRing(); return }
    if (dir === "left" || dir === "right") {
      const o = root.kbOwner(root.kbTarget)
      if (o && o.keyNudge(dir === "right" ? 1 : -1, root.kbTarget)) return
    }
    if (root.kbMove(dir)) return
    if (dir === "up") { root.kbOn = false; searchInput.forceActiveFocus(); return }
    if (dir === "left" && root.kbZone === "detail") root.kbGoSide()
    else if (dir === "right" && root.kbZone === "side") root.kbGoDetail()
  }
  function kbStep(sign) {
    if (!root.kbTarget) { root.kbFirst(); return }
    const all = root.kbList("side").concat(root.kbList("detail"))
    if (all.length === 0) return
    let i = all.indexOf(root.kbTarget)
    if (i < 0) i = sign > 0 ? -1 : 0
    root.kbSet(all[(i + sign + all.length) % all.length])
  }
  function kbCategoryStep(sign) {
    const cats = root.visibleCategories
    if (!cats || cats.length === 0) return
    let i = 0
    for (let j = 0; j < cats.length; j++) { if (cats[j].id === root.category) { i = j; break } }
    root.openCategory(cats[(i + sign + cats.length) % cats.length].id)
    root.kbGoSide()
  }
  function kbScrollBy(f) {
    const maxY = Math.max(0, flick.contentHeight - flick.height)
    flick.scrollTo(Math.max(0, Math.min(maxY, flick.contentY + f * flick.height * 0.85)))
  }
  function kbActivate() {
    const t = root.kbTarget
    if (!t) return
    try {
      if (root.kbIsTextField(t)) t.forceActiveFocus()
      else t.clicked(null)
    } catch (e) { console.log("[kbnav] activar:", e) }
    Qt.callLater(root.kbSyncRing)
  }

  function kbKey(e) {
    const key = e.key
    const m = e.modifiers
    const ctrl = (m & Qt.ControlModifier) !== 0
    const shift = (m & Qt.ShiftModifier) !== 0
    const alt = (m & (Qt.AltModifier | Qt.MetaModifier)) !== 0
    const inSearch = searchInput.activeFocus
    const editing = root.kbEditing()


    if (key === Qt.Key_Escape) {
      if (editing && !inSearch) root.kbLeaveField()
      else if (root.searching) searchInput.text = ""
      else root.closeRequested()
      e.accepted = true
      return
    }


    if (editing) {
      if (key === Qt.Key_Down || key === Qt.Key_Up) {
        root.kbLeaveField()
        if (inSearch && key === Qt.Key_Down) root.kbFirst()
        else root.kbArrow(key === Qt.Key_Down ? "down" : "up")
        e.accepted = true
      } else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
        root.kbLeaveField()
        root.kbStep((key === Qt.Key_Backtab || shift) ? -1 : 1)
        e.accepted = true
      }
      return
    }

    if (!alt) {
      if (ctrl && (key === Qt.Key_Left || key === Qt.Key_Right) && pageLoader.item && pageLoader.item.stepCat) {
        pageLoader.item.stepCat(key === Qt.Key_Left ? -1 : 1)
        e.accepted = true
        return
      }
      if (ctrl && (key === Qt.Key_PageDown || key === Qt.Key_PageUp || key === Qt.Key_Tab || key === Qt.Key_Backtab)) {
        root.kbCategoryStep((key === Qt.Key_PageUp || key === Qt.Key_Backtab || shift) ? -1 : 1)
        e.accepted = true
        return
      }
      if (key === Qt.Key_Slash || (ctrl && key === Qt.Key_F)) {
        root.kbOn = false
        searchInput.forceActiveFocus()
        searchInput.selectAll()
        e.accepted = true
        return
      }
      switch (key) {
        case Qt.Key_Down:     root.kbArrow("down");  e.accepted = true; return
        case Qt.Key_Up:       root.kbArrow("up");    e.accepted = true; return
        case Qt.Key_Left:     root.kbArrow("left");  e.accepted = true; return
        case Qt.Key_Right:    root.kbArrow("right"); e.accepted = true; return
        case Qt.Key_Tab:      root.kbStep(1);        e.accepted = true; return
        case Qt.Key_Backtab:  root.kbStep(-1);       e.accepted = true; return
        case Qt.Key_PageDown: root.kbScrollBy(1);    e.accepted = true; return
        case Qt.Key_PageUp:   root.kbScrollBy(-1);   e.accepted = true; return
        case Qt.Key_Home:     flick.scrollTo(0);     e.accepted = true; return
        case Qt.Key_End:      flick.scrollTo(Math.max(0, flick.contentHeight - flick.height)); e.accepted = true; return
        case Qt.Key_Return:
        case Qt.Key_Enter:
          if (root.kbOn && root.kbTarget) { root.kbActivate(); e.accepted = true }
          return
        case Qt.Key_Space:
          if (root.kbOn && root.kbTarget) { root.kbActivate(); e.accepted = true; return }
          break
      }
    }


    if (e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127
        && !(m & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
      root.kbOn = false
      searchInput.forceActiveFocus()
      searchInput.text += e.text
      searchInput.cursorPosition = searchInput.text.length
      e.accepted = true
    }
  }

  Timer { id: anchorTimer; interval: 130; repeat: false; onTriggered: root.scrollToAnchor() }
  Timer { id: queryDebounce; interval: 110; repeat: false; onTriggered: root.query = searchInput.text }


  readonly property int winBaseW: 960
  readonly property int winBaseH: 660
  readonly property int winW: Math.round(root.winBaseW * Theme.settingsWinW / 100)
  readonly property int winH: Math.round(root.winBaseH * Theme.settingsWinH / 100)

  readonly property real winScale: {
    const p = card.parent
    if (!p || p.width <= 0 || p.height <= 0) return 1
    const fit = Math.min((p.width - 32) / root.winW,
                         (p.height - Theme.barFace * 2 - 16) / root.winH)
    return Math.max(0.5, Math.min(1, fit))
  }


Text {
  id: sidebarMeasure
  visible: false
  font.bold: true
  font.pixelSize: Theme.fs(12)
  font.family: Theme.fontFamily
  text: {
    let longest = ""
    for (const c of root.categories) {
      const t = Translations.t(c.titleKey)
      if (t.length > longest.length) longest = t
    }
    return longest
  }
}


  // ── OozeAudio: mismo AudioService que la app suelta ──
  property string oozeAudioNewName: ""

  property string oozeAudioConfirmDelete: ""


  property bool oozeAudioRefreshedOnce: false


  Connections {
    target: root
    function onCategoryChanged() {
      if (root.category === "audio" && !root.oozeAudioRefreshedOnce) {
        root.oozeAudioRefreshedOnce = true
        AudioService.refreshAll()
      }

      root.oozeAudioConfirmDelete = ""


      if (root.category === "hypr") root.hmRefresh()


      sideFlick.revealCurrent()
    }
  }

  property string oozeAudioError: ""
  Connections {
    target: AudioService
    function onCommandFailed(message) {
      root.oozeAudioError = message
      oozeAudioErrorTimer.restart()
    }
  }
  Timer { id: oozeAudioErrorTimer; interval: 5000; repeat: false; onTriggered: root.oozeAudioError = "" }

  // ── Abrir qpwgraph (avisa si no está instalado) ──
  Process {
    id: qpwgraphProc
    command: ["bash", "-c", "command -v qpwgraph >/dev/null 2>&1 && exec qpwgraph || echo '__ooze_qpwgraph_missing__' >&2"]
    stderr: StdioCollector {
      id: qpwgraphErr
      onStreamFinished: {
        if (qpwgraphErr.text.indexOf("__ooze_qpwgraph_missing__") !== -1) {
          root.oozeAudioError = Translations.t("advAudioQpwgraphMissing")
          oozeAudioErrorTimer.restart()
        }
      }
    }
  }
  function openQpwgraph() {
    qpwgraphProc.running = false
    qpwgraphProc.running = true
  }


  component AudioRow: SkinRect {
    id: row
    property string nodeId: ""
    property string nodeName: ""
    property string title: ""
    property string subtitle: ""
    property int volume: 100
    property bool muted: false
    property bool deletable: false
    property bool confirmingDelete: false

    property bool showConnections: false
    signal volumeMoved(real v)
    signal muteToggled()
    signal deleteRequested()

    Layout.fillWidth: true
    implicitHeight: rowContent.implicitHeight + 20
    radius: 10
    color: Theme.bg
    clip: true

    ColumnLayout {
    id: rowContent
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
    spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.title
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(12)
            font.family: Theme.fontFamily
          }
          Text {
            visible: row.subtitle !== ""
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.subtitle
            color: Theme.subtext
            font.pixelSize: Theme.fs(10)
            font.family: Theme.fontFamily
          }
        }

        SkinRect {
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.muted ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16)
               : (muteArea.containsMouse ? Theme.surfaceHigh : "transparent")
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
          Text {
            anchors.centerIn: parent
            text: row.muted ? "󰝟" : "󰕾"
            color: row.muted ? Theme.error : Theme.subtext
            font.pixelSize: Theme.fs(13)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: muteArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.muteToggled()
          }
        }

        SkinRect {
          visible: row.deletable
          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 9
          color: row.confirmingDelete
            ? Theme.error
            : (delArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.16) : "transparent")
          Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
          Text {
            anchors.centerIn: parent
            text: row.confirmingDelete ? "󰄬" : "󰆴"
            color: row.confirmingDelete ? Theme.textOnPrimary : Theme.subtext
            font.pixelSize: Theme.fs(12)
            font.family: Theme.monoFamily
          }
          MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.deleteRequested()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        enabled: !row.muted
        opacity: row.muted ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.animDuration(120) } }

        Text {
          Layout.fillWidth: true
          text: Translations.t("advAudioVolume")
          color: Theme.subtext
          font.pixelSize: Theme.fs(11)
          font.family: Theme.fontFamily
        }

        NumberStepper {
          Layout.preferredWidth: 130
          value: row.volume
          min: 0; max: 150; step: 5
          suffix: "%"
          onEdited: v => row.volumeMoved(v)
        }
      }

      // ── Conectar a: chips por cada salida física, tildable individual ──
      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 4
        visible: row.showConnections && AudioService.destinationCandidates().length > 0

        Text {
          text: Translations.t("advAudioConnectTo")
          color: Theme.subtext
          font.pixelSize: Theme.fs(10)
          font.family: Theme.fontFamily
        }

        Flow {
          Layout.fillWidth: true
          spacing: 6

          Repeater {
            model: AudioService.destinationCandidates()
            delegate: SkinRect {
              id: chip
              required property var modelData
              readonly property bool connected: AudioService.isConnected(row.nodeName, modelData.name)

              width: chipRow.implicitWidth + 18
              height: 26
              radius: 8
              color: chip.connected
                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                : (chipArea.containsMouse ? Theme.surfaceHigh : Theme.surface)
              border.width: chip.connected ? 1 : 0
              border.color: Theme.primary
              Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }

              RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: 5
                Text {
                  visible: chip.connected
                  text: "󰄬"
                  color: Theme.primary
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.monoFamily
                }
                Text {
                  text: chip.modelData.desc
                  color: chip.connected ? Theme.text : Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }
              }

              MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AudioService.setConnection(row.nodeName, chip.modelData.name, !chip.connected)
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === root.targetScreen) ?? Quickshell.screens[0]
    visible: true
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: root.namespace

    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None


    mask: Region { item: hitArea }

    Connections {
      target: root
      function onOpenChanged() {
        if (root.open) keyCatcher.forceActiveFocus()
      }
    }


    // ── Zona que captura input (clic afuera = cerrar) ──
    Item {
      id: hitArea
      width: root.open ? parent.width : 0
      height: root.open ? parent.height : 0

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.closeRequested()
      }
    }


    FocusScope {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: event => root.kbKey(event)

    // ── Tarjeta grande ──
    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.winW
      height: root.winH

      radius: Theme.cozy ? 0 : Theme.panelRadius
      color: Theme.cozy ? "transparent" : Theme.bg
      border.width: Theme.cozy ? 0 : Theme.bw1
      border.color: Theme.edge

      clip: true

      opacity: root.open ? 1 : 0
      visible: opacity > 0
      scale: (root.open ? 1.0 : 0.95) * root.winScale
      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(180) } }
      Behavior on scale { NumberAnimation { duration: Theme.animDuration(220); easing.type: Easing.OutCubic } }


      MouseArea { anchors.fill: parent }


      HoverHandler {
        id: mouseWatch
        property real lx: -1
        property real ly: -1
        onPointChanged: {
          const p = point.position
          if (root.kbOn && lx >= 0 && Math.abs(p.x - lx) + Math.abs(p.y - ly) > 6) root.kbOn = false
          lx = p.x; ly = p.y
        }
      }

      // ── Marco pixel (solo CoOzey) ──
      readonly property int pixShadow: 4
      readonly property int pixNotch: 8
      Item {
        visible: Theme.cozy
        anchors.fill: parent
        NotchRect {
          x: 0; y: card.pixShadow
          width: parent.width; height: parent.height - card.pixShadow
          topColor: Theme.shadowInk
          notch: card.pixNotch
        }
        NotchRect {
          width: parent.width; height: parent.height - card.pixShadow
          topColor: Theme.ink
          notch: card.pixNotch
        }
        NotchRect {
          x: Theme.inkWidth; y: Theme.inkWidth
          width: parent.width - 2 * Theme.inkWidth
          height: parent.height - card.pixShadow - 2 * Theme.inkWidth
          topColor: Theme.bg
          notch: card.pixNotch - 1
        }
      }


      Item {
        id: cardClip
        readonly property real cornerR: Theme.cozy ? card.pixNotch - 2 : card.radius
        x: Theme.cozy ? Theme.inkWidth : 0
        y: Theme.cozy ? Theme.inkWidth : 0
        width: card.width - (Theme.cozy ? 2 * Theme.inkWidth : 0)
        height: card.height - (Theme.cozy ? card.pixShadow + 2 * Theme.inkWidth : 0)
        clip: true

      ColumnLayout {

        x: -cardClip.x
        y: -cardClip.y
        width: card.width
        height: card.height
        spacing: 0

        // ── Encabezado: volver · título · buscador · cerrar ──
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: 60
          Layout.leftMargin: 20
          Layout.rightMargin: 16
          spacing: 12

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: backArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            Text {
              anchors.centerIn: parent
              text: "󰅁"
              color: Theme.text
              font.pixelSize: Theme.fs(16)
              font.family: Theme.monoFamily
            }
            MouseArea {
              id: backArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.backRequested()
            }
          }

          Text {
            text: "󰒓"
            color: Theme.primary
            font.pixelSize: Theme.fs(19)
            font.family: Theme.monoFamily
          }
          Text {
            text: Translations.t("advTitle")
            color: Theme.text
            font.bold: true
            font.pixelSize: Theme.fs(16)
            font.family: Theme.fontFamily
          }

          Item { Layout.fillWidth: true }

          // ── Buscador: categorías Y opciones de todos los paneles ──
          SkinRect {
            Layout.preferredWidth: 300
            Layout.preferredHeight: 36
            radius: 12
            color: Theme.surface
            border.width: Theme.bw1
            border.color: searchInput.activeFocus
              ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
              : Theme.divider
            Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

            RowLayout {
              anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
              spacing: 8

              Text {
                text: "󰍉"
                color: (searchInput.activeFocus || root.searching) ? Theme.primary : Theme.subtext
                font.pixelSize: Theme.fs(13)
                font.family: Theme.monoFamily
                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
              }

              TextInput {
                id: searchInput
                Layout.fillWidth: true
                color: Theme.text
                selectionColor: Theme.primary
                selectedTextColor: Theme.textOnPrimary
                font.pixelSize: Theme.fs(12)
                font.family: Theme.monoFamily
                clip: true
                inputMethodHints: Qt.ImhNoPredictiveText


                onTextChanged: {
                  if (text === "") { queryDebounce.stop(); root.query = "" }
                  else queryDebounce.restart()
                }

                Keys.onEscapePressed: event => {
                  if (searchInput.text !== "") searchInput.text = ""
                  else root.closeRequested()
                  event.accepted = true
                }

                Keys.onReturnPressed: if (root.searchResults.length > 0) root.goToEntry(root.searchResults[0])
                Keys.onEnterPressed: if (root.searchResults.length > 0) root.goToEntry(root.searchResults[0])

                Text {
                  visible: searchInput.text === "" && !searchInput.activeFocus
                  text: Translations.t("advSearchPlaceholder")
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(12)
                  font.family: Theme.fontFamily
                }
              }

              SkinRect {
                visible: searchInput.text !== ""
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: clearArea.containsMouse ? Theme.surfaceHigh : "transparent"
                Text {
                  anchors.centerIn: parent
                  text: "✕"
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }
                MouseArea {
                  id: clearArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { searchInput.text = ""; searchInput.forceActiveFocus() }
                }
              }
            }
          }

          SkinRect {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: closeArea.containsMouse ? Theme.surfaceHigh : Theme.surface
            Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
            Text {
              anchors.centerIn: parent
              text: "✕"
              color: Theme.text
              font.pixelSize: Theme.fs(14)
              font.family: Theme.fontFamily
            }
            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // ── Cuerpo: categorías + detalle ──
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 0

          // ── Barra lateral ──
          Rectangle {
            id: sideBar
            Layout.preferredWidth: root.sidebarWidth
            Layout.minimumWidth: root.sidebarWidth
            Layout.fillHeight: true
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5)
            bottomLeftRadius: cardClip.cornerR
            clip: true


            Rectangle {
              id: ringSide
              z: 20
              visible: false
              enabled: false
              color: "transparent"
              radius: Theme.cozy ? 4 : 12
              border.width: 2
              border.color: Theme.primary
            }


            Flickable {
              id: sideFlick
              anchors { fill: parent; topMargin: 14; leftMargin: 10; rightMargin: 10; bottomMargin: 10 }
              contentWidth: width
              contentHeight: sideCol.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds


              function sideRevealIdx(i) {
                if (i < 0 || sideFlick.height <= 0) return
                const y0 = i * (40 + 3), y1 = y0 + 40
                let y = sideFlick.contentY
                if (y0 < y) y = y0
                else if (y1 > y + sideFlick.height) y = y1 - sideFlick.height
                const maxY = Math.max(0, sideFlick.contentHeight - sideFlick.height)
                sideFlick.contentY = Math.max(0, Math.min(maxY, y))
              }
              function revealCurrent() {
                if (root.searching) return
                const cats = root.visibleCategories
                for (let i = 0; i < cats.length; i++)
                  if (cats[i].id === root.category) { sideFlick.sideRevealIdx(i); return }
              }

              onContentHeightChanged: sideFlick.contentY =
                Math.max(0, Math.min(sideFlick.contentY,
                                     Math.max(0, sideFlick.contentHeight - sideFlick.height)))

              ColumnLayout {
              id: sideCol
              width: sideFlick.width
              spacing: 3

              Repeater {
                model: root.visibleCategories

                delegate: SkinRect {
                  id: catRow
                  required property var modelData

                  readonly property string catIndex: catRow.modelData.id

                  readonly property bool current: !root.searching && root.category === catIndex
                  readonly property int hits: root.searchCounts[catIndex] ?? 0

                  Layout.fillWidth: true
                  Layout.preferredHeight: 40
                  radius: 11
                  color: catRow.current ? Theme.primary
                       : (catArea.containsMouse ? Theme.surfaceHigh : "transparent")
                  Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                  RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 9 }
                    spacing: 10

                    Text {
                      Layout.preferredWidth: Theme.fs(16)
                      horizontalAlignment: Text.AlignHCenter
                      text: catRow.modelData.icon
                      color: catRow.current ? Theme.textOnPrimary : Theme.primary
                      font.pixelSize: Theme.fs(15)
                      font.family: Theme.monoFamily
                      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }
                    Text {
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                      text: Translations.t(catRow.modelData.titleKey)
                      color: catRow.current ? Theme.textOnPrimary : Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }


                    SkinRect {
                      visible: root.searching
                      Layout.preferredHeight: 20
                      Layout.preferredWidth: Math.max(22, hitsText.implicitWidth + 12)
                      radius: 10
                      color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                      Text {
                        id: hitsText
                        anchors.centerIn: parent
                        text: catRow.hits
                        color: Theme.primary
                        font.bold: true
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }
                  }

                  MouseArea {
                    id: catArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openCategory(catRow.catIndex)
                  }
                }
              }

              Text {
                visible: root.visibleCategories.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 4
                wrapMode: Text.WordWrap
                text: Translations.t("advNoResults")
                color: Theme.subtext
                font.pixelSize: Theme.fs(11)
                font.family: Theme.fontFamily
              }
            }
            }


            Rectangle {
              z: 20
              visible: sideFlick.contentHeight > sideFlick.height + 1
              width: 4
              radius: Theme.cozy ? 0 : 2
              x: sideBar.width - width - 3
              height: Math.max(24, sideFlick.height * sideFlick.height / Math.max(1, sideFlick.contentHeight))
              readonly property real pad: 6
              y: sideFlick.y + ((sideFlick.contentHeight - sideFlick.height) > 0
                 ? pad + (sideFlick.height - height - 2 * pad) * (sideFlick.contentY / (sideFlick.contentHeight - sideFlick.height))
                 : pad)
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (sideFlick.moving || sideFlick.flicking) ? 0.75 : 0.30)
              Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
            }
          }

          Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.divider }

          // ── Detalle de la categoría elegida ──
          Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.minimumWidth: 320
            Layout.preferredWidth: 480
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: detailCol.implicitHeight + 52
            clip: true
            boundsBehavior: Flickable.StopAtBounds


            NumberAnimation {
              id: gotoAnim
              target: flick
              property: "contentY"
              duration: Theme.animDuration(150)
              easing.type: Easing.OutCubic
            }
            function scrollTo(y) {
              gotoAnim.stop()
              if (!Theme.uiAnimationsEnabled || Math.abs(y - flick.contentY) < 2) { flick.contentY = y; return }
              gotoAnim.from = flick.contentY
              gotoAnim.to = y
              gotoAnim.start()
            }

            onMovementStarted: gotoAnim.stop()


            Connections {
              target: root
              function onCategoryChanged() { gotoAnim.stop(); flick.contentY = 0 }
              function onOpenChanged() { if (root.open) { gotoAnim.stop(); flick.contentY = 0 } }
            }


            Connections {
              target: root
              function onQueryChanged() { if (root.searching) { gotoAnim.stop(); flick.contentY = 0; sideFlick.contentY = 0 } }
            }


            Rectangle {
              id: ringDetail
              z: 55
              visible: false
              enabled: false
              color: "transparent"
              radius: Theme.cozy ? 4 : 10
              border.width: 2
              border.color: Theme.primary
            }


            SkinRect {
              id: flashBox
              z: 50
              radius: Theme.cardRadius + 3
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
              inkColor: Theme.primary
              border.width: 2
              border.color: Theme.primary
              opacity: 0
              visible: opacity > 0
              enabled: false
            }
            SequentialAnimation {
              id: flashAnim
              NumberAnimation { target: flashBox; property: "opacity"; from: 0; to: 1; duration: Theme.animDuration(160) }
              PauseAnimation { duration: Theme.animDuration(950) }
              NumberAnimation { target: flashBox; property: "opacity"; to: 0; duration: Theme.animDuration(650) }
            }


            Rectangle {
              parent: flick
              z: 60
              visible: flick.contentHeight > flick.height + 1
              width: 4
              radius: Theme.cozy ? 0 : 2
              x: flick.width - width - 4
              height: Math.max(28, flick.height * flick.height / Math.max(1, flick.contentHeight))
              readonly property real pad: 8
              y: (flick.contentHeight - flick.height) > 0
                 ? pad + (flick.height - height - 2 * pad) * (flick.contentY / (flick.contentHeight - flick.height))
                 : pad
              color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, (flick.moving || flick.flicking) ? 0.75 : 0.30)
              Behavior on color { ColorAnimation { duration: Theme.animDuration(200) } }
            }

            ColumnLayout {
              id: detailCol

              width: Math.min(flick.width - 44, Math.round(760 * Math.max(1, Theme.settingsWinW / 100)))
              x: Math.max(22, Math.round((flick.width - width) / 2))
              y: 22
              spacing: 1

              // ── Resultados de búsqueda ──
              ColumnLayout {
                id: resultsBlock
                Layout.fillWidth: true
                visible: root.searching
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  Layout.bottomMargin: 4
                  spacing: 12

                  SkinRect {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 11
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    Text {
                      anchors.centerIn: parent
                      text: "󰍉"
                      color: Theme.primary
                      font.pixelSize: Theme.fs(17)
                      font.family: Theme.monoFamily
                    }
                  }
                  Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Translations.t("advSearchResults") + (root.searchResults.length > 0 ? "  ·  " + root.searchResults.length : "")
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: Theme.fs(19)
                    font.family: Theme.fontFamily
                  }
                }


                ColumnLayout {
                  visible: root.searchResults.length === 0
                  Layout.fillWidth: true
                  Layout.topMargin: 6
                  spacing: 4
                  Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Translations.t("advNoResults")
                    color: Theme.text
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    font.family: Theme.fontFamily
                  }
                  Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: Translations.t("advSearchTryHint")
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                Repeater {
                  model: root.searchResults

                  delegate: SkinRect {
                    id: resRow
                    required property var modelData
                    readonly property string label: root.entryLabel(resRow.modelData)
                    readonly property string hint: root.entryHint(resRow.modelData)
                    readonly property string secName: resRow.modelData.sec !== ""
                      ? Translations.t(resRow.modelData.sec) : ""
                    readonly property string crumb: Translations.t(root.catKeyOf(resRow.modelData.cat))
                      + ((resRow.secName !== "" && resRow.secName !== resRow.label) ? "   ›   " + resRow.secName : "")

                    Layout.fillWidth: true
                    implicitHeight: resLay.implicitHeight + 24
                    radius: Theme.cardRadius
                    color: resArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                    border.width: Theme.bw1
                    border.color: resArea.containsMouse
                      ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                      : Theme.divider
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animDuration(120) } }

                    RowLayout {
                      id: resLay
                      anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                      spacing: 12

                      SkinRect {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignTop
                        radius: 10
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        Text {
                          anchors.centerIn: parent
                          text: root.catIconOf(resRow.modelData.cat)
                          color: Theme.primary
                          font.pixelSize: Theme.fs(15)
                          font.family: Theme.fontFamily
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                          Layout.fillWidth: true
                          textFormat: Text.RichText
                          elide: Text.ElideRight
                          text: root.hl(resRow.label, root.query)
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          Layout.fillWidth: true
                          elide: Text.ElideRight
                          text: resRow.crumb
                          color: Theme.primary
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          visible: resRow.hint !== ""
                          Layout.fillWidth: true
                          Layout.topMargin: 2
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          textFormat: Text.RichText
                          text: root.hl(resRow.hint, root.query)
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                      }

                      Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "󰅂"
                        color: resArea.containsMouse ? Theme.primary : Theme.subtext
                        font.pixelSize: Theme.fs(15)
                        font.family: Theme.monoFamily
                        Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                      }
                    }

                    MouseArea {
                      id: resArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.goToEntry(resRow.modelData)
                    }
                  }
                }
              }

              // ── Páginas migradas (pages/): solo existe la de la categoría elegida ──
              Loader {
                id: pageLoader
                Layout.fillWidth: true

                visible: pageLoader.active
                Layout.preferredHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0

                active: !root.searching && root.pageOf(root.category) !== "" && (root.open || card.visible)
                source: root.pageOf(root.category)
                onLoaded: {

                  pageLoader.item.host = root
                  pageLoader.item.active = Qt.binding(() => root.open)

                  if (root.pendingAnchor !== "") anchorTimer.restart()
                }
              }


              // ── Apariencia · Paleta ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "appearance"
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatAppearance"); title: Translations.t("advCatAppearance") }

                // ── Tema: oscuro / claro / colorido ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: themeCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: themeCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("themeSection") }

                    Text {
                      text: Translations.t("themeModeLabel")
                      color: Theme.text
                      font.bold: true
                      font.pixelSize: Theme.fs(12)
                      font.family: Theme.fontFamily
                    }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      SettingsBtn {
                        icon: "󰖔"
                        text: Translations.t("themeDark")
                        primary: Theme.themeMode === "dark"
                        onClicked: Theme.setThemeMode("dark")
                      }
                      SettingsBtn {
                        icon: "󰖨"
                        text: Translations.t("themeLight")
                        primary: Theme.themeMode === "light"
                        onClicked: Theme.setThemeMode("light")
                      }
                      SettingsBtn {
                        icon: "󰏘"
                        text: Translations.t("themeColorful")
                        primary: Theme.themeMode === "colorful"
                        onClicked: Theme.setThemeMode("colorful")
                      }
                    }


                    SectionLabel {
                      visible: Theme.themeMode === "colorful" && !Theme.paletteMode
                      text: Translations.t("themeColorfulDepth")
                    }
                    ScaleSlider {
                      visible: Theme.themeMode === "colorful" && !Theme.paletteMode
                      value: Theme.colorfulDepth
                      min: 0
                      max: 100
                      step: 5
                      defaultValue: 50
                      onEdited: v => Theme.setColorfulDepth(v)
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("themeModeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                    Text {
                      Layout.fillWidth: true
                      visible: Theme.paletteMode
                      text: Translations.t("themeModePalettesNote")
                      wrapMode: Text.WordWrap
                      color: Theme.primary
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: paletteCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: paletteCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advPaletteTitle") }

                    // ── Automático ⇄ Paletas ──
                    SkinRect {
                      id: modeSlider
                      Layout.fillWidth: true
                      Layout.preferredHeight: 36
                      radius: 18
                      color: Theme.bg
                      border.width: Theme.bw1
                      border.color: Theme.edge

                      readonly property bool manual: Theme.paletteMode
                      readonly property real half: (width - 4) / 2

                      SkinRect {
                        x: modeSlider.manual ? modeSlider.half + 2 : 2
                        y: 2
                        width: modeSlider.half
                        height: parent.height - 4
                        radius: 16
                        color: Theme.primary
                        Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
                      }

                      RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                          model: [
                            { key: "advPaletteModeAuto",   value: false },
                            { key: "advPaletteModeManual", value: true  }
                          ]

                          delegate: Item {
                            id: seg
                            required property var modelData
                            readonly property bool active: seg.modelData.value === modeSlider.manual

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                              anchors.centerIn: parent
                              text: Translations.t(seg.modelData.key)
                              color: seg.active ? Theme.textOnPrimary : Theme.subtext
                              font.bold: seg.active
                              font.pixelSize: Theme.fs(11)
                              font.family: Theme.fontFamily
                              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: Theme.setPaletteMode(seg.modelData.value)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: Theme.paletteMode
                      text: Translations.t("advPaletteManualHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    // ── Paleta → resto del sistema (plantillas de matugen) ──
                    RowLayout {
                      Layout.fillWidth: true
                      visible: Theme.paletteMode
                      spacing: 10

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("advPaletteSystem")
                        elide: Text.ElideRight
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      SettingsBtn {
                        icon: Theme.paletteSystemSync ? "󰄬" : "󰅖"
                        text: Theme.paletteSystemSync ? "ON" : "OFF"
                        primary: Theme.paletteSystemSync
                        onClicked: Theme.setPaletteSystemSync(!Theme.paletteSystemSync)
                      }
                    }

                    // ── Estilo de interfaz ──
                    SectionLabel { text: Translations.t("advStyleTitle") }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 10

                      Repeater {
                        model: [
                          { id: "soft", nameKey: "advStyleSoft", hintKey: "advStyleSoftHint" },
                          { id: "cozy", nameKey: "advStyleCozy", hintKey: "advStyleCozyHint" }
                        ]

                        delegate: SkinRect {
                          id: scard
                          required property var modelData
                          readonly property bool active: Theme.uiStyle === scard.modelData.id
                          readonly property bool isCozy: scard.modelData.id === "cozy"

                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          implicitHeight: scol.implicitHeight + 24
                          radius: scard.isCozy ? 4 : 12
                          color: scardArea.containsMouse ? Theme.surfaceHigh : Theme.bg
                          inkColor: scard.active ? Theme.primary : Theme.ink
                          border.width: scard.active ? 2 : (scard.isCozy ? 2 : 1)
                          border.color: scard.active ? Theme.primary : (scard.isCozy ? Theme.ink : Theme.divider)
                          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                          ColumnLayout {
                            id: scol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 8


                            Rectangle {
                              Layout.fillWidth: true
                              Layout.preferredHeight: 54
                              radius: scard.isCozy ? 4 : 10
                              color: Theme.surface
                              border.width: scard.isCozy ? 2 : 1
                              border.color: scard.isCozy ? Theme.ink : Theme.divider
                              clip: true

                              Rectangle {
                                anchors { left: parent.left; right: parent.right; top: parent.top
                                          margins: scard.isCozy ? 2 : 1 }
                                height: 12
                                radius: scard.isCozy ? 2 : 8
                                color: Theme.bg
                                border.width: scard.isCozy ? 2 : 0
                                border.color: Theme.ink
                              }
                              Rectangle {
                                x: 8; y: 22; width: parent.width * 0.5; height: 22
                                radius: scard.isCozy ? 2 : 7
                                color: Theme.surfaceHigh
                                border.width: scard.isCozy ? 2 : 1
                                border.color: scard.isCozy ? Theme.ink : Theme.divider
                              }
                              Rectangle {
                                x: parent.width * 0.5 + 16; y: 26
                                width: parent.width * 0.5 - 30; height: 14
                                radius: scard.isCozy ? 4 : 7
                                color: Theme.primary
                                border.width: scard.isCozy ? 2 : 0
                                border.color: Theme.ink
                              }
                            }

                            RowLayout {
                              Layout.fillWidth: true
                              spacing: 6
                              Text {
                                Layout.fillWidth: true
                                text: Translations.t(scard.modelData.nameKey)
                                color: Theme.text
                                font.bold: true
                                font.pixelSize: Theme.fs(12)
                                font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
                                elide: Text.ElideRight
                              }
                              Text {
                                visible: scard.active
                                text: "󰄬"
                                color: Theme.primary
                                font.pixelSize: Theme.fs(14)
                                font.family: Theme.monoFamily
                              }
                            }
                            Text {
                              Layout.fillWidth: true
                              text: Translations.t(scard.modelData.hintKey)
                              wrapMode: Text.WordWrap
                              color: Theme.subtext
                              font.pixelSize: Theme.fs(10)
                              font.family: scard.isCozy ? Theme.cozyFamily : Theme.monoFamily
                            }
                          }

                          MouseArea {
                            id: scardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setUiStyle(scard.modelData.id)
                          }
                        }
                      }
                    }

                    // ── Paletas: 14 paletas fijas (con muestra de color) ──
                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: Theme.paletteMode

                      Repeater {
                        model: Theme.paletteOrder
                        delegate: SkinRect {
                          id: pchip

                          required property int modelData
                          readonly property var pal: Theme.manualPalettes[pchip.modelData]
                          readonly property bool active: pchip.modelData === Theme.manualPaletteIndex

                          implicitWidth: pchipRow.implicitWidth + 22
                          implicitHeight: 32
                          radius: 16
                          color: pchip.active ? Theme.primary
                               : (pchipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
                          border.width: pchip.active ? 0 : Theme.bw1
                          border.color: Theme.edge
                          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                          RowLayout {
                            id: pchipRow
                            anchors.centerIn: parent
                            spacing: 6

                            SkinRect {
                              Layout.preferredWidth: 14
                              Layout.preferredHeight: 14
                              radius: 7
                              color: pchip.pal.primary
                              border.width: Theme.bw1
                              border.color: pchip.active ? Theme.textOnPrimary : Theme.edge
                            }

                            Text {
                              text: pchip.pal.label
                              color: pchip.active ? Theme.textOnPrimary : Theme.text
                              font.pixelSize: Theme.fs(11)
                              font.bold: pchip.active
                              font.family: Theme.fontFamily
                            }
                          }

                          MouseArea {
                            id: pchipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setManualPaletteIndex(pchip.modelData)
                          }
                        }
                      }
                    }
                    // ── CoOzey: paletas y atajos (solo con el estilo CoOzey) ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      visible: Theme.cozy
                      spacing: 12

                      SectionLabel { text: Translations.t("cozyTitle") }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("cozyHint")
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(11)
                        font.family: Theme.fontFamily
                      }


                      RowLayout {
                        Layout.fillWidth: true
                        visible: !Theme.paletteMode
                        spacing: 8
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("cozyWarm") + " · " + Theme.cozyWarm + "%"
                          elide: Text.ElideRight
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                        }
                        SettingsBtn { text: "−"; onClicked: Theme.setCozyWarm(Theme.cozyWarm - 10) }
                        SettingsBtn { text: "+"; onClicked: Theme.setCozyWarm(Theme.cozyWarm + 10) }
                      }

                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SettingsBtn {
                          icon: "󰉼"
                          text: Translations.t("cozyUsePalettes")
                          onClicked: Theme.enableCozy(null)
                        }
                      }
                    }
                  }
                }

                // ── Hyprland: gaps, bordes, blur, sombra ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: hyprCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: hyprCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 14

                    SectionLabel { text: Translations.t("advHyprTitle") }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advHyprHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    GridLayout {
                      Layout.fillWidth: true
                      columns: 2
                      columnSpacing: 18
                      rowSpacing: 10

                      Repeater {
                        model: root.hyprSliderSpecs

                        delegate: AppearanceSlider {
                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          Layout.preferredHeight: 44

                          opacity: (modelData.key.indexOf("shadow") === 0
                                    && !(root.appearanceValues.shadowEnabled ?? false)) ? 0.45 : 1
                          Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

                          label: modelData.label
                          keyName: modelData.key
                          minValue: modelData.min
                          maxValue: modelData.max
                          stepValue: modelData.step
                          decimals: modelData.dec
                          value: root.appearanceValues[modelData.key] ?? modelData.def
                          colors: root.hyprSliderColors

                          onPreviewChanged: (k, v) => root.appearancePreviewChanged(k, v)
                          onCommitted: (k, v) => root.appearanceValueCommitted(k, v)
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      Repeater {
                        model: root.hyprToggles

                        delegate: Item {
                          id: tog
                          readonly property bool on: root.appearanceValues[modelData.key] ?? modelData.def

                          Layout.fillWidth: true
                          Layout.preferredWidth: 1
                          Layout.preferredHeight: 26

                          RowLayout {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            SkinRect {
                              Layout.preferredWidth: 34
                              Layout.preferredHeight: 20
                              radius: 10
                              color: tog.on ? Theme.primary : Theme.surfaceHigh
                              Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                              SkinRect {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                x: tog.on ? 17 : 3
                                color: tog.on ? Theme.textOnPrimary : Theme.subtext
                                Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                              }
                            }

                            Text {
                              Layout.fillWidth: true
                              text: modelData.label
                              color: Theme.text
                              font.pixelSize: Theme.fs(11)
                              font.family: Theme.fontFamily
                              elide: Text.ElideRight
                            }
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.appearanceToggleChanged(modelData.key, !tog.on)
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Estilo de animación (animprofile.lua / .conf / .kdl según el WM) ──
                    ColumnLayout {
                      id: animStyleCol
                      Layout.fillWidth: true
                      spacing: 8

                      opacity: (root.appearanceValues.animationsEnabled ?? true) ? 1 : 0.45
                      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("advAnimStyle")
                        color: Theme.text
                        font.pixelSize: Theme.fs(12)
                        font.bold: true
                        font.family: Theme.fontFamily
                      }

                      Flow {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                          model: root.animProfiles

                          delegate: SkinRect {
                            id: achip
                            required property var modelData
                            readonly property bool active: root.animProfile === modelData.key

                            implicitWidth: achipText.implicitWidth + 26
                            implicitHeight: 32
                            radius: 16
                            color: achip.active ? Theme.primary
                                 : (achipArea.containsMouse ? Theme.surfaceHigh : Theme.bg)
                            border.width: achip.active ? 0 : Theme.bw1
                            border.color: Theme.edge
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                            Text {
                              id: achipText
                              anchors.centerIn: parent
                              text: Translations.t(achip.modelData.label)
                              color: achip.active ? Theme.textOnPrimary : Theme.text
                              font.pixelSize: Theme.fs(11)
                              font.bold: achip.active
                              font.family: Theme.fontFamily
                            }

                            MouseArea {
                              id: achipArea
                              anchors.fill: parent
                              hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: root.animProfileChosen(achip.modelData.key)
                            }
                          }
                        }
                      }


                      Text {
                        Layout.fillWidth: true
                        readonly property var cur: root.animProfiles.find(p => p.key === root.animProfile)
                        text: cur ? Translations.tw(cur.hint, WM.wm) : ""
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(11)
                        font.family: Theme.fontFamily
                      }
                    }
                  }
                }
              }

              // ── Interfaz · tamaño, ventana de ajustes, marco de pantalla ──
              Loader {
                id: catLoader_interface
                Layout.fillWidth: true


                active: !root.searching && root.category === "interface" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatInterface"); title: Translations.t("advCatInterface") }

                // ── PERFORMANCE (modo para equipos modestos) ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: perfCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.performanceMode ? Theme.primary : Theme.edge
                  clip: true

                  ColumnLayout {
                    id: perfCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    RowLayout {
                      Layout.fillWidth: true
                      SectionLabel { text: Translations.t("perfTitle") }
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        icon: "󰓅"
                        text: Theme.performanceMode ? "ON" : "OFF"
                        primary: Theme.performanceMode
                        onClicked: Theme.setPerformanceMode(!Theme.performanceMode)
                      }
                    }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("perfHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Tamaño de la interfaz ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: sizeCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: sizeCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      SectionLabel { text: Translations.t("uiSizeTitle") }
                      Item { Layout.fillWidth: true }
                      Text {
                        visible: root.masterLevel < 0
                        text: Translations.t("uiCustom")
                        color: Theme.primary
                        font.pixelSize: Theme.fs(11)
                        font.family: Theme.fontFamily
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("uiSizeHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    LevelPicker {
                      level: root.masterLevel
                      names: root.levelNames
                      showNames: true
                      onPicked: index => Theme.setInterfaceLevel(index)
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: "Animaciones de OozeShell" }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("uiAnimNote")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Normal"
                        primary: Theme.uiAnimationMode === "normal"
                        onClicked: Theme.setUiAnimationMode("normal")
                      }
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Mínimas"
                        primary: Theme.uiAnimationMode === "minimal"
                        onClicked: Theme.setUiAnimationMode("minimal")
                      }
                      SettingsBtn {
                        Layout.fillWidth: true
                        text: "Desactivadas"
                        primary: Theme.uiAnimationMode === "off"
                        onClicked: Theme.setUiAnimationMode("off")
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    SectionLabel { text: Translations.t("uiFineTune") }

                    // ── Tamaño de fuente manual (%) ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 6

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("uiFontManual")
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }
                        Text {
                          visible: Theme.fontCustom
                          text: Translations.t("uiCustom")
                          color: Theme.primary
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                        }
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        NumberStepper {
                          Layout.preferredWidth: 150
                          value: Theme.fontPercentEffective
                          min: Theme.fontPercentMin
                          max: Theme.fontPercentMax
                          step: 5
                          suffix: "%"
                          onEdited: v => Theme.setFontPercent(v)
                        }

                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("uiFontExample") + ": 13 px → " + Theme.fs(13) + " px"
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }

                        SkinRect {
                          visible: Theme.fontCustom
                          Layout.preferredWidth: fontResetLbl.implicitWidth + 20
                          Layout.preferredHeight: 30
                          radius: 9
                          color: fontResetArea.containsMouse ? Theme.surfaceHigh : Theme.surface
                          Text {
                            id: fontResetLbl
                            anchors.centerIn: parent
                            text: "󰑙  " + Translations.t("uiFontReset")
                            color: Theme.text
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.monoFamily
                          }
                          MouseArea {
                            id: fontResetArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setFontPercent(0)
                          }
                        }
                      }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("uiFontManualHint")
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }

                    Repeater {
                      model: [
                        { kind: "font",   label: "uiFont" },
                        { kind: "bar",    label: "uiBar" },
                        { kind: "window", label: "uiWindows" }
                      ]

                      delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                          Layout.preferredWidth: 100
                          Layout.maximumWidth: 140
                          spacing: 0
                          Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: Translations.t(modelData.label)
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                          Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: (modelData.kind === "font" && Theme.fontCustom) ? (Theme.fontPercent + "%") : (root.levelNames[root.levelOf(modelData.kind)] ?? "")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                        }

                        LevelPicker {
                          level: (modelData.kind === "font" && Theme.fontCustom) ? -1 : root.levelOf(modelData.kind)
                          names: root.levelNames
                          showNames: false
                          onPicked: index => Theme.setLevel(modelData.kind, index)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("uiFineHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    RowLayout {
                      Layout.fillWidth: true
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        text: Translations.t("uiReset")
                        onClicked: Theme.resetLevels()
                      }
                    }
                  }
                }

                // ── Ventana de ajustes: tamaño propio ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: winCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: winCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsWinTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsWinHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      Text {
                        Layout.preferredWidth: 110
                        elide: Text.ElideRight
                        text: Translations.t("settingsWinWidth")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      ScaleSlider {
                        value: Theme.settingsWinW
                        min: Theme.settingsWinMin
                        max: Theme.settingsWinMax
                        step: 5
                        defaultValue: Theme.settingsWinDefault
                        onEdited: v => Theme.setSettingsWinW(v)
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      Text {
                        Layout.preferredWidth: 110
                        elide: Text.ElideRight
                        text: Translations.t("settingsWinHeight")
                        color: Theme.text
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        font.family: Theme.fontFamily
                      }
                      ScaleSlider {
                        value: Theme.settingsWinH
                        min: Theme.settingsWinMin
                        max: Theme.settingsWinMax
                        step: 5
                        defaultValue: Theme.settingsWinDefault
                        onEdited: v => Theme.setSettingsWinH(v)
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsWinNote")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      Item { Layout.fillWidth: true }
                      SettingsBtn {
                        text: Translations.t("settingsWinReset")
                        onClicked: Theme.resetSettingsWin()
                      }
                    }
                  }
                }

                // ── Marco de pantalla: ON/OFF, estilo y radio/grosor ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: frameCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: frameCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    // ── Encabezado + interruptor ON/OFF ──
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12

                      SkinRect {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 11
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        Text {
                          anchors.centerIn: parent
                          text: root.screenCorners ? "▣" : "▢"
                          color: Theme.primary
                          font.pixelSize: Theme.fs(16)
                          font.family: Theme.fontFamily
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        SectionLabel { text: Translations.t("advFrameTitle") }
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("advFrameEnableHint")
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(10)
                          font.family: Theme.fontFamily
                        }
                      }

                      // ── Interruptor ──
                      Item {
                        id: frameSwitch
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 20
                        opacity: Theme.barSeparated ? 0.4 : 1.0

                        SkinRect {
                          anchors.fill: parent
                          radius: 10
                          color: root.screenCorners ? Theme.primary : Theme.surfaceHigh
                          Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                          SkinRect {
                            width: 14
                            height: 14
                            radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.screenCorners ? 17 : 3
                            color: root.screenCorners ? Theme.textOnPrimary : Theme.subtext
                            Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                          }
                        }

                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Theme.barSeparated ? Qt.ArrowCursor : Qt.PointingHandCursor
                          onClicked: if (!Theme.barSeparated) root.requestCornersToggle()
                        }
                      }
                    }

                    // ── Aviso: no se muestra con barra flotante o Islas ──
                    Text {
                      visible: Theme.barSeparated
                      Layout.fillWidth: true
                      text: Translations.t("advFrameOffHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Estilo: Esquinas | Curvas (selector de 2) ──
                    SectionLabel { text: Translations.t("advFrameStyleLabel") }

                    SkinRect {
                      id: styleSeg
                      Layout.fillWidth: true
                      Layout.preferredHeight: 44
                      radius: 12
                      color: Theme.surfaceHigh

                      readonly property bool curved: Theme.frameCurved
                      readonly property real segW: (width - 6) / 2


                      SkinRect {
                        x: 3 + (styleSeg.curved ? 1 : 0) * styleSeg.segW
                        y: 3
                        width: styleSeg.segW
                        height: parent.height - 6
                        radius: 9
                        color: Theme.primary
                        Behavior on x { NumberAnimation { duration: Theme.animDuration(180); easing.type: Easing.OutCubic } }
                      }

                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 0

                        Repeater {
                          model: [
                            { key: "corners", glyph: "▨", label: Translations.t("advFrameStyleCorners") },
                            { key: "curved",  glyph: "◜", label: Translations.t("advFrameStyleCurved")  }
                          ]

                          delegate: Item {
                            id: opt
                            required property var modelData
                            readonly property bool current: Theme.frameStyle === modelData.key

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                              anchors.centerIn: parent
                              spacing: 6
                              Text {
                                text: opt.modelData.glyph
                                color: opt.current ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.fs(14)
                                font.family: Theme.monoFamily
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                              }
                              Text {
                                text: opt.modelData.label
                                color: opt.current ? Theme.textOnPrimary : Theme.text
                                font.pixelSize: Theme.fs(11)
                                font.family: Theme.fontFamily
                                Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                              }
                            }

                            MouseArea {
                              anchors.fill: parent
                              cursorShape: Qt.PointingHandCursor
                              onClicked: Theme.setFrameStyle(opt.modelData.key)
                            }
                          }
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advFrameStyleHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    // ── Radio / grosor: solo tienen sentido con "curvas" ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 10
                      visible: Theme.frameCurved
                      opacity: Theme.frameCurved ? 1 : 0
                      Behavior on opacity { NumberAnimation { duration: Theme.animDuration(150) } }

                      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 6
                          Text {
                            text: Translations.t("advFrameRadiusLabel")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                          NumberStepper {
                            value: Theme.frameCurveRadius
                            min: 10; max: 60; step: 2
                            suffix: "px"
                            onEdited: v => Theme.setFrameCurveRadius(v)
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 6
                          Text {
                            text: Translations.t("advFrameThicknessLabel")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(10)
                            font.family: Theme.fontFamily
                          }
                          NumberStepper {
                            value: Theme.frameThickness
                            min: 0; max: 150; step: 2
                            suffix: "px"
                            onEdited: v => Theme.setFrameThickness(v)
                          }
                        }


                        RowLayout {
                          Layout.fillWidth: true
                          visible: Theme.frameBorderActive
                          spacing: 10
                          Text {
                            Layout.fillWidth: true
                            text: Translations.t("advFrameFuse")
                            elide: Text.ElideRight
                            color: Theme.text
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                          SettingsBtn {
                            icon: Theme.frameFuse ? "󰄬" : "󰅖"
                            text: Theme.frameFuse ? "ON" : "OFF"
                            primary: Theme.frameFuse
                            onClicked: Theme.setFrameFuse(!Theme.frameFuse)
                          }
                        }
                      }
                    }
                  }
                }

                  }
                }
              }


              // ── Audio · OozeAudio ──
              Loader {
                id: catLoader_audio
                Layout.fillWidth: true


                active: !root.searching && root.category === "audio" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  SettingsPanelTitle { icon: root.catIconByKey("advCatAudio"); title: Translations.t("advCatAudio") }

                  SettingsBtn {
                    text: Translations.t("advAudioOpenQpwgraph")
                    icon: "󰏌"
                    onClicked: root.openQpwgraph()
                  }

                  // ── Refrescar: ghost button, gira mientras consulta ──
                  SkinRect {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 9
                    color: audioRefreshArea.containsMouse ? Theme.surfaceHigh : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(120) } }
                    Text {
                      anchors.centerIn: parent
                      text: "󰑐"
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(14)
                      font.family: Theme.monoFamily
                      RotationAnimation on rotation {
                        running: AudioService.busy && Theme.uiAnimationsEnabled
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: Theme.animDuration(700)
                      }
                    }
                    MouseArea {
                      id: audioRefreshArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: AudioService.refreshAll()
                    }
                  }
                }

                // ── Mostrar/ocultar tarjeta de monitores físicos ──
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Text {
                    Layout.fillWidth: true
                    text: Translations.t("advAudioMonitorsToggleLabel")
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }

                  SkinRect {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 20
                    radius: 10
                    color: Theme.audioMonitorsCardEnabled ? Theme.primary : Theme.surfaceHigh
                    Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }

                    SkinRect {
                      width: 14
                      height: 14
                      radius: 7
                      anchors.verticalCenter: parent.verticalCenter
                      x: Theme.audioMonitorsCardEnabled ? 17 : 3
                      color: Theme.audioMonitorsCardEnabled ? Theme.textOnPrimary : Theme.subtext
                      Behavior on x { NumberAnimation { duration: Theme.animDuration(150); easing.type: Easing.OutCubic } }
                      Behavior on color { ColorAnimation { duration: Theme.animDuration(150) } }
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: Theme.setAudioMonitorsCardEnabled(!Theme.audioMonitorsCardEnabled)
                    }
                  }
                }

                // ── Error del backend, si el último comando falló ──
                SkinRect {
                  visible: root.oozeAudioError !== ""
                  Layout.fillWidth: true
                  implicitHeight: audioErrText.implicitHeight + 24
                  radius: Theme.cardRadius
                  color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                  clip: true
                  Text {
                    id: audioErrText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    wrapMode: Text.WordWrap
                    text: root.oozeAudioError
                    color: Theme.error
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }
                }

                // ── Salidas virtuales (ooze_*): crear, borrar, volumen ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: outputsCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: outputsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advAudioOutputsTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advAudioOutputsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    // ── Aviso: las salidas virtuales son para usuarios avanzados ──
                    SkinRect {
                      Layout.fillWidth: true
                      implicitHeight: virtualWarnRow.implicitHeight + 20
                      radius: 10
                      color: Qt.rgba(0.88, 0.69, 0.31, 0.14)
                      border.width: Theme.bw1
                      border.color: Qt.rgba(0.88, 0.69, 0.31, 0.45)
                      clip: true

                      RowLayout {
                        id: virtualWarnRow
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                        spacing: 10

                        Text {
                          Layout.alignment: Qt.AlignTop
                          text: "󰀦"
                          color: "#e0b04f"
                          font.pixelSize: Theme.fs(16)
                          font.family: Theme.monoFamily
                        }
                        Text {
                          Layout.fillWidth: true
                          text: Translations.t("advAudioVirtualWarning")
                          wrapMode: Text.WordWrap
                          color: Theme.text
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                        }
                      }
                    }

                    // ── Crear salida nueva ──
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 8

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: 10
                        color: Theme.bg
                        border.width: newOutputInput.activeFocus ? 1 : 0
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                        Behavior on border.width { NumberAnimation { duration: Theme.animDuration(150) } }

                        TextInput {
                          id: newOutputInput
                          anchors { fill: parent; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
                          verticalAlignment: TextInput.AlignVCenter
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          text: root.oozeAudioNewName
                          onTextChanged: root.oozeAudioNewName = text
                          onAccepted: if (root.oozeAudioNewName.trim() !== "") {
                            AudioService.createOutput(root.oozeAudioNewName.trim())
                            root.oozeAudioNewName = ""
                          }

                          Text {
                            visible: newOutputInput.text === "" && !newOutputInput.activeFocus
                            text: Translations.t("advAudioNewOutputPlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }

                      SettingsBtn {
                        text: Translations.t("advAudioCreate")
                        icon: "󰐕"
                        primary: true
                        enabled: !AudioService.busy && root.oozeAudioNewName.trim() !== ""
                        onClicked: {
                          AudioService.createOutput(root.oozeAudioNewName.trim())
                          root.oozeAudioNewName = ""
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Lista de salidas virtuales ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: AudioService.outputs.length > 0

                      Repeater {
                        model: AudioService.outputs
                        delegate: AudioRow {
                          required property var modelData
                          nodeId: modelData.id
                          nodeName: modelData.name
                          title: modelData.desc
                          subtitle: modelData.name
                          volume: modelData.volume
                          muted: modelData.muted
                          deletable: true
                          showConnections: true
                          confirmingDelete: root.oozeAudioConfirmDelete === modelData.name
                          onVolumeMoved: v => AudioService.setVolume("outputs", modelData.id, v)
                          onMuteToggled: AudioService.setMute("outputs", modelData.id, !modelData.muted)
                          onDeleteRequested: {
                            if (root.oozeAudioConfirmDelete === modelData.name) {
                              AudioService.deleteOutput(modelData.desc)
                              root.oozeAudioConfirmDelete = ""
                            } else {
                              root.oozeAudioConfirmDelete = modelData.name
                            }
                          }
                        }
                      }
                    }

                    Text {
                      visible: AudioService.outputs.length === 0
                      Layout.fillWidth: true
                      wrapMode: Text.WordWrap
                      text: Translations.t("advAudioNoOutputs")
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Aplicaciones: salida, volumen y mute por app ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: appsCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: appsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advAudioAppsTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advAudioAppsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    AppsRouting {}
                  }
                }

                // ── Monitores / salidas físicas: solo volumen ──
                SkinRect {
                  Layout.fillWidth: true
                  visible: Theme.audioMonitorsCardEnabled
                  implicitHeight: sinksCol.implicitHeight + 28
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: sinksCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    SectionLabel { text: Translations.t("advAudioMonitorsTitle") }
                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("advAudioMonitorsHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 8
                      visible: AudioService.destinationCandidates().length > 0

                      Repeater {
                        model: AudioService.destinationCandidates()
                        delegate: AudioRow {
                          required property var modelData
                          nodeId: modelData.id
                          title: modelData.desc
                          subtitle: modelData.name
                          volume: modelData.volume
                          muted: modelData.muted
                          deletable: false
                          onVolumeMoved: v => AudioService.setVolume("sinks", modelData.id, v)
                          onMuteToggled: AudioService.setMute("sinks", modelData.id, !modelData.muted)
                        }
                      }
                    }

                    Text {
                      visible: AudioService.destinationCandidates().length === 0
                      Layout.fillWidth: true
                      wrapMode: Text.WordWrap
                      text: Translations.t("advAudioNoMonitors")
                      color: Theme.subtext
                      font.italic: true
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                Item { Layout.preferredHeight: 4 }
                  }
                }
              }


              // ── Perfil · foto y nombre ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "profile"
                spacing: 14

                SettingsPanelTitle { icon: root.catIconByKey("advCatProfile"); title: Translations.t("advCatProfile") }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: profileCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: profileCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 16

                      Avatar {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 76
                        size: 76
                        source: UserProfile.avatarUrl
                        letter: UserProfile.shownName.length > 0 ? UserProfile.shownName.charAt(0).toUpperCase() : "?"
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 6

                        Text {
                          Layout.fillWidth: true
                          text: UserProfile.shownName.length > 0 ? UserProfile.shownName : "—"
                          color: Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(15)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }
                        Text {
                          Layout.fillWidth: true
                          text: UserProfile.busy ? Translations.t("profileSaving")
                              : UserProfile.avatarSource !== "" ? Translations.t("profilePhoto")
                              : Translations.t("profileNoPhoto")
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                          elide: Text.ElideRight
                        }

                        RowLayout {
                          spacing: 8
                          SettingsBtn {
                            primary: true
                            icon: "󰋩"
                            text: UserProfile.avatarSource !== "" ? Translations.t("profileChange")
                                                                  : Translations.t("profileChoose")
                            onClicked: root.browsing = !root.browsing
                          }
                          SettingsBtn {
                            visible: UserProfile.avatarPath !== ""
                            icon: "󰆴"
                            text: Translations.t("profileRemove")
                            onClicked: UserProfile.clearAvatar()
                          }
                        }
                      }
                    }

                    Text {
                      visible: root.browsing
                      Layout.fillWidth: true
                      text: Translations.t("profileBrowseHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }

                    ImageBrowser {
                      id: profileBrowser
                      visible: root.browsing
                      Layout.fillWidth: true
                      Layout.preferredHeight: 290

                      onPicked: path => {
                        UserProfile.chooseAvatar(path)
                        root.browsing = false
                      }
                      onCancelled: root.browsing = false
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

                    // ── Nombre a mostrar: vacío = se usa el de usuario ──
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 6

                      SectionLabel { text: Translations.t("profileDisplayName") }

                      Text {
                        Layout.fillWidth: true
                        text: Translations.t("profileDisplayNameHint")
                        wrapMode: Text.WordWrap
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: 12
                        color: Theme.bg
                        border.width: Theme.bw1
                        border.color: displayNameInput.activeFocus
                          ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                          : Theme.divider
                        Behavior on border.color { ColorAnimation { duration: Theme.animDuration(150) } }

                        TextInput {
                          id: displayNameInput
                          anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                          verticalAlignment: TextInput.AlignVCenter
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          text: UserProfile.displayName


                          onEditingFinished: UserProfile.setDisplayName(displayNameInput.text)
                          Keys.onReturnPressed: displayNameInput.focus = false
                          Keys.onEnterPressed: displayNameInput.focus = false

                          Text {
                            visible: displayNameInput.text === "" && !displayNameInput.activeFocus
                            text: Translations.t("profileDisplayNamePlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }
                    }
                  }
                }
              }

              // ── General · accesos a Monitor/Idioma/Launcher/Terminal ──
              Loader {
                id: catLoader_general
                Layout.fillWidth: true


                active: !root.searching && root.category === "general" && (root.open || card.visible)
                visible: active
                Layout.preferredHeight: item ? item.implicitHeight : 0
                onLoaded: { if (root.pendingAnchor !== "") anchorTimer.restart() }
                sourceComponent: Component {
                  ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatGeneral"); title: Translations.t("advCatGeneral") }

                // ── Todo se configura acá; solo Idioma abre su ventana (IPC) ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: monitorCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: monitorCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsMonitor") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      SettingsBtn {
                        icon: "󰍹"
                        text: Translations.t("monitorAutoOption")
                        primary: root.targetMonitor === "auto"
                        onClicked: root.monitorChosen("auto")
                      }
                      Repeater {
                        model: Quickshell.screens
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰍹"
                          text: modelData.name
                          primary: root.targetMonitor === modelData.name
                          onClicked: root.monitorChosen(modelData.name)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: root.targetMonitor === "auto" && root.resolvedMonitor !== ""
                        ? Translations.t("monitorAutoHint") + " " + root.resolvedMonitor
                        : Translations.t("monitorAutoSubtitle")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Idioma ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: languageCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: languageCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsLanguage") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      Repeater {

                        model: Translations.availableLanguages
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰗊"
                          text: modelData.name
                          primary: modelData.code === Translations.current
                          onClicked: root.languageChosen(modelData.code)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsLanguageHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: terminalCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: terminalCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("settingsTerminalSection") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8
                      Repeater {
                        model: root.terminalChoices
                        delegate: SettingsBtn {
                          required property var modelData
                          icon: "󰆍"
                          text: modelData.name
                          primary: Theme.terminalId === modelData.id
                          onClicked: Theme.setTerminal(modelData.id)
                        }
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("settingsTerminalHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }
                  }
                }

                // ── Pantalla de bloqueo: origen del fondo ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: lockCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: lockCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10


                    property string pathStatus: ""

                    function checkPath() {
                      if (Theme.lockWallpaperPath === "") { lockCol.pathStatus = "empty"; return }
                      lockPathCheck.running = false
                      lockPathCheck.running = true
                    }
                    Component.onCompleted: lockCol.checkPath()

                    Process {
                      id: lockPathCheck
                      command: ["bash", "-c", [
                        'p="$1"',
                        'case "$p" in "~"|"~/"*) p="$HOME${p#\\~}";; esac',
                        'p="${p/#\\$HOME/$HOME}"',
                        '[ -f "$p" ] && echo ok || echo missing'
                      ].join("\n"), "sh", Theme.lockWallpaperPath]
                      stdout: SplitParser {
                        onRead: line => lockCol.pathStatus = line.trim() === "ok" ? "ok" : "missing"
                      }
                    }

                    Connections {
                      target: Theme
                      function onLockWallpaperPathChanged() { lockCol.checkPath() }
                    }

                    SectionLabel { text: Translations.t("lockSection") }

                    Flow {
                      Layout.fillWidth: true
                      spacing: 8

                      SettingsBtn {
                        icon: "󰸉"
                        text: Translations.t("lockModeAuto")
                        primary: Theme.lockWallpaperMode === "auto"
                        onClicked: Theme.setLockWallpaperMode("auto")
                      }
                      SettingsBtn {
                        icon: "󰋩"
                        text: Translations.t("lockModeCustom")
                        primary: Theme.lockWallpaperMode === "custom"
                        onClicked: Theme.setLockWallpaperMode("custom")
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t(Theme.lockWallpaperMode === "custom" ? "lockCustomHint" : "lockAutoHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(10)
                      font.family: Theme.fontFamily
                    }


                    RowLayout {
                      Layout.fillWidth: true
                      visible: Theme.lockWallpaperMode === "custom"
                      spacing: 8

                      SkinRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 10
                        color: Theme.surfaceHigh
                        border.width: lockPathInput.activeFocus ? 1 : 0
                        border.color: Theme.primary

                        TextInput {
                          id: lockPathInput
                          anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                          verticalAlignment: TextInput.AlignVCenter
                          text: Theme.lockWallpaperPath
                          color: Theme.text
                          selectionColor: Theme.primary
                          selectedTextColor: Theme.textOnPrimary
                          font.pixelSize: Theme.fs(12)
                          font.family: Theme.fontFamily
                          clip: true
                          inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhUrlCharactersOnly
                          onAccepted: Theme.setLockWallpaperPath(text)
                          onEditingFinished: Theme.setLockWallpaperPath(text)

                          Text {
                            visible: lockPathInput.text === "" && !lockPathInput.activeFocus
                            text: Translations.t("lockPathPlaceholder")
                            color: Theme.subtext
                            font.pixelSize: Theme.fs(12)
                            font.family: Theme.fontFamily
                          }
                        }
                      }

                      SettingsBtn {
                        icon: "󰄬"
                        text: Translations.t("lockPathApply")
                        onClicked: Theme.setLockWallpaperPath(lockPathInput.text)
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      visible: Theme.lockWallpaperMode === "custom" && lockCol.pathStatus !== ""
                      wrapMode: Text.WordWrap
                      text: lockCol.pathStatus === "ok" ? "󰄬  " + Translations.t("lockPathOk")
                          : lockCol.pathStatus === "missing" ? "󰅖  " + Translations.t("lockPathMissing")
                          : Translations.t("lockPathEmpty")
                      color: lockCol.pathStatus === "ok" ? Theme.primary
                           : lockCol.pathStatus === "missing" ? Theme.error
                           : Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.monoFamily
                    }
                  }
                }

                // ── Fuente del shell (una por estilo; ver Theme.setFontPref) ──
                SkinRect {
                  Layout.fillWidth: true
                  implicitHeight: fontCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: fontCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    SectionLabel { text: Translations.t("fontTitle") }

                    Text {
                      Layout.fillWidth: true
                      text: Translations.t("fontHint")
                      wrapMode: Text.WordWrap
                      color: Theme.subtext
                      font.pixelSize: Theme.fs(11)
                      font.family: Theme.fontFamily
                    }

                    FontPicker { Layout.fillWidth: true }
                  }
                }
                  }
                }
              }

              // ── HyprMonitor · editor de monitores ──
              ColumnLayout {
                Layout.fillWidth: true
                visible: !root.searching && root.category === "hypr"
                spacing: 12

                SettingsPanelTitle { icon: root.catIconByKey("advCatHyprMonitor"); title: Translations.t("advCatHyprMonitor") }

                Text {
                  Layout.fillWidth: true
                  text: Translations.t("hyprMonitorsHint")
                  wrapMode: Text.WordWrap
                  color: Theme.subtext
                  font.pixelSize: Theme.fs(10)
                  font.family: Theme.fontFamily
                }

                // ── Mapa: arrastrar para reposicionar ──
                SkinRect {
                  id: hmMapCard
                  Layout.fillWidth: true
                  Layout.preferredHeight: root.hmMapHeight
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true
                  onWidthChanged: root.hmMapWidth = width
                  Component.onCompleted: root.hmMapWidth = width

                  Text {
                    visible: root.hmMonitors.length === 0
                    anchors.centerIn: parent
                    text: Translations.t("hyprMonitorsRefresh") + "…"
                    color: Theme.subtext
                    font.italic: true
                    font.pixelSize: Theme.fs(11)
                    font.family: Theme.fontFamily
                  }

                  Repeater {
                    model: root.hmMonitors

                    delegate: SkinRect {
                      id: hmBox
                      required property var modelData
                      readonly property bool isSelected: modelData.output === root.hmSelected
                      readonly property real logW: modelData.width / (modelData.scale || 1)
                      readonly property real logH: modelData.height / (modelData.scale || 1)

                      x: root.hmToMapX(modelData.x)
                      y: root.hmToMapY(modelData.y)
                      width: Math.max(40, logW * root.hmMapScale)
                      height: Math.max(30, logH * root.hmMapScale)
                      radius: 8
                      color: isSelected
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                        : Theme.bg
                      border.width: isSelected ? 2 : Theme.bw1
                      border.color: isSelected ? Theme.primary : Theme.edge
                      Behavior on x { enabled: !hmDrag.drag.active; NumberAnimation { duration: Theme.animDuration(120) } }
                      Behavior on y { enabled: !hmDrag.drag.active; NumberAnimation { duration: Theme.animDuration(120) } }

                      ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                          Layout.alignment: Qt.AlignHCenter
                          text: hmBox.modelData.output
                          color: hmBox.isSelected ? Theme.primary : Theme.text
                          font.bold: true
                          font.pixelSize: Theme.fs(11)
                          font.family: Theme.fontFamily
                        }
                        Text {
                          Layout.alignment: Qt.AlignHCenter
                          visible: hmBox.width > 70
                          text: hmBox.modelData.width + "×" + hmBox.modelData.height
                          color: Theme.subtext
                          font.pixelSize: Theme.fs(9)
                          font.family: Theme.fontFamily
                        }
                      }

                      MouseArea {
                        id: hmDrag
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: root.hmSelected = hmBox.modelData.output
                        drag.target: hmBox
                        drag.axis: Drag.XAndYAxis
                        onReleased: root.hmUpdateMonitor(hmBox.modelData.output, {
                          x: root.hmSnap(root.hmFromMapX(hmBox.x)),
                          y: root.hmSnap(root.hmFromMapY(hmBox.y))
                        })
                      }
                    }
                  }
                }

                // ── Selector de salida (si hay más de una) ──
                Flow {
                  Layout.fillWidth: true
                  visible: root.hmMonitors.length > 1
                  spacing: 8
                  Repeater {
                    model: root.hmMonitors
                    delegate: SettingsBtn {
                      required property var modelData
                      icon: "󰍹"
                      text: modelData.output
                      primary: modelData.output === root.hmSelected
                      onClicked: root.hmSelected = modelData.output
                    }
                  }
                }

                // ── Ajustes del monitor seleccionado ──
                SkinRect {
                  Layout.fillWidth: true
                  visible: root.hmCurrent !== null
                  implicitHeight: hmSettingsCol.implicitHeight + 30
                  radius: Theme.cardRadius
                  color: Theme.surface
                  border.width: Theme.bw1
                  border.color: Theme.edge
                  clip: true

                  ColumnLayout {
                    id: hmSettingsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 12

                    RowLayout {
                      Layout.fillWidth: true
                      Text {
                        text: root.hmCurrent ? root.hmCurrent.output : ""
                        color: Theme.primary
                        font.bold: true
                        font.pixelSize: Theme.fs(13)
                        font.family: Theme.fontFamily
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: root.hmCurrent ? (root.hmCurrent.width + "×" + root.hmCurrent.height
                              + "  @ " + root.hmCurrent.x + "," + root.hmCurrent.y) : ""
                        color: Theme.subtext
                        font.pixelSize: Theme.fs(10)
                        font.family: Theme.fontFamily
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }


                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsMode")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SettingsBtn {
                          text: Translations.t("hyprMonitorsPreferred")
                          primary: root.hmCurrent && root.hmCurrent.mode === "preferred"
                          onClicked: root.hmUpdateMonitor(root.hmSelected, { mode: "preferred" })
                        }
                        Repeater {
                          model: root.hmCurrent ? root.hmCurrent.modes : []
                          delegate: SettingsBtn {
                            required property string modelData
                            text: modelData
                            primary: root.hmCurrent && root.hmCurrent.mode === modelData
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { mode: modelData })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }


                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsScale")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                          model: ["auto", 1, 1.25, 1.5, 2]
                          delegate: SettingsBtn {
                            required property var modelData
                            text: modelData === "auto" ? Translations.t("hyprMonitorsAuto")
                                                        : Math.round(modelData * 100) + "%"
                            primary: root.hmCurrent && root.hmCurrent.scale === modelData
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { scale: modelData })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }


                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsRotation")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                          model: [ { v: 0, l: "0°" }, { v: 1, l: "90°" }, { v: 2, l: "180°" }, { v: 3, l: "270°" } ]
                          delegate: SettingsBtn {
                            required property var modelData
                            text: modelData.l
                            primary: root.hmCurrent && root.hmCurrent.transform === modelData.v
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { transform: modelData.v })
                          }
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }


                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      SectionLabel {
                        Layout.preferredWidth: 90
                        Layout.alignment: Qt.AlignTop
                        text: Translations.t("hyprMonitorsMirror")
                      }
                      Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SettingsBtn {
                          text: Translations.t("hyprMonitorsMirrorNone")
                          primary: root.hmCurrent && root.hmCurrent.mirrorOf === ""
                          onClicked: root.hmUpdateMonitor(root.hmSelected, { mirrorOf: "" })
                        }
                        Repeater {
                          model: root.hmMonitors.filter(m => m.output !== root.hmSelected)
                          delegate: SettingsBtn {
                            required property var modelData
                            icon: "󰍹"
                            text: modelData.output
                            primary: root.hmCurrent && root.hmCurrent.mirrorOf === modelData.output
                            onClicked: root.hmUpdateMonitor(root.hmSelected, { mirrorOf: modelData.output })
                          }
                        }
                      }
                    }
                  }
                }

                // ── Pie: redetectar · estado · aplicar ──
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10
                  SettingsBtn {
                    icon: "󰑐"
                    text: Translations.t("hyprMonitorsRefresh")
                    onClicked: root.hmRefresh()
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    visible: root.hmStatus !== ""
                    Layout.maximumWidth: 260
                    text: root.hmStatus
                    wrapMode: Text.WordWrap
                    color: Theme.subtext
                    font.pixelSize: Theme.fs(10)
                    font.family: Theme.fontFamily
                  }
                  SettingsBtn {
                    primary: true
                    icon: "󰄬"
                    text: Translations.t("hyprMonitorsApply")
                    onClicked: root.hmApplyAndSave()
                  }
                }
              }

              Item { Layout.preferredHeight: 4 }
            }
          }
        }
      }
      }
    }
    }
  }
}
